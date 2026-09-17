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

Start the backend (`../quiz_app`) on port 8000 first.

### Physical phone or tablet — `tool/run.sh`

```bash
tool/run.sh                 # opens the tunnel, then builds, installs and attaches
tool/run.sh --tunnel-only   # just the tunnel, then launch from the IDE
tool/run.sh --watch         # keeps the tunnel open; leave it running in a tab
tool/run.sh --release       # extra flags are passed through to flutter run
```

A device cannot reach the backend on its own — device-to-device traffic is blocked on this Wi-Fi, so
`http://127.0.0.1:8000` (`config/device.json`) resolves only through an `adb reverse` tunnel. That
tunnel is **dropped every time the cable is unplugged**, the phone reboots or the adb server
restarts, and its absence looks exactly like a server outage: *"Serverga ulanib bo'lmadi"*. The
script opens it, warns if the backend itself is down, and then runs the app. Set `ANDROID_SERIAL`
when more than one device is connected.

`--watch` is the answer to the drop rather than the first launch: it checks every three seconds and
reopens the tunnel as soon as the device is back, printing a timestamped line when it does. Use it
when the app is launched from the IDE or from an already-installed build, where nothing else would
reopen it.

Check the tunnel by hand with `adb reverse --list` — empty output is the cause of that server
error.

Without the script, the same thing by hand:

```bash
adb reverse tcp:8000 tcp:8000
flutter run --dart-define-from-file=config/device.json
```

### Android emulator

The emulator reaches the host at `10.0.2.2` and needs no tunnel:

```bash
flutter run --dart-define-from-file=config/dev.json
```

### Production API

```bash
flutter run --dart-define-from-file=config/prod.json
```

Without any `--dart-define-from-file` the app falls back to `http://127.0.0.1:8000`, which is right
for a real device; only the emulator needs the flag.

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
