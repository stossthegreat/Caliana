/**
 * Curated trending recipes — hand-picked elite recipes with real data.
 * Update this file and push to Railway to refresh the trending feed.
 * No external API dependency. Can't break. You control it.
 *
 * To update: change the recipes below, commit, push to the backend repo.
 * Railway auto-deploys. The app picks up the new list on next launch.
 */
export interface TrendingRecipe {
  id: string;
  title: string;
  source: string;
  sourceUrl: string;
  image: string;
  emoji: string;
  rating: number;
  time: string;
  category: string; // 'TRENDING' | 'VIRAL' | 'CLASSIC' | 'QUICK'
  description: string;
}

// Rotate these based on season, trends, whatever you want.
// Just push to Railway and the app updates instantly.
export const TRENDING_RECIPES: TrendingRecipe[] = [
  {
    id: 't1',
    title: 'Marry Me Chicken',
    source: 'Delish',
    sourceUrl: 'https://www.delish.com/cooking/recipe-ideas/a26257425/marry-me-chicken-recipe/',
    image: 'https://hips.hearstapps.com/hmg-prod/images/marry-me-chicken-index-6476a8bc298b1.jpg',
    emoji: '🍗',
    rating: 4.9,
    time: '40 min',
    category: 'VIRAL',
    description: 'Creamy sun-dried tomato chicken that makes people propose.',
  },
  {
    id: 't2',
    title: 'Birria Tacos',
    source: 'Serious Eats',
    sourceUrl: 'https://www.seriouseats.com/birria-de-res-beef-birria-recipe-8710691',
    image: 'https://www.seriouseats.com/thmb/birria-tacos-hero.jpg',
    emoji: '🌮',
    rating: 4.8,
    time: '3 hrs',
    category: 'TRENDING',
    description: 'Slow-braised beef birria with consommé for dipping.',
  },
  {
    id: 't3',
    title: 'Baked Feta Pasta',
    source: 'Feel Good Foodie',
    sourceUrl: 'https://feelgoodfoodie.net/recipe/baked-feta-pasta/',
    image: 'https://feelgoodfoodie.net/wp-content/uploads/2021/02/Baked-Feta-Pasta-9.jpg',
    emoji: '🍝',
    rating: 4.9,
    time: '35 min',
    category: 'VIRAL',
    description: 'The TikTok pasta that broke the internet. Feta, tomatoes, basil.',
  },
  {
    id: 't4',
    title: 'Butter Chicken',
    source: 'RecipeTin Eats',
    sourceUrl: 'https://www.recipetineats.com/butter-chicken/',
    image: 'https://www.recipetineats.com/wp-content/uploads/2018/11/Butter-Chicken_9.jpg',
    emoji: '🍛',
    rating: 4.9,
    time: '30 min',
    category: 'CLASSIC',
    description: 'Rich, creamy, mildly spiced. Restaurant quality at home.',
  },
  {
    id: 't5',
    title: 'Smash Burgers',
    source: 'Serious Eats',
    sourceUrl: 'https://www.seriouseats.com/ultra-smashed-cheeseburger-recipe-food-lab',
    image: 'https://www.seriouseats.com/thmb/smash-burger-hero.jpg',
    emoji: '🍔',
    rating: 4.8,
    time: '20 min',
    category: 'QUICK',
    description: 'Crispy edges, juicy center. The only burger method that matters.',
  },
  {
    id: 't6',
    title: 'Overnight Oats',
    source: 'Minimalist Baker',
    sourceUrl: 'https://minimalistbaker.com/peanut-butter-overnight-oats/',
    image: 'https://minimalistbaker.com/wp-content/uploads/2015/07/THE-BEST-Peanut-Butter-Overnight-Oats-5-ingredients.jpg',
    emoji: '🥣',
    rating: 4.7,
    time: '5 min',
    category: 'QUICK',
    description: '5 minutes prep, ready when you wake up. Perfect meal prep.',
  },
  {
    id: 't7',
    title: 'Shakshuka',
    source: 'NYT Cooking',
    sourceUrl: 'https://cooking.nytimes.com/recipes/1014721-shakshuka',
    image: 'https://static01.nyt.com/images/2023/02/28/multimedia/ep-shakshuka-zwfl/ep-shakshuka-zwfl-superJumbo.jpg',
    emoji: '🍳',
    rating: 4.8,
    time: '30 min',
    category: 'TRENDING',
    description: 'Poached eggs in spiced tomato sauce. One pan, zero effort.',
  },
  {
    id: 't8',
    title: 'Korean Fried Chicken',
    source: 'RecipeTin Eats',
    sourceUrl: 'https://www.recipetineats.com/korean-fried-chicken/',
    image: 'https://www.recipetineats.com/wp-content/uploads/2020/10/Korean-Fried-Chicken_5.jpg',
    emoji: '🍗',
    rating: 4.9,
    time: '45 min',
    category: 'VIRAL',
    description: 'Double-fried, sticky gochujang glaze. Dangerously addictive.',
  },
  {
    id: 't9',
    title: 'Carbonara',
    source: 'Bon Appétit',
    sourceUrl: 'https://www.bonappetit.com/recipe/simple-carbonara',
    image: 'https://assets.bonappetit.com/photos/5a6f48f94f6e7c4c99438cd7/16:9/w_1280/carbonara.jpg',
    emoji: '🍝',
    rating: 4.8,
    time: '25 min',
    category: 'CLASSIC',
    description: 'Egg, pecorino, guanciale, black pepper. Nothing else needed.',
  },
  {
    id: 't10',
    title: 'Banana Bread',
    source: 'Sally\'s Baking Addiction',
    sourceUrl: 'https://sallysbakingaddiction.com/best-banana-bread-recipe/',
    image: 'https://sallysbakingaddiction.com/wp-content/uploads/2019/07/best-banana-bread-recipe.jpg',
    emoji: '🍞',
    rating: 4.9,
    time: '1 hr',
    category: 'CLASSIC',
    description: 'Moist, sweet, one bowl. The most-baked recipe on the internet.',
  },
  {
    id: 't11',
    title: 'Chicken Stir Fry',
    source: 'Budget Bytes',
    sourceUrl: 'https://www.budgetbytes.com/easy-chicken-stir-fry/',
    image: 'https://www.budgetbytes.com/wp-content/uploads/2019/07/Easy-Chicken-Stir-Fry-above.jpg',
    emoji: '🥘',
    rating: 4.7,
    time: '20 min',
    category: 'QUICK',
    description: 'Weeknight hero. 20 minutes, one pan, endless variations.',
  },
  {
    id: 't12',
    title: 'Greek Salad',
    source: 'Love and Lemons',
    sourceUrl: 'https://www.loveandlemons.com/greek-salad/',
    image: 'https://www.loveandlemons.com/wp-content/uploads/2019/07/greek-salad.jpg',
    emoji: '🥗',
    rating: 4.7,
    time: '10 min',
    category: 'QUICK',
    description: 'Crisp, fresh, no cooking required. Summer in a bowl.',
  },
];

/**
 * Get today's trending selection. Rotates through the list so the
 * home screen feels fresh each day without any external API.
 * Returns 5-6 recipes per day.
 */
export function getTodaysTrending(count: number = 6): TrendingRecipe[] {
  const dayOfYear = Math.floor(
    (Date.now() - new Date(new Date().getFullYear(), 0, 0).getTime()) /
      (1000 * 60 * 60 * 24),
  );
  // Rotate starting index by day so users see different recipes daily
  const startIndex = dayOfYear % TRENDING_RECIPES.length;
  const result: TrendingRecipe[] = [];
  for (let i = 0; i < count && i < TRENDING_RECIPES.length; i++) {
    result.push(TRENDING_RECIPES[(startIndex + i) % TRENDING_RECIPES.length]);
  }
  return result;
}
