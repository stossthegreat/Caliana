import type { FastifyInstance } from 'fastify';
import { config } from '../config.js';

/**
 * GET /api/debug-keys
 *
 * Shows masked info about the API keys stored in Railway so you can
 * verify the stored value matches what you think you pasted. Shows:
 * - length (whitespace shows up as extra length)
 * - first 3 chars
 * - last 3 chars
 * - hex dump of any non-printable characters at start/end (catches hidden \n, \r)
 *
 * NEVER returns the full key. Safe to leave in production.
 */
export async function registerDebugRoute(app: FastifyInstance): Promise<void> {
  app.get('/api/debug-keys', async () => {
    return {
      openai: maskKey(config.openaiApiKey),
      serper: maskKey(config.serperApiKey),
      brave: maskKey(config.braveApiKey),
      timestamp: new Date().toISOString(),
    };
  });

  /**
   * GET /api/debug-serper
   * Directly calls Serper with the stored key and returns the raw response.
   * Useful when /api/diagnose says it's invalid but you can't figure out why.
   */
  app.get('/api/debug-serper', async () => {
    if (!config.serperApiKey) {
      return { error: 'SERPER_API_KEY not set in Railway' };
    }

    try {
      const response = await fetch('https://google.serper.dev/search', {
        method: 'POST',
        headers: {
          'X-API-KEY': config.serperApiKey,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ q: 'test', num: 1 }),
      });

      const body = await response.text();
      const headers: Record<string, string> = {};
      response.headers.forEach((value, key) => {
        headers[key] = value;
      });
      return {
        status: response.status,
        statusText: response.statusText,
        headers,
        body: body.slice(0, 500),
        keyInfo: maskKey(config.serperApiKey),
      };
    } catch (err) {
      return {
        error: err instanceof Error ? err.message : String(err),
        keyInfo: maskKey(config.serperApiKey),
      };
    }
  });
}

function maskKey(key: string): {
  set: boolean;
  length: number;
  prefix: string;
  suffix: string;
  hasLeadingWhitespace: boolean;
  hasTrailingWhitespace: boolean;
  hasInternalWhitespace: boolean;
  firstByteHex: string;
  lastByteHex: string;
} {
  if (!key) {
    return {
      set: false,
      length: 0,
      prefix: '',
      suffix: '',
      hasLeadingWhitespace: false,
      hasTrailingWhitespace: false,
      hasInternalWhitespace: false,
      firstByteHex: '',
      lastByteHex: '',
    };
  }

  return {
    set: true,
    length: key.length,
    prefix: key.slice(0, 3),
    suffix: key.slice(-3),
    hasLeadingWhitespace: /^\s/.test(key),
    hasTrailingWhitespace: /\s$/.test(key),
    hasInternalWhitespace: /\s/.test(key.trim()),
    firstByteHex: key.charCodeAt(0).toString(16).padStart(2, '0'),
    lastByteHex: key.charCodeAt(key.length - 1).toString(16).padStart(2, '0'),
  };
}
