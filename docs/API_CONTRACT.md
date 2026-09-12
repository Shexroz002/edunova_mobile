# API contract (student app)

Extracted from the live `http://127.0.0.1:8000/openapi.json` on 2026-09-11. GET endpoints were spot-checked with a real student account.

- Behaviour and quirks are described in `api-notes.md`.
- To refresh this file: `curl -s http://127.0.0.1:8000/openapi.json -o docs/openapi.json`.
- Notation: `p:` path param, `q:` query param, `?` optional, `[T]` list, `Page<T>` = `{items:[T], total, page, size, pages}`.

## Conventions verified live (2026-09-11)
- **Trailing slashes are exact.** `GET /api/v1/users/search` with a slash → `422`;
  `GET /api/v1/notifications` without one → `307`, and dio does not follow redirects for POST.
- `GET /api/v1/subject/list/` returns **only two subjects**: `{id:1, name:"Fizika", type:"fizika",
  icon:""}` and `{id:2, name:"Matematika", type:"math", icon:null}`. `icon` is always empty, so the
  app picks icons from `name`/`type`. Registration demands 2 subjects, so a student must take both.
- `GET /api/v1/users/{user_id}/` answers **without a token** (confirmed with a real request) — see
  `BACKEND_ISSUES.md` #17.
- Pagination: `page` ≥ 1 (default 1), `size` 1..100 (default 50).
- ⚠ **Enum casing:** the schema declares `GroupStatus`/`GroupColor` lowercase, but the server sends
  `ACTIVE`, `VIOLET`. Parse case-insensitively with an unknown-value fallback.
- Register: the schema's `password` minimum is **6**; the web enforces **8**. The app uses 8.

## Live verification log (2026-09-11, account `shehroz`, id 1, role `student`)

Every GET below returned `200` and matched the documented shape. All calls were side-effect free;
`multiplayer/{id}/results/` and `.../topic-statistic/` were **not** called.

| Endpoint | Confirmed |
|---|---|
| `POST /auth/me/` | `{access_token, refresh_token, token_type:"bearer", user}`; **`user.profile_image` is `null`** even though the avatar exists (root cause: `auth_service.py` builds the key as `image_url`) |
| `GET /auth/me/` | full profile; `email`, `phone_number`, `school_name`, `education_level` are all `null` for this account; `subjects` has 2 rows shaped `{id, subject:{...}}` |
| `analytics/overall/cards` | `{total_quiz_session:int, correct_answer:int, average:"<string>"}` — `average` really is a string |
| `analytics/subjects` | 2 rows, `percentage` float, dates are `date` strings |
| `analytics/recommendation` | `{title, badge, subtitle, strong_sides{title,icon,text}, improvement{…}, next_goal{…}}` — matches `api-notes.md` |
| `analytics/topic?subject=Matematika` | 22 rows; the parameter really is a subject **name** |
| `student/quizzes/list` | 25 quizzes; items key is **`quiz_id`**; `quiz_generate_type` seen as `PDF` and `AI_GENERATE` |
| `student/quizzes/79/` | 30 questions, each `{id, question_text, topic, difficulty}` — no options |
| `question/detail/680` | options carry `is_correct`; `table_markdown` is `""`; `images` is `[]` |
| `sessions/me/history/` | 21 rows: **18 finished, 3 unfinished with `null` counts**; `rank` present; 11 rows have `participant_count > 1` |
| `sessions/multiplayer/22/info/` | `session_type:"individual"`, `status:"finished"`, times carry **`+05:00`** (`2026-09-08T10:30:21.280921+05:00`) |
| `sessions/69/leaderboard/` | `spend_time_seconds` is a **string** (`"45.548054"`); no `rank` field |
| `sessions/22/single-player-error-analysis/` | ⚠ **bug reproduced**: `id:680` is the question, `question_id:27` equals session 22's **`quiz_id`** |
| `notifications/` | 19 rows; all three types present with exact payloads (below) |
| `users/contact/list/` | 1 contact; note a friend's `role` can be `teacher` |
| `users/contact/suggestions/`, `users/search?search=sh` | paginated, `contact_available` present |
| `student/group/` | 1 group; ⚠ **`status:"ACTIVE"`, `color:"BLUE"` — uppercase, contradicting the schema** |
| `student/group/1/detail-card`, `/sessions`, `/students-performance` | all match; `cover_image` is `null` in **both** the list and the detail card |
| `student/group/1/results/69`, `/question-accuracy/69`, `/leaderboard/69` | all match; `question-accuracy` returned 15 rows with `level` values |

**Notification payloads, verified verbatim:**
```
competition_result / open_result
  {session_id, quiz_id, quiz_title, rank, participants_count, score,
   total_questions, score_percent: 5.0, wrong_answers, spend_time_seconds: 20}
  title: "Competition result"      <- English, as documented; build the Uzbek text yourself
test_invite_notification / test_invite_notification
  {session_code: "LCIOAF"}         title: "Quiz Session  taklif"
friend_request / friend_request
  {friend_id: 2}                   title: "Yangi do'st so'rovi"
```
⚠ `spend_time_seconds` is an **int** in the notification payload but a **string** in the
leaderboard. Parse both.

## Auth, users, subjects
| Method | Path | Auth | Params / body | Response |
|---|---|---|---|---|
| POST | `/api/v1/auth/me/` | – | form: `grant_type=password, username, password` | `LoginResponse` |
| POST | `/api/v1/auth/refresh/` | – | `{refresh_token}` | `TokenResponse` |
| GET | `/api/v1/auth/me/` | ✓ | – | `UserDetailInfo` |
| POST | `/api/v1/auth/register/` | – | `RegisterSchema` | 201 `UserShortInfo` |
| GET | `/api/v1/subject/list/` | – | – | `[Subject]` |
| GET | `/api/v1/users/{user_id}/` | – | p:user_id | `UserListItem` |
| PUT | `/api/v1/users/{user_id}/` | ✓ | `UserDetailPatch` | `UserDetailPatch` |
| PUT | `/api/v1/users/{user_id}/avatar/` | (✓) | multipart `avatar` | `{msg, profile_image}` |
| GET | `/api/v1/users/search` | ✓ | q:search?, page, size | `Page<UserContactItem>` |
| GET | `/api/v1/users/contact/create/{friend_id}` | ✓ | – | 201 `{message}` |
| GET | `/api/v1/users/contact/list/` | ✓ | q:search?, page, size | `Page<ContactResponse>` |
| GET | `/api/v1/users/contact/suggestions/` | ✓ | page, size | `Page<UserShortInfo>` (no `contact_available`) |

⚠ `contact_available` means **"already a contact"**, not "can be added" — verified live and in
`user_repo.users_with_contact_status` (issue 42). `PUT /users/{id}/` applies `exclude_unset`, so only
the changed fields need to be sent; its response echoes the patch schema with `null` for everything
omitted and must not be used to refresh state (issue 41). `education_level` accepts exactly
`1-sinf … 11-sinf` and `Universitet`; `subject_ids` replaces the whole selection but an empty list is
ignored (issue 40). `avatar` uploads accept `image/jpeg`, `image/png` and `image/webp` only, chosen
by the part's `Content-Type`.

## Notifications
| Method | Path | Params | Response |
|---|---|---|---|
| GET | `/api/v1/notifications/` | page, size | `Page<Notification>` |
| PATCH | `/api/v1/notifications/{id}/read/` | – | `{id, is_read, read_at?}` |
| PATCH | `/api/v1/notifications/read-all/` | – | `int` |

## Student quizzes and analytics
| Method | Path | Params | Response |
|---|---|---|---|
| GET | `/api/v1/student/quizzes/list` | q:search?, page, size | `Page<QuizListItem>` |
| GET | `/api/v1/student/quizzes/{quiz_id}/` | – | `QuizDetail` |
| PUT | `/api/v1/student/quizzes/{quiz_id}/` | `{title, quiz_generate_type, subject?, description?}` | ⚠ returns 500 (see notes) |
| DELETE | `/api/v1/student/quizzes/{quiz_id}/` | – | object |
| GET | `/api/v1/question/detail/{question_id}` | – | `QuestionDetail` |
| GET | `/api/v1/student/quizzes/analytics/overall/cards` | – | `{total_quiz_session?, correct_answer?, average?: string}` |
| GET | `/api/v1/student/quizzes/analytics/subjects` | – | `[SubjectStatistic]` |
| GET | `/api/v1/student/quizzes/analytics/topic` | q:subject (**required, subject NAME string**, e.g. `Matematika`), q:search? | `[TopicStatistic]` |
| GET | `/api/v1/student/quizzes/analytics/recommendation` | – | object (see notes §10) |

## Sessions
| Method | Path | Params / body | Response |
|---|---|---|---|
| POST | `/api/v1/student/sessions/{quiz_id}/start-single-player/` | q:duration_minute=30 | `{session_id, quiz_id}` |
| GET | `/api/v1/student/sessions/{session_id}/start-single-player/info` | – | `SessionQuestions`. ⚠ **Verified live: returns `questions: []` for a multiplayer session** (checked on session 69); for single-player sessions it returns exactly the same questions as `multiplayer/{id}/questions/` (checked on 9 sessions). **Always use `multiplayer/{id}/questions/`** — it works for both kinds. |
| POST | `/api/v1/student/sessions/{session_id}/finish-single-player/` | `[{question_id, selected_option}]` | `FinishQuizResponse` |
| GET | `/api/v1/student/sessions/{session_id}/single-player-error-analysis/` | – | `[ErrorAnalysisItem]` |
| GET | `/api/v1/student/sessions/me/history/` | q:search?, page, size | `Page<HistoryRow>` |
| GET | `/api/v1/student/sessions/{session_id}/leaderboard/` | page, size | `Page<ParticipantResult>` |
| POST | `/api/v1/student/sessions/multiplayer/create/` | `{quiz_id, duration_minutes, max_participants?}` — schema sets **no bounds**; the client enforces 1..180 min and `max_participants` is never enforced by the server | 201 `SessionInfo` (carries `join_code`). Errors: `404 "Quiz not found"`, `404 "Ba'zi savollarda to‘g‘ri javob belgilanmagan."` |
| POST | `/api/v1/student/sessions/multiplayer/join/` | `{session_code}` (uppercase) | `{id}` (the **session** id). Errors: `404 "Invalid session code"`, `400 "Session already started"` (also for an existing participant — rejoin by id), `403 "Bu faqat belgilangan guruh azolari uchun mo'ljallangan test!"` |
| POST | `/api/v1/student/sessions/multiplayer/leave/` | `{session_id, participant_id}` | 204 |
| GET | `/api/v1/student/sessions/multiplayer/{id}/info/` | – | `SessionInfo` |
| GET | `/api/v1/student/sessions/multiplayer/{id}/participants/` | page, size | `Page<Participant>` |
| POST | `/api/v1/student/sessions/multiplayer/{id}/start/` | – | `StartSessionResponse`. Errors: `404 "Session not found or access denied"`, `403 "Only host can start the session"`, `400 "Session is not in waiting state"`, `400 "No participants in session"`. ⚠ The host counts as a participant, so the backend lets a host start **alone** — see `BACKEND_ISSUES.md` #22 |
| GET | `/api/v1/student/sessions/multiplayer/{id}/questions/` | – | `SessionQuestions` |
| POST | `/api/v1/student/sessions/multiplayer/{id}/answer` | `{question_id, selected_option}` | same echo |
| POST | `/api/v1/student/sessions/multiplayer/{id}/change/question/order` | `{question_order_id, participant_id}` | null |
| POST | `/api/v1/student/sessions/multiplayer/{id}/invite/` | q:session_code; `{recipient_id}` | `{message}` |
| ✗ | `.../multiplayer/{id}/finish/`, `.../results/`, `.../topic-statistic/` | – | do not use |

## Student groups
| Method | Path | Params | Response |
|---|---|---|---|
| GET | `/api/v1/student/group/` | q:search?, q:subject_id?, page, size | `Page<GroupCard>` |
| GET | `/api/v1/student/group/{gid}/detail-card` | – | `GroupDetailCard` |
| GET | `/api/v1/student/group/{gid}/sessions` | page, size | `Page<GroupTestResult>` |
| GET | `/api/v1/student/group/{gid}/students-performance` | q:search?, page, size | `Page<GroupStudentPerformance>` |
| GET | `/api/v1/student/group/{gid}/results/{sid}` | – | `SessionResultsDetail` |
| GET | `/api/v1/student/group/{gid}/question-accuracy/{sid}` | – | `[QuestionAccuracy]` |
| GET | `/api/v1/student/group/{gid}/leaderboard/{sid}` | page, size | `Page<ParticipantResult>` |

## Quiz generation
| Method | Path | Params / body | Response |
|---|---|---|---|
| POST | `/api/v1/quiz-generator/pdf-jobs` | multipart `file` | `{job_id, status, progress, message, task_id}` |
| POST | `/api/v1/quiz-generator/quiz/generate` | q:`subject` (**integer subject id**, not a name), q:`description`, q:`question_count` — all required, **no body** | `{job_id, status, progress, message, task_id}` |
| GET | `/api/v1/quiz-generator/jobs/{job_id}` | – | `{job_id, status, progress, message, quiz_id?, question_count?, error?}`; `404 "Job topilmadi"` for a missing or other user's job |

**Verified live 2026-09-12.** `status` is the plain lowercase string (`queued|processing|completed|failed`)
in the `POST` body, the `GET` and the socket alike. PDF upload is rejected with `400` and a friendly
Uzbek message for a non-`.pdf` name ("Faqat PDF yuklash mumkin") or a wrong content type
("Noto'g'ri fayl turi, faqat PDF qabul qilinadi"); the size cap is **5 MB**. A finished PDF job
returned `quiz_id` and `question_count: 30`. `progress` reaches **100 on failure too** (issue 47).

## Question editing
| Method | Path | Params / body | Response |
|---|---|---|---|
| PUT | `/api/v1/question/{question_id}/edit` | `QuestionUpdateSchema` — partial (`exclude_unset`) | `202` + the patch echoed. ⚠ **no ownership check** (issue 44) |
| PUT | `/api/v1/question/update-correct-option/{question_id}/{option_id}` | – | the option; every other option is set wrong |
| POST | `/api/v1/question/upload-image/{question_id}` | multipart `image` | the created image row. Max **2** per question |
| DELETE | `/api/v1/question/delete-image/{question_id}/{image_id}` | – | `204` |

```
QuestionUpdateSchema   { topic?, difficulty?, question_text?, table_markdown?, subject?: string }
```
`difficulty` is a free string; the generator writes `oson`, `o'rta` / `o‘rta` and `qiyin` — parse
case- and apostrophe-insensitively. `question/detail/{id}` is the only response carrying **option
ids** and **image ids**, which the two endpoints above need. There is no endpoint for option text
(issue 50).

## Schemas
```
LoginResponse          { access_token, refresh_token, token_type?, user: UserShortInfo }
TokenResponse          { access_token, refresh_token, token_type? }
UserShortInfo          { id, username, first_name, last_name, role?, profile_image? }
UserDetailInfo         UserShortInfo + { email?, phone_number?, school_name?, education_level?, subjects?: [ {id, subject: Subject} ] }
Subject                { id, name?, type?, icon? }
RegisterSchema         { username, password, first_name, last_name, subjects: [{id}], role: student|schoolboy|teacher }
UserDetailPatch        { first_name?, last_name?, email?, phone_number?, school_name?, education_level?: EducationLevel, subject_ids?: [int] }
EducationLevel         1-sinf | ... | 11-sinf | Universitet
UserListItem           { id, username, first_name, last_name, profile_image? }
UserContactItem        UserListItem + { contact_available: bool }
ContactResponse        { id, friend: UserShortInfo }

Notification           { id, type: NotificationType, action_type, title, message, payload?: map, is_read, read_at?, created_at, sender?: {id?, first_name?, last_name?, profile_image?} }
NotificationType       friend_request | friend_accepted | test_invite_notification | test_reminder | test_result | achievement | teacher_message | competition_result | system
NotificationActionType none | friend_request | test_invite_notification | open_test | open_chat | open_result

QuizListItem           { quiz_id, title, description?, subject?, question_count?, is_new?, quiz_generate_type, created_at }
QuizGenerateType       AI_GENERATE | PDF | MANUAL | UNDEFINED
QuizDetail             { id, title, description?, subject?, quiz_generate_type, questions?: [ {id?, question_text?, topic?, difficulty?} ] }
QuestionDetail         { id, subject?, question_text?, table_markdown?, difficulty?, topic?, images?: [{id, image_url?}], options: [{id, label, text, is_correct}] }
SubjectStatistic       { subject_name, correct_answer, wrong_answer, total_answer, percentage, first_attempt_date?, last_attempt_date? }
TopicStatistic         { subject_name, topic_name, correct_answer, wrong_answer, total_answer, percentage, first_test_date?, last_test_date? }

SessionInfo            { session_id, quiz_id, quiz_name?, subject_name?, host_id, join_code, status, duration_minutes, questions_count, started_at?, deadline_at?, finished_at?, session_type: individual|group|public, current_participant_id? }
SessionQuestions       { session_id, quiz_id, status, questions_count, started_at?, deadline_at?, finished_at?, questions: [QuestionForTaking] }
QuestionForTaking      { id, subject?, question_text?, table_markdown?, difficulty?, topic?, images?: [{id, image_url?}], options: [{label, text}] }
StartSessionResponse   { id, status, started_at?, deadline_at?, finished_at?, participants_count, attempts_created }
FinishQuizResponse     { session_id, attempt_id, total_questions, answered_questions, correct_answers, wrong_answers, spend_time?, score, finished, topic_statistic: [{topic_name, total_questions, correct_answers}] }
ErrorAnalysisItem      { id (question id), question_id (= quiz id, bug), difficulty?, question_text, subject?, table_markdown?, images, topic?, options?: [{id, label, text, is_correct}], user_select_option?, user_select_option_is_correct? }
HistoryRow             { session_id, user_id, title?, subject?, rank, participant_count?, correct_answers?, wrong_answers?, total_questions?, finished_at?, created_at }
ParticipantResult      { user_id, first_name?, last_name?, profile_image?, score?, wrong_answers?, total_questions?, spend_time_seconds?: string|number }
Participant            { participant_id, user_id, nickname, first_name?, last_name?, profile_image?, is_host, joined_at?, participant_status? }

GroupCard              { id, name, subject_name?, description?, students_count?, tests_count?, average_score?, status, last_activity?, color?, cover_image? }
GroupDetailCard        same as GroupCard (cover_image always null)
GroupTestResult        { session_id, quiz_id, quiz_name, average_score?, completed_students?, total_students?, session_date? }
GroupStudentPerformance{ student_id, full_name, profile_image?, correct_answers?, wrong_answers?, tests_count?, average_score? }
SessionResultsDetail   { session_id, quiz_id, quiz_name, subject_name?, status, session_date?, participants_count?, duration_minutes?, average_score?, highest_score?, lowest_score?, hardest_question_number?, hardest_question_accuracy? }
QuestionAccuracy       { question_id, question_number, label, total_answers?, correct_answers?, accuracy_percent?, level }
```

## Phase 3 live verification (2026-09-11, sessions 71 / 72)

Run with the owner's permission to create test sessions.

| Call | Result |
|---|---|
| `POST /multiplayer/create/` `{quiz_id:26, duration_minutes:5, max_participants:10}` | `201`; `session_type:"public"`, `status:"waiting"`, `join_code:"0O1VHN"`, `current_participant_id:95`. ⚠ **`quiz_name` and `subject_name` come back `null`** — the lobby must call `info/` for them |
| `GET /multiplayer/71/info/` | same shape **with** `quiz_name:"Aritmetik Progressiya Testi"`, `subject_name:"Matematika"` |
| `GET /multiplayer/71/participants/` | host row `participant_status:"ready"`, `is_host:true`, and `joined_at:"2026-09-11T16:38:41.167808"` — **no offset** (treat as UTC) |
| `POST /multiplayer/join/` `{"session_code":"ZZZZZZ"}` | `404 {"detail":"Invalid session code"}` |
| `POST /multiplayer/join/` with the code **lowercased** | `404` — ⚠ **the code is case-sensitive; the client must uppercase input** |
| `POST /multiplayer/join/` with the real code | `200 {"id":71}` |
| `POST /multiplayer/71/invite/?session_code=…` `{"recipient_id":3}` | `200 {"message":"Invitation sent successfully"}` |
| same call **without** `session_code` | `422` — the query parameter really is required |
| `POST /multiplayer/71/start/` | `200 {"id":71,"status":"running","started_at":"…+05:00","deadline_at":"…+05:00","finished_at":null,"participants_count":1,"attempts_created":1}` — ⚠ **started with only the host present** |
| `POST /multiplayer/join/` after start | `400 {"detail":"Session already started"}` |
| `POST /multiplayer/71/start/` again | `400 {"detail":"Session is not in waiting state"}` |
| `POST /multiplayer/leave/` `{session_id, participant_id}` | `204`, **empty body**. ⚠ The participant is **not removed** — the row stays with `participant_status:"disconnected"` |
| `PATCH /notifications/104/read/` | `200 {"id":104,"is_read":true,"read_at":"2026-09-11T16:41:16.919585Z"}` |

`PATCH /notifications/read-all/` was **not** called: it would wipe the account's unread state, which
is a side effect beyond what was authorised.

### WebSockets, verified live

**Handshake failures are HTTP statuses, not close codes.** The backend closes before `accept()`, so
the client sees the upgrade rejected:

| Socket | Result |
|---|---|
| `/ws/quiz/sessions/71` with **no** token | rejected, **HTTP 403** |
| `/ws/quiz/sessions/71` with an invalid token | rejected, **HTTP 401** |
| `/ws/notifications/2` with user 1's token | rejected, **HTTP 403** |
| `/ws/notifications/1` with user 1's token | connected |

⚠ `SocketService` must therefore treat an **upgrade exception carrying 401/403** as "refresh the
token and retry", rather than waiting for a `1008` close frame.

**Room socket `/ws/quiz/sessions/71`** — observed frames, in order:
```
{"event":"participant_ready","data":{"user_id":1,"status":"ready"}}     <- just from connecting
{"event":"pong","data":{}}                                              <- reply to {"event":"ping"}
{"event":"error","data":{"detail":"Unsupported event. Use event='ping' for heartbeat."}}  <- spurious
{"event":"session_started","data":{"session_id":71,"quiz_id":26,
   "started_at":"2026-09-11T16:40:27.010412+00:00",
   "deadline_at":"2026-09-11T16:45:27.010412+00:00","finished_at":null}}
{"event":"participant_disconnected","data":{"user_id":1,"status":"disconnected"}}   <- after leave/
```
- ✅ The event really is **`participant_ready`** — the backend source was right and
  `api-notes.md`'s `participant_read` is wrong.
- ✅ The `ping` → `pong` **+ spurious `error`** bug is real.
- ⚠ **Offsets disagree between transports:** `start/`'s REST body says `+05:00`
  (`21:40:27.010412+05:00`) while the `session_started` frame says `+00:00`
  (`16:40:27.010412+00:00`). Same instant, different representation — parse the offset, never assume it.

**Notifications socket `/ws/notifications/1`** — a self-invite delivered **two** frames:
```
{"type":"test_invite_notification",
 "data":{"id":105,"type":"test_invite_notification","action_type":"test_invite_notification",
         "title":"Quiz Session  taklif",
         "message":"Shehroz Toshpo'latov sizni birgalikda test ishlashga taklif qilmoqda.",
         "payload":{"session_code":"9JXD8A"},"sender":{"id":1,…}}}
{"type":"notification_count_update","data":{"count":6}}
```
⚠ This producer's `data` has **no `is_read` and no `created_at`** (the REST list has both), so the
notification model must tolerate their absence — treat a pushed notification as unread and fall back
to "now" for the timestamp.

## WebSockets
All sockets authenticate with `?token=<access_token>` and close with `1008` on failure (refresh the
token, then reconnect). **Never log a full socket URL — it contains the token.**

### Session room · `/ws/quiz/sessions/{id}` — envelope `{event, data}`
⚠ **Connecting already marks you "ready" server-side** (`exam_ws.py` calls `mark_ready`), which is
why no client-side "Ready" toggle is needed.

| Event | `data` |
|---|---|
| `participant_joined` | `participant_id, user_id, is_host, nickname, profile_image, first_name, last_name, joined_at, status, participants_online` |
| `participant_ready` / `participant_read` | `user_id, status:"ready"` — the source broadcasts `participant_ready`, `api-notes.md` recorded `participant_read`. **Accept both.** |
| `participant_reconnected` | `user_id, status, participants_online` |
| `participant_disconnected` | `user_id, status` |
| `session_started` | `session_id, quiz_id, started_at, deadline_at, finished_at` |
| `session_finished` | `session_id, quiz_id, reason, finished_at` — `reason` ∈ `all_finished, time_expired, host_finished`. ⚠ `api-notes.md` says `{message}`; the source says these four. Parse tolerantly. |
| `chat_message` | ignore (chat is out of scope) |
| `pong` / `error` | a client `ping` gets **both** `pong` and a spurious `error` — ignore it |

Host-only monitoring sockets `/ws/quiz-sessions/{id}` and `/ws/quiz-sessions/{id}/participant`
(hyphen, not slash) are **not used** by the student app.

### Notifications · `/ws/notifications/{userId}` — envelope `{type, data}`
The path `userId` must match the token's user, else `1008`.

| `type` | `data` |
|---|---|
| any `NotificationType` value (`test_invite_notification`, `friend_request`, `competition_result`, …) | the notification object: `id, type, action_type, title, message, payload, read_at, created_at, sender` |
| `notification_count_update` | `{count}` → the app-bar bell badge |

Two producers build `data` slightly differently (one omits `is_read`/`created_at`) — parse tolerantly.

### Quiz-generation job · `/ws/jobs/{jobId}/` (**trailing slash required**)
First message is a snapshot, then pub/sub pushes. **Verified live**: pushes carry a `type` too
(`"progress"`, then `"completed"`), so the shape is the same throughout and `type` can be ignored.
```
{ type: "snapshot",   job_id, status, progress, message, quiz_id, question_count, error }
{ type: "progress",   job_id, status, progress, message, quiz_id, question_count, error }
{ type: "completed",  job_id, status, progress, message, quiz_id, question_count, error }
```
Real messages from one PDF run: `AI qayta urinmoqda (2/3)` → `AI javobi olindi` →
`AI javobi JSON formatga o'tkazilmoqda` → `Savollar bazaga saqlanmoqda` → `Test tayyor bo'ldi`.
⚠ The socket only breaks out of its loop on a **pushed** terminal frame; for a job that was already
finished it sends the snapshot and then waits forever, so the client must close it itself.
`status` ∈ `queued | processing | completed | failed`. Always keep the 3 s polling fallback on
`GET /api/v1/quiz-generator/jobs/{job_id}`.
