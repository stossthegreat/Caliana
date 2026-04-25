import OpenAI from 'openai';
import { config, assertKeysConfigured } from '../config.js';

let _client: OpenAI | null = null;
function getClient(): OpenAI {
  assertKeysConfigured();
  if (!_client) {
    _client = new OpenAI({ apiKey: config.openaiApiKey });
  }
  return _client;
}

/**
 * Normalize a raw user query into a web-search-friendly phrase.
 * "I want something cozy for a rainy day" → "cozy comfort food recipes"
 */
export async function normalizeQuery(query: string, userContext?: string): Promise<string> {
  const systemPrompt = `You convert casual user food requests into concise web search queries optimized for finding the BEST, HIGHEST-RATED versions of a recipe on cooking websites.

Rules:
- Output ONLY the search query, nothing else. No quotes, no explanation.
- Keep it 3-7 words
- Include the word "recipe" naturally
- Bias toward popularity signals like "best", "perfect", "ultimate" when natural
- When a celebrity chef has a definitive version of a dish, prefer their name
  (e.g. "Gordon Ramsay scrambled eggs", "Ina Garten roast chicken")
- Respect the user's context (allergies, diet, dislikes) — never suggest things they can't eat
- Prefer specific iconic dish names over vague descriptions
- Remove first-person phrasing ("I want", "give me")

Examples:
Input: "I want mac and cheese" → "best mac and cheese recipe"
Input: "scrambled eggs" → "Gordon Ramsay scrambled eggs"
Input: "carbonara" → "best pasta carbonara recipe"
Input: "something cozy for winter" → "best winter comfort food recipes"
Input: "quick dinner" → "best quick weeknight dinner recipes"
Input: "impress my date" → "best date night dinner recipes"`;

  const userMessage = userContext
    ? `User context:\n${userContext}\n\nUser request: ${query}`
    : query;

  const response = await getClient().chat.completions.create({
    model: config.openaiModel,
    messages: [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: userMessage },
    ],
    temperature: 0.3,
    max_tokens: 30,
  });

  const normalized = response.choices[0]?.message?.content?.trim() || query;
  return normalized.replace(/^["']|["']$/g, ''); // strip surrounding quotes
}

/**
 * Generate a meal plan covering 1–7 days as specific dish names.
 * Returns an object with the structure: { Mon: { Breakfast, Lunch, Dinner }, ... }
 *
 * The dish names are biased toward HIGHLY-RATED, established, recognizable
 * recipes — celebrity chef names where appropriate (e.g., "Gordon Ramsay
 * scrambled eggs", "Ina Garten roast chicken") so the downstream search
 * pulls back elite, well-known versions.
 */
export async function generateWeekPlan(
  request: string,
  userContext?: string,
  days: number = 7,
): Promise<Record<string, Record<string, string>>> {
  const dayCount = Math.max(1, Math.min(7, days));
  const allDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const targetDays = allDays.slice(0, dayCount);
  const targetDaysList = targetDays.map((d) => `"${d}"`).join(', ');

  const systemPrompt = `You are a meal planning expert. Generate a ${dayCount}-day meal plan with ${dayCount * 3} specific dish names (one for each breakfast, lunch, and dinner across ${dayCount} days).

CRITICAL RULES:
- Return ONLY valid JSON, no markdown, no explanation
- Each dish MUST be a SIMPLE, COMMON recipe name that will definitely be found on AllRecipes, NYT Cooking, BBC Good Food, or similar major cooking websites
- Use PLAIN dish names like "chicken stir fry", "banana pancakes", "greek salad", "spaghetti bolognese", "overnight oats"
- Do NOT use obscure, creative, or overly specific names that might not have a recipe page online
- Do NOT include chef names — just the dish itself
- Respect user allergies, diet, and dislikes STRICTLY
- If the user context mentions household size, choose recipes that naturally serve that many people. For example, household of 1 = single-serving dishes, household of 4 = family-sized recipes
- Vary cuisines, proteins, and cooking styles across the days
- Keep dishes realistic for the user's skill level and time preference
- NEVER invent fusion dishes or made-up combinations

Output keys must use exactly: ${targetDaysList}
Each day must have exactly "Breakfast", "Lunch", "Dinner" keys.

Return format:
{
  "Mon": {"Breakfast": "...", "Lunch": "...", "Dinner": "..."},
  ...
}`;

  const userMessage = userContext
    ? `User context:\n${userContext}\n\nUser request: ${request}`
    : request;

  const response = await getClient().chat.completions.create({
    model: config.openaiModel,
    messages: [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: userMessage },
    ],
    temperature: 0.7,
    max_tokens: 800,
    response_format: { type: 'json_object' },
  });

  const content = response.choices[0]?.message?.content || '{}';
  try {
    return JSON.parse(content);
  } catch {
    throw new Error('GPT returned invalid JSON for meal plan');
  }
}

/**
 * Fallback HTML parser — when a page has no JSON-LD, ask GPT to extract the recipe.
 * Expensive compared to JSON-LD parsing, so only use for top candidates.
 */
export async function extractRecipeFromHtmlWithLlm(
  html: string,
  sourceUrl: string,
): Promise<unknown | null> {
  // Strip HTML to roughly 4000 chars of visible text
  const cleaned = html
    .replace(/<script[\s\S]*?<\/script>/gi, '')
    .replace(/<style[\s\S]*?<\/style>/gi, '')
    .replace(/<[^>]+>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, 6000);

  const response = await getClient().chat.completions.create({
    model: config.openaiModel,
    messages: [
      {
        role: 'system',
        content: `Extract the recipe from the given webpage text. Return JSON only:
{
  "name": "...",
  "description": "...",
  "image": "",
  "recipeIngredient": ["..."],
  "recipeInstructions": ["step 1", "step 2"],
  "prepTime": "PT15M",
  "cookTime": "PT30M",
  "recipeYield": "4 servings"
}
If the page is not a recipe, return null.`,
      },
      { role: 'user', content: `URL: ${sourceUrl}\n\nText:\n${cleaned}` },
    ],
    temperature: 0.1,
    max_tokens: 1200,
    response_format: { type: 'json_object' },
  });

  const content = response.choices[0]?.message?.content || 'null';
  try {
    const parsed = JSON.parse(content);
    if (!parsed || !parsed.name) return null;
    return parsed;
  } catch {
    return null;
  }
}
