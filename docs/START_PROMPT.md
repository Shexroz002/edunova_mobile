You are a senior Flutter engineer. In this repository (`edunova_mobile`), build a production-quality Flutter mobile and tablet app for the **student role** of EduNova. Chat is out of scope.

## Context you must load first
1. Read `CLAUDE.md` completely. It holds the rules, stack, architecture, UI rules and default product decisions.
2. Read `docs/api-notes.md`. It describes backend behaviour and quirks verified on the live server.
3. Read `docs/student-pages-analysis.md` (Uzbek). It covers every student screen: sections, APIs, real vs mock data, and web bugs not to copy.
4. Download the live API schema with `curl -s http://127.0.0.1:8000/openapi.json -o docs/openapi.json`. Read the student, common, auth, users, notifications and quiz-generator paths. Ignore `/teacher/*`, `/bot/*`, `/chats*` and `/messages*`.
5. Study the web frontend in `../edunova_frontend`, which is the UI/UX reference:
   - `src/app/routes.tsx`;
   - `src/app/layouts/StudentLayout.tsx`;
   - `src/app/components/ThemeContext.tsx`;
   - every file in `src/app/pages/student/` except `StudentChatPage.tsx` and `components/chat/*`;
   - shared modals in `src/app/components/*`;
   - `CreateQuizModal` in `src/app/pages/teacher/QuizzesPage.tsx`.

   Take the look, Uzbek texts and flows from here. Do not take API usage from here; the backend is the authority.
6. Skim the backend `../quiz_app/app` (routers, schemas, websocket managers) when a behaviour is unclear.

**Local services:**
- backend: `http://127.0.0.1:8000`;
- web: `http://127.0.0.1:5174`;
- Android emulator reaches the backend at `http://10.0.2.2:8000`.

**Test account:** read it from the env vars `EDUNOVA_TEST_USER` and `EDUNOVA_TEST_PASS`. Get a token like this, and never print or store the token or password:

```
curl -s -X POST http://127.0.0.1:8000/api/v1/auth/me/ \
  -d "grant_type=password&username=$EDUNOVA_TEST_USER&password=$EDUNOVA_TEST_PASS"
```

## Screens in scope
The mapping of web routes to Flutter routes is in `docs/student-pages-analysis.md` §2.
- **Auth:** Login, Register (2 steps, role fixed to `schoolboy`).
- **Tabs:** Bosh sahifa, Guruhlar, Do'stlar, Statistika, Profil.
- **Tests:** list; detail; start-test sheet (time choice); play (timer, math, question map, submit, auto-submit); result; error review; results history with leaderboard sheet.
- **Competition:** create wizard; join by code; lobby / waiting room (WebSocket, invite friends, host start, leave).
- **Groups:** list; detail; group session result (with PDF export and share).
- **Notifications:** list, filters, and actions for `competition_result`, `test_invite_notification` and `friend_request`, plus a realtime badge.
- **Friends:** list, search, add (search and suggestions).
- **Statistics:** cards, subjects, recommendation, weekly activity from history.
- **Profile:** view, edit, avatar upload.
- **Quiz creation:** from PDF and from AI, with job progress over WebSocket plus a polling fallback.
- **Last phase:** the question editor, tablet-first.

## Phases
Stop after each phase, report, and wait for my "davom et" before starting the next one.

**Phase 0: Discovery, no app code.**
- Create `docs/API_CONTRACT.md`. For every endpoint the app will use, record method, path, params, request and response fields. Build it from `docs/openapi.json` and confirm with real GET calls.
- Create `docs/SCREENS.md`. For each screen, list the web source file(s), sections, API calls, states, the phone layout and the tablet layout.
- List open questions and any conflicts with `CLAUDE.md` or the docs.

**Phase 1: Foundation.**
- `flutter create` (org `uz.myedunova`, platforms android and ios), then `config/dev.json` and a debug manifest with cleartext allowed.
- Theme tokens from `ThemeContext.tsx`, light and dark.
- `ApiClient` with auth refresh, `ApiException`, `MediaUrl`, tolerant JSON helpers, `SocketService`.
- `go_router` with an auth guard and a `StatefulShellRoute` holding the 5 tabs.
- Adaptive shell: `NavigationBar` on phone, `NavigationRail` on tablet.
- Login, Register, and a Profile view with logout.
- Shared widgets: `AppCard`, `AppTextField`, `PrimaryButton`, `UserAvatar`, `EmptyView`, `ErrorView`, `LoadingView`, `SearchField`, `FilterChips`.
- Unit tests for the JSON helpers, `MediaUrl`, token expiry and difficulty normalization.

**Phase 2: Tests core** (the most important flow).
- Screens: tests list (infinite scroll, search), test detail, start sheet, **play screen**, result screen, error review, results history and leaderboard.
- Widgets: `MathText` (strips ANSI escapes, falls back to plain text on errors), `MarkdownTable`, `QuestionView`, `OptionTile` (default / selected / correct / wrong), `QuestionMapSheet`, `CountdownTimer`, `ScoreRing`, `GradeBadge`, `DifficultyChip`.
- The play screen must:
  - base its timer on `deadline_at`;
  - save progress to local storage and restore it on restart;
  - recompute the timer on resume;
  - confirm before leaving (`PopScope`);
  - auto-submit at 0 and on `session_finished`;
  - send the multiplayer `answer` and `change/question/order` calls when needed.
- On tablet, the question map is a side panel.

**Phase 3: Realtime and competition.**
- Join by code (bottom sheet), competition wizard, lobby (room WebSocket, participant statuses, share/copy code, invite friends, host start, leave).
- Notifications screen and the notifications WebSocket, including the bell badge on the home app bar.

**Phase 4: Groups.**
- Groups list (search, sort, grid/list), group detail (stats, podium, tests, student performance), group session result (stats, podium, question-accuracy grid, table, PDF export and share).

**Phase 5: Home, statistics, friends, profile edit.**
- Assemble the home dashboard with real data only.
- Statistics with `fl_chart`.
- Friends with add friend.
- Profile edit (only changed, non-empty fields) and avatar upload (explicit image MIME).

**Phase 6: Quiz creation and editor.**
- Create quiz from PDF (`file_picker`) or AI, with job progress over WebSocket plus 3 s polling, and resume after an app restart.
- Question editor: text, topic, difficulty, table, images, correct option. Tablet-first.

## Definition of done (every screen)
- Matches the web screen visually in dark and light mode, uses Uzbek texts, and shows no mock data.
- Works on a 360 dp phone and a 768 dp or larger tablet in portrait and landscape, with no overflow.
- Has loading, empty, error-with-retry and pull-to-refresh states. API errors show the backend `detail` translated to Uzbek.
- Every public class and function has a `///` docstring. `flutter analyze` is clean. Non-trivial logic has tests.
- Verified manually against the local backend with the test account.

## Reporting after each phase
Report:
1. what was built (screens and files);
2. how to run it: `flutter run --dart-define-from-file=config/dev.json`;
3. what you verified and how;
4. new backend issues added to `docs/BACKEND_ISSUES.md`;
5. open questions for me.

Keep `PROGRESS.md` updated. Never modify `../quiz_app` or `../edunova_frontend`.

Start with **Phase 0** now.
