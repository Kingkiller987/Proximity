# Proximity — Privacy-First Local Chat & Temporary Events

Cross-platform Flutter mobile application for discovering nearby conversations and temporary local events with strict attendance privacy.

## Quick Start

```bash
export PATH="$HOME/.local/bin:$PATH"
flutter pub get
flutter analyze
flutter test
```

### Run on iOS Simulator or macOS

```bash
# If Xcode iOS Simulator runtime is not yet installed:
xcodebuild -downloadPlatform iOS
open -a Simulator

# Run the app
flutter run
```

### Environment Variables (Never hardcode secrets)

Pass runtime configuration via `--dart-define`:

```bash
flutter run \
  --dart-define=APP_ENV=development \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_ANON_KEY=<your-local-anon-key> \
  --dart-define=MAP_TILE_URL_TEMPLATE=https://tile.openstreetmap.org/{z}/{x}/{y}.png
```

### Production Map Tile Provider Requirement

- Local development and iOS Simulator testing default to OpenStreetMap's `https://tile.openstreetmap.org/{z}/{x}/{y}.png`.
- Per the OpenStreetMap Tile Usage Policy, the public `tile.openstreetmap.org` endpoint must **not** be used in production mobile apps.
- `AppConfig.isTileProviderValidForEnvironment` rejects `tile.openstreetmap.org` when `APP_ENV=production`. For production builds, pass an authorized commercial or self-hosted tile URL template via `--dart-define=MAP_TILE_URL_TEMPLATE=https://tiles.example.com/{z}/{x}/{y}.png`.

### Supabase PostGIS & RLS Migration (Milestone 2)

Apply `supabase/migrations/20261025000000_milestone2_schema.sql` to enforce server-side PostGIS geofencing (`ST_DWithin`), current-visit-only Landmark Chat RLS (`created_at >= visit.entered_at`), immutable `AdjectiveNoun` handle triggers, and private `chat-media` Storage authorization. Client-side checks in `AppController` mirror these rules for local/offline simulation and must be paired with the Supabase migration in production.
