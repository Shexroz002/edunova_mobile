# Open questions and conflicts (end of Phase 0)

Raised 2026-09-11. Nothing here blocks Phase 1 except **Q1**.

---

## Blocking

### Q1. Test credentials
`CLAUDE.md` says credentials come **only** from `EDUNOVA_TEST_USER` and `EDUNOVA_TEST_PASS`.
Neither is set in my environment, and they are in no shell profile. So Phase 0's
"confirm with real GET calls" could only be done for the public endpoints.

**Need:** export both vars for the session that runs the work, e.g.

```bash
export EDUNOVA_TEST_USER='...' EDUNOVA_TEST_PASS='...'
```

Then I run the side-effect-free GET list in `docs/API_CONTRACT.md` §12 and mark each endpoint
verified before Phase 2 writes any model. Phase 1 (scaffold, theme, `ApiClient`, router, shell,
shared widgets, unit tests) does not depend on this and can start immediately.

---

## Needs a decision

### Q2. When may the host start a competition?
- The **backend** only checks that the participant list is non-empty — and the host *is* a
  participant — so a host can start **alone** (`quiz_session.py`, `start_session`).
- The **web** additionally requires 2 participants *and* 2 "ready" flags, which in practice means
  two joiners because the host never gets marked ready in its UI (web bug #9).

**My default, unless you say otherwise:** enable "Boshlash" when there is the host **plus at least
one other participant**, and show "Kamida 1 ishtirokchi kutilmoqda" until then. Options: (a) that,
(b) mirror the backend and allow starting solo, (c) mirror the web's 2-joiner rule.

### Q3. Weekly activity chart — keep it?
`CLAUDE.md` default decision 3 says compute it from `/sessions/me/history/` over the last 7 days and
**hide it if that is not reliable**. I cannot judge reliability until I can read real history
(Q1). The concrete risk: history rows carry `created_at` and `finished_at` but no per-day activity
count, so the chart would count *sessions started per day*, which is not quite "faollik".

**Proposal:** build it as "oxirgi 7 kunda boshlangan sessiyalar", labelled exactly that so it is not
misleading. Say the word and I hide it instead.

### Q4. `analytics/topic` — add a "Mavzular" section?
The endpoint exists (`GET /student/quizzes/analytics/topic?subject=<name>`) and the web never uses
it. The analysis suggests it as a Statistics section. It is **extra scope** beyond the web.

**Proposal:** add it in Phase 5 as a collapsed "Mavzular" section per subject. Cheap, real data,
no mock. Confirm or drop.

### Q5. Push notifications
`docs/student-pages-analysis.md` §8.6 lists FCM as a later step; `docs/START_PROMPT.md` does not
include it in any phase. **Assuming out of scope** — realtime only while the app is open.
Confirm if you want FCM planned.

### Q6. Result screen for an old session
No endpoint replays `FinishQuizResponse` (backend issue 25). When the user opens a result later I
plan to **rebuild** the counts from `single-player-error-analysis` (which has every question, the
correct option and the user's choice) — accurate for correct/wrong/unanswered and the topic
breakdown, but `spend_time` is **unavailable**, so the time tile would be hidden in that case.

Alternative: send them to `/results` (the history list) instead of a rebuilt result screen.
**My default:** rebuild, hide the time tile.

### Q7. Friends: what replaces the chat button?
Chat is out of scope, so the per-friend chat button is gone. `docs/student-pages-analysis.md` §3.16
suggests "Musobaqaga taklif" instead. But inviting needs an **existing** session
(`POST .../multiplayer/{id}/invite/?session_code=`), so from the friends list there is nothing to
invite to.

**Proposal:** no per-friend action button on the friends list; invitations happen only from the
lobby, where a session exists. Confirm.

### Q8. AI answer keys are sometimes wrong
Backend issue 8: a verified generated question has the wrong `is_correct`. The student sees a
"correct" answer that is mathematically wrong, and their score reflects the bad key. The question
editor (Phase 6) lets them fix it, but that is the last phase.

**Question:** should the app warn anywhere that AI-generated tests may contain mistakes, or stay
silent? No client-side fix is possible.

### Q9. Test cards show a guessed duration (`~30 daqiqa`)
Seen on the device: each quiz card shows `30 savol · ~30 daqiqa · 11-sentyabr, 2026`. The API has
**no duration field** — the minutes are computed client-side from the question count, exactly as the
web does. `student-pages-analysis.md` §4 row 3 marks the duration as guessed (🟡) and proposes
dropping it along with the participant count (which *is* already gone).

It is not fabricated data in the harmful sense: it is labelled `~`, and it equals the value the start
sheet pre-selects, so it reads as "suggested length". But it is still a number the backend never sent.

**My default:** keep it, since it matches the pre-selected time and helps the student choose.
Say the word and I drop it, leaving `N savol` and the date (both real).

---

## Conflicts found between the sources

Resolved by `CLAUDE.md`'s authority order (live schema + real responses > backend code > docs >
web). Listed so you can see what the docs get wrong.

| # | Topic | `docs/api-notes.md` | Schema / backend source | Resolution |
|---|---|---|---|---|
| 1 | Room "ready" event | `participant_read` | `exam_ws.py` broadcasts `participant_ready` | handle **both** (issue 10) |
| 2 | `session_finished` payload | `{message}` | `{session_id, quiz_id, reason, finished_at}` | parse tolerantly (issue 11) |
| 3 | `quiz/generate` `subject` | "check OpenAPI" | an **integer subject id** (`ai_quiz.py`) | use the id (contract §10) |
| 4 | `FinishQuizResponse` fields | 7 fields | also `session_id`, `attempt_id`, `finished` | contract §4.4 |
| 5 | Single-player load | two calls (`multiplayer/{id}/questions/` + `info/`) | `GET /sessions/{id}/start-single-player/info` returns **both** in one call, and is absent from `api-notes.md` | use the single call, keep the pair as fallback |
| 6 | Group `status` / `color` | uppercase (`ACTIVE`, `VIOLET`) | schema declares lowercase | parse case-insensitively (issue 17) |
| 7 | Register password | "at least 8 characters" (web rule) | schema minimum is **6** | enforce 8 (stricter, matches web) |
| 8 | Lobby "Ready" toggle | "screen-only, hide it" | connecting to `/ws/quiz/sessions/{id}` **marks you ready server-side** | no toggle needed at all — the socket does it (default decision 4 holds, for a better reason) |
| 9 | `users/{id}/` | not mentioned | **public, no auth** (verified live) | unused by the app; reported (issue 12) |

No conflict was found with `CLAUDE.md` itself. Its default product decisions 1–6 all still hold; 4
turns out to be supported by the backend rather than merely a UI simplification.
