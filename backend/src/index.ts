import Fastify from 'fastify';
import cors from '@fastify/cors';
import multipart from '@fastify/multipart';
import { config } from './config.js';
import { registerHealthRoute } from './routes/health.js';
import { registerDiagnoseRoute } from './routes/diagnose.js';
import { registerDebugRoute } from './routes/debug.js';
import { registerTranscribeRoute } from './routes/transcribe.js';
import { registerSearchRoute } from './routes/search.js';
import { registerCalianaChatRoute } from './routes/caliana-chat.js';
import { registerLogTextRoute } from './routes/log-text.js';
import { registerLogPhotoRoute } from './routes/log-photo.js';
import { registerCalianaVoiceRoute } from './routes/caliana-voice.js';
import { registerMealSuggestRoute } from './routes/meal-suggest.js';
import { registerFridgeSuggestRoute } from './routes/fridge-suggest.js';
import { registerPlanDayRoute } from './routes/plan-day.js';

async function main(): Promise<void> {
  const app = Fastify({
    logger: {
      level: 'info',
      transport:
        process.env.NODE_ENV !== 'production'
          ? {
              target: 'pino-pretty',
              options: {
                translateTime: 'HH:MM:ss',
                ignore: 'pid,hostname',
              },
            }
          : undefined,
    },
  });

  await app.register(cors, {
    origin: true,
    methods: ['GET', 'POST', 'OPTIONS'],
  });

  await app.register(multipart, {
    limits: {
      fileSize: 25 * 1024 * 1024, // 25 MB — Whisper max, also covers food photos
    },
  });

  app.addHook('onRequest', async (req) => {
    req.log.info(
      { method: req.method, url: req.url, ua: req.headers['user-agent'] },
      '→ incoming',
    );
  });

  app.addHook('onResponse', async (req, reply) => {
    req.log.info(
      {
        method: req.method,
        url: req.url,
        status: reply.statusCode,
        durationMs: Math.round(reply.elapsedTime),
      },
      '← response',
    );
  });

  app.setErrorHandler((err, req, reply) => {
    req.log.error({ err }, 'unhandled error');
    reply.status(500).send({
      error: 'Internal server error',
      message: err instanceof Error ? err.message : String(err),
    });
  });

  // ---- Infrastructure routes ----
  await registerHealthRoute(app);
  await registerDiagnoseRoute(app);
  await registerDebugRoute(app);

  // ---- Caliana core pipeline ----
  await registerTranscribeRoute(app); // Whisper voice → text
  await registerCalianaChatRoute(app); // GPT-4o mini → tone-aware reply
  await registerLogTextRoute(app); // GPT-4o mini → food estimate
  await registerLogPhotoRoute(app); // GPT-4o vision → food estimate
  await registerCalianaVoiceRoute(app); // ElevenLabs → audio/mpeg
  await registerMealSuggestRoute(app); // GPT-4o mini + Serper → meal ideas
  await registerFridgeSuggestRoute(app); // GPT-4o vision + Serper → fridge-aware ideas
  await registerPlanDayRoute(app); // GPT-4o mini → 4-slot day plan

  // ---- Legacy recipe search (kept — Caliana can tap it for richer meal pulls) ----
  await registerSearchRoute(app);

  app.get('/', async () => ({
    name: 'Caliana API',
    version: '0.2.0',
    endpoints: [
      'GET  /health',
      'GET  /api/diagnose',
      'POST /api/transcribe',
      'POST /api/caliana-chat',
      'POST /api/log-text',
      'POST /api/log-photo',
      'POST /api/caliana-voice',
      'POST /api/meal-suggest',
      'POST /api/fridge-suggest',
      'POST /api/plan-day',
      'POST /api/search',
    ],
  }));

  try {
    await app.listen({ port: config.port, host: '0.0.0.0' });
    app.log.info(`Caliana backend listening on :${config.port}`);
  } catch (err) {
    app.log.error({ err }, 'Failed to start server');
    process.exit(1);
  }
}

main().catch((err) => {
  console.error('Fatal startup error:', err);
  process.exit(1);
});
