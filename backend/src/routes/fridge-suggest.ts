import type { FastifyInstance } from 'fastify';
import { getOpenAI } from '../services/openai_client.js';
import { webSearch } from '../services/web_search.js';

interface FridgeMealIdea {
  name: string;
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
  ingredients: string[];
  steps: string[];
  link?: string;
  source?: string;
}

/**
 * POST /api/fridge-suggest
 *
 * Multipart:
 *   - photo (file): a snap of the inside of the user's fridge
 *   - remainingKcal (text, optional): kcal budget left for today
 *   - userContext (text, optional): allergies, diet, dislikes, tone profile
 *
 * Single GPT-4o vision call: identifies visible ingredients in the photo,
 * then returns 2-3 meal ideas that USE those ingredients and fit the
 * remaining calorie budget. Each idea is enriched with a Serper recipe
 * link (best-effort), then returned to the client which renders recipe
 * cards inline + saves them to the user's Recipes Sheet.
 */
export async function registerFridgeSuggestRoute(
  app: FastifyInstance,
): Promise<void> {
  app.post('/api/fridge-suggest', async (req, reply) => {
    try {
      const parts = req.parts();
      let imageBuffer: Buffer | null = null;
      let mimetype = 'image/jpeg';
      let remainingKcal: number | undefined;
      let userContext = '';

      for await (const part of parts) {
        if (part.type === 'file' && part.fieldname === 'photo') {
          imageBuffer = await part.toBuffer();
          mimetype = part.mimetype || 'image/jpeg';
        } else if (part.type === 'field') {
          if (part.fieldname === 'remainingKcal') {
            const n = Number(part.value);
            if (Number.isFinite(n) && n > 0) remainingKcal = Math.round(n);
          } else if (part.fieldname === 'userContext') {
            const v = part.value;
            if (typeof v === 'string') userContext = v;
          }
        }
      }

      if (!imageBuffer || imageBuffer.length === 0) {
        return reply.status(400).send({ error: 'photo file required' });
      }

      const dataUrl = `data:${mimetype};base64,${imageBuffer.toString('base64')}`;
      const ideas = await suggestFromFridge(dataUrl, remainingKcal, userContext);

      // Best-effort recipe-link enrichment via Serper/Brave (same pattern
      // as /api/meal-suggest). Failures here don't block the response.
      const enriched = await Promise.all(
        ideas.map(async (idea) => {
          try {
            const results = await webSearch(`${idea.name} recipe`, 1);
            const top = results[0];
            if (top) return { ...idea, link: top.link, source: top.title };
          } catch {
            /* ignore */
          }
          return idea;
        }),
      );

      return { ideas: enriched };
    } catch (err) {
      req.log.error({ err }, 'fridge-suggest failed');
      return reply.status(500).send({
        error: 'fridge suggest failed',
        message: err instanceof Error ? err.message : String(err),
      });
    }
  });
}

async function suggestFromFridge(
  imageDataUrl: string,
  remainingKcal: number | undefined,
  userContext: string,
): Promise<FridgeMealIdea[]> {
  const budgetLine = typeof remainingKcal === 'number'
    ? `BUDGET: ~${Math.max(100, remainingKcal)} kcal remaining for today.`
    : 'BUDGET: unspecified — aim for 400-600 kcal per meal.';

  const system = `You see a photo of the inside of a user's fridge.
Identify the visible ingredients, then propose 2-3 meal ideas that USE
those ingredients (mostly) and fit the user's remaining calorie budget.

Return JSON only — no prose:
{
  "visibleIngredients": ["chicken breast", "spinach", "feta", "..."],
  "ideas": [
    {
      "name": "short dish name (3-6 words)",
      "calories": 420,
      "protein": 38,
      "carbs": 22,
      "fat": 16,
      "ingredients": ["6oz chicken breast", "1 cup spinach", "..."],
      "steps": ["Pan-sear chicken 4 min per side.", "..."]
    },
    ...
  ]
}

RULES:
- Use what's actually in the photo. Don't invent ingredients the user
  obviously doesn't have. Acceptable to assume basic pantry items
  (oil, salt, pepper, garlic, common spices) that may be off-screen.
- Each idea must use AT LEAST 2 things visible in the photo.
- Names must be COMMON dishes (e.g. "spinach feta omelette",
  "chicken stir-fry with veg"), not invented fusion names.
- Fit the BUDGET — adjust portions, not honesty.
- 2-3 ideas. Round calories to the nearest 10.
- INGREDIENTS: 4-8 short bullet lines with quantities. UK measurements
  where natural. No prose.
- STEPS: 3-5 short imperative sentences. No fluff.
- If the photo is unclear or shows no food, return {"ideas": []} and
  flag in visibleIngredients with a single string "unclear".`;

  const userMessage = [
    budgetLine,
    userContext ? `USER: ${userContext}` : '',
    "What's in this fridge? Plan two or three meals from it.",
  ]
    .filter(Boolean)
    .join('\n');

  const response = await getOpenAI().chat.completions.create({
    model: 'gpt-4o',
    messages: [
      { role: 'system', content: system },
      {
        role: 'user',
        content: [
          { type: 'text', text: userMessage },
          { type: 'image_url', image_url: { url: imageDataUrl } },
        ],
      },
    ],
    temperature: 0.5,
    max_tokens: 1100,
    response_format: { type: 'json_object' },
  });

  const raw = response.choices[0]?.message?.content || '{"ideas":[]}';
  const parsed = JSON.parse(raw) as { ideas?: FridgeMealIdea[] };
  if (!parsed.ideas || !Array.isArray(parsed.ideas)) return [];

  return parsed.ideas.slice(0, 3).map((i) => ({
    name: String(i.name || 'Fridge meal'),
    calories: clampInt(i.calories, 0, 2000),
    protein: clampInt(i.protein, 0, 200),
    carbs: clampInt(i.carbs, 0, 300),
    fat: clampInt(i.fat, 0, 200),
    ingredients: cleanStringList(i.ingredients, 8),
    steps: cleanStringList(i.steps, 6),
  }));
}

function cleanStringList(raw: unknown, max: number): string[] {
  if (!Array.isArray(raw)) return [];
  return raw
    .map((x) => (typeof x === 'string' ? x.trim() : ''))
    .filter((s) => s.length > 0 && s.length <= 140)
    .slice(0, max);
}

function clampInt(v: unknown, min: number, max: number): number {
  const n = typeof v === 'number' ? v : Number(v);
  if (!Number.isFinite(n)) return 0;
  return Math.max(min, Math.min(max, Math.round(n)));
}
