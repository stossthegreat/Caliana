# Caliana

Caliana is a Flutter app: your sassy British AI calorie coach. Snap, speak, sorted.

Talk to her, log meals by voice or photo, and let her work out the calories without you doing the maths.

## What's in here

- **`lib/`** — Flutter app (Dart). UI, state, and services that talk to the backend.
- **`backend/`** — Node + Fastify API (deploys to Railway via `Dockerfile`).
- **`docs/`** — Privacy, Terms, and account-deletion pages served via GitHub Pages.
- **`android/`, `ios/`, `macos/`, `linux/`, `windows/`** — Flutter platform shells.

## Identifiers

- **iOS bundle:** `com.caliana.app`
- **Android package:** `com.caliana.caliana`

## Backend

See [`backend/README.md`](backend/README.md) for endpoint docs, env vars, and deploy notes.

## Legal

- Privacy: https://stossthegreat.github.io/Caliana/privacy.html
- Terms: https://stossthegreat.github.io/Caliana/terms.html
- Delete account: https://stossthegreat.github.io/Caliana/delete-account.html

## Building

```bash
flutter pub get
flutter run
```
