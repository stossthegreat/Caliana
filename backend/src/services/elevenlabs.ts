import { config } from '../config.js';

export type Tone = 'polite' | 'cheeky' | 'savage';

/**
 * Pick the right voice for the requested tone — each character has its
 * own ElevenLabs voice so Polite, Cheeky and Savage actually sound like
 * different facets of Caliana, not the same line read three ways. Falls
 * back to the generic ELEVENLABS_VOICE_ID if a per-tone ID isn't set.
 */
function voiceIdFor(tone: Tone | undefined): string {
  const fallback = config.elevenLabsVoiceId;
  switch (tone) {
    case 'polite':
      return config.elevenLabsVoiceIdPolite || fallback;
    case 'savage':
      return config.elevenLabsVoiceIdSavage || fallback;
    case 'cheeky':
      return config.elevenLabsVoiceIdCheeky || fallback;
    default:
      return fallback;
  }
}

/**
 * Tune voice settings per tone. Polite reads softer (lower style),
 * Cheeky is the lively default, Savage edges up the style/stability for
 * deadpan delivery.
 */
function settingsFor(tone: Tone | undefined) {
  switch (tone) {
    case 'polite':
      return { stability: 0.55, similarity_boost: 0.78, style: 0.20 };
    case 'savage':
      return { stability: 0.50, similarity_boost: 0.75, style: 0.55 };
    case 'cheeky':
    default:
      return { stability: 0.45, similarity_boost: 0.75, style: 0.40 };
  }
}

/**
 * Synthesise speech with ElevenLabs and return raw audio bytes (mp3).
 * The route streams these to the client which plays via audioplayers.
 *
 * Defaults: Lily (British female, young) voice, eleven_turbo_v2_5 model
 * (low latency for chat). All overrideable via env or per-call args.
 */
export async function synthesize(
  text: string,
  options?: { voiceId?: string; modelId?: string; tone?: Tone },
): Promise<Buffer> {
  if (!config.elevenLabsApiKey) {
    throw new Error('ELEVENLABS_API_KEY is not set');
  }
  const voiceId = options?.voiceId || voiceIdFor(options?.tone);
  const modelId = options?.modelId || config.elevenLabsModel;
  const settings = settingsFor(options?.tone);

  const url = `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`;
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'xi-api-key': config.elevenLabsApiKey,
      'Content-Type': 'application/json',
      Accept: 'audio/mpeg',
    },
    body: JSON.stringify({
      text,
      model_id: modelId,
      voice_settings: {
        ...settings,
        use_speaker_boost: true,
      },
    }),
  });

  if (!res.ok) {
    const body = await res.text().catch(() => '');
    throw new Error(
      `ElevenLabs ${res.status}: ${body.slice(0, 250)}`,
    );
  }

  const ab = await res.arrayBuffer();
  return Buffer.from(ab);
}
