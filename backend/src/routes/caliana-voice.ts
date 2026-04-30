import type { FastifyInstance } from 'fastify';
import { synthesize } from '../services/elevenlabs.js';

interface VoiceRequest {
  text: string;
  voiceId?: string;
  modelId?: string;
}

/**
 * POST /api/caliana-voice
 *
 * Synthesise Caliana's reply with ElevenLabs. Returns raw audio/mpeg bytes
 * the client plays via audioplayers.
 */
export async function registerCalianaVoiceRoute(
  app: FastifyInstance,
): Promise<void> {
  app.post<{ Body: VoiceRequest }>('/api/caliana-voice', async (req, reply) => {
    const { text, voiceId, modelId } = req.body || ({} as VoiceRequest);
    if (!text || typeof text !== 'string' || text.trim().length === 0) {
      return reply.status(400).send({ error: 'text is required' });
    }

    try {
      const audio = await synthesize(text.trim(), { voiceId, modelId });
      reply.header('Content-Type', 'audio/mpeg');
      reply.header('Cache-Control', 'public, max-age=600');
      return reply.send(audio);
    } catch (err) {
      req.log.error({ err }, 'caliana-voice failed');
      return reply.status(500).send({
        error: 'voice failed',
        message: err instanceof Error ? err.message : String(err),
      });
    }
  });
}
