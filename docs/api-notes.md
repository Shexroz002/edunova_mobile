# EduNova API notes for the student app

Verified against the **live** backend (`http://127.0.0.1:8000`) on 2026-09-11 with a real student account. The live server is newer than older code snapshots.

**`/openapi.json` is the schema authority.** This file documents *behaviour* that the schema does not show.

---

## 1. Basics
- **Paths:**
  - REST: `/api/v1/...`
  - WebSockets: at the root, `/ws/...`
  - static media: `/media/...`
- **Trailing slashes:** use paths **exactly** as OpenAPI lists them. A wrong slash returns `307`, and dio does not follow redirects for POST.
  - `GET /api/v1/users/search` has **no** trailing slash. With a slash it returns `422`.
- **Errors:**
  - `{"detail": "text"}`;
  - validation: `422 {"detail": [{"loc": [...], "msg": "..."}]}`;
  - some failures are `500` with a plain-text body `Internal Server Error`, so parse defensively.
- **Pagination:** `Page = {items, total, page, size, pages}`, query `page` (≥1) and `size` (1..100).

## 2. Auth
- **Login:** `POST /api/v1/auth/me/`, `application/x-www-form-urlencoded`.
  - Body: `grant_type=password&username=...&password=...`
  - **Lowercase and trim the username** before sending.
  - Response: `{access_token, refresh_token, token_type, user}`. `user.profile_image` is always `null` here, so call `GET /api/v1/auth/me/` right after login.
- **Roles:** accept `student` and `schoolboy`. Reject `teacher` with an Uzbek message saying teachers use the web.
- **Refresh:** `POST /api/v1/auth/refresh/` with `{refresh_token}` returns a new pair. JWT `exp` is readable client-side. There is no logout endpoint.
- **Register:** `POST /api/v1/auth/register/` with `{username, password, first_name, last_name, subjects: [{id}], role: "schoolboy"}` returns `201`.
  - Errors: `"Username already taken"`, `422` on length rules.
  - Web rules: password at least 8 characters, at least 2 subjects.
- **Subjects:** `GET /api/v1/subject/list/` (public). `icon` is often `""` or `null`, so choose icons by subject `name`/`type`.

## 3. Data formats
| Field | Real example | How to parse |
|---|---|---|
| Session `started_at`, `deadline_at`, `finished_at` (info, questions) | `2026-09-09T09:58:27.263592+05:00` | ISO with offset |
| `created_at`, history `finished_at`, notification dates | `2026-09-09T04:58:12.029307Z` | ISO UTC |
| participants `joined_at` | `2026-09-09T04:58:12.012307` (no offset) | treat as UTC |
| `overall/cards.average` | `"30.77"` (string) | `double.tryParse` |
| leaderboard `spend_time_seconds` | `"31.294116"` (string) | `double.tryParse` |
| image URLs | `http://127.0.0.1:8000/media/avatars/x.jpg` | see below |
| `difficulty` | `"oson"`, `"o‘rta"` (U+2018), `"o'rta"`, `"o'son"`, `"qiyin"` | normalize to easy/medium/hard |

**Image URLs:**
- the host `localhost`/`127.0.0.1` is unreachable from a phone, so rewrite it to the configured API host;
- relative paths get the API host as prefix;
- collapse `//` in the path;
- `http://localhost:8000/` (host-only placeholder) means no image.

**Difficulty normalization:** lowercase, unify `'` `‘` `’` `ʻ`, strip the apostrophe. Then: starts with `os` or `o'son` → easy, contains `rta` → medium, contains `qiy` → hard.

## 4. Quizzes (the student's own quizzes, created from PDF or AI)
- **List:** `GET /api/v1/student/quizzes/list?search=&page=&size=`
  - items use **`quiz_id`**, not `id`;
  - fields: `title, description, subject, question_count, is_new, quiz_generate_type (AI_GENERATE|PDF|MANUAL|UNDEFINED), created_at`.
- **Detail:** `GET /api/v1/student/quizzes/{id}/`. Returns `questions [{id, question_text, topic, difficulty}]` without options.
- **Question detail:** `GET /api/v1/question/detail/{id}`. Returns options with `is_correct`. Only works for the owner's quizzes.
- **Edit quiz meta:** the student `PUT /student/quizzes/{id}/` returns `500` even when it succeeds. The web uses `PUT /api/v1/teacher/quizzes/{id}/`. Confirm before using either.

## 5. Sessions
**Single player:**
1. Start: `POST /api/v1/student/sessions/{quiz_id}/start-single-player/?duration_minute=N` returns `{session_id, quiz_id}`.
2. Load:
   - questions: `GET /api/v1/student/sessions/multiplayer/{session_id}/questions/`. Questions are ordered by id; options are `[{label, text}]`, **sort by label**.
   - info: `GET /api/v1/student/sessions/multiplayer/{session_id}/info/`. Gives `duration_minutes, deadline_at, session_type, current_participant_id, status`.

**Timer:**
- use `deadline_at`; fallback is `started_at + duration_minutes`;
- the server enforces nothing, so **the client must auto-submit at 0**;
- recompute the remaining time on app resume.

**Finish (single AND multiplayer):**
- `POST /api/v1/student/sessions/{session_id}/finish-single-player/`
- Body: a **bare JSON array** `[{"question_id": 1051, "selected_option": "B"}]`. Send only answered questions.
- Returns `FinishQuizResponse {total_questions, answered_questions, correct_answers, wrong_answers, score (= correct count), spend_time (s), topic_statistic[{topic_name, total_questions, correct_answers}]}`.
- Retrying is safe (it re-scores). No other endpoint returns this object later, so pass it to the result screen via the route.

**Multiplayer while playing** (`session_type` is `public` or `group`):
- `POST .../multiplayer/{id}/answer` with `{question_id, selected_option}` on every selection. This only updates live monitoring and is **not persisted**.
- `POST .../multiplayer/{id}/change/question/order` with `{question_order_id (1-based), participant_id}` on every navigation.
- Always finish with `finish-single-player`. **Never** rely on `.../multiplayer/{id}/finish/`: it scores from the DB and returns 0.

**Review:** `GET /api/v1/student/sessions/{id}/single-player-error-analysis/`
- use **`id`** as the question id; `question_id` is actually the quiz id (backend bug);
- options include `is_correct`; the response also has `user_select_option` and `user_select_option_is_correct`;
- multiplayer joiners may see the host's answers (backend bug, log it).

**History:** `GET /api/v1/student/sessions/me/history/?search=&page=&size=`
- `search` needs at least 1 character, so omit it when empty;
- unfinished sessions have `null` counts; show them as "Tugallanmagan";
- `participant_count > 1` means multiplayer.

**Leaderboard:** `GET /api/v1/student/sessions/{id}/leaderboard/?page=&size=`
- there is no `rank` field and `null` scores come first;
- sort nulls last and compute the rank yourself.

**Competition:**
- **Create:** `POST .../multiplayer/create/` with `{quiz_id, duration_minutes (1..180), max_participants}` returns SessionInfo with `join_code`.
- **Join:** `POST .../multiplayer/join/` with `{session_code}` (uppercase) returns `{id}`.
  - Errors: `404 Invalid session code`, `400 Session already started` (also returned for existing participants, who should rejoin by id), `403` for a group session when the user is not a member.
- **Lobby:** `GET .../multiplayer/{id}/info/` and `GET .../multiplayer/{id}/participants/`.
- **Leave:** `POST .../multiplayer/leave/` with `{session_id, participant_id}` returns `204`.
- **Host start:** `POST .../multiplayer/{id}/start/`.
- **Invite a contact:** `POST .../multiplayer/{id}/invite/?session_code=CODE` with `{recipient_id}`.

## 6. WebSockets
All sockets authenticate with `?token=<access_token>`. A failed handshake means: refresh the token, then reconnect.

**Session room:** `/ws/quiz/sessions/{id}`
- Envelope: `{"event": "...", "data": {...}}`.
- Events:
  - `participant_joined`;
  - `participant_reconnected`;
  - **`participant_read`** (means "ready"; the typo is in the backend);
  - `participant_disconnected`;
  - `session_started {session_id, quiz_id, started_at, finished_at}`, which moves everyone to the play screen;
  - `session_finished {message}`: show a toast and auto-submit;
  - `chat_message`: ignore.
- Client ping `{"event":"ping"}` gets `pong` **plus a spurious `error` event**; ignore that error.

**Notifications:** `/ws/notifications/{userId}`
- Envelope: `{"type": "...", "data": {...}}`.
- `type: "test_invite_notification"`: `data` is a notification object.
- `type: "notification_count_update"`: `data {count}`, used for the bell badge.

**Quiz generation job:** `/ws/jobs/{jobId}/`
- Payload: `{status: queued|processing|completed|failed, progress, message, quiz_id, question_count, error}`.
- **Always keep a polling fallback:** `GET /api/v1/quiz-generator/jobs/{jobId}` every 3 s.

## 7. Notifications
- **List:** `GET /api/v1/notifications/?page=&size=` (paginated).
- **Mark read:** `PATCH /api/v1/notifications/{id}/read/`. **Mark all:** `PATCH /api/v1/notifications/read-all/`, returns an integer.
- **Live types:**

| type / action_type | payload | UI |
|---|---|---|
| `competition_result` / `open_result` | `session_id, quiz_id, quiz_title, rank, participants_count, score, total_questions, score_percent, wrong_answers, spend_time_seconds` | medal by rank, %, "Ko'rish" opens the result |
| `test_invite_notification` | `session_code` | "Qabul qilish": join, then lobby. "Rad etish": local only |
| `friend_request` | `friend_id` | "Qabul qilish": `GET /api/v1/users/contact/create/{friend_id}`. "Rad etish": local only |

- The `title` and `message` of `competition_result` are English on the server. Build the Uzbek text from the payload, as the web does.

## 8. Groups (student is a member)
- **List:** `GET /api/v1/student/group/?search=&subject_id=&page=&size=`.
- **Detail:**
  - `GET /api/v1/student/group/{gid}/detail-card`. `cover_image` is always null here, so reuse the value from the list.
  - `GET /api/v1/student/group/{gid}/sessions`
  - `GET /api/v1/student/group/{gid}/students-performance`
- **Session result:**
  - `GET /api/v1/student/group/{gid}/results/{sid}`
  - `GET /api/v1/student/group/{gid}/question-accuracy/{sid}` (`level`: easy/medium/hard)
  - `GET /api/v1/student/group/{gid}/leaderboard/{sid}`
- `color` is an uppercase name (`BLUE, VIOLET, TEAL, PURPLE, GREEN, YELLOW, RED, PINK, ORANGE, CYAN`). `status` is `ACTIVE` or `ARCHIVED`.
- A non-member gets `500` plain text. Show a generic error.

## 9. Users and friends
- **Friends:**
  - list: `GET /api/v1/users/contact/list/?search=&page=&size=` returns items `{id, friend: {id, username, first_name, last_name, role, profile_image}}`;
  - suggestions: `GET /api/v1/users/contact/suggestions/`;
  - search: `GET /api/v1/users/search?search=` returns items with `contact_available` (true = already added);
  - add: `GET /api/v1/users/contact/create/{id}` (**it is a GET**, returns `201`). It is idempotent and there is no unfriend endpoint.
- **Profile update:** `PUT /api/v1/users/{id}/`.
  - Send only non-empty changed fields. `email` and `phone` are unique, and `""` breaks them.
  - `education_level` is `"1-sinf"`…`"11-sinf"` or `"Universitet"`. `subject_ids` is `[int]`.
  - The response `subject_ids` is always `null`, so refetch `/auth/me/`.
- **Avatar:** `PUT /api/v1/users/{id}/avatar/` as multipart.
  - field `avatar`; set the content type `image/jpeg|png|webp` explicitly; at most 5 MB;
  - the response `profile_image` is **relative**.

## 10. Statistics
Endpoints:
- `GET /api/v1/student/quizzes/analytics/overall/cards` returns `{total_quiz_session, correct_answer, average (string)}`;
- `GET /api/v1/student/quizzes/analytics/subjects` returns `[{subject_name, correct_answer, wrong_answer, total_answer, percentage, first_attempt_date, last_attempt_date}]`;
- `GET /api/v1/student/quizzes/analytics/topic?subject=Matematika` (the web does not use it; good for a "Mavzular" section);
- `GET /api/v1/student/quizzes/analytics/recommendation` returns `{title, badge, subtitle, strong_sides{title,icon,text}, improvement{...}, next_goal{...}}` (rule-based text).

## 11. Quiz generation (PDF / AI)
- **PDF:** `POST /api/v1/quiz-generator/pdf-jobs`, multipart field `file`, returns `{job_id, status, progress, message}`. Then use the WS or polling.
- **AI:** `POST /api/v1/quiz-generator/quiz/generate?subject=&description=&question_count=`. Check the exact parameters in OpenAPI.
- **Verified 2026-09-11:** a 2-page math PDF finished with 30 questions (quiz #79). Findings:
  - **23 of 30 `question_text` values contain ANSI escape codes** inside LaTeX: a real ESC byte `\x1B[3m` and the literal text `\u001b[23m`.
    - `MathText` must strip both: `RegExp(r'\x1B\[[0-9;]*m')` and `RegExp(r'\\u001b\[[0-9;]*m')`.
    - Log this in `docs/BACKEND_ISSUES.md`.
  - The AI answer key can be wrong. Example: "√(x²−4x+5)+√(2x²−8x+17)=4 nechta ildizga ega?" is marked `B) 2`, but the correct answer is `D) 1`. The client just displays; report it to the owner.
  - Question order does not follow the PDF order.

## 12. Math and tables in question text
- **Delimiters:** `$...$`, `$$...$$`, `\(...\)`, `\[...\]`.
- **Rendering:** use `flutter_math_fork` for the formulas. If parsing fails, show the raw text; never crash.
- **Tables:** `table_markdown` is a pipe table (often empty). Render it with a small parser and a `Table` widget.
