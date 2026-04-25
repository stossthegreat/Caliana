/**
 * Parallel HTML fetcher with timeout and user-agent spoofing.
 * Some sites block bots, so we send a realistic UA.
 */

const USER_AGENT =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36';

const REQUEST_TIMEOUT_MS = 7000;

export interface FetchResult {
  url: string;
  html: string | null;
  error?: string;
}

async function fetchOne(url: string): Promise<FetchResult> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

  try {
    const response = await fetch(url, {
      headers: {
        'User-Agent': USER_AGENT,
        Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9',
        'Accept-Language': 'en-US,en;q=0.9',
      },
      signal: controller.signal,
      redirect: 'follow',
    });

    if (!response.ok) {
      return { url, html: null, error: `HTTP ${response.status}` };
    }

    const html = await response.text();
    return { url, html };
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return { url, html: null, error: message };
  } finally {
    clearTimeout(timeout);
  }
}

/**
 * Fetch multiple URLs in parallel.
 * Returns results in the same order as input; failed fetches have html=null.
 */
export async function fetchParallel(urls: string[]): Promise<FetchResult[]> {
  return Promise.all(urls.map(fetchOne));
}
