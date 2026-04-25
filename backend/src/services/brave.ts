import { config } from '../config.js';

/**
 * Brave Search API result (simplified to what we need).
 */
export interface BraveResult {
  title: string;
  url: string;
  description?: string;
}

/**
 * Call Brave Search API and return web results.
 * Free tier: 2000 queries/month, 1 query/sec.
 * https://api.search.brave.com/
 */
export async function braveSearch(
  query: string,
  limit: number = 10,
): Promise<BraveResult[]> {
  if (!config.braveApiKey) {
    throw new Error('BRAVE_API_KEY not set');
  }

  const enrichedQuery = /recipe/i.test(query) ? query : `${query} recipe`;

  const url = new URL('https://api.search.brave.com/res/v1/web/search');
  url.searchParams.set('q', enrichedQuery);
  url.searchParams.set('count', String(limit));
  url.searchParams.set('country', 'US');
  url.searchParams.set('safesearch', 'moderate');

  const response = await fetch(url.toString(), {
    headers: {
      Accept: 'application/json',
      'X-Subscription-Token': config.braveApiKey,
    },
  });

  if (!response.ok) {
    const body = await response.text().catch(() => '');
    throw new Error(`Brave search failed: ${response.status} ${body}`);
  }

  const data = (await response.json()) as {
    web?: { results?: Array<{ title: string; url: string; description?: string }> };
  };

  return (data.web?.results || []).map((r) => ({
    title: r.title,
    url: r.url,
    description: r.description,
  }));
}
