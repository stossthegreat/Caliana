import type { JsonLdRecipe, Recipe } from '../types/recipe.js';
import { getDomainInfo } from '../data/domains.js';
import { createHash } from 'node:crypto';

/**
 * Extract all JSON-LD script blocks from raw HTML.
 * Handles edge cases: comments, malformed JSON, nested arrays, @graph containers.
 */
export function extractJsonLdBlocks(html: string): unknown[] {
  const blocks: unknown[] = [];
  const scriptRegex = /<script[^>]+type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi;
  let match;
  while ((match = scriptRegex.exec(html)) !== null) {
    const raw = match[1].trim();
    if (!raw) continue;
    try {
      // Some sites wrap JSON in CDATA
      const cleaned = raw.replace(/^\s*\/\*\s*<!\[CDATA\[\s*\*\/|\s*\/\*\s*\]\]>\s*\*\/\s*$/g, '');
      const parsed = JSON.parse(cleaned);
      blocks.push(parsed);
    } catch {
      // Skip malformed JSON — some sites ship broken schema
    }
  }
  return blocks;
}

/**
 * Walk a parsed JSON-LD object tree and find the first Recipe node.
 * Handles: bare Recipe, @graph arrays, nested arrays, mainEntity pattern.
 */
export function findRecipeNode(data: unknown): JsonLdRecipe | null {
  if (!data || typeof data !== 'object') return null;

  // Array at top level — scan each entry
  if (Array.isArray(data)) {
    for (const item of data) {
      const found = findRecipeNode(item);
      if (found) return found;
    }
    return null;
  }

  const obj = data as Record<string, unknown>;

  // Check @type — could be string or array
  const type = obj['@type'];
  if (type) {
    const types = Array.isArray(type) ? type : [type];
    if (types.some((t) => typeof t === 'string' && t.toLowerCase() === 'recipe')) {
      return obj as unknown as JsonLdRecipe;
    }
  }

  // @graph container — recurse into it
  if (obj['@graph']) {
    return findRecipeNode(obj['@graph']);
  }

  // mainEntity pattern
  if (obj.mainEntity) {
    return findRecipeNode(obj.mainEntity);
  }

  return null;
}

/** Parse ISO 8601 duration (PT15M, PT1H30M) into minutes */
function parseDuration(iso: string | undefined): number | null {
  if (!iso) return null;
  const match = iso.match(/^PT(?:(\d+)H)?(?:(\d+)M)?/);
  if (!match) return null;
  const hours = parseInt(match[1] || '0', 10);
  const minutes = parseInt(match[2] || '0', 10);
  const total = hours * 60 + minutes;
  return total > 0 ? total : null;
}

function formatDuration(minutes: number | null): string {
  if (!minutes) return '';
  if (minutes < 60) return `${minutes} min`;
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  return m === 0 ? `${h} hr` : `${h}h ${m}m`;
}

function extractImageUrl(image: unknown): string {
  if (!image) return '';
  if (typeof image === 'string') return image;
  if (Array.isArray(image)) {
    for (const item of image) {
      const url = extractImageUrl(item);
      if (url) return url;
    }
    return '';
  }
  if (typeof image === 'object' && image !== null) {
    const obj = image as { url?: unknown; contentUrl?: unknown };
    if (typeof obj.url === 'string') return obj.url;
    if (typeof obj.contentUrl === 'string') return obj.contentUrl;
  }
  return '';
}

function extractInstructions(instructions: JsonLdRecipe['recipeInstructions']): string[] {
  if (!instructions) return [];
  if (typeof instructions === 'string') {
    // Single long string — try to split on sentences or numbered lists
    return instructions
      .split(/(?:\n+|\.\s+(?=[A-Z]))/)
      .map((s) => s.trim())
      .filter((s) => s.length > 0);
  }
  if (Array.isArray(instructions)) {
    return instructions
      .map((step) => {
        if (typeof step === 'string') return step.trim();
        if (step && typeof step === 'object') return (step.text || step.name || '').trim();
        return '';
      })
      .filter((s) => s.length > 0);
  }
  return [];
}

function extractServings(yield_: JsonLdRecipe['recipeYield']): number | null {
  if (!yield_) return null;
  const str = Array.isArray(yield_) ? yield_[0] : String(yield_);
  const match = String(str).match(/\d+/);
  return match ? parseInt(match[0], 10) : null;
}

function extractRating(rating: JsonLdRecipe['aggregateRating']): { value: number; count: number } {
  if (!rating) return { value: 0, count: 0 };
  const value = parseFloat(String(rating.ratingValue || '0')) || 0;
  const count =
    parseInt(String(rating.ratingCount || rating.reviewCount || '0'), 10) || 0;
  return { value, count };
}

function hashUrl(url: string): string {
  return createHash('sha1').update(url).digest('hex').slice(0, 12);
}

/**
 * Normalize a raw JSON-LD Recipe object into our canonical Recipe type.
 * Returns null if critical fields are missing (no title, no ingredients).
 */
export function normalizeRecipe(
  jsonld: JsonLdRecipe,
  sourceUrl: string,
): Recipe | null {
  const title = (jsonld.name || '').trim();
  const ingredients = (jsonld.recipeIngredient || []).map((i) => i.trim()).filter(Boolean);
  const instructions = extractInstructions(jsonld.recipeInstructions);

  // Reject if it's not actually a usable recipe
  if (!title || ingredients.length === 0 || instructions.length === 0) {
    return null;
  }

  const image = extractImageUrl(jsonld.image);
  const domainInfo = getDomainInfo(sourceUrl);
  const rating = extractRating(jsonld.aggregateRating);

  const prep = parseDuration(jsonld.prepTime);
  const cook = parseDuration(jsonld.cookTime);
  const total = parseDuration(jsonld.totalTime) || (prep && cook ? prep + cook : prep || cook);

  return {
    id: hashUrl(sourceUrl),
    title,
    description: (jsonld.description || '').trim().slice(0, 500),
    image,
    source: {
      domain: domainInfo.domain,
      name: domainInfo.name,
      url: sourceUrl,
      authority: domainInfo.authority,
    },
    rating,
    time: {
      prep,
      cook,
      total,
      display: formatDuration(total),
    },
    servings: extractServings(jsonld.recipeYield),
    ingredients,
    instructions,
    nutrition: jsonld.nutrition
      ? {
          calories: jsonld.nutrition.calories
            ? parseInt(String(jsonld.nutrition.calories).replace(/\D/g, ''), 10)
            : undefined,
          protein: jsonld.nutrition.proteinContent,
          carbs: jsonld.nutrition.carbohydrateContent,
          fat: jsonld.nutrition.fatContent,
        }
      : undefined,
    score: 0, // filled in by ranker
  };
}

/**
 * Full pipeline: HTML → Recipe. Returns null if extraction fails.
 */
export function extractRecipeFromHtml(html: string, sourceUrl: string): Recipe | null {
  const blocks = extractJsonLdBlocks(html);
  for (const block of blocks) {
    const node = findRecipeNode(block);
    if (node) {
      const recipe = normalizeRecipe(node, sourceUrl);
      if (recipe) return recipe;
    }
  }
  return null;
}
