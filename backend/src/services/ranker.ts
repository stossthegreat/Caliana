import type { Recipe } from '../types/recipe.js';

/**
 * Rank recipes by a weighted score combining:
 * - Rating (40%): the actual star rating
 * - Review count (40%): log-scaled so 1000 reviews isn't 10x better than 100
 * - Domain authority (20%): trusted publishers rank higher
 *
 * Returns the recipes sorted descending with the `score` field populated.
 */
export function rankRecipes(recipes: Recipe[]): Recipe[] {
  const withScores = recipes.map((recipe) => ({
    ...recipe,
    score: computeScore(recipe),
  }));

  return withScores.sort((a, b) => b.score - a.score);
}

function computeScore(recipe: Recipe): number {
  const ratingValue = recipe.rating.value;
  const reviewCount = recipe.rating.count;

  // Unrated recipes get a neutral default so they don't always lose
  const ratingScore = ratingValue > 0 ? ratingValue / 5 : 0.6;

  // Log-scale review count: log10(0+1)=0, log10(99+1)=2, log10(999+1)=3, log10(9999+1)=4
  const reviewScore = Math.min(Math.log10(reviewCount + 1) / 4, 1);

  const authorityScore = recipe.source.authority / 100;

  return ratingScore * 0.4 + reviewScore * 0.4 + authorityScore * 0.2;
}

/**
 * Elite filter: only the BEST versions of a recipe make it through.
 * A recipe qualifies if ANY of these is true:
 *   - It's from a top-tier publisher (NYT, Serious Eats, BBC etc, authority ≥ 90)
 *   - It has 4.5+ stars AND 50+ reviews
 *   - It has 4.3+ stars AND 500+ reviews (mass-validated)
 */
export function isElite(recipe: Recipe): boolean {
  if (!recipe.image) return false;
  if (recipe.ingredients.length === 0) return false;
  if (recipe.instructions.length === 0) return false;

  const r = recipe.rating;
  const isTopTier = recipe.source.authority >= 90;
  if (isTopTier) return true;

  const goodAndPopular = r.value >= 4.5 && r.count >= 50;
  if (goodAndPopular) return true;

  const massValidated = r.value >= 4.3 && r.count >= 500;
  if (massValidated) return true;

  return false;
}

/**
 * Looser quality filter for fallback when no elite results exist.
 * Still requires image, ingredients, instructions, and at least a
 * decent rating if rated.
 */
export function isGoodQuality(recipe: Recipe): boolean {
  if (!recipe.image) return false;
  if (recipe.ingredients.length === 0) return false;
  if (recipe.instructions.length === 0) return false;
  if (recipe.rating.value > 0 && recipe.rating.value < 4.0) return false;
  return true;
}

/**
 * Minimum bar — only requires image and structured ingredients/instructions.
 * Last resort fallback so we don't return zero results for obscure queries.
 */
export function isMinimumBar(recipe: Recipe): boolean {
  if (!recipe.image) return false;
  if (recipe.ingredients.length === 0) return false;
  if (recipe.instructions.length === 0) return false;
  return true;
}

/**
 * Cascade-rank: try elite first, fall back to good, then minimum bar.
 * Returns at most `limit` results, prioritizing the highest tier that
 * has at least 1 result.
 */
export function eliteRank(recipes: Recipe[], limit: number): Recipe[] {
  const elite = recipes.filter(isElite);
  if (elite.length >= 1) {
    return rankRecipes(elite).slice(0, limit);
  }
  const good = recipes.filter(isGoodQuality);
  if (good.length >= 1) {
    return rankRecipes(good).slice(0, limit);
  }
  const minBar = recipes.filter(isMinimumBar);
  return rankRecipes(minBar).slice(0, limit);
}

/**
 * @deprecated Use eliteRank() — this just delegates to keep callers working.
 */
export function filterQuality(
  recipes: Recipe[],
  options: { minRating?: number; minImage?: boolean } = {},
): Recipe[] {
  const { minRating = 0, minImage = true } = options;
  return recipes.filter((r) => {
    if (minImage && !r.image) return false;
    if (r.rating.value > 0 && r.rating.value < minRating) return false;
    if (r.ingredients.length === 0) return false;
    if (r.instructions.length === 0) return false;
    return true;
  });
}
