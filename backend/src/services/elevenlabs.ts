import { config } from '../config.js';

/**
 * Synthesise speech with ElevenLabs and return raw audio bytes (mp3).
 * The route streams these to the client which plays via audioplayers.
 *
 * Defaults: Lily (British female, young) voice, eleven_turbo_v2_5 model
 * (low latency for chat). Both overrideable via env or per-call args.
 */
export async function synthesize(
  text: string,
  options?: { voiceId?: string; modelId?: string },
): Promise<Buffer> {
  if (!config.elevenLabsApiKey) {
    throw new Error('ELEVENLABS_API_KEY is not set');
  }
  const voiceId = options?.voiceId || config.elevenLabsVoiceId;
  const modelId = options?.modelId || config.elevenLabsModel;

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
        // Slightly higher stability for consistent personality across short replies.
        stability: 0.45,
        similarity_boost: 0.75,
        style: 0.35,
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
