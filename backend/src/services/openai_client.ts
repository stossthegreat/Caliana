import OpenAI from 'openai';
import { config, assertKeysConfigured } from '../config.js';

let _client: OpenAI | null = null;

/**
 * Shared OpenAI SDK client. Lazily constructed so the server can boot
 * before keys are set; the first call will assert keys are configured.
 */
export function getOpenAI(): OpenAI {
  assertKeysConfigured();
  if (!_client) {
    _client = new OpenAI({ apiKey: config.openaiApiKey });
  }
  return _client;
}
