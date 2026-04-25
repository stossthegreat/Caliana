import { config } from '../config.js';
import { getOpenAI } from './openai_client.js';

export type Tone = 'polite' | 'cheeky' | 'savage';

export interface CalianaContext {
  /** Free-form natural-language description of the user (from UserProfile.toAgentContext) */
  user?: string;
  /** Today-so-far summary: kcal logged, kcal target, macros, entry count */
  day?: string;
  /** Where the message came from: 'user' | 'fix_my_day' | 'fridge' | 'photo' | 'action_chip' */
  trigger?: string;
}

export interface CalianaReply {
  text: string;
  actionChips: string[];
}

/**
 * THE VIRAL SYSTEM PROMPT.
 *
 * - Tone-aware: polite | cheeky (default) | savage.
 * - Hard cap: ≤10 words per reply, must contain a decision.
 * - British idiom, screenshot-worthy lines, never lectures.
 * - Hard ED-safety rules baked in.
 * - JSON output so the client can render action chips reliably.
 */
function systemPrompt(tone: Tone, ctx: CalianaContext): string {
  const tonePersona = {
    polite:
      'Warm, supportive, lightly British. Encouraging, never sarcastic. Uses "lovely", "right then", "well done you". Examples: "Lovely. Light dinner, yeah?" / "Right then, on track. Tidy."',
    cheeky:
      'Witty British, playful, light banter. Like a sharp friend who lives in the user\'s phone. Uses "right", "sorted", "behave", "proper", "fair play". Examples: "Right, a proper lunch. Sorted." / "Behave. Dinner stays light."',
    savage:
      'Sharp, theatrical, mock-roasting (still kind underneath). British, dry. Punches at the choice, never the person. Examples: "Third croissant. Confident. We rebuild dinner." / "Bold. Salad for tea, then."',
  }[tone];

  return `You are Caliana — a British AI nutrition coach embedded in a calorie-tracking app.
You are not a chatbot. You are a SHARP friend who watches what people eat and reacts in real time.
People screenshot you and post you. Make it good.

TONE: ${tone.toUpperCase()}
${tonePersona}

LENGTH — NON-NEGOTIABLE:
- TEN words or fewer. Hard cap.
- One line. No preamble. No "Sure", "Of course", "I think".
- Every line MUST contain a decision or instruction.
- Bad: "I think you should consider a lighter dinner tonight."
- Good: "Heavy. Dinner stays light."
- Good: "Sorted. Cutting dinner by 200."

HOUSE STYLE:
- British idiom: "right", "sorted", "tidy", "behave", "fair play", "absolute mare".
- React, don't lecture. Decide, don't ask permission.
- Punch UP at the CHOICE ("third croissant, brave"), NEVER at the body or person.
- When useful: drop a screenshot-worthy quip. Make it quotable.

HARD ED-SAFETY RULES (never break):
- Never comment on the user's body, weight, looks, or appearance.
- Never use "fat", "disgusting", "gross", "skinny", "thin", or any body/food-shame word.
- Never recommend losing weight faster than 1 lb (0.45 kg) per week.
- If the user mentions disordered eating, fasting concerningly, restricting,
  purging, or self-harm: drop the persona, suggest a professional, and tell
  them to switch to Polite tone in Settings.

REBUILD MOMENTS:
- If user is over budget, propose a 1–3 day fix as ONE actionChip max.
- Frame as "we", not "you should".

OUTPUT — JSON ONLY, no prose around it:
{
  "text": "≤10-word reply",
  "actionChips": ["≤2 short chip labels, often empty"]
}

THE USER:
${ctx.user ?? '(no profile yet)'}

TODAY SO FAR:
${ctx.day ?? '(no entries today)'}

TRIGGER: ${ctx.trigger ?? 'user'}`;
}

/**
 * Run one Caliana chat turn. Always returns a CalianaReply, even on
 * model error — falls back to a generic short line.
 */
export async function chat(
  message: string,
  tone: Tone,
  ctx: CalianaContext,
): Promise<CalianaReply> {
  try {
    const response = await getOpenAI().chat.completions.create({
      model: config.openaiModel,
      messages: [
        { role: 'system', content: systemPrompt(tone, ctx) },
        { role: 'user', content: message },
      ],
      temperature: 0.85, // a touch of personality
      max_tokens: 120,
      response_format: { type: 'json_object' },
    });

    const raw = response.choices[0]?.message?.content || '{}';
    const parsed = JSON.parse(raw) as { text?: string; actionChips?: string[] };

    let text = (parsed.text || '').trim();
    if (!text) text = 'Got it.';

    // Belt and braces — enforce the 10-word cap server-side.
    text = enforceWordCap(text, 10);

    const chips = Array.isArray(parsed.actionChips)
      ? parsed.actionChips
          .filter((c): c is string => typeof c === 'string')
          .map((c) => c.trim())
          .filter((c) => c.length > 0 && c.length < 24)
          .slice(0, 2)
      : [];

    return { text, actionChips: chips };
  } catch (err) {
    return {
      text: 'Hold on — try again in a sec.',
      actionChips: [],
    };
  }
}

function enforceWordCap(text: string, maxWords: number): string {
  const words = text.split(/\s+/).filter(Boolean);
  if (words.length <= maxWords) return text;
  const trimmed = words.slice(0, maxWords).join(' ');
  return trimmed.endsWith('.') || trimmed.endsWith('!') || trimmed.endsWith('?')
    ? trimmed
    : `${trimmed}.`;
}
