import type { FastifyInstance } from 'fastify';
import { config } from '../config.js';
import { getOpenAI } from '../services/openai_client.js';

interface PlanRequest {
  /** Total daily kcal target (BMR + activity, after deficit if any). */
  dailyCalorieGoal: number;
  /** Daily protein target in grams. */
  dailyProteinGoal?: number;
  /** Free-form user profile context (diet, allergies, dislikes). */
  userContext?: string;
  /** Tone preference — 'soft' / 'cheeky' / 'savage'. Influences blurb. */
  tone?: 'polite' | 'cheeky' | 'savage';
  /** Mode hint — 'normal' | 'recovery' | 'high_protein' | 'cheap' | 'busy' | 'cut' | 'maintain'. */
  mode?: string;
  /** Override the per-day kcal target (e.g. dailyGoal - todayOverage to
   *  absorb a previous day's spillover across the plan). When set, the
   *  plan distributes against this number instead of dailyCalorieGoal. */
  targetKcalOverride?: number;
  /** Number of kcal yesterday/today went over goal — surfaces in the
   *  rebalance reasoning so the plan explicitly absorbs it. */
  absorbingDeltaKcal?: number;
}

interface PlannedSlot {
  slot: 'breakfast' | 'lunch' | 'dinner' | 'snack';
  name: string;
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
  ingredients: string[];
  steps: string[];
  imageUrl: string;
}

/**
 * POST /api/plan-day
 *
 * Generates a 4-slot day plan (breakfast, lunch, dinner, snack) that
 * sums to roughly the user's daily kcal goal and at least the protein
 * target. Each slot ships with single-portion ingredients, 3-5 steps,
 * and a stock food image so the Plan tab can render proper cards
 * straight away.
 */
export async function registerPlanDayRoute(
  app: FastifyInstance,
): Promise<void> {
  app.post<{ Body: PlanRequest }>('/api/plan-day', async (req, reply) => {
    const {
      dailyCalorieGoal,
      dailyProteinGoal,
      userContext,
      mode,
      targetKcalOverride,
      absorbingDeltaKcal,
    } = req.body || ({} as PlanRequest);

    if (!dailyCalorieGoal || dailyCalorieGoal < 600) {
      return reply
        .status(400)
        .send({ error: 'dailyCalorieGoal is required (>= 600)' });
    }

    // Resolve the actual kcal target for distribution. Clamp to a safe
    // floor (1200) so a big overage never produces a starvation plan.
    const resolvedTarget = (() => {
      if (
        typeof targetKcalOverride === 'number' &&
        targetKcalOverride >= 600
      ) {
        return Math.max(1200, Math.round(targetKcalOverride));
      }
      return dailyCalorieGoal;
    })();

    try {
      const slots = await generateDayPlan(
        resolvedTarget,
        dailyProteinGoal,
        userContext,
        mode,
        absorbingDeltaKcal,
      );
      return {
        slots,
        targetKcal: resolvedTarget,
        absorbingDeltaKcal: absorbingDeltaKcal ?? 0,
      };
    } catch (err) {
      req.log.error({ err }, 'plan-day failed');
      return reply.status(500).send({
        error: 'plan failed',
        message: err instanceof Error ? err.message : String(err),
      });
    }
  });
}

async function generateDayPlan(
  dailyCalorieGoal: number,
  dailyProteinGoal: number | undefined,
  userContext: string | undefined,
  mode: string | undefined,
  absorbingDeltaKcal: number | undefined,
): Promise<PlannedSlot[]> {
  // Distribute the daily kcal across slots: 25 / 35 / 30 / 10.
  const breakfastTarget = Math.round(dailyCalorieGoal * 0.25);
  const lunchTarget = Math.round(dailyCalorieGoal * 0.35);
  const dinnerTarget = Math.round(dailyCalorieGoal * 0.30);
  const snackTarget = Math.round(dailyCalorieGoal * 0.10);

  const proteinTarget = dailyProteinGoal && dailyProteinGoal > 0
    ? `Hit at least ${dailyProteinGoal}g protein for the day.`
    : 'Hit a sensible protein total for the day (~0.8g/lb body weight).';

  const modeLine = (() => {
    switch (mode) {
      case 'recovery':
        return 'MODE: recovery — yesterday went heavy. Lean protein, more veg, less salt, no fried, steady carbs. Calm food, clean hit.';
      case 'high_protein':
        return 'MODE: high-protein push. Every slot anchors on a protein source (chicken / salmon / tuna / eggs / Greek yog / lentils / tofu). Aim 30g+ per slot.';
      case 'cheap':
        return 'MODE: cheap week. Eggs, oats, tinned tuna, lentils, frozen veg, mince. Real food, low spend.';
      case 'busy':
        return 'MODE: busy week. <20 min cook time per meal. Sheet pans, one-pan, microwaveable.';
      case 'cut':
        return 'MODE: cut week. Higher protein, lower fat, lower-carb-density choices. Volume eating: leafy greens, eggs, lean meat, low-cal noodles. Still sating, still real food, no crash dieting.';
      case 'maintain':
        return 'MODE: maintain — balanced macros, varied protein sources, no extremes. Just steady, normal eating.';
      default:
        return 'MODE: normal — balanced, satisfying, varied.';
    }
  })();

  const rebalanceLine =
    absorbingDeltaKcal && absorbingDeltaKcal > 0
      ? `REBALANCE: this plan absorbs ${absorbingDeltaKcal} kcal of overage from a prior day. The kcal target above (${dailyCalorieGoal}) is ALREADY adjusted for that. Do not cut further. Aim filling, satiating meals so the lower number doesn't trigger hunger spirals.`
      : '';

  const system = `You are CALIANA, a British nutritionist. Generate ONE day of meals — breakfast, lunch, dinner, snack — that hit the user's targets and sound like food a real adult would actually eat.

${modeLine}
${rebalanceLine}

OUTPUT — JSON only, exactly this shape:
{
  "slots": [
    {
      "slot": "breakfast",
      "name": "3-5 word dish name",
      "calories": 480,
      "protein": 32,
      "carbs": 40,
      "fat": 18,
      "ingredients": ["...", "..."],
      "steps": ["...", "..."],
      "imageQuery": "1-3 word dish description for stock image"
    },
    { "slot": "lunch", ... },
    { "slot": "dinner", ... },
    { "slot": "snack", ... }
  ]
}

RULES:
- 4 slots in this order: breakfast, lunch, dinner, snack.
- Calories per slot:
    breakfast ≈ ${breakfastTarget} kcal
    lunch ≈ ${lunchTarget} kcal
    dinner ≈ ${dinnerTarget} kcal
    snack ≈ ${snackTarget} kcal
  Total of all four = ${dailyCalorieGoal} kcal ± 5%.
- ${proteinTarget}
- Each slot: real, common dish names — never invented fusion. UK measurements where natural.
- 5-8 ingredient lines per slot, FOR ONE PORTION, with quantities.
- 3-5 short imperative steps per slot.
- Macros must roughly satisfy P*4 + C*4 + F*9 within 15% of slot kcal.
- imageQuery: 1-3 lowercase words for stock image search (no commas).
- No repeating the same protein across all four slots.
- Round calories to nearest 10. Macros to 1g.`;

  const user = userContext ? `USER: ${userContext}` : '(no profile)';

  const response = await getOpenAI().chat.completions.create({
    model: config.openaiModel,
    messages: [
      { role: 'system', content: system },
      { role: 'user', content: user },
    ],
    temperature: 0.55,
    max_tokens: 1500,
    response_format: { type: 'json_object' },
  });

  const raw = response.choices[0]?.message?.content || '{"slots":[]}';
  let parsed: { slots?: Array<Partial<PlannedSlot> & { imageQuery?: string }> };
  try {
    parsed = JSON.parse(raw);
  } catch {
    return [];
  }
  if (!parsed.slots || !Array.isArray(parsed.slots)) return [];

  const wantSlots: Array<'breakfast' | 'lunch' | 'dinner' | 'snack'> = [
    'breakfast',
    'lunch',
    'dinner',
    'snack',
  ];
  const out: PlannedSlot[] = [];
  for (const slot of wantSlots) {
    const found = parsed.slots.find((s) => s.slot === slot);
    if (!found) continue;
    const imageQuery =
      (found.imageQuery && String(found.imageQuery).trim()) ||
      String(found.name || slot);
    out.push({
      slot,
      name: String(found.name || slot),
      calories: clampInt(found.calories, 0, 2000),
      protein: clampInt(found.protein, 0, 200),
      carbs: clampInt(found.carbs, 0, 300),
      fat: clampInt(found.fat, 0, 200),
      ingredients: cleanStringList(found.ingredients, 8),
      steps: cleanStringList(found.steps, 6),
      imageUrl: `https://loremflickr.com/640/480/${encodeURIComponent(
        imageQuery.toLowerCase().replace(/\s+/g, ','),
      )}/?lock=${Date.now()}-${slot}`,
    });
  }
  return out;
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
