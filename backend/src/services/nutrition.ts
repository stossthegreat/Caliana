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

const PHOTO_SYSTEM = `You are a food vision analyst. You see a photo and identify exactly what is in it, then estimate calories and macros.

Respond with JSON only — exactly this shape, nothing else:
{
  "name": "2-5 word dish name (e.g. 'pepperoni pizza slice')",
  "calories": 380,
  "protein": 6,
  "carbs": 32,
  "fat": 24,
  "confidence": "low" | "medium" | "high",
  "notes": "any assumptions about portion or hidden fats"
}

CRITICAL — read every time:
1. NEVER default to a salad. If you see cake, say cake. If you see pizza, say pizza. Salad is only the answer when you see leaves and dressing.
2. The "name" field must describe the EXACT dish you see — not "photographed meal", not "logged food". If unclear, take your best specific guess and mark confidence "low".
3. Common foods and their typical kcal — use these as anchors:
    cheesecake slice (~120g): 350-450, 4P / 30C / 25F
    glazed doughnut: 250-300, 4P / 35C / 12F
    croissant: 270-330, 6P / 30C / 17F
    chocolate brownie: 380-450, 4P / 50C / 22F
    Greggs sausage roll: 327, 9P / 25C / 22F
    pizza slice (single): 280-350, 12P / 36C / 12F
    whole 12" pepperoni pizza: ~2000, ~72P / ~210C / ~88F
    Big Mac: 550, 25P / 45C / 30F
    chicken caesar (full meal): 500-650, 35P / 25C / 38F
    grilled salmon + salad: 400-500, 36P / 12C / 24F
    bowl of pasta + sauce: 500-700, 18P / 80C / 18F
    full English breakfast: 800-1100, 40P / 60C / 60F
    bowl of cereal + milk: 250-350, 8P / 50C / 6F
4. For multi-item plates, sum components into one entry.
5. Hidden fats (oil, butter, dressing) are the #1 underestimation source. Assume them; flag in notes.
6. If portion is hard to gauge, default to ONE typical serving — never half, never double.
7. Macros must roughly satisfy P*4 + C*4 + F*9 within 15% of total kcal.
8. Round calories to nearest 10. Macros to nearest 1g.
9. Confidence:
   - HIGH: dish is unambiguous AND portion visible
   - MEDIUM: dish known, portion ambiguous OR hidden ingredients
   - LOW: blurry / mixed plate / can barely tell what it is`;

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
    ? `Hint from the user: ${hint.trim()}\n\nLook at the photo carefully. Identify the dish, then estimate. Don't return "salad" unless you actually see leaves and dressing. Return JSON only.`
    : `Look at the photo carefully. Identify the EXACT dish — pizza, cheesecake, pasta, omelette, whatever it is. Then estimate kcal and macros. Don't default to a salad estimate just because the portion looks small. Return JSON only.`;

  const response = await getOpenAI().chat.completions.create({
    model: visionModel,
    messages: [
      { role: 'system', content: PHOTO_SYSTEM },
      {
        role: 'user',
        content: [
          { type: 'text', text: userMessage },
          {
            type: 'image_url',
            image_url: { url: imageDataUrl, detail: 'high' },
          },
        ],
      },
    ],
    temperature: 0.15,
    max_tokens: 400,
    response_format: { type: 'json_object' },
  });
  const raw = response.choices[0]?.message?.content || '{}';
  let parsed: unknown = {};
  try {
    parsed = JSON.parse(raw);
  } catch {
    // Last-ditch: scan for the first {...} block in the raw text.
    const start = raw.indexOf('{');
    const end = raw.lastIndexOf('}');
    if (start !== -1 && end !== -1 && end > start) {
      try {
        parsed = JSON.parse(raw.slice(start, end + 1));
      } catch {
        parsed = {};
      }
    }
  }
  return normalize(parsed, hint || 'photographed meal');
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
