import { config } from '../config.js';

/**
 * Serper.dev search result (simplified to what we need).
 */
export interface SerperResult {
  title: string;
  link: string;
  snippet?: string;
  position?: number;
}

/**
 * Call Serper.dev Google search API and return organic results.
 * Adds "recipe" to the query if not already present to bias toward cooking sites.
 */
export async function serperSearch(
  query: string,
  limit: number = 10,
): Promise<SerperResult[]> {
  if (!config.serperApiKey) {
    throw new Error('SERPER_API_KEY not set');
  }
  const enrichedQuery = /recipe/i.test(query) ? query : `${query} recipe`;

  const response = await fetch('https://google.serper.dev/search', {
    method: 'POST',
    headers: {
      'X-API-KEY': config.serperApiKey,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      q: enrichedQuery,
      num: limit,
      gl: 'us',
      hl: 'en',
    }),
  });

  if (!response.ok) {
    const body = await response.text().catch(() => '');
    throw new Error(`Serper search failed: ${response.status} ${body}`);
  }

  const data = (await response.json()) as { organic?: SerperResult[] };
  return data.organic || [];
}
