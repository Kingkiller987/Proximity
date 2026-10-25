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
  --dart-define=SUPABASE_ANON_KEY=<your-local-anon-key>
```
