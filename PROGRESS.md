# Progress

## Phase 0: Discovery ✅
- `docs/API_CONTRACT.md`: endpoints and schemas from the live OpenAPI.
- `docs/SCREENS.md`: web page to Flutter screen map, with phases.
- `docs/OPEN_QUESTIONS.md`: open product questions and the conflicts found between `api-notes.md`, the schema and the backend source.
- `docs/BACKEND_ISSUES.md`: **30 issues** (16 from the first pass, 10 added from a schema + backend-source review, 4 more from the live verification on 2026-09-11).
- `docs/api-notes.md` and `docs/student-pages-analysis.md`: behaviour notes and screen analysis.

## Phase 1: Foundation ✅
Verified by the owner on 2026-09-11: `flutter analyze` found no issues and all 12 tests passed. Not yet run on a device: no emulator was connected.

Done:
- **Config:** `config/dev.json` / `prod.json` (`API_BASE_URL`); a debug manifest that allows cleartext HTTP.
- **Theme:** `AppColors` (tokens from the web `ThemeContext`) and `AppTheme` for light and dark; students default to dark; the choice is persisted.
- **Network:**
  - `ApiClient` (dio) and `AuthInterceptor`: Bearer token, proactive refresh at 60 s, single-flight refresh on 401, one retry, logout when refresh is rejected;
  - `ApiException` (Uzbek messages from `detail`, 422 field errors);
  - `MediaUrl` (rewrites localhost image hosts, collapses `//`).
- **Realtime:** `SocketService` (reconnect with backoff, heartbeat, fresh token on each connect) and `socketFactoryProvider`.
- **Storage:** `TokenStorage` (secure storage with an in-memory cache, cached user JSON).
- **Utils:** `json_utils` (tolerant parsing, UTC and Tashkent dates, `PageResult`), `Difficulty.parse`.
- **Auth:**
  - Login: lowercases the username, rejects teachers, loads `/auth/me/` after login.
  - Register: 2 steps, subjects chosen as chips (at least 2), role `schoolboy`, auto-login.
  - Session restore on start.
- **Router:** `go_router` with a splash/login/app redirect and a `StatefulShellRoute` with 5 tabs.
- **Shell:** `NavigationBar` on phones, `NavigationRail` on tablets (extended at 1024 dp and wider).
- **Screens:**
  - Profile: real data only, theme switch, logout.
  - Home, Groups, Friends and Statistics are placeholders for their phases.
- **Shared widgets:** `AppCard`, `AppTextField`, `PrimaryButton`, `SearchField` (debounced), `FilterChips`, `UserAvatar`, `BrandMark`/`BrandTitle`, `PageAppBar`, `ErrorBanner`, `LoadingView`, `ErrorView`, `EmptyView`, `ContentConstraint`, breakpoints.
- **Tests:** `test/core_utils_test.dart` (MediaUrl, JSON helpers, dates, PageResult, AuthUser, JWT expiry, Difficulty) and `test/widget_test.dart` (PrimaryButton).

## Phase 2: Tests core ✅ verified against the live backend (2026-09-11)

Verification run on 2026-09-11 with the Flutter SDK present (3.47.3 / Dart 3.13.3):

| Gate | Result |
|---|---|
| `flutter analyze` | **No issues found** — 0 errors, 0 warnings |
| `flutter test` | **22 passed, 1 skipped** (the skipped one is the live suite, which is off by default) |
| Live backend | **15/15 live contract tests passed** against `http://127.0.0.1:8000` with the real account |
| `flutter test` (after the fix below) | **26 passed, 1 skipped** |
| Device run | ✅ **Redmi 2409BRN2CY, Android 16, 360×820 dp** — the full critical path ran against the live backend; one layout bug found and fixed |

### Device run — what was exercised
Real phone (`CUVOHQ7HGU69EMQS`), debug build with
`--dart-define-from-file=config/device.json`, backend reached through
`adb reverse tcp:8000 tcp:8000`. The request log shows the whole Phase 2 critical path completing
end to end:

```
POST /auth/me/                                     login
GET  /auth/me/                                     profile
GET  /student/quizzes/list?page=1&size=20          tests list
POST /student/sessions/79/start-single-player/?duration_minute=10
GET  /student/sessions/multiplayer/70/info/        session info
GET  /student/sessions/multiplayer/70/questions/   questions
POST /student/sessions/70/finish-single-player/    submit
GET  /student/sessions/70/single-player-error-analysis/   review
```

Session **70** was created and scored on the server, so home → tests → start sheet → play → finish →
result → review all work on a real device. Screens confirmed visually: home (5 tabs, **no Chat**),
tests list (subject icons picked from `name`/`type`, `YANGI`, `PDF`/`AI` badges, `N savol`, no mock
participant count), start-test sheet (time chips with the recommended value starred), landscape rail.

Also checked:
- **Theme:** the dark default is correct (`providers.dart` falls back to dark and persists the
  choice) — the phone showed light only because the toggle had been used.
- **Duplicate request scare:** the first log showed `quizzes/list` twice; re-tested with sole control
  of the device and it fires **exactly once** per screen open. The duplicate was two navigations, not
  a bug.

### Bug found and fixed on the device: rail overflow in landscape
`RenderFlex overflowed by 73 pixels on the bottom` — `NavigationRail`,
`lib/features/shell/student_shell.dart`.

Rotating a 360 dp phone to landscape makes it **820×360 dp**: wide enough (≥ 600) to switch to the
rail, but too short for the brand plus five labelled destinations, which the rail lays out in a
Column that does not scroll. This violates the definition of done ("no overflow … portrait and
landscape").

Fixed by letting the rail scroll while still filling the height
(`LayoutBuilder` → `SingleChildScrollView` → `ConstrainedBox(minHeight)` → `IntrinsicHeight`), so no
destination becomes unreachable. Verified on the device: zero overflows or exceptions after the fix.

Covered by a new regression suite `test/student_shell_test.dart` (4 tests): phone portrait uses the
bottom bar with all five tabs and **no Chat**; landscape switches to the rail without overflowing; a
very short viewport still reaches `Profil` by scrolling; tablet vs large screen pick the right rail
mode. The landscape test was confirmed to **fail without the fix and pass with it**.

### Live contract suite — `test/live_api_test.dart`
Runs the **real repositories** (`AuthRepository`, `TestsRepository`, `SessionRepository`) through the
real `ApiClient`/`AuthInterceptor` against a running backend, so model parsing and error mapping are
checked against live data rather than fixtures. Skipped unless explicitly enabled, which keeps
`flutter test` hermetic:

```bash
EDUNOVA_LIVE=1 EDUNOVA_TEST_USER=... EDUNOVA_TEST_PASS=... flutter test test/live_api_test.dart
```

Only side-effect-free GETs are used; `multiplayer/{id}/results/` and `.../topic-statistic/` are
never called. What it pins down:
- login yields a readable JWT `exp`, a student profile, and **`profile_image: null`** (so the app
  must follow up with `/auth/me/`); a forced refresh keeps the session alive;
- `/auth/me/` resolves the nested `{id, subject:{id}}` subject rows; every subject's `icon` is empty;
- quizzes paginate without repeats, parse **`quiz_id`** (not `id`), and an **empty `search` is
  dropped** rather than sent as `search=` (which the backend rejects);
- quiz detail carries no options while `question/detail/{id}` adds exactly one correct option, with
  labels in `A, B, C…` order;
- history keeps unfinished rows honest — `null` counts, `percent == 0`, no duration;
- session info parses the `+05:00` offsets, and `deadline_at > started_at`;
- play questions **never leak `is_correct`**;
- review survives the `question_id`-is-really-the-quiz-id bug — ids stay distinct;
- a result rebuilt from review adds up, and leaves `spend_time` **unset instead of faked**;
- the leaderboard is re-ranked client-side with `null` scores **last**, not first as the API returns
  them;
- a 404 and a bad password both surface a non-empty message **without** clearing a live session.

### Code as written earlier (unverified at the time)

**Screens and routes (full screen, opened over the tabs):**
- `/tests`: the student's quizzes with debounced search and infinite scroll (`PagedListView`).
- `/tests/:quizId`: header, difficulty split, question list, and a question preview sheet with the correct answer.
- **Start sheet:** time options 10–120 min with a recommended value, then `start-single-player`, then play.
- `/session/:id/play`:
  - countdown from `deadline_at`, auto-submit at 0;
  - progress saved to `shared_preferences` and restored;
  - `PopScope` asks before leaving;
  - on app resume the timer is recomputed and the socket reconnects;
  - multiplayer: sends `answer` and `change/question/order`, listens for `session_finished` on the room socket;
  - phone: bottom bar and map sheet; tablet: side panel.
- `/session/:id/result`: shows the finish response, or rebuilds it from the review data when opened later. Includes score ring, grade, stats, topics with a "weak" filter, and actions.
- `/session/:id/review`: filters (all / wrong / unanswered), pager, map, and correct/wrong highlighting.
- `/results`: summary, sorting, history cards (result, review, leaderboard sheet), unfinished badge.

**Home:** "Testlar" and "Natijalar" tiles.

**Shared widgets (`core/widgets/quiz/`):**
- `MathText`: LaTeX via `flutter_math_fork`; strips ANSI codes; falls back to plain text.
- `MarkdownTable`, `OptionTile`, `QuestionView` (images with zoom), `QuestionMapGrid` and sheet.
- `Pill`, `DifficultyChip`, `SubjectBadge`, `SubjectIconTile`, `GradeBadge`, `ScoreRing`.

**Utils:** `formatters` (Uzbek dates, clock), `Grade`, `SubjectStyle`, `math_segments`.

**Tests:** `test/phase2_test.dart` covers math parsing (ANSI included), the markdown table, option sorting, leaderboard ranking, `FinishResult.fromReview`, and `PlayController` (save/restore/submit, auto-submit).

Not in this phase: the "Multiplayer" button on quiz cards (phase 3) and quiz editing (phase 6).

## Phase 3: Realtime and competition ✅ built and verified (2026-09-11)

Every endpoint was confirmed with a real request **before** its model was written (`CLAUDE.md`),
using the owner's permission to create test sessions 71 and 72. The findings are in
`docs/API_CONTRACT.md` ("Phase 3 live verification") and `docs/BACKEND_ISSUES.md` #31–#38.

**Screens and routes**
- `/competition/new` — three-step wizard (quiz → participants → duration), optional `?quizId=`
  preselection. Enforces 1..180 minutes client-side because the schema declares no bounds, and maps
  `"Ba'zi savollarda to‘g‘ri javob belgilanmagan."` to a readable error.
- `/session/:id/lobby` — join code (copy + share), quiz header, participant list, invite sheet,
  host start, leave with confirmation, live socket status. Moves to the play screen on
  `session_started`, or immediately when the session is already `running`.
- `/notifications` — filters (Barchasi / Testlar / Do'stlar / Tizim), `BUGUN`/`OLDINGI` grouping,
  relative times, per-type actions, mark one / mark all read, live prepend of pushed notifications.
- Join-by-code sheet and a competition entry on the home screen, plus the app-bar bell with a live
  unread badge.

**Realtime**
- Room socket `/ws/quiz/sessions/{id}` with a `ping` heartbeat; handles `participant_joined`,
  `participant_ready` **and** `participant_read`, `participant_reconnected`,
  `participant_disconnected`, `session_started`, `session_finished`. Ignores `chat_message` and the
  spurious `error` that every `ping` provokes. Reconnects and refreshes on app resume.
- Notification socket `/ws/notifications/{userId}` feeding both the list and the badge
  (`notification_count_update`).

**Deliberately absent** (`CLAUDE.md` default decision 4): no ready toggle — connecting to the room
socket is what marks a student ready server-side — no kick, and no room chat.

### SocketService fix
A rejected handshake surfaces as an **HTTP 401/403 on the upgrade**, not a `1008` close frame, and
`accessToken()` only refreshes a token that is within 60 s of expiry. A token rejected earlier than
that would have retried forever behind exponential backoff. The service now forces one token
refresh after the first handshake failure and retries immediately, falling back to backoff after
that, and stops for good when the refresh token is gone too.

### Gates
| Gate | Result |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | **42 passed**, 1 skipped (the live suite) |
| Device | Redmi 2409BRN2CY, Android 16, 360 dp — home → bell (badge `7`) → notifications → accept invite → join → lobby, all against the live backend; **0 exceptions, 0 overflows** |

`test/phase3_test.dart` (16 tests) pins the logic to payloads captured live: join codes are
uppercased (the backend compares case-sensitively — the lowercase form really returns `404`), both
ready-event spellings map to one event, a naive `joined_at` is UTC, participants who left are
excluded from the room count, competition-result text is rebuilt in Uzbek from the payload, and a
pushed notification without `is_read`/`created_at` counts as unread.

### Two defects found on the device and fixed
- The notification list was fetched **three times** when the screen opened, because the screen asked
  the badge to recount from the server although it already held the rows. It now hands the badge the
  count it computed.
- `Bildirishnomalar` plus a "Hammasini o‘qildi" text button did not fit 360 dp and the title
  truncated to `Bildiris…`. The action is now an icon button with a tooltip.

### Documentation fix
`parseTashkentDate`'s docstring recommended itself for `joined_at`. That is wrong: `joined_at`
arrives without an offset but is **UTC** (session 71 was created at 21:38 Tashkent time and the row
reads `16:38`), so using it would have shifted every join time by five hours. The docstring now says
so and points at `parseUtcDate`.

### UI/UX pass against the running web (2026-09-11)

The first cut of these screens was built from `docs/student-pages-analysis.md` and my own layout
judgement, not from the web itself — so the texts were invented and the layouts diverged. The owner
caught it. The web was then opened at `http://127.0.0.1:5174` at a 375 dp viewport and every Phase 3
page was compared side by side, with the design taken from the web and the details adapted for a
phone.

**What changed**

| Screen | Before | Now (from the web) |
|---|---|---|
| Notifications | app-bar title, filter chips, medal emoji, one-line body, full-width buttons | large page heading, **dropdown** filter, coloured icon tile, **inset message panel** with the quiz name and place emphasised, `1-o'rin medali` / `0% natija` badge pills, `Kod: XXXXXX` line, side-by-side actions, footer with relative time and a **dismiss** button |
| Waiting room | plain card, two outline buttons, inline facts | in-page header with the connection pill, **indigo gradient** code panel (`#6366F1 → #A78BFA`), full-width `Kodni nusxalash`, **green gradient** `Do'st qo'shish` (`#22C55E → #10B981`), amber `Sessiya ma'lumotlari` card, participants card with ready pill, `Host` badge and avatar status dot, `Testni boshlash` |
| Competition | one step at a time with a progress bar | one scrolling page: header, `N/3 bajarildi` progress, **gradient hero** with the four feature pills, three step cards that collapse once filled, `Musobaqa xulosasi`, gradient CTA |

**Copy** now comes from the web instead of being invented: `Musobaqa kodi`, `Kod nusxalandi!`,
`Do'stlaringizni bu kod bilan taklif qiling`, `Barchasini o'qilgan qilish`, `Hozir` / `Kecha`,
`Kamida 2 kishi kerak`, `Xonadan chiqishda xatolik yuz berdi`, the connection labels, the step
titles and helper texts, and the congratulation sentence.

**Adapted for mobile rather than copied**
- the quiz dropdown became a **bottom sheet with search** and large rows;
- the typed number fields became **−/+ steppers with preset chips**, so the keyboard never opens;
- finished steps **collapse** to a one-line recap with an edit affordance, keeping the call to
  action reachable on a 360 dp screen;
- picking a quiz pre-fills sensible defaults (4 kishi, 30 daqiqa) so the flow needs one decision,
  and the summary can never disagree with what the steppers display;
- `Rad etish` sits beside `Qabul qilish` instead of wrapping.

Verified on the device: **0 exceptions, 0 overflows**; `flutter analyze` clean; **43 tests** pass.

### UI/UX pass, part 2: tests list and the play screen (2026-09-11)

Both opened in the running web at 375 dp, then rebuilt — design from the web, sizing and controls
chosen for a phone.

**Tests list** (`StudentTestsPage.tsx`)
- in-page header `Testlar` / `Mavjud testlar ro'yxati`;
- **gradient hero** with the lightning tile, the web's subtitle and the three counters
  (`N ta test`, `N ta yangi`, `N ta fan`);
- a `• N ta test topildi` result line;
- cards with the subject icon tile, the `Matematika` / `YANGI` / `PDF` badge row, title,
  description, meta chips (`30 savol`, `~30 daqiqa`, date) and a **gradient primary action**.
- `PagedListView` gained an `onLoaded` callback so the hero counters come from the page already
  fetched instead of a second request.

**Play screen** (`StudentTestTakingPage.tsx`)
- the `AppBar` became the web's **status bar card**: `Savol 1/30`, the green answered badge, the
  progress bar with its percentage, the countdown pill, the question-map button and the submit
  button;
- countdown colours match the web exactly — red under 5 minutes, amber under 10, green above;
- the bottom bar is now `Oldingi` / `Keyingi`, turning into a green `Yakunlash` on the last
  question.

**Adapted rather than copied**
- the web's `0 ta` participant count and its guessed difficulty pill stay out — both are invented
  client-side and `CLAUDE.md` decision 2 drops them; the real `N savol` carries that weight;
- the web's book icon in the play header was dropped: at 360 dp that space is worth more to the
  counter and the controls;
- the card's duplicated question counter was removed now that the status bar owns it;
- buttons are 46–50 dp tall (above the 44 dp minimum), status-bar icon buttons 40×40;
- `Testni boshlash` on a card became `Boshlash`: at 360 dp the full label truncated `Musobaqa`
  next to it. Tapping the card itself opens the detail, so the extra eye button went away.

`analysis_options.yaml` now pins `formatter: page_width: 100`, because `dart format` had reflowed a
file to its 80-column default, against the rest of the codebase.

Verified on the device: **0 exceptions, 0 overflows**; `flutter analyze` clean; **43 tests** pass.

### UI/UX pass, part 3: quiz detail, review and results history (2026-09-11)

Each opened in the running web at 375 dp, then reworked.

**Quiz detail** — an in-page header with the quiz name, the info card gained the web's **accent
strip**, difficulty cards read `N ta` over `Oson/O'rta/Qiyin savollar`, the primary action is the
gradient button, and the questions section carries `N ta savol ko'rsatilmoqda` with an `N ta jami`
pill. The web's `Faol` status, created date, `0 urinish` and the per-question `88%` accuracy stay
out — all four are invented client-side (`CLAUDE.md` decision 2). The card no longer repeats the
title the page header already shows.

**Review** — the app bar and chip row became the web's **status bar**: back, `Xatolar tahlili`,
`N / M savol`, the question-map button and the `Barchasi` / `Xato (n)` / `Javobsiz (n)` filters.
Questions get a `#N` badge, and the verdict panel now matches the web:
`Siz bu savolga noto'g'ri javob bergansiz!` over `Sizning javobingiz: C • To'g'ri javob: B`.
The bottom bar is `Oldingi` / `Keyingi`.

**Results history** — in-page header, the summary card became a score ring beside a **2×2 stat
grid** (`Sessiyalar`, `Eng yuqori`, `Jami vaqt`, `Savollar`), and the sort row gained the web's
`Saralash:` label and `N natija` pill. ⚠ `Jami vaqt` is computed from **finished sessions only**;
the web adds unfinished ones and reports nonsense (web bug #5).

**Shared widgets extracted** now that the patterns repeated: `PageHeader` + `SquareIconButton`
(used by tests, competition, lobby, quiz detail, results, review) and `GradientButton` (tests card,
quiz detail, competition CTA). `formatMinutesCompact` was added because `Jami vaqt` truncated in its
tile as `12 so…`.

Verified on the device: **0 exceptions, 0 overflows**; `flutter analyze` clean; **44 tests** pass.

### UI/UX pass, part 4: home and profile (2026-09-11)

Both pages on the web are dominated by invented gamification, so this pass took the **layout** and
filled it with real data.

**Home** — greeting with the time-of-day line and `school • class`, then:
- ⚠ the web's four stat cards (`40 Jami testlar`, `7 kun Streak`, `1560 Jami XP`, `#4 O'rin`) are
  hard-coded in `StudentHomePage.tsx`. Replaced with **three real cards** from
  `analytics/overall/cards`: sessions, correct answers, average (`CLAUDE.md` decision 1);
- the indigo **"Test ishlash" hero** with the `ASOSIY` pill and the play circle;
- a 2×2 **quick-action grid** (Testlar, Natijalar, Musobaqa, Jonli sessiya) in the web's card style;
- the **competition card** with its feature pills — minus `+12 do'st onlayn`, which is fabricated
  (decision 2), and minus the hero's `~15 min` estimate for the same reason;
- **"Mening fanlarim"** from `analytics/subjects`: percentage, progress bar, correct / wrong / total
  and the first and last attempt dates.

**Profile** — the web's gradient header kept, its contents replaced: avatar, name, `class • role`
and `@username`, then three translucent tiles carrying the same real `overall/cards` values. The
web's `Daraja 8`, `Top 10%`, XP, test count, streak, the level-progress card and all six
achievements are **left out entirely** (decision 1).

New `features/analytics/` layer (`OverallStats`, `SubjectStats`, repository and providers) backs
both pages; it is what Phase 5's statistics screen will build on.

`flutter analyze` clean, **44 tests** pass, and the device log shows the new home rendering with
**0 exceptions and 0 overflows** while both analytics endpoints fire. The side-by-side screenshot
check of home and profile is still pending — the phone locked itself before it could be taken.

### UI/UX pass, part 5: the result screen; login and register reviewed (2026-09-11)

**Home and profile verified on the device.** Home shows the real `25 / 26 / 26%` where the web
hard-codes `40 / 7 kun / 1560 XP / #4`, and "Mening fanlarim" reproduces the web's own numbers
(Matematika 27.03%, Fizika 24.00%) from `analytics/subjects`. Profile keeps the gradient header with
those same real values and none of the gamification.

**Result screen** — the web page could only be seen with its fabricated fallback data
(`Fan olimpiadasi - 2026`, 60%), which is the bug `student-pages-analysis.md` §3.7 describes, so the
**layout** was taken and filled with the real result:
- the grade word is now a **pill** and follows the web's `getPerformanceLabel` buckets
  (`A'lo` ≥80, `Yaxshi` ≥60, `Qoniqarli` ≥40, `Zaif`), with `Grade.letter` left on its own
  thresholds because the history cards use it;
- added the web's summary line `Yakunlandi: N ta to'g'ri, N ta xato, N ta javobsiz`;
- "Mavzular tahlili" gained the icon tile and the `N ta mavzu` subtitle;
- the actions are now `Xatolar tahlilini boshlash` (gradient) and `Yangi test yechish`.

When a result is opened later it is rebuilt from the review endpoint, and `Vaqt` then shows `—`
rather than an invented number — no endpoint replays `spend_time` (backend issue 25).

**Login and register** were checked against `pages/common/LoginPage.tsx` and `RegisterPage.tsx` and
**already match**: `Foydalanuvchi nomi`, `Parol` with `••••••••`, `Ism` / `Familiya`,
`Kamida 8 belgi`, `Parolni qayta kiriting`. Nothing was copied from the web's auth chrome: it is
branded `EduPanel — O'qituvchi boshqaruv tizimi` (the teacher panel) and carries the Google and
Telegram buttons that default decision 5 removes.

Verified on the device: **0 exceptions, 0 overflows**; `flutter analyze` clean; **46 tests** pass
(two new ones pin the grade wording to the web's buckets).

Every screen built so far has now been compared against the running web.

## Phase 4: Groups — built, device check pending

Every endpoint was confirmed live in Phase 0 (all `200`, shapes recorded in `API_CONTRACT.md` §8);
the three web pages were opened at 375 dp and the design taken from them.

**Data layer** — `features/groups/`:
- `GroupColor` / `GroupStatus` parse **case-insensitively**, because the server sends `BLUE` and
  `ACTIVE` while the schema declares them lowercase (issue 17) — and the web's own colour map has no
  entry for `VIOLET`;
- `AccuracyBand` implements the web's legend (≥75% oson, 50–74% o'rta, <50% qiyin);
- the repository sorts member performance best-first, since the web's podium order is wrong
  (web bug #4), and carries the list's `cover_image` into the detail card, which always returns
  `null` (issue 18 / 28).

**Groups list** — heading, a controls card with search and a sort dropdown
(`Nom / Fan / Faollik bo'yicha`), then cards with the coloured tile, subject, status dot,
description, three stat boxes and the relative last-activity footer.

**Group detail** — header card with the four group numbers, a **top-3 podium** with medals, the
assigned tests (percentage pill, `N/M ta`, date, progress bar) and every member's accuracy with a
name filter and a "show all" toggle. Dates are formatted properly; the web prints `M09 11`
(web bug #3).

**Group session result** — status header with the quiz name, four summary tiles
(`O'rtacha / Eng yuqori / Eng past ball`, `Qiyin savol`), the session ranking, per-question accuracy
bars with the legend, the student table and **PDF export**. Both ids come from the route, so a reload
cannot break it the way the web's router state does (web bug #2).

**PDF** — `SessionResultPdf` builds an A4 document (header, summary boxes, ranking table, accuracy
table, page footer) and `Printing.sharePdf` hands it to the system share sheet. It takes plain data
rather than widgets, so it can be unit-tested. New packages: `pdf`, `printing`, `path_provider`.

`PagedListView` gained a `transform` hook so a list can be sorted client-side for endpoints that
offer no ordering.

### Verified on the device, with two layout fixes

The groups list, the group detail and the leaderboard render correctly against the live backend.
Dates read `11-sentyabr, 2026` where the web prints `M09 11`, and the podium is ordered properly.

Two things were too cramped on a 360 dp phone and were fixed after seeing them:
- **`O'quvchilar ko'rsatkichi`** gave each student two tall boxes for `To'g'ri` and `Noto'g'ri` —
  two numbers eating most of the card. They are now inline counters
  (`✓ 2 to'g'ri   ✗ 13 noto'g'ri   10%`) above the progress bar, so three students fit where one and
  a half did.
- **`So'nggi faollik`** truncated to `5 soat ol…`. Added `formatRelativeShort`, which drops the
  trailing "oldin" for narrow tiles (`5 soat`), with a test.

`flutter analyze` clean, **47 tests** pass, **0 exceptions and 0 overflows** on the device.

**Note for future native-dependency changes:** adding `pdf`/`printing` made Flutter uninstall and
reinstall the app, which cleared secure storage and signed the session out. A plain
`adb install -r` avoids that; the uninstall path also trips Xiaomi's "Install via USB" restriction.

## Phase 5: Statistics, friends, profile edit ✅ built and verified on the device (2026-09-12)

### Statistics — `lib/features/statistics/statistics_screen.dart`
Web layout (`StudentStatisticsPage.tsx`) with the mock dropped:
- **three** stat cards from `analytics/overall/cards` (`Jami testlar`, `O'rtacha ball`,
  `To'g'ri javoblar`). The web's fourth card, `975 Jami XP`, is `sessions × 39` on the client —
  hidden per default decision 1;
- **"Haftalik faollik"** as an `fl_chart` bar chart. The web hard-codes `[4,7,3,8,5,2,6]`; this
  counts sessions per day from `/sessions/me/history/` (default decision 3). History only records
  when a session was *created*, so the subtitle says exactly that:
  "Oxirgi 7 kunda boshlangan sessiyalar". Empty week → "Oxirgi 7 kunda sessiya bo'lmagan";
- the left axis uses at most five labels and ends on a round one, instead of printing `0..11`;
- **"Fanlar bo'yicha natija"**: the web's ✓/✗ percentages plus the real counts
  (`20 to'g'ri · 54 xato · 74 jami javob`), which the web does not show;
- **"AI Tavsiyasi"** with the backend's own three blocks and their actions
  (`Davom etish` / `Mashq qilish` / `Testni boshlash`). Whole blocks are hidden when the endpoint
  omits them; the card disappears entirely when all three are missing.

### Friends — `lib/features/friends/`
- `friends_screen.dart`: subtitle, search + gradient `Qo'shish`, the "Mening do'stlarim" header with
  its count badge, and one card per contact. A `teacher` contact gets an `O'qituvchi` badge, since
  `contact/list/` really does return teachers;
- the web's green "Hozir onlayn — N do'st" banner, the per-row online dot and "Faol emas" are
  invented (no presence endpoint) and are hidden; the row's chat button is out of scope;
- `widgets/add_friend_sheet.dart`: suggestions with an empty query, `users/search` once typing
  starts, the "N foydalanuvchi topildi" strip, and an add button per row.

**The trap in `contact_available`** (backend issue 42): it is `true` when the user is **already** a
contact. Verified live — the one existing contact came back `true`, a stranger `false` — so only
`false` gets an add button; everyone else shows `✓ Do'st`.

### Profile edit — `lib/features/profile/`
- `domain/profile_edit.dart`: `ProfileForm` (validation + the web's 7-field completion percentage)
  and `ProfilePatch.diff`, which sends **only the changed fields**; the web re-sends everything;
- `data/profile_repository.dart`: `PUT /users/{id}/` and the multipart avatar upload, whose part
  `Content-Type` is set explicitly because the backend picks the extension from it;
- `presentation/profile_edit_screen.dart`: completion bar, avatar with the camera button
  (`image_picker`), "Shaxsiy ma'lumotlar", "Ta'lim" (school + the `EducationLevel` dropdown) and
  "Fanlar" chips. "Parolni o'zgartirish" is hidden — no endpoint (default decision 5);
- blanks are sent as `null`, never `""` (which is a raw pydantic 422); the email is checked on the
  client so the user never sees that message;
- an empty subject selection is refused with "Kamida bitta fan tanlang", because the backend
  **ignores** `subject_ids: []` and would silently keep the old list (issue 40);
- leaving with unsaved changes asks first; after a save the form is marked clean and the screen
  closes — falling back to the profile tab when it was opened as a restored route.

### Verified on the device
Statistics (3 cards, chart, subjects, all three advice blocks), friends list, the add sheet
(suggestions → search → `✓ Do'st` for an existing contact → adding `@shehroz3`, which flipped the
row and reloaded the list to 2), and profile edit: `11-sinf`, then `42-maktab`, then the phone —
each saved, propagated to `/auth/me/` and shown on the home and profile screens.

Two defects found and fixed while testing:
1. after a save the screen stayed open, because `PopScope` still saw the form as dirty — the form is
   now marked clean and the pop waits one frame;
2. `Navigator.pop` did nothing when the edit screen was the restored initial route — it now falls
   back to `context.go(Routes.profile)`.

Five new backend issues documented (39–43): the **unauthenticated avatar upload**, the ignored empty
`subject_ids`, the useless `PUT` response, the backwards `contact_available`, and the raw 422 on
`email: ""`.

`flutter analyze` clean, **63 tests** pass.

## Phase 6: Quiz creation and the question editor ✅ built and verified on the device (2026-09-12)

### Quiz creation — `lib/features/quiz_create/`
The web's three-step `CreateQuizModal` as a full screen, since a phone has no room for a modal:
1. **method** — two cards, `PDF fayldan` (`~2-3 daqiqa · Avtomatik`) and `AI bilan yaratish`
   (`~1-2 daqiqa · Intellektual`), with the web's own descriptions;
2. **form** — PDF: a picker showing the file name and size with `O'chirish`; AI: the real subject
   list, the web's `Tavsif` placeholder, and a **stepper** for `Savollar soni` (5–50) because a
   number field is awkward on a phone;
3. **progress** — `AI JARAYONI`, the backend's own Uzbek step text, `Jarayon holati` and the bar.

- **`/ws/jobs/{id}/` plus a 3 s poll**, as `docs/api-notes.md` §11 requires. Whichever reports a
  terminal status first wins, and the client closes the socket itself — the server keeps it open
  after a snapshot of an already-finished job.
- Success is `status == completed && quiz_id != null`, never the progress bar: a **failed job also
  reports 100%** (issue 47).
- The failure card shows the backend's Uzbek `message`; `error` quotes the AI provider in English
  and is never displayed.
- A job that stops moving for 6 minutes ends with "Jarayon juda uzoq davom etdi", because the
  backend has no deadline of its own.
- The PDF cap is **5 MB** (`settings.MAX_PDF_SIZE`), not the web's advertised 10 (issue 49).
- `file_picker` had to be **10.x**: 8.x compiles against android-34 and fails the build.

### Question editor — `lib/features/question_edit/`
Tablet-first per default decision 6: on a large screen the form and a live preview sit side by
side, on a phone the preview follows the form. Editable: question text (LaTeX), topic, difficulty,
the correct option and the images (max 2) — exactly what the API supports. The card says plainly
"Javob variantlarining matnini o'zgartirib bo'lmaydi", because no endpoint exists for it (issue 50).
Only changed fields are sent; leaving with unsaved changes asks first.

### Verified on the device
- **AI generation end-to-end**: Matematika + a description + 5 questions produced quiz #81
  ("Kvadrat Tenglamalar va Vietta Teoremasi") in about ten seconds, and the app opened it.
- **PDF generation**: verified against the live job socket — 66% → 74% → 80% → 85% → `completed`,
  quiz #80 with 30 questions.
- **Editor round trip**: question 1318 `o'rta` → `qiyin` → back to `o'rta`; each save reached the
  backend, and the quiz list updated in place.

Two defects found and fixed while testing:
1. the preview sheet clipped its own content — a `ConstrainedBox` of 85% of the screen exceeded the
   height the sheet actually had, so the inner scroll view never scrolled and the new
   "Tahrirlash" button was cut off. It is now a `DraggableScrollableSheet` with the sheet's own
   controller;
2. the quiz list did not refresh after a save, because the sheet navigated to the editor itself and
   the row's `await push` therefore never resolved. The sheet now just returns "edit me" and the row
   owns the navigation — confirmed by the refetch of `student/quizzes/81/` in the device log.

Seven new backend issues documented (44–50), including two security ones: **`PUT /question/{id}/edit`
has no ownership check** (a missing `await` makes the guard dead code and the repository query
ignores the user), and **image upload writes the client's file name verbatim** with no type check.

`flutter analyze` clean, **80 tests** pass.

## Tablet pass, part 1 — verified on a real tablet (Lenovo TB361FU, 1280 dp, 2026-09-12)

The web is the reference here too: its shell switches to a sidebar only at `lg` (1024 px), so at
768 px it still shows the phone layout, but its **content** grids widen. The app keeps the
`NavigationRail` that `CLAUDE.md` requires and takes the per-page layout from the web.

**First finding on the device:** requests failed because the installed APK had been built without
`--dart-define-from-file=config/device.json`, so it called `10.0.2.2:8000` (the emulator address).
Rebuilt with the device config, plus `adb reverse tcp:8000 tcp:8000` for that device.

| Page | Was | Now |
|---|---|---|
| Bosh sahifa | four action tiles at `childAspectRatio: 1.05` were 205 dp tall and almost empty; stat cards centred in 313 dp of space | tiles use a fixed `mainAxisExtent: 152`; on a tablet the stat card puts the icon beside the number |
| Guruhlar | app bar and page both read "Mening guruhlarim"; search over sort; one full-width card | bar keeps the tab name; search and sort share a row; cards in **2 columns**, as the web does |
| Do'stlar | one row per friend across 1000 dp | **2 columns** |
| Natijalar | "Saralash:" and the chips on separate lines | one line on a tablet, as the web does |
| Bildirishnomalar, Musobaqa yaratish, Kutish xonasi | full-screen routes stretched edge to edge with no cap | wrapped in `ContentConstraint` like every tab page |

`PagedListView` gained a `columns` parameter so any paged list can become a grid.

## Bosh sahifa + light tema, webga moslash (2026-09-12)

Compared against the web's own light theme at 375 px.

- **"Test yaratish" kartasi qo'shildi** — the web's quick-action grid leads with it and has **no**
  "Musobaqa" tile; competition is reached from the "Do'stlar bilan ishlash" card below, which the
  app already had. The app's grid now matches: Test yaratish · Testlar · Natijalar · Jonli sessiya.
- **Tinted action tiles.** The web washes each tile with its own accent
  (`rgba(accent, .12→.08)` dark, `.07→.04` light) with a matching border; the app drew four
  identical grey cards. Now each tile carries its accent in both themes.
- **`cardShadow` token added.** The web's `shadowCard` is what lifts a white card off the near-white
  page in light mode — a 1 px border alone cannot. `AppColors` now carries it per theme and
  `AppCard` applies it. This was the biggest reason the app's light theme felt flat next to the web.
- **Hero gradient fixed.** The web uses a **three-stop** gradient that ends in blue and differs per
  theme (`#4C1D95→#6366F1→#3B82F6` dark, `#6366F1→#4F46E5→#3B82F6` light) plus an indigo glow. The
  app had a fixed two-stop indigo→purple, which read far more purple than the site.

Also fixed while testing on the phone: the default `API_BASE_URL` was `10.0.2.2` (the **emulator**
address) whenever the dart-define was missing, which had now broken three separate installs. The
default is `127.0.0.1:8000` — right for a real device with `adb reverse` — and the emulator keeps
`config/dev.json`.

## Header + logo (2026-09-12)

**Header, ported from the web's `StudentLayout` mobile bar** (checked in light mode):
- the bar sits on `bgCard` with a hairline bottom border, not on the page background;
- the two actions are 36×36 `rounded-xl` tiles instead of bare icons, theme toggle **first**;
- the toggle flips both tint and glyph the way the web does: an amber tile with an **indigo moon**
  in light mode, an indigo tile with an **amber sun** in dark;
- the bell sits on `bgInner` with a `border` outline and an 8 px unread dot ringed in the header
  colour.
New shared widgets: `HeaderButton` and `HeaderDot`.

**Logo.** The owner picked the "open book under a nova spark" mark. Drawn geometrically, so the
launcher icon and the in-app mark are the same shape:
- `BrandMarkPainter` renders it in-app at any size, in any colour;
- Android: `ic_launcher.png` at all five densities, plus an **adaptive icon** — a gradient
  background drawable (`#8B5CF6 → #6366F1`) and a foreground inside the 66 % safe zone, also used
  as the monochrome layer;
- iOS: all 15 `AppIcon` slots, flattened onto white since iOS icons cannot be transparent.

This is the one place the app deliberately differs from the web, which still uses a lightning bolt.

## Natijalar sahifasi, webga moslash (2026-09-12)

Checked against the web page in both themes at 375 px.

- **Search**, which the app did not have at all: a toggle in the header opens the field, exactly as
  the web does. The web filters server-side; the history is already loaded here, so the filter is
  local and matches the same two fields — quiz title and subject.
- **"Ko'rish" sheet** (`result_detail_sheet.dart`), the web's detail modal: score and grade, the
  To'g'ri / Noto'g'ri / O'tkazilgan tallies, a segmented progress bar with its legend, the detail
  rows, and a button through to the error analysis. Everything comes from the history row, so it
  opens without a request. The web's "Quiz ID" row is dropped — it means nothing to a student.
  The card's first button was "Tahlil", which jumped straight to the review; it is now "Ko'rish"
  and opens this sheet, with the review one tap further in.
- **Card redesigned** to the web's shape: score pill beside the grade badge, a progress bar, and the
  counts as rounded chips instead of bare icons — previously a lone grade badge floated at the right
  edge.
- **Summary tiles are tinted** per accent in both themes, and "12 soat" no longer clipped to
  "12 so…" (smaller ring, and the value scales down instead of ellipsing).
- **Sort chips wrap** instead of scrolling "Eng yomon" out of sight; `FilterChips` gained a `wrap`
  flag, and `SearchField` an optional external controller plus `autofocus`.

**Second pass on the same page:**

- **Sort chips** were wrapping onto two rows and left the counter stranded on a line of its own.
  `FilterChips` gained a `segmented` mode: for a short fixed set the three options now split the
  width evenly on one line, which beats both scrolling (clips "Eng yomon") and wrapping on a phone.
- **Card actions carry the web's colours**: "Ko'rish" sky (`#38BDF8`, darkened to `#0284C7` on
  light) and "Reyting" indigo, each on its own tint with a matching border. Two identical outlined
  buttons read as the same action.
- **Reyting sheet rebuilt** to the web's modal: quiz title, tinted meta chips (participants,
  date, question count), a "Mening natijam" strip with its own bar, then the ranked rows — medal or
  rank, avatar, name with a "Siz" badge, score bar, and `correct / total` over the percentage.
  The percentage is shown once per row: "Mening natijam" carries it in the header, so its count
  block omits it.

The rating sheet **sizes itself to its content**: it was a `DraggableScrollableSheet` pinned at 72 %
of the screen, so a session with one participant floated above a screenful of empty sheet. It is now
a plain scroll view inside the modal's own constraints — short lists shrink, long ones stop at the
screen and scroll. `test/leaderboard_sheet_test.dart` covers both, and was checked against the old
behaviour: with the fixed sheet a solo participant measured **484 px** on a 720 px screen.

One bug found while testing: the segmented progress bar was drawn as nothing at all. A `Row` gives
its children a **loose** cross-axis constraint, so an empty `ColoredBox` collapsed to zero height;
it needs `CrossAxisAlignment.stretch`.

## Chat (Suhbatlar)

Chat was out of scope until the owner brought it in. It is now the **fourth tab**
(*Bosh sahifa, Guruhlar, Do'stlar, Suhbatlar, Statistika, Profil*) with the room, its info page
and the pickers as full-screen pages. `CLAUDE.md` records the scope change and the chat rules.

**Design first.** Seven screens in dark and light, generated from one source so the two themes
cannot drift: `docs/design/chat/` (published canvas linked in its README). Colours are lifted
from `app_colors.dart`; nothing new was invented.

**Transport split.** The list, history, chat/member metadata and the upload go over HTTP; every
mutation goes over `/ws/chat`. That is not a style choice — a message written over HTTP is stored
but never published to Redis, so the other member would not see it until a reload.

**All of `EventType` is wired.** Out: `message:new`, `message:forward`, `message:edited`,
`message:deleted`, `message:reaction_add`, `message:read`, `chat:created`, `typing:update`,
`chat:leaved`, `heartbeat:heartbeat`. In: the same set plus `message:ack`, `presence:update`,
`connection:ready` and `error`.

Three payload quirks cost real time and are now pinned by `test/chat_socket_test.dart`:

- a broadcast `message:new` is **not** a Mongo document — the text is `content` and the id is
  `message_id`, so `Message.fromJson` cannot parse it;
- `message:read` publishes **one** id under the plural key `message_ids`;
- `typing:update` has no `chat_id` of its own, so the server fills it from the Redis channel name
  and it arrives as a **string**.

**Optimistic send.** The server suppresses the sender's own echo per connection, so a sent bubble
is reconciled from `message:ack` via the `client_message_id` we generate — never from a
`message:new` coming back. Failed sends keep the bubble and mark it.

**Read receipts** come from the peer's `last_read_message_id`. Mongo ObjectIds begin with a
timestamp, so their hex strings sort in creation order and a plain string compare decides which of
our messages have been read. In a group the earliest cursor wins, so the second tick only appears
once everyone has caught up.

**Left out on purpose:** the design's media counters on the info page (128 rasm / 31 fayl /
54 ovozli). No endpoint reports them and inventing numbers is worse than omitting the row.

`url_launcher` was added for opening file attachments; images open in an in-app zoomable viewer.
Audio and video are rendered but not played inline — that needs a player package and is the
obvious next decision.


### Chat media and presence, second pass

Three things the owner found once it was on a real phone:

- **The mic button was decoration.** It rendered from the design but was never wired, and it was
  disabled whenever the field was empty — so it could not even be pressed. Recording now runs on
  `record` (AAC/m4a = `audio/mp4`, the type the upload allow-list takes) with a red timer bar,
  cancel and send. `RECORD_AUDIO` is in the manifest.
- **Media opened in a browser.** `url_launcher` handled audio and video, which drops the session
  and leaves the file unplayable. Audio now plays in the bubble through one shared `just_audio`
  player, a normal video opens an in-app `video_player` page, and a **round video message plays in
  place** with a playhead ring, Telegram-style. Only documents still leave the app.
- **Camera clips are `video_message`.** The attach sheet gained Video (gallery) and Video xabar
  (camera, round, capped at a minute); a clip from the gallery stays a rectangular `video`.

**Presence was inconsistent between the list and the room**, and the cause was not the obvious one.
`presence:{user_id}` is published *only* on an explicit connect or disconnect; when the 60 s Redis
key expires on its own — a client that was killed or lost the network — **no event is emitted at
all**. The room re-reads `GET /chats/{id}` every time it opens, so it was right; the list held its
load-time snapshot forever, so it stayed green. It now applies `presence:update` where it knows the
peer (learned from opened chats, since `GET /chats` does not return the peer's id), re-reads on a
debounce after any presence event, and polls at the TTL cadence plus on app resume. Verified by
setting and then silently deleting the Redis key: the dot went green, then grey on its own.

Two smaller fixes found while testing on the device: one tap could stop a recording and immediately
start another (the send button sits exactly where the mic reappears — both transitions await the
platform recorder, so they are now guarded), and a message of ours loaded from history showed no
tick at all until the peer read it, rather than the single "stored" tick it had earned.

`record` also had to move from `^5.2.0` to `^6.1.1`: the old constraint resolved
`record_linux 0.7.2` against `record_platform_interface 1.6.0`, which does not compile — and it
broke the **Android** build, not just Linux.


## Next
Tablet pass, part 2: test detali, guruh detali, sessiya natijasi, test ishlash, test yaratish and
profil tahrirlash still need the same treatment.

All six phases are built. Open: `docs/OPEN_QUESTIONS.md` still has 9 questions for the owner, and
the backend issues list (50 entries) is waiting on the backend team.
