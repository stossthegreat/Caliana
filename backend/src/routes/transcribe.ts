import type { FastifyInstance } from 'fastify';
import OpenAI from 'openai';
import { toFile } from 'openai/uploads';
import { config, assertKeysConfigured } from '../config.js';

let _client: OpenAI | null = null;
function getClient(): OpenAI {
  assertKeysConfigured();
  if (!_client) {
    _client = new OpenAI({ apiKey: config.openaiApiKey });
  }
  return _client;
}

/**
 * POST /api/transcribe
 *
 * Accepts a multipart upload with an "audio" file field, forwards to
 * OpenAI Whisper, and returns the transcribed text.
 *
 * Max file size: 25 MB (Whisper limit).
 * Accepted formats: m4a, mp3, mp4, mpeg, mpga, wav, webm.
 */
export async function registerTranscribeRoute(app: FastifyInstance): Promise<void> {
  app.post('/api/transcribe', async (request, reply) => {
    const started = Date.now();

    try {
      // Pull the uploaded file
      const data = await request.file();
      if (!data) {
        return reply.status(400).send({ error: 'No audio file provided' });
      }

      // Read the whole buffer
      const buffer = await data.toBuffer();
      if (buffer.length === 0) {
        return reply.status(400).send({ error: 'Audio file is empty' });
      }

      // Forward to OpenAI Whisper
      const transcription = await getClient().audio.transcriptions.create({
        file: await toFile(buffer, data.filename || 'audio.m4a', {
          type: data.mimetype || 'audio/m4a',
        }),
        model: 'whisper-1',
        language: 'en',
      });

      return {
        text: transcription.text,
        durationMs: Date.now() - started,
      };
    } catch (err) {
      request.log.error({ err }, 'Transcription failed');
      return reply.status(500).send({
        error: 'Transcription failed',
        message: err instanceof Error ? err.message : String(err),
      });
    }
  });
}
