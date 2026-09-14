# EduNova Mobile (Flutter): project rules

Read this file fully before doing any work in this repository.

## What we are building
A Flutter app for the **STUDENT role** of EduNova, an education quiz platform. Platforms: Android and iOS. Form factors: phone and tablet.

**Chat is in scope** (owner decision, replaces the earlier exclusion). It is its own tab plus
full-screen pages, and it uses `/chats`, `/messages` and `/ws/chat`. The chat button on a friend row
opens a private chat. Still out of scope: the **room chat inside the waiting room** — the
`chat_message` event on `/ws/quiz/sessions/{id}` is a separate, unpersisted feature.

## Sources of truth
These projects are **read-only**. Never modify them.

| What | Where | Notes |
|---|---|---|
| Backend (FastAPI) | `../quiz_app` | Runs at `http://127.0.0.1:8000`. Swagger at `/docs`, schema at `/openapi.json`. |
| Web frontend (UI/UX reference) | `../edunova_frontend` | Runs at `http://127.0.0.1:5174`. Student pages in `src/app/pages/student/*`. Layout: `src/app/layouts/StudentLayout.tsx`. Theme: `src/app/components/ThemeContext.tsx`. Shared modals: `src/app/components/*`. Create-quiz modal: `CreateQuizModal` in `src/app/pages/teacher/QuizzesPage.tsx`. |
| Screen analysis | `docs/student-pages-analysis.md` | Uzbek. Per screen: what is real vs mock, and web bugs to avoid. |
| API behaviour notes | `docs/api-notes.md` | Quirks verified against the live server. |

**When sources conflict:** live `/openapi.json` plus real responses win, then backend code, then the docs. The web frontend is the reference for **look, texts and flows only**, never for API correctness, because it has known bugs.

## Tech stack
- Flutter stable, Dart 3.
- `flutter_riverpod`: Notifier / AsyncNotifier, no code generation.
- Networking and routing: `dio`, `go_router` (`StatefulShellRoute` for tabs).
- Storage: `flutter_secure_storage` (tokens), `shared_preferences`.
- Realtime: `web_socket_channel`.
- Content and media: `flutter_math_fork` (LaTeX), `fl_chart`, `cached_network_image`, `file_picker`, `image_picker`.
- Sharing and export: `share_plus`, `pdf` + `printing`, `intl`.
- Add a package only when a screen needs it. Pin versions with `^`.
- Models: hand-written immutable classes with tolerant `fromJson`. No `build_runner`/`freezed` unless the owner asks.

## Architecture
```
lib/
  core/      config, network (ApiClient, AuthInterceptor, ApiException, MediaUrl),
             realtime (SocketService), storage, theme, router, widgets, utils
  features/  auth, shell, home, tests, session (play/result/review/lobby),
             results, competition, groups, notifications, friends, statistics,
             profile, quiz_create
    <feature>/data (repository + DTO parsing), domain (models), presentation (screens, controllers, widgets)
```

**ApiClient (single dio instance):**
- attaches the Bearer token;
- refreshes proactively when the token has less than 60 s left;
- on 401 does a single-flight refresh and retries once;
- logs out if refresh fails;
- maps errors to user-facing Uzbek messages from `detail`.

**SocketService:**
- reconnects with exponential backoff;
- sends a heartbeat;
- reconnects on app resume;
- passes the token as `?token=`;
- never logs full URLs, because they contain the token.

**Config:**
- `--dart-define-from-file=config/dev.json` provides `API_BASE_URL`.
- Android emulator: `http://10.0.2.2:8000`.
- The debug manifest allows cleartext HTTP.
- WS base is derived from `API_BASE_URL` (`http` → `ws`).

## Code style (owner's preference)
- Simple, clean, organized.
- **Every public class and function has a `///` docstring.**
- Small files, one widget per file when it grows beyond ~150 lines.
- No dead code, no commented-out code, no premature abstraction.

## UI/UX rules
- **Match the web look:**
  - tokens from `ThemeContext.tsx`: dark theme by default for students, light theme via a toggle;
  - brand color `#6366F1`;
  - cards with 16 px radius and a 1 px border;
  - the same icons in spirit.
- **Texts:** Uzbek, copied from the web pages.
- **Responsive:**
  - under 600 dp: bottom `NavigationBar` with 6 tabs: *Bosh sahifa, Guruhlar, Do'stlar, Suhbatlar, Statistika, Profil*;
  - 600–1024 dp: `NavigationRail`, with two panes (list and detail) where it makes sense;
  - 1024 dp and wider: extended rail;
  - tables become cards on phones;
  - tap targets at least 44 dp.
- **Every screen has:** loading, empty and error-with-retry states, plus pull-to-refresh on lists.
- **Both themes, always.** Every screen reads its colours from `context.colors` (`AppColors`) and is
  checked in dark *and* light; never hardcode a hex that is not a token or a brand/semantic constant.
  Chat is no exception: bubbles, presence dots, reactions and sheets all resolve from the tokens.
- **Do not port mock or fake UI** (analysis §4). Use the default decisions below.

## Default product decisions (ask the owner before changing any)
1. **Gamification is hidden**: XP, streak, level, achievements, rank, "Top 10%". Home stat cards use `GET /api/v1/student/quizzes/analytics/overall/cards` instead.
2. **Other fake UI is hidden**:
   - online status and "+12 do'st onlayn";
   - quiz-detail fake "Faol" status, created date, attempts count and 88/67/42% accuracy;
   - test-card "participants 0".
3. **Weekly activity chart**: compute it from `/student/sessions/me/history/` (last 7 days). Hide it if that is not reliable.
4. **Waiting room**: no local-only "Ready" toggle, no "Kick", no room chat.
5. **Hidden entirely**: password change (no endpoint) and Google/Telegram login.
6. **Question editor for students** (edit text, images, correct option) is the last phase and designed tablet-first.

## Chat
- **Design:** the canvas at `docs/design/chat/` (dark and light, 7 screens each) is the reference.
- **Transport split:** the chat list, history, upload and chat/member metadata come over HTTP;
  everything live goes through `/ws/chat`. A message SENT over HTTP is not broadcast, so the app
  always sends through the socket and uses HTTP only for reads and the file upload.
- **Every `EventType` is used.** Outgoing: `message:new`, `message:forward`, `message:edited`,
  `message:deleted`, `message:reaction_add`, `message:read`, `chat:created`, `typing:update`,
  `chat:leaved`, `heartbeat:heartbeat`. Incoming: those plus `message:ack`, `presence:update`,
  `connection:ready` and `error`.
- **`message:ack` is how the sender learns the server id.** The socket suppresses the sender's own
  echo per connection, so an optimistic bubble is reconciled from the ack (`client_message_id`),
  never from a `message:new` coming back.
- **Media stays in the app.** Voice is recorded with `record` and plays through one shared
  `just_audio` player; a round `video_message` plays in place and a normal `video` opens the in-app
  `video_player` page. Only documents are handed to the system viewer.
- **Presence expires silently.** `presence:{user_id}` is published only on an explicit connect or
  disconnect — the 60 s Redis key expiring emits nothing — so any presence snapshot must be
  re-read, never trusted indefinitely.
- **Membership is enforced server-side**: a non-member gets `403` on HTTP and an `error` frame on the
  socket. Surface it, do not retry.

## Workflow rules
- Work **phase by phase** (`docs/START_PROMPT.md`). After each phase:
  1. `flutter analyze` must show 0 errors and 0 warnings;
  2. `flutter test` must pass;
  3. run the app against the local backend;
  4. update `PROGRESS.md`;
  5. stop and summarize for the owner.
- **Verify every endpoint with a real request before writing its model.** Never guess fields.
- **Credentials:** take test credentials only from the env vars `EDUNOVA_TEST_USER` and `EDUNOVA_TEST_PASS`. Never write them to files or logs, never commit secrets.
- **While exploring, never call endpoints with side effects** (create/join/start/finish sessions, invite, contact create, avatar upload, quiz generation) unless you are testing that exact flow. Never call:
  - `GET .../multiplayer/{id}/results/` (host-only, it rewrites scores);
  - `.../topic-statistic/` (always returns 500).
- **Backend bugs:** write them to `docs/BACKEND_ISSUES.md` (endpoint, request, actual vs expected). Work around them in the client, never by editing `../quiz_app`.
