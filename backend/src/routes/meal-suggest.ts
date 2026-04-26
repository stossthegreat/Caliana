import type { FastifyInstance } from 'fastify';
import type { Recipe } from '../types/recipe.js';
import { webSearch } from '../services/web_search.js';
import { fetchParallel } from '../services/fetcher.js';
import { extractRecipeFromHtml } from '../services/jsonld.js';
import { isBlocked } from '../data/domains.js';
import { config } from '../config.js';

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
  // Rich JSON-LD fields.
  imageUrl?: string;
  ratingValue?: number;
  ratingCount?: number;
  totalTimeMin?: number;
  description?: string;
  sourceDomain?: string;
  // Always 1 — we now scale everything to one portion server-side so
  // the user can cook straight from the card without doing maths.
  servings?: number;
  originalServings?: number;
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

        // We deliberately DO NOT fall back to GPT-only slim ideas
        // here. Mixing image-rich recipe cards with bare-text cards
        // looked cheap and inconsistent. If we can't scrape real
        // recipes with images, return [] and let Flutter show a
        // Caliana chat reply instead.
        return { ideas };
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
  // Build a search query that biases Google toward real recipe pages
  // with photos. Budget hint nudges results to the right calorie range.
  const budgetHint = typeof remainingKcal === 'number' && remainingKcal > 0
    ? ` under ${Math.round(remainingKcal)} calories`
    : '';
  const query = `${ask}${budgetHint} recipe with photo`;

  // Pull a wide net so the image-only filter still has plenty to pick
  // from after low-quality recipes are stripped.
  const searchResults = await webSearch(query, 20);
  const candidates = searchResults
    .filter((r) => r.link && !isBlocked(r.link))
    .slice(0, Math.max(config.maxCandidates, 14));

  if (candidates.length === 0) return [];

  const fetched = await fetchParallel(candidates.map((c) => c.link));

  const recipes: Recipe[] = [];
  for (const result of fetched) {
    if (!result.html) continue;
    const recipe = extractRecipeFromHtml(result.html, result.url);
    if (recipe) recipes.push(recipe);
  }

  if (recipes.length === 0) return [];

  // STRICT: only image-rich recipes. Inconsistent cards (some hero
  // image, some bare text) read as cheap. If we can't find any with
  // images, return [] and let the Flutter UI fall through to chat.
  let pool = recipes.filter((r) => r.image && r.image.length > 0);
  if (pool.length === 0) return [];

  // Intent-aware filtering: when the user asked for "high protein",
  // strip dishes that obviously don't deliver (plain salads with no
  // protein number, dessert recipes, etc.) BEFORE ranking. This stops
  // the "I asked high protein, got Caesar salad" complaint.
  const askLower = ask.toLowerCase();
  const wantsHighProtein =
    askLower.includes('high protein') ||
    askLower.includes('high-protein') ||
    askLower.includes('protein-rich');

  if (wantsHighProtein) {
    const proteinFiltered = pool.filter((r) => isLikelyHighProtein(r));
    if (proteinFiltered.length >= 1) pool = proteinFiltered;
    // If filter wipes everything (e.g. JSON-LD has no nutrition data),
    // keep the original pool but the scorer below will still demote
    // obvious low-protein dishes by name.
  }

  const target = remainingKcal && remainingKcal > 0 ? remainingKcal : 0;
  const scored = pool
    .map((r) => ({ r, score: scoreRecipe(r, target, wantsHighProtein) }))
    .sort((a, b) => b.score - a.score)
    .slice(0, 3);

  return scored.map(({ r }) => recipeToMealIdea(r));
}

function isLikelyHighProtein(r: Recipe): boolean {
  // 1. JSON-LD told us protein in grams: trust it. >= 25g/serving qualifies.
  const proteinGrams = parseGrams(r.nutrition?.protein);
  if (proteinGrams >= 25) return true;
  // 2. JSON-LD has nutrition but protein is low — DON'T trust the title alone.
  if (r.nutrition?.protein && proteinGrams < 25) return false;
  // 3. No nutrition data at all: name-based heuristic.
  const name = r.title.toLowerCase();
  const proteinHits = [
    'chicken', 'salmon', 'tuna', 'turkey', 'beef', 'steak', 'pork',
    'shrimp', 'prawn', 'cod', 'tofu', 'tempeh', 'lentil', 'chickpea',
    'protein', 'omelette', 'omelet', 'eggs',
  ];
  const proteinDodges = [
    'pasta salad', 'caesar salad', 'green salad', 'side salad',
    'fruit salad', 'cookie', 'cake', 'brownie', 'pancake',
    'doughnut', 'donut', 'smoothie', 'oatmeal',
  ];
  if (proteinDodges.some((w) => name.includes(w))) return false;
  return proteinHits.some((w) => name.includes(w));
}

function scoreRecipe(
  r: Recipe,
  target: number,
  wantsHighProtein: boolean,
): number {
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

  if (wantsHighProtein) {
    const grams = parseGrams(r.nutrition?.protein);
    if (grams >= 35) s += 5;
    else if (grams >= 25) s += 3;
    else if (grams > 0 && grams < 15) s -= 5; // Demote known low-protein.
    const name = r.title.toLowerCase();
    if (
      name.includes('chicken') ||
      name.includes('salmon') ||
      name.includes('steak') ||
      name.includes('tuna') ||
      name.includes('protein')
    ) {
      s += 2;
    }
    if (
      name.includes('caesar salad') ||
      name.includes('pasta salad') ||
      name.includes('green salad')
    ) {
      s -= 4;
    }
  }
  return s;
}

function recipeToMealIdea(r: Recipe): RichMealIdea {
  const cals = r.nutrition?.calories ?? 0;
  // Scale ingredients down to a single portion so users can cook the
  // card without doing maths in their head. JSON-LD nutrition is
  // already per-serving; only the ingredient quantities are bulk.
  const original = r.servings && r.servings > 1 ? r.servings : 1;
  const factor = original > 1 ? 1 / original : 1;
  const scaledIngredients = r.ingredients
    .slice(0, 12)
    .map((line) => (factor < 1 ? scaleIngredient(line, factor) : line));
  return {
    name: r.title,
    calories: Math.round(cals),
    protein: parseGrams(r.nutrition?.protein),
    carbs: parseGrams(r.nutrition?.carbs),
    fat: parseGrams(r.nutrition?.fat),
    ingredients: scaledIngredients,
    steps: r.instructions.slice(0, 8),
    servings: 1,
    originalServings: original,
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
 * Scale a single ingredient line by a factor (e.g. 0.25 to go from
 * 4 servings to 1). Best-effort: handles whole numbers ("2 tbsp"),
 * decimals ("1.5 cups"), fractions ("1/2 cup"), unicode fractions
 * ("½ cup"), and number-glued-to-unit ("400g flour"). Lines with no
 * leading number ("salt and pepper to taste") pass through unchanged.
 */
function scaleIngredient(line: string, factor: number): string {
  const fracMap: Record<string, number> = {
    '½': 0.5,
    '¼': 0.25,
    '¾': 0.75,
    '⅓': 1 / 3,
    '⅔': 2 / 3,
    '⅛': 0.125,
    '⅜': 0.375,
    '⅝': 0.625,
    '⅞': 0.875,
  };
  const trimmed = line.trim();

  // Unicode fraction at the start, e.g. "½ cup milk".
  const firstChar = trimmed.charAt(0);
  if (firstChar in fracMap) {
    const rest = trimmed.slice(1).trim();
    return `${formatScaled(fracMap[firstChar] * factor)} ${rest}`;
  }

  // "1 ½ cup" mixed number.
  const mixedMatch = trimmed.match(
    /^(\d+)\s*([½¼¾⅓⅔⅛⅜⅝⅞])\s+(.+)$/,
  );
  if (mixedMatch) {
    const whole = parseInt(mixedMatch[1], 10);
    const frac = fracMap[mixedMatch[2]] || 0;
    return `${formatScaled((whole + frac) * factor)} ${mixedMatch[3]}`;
  }

  // "1/2 cup".
  const fracMatch = trimmed.match(/^(\d+)\s*\/\s*(\d+)\s+(.+)$/);
  if (fracMatch) {
    const num = parseInt(fracMatch[1], 10);
    const den = parseInt(fracMatch[2], 10);
    if (den !== 0) {
      return `${formatScaled((num / den) * factor)} ${fracMatch[3]}`;
    }
  }

  // "2.5 tbsp" or "1.5 cups".
  const decMatch = trimmed.match(/^(\d+\.\d+)\s+(.+)$/);
  if (decMatch) {
    return `${formatScaled(parseFloat(decMatch[1]) * factor)} ${decMatch[2]}`;
  }

  // "2 large onions" — whole number then space.
  const intMatch = trimmed.match(/^(\d+)\s+(.+)$/);
  if (intMatch) {
    return `${formatScaled(parseInt(intMatch[1], 10) * factor)} ${intMatch[2]}`;
  }

  // "400g flour", "500ml stock", "8oz beef" — number stuck to a unit.
  const unitMatch = trimmed.match(
    /^(\d+(?:\.\d+)?)\s*(g|kg|ml|l|oz|lb|lbs|tbsp|tsp|cup|cups)\b\s*(.*)$/i,
  );
  if (unitMatch) {
    const n = parseFloat(unitMatch[1]);
    const unit = unitMatch[2];
    const rest = unitMatch[3] ?? '';
    return `${formatScaled(n * factor)}${unit}${rest ? ' ' + rest : ''}`;
  }

  // Bare numeric range like "2-3 onions" — scale both ends.
  const rangeMatch = trimmed.match(/^(\d+)\s*-\s*(\d+)\s+(.+)$/);
  if (rangeMatch) {
    const a = parseInt(rangeMatch[1], 10) * factor;
    const b = parseInt(rangeMatch[2], 10) * factor;
    return `${formatScaled(a)}-${formatScaled(b)} ${rangeMatch[3]}`;
  }

  return line;
}

function formatScaled(n: number): string {
  if (!Number.isFinite(n) || n <= 0) return '0';
  if (n >= 1) {
    // Round to 1 decimal where it matters; whole when clean.
    const rounded = Math.round(n * 10) / 10;
    return rounded === Math.round(rounded)
      ? String(Math.round(rounded))
      : rounded.toFixed(1);
  }
  // < 1: prefer a common fraction over an ugly decimal.
  const closest: Array<[number, string]> = [
    [0.125, '⅛'],
    [0.25, '¼'],
    [0.333, '⅓'],
    [0.5, '½'],
    [0.667, '⅔'],
    [0.75, '¾'],
  ];
  let best = closest[0];
  let bestDiff = Math.abs(n - best[0]);
  for (const c of closest) {
    const diff = Math.abs(n - c[0]);
    if (diff < bestDiff) {
      best = c;
      bestDiff = diff;
    }
  }
  if (bestDiff < 0.06) return best[1];
  // Otherwise round to 2 decimals.
  return (Math.round(n * 100) / 100).toString();
}

