import type { FastifyInstance } from 'fastify';
import { chat, type Tone, type CalianaContext } from '../services/caliana_agent.js';

interface ChatRequest {
  message: string;
  tone?: Tone;
  user?: string;
  day?: string;
  trigger?: string;
}

/**
 * POST /api/caliana-chat
 *
 * Caliana talks back. Tone-aware system prompt, 10-word reply cap,
 * JSON response with text + optional action chips.
 */
export async function registerCalianaChatRoute(
  app: FastifyInstance,
): Promise<void> {
  app.post<{ Body: ChatRequest }>('/api/caliana-chat', async (req, reply) => {
    const { message, tone, user, day, trigger } = req.body || ({} as ChatRequest);

    if (!message || typeof message !== 'string' || message.trim().length === 0) {
      return reply.status(400).send({ error: 'message is required' });
    }

    const resolvedTone: Tone =
      tone === 'polite' || tone === 'savage' || tone === 'cheeky'
        ? tone
        : 'cheeky';
    if (tone && tone !== resolvedTone) {
      req.log.warn(
        { requestedTone: tone, resolved: resolvedTone },
        'unknown tone coerced to cheeky',
      );
    }

    const ctx: CalianaContext = { user, day, trigger };

    try {
      const result = await chat(message.trim(), resolvedTone, ctx);
      return result;
    } catch (err) {
      req.log.error({ err }, 'caliana-chat failed');
      return reply.status(500).send({
        error: 'chat failed',
        message: err instanceof Error ? err.message : String(err),
      });
    }
  });
}
