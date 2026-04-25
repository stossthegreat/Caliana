# Recimo Backend

The lethal recipe agent. Pipes user queries through GPT-4o mini → Serper.dev → JSON-LD extraction → quality ranking → beautiful recipe cards.

## What it does

### `POST /api/search`
Takes a user query and returns the top 3 highest-rated matching recipes from trusted food publishers.

**Request:**
```json
{
  "query": "mac and cheese",
  "userContext": "Diet: vegetarian\nAllergies: nuts"
}
```

**Pipeline:**
1. GPT-4o mini normalizes the query ("I want mac and cheese" → "mac and cheese recipe")
2. Serper.dev searches Google for the normalized query
3. Results are filtered to trusted domains (NYT Cooking, Serious Eats, etc.) and not-blocked sites
4. Top 6 candidates are fetched in parallel
5. JSON-LD `schema.org/Recipe` data is extracted from each page
6. Low-quality results (no image, no ingredients) are filtered out
7. Remaining recipes are ranked by rating × log(reviewCount) × domainAuthority
8. Top 3 are returned with full structured data

**Response:**
```json
{
  "query": "mac and cheese recipe",
  "results": [
    {
      "id": "abc123",
      "title": "Perfect Mac and Cheese",
      "description": "...",
      "image": "https://...",
      "source": {
        "domain": "cooking.nytimes.com",
        "name": "NYT Cooking",
        "url": "https://..."
      },
      "rating": { "value": 4.9, "count": 2847 },
      "time": { "prep": 15, "cook": 30, "total": 45, "display": "45 min" },
      "servings": 6,
      "ingredients": ["1 lb elbow macaroni", "..."],
      "instructions": ["Boil water...", "..."],
      "score": 0.92
    }
  ],
  "durationMs": 2841,
  "cached": false
}
```

### `POST /api/plan-week`
Generates a full 7-day meal plan (21 meals) with real recipes attached.

**Request:**
```json
{
  "prompt": "Mediterranean this week, quick meals",
  "userContext": "..."
}
```

GPT-4o mini generates 21 specific dish names, then the backend searches for a real recipe for each dish in parallel. Target time: under 15 seconds for the full week.

### `GET /health`
Health check endpoint for Railway.

## Stack

- **Runtime:** Node.js 20+
- **Framework:** Fastify (faster than Express, better types)
- **Language:** TypeScript
- **LLM:** OpenAI GPT-4o mini (cheap, fast, smart enough)
- **Search:** Serper.dev (~$0.001/search)
- **Cache:** In-memory TTL map (upgrade to Upstash Redis later)

## Local development

```bash
cd backend
cp .env.example .env
# Fill in OPENAI_API_KEY and SERPER_API_KEY
npm install
npm run dev
```

The server starts on `http://localhost:3000`.

### Test it

```bash
curl http://localhost:3000/health

curl -X POST http://localhost:3000/api/search \
  -H "Content-Type: application/json" \
  -d '{"query": "mac and cheese"}'
```

## Deploying to Railway

1. Create a new Railway project: `railway init`
2. Connect this directory
3. Set environment variables:
   - `OPENAI_API_KEY`
   - `SERPER_API_KEY`
4. Push to main — Railway auto-deploys via `railway.json` + Nixpacks
5. Enable public networking in Railway settings to get a URL like `recimo-backend.up.railway.app`
6. Set the Flutter app's `BACKEND_URL` to this URL

Railway handles `PORT`, TLS, and restarts automatically.

## API key costs (rough math)

At 100K queries/month:
- **Serper**: ~$50 (or free with their 2,500/mo free tier for testing)
- **OpenAI GPT-4o mini**: ~$5 (≈$0.15/M input + $0.60/M output tokens, ~300 tokens per query)

Total: roughly **$55/mo at 100K queries**. Still cheap.

With the TTL cache hitting even 30% of repeat queries, you cut that to ~$40/mo.

## Environment variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `OPENAI_API_KEY` | ✅ | — | OpenAI API key |
| `SERPER_API_KEY` | ✅ | — | Serper.dev API key |
| `OPENAI_MODEL` | | `gpt-4o-mini` | LLM model to use |
| `PORT` | | `3000` | Server port (Railway sets this) |
| `CACHE_TTL_SECONDS` | | `3600` | Search result cache TTL |
| `MAX_CANDIDATES` | | `6` | Max URLs to fetch per search |
| `RESULTS_PER_QUERY` | | `3` | Final results returned |
