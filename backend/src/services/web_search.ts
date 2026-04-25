import { config } from '../config.js';
import { serperSearch } from './serper.js';
import { braveSearch } from './brave.js';

/**
 * Unified web search result — normalizes Brave and Serper into one shape.
 */
export interface WebSearchResult {
  title: string;
  link: string;
  snippet?: string;
}

/**
 * Calls whichever search provider is configured.
 * Prefers Brave (newer, generous free tier) if both are set,
 * falls back to Serper automatically if Brave fails.
 */
export async function webSearch(
  query: string,
  limit: number = 10,
): Promise<WebSearchResult[]> {
  const hasBrave = !!config.braveApiKey;
  const hasSerper = !!config.serperApiKey;

  if (!hasBrave && !hasSerper) {
    throw new Error(
      'No search provider configured. Set BRAVE_API_KEY (preferred) or SERPER_API_KEY in Railway.',
    );
  }

  // Try Brave first if available
  if (hasBrave) {
    try {
      const results = await braveSearch(query, limit);
      return results.map((r) => ({
        title: r.title,
        link: r.url,
        snippet: r.description,
      }));
    } catch (err) {
      // If Brave fails and Serper is available, fall through to Serper
      if (!hasSerper) throw err;
      // eslint-disable-next-line no-console
      console.warn('Brave search failed, falling back to Serper:', err);
    }
  }

  // Serper fallback (or only option)
  const results = await serperSearch(query, limit);
  return results.map((r) => ({
    title: r.title,
    link: r.link,
    snippet: r.snippet,
  }));
}
