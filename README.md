# Gobly

The fastest way to find the right recipe and plan your week.

Gobly is a Flutter app that pairs a lethal AI agent with a clean three-tab UX (Home / Plan / Groceries) to take you from "what should I cook tonight?" to a fully planned week with auto-populated grocery list in seconds.

## Features

- **Voice + text recipe search** — speak or type, the agent fetches the highest-rated real recipes from trusted food publishers (NYT Cooking, Serious Eats, Bon Appétit, etc.)
- **AI week planner** — describe the week you want, get a full meal plan with real recipes attached
- **Auto-grocery from meal plan** — every ingredient flows automatically into the grocery list, categorized
- **Cookbooks** — group recipes into named collections
- **OpenAI Whisper voice transcription** for accurate hands-free input
- **Profile-aware** — allergies, dislikes, diet, household size all sent to the agent on every query

## Stack

- **Frontend**: Flutter
- **Backend**: Node.js + Fastify + TypeScript (separate repo)
- **LLM**: OpenAI GPT-4o mini + Whisper
- **Search**: Brave Search / Serper.dev
- **Recipe extraction**: schema.org/Recipe JSON-LD parsing

## Building

```bash
flutter pub get
flutter run
```
