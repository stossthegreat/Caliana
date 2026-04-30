import type { FastifyInstance } from 'fastify';
import { config, activeSearchProvider } from '../config.js';

/**
 * GET /api/diagnose
 *
 * Real end-to-end check that actually calls OpenAI, Brave, and Serper
 * with minimal live requests. Use this instead of /health when you
 * want to verify API keys are valid, not just that env vars are set.
 */
export async function registerDiagnoseRoute(app: FastifyInstance): Promise<void> {
  app.get('/api/diagnose', async () => {
    const checks: Record<string, unknown> = {
      openai: await checkOpenAI(),
    };

    if (config.braveApiKey) {
      checks.brave = await checkBrave();
    }
    if (config.serperApiKey) {
      checks.serper = await checkSerper();
    }

    const openaiOk = (checks.openai as { ok: boolean }).ok;
    const braveOk = config.braveApiKey ? (checks.brave as { ok: boolean }).ok : false;
    const serperOk = config.serperApiKey ? (checks.serper as { ok: boolean }).ok : false;

    const searchOk = braveOk || serperOk;
    const overall = openaiOk && searchOk ? 'ok' : 'degraded';

    return {
      status: overall,
      activeProvider: activeSearchProvider(),
      checks,
      timestamp: new Date().toISOString(),
    };
  });
}

async function checkOpenAI(): Promise<{ ok: boolean; error?: string; latencyMs?: number }> {
  if (!config.openaiApiKey) {
    return { ok: false, error: 'OPENAI_API_KEY not set' };
  }

  const started = Date.now();
  try {
    const response = await fetch('https://api.openai.com/v1/models', {
      headers: { Authorization: `Bearer ${config.openaiApiKey}` },
    });

    const latency = Date.now() - started;

    if (response.ok) {
      return { ok: true, latencyMs: latency };
    }

    const body = await response.text().catch(() => '');
    return {
      ok: false,
      error: `OpenAI ${response.status}: ${body.slice(0, 200)}`,
      latencyMs: latency,
    };
  } catch (err) {
    return {
      ok: false,
      error: err instanceof Error ? err.message : String(err),
      latencyMs: Date.now() - started,
    };
  }
}

async function checkBrave(): Promise<{ ok: boolean; error?: string; latencyMs?: number }> {
  if (!config.braveApiKey) {
    return { ok: false, error: 'BRAVE_API_KEY not set' };
  }

  const started = Date.now();
  try {
    const url = new URL('https://api.search.brave.com/res/v1/web/search');
    url.searchParams.set('q', 'test');
    url.searchParams.set('count', '1');
    const response = await fetch(url.toString(), {
      headers: {
        Accept: 'application/json',
        'X-Subscription-Token': config.braveApiKey,
      },
    });

    const latency = Date.now() - started;

    if (response.ok) {
      return { ok: true, latencyMs: latency };
    }

    const body = await response.text().catch(() => '');
    let friendly = `Brave ${response.status}: ${body.slice(0, 200)}`;
    if (response.status === 401 || response.status === 403) {
      friendly =
        'Brave API key is invalid. Get a fresh key at https://api.search.brave.com and paste it as BRAVE_API_KEY in Railway.';
    }
    return { ok: false, error: friendly, latencyMs: latency };
  } catch (err) {
    return {
      ok: false,
      error: err instanceof Error ? err.message : String(err),
      latencyMs: Date.now() - started,
    };
  }
}

async function checkSerper(): Promise<{ ok: boolean; error?: string; latencyMs?: number }> {
  if (!config.serperApiKey) {
    return { ok: false, error: 'SERPER_API_KEY not set' };
  }

  const started = Date.now();
  try {
    const response = await fetch('https://google.serper.dev/search', {
      method: 'POST',
      headers: {
        'X-API-KEY': config.serperApiKey,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ q: 'test', num: 1 }),
    });

    const latency = Date.now() - started;

    if (response.ok) {
      return { ok: true, latencyMs: latency };
    }

    const body = await response.text().catch(() => '');
    let friendly = `Serper ${response.status}: ${body.slice(0, 200)}`;
    if (response.status === 403 || response.status === 401) {
      friendly =
        'Serper API key is invalid (403 Unauthorized). Sign up at https://serper.dev and paste a fresh key as SERPER_API_KEY in Railway.';
    }
    return { ok: false, error: friendly, latencyMs: latency };
  } catch (err) {
    return {
      ok: false,
      error: err instanceof Error ? err.message : String(err),
      latencyMs: Date.now() - started,
    };
  }
}
