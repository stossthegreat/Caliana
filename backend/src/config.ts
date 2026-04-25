// Centralized environment configuration.
// API keys are optional at boot so the server starts cleanly on Railway
// and the health check passes before you add credentials. Endpoints that
// need the keys will throw a clear error at request time if they're missing.

function optional(name: string, fallback: string): string {
  return process.env[name] || fallback;
}

function optionalInt(name: string, fallback: number): number {
  const value = process.env[name];
  if (!value) return fallback;
  const parsed = parseInt(value, 10);
  return isNaN(parsed) ? fallback : parsed;
}

export const config = {
  port: optionalInt('PORT', 3000),

  // ---- OpenAI (Whisper + GPT-4o mini + GPT-4o vision) ----
  openaiApiKey: optional('OPENAI_API_KEY', ''),
  openaiModel: optional('OPENAI_MODEL', 'gpt-4o-mini'),

  // ---- Web search (Brave preferred, Serper fallback) ----
  braveApiKey: optional('BRAVE_API_KEY', ''),
  serperApiKey: optional('SERPER_API_KEY', ''),

  // ---- ElevenLabs TTS (Caliana's voice) ----
  elevenLabsApiKey: optional('ELEVENLABS_API_KEY', ''),
  // Default: Lily — British female, young, playful. Perfect for Caliana.
  elevenLabsVoiceId: optional(
    'ELEVENLABS_VOICE_ID',
    'pFZP5JQG7iQjIQuC4Bku',
  ),
  // Default: turbo v2.5 — low latency, ideal for chat replies.
  elevenLabsModel: optional(
    'ELEVENLABS_MODEL',
    'eleven_turbo_v2_5',
  ),

  // ---- Legacy recipe-search tunables (kept for meal-suggest route) ----
  cacheTtlSeconds: optionalInt('CACHE_TTL_SECONDS', 3600),
  maxCandidates: optionalInt('MAX_CANDIDATES', 6),
  resultsPerQuery: optionalInt('RESULTS_PER_QUERY', 3),
};

/** True if at least one web search provider is configured */
export function hasSearchProvider(): boolean {
  return !!config.braveApiKey || !!config.serperApiKey;
}

/** Returns which search provider will be used */
export function activeSearchProvider(): 'brave' | 'serper' | 'none' {
  if (config.braveApiKey) return 'brave';
  if (config.serperApiKey) return 'serper';
  return 'none';
}

export function assertKeysConfigured(): void {
  const missing: string[] = [];
  if (!config.openaiApiKey) missing.push('OPENAI_API_KEY');
  if (missing.length > 0) {
    throw new Error(
      `Missing required environment variables: ${missing.join(', ')}. ` +
        'Set them in Railway dashboard under Variables.',
    );
  }
}

/** Returns a status object for the /health endpoint */
export function configStatus(): {
  ok: boolean;
  openaiConfigured: boolean;
  braveConfigured: boolean;
  serperConfigured: boolean;
  elevenLabsConfigured: boolean;
  searchProvider: 'brave' | 'serper' | 'none';
} {
  return {
    ok: true,
    openaiConfigured: !!config.openaiApiKey,
    braveConfigured: !!config.braveApiKey,
    serperConfigured: !!config.serperApiKey,
    elevenLabsConfigured: !!config.elevenLabsApiKey,
    searchProvider: activeSearchProvider(),
  };
}
