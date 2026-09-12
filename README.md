# EduNova Mobile

Flutter app for EduNova **students** (phone and tablet, Android and iOS). Chat is not included.

## First-time setup
Run these in this folder. `flutter create` only adds the missing platform folders; it does not overwrite existing files.

```bash
flutter create --org uz.myedunova --project-name edunova_mobile --platforms android,ios .
flutter pub get
flutter analyze
flutter test
```

## Run against the local backend
1. Start the backend (`../quiz_app`) on port 8000.
   - The Android emulator reaches it as `http://10.0.2.2:8000`, which is already set in `config/dev.json`.
   - For a **physical phone**, run the backend on `0.0.0.0:8000` and put your computer's LAN IP in `config/dev.json`, e.g. `http://192.168.1.20:8000`.
2. Start the app:

```bash
flutter run --dart-define-from-file=config/dev.json
# production API:
flutter run --dart-define-from-file=config/prod.json
```

Debug builds allow plain HTTP through `android/app/src/debug/AndroidManifest.xml`.

**Release builds:**
- add `<uses-permission android:name="android.permission.INTERNET"/>` to `android/app/src/main/AndroidManifest.xml`;
- use HTTPS.

## Project layout
```
lib/core/      config, network (ApiClient, auth refresh), realtime (SocketService),
               storage, theme, router, widgets, utils
lib/features/  auth, shell, home, groups, friends, statistics, profile, ...
docs/          START_PROMPT.md, api-notes.md, API_CONTRACT.md, SCREENS.md,
               BACKEND_ISSUES.md, student-pages-analysis.md
```

Rules for contributors, including Claude Code, are in `CLAUDE.md`. Status is in `PROGRESS.md`.
