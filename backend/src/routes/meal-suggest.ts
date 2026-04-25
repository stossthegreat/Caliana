import type { FastifyInstance } from 'fastify';
import type { Recipe } from '../types/recipe.js';
import { webSearch } from '../services/web_search.js';
import { fetchParallel } from '../services/fetcher.js';
import { extractRecipeFromHtml } from '../services/jsonld.js';
import { isBlocked } from '../data/domains.js';
import { config } from '../config.js';
import { getOpenAI } from '../services/openai_client.js';

interface MealSuggestRequest {
  /** Free-form ask: "high protein dinner", "quick lunch", "light clean meal" */
  ask: string;
  /** Remaining kcal for the day — drives the calorie target in the search query */
  remainingKcal?: number;
  /** Free-form user profile context (diet, allergies, etc.) */
  userContext?: string;
}

/** Wire-format meal idea — backwards compatible with the old shape, plus
 *  the rich JSON-LD fields the Flutter recipe card needs (image, rating, time). */
interface RichMealIdea {
  name: string;
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
  ingredients: string[];
  steps: string[];
  link?: string;
  source?: string;
  // New fields populated from JSON-LD when we successfully scrape a real recipe.
  imageUrl?: string;
  ratingValue?: number;
  ratingCount?: number;
  totalTimeMin?: number;
  description?: string;
  sourceDomain?: string;
}

/**
 * POST /api/meal-suggest
 *
 * Returns 1-3 REAL recipes from trusted publishers (NYT Cooking, Serious Eats,
 * BBC Good Food, etc.) — full JSON-LD extraction including image, rating,
 * cook time, ingredients and instructions. Same pipeline Gobly used.
 *
 * Falls back to a slim GPT-generated idea only when no real recipe can be
 * scraped — so the UI never dead-ends.
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
        const ideas = await suggestRealRecipes(
          ask.trim(),
          remainingKcal,
          userContext,
        );

        if (ideas.length > 0) {
          return { ideas };
        }

        // Backstop: if the JSON-LD pipeline returned nothing usable
        // (search blocked, sites without schema.org markup, etc.),
        // fall back to a quick GPT-generated idea so the UI still has
        // something to render.
        const fallback = await fallbackGptIdeas(
          ask.trim(),
          remainingKcal,
          userContext,
        );
        return { ideas: fallback };
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

/**
 * The real-recipe pipeline. Mirrors /api/search but tuned for the
 * meal-suggest UX (kcal-budget-aware query, fewer fetches, returns the
 * RichMealIdea shape the chat UI expects).
 */
async function suggestRealRecipes(
  ask: string,
  remainingKcal: number | undefined,
  userContext: string | undefined,
): Promise<RichMealIdea[]> {
  // Build a search query that biases Google toward real recipe pages.
  // Budget hint nudges results to the right calorie range.
  const budgetHint = typeof remainingKcal === 'number' && remainingKcal > 0
    ? ` under ${Math.round(remainingKcal)} calories`
    : '';
  const query = `${ask}${budgetHint} recipe`;

  const searchResults = await webSearch(query, 12);
  const candidates = searchResults
    .filter((r) => r.link && !isBlocked(r.link))
    .slice(0, Math.max(config.maxCandidates, 8));

  if (candidates.length === 0) return [];

  const fetched = await fetchParallel(candidates.map((c) => c.link));

  const recipes: Recipe[] = [];
  for (const result of fetched) {
    if (!result.html) continue;
    const recipe = extractRecipeFromHtml(result.html, result.url);
    if (recipe) recipes.push(recipe);
  }

  if (recipes.length === 0) return [];

  // Rank: prefer recipes with images + a calorie estimate close to budget,
  // then by rating × log(reviewCount + 1) so popularity helps but a
  // 5-star recipe with one review doesn't trump a 4.7 with thousands.
  const target = remainingKcal && remainingKcal > 0 ? remainingKcal : 0;
  const scored = recipes
    .map((r) => ({ r, score: scoreRecipe(r, target) }))
    .sort((a, b) => b.score - a.score)
    .slice(0, 3);

  return scored.map(({ r }) => recipeToMealIdea(r));
}

function scoreRecipe(r: Recipe, target: number): number {
  let s = 0;
  if (r.image) s += 4; // Hero image is non-negotiable for the new card.
  if (r.rating.value >= 4.5) s += 3;
  else if (r.rating.value >= 4.0) s += 1;
  if (r.rating.count >= 100) s += 2;
  if (target > 0 && r.nutrition?.calories) {
    const diff = Math.abs(r.nutrition.calories - target) / target;
    if (diff < 0.20) s += 4;
    else if (diff < 0.40) s += 2;
    else if (diff > 0.80) s -= 3;
  }
  s += (r.source.authority || 0) / 25;
  return s;
}

function recipeToMealIdea(r: Recipe): RichMealIdea {
  const cals = r.nutrition?.calories ?? 0;
  return {
    name: r.title,
    calories: Math.round(cals),
    protein: parseGrams(r.nutrition?.protein),
    carbs: parseGrams(r.nutrition?.carbs),
    fat: parseGrams(r.nutrition?.fat),
    ingredients: r.ingredients.slice(0, 12),
    steps: r.instructions.slice(0, 8),
    link: r.source.url,
    source: r.source.name,
    imageUrl: r.image || undefined,
    ratingValue: r.rating.value > 0 ? r.rating.value : undefined,
    ratingCount: r.rating.count > 0 ? r.rating.count : undefined,
    totalTimeMin: r.time.total ?? undefined,
    description: r.description || undefined,
    sourceDomain: r.source.domain,
  };
}

function parseGrams(s: string | undefined): number {
  if (!s) return 0;
  const m = String(s).match(/[\d.]+/);
  if (!m) return 0;
  return Math.round(parseFloat(m[0]));
}

/**
 * If the real-recipe pipeline returned nothing, hand the user something
 * rather than an empty card. GPT-generated ideas: name + macros only,
 * no image/rating/link. The card still renders; it just looks slimmer.
 */
async function fallbackGptIdeas(
  ask: string,
  remainingKcal: number | undefined,
  userContext: string | undefined,
): Promise<RichMealIdea[]> {
  const budgetLine = typeof remainingKcal === 'number'
    ? `BUDGET: ~${Math.max(100, remainingKcal)} kcal remaining for today.`
    : 'BUDGET: unspecified — aim for 400-600 kcal.';

  const system = `Return 2 real, common dishes that fit the user's ask and BUDGET.
Return JSON only:
{"ideas":[{"name":"3-5 word dish name","calories":420,"protein":38,"carbs":22,"fat":16,"ingredients":["...","..."],"steps":["...","..."]}]}
RULES:
- 2 ideas. Real, common dishes (chicken caesar salad, tuna pasta bake) — never invented fusion names.
- Calories must be realistic for ONE serving. Macros sum within 15% of calories.
- 4-8 ingredient lines with quantities. 3-5 short imperative steps.
- Round calories to 10. UK measurements where natural.`;

  const user = [
    budgetLine,
    userContext ? `USER: ${userContext}` : '',
    `ASK: ${ask}`,
  ].filter(Boolean).join('\n');

  const response = await getOpenAI().chat.completions.create({
    model: config.openaiModel,
    messages: [
      { role: 'system', content: system },
      { role: 'user', content: user },
    ],
    temperature: 0.3,
    max_tokens: 700,
    response_format: { type: 'json_object' },
  });
  const raw = response.choices[0]?.message?.content || '{"ideas":[]}';
  const parsed = JSON.parse(raw) as { ideas?: Partial<RichMealIdea>[] };
  if (!parsed.ideas || !Array.isArray(parsed.ideas)) return [];
  return parsed.ideas.slice(0, 2).map((i) => ({
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
    .filter((s) => s.length > 0 && s.length <= 200)
    .slice(0, max);
}

function clampInt(v: unknown, min: number, max: number): number {
  const n = typeof v === 'number' ? v : Number(v);
  if (!Number.isFinite(n)) return 0;
  return Math.max(min, Math.min(max, Math.round(n)));
}
