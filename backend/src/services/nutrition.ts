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

const PHOTO_SYSTEM = `You are a food vision analyst. You see a photo and identify exactly what's in it, then estimate calories and macros.

ANSWER FORMAT — respond with TWO sections, in order:

## Identification
One sentence describing exactly what you see in the photo. Be specific: "A slice of New York-style cheesecake with strawberry topping on a white plate" or "Two pepperoni pizza slices" or "A chicken caesar salad in a bowl". If you genuinely cannot identify the dish, say so.

## JSON
\`\`\`json
{
  "name": "2-5 word dish name",
  "calories": 380,
  "protein": 6,
  "carbs": 32,
  "fat": 24,
  "confidence": "low" | "medium" | "high",
  "notes": "any assumptions about portion or hidden fats"
}
\`\`\`

CRITICAL RULES — read every time:
1. NEVER default to a salad estimate. If you see cake, say cake. If you see pizza, say pizza. Salad is only the answer when you see leaves and dressing.
2. Identify FIRST in plain English (## Identification section). Then estimate. The estimate must match what you described.
3. Common foods and their typical kcal — use these as anchors:
    cheesecake slice (~120g): 350-450 kcal, 4P / 30C / 25F
    glazed doughnut: 250-300, 4P / 35C / 12F
    croissant: 270-330, 6P / 30C / 17F
    Greggs sausage roll: 327, 9P / 25C / 22F
    chocolate brownie: 380-450, 4P / 50C / 22F
    pizza slice (1): 280-350, 12P / 36C / 12F
    pepperoni pizza (whole 12"): ~2000, ~72P / ~210C / ~88F
    Big Mac: 550, 25P / 45C / 30F
    chicken caesar (full): 500-650, 35P / 25C / 38F
    grilled salmon + salad: 400-500, 36P / 12C / 24F
    bowl of pasta + sauce: 500-700, 18P / 80C / 18F
    full English breakfast: 800-1100, 40P / 60C / 60F
4. Multi-item plates → sum components.
5. Hidden fats (oil, butter, dressing) are the #1 underestimation source. Assume them; note them.
6. If camera is too close to gauge portion, default to ONE typical serving — never half, never double.
7. Macros must roughly satisfy P*4 + C*4 + F*9 within 15% of total kcal. Re-check before answering.
8. Round calories to nearest 10. Macros to nearest 1g.
9. Confidence:
   - HIGH: clearly identifiable + visible portion
   - MEDIUM: known dish, ambiguous portion or hidden ingredients
   - LOW: mixed plate / blurry / unclear`;

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
    ? `Hint from the user: ${hint.trim()}\n\nLook at the photo carefully. First describe what you see in plain English under "## Identification", then return JSON under "## JSON". Don't default to a salad — name the actual food.`
    : `Look at the photo carefully. First describe what you see in plain English under "## Identification" (be specific: "two pepperoni pizza slices", "a slice of cheesecake", etc). Then return JSON under "## JSON". Don't default to a salad estimate just because the portion looks small.`;

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
            image_url: {
              url: imageDataUrl,
              // Force high detail so GPT-4o actually parses the image
              // pixels properly. Default 'auto' picks 'low' for
              // compact uploads, which is why pizzas were coming back
              // as salads.
              detail: 'high',
            },
          },
        ],
      },
    ],
    temperature: 0.15,
    max_tokens: 500,
    // NOTE: do NOT set response_format: json_object here. Forcing JSON
    // mode noticeably degrades GPT-4o vision — the model spends its
    // budget on schema compliance instead of pixel reading. We let it
    // think in plain English first (## Identification), then parse the
    // ## JSON block out of the response below.
  });
  const raw = response.choices[0]?.message?.content || '';
  return normalize(extractJsonFromMarkdown(raw), hint || 'photographed meal');
}

/**
 * Pull the JSON object out of a vision response that uses our
 * "## Identification ... ## JSON ```json {...}``` " template. Falls
 * back to scanning for the first {...} block in the raw text. If
 * nothing parses, returns {} so normalize() lands on safe defaults.
 */
function extractJsonFromMarkdown(raw: string): unknown {
  if (!raw) return {};
  // Look for a fenced ```json ... ``` block first (preferred).
  const fenceMatch = raw.match(/```\s*json\s*([\s\S]*?)```/i);
  if (fenceMatch) {
    try {
      return JSON.parse(fenceMatch[1].trim());
    } catch {
      // fall through
    }
  }
  // Generic fenced block.
  const anyFence = raw.match(/```\s*([\s\S]*?)```/);
  if (anyFence) {
    try {
      return JSON.parse(anyFence[1].trim());
    } catch {
      // fall through
    }
  }
  // First-bracket scan as last resort.
  const start = raw.indexOf('{');
  const end = raw.lastIndexOf('}');
  if (start !== -1 && end !== -1 && end > start) {
    try {
      return JSON.parse(raw.slice(start, end + 1));
    } catch {
      // fall through
    }
  }
  return {};
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
