import { config } from '../config.js';
import { getOpenAI } from './openai_client.js';

export interface FoodEntryDraft {
  name: string;
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
  confidence: 'low' | 'medium' | 'high';
  notes: string;
}

const TEXT_SYSTEM = `You parse a user's text or transcribed speech into a SINGLE food log entry with realistic calorie + macro estimates.

Return JSON only — no prose:
{
  "name": "concise food name (2-5 words, never a sentence)",
  "calories": 350,
  "protein": 18,
  "carbs": 35,
  "fat": 14,
  "confidence": "low" | "medium" | "high",
  "notes": ""
}

NAME RULES — STRICT:
- "name" must be a SHORT dish label, never a sentence and never the user's words.
- Strip emotion, filler, complaints, and self-talk. The user can ramble; you don't.
- Maximum 5 words. Title case. No trailing punctuation.
- Examples:
  - "Oh my god I messed up I had three burgers" -> "3 burgers"
  - "fml ate a whole pizza by myself" -> "Whole pizza"
  - "Just had a chicken caesar" -> "Chicken caesar salad"
  - "literally just three black coffees" -> "3 black coffees"
- If the user mentions multiple distinct foods, sum into one entry and name it
  generically (e.g. "Lunch combo", "Pub meal").

CONFIDENCE RULES:
- HIGH: clear single food + known portion ("medium banana", "200g chicken breast")
- MEDIUM: known dish but portion ambiguous ("had a burger", "chicken sandwich")
- LOW: complex/mixed dish or vague description ("had lunch", "snack")

ESTIMATION RULES — accuracy matters, the user trusts these numbers:
- Default to UK serving sizes when the description is in British English ("a pint", "a bag of crisps", "a Greggs sausage roll", "a flat white"). US sizes when American context.
- For chain foods, use the chain's actual nutrition data when known
  (e.g. McDonald's Big Mac = 550 kcal, Greggs sausage roll = 327 kcal,
  Pret tuna baguette ≈ 520 kcal). Don't guess wildly.
- If the user gives weight/volume ("200g rice", "500ml beer"), use that exactly.
- For ambiguous items, choose the COMMON/MEDIUM portion (a "coffee" = ~120 kcal latte, not a black filter). Mention the assumption in notes.
- Sum components for mixed dishes (a sandwich = bread + filling + mayo + cheese if implied).
- Hidden fats are the #1 underestimation source — assume cooking oil for fried/sauteed items, dressing for salads, butter for toast, unless the user says otherwise. Add to fat estimate, mention in notes.
- Drinks count: latte ≈ 120, cappuccino ≈ 80, oat milk latte ≈ 160, pint of lager ≈ 200, glass of wine ≈ 130.
- Round calories to nearest 10, macros to nearest 1g.
- Macros must roughly add up: protein*4 + carbs*4 + fat*9 should be within 15% of the calorie total. Re-check before returning.
- Never return zero everywhere — if the user says they ate something, estimate.`;

const PHOTO_SYSTEM = `You see a photo of food and parse it into a SINGLE log entry with realistic estimates.

Return JSON only:
{
  "name": "...",
  "calories": ...,
  "protein": ...,
  "carbs": ...,
  "fat": ...,
  "confidence": "low" | "medium" | "high",
  "notes": ""
}

CONFIDENCE RULES:
- HIGH: clearly identifiable dish + visible portion + plain ingredients
- MEDIUM: known dish but hidden ingredients (oils, sauces, dressings — flag in notes)
- LOW: mixed dish, unclear portion, multiple unknowns

ESTIMATION RULES:
- If the plate has multiple distinct foods, sum them into one entry.
- Hidden fats are the #1 error source — if you suspect oil/butter/dressing, ASSUME it
  and add it to the fat estimate, then mention in notes (e.g. "assumed 1 tbsp oil").
- Use a reasonable plate-size assumption (~10-inch dinner plate) when no scale
  reference is visible.
- Round calories to nearest 10.
- Be honest about uncertainty in notes.`;

/**
 * Parse text or transcribed speech into a single FoodEntry estimate.
 */
export async function parseFromText(text: string): Promise<FoodEntryDraft> {
  const response = await getOpenAI().chat.completions.create({
    model: config.openaiModel,
    messages: [
      { role: 'system', content: TEXT_SYSTEM },
      { role: 'user', content: text },
    ],
    temperature: 0.2,
    max_tokens: 250,
    response_format: { type: 'json_object' },
  });
  const raw = response.choices[0]?.message?.content || '{}';
  return normalize(JSON.parse(raw), text);
}

/**
 * Parse a base64-encoded image (data URL) into a single FoodEntry estimate
 * via GPT-4o vision. The hint is appended to help disambiguate.
 */
export async function parseFromPhoto(
  imageDataUrl: string,
  hint: string,
): Promise<FoodEntryDraft> {
  // Vision always uses gpt-4o regardless of the configured chat model.
  // Older "mini" variants are text-only; relying on the env string to
  // contain "mini" silently breaks vision when the env is set to e.g.
  // gpt-3.5-turbo or any custom alias.
  const visionModel = 'gpt-4o';

  const userMessage = hint && hint.trim().length > 0
    ? `Hint from the user: ${hint.trim()}`
    : "Identify what's on the plate and estimate.";

  const response = await getOpenAI().chat.completions.create({
    model: visionModel,
    messages: [
      { role: 'system', content: PHOTO_SYSTEM },
      {
        role: 'user',
        content: [
          { type: 'text', text: userMessage },
          { type: 'image_url', image_url: { url: imageDataUrl } },
        ],
      },
    ],
    temperature: 0.2,
    max_tokens: 300,
    response_format: { type: 'json_object' },
  });
  const raw = response.choices[0]?.message?.content || '{}';
  return normalize(JSON.parse(raw), hint || 'photographed meal');
}

function normalize(parsed: unknown, fallbackName: string): FoodEntryDraft {
  const p = (parsed && typeof parsed === 'object' ? parsed : {}) as Record<string, unknown>;
  let name = typeof p.name === 'string' && p.name.trim().length > 0
    ? p.name.trim()
    : titleCase(fallbackName);
  // Belt-and-braces: never let a multi-sentence ramble through as the name.
  // Cap at 50 chars and strip anything after the first sentence boundary.
  name = name.replace(/[.!?].*$/, '').trim();
  if (name.length > 50) name = name.slice(0, 47).trimEnd() + '…';
  if (!name) name = 'Logged food';
  const calories = clampInt(p.calories, 0, 6000);
  const protein = clampInt(p.protein, 0, 500);
  const carbs = clampInt(p.carbs, 0, 800);
  const fat = clampInt(p.fat, 0, 400);
  const confidenceRaw = typeof p.confidence === 'string' ? p.confidence : 'medium';
  const confidence: 'low' | 'medium' | 'high' =
    confidenceRaw === 'low' || confidenceRaw === 'high' ? confidenceRaw : 'medium';
  const notes = typeof p.notes === 'string' ? p.notes : '';
  return { name, calories, protein, carbs, fat, confidence, notes };
}

function clampInt(v: unknown, min: number, max: number): number {
  const n = typeof v === 'number' ? v : Number(v);
  if (!Number.isFinite(n)) return 0;
  return Math.max(min, Math.min(max, Math.round(n)));
}

function titleCase(s: string): string {
  if (!s) return 'Logged food';
  return s.charAt(0).toUpperCase() + s.slice(1);
}
