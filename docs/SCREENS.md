# Screen map (web → Flutter)

The detailed Uzbek analysis is in `student-pages-analysis.md`. Web sources are in `../edunova_frontend/src/app/`.

- **Phone:** under 600 dp.
- **Tablet:** 600 dp and wider.
- **Phase:** see `START_PROMPT.md`.

| # | Flutter route | Web source | Main APIs | Phone layout | Tablet layout | Phase |
|---|---|---|---|---|---|---|
| 1 | `/login` | `pages/common/LoginPage.tsx` | `auth/me` (POST), `auth/me` (GET) | centered card | same, max 460 dp | 1 ✅ |
| 2 | `/register` | `pages/common/RegisterPage.tsx` | `subject/list`, `auth/register` | 2-step card | same, max 520 dp | 1 ✅ |
| 3 | `/home` | `pages/student/StudentHomePage.tsx` | `overall/cards`, `analytics/subjects`, `quizzes/list`, `multiplayer/join`, WS notifications | single column | 2 columns (actions / subjects) | 1 (shell) → 5 |
| 4 | `/tests` | `StudentTestsPage.tsx` + `components/TestTimeModal.tsx` | `quizzes/list`, `start-single-player` | list + search | centered list | 2 ✍️ |
| 5 | `/tests/:quizId` | `StudentQuizDetailPage.tsx` + `components/QuestionDetailModal.tsx` | `quizzes/{id}`, `question/detail/{id}` | header + list | centered list | 2 ✍️ (view), 6 (editor) |
| 6 | `/session/:id/play` | `StudentTestTakingPage.tsx` | `multiplayer/{id}/questions`, `info`, `answer`, `change/question/order`, `finish-single-player`, WS room | one question per page, map in a sheet | question + map side panel | 2 ✍️ |
| 7 | `/session/:id/result` | `StudentTestTakingPage` → `StudentTestResultsPage.tsx` | route extra `FinishQuizResponse` | score ring, topics | 2 columns | 2 ✍️ |
| 8 | `/session/:id/review` | `StudentErrorAnalysisPage.tsx` | `single-player-error-analysis` | pager + filter | pager + map | 2 ✍️ |
| 9 | `/results` | `StudentResultsPage.tsx` | `me/history`, `{id}/leaderboard` | summary + cards, leaderboard sheet | centered list | 2 ✍️ |
| 10 | `/competition/new` | `StudentCompetitionPage.tsx` | `quizzes/list`, `multiplayer/create` | 3-step wizard | same, max 640 dp | 3 |
| 11 | `/session/:id/lobby` | `StudentWaitingRoomPage.tsx` + `InviteFriendsModal.tsx` | `info`, `participants`, `start`, `leave`, `invite`, `contact/list`, WS room | code card + participants | code/info and participants side by side | 3 |
| 12 | `/notifications` | `StudentNotificationsPage.tsx` | `notifications`, `read`, `read-all`, `join`, `contact/create` | filters + grouped list | list + preview | 3 |
| 13 | `/groups` | `StudentGroupsPage.tsx` | `student/group` | search, sort, cards | 2–3 column grid | 4 |
| 14 | `/groups/:gid` | `StudentGroupDetailPage.tsx` | `detail-card`, `sessions`, `students-performance` | stacked sections | 2 columns | 4 |
| 15 | `/groups/:gid/sessions/:sid` | `StudentSessionResultPage.tsx` | `results`, `question-accuracy`, `leaderboard`, PDF | stacked sections | 2 columns | 4 |
| 16 | `/friends` | `StudentFriendsPage.tsx` + `components/AddFriendModal.tsx` | `contact/list`, `users/search`, `contact/suggestions`, `contact/create` | list + search | list + add panel | 5 |
| 17 | `/statistics` | `StudentStatisticsPage.tsx` | `overall/cards`, `analytics/subjects`, `analytics/topic`, `analytics/recommendation`, `me/history` | cards + charts | 2 columns | 5 |
| 18 | `/profile` | `StudentProfilePage.tsx` | `auth/me` | real data only | 2 columns | 1 ✅ |
| 19 | `/profile/edit` | `StudentProfileEditPage.tsx` | `users/{id}` (PUT), `users/{id}/avatar` (PUT), `subject/list` | form | form, max 640 dp | 5 |
| 20 | `/quiz/new` | `pages/teacher/QuizzesPage.tsx` (`CreateQuizModal`) + `QuizCreatedSuccessModal.tsx` | `quiz-generator/pdf-jobs`, `quiz/generate`, `jobs/{id}`, WS jobs | full-screen flow | same, max 640 dp | 6 |

✍️ = code written, awaiting verification.

Excluded: `StudentChatPage` and everything in `components/chat`.
