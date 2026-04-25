import type { FastifyInstance } from 'fastify';
import { config } from '../config.js';
import { getOpenAI } from '../services/openai_client.js';
import { webSearch } from '../services/web_search.js';

interface MealSuggestRequest {
  /** Free-form ask: "high protein", "quick lunch", "light dinner", "fridge fix" */
  ask: string;
  /** Remaining kcal for the day */
  remainingKcal?: number;
  /** Free-form user profile context */
  userContext?: string;
}

interface MealIdea {
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
 * POST /api/meal-suggest
 *
 * Caliana's "suggest me a meal" endpoint. Uses GPT to propose 2-3 meal ideas
 * that fit the user's remaining budget + macros, then optionally enriches
 * each idea with a Serper web-search link so the client can open the
 * original recipe.
 */
export async function registerMealSuggestRoute(
  app: FastifyInstance,
): Promise<void> {
  app.post<{ Body: MealSuggestRequest }>(
    '/api/meal-suggest',
    async (req, reply) => {
      const { ask, remainingKcal, userContext } =
        req.body || ({} as MealSuggestRequest);

      if (!ask || typeof ask !== 'string') {
        return reply.status(400).send({ error: 'ask is required' });
      }

      try {
        const ideas = await generateIdeas(
          ask.trim(),
          remainingKcal,
          userContext,
        );

        // Enrich with a web link for each idea (best-effort; ignore failures).
        const enriched = await Promise.all(
          ideas.map(async (idea) => {
            try {
              const results = await webSearch(`${idea.name} recipe`, 1);
              const top = results[0];
              if (top) {
                return { ...idea, link: top.link, source: top.title };
              }
            } catch {
              // If search isn't configured or fails, return the idea as-is.
            }
            return idea;
          }),
        );

        return { ideas: enriched };
      } catch (err) {
        req.log.error({ err }, 'meal-suggest failed');
        return reply.status(500).send({
          error: 'suggest failed',
          message: err instanceof Error ? err.message : String(err),
        });
      }
    },
  );
}

async function generateIdeas(
  ask: string,
  remainingKcal: number | undefined,
  userContext: string | undefined,
): Promise<MealIdea[]> {
  const budgetLine = typeof remainingKcal === 'number'
    ? `BUDGET: ~${Math.max(100, remainingKcal)} kcal remaining for today.`
    : 'BUDGET: unspecified — aim for 400-600 kcal.';

  const system = `You generate 2-3 meal ideas that match a user's ask.

Return JSON only:
{
  "ideas": [
    {
      "name": "short dish name (3-6 words)",
      "calories": 420,
      "protein": 38,
      "carbs": 22,
      "fat": 16,
      "ingredients": ["6oz chicken breast", "1 cup brown rice (cooked)", "..."],
      "steps": ["Pan-sear the chicken 4 min per side.", "..."]
    },
    ...
  ]
}

RULES:
- Return 2-3 ideas max.
- Names must be COMMON dishes that would have real recipes online
  (e.g. "grilled chicken bowl", "greek salad with feta", "tuna wrap").
- Fit the BUDGET and the user's context (allergies, diet, dislikes).
- Realistic single-serving macros.
- Round calories to nearest 10.
- Never invent fusion names.
- INGREDIENTS: 4-8 short bullet lines, each with quantity (e.g. "1 tbsp olive oil",
  "2 eggs", "150g cooked quinoa"). UK measurements where natural. No prose.
- STEPS: 3-5 short imperative steps. One sentence each. No fluff.`;

  const user = [
    budgetLine,
    userContext ? `USER: ${userContext}` : '',
    `ASK: ${ask}`,
  ]
    .filter(Boolean)
    .join('\n');

  const response = await getOpenAI().chat.completions.create({
    model: config.openaiModel,
    messages: [
      { role: 'system', content: system },
      { role: 'user', content: user },
    ],
    temperature: 0.5,
    max_tokens: 900,
    response_format: { type: 'json_object' },
  });
  const raw = response.choices[0]?.message?.content || '{"ideas": []}';
  const parsed = JSON.parse(raw) as { ideas?: MealIdea[] };
  if (!parsed.ideas || !Array.isArray(parsed.ideas)) return [];
  return parsed.ideas.slice(0, 3).map((i) => ({
    name: String(i.name || 'Meal idea'),
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
