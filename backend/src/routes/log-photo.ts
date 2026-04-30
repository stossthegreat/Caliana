import type { FastifyInstance } from 'fastify';
import { parseFromPhoto } from '../services/nutrition.js';

/**
 * POST /api/log-photo
 *
 * Multipart: "photo" file field + optional "hint" text field.
 * Runs GPT-4o vision and returns a food-log entry with estimates.
 *
 * Max file size: 10 MB (enforced in index.ts via multipart limit).
 */
export async function registerLogPhotoRoute(app: FastifyInstance): Promise<void> {
  app.post('/api/log-photo', async (req, reply) => {
    try {
      const parts = req.parts();
      let imageBuffer: Buffer | null = null;
      let mimetype = 'image/jpeg';
      let hint = '';

      for await (const part of parts) {
        if (part.type === 'file' && part.fieldname === 'photo') {
          imageBuffer = await part.toBuffer();
          mimetype = part.mimetype || 'image/jpeg';
        } else if (part.type === 'field' && part.fieldname === 'hint') {
          const v = part.value;
          if (typeof v === 'string') hint = v;
        }
      }

      if (!imageBuffer || imageBuffer.length === 0) {
        return reply.status(400).send({ error: 'photo file required' });
      }

      const dataUrl = `data:${mimetype};base64,${imageBuffer.toString('base64')}`;
      const entry = await parseFromPhoto(dataUrl, hint);
      return entry;
    } catch (err) {
      req.log.error({ err }, 'log-photo failed');
      return reply.status(500).send({
        error: 'parse failed',
        message: err instanceof Error ? err.message : String(err),
      });
    }
  });
}
