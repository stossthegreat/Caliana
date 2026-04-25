/**
 * Whitelist of trusted recipe publishers with domain authority scores.
 * Unknown domains get a base score. Used by the ranker to prefer
 * established publishers over SEO farms.
 */
export const TRUSTED_DOMAINS: Record<string, { name: string; authority: number }> = {
  'cooking.nytimes.com': { name: 'NYT Cooking', authority: 100 },
  'nytimes.com': { name: 'NYT Cooking', authority: 100 },
  'seriouseats.com': { name: 'Serious Eats', authority: 98 },
  'bonappetit.com': { name: 'Bon Appétit', authority: 96 },
  'epicurious.com': { name: 'Epicurious', authority: 95 },
  'foodnetwork.com': { name: 'Food Network', authority: 94 },
  'bbcgoodfood.com': { name: 'BBC Good Food', authority: 95 },
  'allrecipes.com': { name: 'AllRecipes', authority: 90 },
  'simplyrecipes.com': { name: 'Simply Recipes', authority: 92 },
  'halfbakedharvest.com': { name: 'Half Baked Harvest', authority: 90 },
  'thekitchn.com': { name: 'The Kitchn', authority: 91 },
  'food52.com': { name: 'Food52', authority: 92 },
  'smittenkitchen.com': { name: 'Smitten Kitchen', authority: 90 },
  'sallysbakingaddiction.com': { name: "Sally's Baking Addiction", authority: 91 },
  'pinchofyum.com': { name: 'Pinch of Yum', authority: 89 },
  'minimalistbaker.com': { name: 'Minimalist Baker', authority: 89 },
  'budgetbytes.com': { name: 'Budget Bytes', authority: 88 },
  'feelgoodfoodie.net': { name: 'Feel Good Foodie', authority: 87 },
  'tasty.co': { name: 'Tasty', authority: 86 },
  'delish.com': { name: 'Delish', authority: 85 },
  'tasteofhome.com': { name: 'Taste of Home', authority: 86 },
  'onceuponachef.com': { name: 'Once Upon a Chef', authority: 90 },
  'loveandlemons.com': { name: 'Love and Lemons', authority: 87 },
  'cookieandkate.com': { name: 'Cookie and Kate', authority: 87 },
  'skinnytaste.com': { name: 'Skinnytaste', authority: 88 },
  'ambitiouskitchen.com': { name: 'Ambitious Kitchen', authority: 87 },
  'damndelicious.net': { name: 'Damn Delicious', authority: 87 },
  'recipetineats.com': { name: 'RecipeTin Eats', authority: 92 },
  'gimmesomeoven.com': { name: 'Gimme Some Oven', authority: 86 },
  'twopeasandtheirpod.com': { name: 'Two Peas & Their Pod', authority: 85 },
  'cooktoria.com': { name: 'Cooktoria', authority: 82 },
  'theboysclubkitchen.com': { name: 'The Boys Club Kitchen', authority: 75 },
  'jamieoliver.com': { name: 'Jamie Oliver', authority: 95 },
  'marthastewart.com': { name: 'Martha Stewart', authority: 93 },
  'food.com': { name: 'Food.com', authority: 82 },
  'kingarthurbaking.com': { name: 'King Arthur Baking', authority: 94 },
};

/** Default authority for unknown domains */
export const DEFAULT_DOMAIN_AUTHORITY = 50;

/** Low-quality / SEO-farm domains to reject entirely */
export const BLOCKED_DOMAINS = new Set([
  'pinterest.com',
  'youtube.com',
  'facebook.com',
  'instagram.com',
  'tiktok.com',
]);

export function getDomainInfo(url: string): { domain: string; name: string; authority: number } {
  try {
    const host = new URL(url).hostname.replace(/^www\./, '');
    if (TRUSTED_DOMAINS[host]) {
      return { domain: host, ...TRUSTED_DOMAINS[host] };
    }
    // Check if any trusted domain is a suffix (e.g. blog.example.com)
    for (const [trusted, info] of Object.entries(TRUSTED_DOMAINS)) {
      if (host.endsWith('.' + trusted) || host === trusted) {
        return { domain: host, ...info };
      }
    }
    // Fallback: use hostname as the display name (titlecased)
    const name = host.split('.').slice(0, -1).join('.');
    return {
      domain: host,
      name: name.charAt(0).toUpperCase() + name.slice(1),
      authority: DEFAULT_DOMAIN_AUTHORITY,
    };
  } catch {
    return { domain: '', name: 'Unknown', authority: 0 };
  }
}

export function isBlocked(url: string): boolean {
  try {
    const host = new URL(url).hostname.replace(/^www\./, '');
    return BLOCKED_DOMAINS.has(host);
  } catch {
    return true;
  }
}
