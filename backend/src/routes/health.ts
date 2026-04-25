import type { FastifyInstance } from 'fastify';
import { configStatus } from '../config.js';

export async function registerHealthRoute(app: FastifyInstance): Promise<void> {
  app.get('/health', async () => {
    const status = configStatus();
    const ready = status.openaiConfigured && status.searchProvider !== 'none';
    return {
      status: 'ok',
      service: 'recimo-backend',
      timestamp: new Date().toISOString(),
      config: {
        openaiConfigured: status.openaiConfigured,
        braveConfigured: status.braveConfigured,
        serperConfigured: status.serperConfigured,
        searchProvider: status.searchProvider,
        ready,
      },
    };
  });
}
