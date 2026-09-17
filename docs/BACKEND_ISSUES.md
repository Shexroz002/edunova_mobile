# Backend issues found while building the mobile app

Each entry lists what happens, what should happen, and the client workaround.

| # | Endpoint | Problem | Expected | Client workaround |
|---|---|---|---|---|
| 1 | Quiz generation (PDF/AI) | 23 of 30 `question_text` values contain ANSI escape codes inside LaTeX (a raw `\x1B[3m` and the literal text `[23m`). Verified with quiz #79 on 2026-09-11. | Clean LaTeX | `MathText` strips both patterns |
| 2 | Quiz generation | The answer key can be wrong, e.g. "√(x²−4x+5)+√(2x²−8x+17)=4 nechta ildiz" is marked `B) 2`; the correct answer is `D) 1`. | Validation step or human review | none (display as is) |
| 3 | Quiz generation | Questions are not in PDF order. The `difficulty` values are inconsistent (`o'son`, `oson`, `o‘rta`). | Keep source order; use a fixed enum | `Difficulty.parse` normalizes |
| 4 | `POST /auth/me/` | The login response has `user.profile_image = null` because the service builds the key as `image_url`. | Return `profile_image` | call `GET /auth/me/` after login |
| 5 | `POST /auth/me/` | The username match is case-sensitive, while registration lowercases the username. | Case-insensitive login | lowercase before sending |
| 6 | `GET .../single-player-error-analysis/` | `question_id` holds the quiz id. Multiplayer joiners see the host's answers. | Real question id; the caller's own answers | use `id`; note it in the UI |
| 7 | `POST .../multiplayer/{id}/answer` | Answers are not persisted (they only reach Redis monitoring). | Persist answers | finish with `finish-single-player` and all answers |
| 8 | `GET .../leaderboard/` (session and group) | Rows with a `null` score come first. There is no `rank`. `spend_time_seconds` is a string. | Nulls last, include `rank`, numeric type | sort and rank on the client |
| 9 | `PUT /student/quizzes/{id}/` | Returns 500 after committing, because the response model mismatches. | 200 with the object | not used |
| 10 | `GET .../multiplayer/{id}/topic-statistic/` | Always 500 (KeyError). | Works | not used |
| 11 | `GET /student/group/{gid}/detail-card` | `cover_image` is always null. A non-member gets a plain-text 500. | Return cover; 403/404 for non-members | reuse the list value; generic error |
| 12 | Media URLs | Absolute URLs point to `BASE_URL=http://127.0.0.1:8000`, which a phone cannot reach. Avatar upload returns a relative path. | Public host from config; consistent format | `MediaUrl.resolve` rewrites |
| 13 | Session room WS | Every `ping` gets `pong` plus a spurious `error`. The ready event is named `participant_read` (typo). | `pong` only; `participant_ready` | ignore that error; accept both names |
| 14 | Web client (FYI) | `WEBSOCKET_BASE_URL` has no `VITE_` prefix, so the job socket always uses `ws://127.0.0.1:8000`. | `VITE_WS_BASE_URL` | n/a (mobile derives the WS URL from `API_BASE_URL`) |
| 15 | Notifications | `competition_result` title and message are in English. "Decline" has no endpoint for invites or friend requests. | Localized text; decline endpoint | build Uzbek text from the payload; decline is local only |
| 16 | Users | `PUT /users/{id}/avatar/` has no auth or ownership check. Profile update fails on `""` for the unique email/phone fields. | Owner-only; `""` treated as null | send only non-empty fields |

## Added 2026-09-11 (schema + backend-source review, Phase 0 follow-up)

| # | Endpoint / socket | Problem | Expected | Client workaround |
|---|---|---|---|---|
| 17 | `GET /api/v1/users/{user_id}/` | **Publicly readable — no auth.** Reproduced: `curl http://127.0.0.1:8000/api/v1/users/1/` → `200` with username, full name and avatar URL. Lets anyone enumerate users. | Authentication required | the app never calls it (it uses `GET /auth/me/`). **Security issue — needs a backend fix.** |
| 18 | Session room WS `session_finished` | The payload is `{session_id, quiz_id, reason, finished_at}` (`reason` ∈ `all_finished, time_expired, host_finished`), not the `{message}` recorded in `api-notes.md`. | One documented shape | parse tolerantly; show a generic Uzbek toast and auto-submit regardless |
| 19 | `GET /student/group/` and `.../detail-card` | `status` and `color` come back **uppercase** (`ACTIVE`, `VIOLET`) while `/openapi.json` declares `GroupStatus`/`GroupColor` as lowercase. The web's colour map misses `VIOLET` entirely. | Schema matches reality | parse case-insensitively with a fallback colour |
| 20 | `POST .../finish-single-player/` | `FinishQuizResponse` is returned **only** here; no endpoint serves it again later. | A "get result" endpoint | pass the object through the route; rebuild counts from `single-player-error-analysis` when opened later (`spend_time` is then unavailable). **Never fabricate a result** — the web does. |
| 21 | Auth | **No logout endpoint** exists. | Token revocation | logout clears tokens from secure storage locally |
| 22 | `POST .../multiplayer/{id}/start/` | The only check is `if not participants` — and the **host is always a participant** — so a host can start a "competition" alone. The web's 2-ready-participants gate exists only in the web. | A documented minimum | the app requires the host **plus at least one other** participant (open question 2) |
| 23 | `POST .../multiplayer/create/` | The schema sets **no bounds** on `duration_minutes`, and `max_participants` is stored but **never enforced** when players join. | Validated bounds; enforced capacity | the client enforces 1..180 minutes and treats `max_participants` as advisory |
| 24 | `POST .../{quiz_id}/start-single-player/` | `duration_minute` has no bounds and the server never stops a single-player session at the deadline. | Server-side enforcement | the client bounds the choice and **auto-submits at 0** |
| 25 | `GET /api/v1/subject/list/` | Only **two** subjects exist (Fizika, Matematika) and `icon` is `""`/`null` on both — while the web's registration rule demands at least 2, forcing a student to pick both. | Real subject catalogue with icons | app-side icons from `name`/`type`; the subject step explains the "both" situation |
| 26 | `analytics/topic` vs `quiz-generator/quiz/generate` | The same parameter name `subject` means a **name string** in one endpoint and a **numeric id** in the other. | Consistent typing | the two repositories keep the parameter separately typed |

## Added 2026-09-11 (live verification with the test account)

| # | Endpoint | Problem | Expected | Client workaround |
|---|---|---|---|---|
| 27 | `GET .../{session_id}/start-single-player/info` | Returns `questions: []` for a **multiplayer** session (reproduced on session 69), while `multiplayer/{id}/questions/` returns the real 20 questions. For single-player sessions the two agree exactly (checked on 9 sessions). | Either works for both, or the single-player route rejects multiplayer ids | **always** load questions from `multiplayer/{id}/questions/` |
| 28 | `GET /student/group/` and `.../detail-card` | `cover_image` is `null` in the **list** too, not only in the detail card — so the "reuse the list value" workaround has nothing to reuse. | Return the cover image | fall back to the `color` token for the card background |
| 29 | `spend_time_seconds` | Typed inconsistently: a **string** (`"45.548054"`) in `.../leaderboard/`, an **int** (`20`) in the `competition_result` notification payload. | One numeric type | tolerant `asDouble` accepts both |
| 30 | `GET /student/group/{gid}/question-accuracy/{sid}` | Returned **15** rows for a session whose leaderboard reports `total_questions: 20`. Unanswered questions appear to be dropped. | One row per quiz question | render only the returned rows; never assume the count equals `total_questions` |

## Added 2026-09-11 (Phase 3 live verification, sessions 71 / 72)

| # | Endpoint / socket | Problem | Expected | Client workaround |
|---|---|---|---|---|
| 31 | `POST .../multiplayer/create/` | The `201` body has `quiz_name: null` and `subject_name: null`, although `GET .../{id}/info/` fills both for the same session. | Return the quiz name it already knows | the lobby ignores create's names and calls `info/` |
| 32 | `POST .../multiplayer/join/` | The join code is **case-sensitive**: the exact code works, the same code lowercased returns `404 "Invalid session code"`. Codes are shown to users to retype. | Case-insensitive lookup | the code field force-uppercases every keystroke |
| 33 | Join-code generation | `generate_join_code()` draws from `ascii_uppercase + digits`, so codes mix visually identical characters — the session created in this pass was **`0O1VHN`** (digit zero next to letter O). Users mistype these. | An unambiguous alphabet (drop `O I 0 1`) | show the code in a monospace, letter-spaced style; cannot be fixed on the client for input |
| 34 | All WebSockets | A rejected handshake surfaces as an **HTTP status** (`401` for a bad token, `403` for a missing token or a foreign `user_id`), not a `1008` close frame, because the backend closes before `accept()`. | A documented close code, or a consistent status | `SocketService` inspects the upgrade exception's status and refreshes the token on `401`/`403` |
| 35 | `session_started` frame vs `start/` body | The REST body reports `+05:00` (`2026-09-11T21:40:27.010412+05:00`) while the socket frame for the same event reports `+00:00` (`2026-09-11T16:40:27.010412+00:00`). | One representation | always parse the offset; never assume `+05:00` |
| 36 | `POST .../multiplayer/leave/` | Returns `204` but **does not remove the participant** — the row stays in `participants/` with `participant_status: "disconnected"`, and it is still counted in `total`. | Remove the row, or document the soft state | the lobby hides/greys `disconnected` participants and excludes them from the "N ta ishtirokchi" count |
| 37 | Notifications socket payload | The pushed `data` omits **`is_read`** and **`created_at`**, which the REST list always includes (two different producers build the payload). | The same shape on both transports | the model defaults a pushed notification to unread with the arrival time |
| 38 | `POST .../multiplayer/{id}/start/` | **Reproduced live:** the host started session 71 alone — `participants_count: 1, attempts_created: 1`. Confirms issue 22 with a real request. | A documented minimum | the app requires the host plus at least one other participant (open question 2) |

## Added 2026-09-12 (Phase 5 live verification: profile, friends)

| # | Endpoint | Problem | Expected | Client workaround |
|---|---|---|---|---|
| 39 | `PUT /api/v1/users/{id}/avatar/` | **Reproduced unauthenticated:** `curl -X PUT .../users/2/avatar/` with no token returns `422 {"loc":["body","avatar"],"msg":"Field required"}` — body validation, not `401`. The route declares no `get_current_user` dependency and never compares `user_id` with the caller, so **anyone can replace any user's avatar**. Confirms and sharpens issue 16. | Authenticated, owner only | the app only ever uploads for the signed-in id. **Security issue — needs a backend fix.** |
| 40 | `PUT /api/v1/users/{id}/` | `subject_ids: []` is **silently ignored** (`if subject_ids:` in `UserService.update_user`), so a student can never remove their last subject. Verified: the account kept Fizika + Matematika after sending `[]`, response `200`. | Clear the list, or reject it with 400 | the edit form refuses to save an empty selection and says "Kamida bitta fan tanlang" |
| 41 | `PUT /api/v1/users/{id}/` | The response is `UserDetailPatchSchema` dumped **in full**, so every field that was *not* sent comes back as `null` (verified: sending only the two names returned `email:null, school_name:null …` while the stored values were untouched). The body therefore says nothing about the saved user. | Return the updated user | ignore the response and reload `GET /auth/me/` |
| 42 | `GET /api/v1/users/search` | `contact_available` is named backwards: `user_repo.users_with_contact_status` sets it to `true` when a `Contact` row **already exists**. Verified: the one existing contact came back `true`, a stranger `false`. A reader would add exactly the wrong people. | Rename to `is_contact`, or invert | only `contact_available == false` gets an add button; `contact/suggestions/` omits the field and is treated as addable |
| 43 | `PUT /api/v1/users/{id}/` | `email: ""` fails with a raw pydantic `422` ("An email address must have an @-sign"), and `email`/`phone_number` are unique columns, so a duplicate surfaces as a database error rather than a validation message. | `""` treated as `null`; a friendly conflict error | blanks are sent as `null`; the email is validated client-side before the request |

## Added 2026-09-12 (Phase 6 live verification: quiz generation, question editor)

| # | Endpoint | Problem | Expected | Client workaround |
|---|---|---|---|---|
| 44 | `PUT /api/v1/question/{id}/edit` | **No ownership check.** `QuestionService.question_update` calls `self.repo.detail(question_id, user_id)` **without `await`**, so the result is a coroutine — always truthy — and the `404` guard is dead code. `QuestionRepository.question_update` then selects the question **by id alone**, ignoring `user_id`. Any authenticated user can therefore edit any question in the database. | Owner-only, like `detail` and `update-correct-option` | the app only opens the editor from the student's own quiz. **Security issue — needs a backend fix.** |
| 45 | `POST /api/v1/question/upload-image/{id}` | The file is written to `media/image/{question_id}/{image.filename}` using the **client's file name verbatim**, with no extension or content-type check (`QuestionService.upload_image_to_question`). A crafted name is an arbitrary-write primitive. The limit is also inconsistent: the guard is `len(question.images) >= 2` but the error reads "Only one image can be uploaded". | Sanitized, server-generated names; a real type check; a message matching the limit | the client validates the extension, sets the part's `Content-Type`, and caps the UI at the **2** images the code really allows |
| 46 | `POST /api/v1/quiz-generator/quiz/generate` | `create_job_by_description` dispatches the Celery task **before** the row is committed — `repo.create` only flushes, and the commit happens afterwards inside `set_task_id`. The worker can start before the job exists. | Commit, then enqueue | the job screen polls every 3 s and gives up after 6 minutes with an Uzbek message instead of hanging |
| 47 | `GET /api/v1/quiz-generator/jobs/{job_id}` | Two traps, both reproduced live: `progress` is **100 on failure**, and `error` carries the raw upstream text in English — `"ServerError None: 503 UNAVAILABLE. {'error': {'code': 503, 'message': 'This model is currently experiencing high demand…'}}"` — leaking the AI provider's internals. | Progress that reflects failure; an error safe to show | success is decided by `status == completed && quiz_id != null`; only the backend's own Uzbek `message` is shown, never `error` |
| 48 | `GET /api/v1/student/quizzes/{id}/` | Questions come back in **update order**, not by id: editing question 3 of 5 moved it to the end of the list, which would renumber the whole quiz in the UI. | A stable order | `QuizDetail.fromJson` sorts by id |
| 49 | Web client (FYI) | The create-quiz modal advertises "Maksimal: 10 MB" while `settings.MAX_PDF_SIZE` is **5 MB**; a 6 MB PDF is accepted by the form and then fails with "Fayl saqlanmadi". | One limit | the app states 5 MB and refuses a bigger file before uploading |
| 50 | Question editing | There is **no endpoint** to change an option's text, to add or remove options, or to add or delete a question. Only `question/{id}/edit` (text, topic, difficulty, table), `update-correct-option` and the two image routes exist. | Full editing, if students are meant to author quizzes | the editor exposes exactly what the API supports and says so: "Javob variantlarining matnini o'zgartirib bo'lmaydi" |

## Added 2026-09-15 (waiting-room design pass)

| # | Endpoint | Problem | Expected | Client workaround |
|---|---|---|---|---|
| 51 | `GET /api/v1/student/quiz/multiplayer/{id}/info/` | `max_participants` is stored on the session (`QuizSession.max_participants`, set by `create`) but the response schema `QuizSessionTeacherResponse` does not include it, so the lobby cannot show how many people the room is waiting for. The host chose the number one screen earlier and then cannot see it; a joiner never learns it at all. | `max_participants` in the info response | the waiting room shows the present count only — no "3 / 4" and no empty slots — and the design is drawn that way on purpose |
