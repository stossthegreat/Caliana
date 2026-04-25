/**
 * The canonical shape of a recipe returned to the Flutter app.
 * Anything the backend extracts from JSON-LD or generates with an LLM
 * gets normalized into this before going over the wire.
 */
export interface Recipe {
  id: string; // stable hash of the source URL
  title: string;
  description: string;
  image: string; // high-res URL
  source: {
    domain: string; // "cooking.nytimes.com"
    name: string; // "NYT Cooking"
    url: string; // original recipe URL
    authority: number; // 0–100, used for elite ranking
  };
  rating: {
    value: number; // 0–5
    count: number; // number of reviews
  };
  time: {
    prep: number | null; // minutes
    cook: number | null;
    total: number | null;
    display: string; // "45 min"
  };
  servings: number | null;
  ingredients: string[]; // raw ingredient strings
  instructions: string[]; // step-by-step
  nutrition?: {
    calories?: number;
    protein?: string;
    carbs?: string;
    fat?: string;
  };
  // Ranking metadata — useful for the client to display proof
  score: number;
}

/** The payload Flutter sends when searching */
export interface SearchRequest {
  query: string;
  userContext?: string; // serialized user profile
}

/** The payload Flutter gets back */
export interface SearchResponse {
  query: string;
  results: Recipe[];
  durationMs: number;
  cached: boolean;
}

/** Raw JSON-LD Recipe object (schema.org/Recipe) — what we parse from HTML */
export interface JsonLdRecipe {
  '@type'?: string | string[];
  name?: string;
  description?: string;
  image?: string | string[] | { url?: string };
  author?: { name?: string } | { name?: string }[] | string;
  datePublished?: string;
  recipeYield?: string | number | string[];
  prepTime?: string;
  cookTime?: string;
  totalTime?: string;
  recipeIngredient?: string[];
  recipeInstructions?:
    | string
    | string[]
    | { text?: string; name?: string }[];
  aggregateRating?: {
    ratingValue?: number | string;
    ratingCount?: number | string;
    reviewCount?: number | string;
  };
  nutrition?: {
    calories?: string;
    proteinContent?: string;
    carbohydrateContent?: string;
    fatContent?: string;
  };
}
