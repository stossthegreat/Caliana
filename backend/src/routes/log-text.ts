import type { FastifyInstance } from 'fastify';
import { parseFromText } from '../services/nutrition.js';

interface LogTextRequest {
  text: string;
}

/**
 * POST /api/log-text
 *
 * Parse a user's text (or voice transcript) into a single food-log entry
 * with realistic macro estimates.
 */
export async function registerLogTextRoute(app: FastifyInstance): Promise<void> {
  app.post<{ Body: LogTextRequest }>('/api/log-text', async (req, reply) => {
    const { text } = req.body || ({} as LogTextRequest);
    if (!text || typeof text !== 'string' || text.trim().length === 0) {
      return reply.status(400).send({ error: 'text is required' });
    }

    try {
      const entry = await parseFromText(text.trim());
      return entry;
    } catch (err) {
      req.log.error({ err }, 'log-text failed');
      return reply.status(500).send({
        error: 'parse failed',
        message: err instanceof Error ? err.message : String(err),
      });
    }
  });
}
