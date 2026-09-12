@Tags(['live'])
library;

import 'dart:io';

import 'package:edunova_mobile/core/network/api_client.dart';
import 'package:edunova_mobile/core/storage/token_storage.dart';
import 'package:edunova_mobile/core/utils/difficulty.dart';
import 'package:edunova_mobile/features/auth/data/auth_repository.dart';
import 'package:edunova_mobile/features/session/data/session_repository.dart';
import 'package:edunova_mobile/features/session/domain/session_models.dart';
import 'package:edunova_mobile/features/tests/data/tests_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Live contract tests: the real repositories against a running backend.
///
/// These are **skipped by default** so `flutter test` stays hermetic. Run them
/// against a local backend with:
///
/// ```
/// EDUNOVA_LIVE=1 EDUNOVA_TEST_USER=... EDUNOVA_TEST_PASS=... flutter test test/live_api_test.dart
/// ```
///
/// Only side-effect-free `GET`s are used. `multiplayer/{id}/results/` and
/// `multiplayer/{id}/topic-statistic/` are never called (see
/// `docs/BACKEND_ISSUES.md`).
void main() {
  final env = Platform.environment;
  final enabled = env['EDUNOVA_LIVE'] == '1';
  final username = env['EDUNOVA_TEST_USER'] ?? '';
  final password = env['EDUNOVA_TEST_PASS'] ?? '';
  final baseUrl = env['EDUNOVA_API_BASE_URL'] ?? 'http://127.0.0.1:8000';

  if (!enabled || username.isEmpty || password.isEmpty) {
    test('live API contract', () {}, skip: 'set EDUNOVA_LIVE=1 with EDUNOVA_TEST_USER/PASS');
    return;
  }

  late ApiClient api;
  late AuthRepository auth;
  late TestsRepository tests;
  late SessionRepository sessions;
  var sessionExpired = false;

  setUpAll(() async {
    api = ApiClient(
      tokenStorage: _MemoryTokenStorage(),
      onSessionExpired: () => sessionExpired = true,
      baseUrl: baseUrl,
    );
    auth = AuthRepository(api);
    tests = TestsRepository(api);
    sessions = SessionRepository(api);

    final login = await auth.login(username: username, password: password);
    await _MemoryTokenStorage.shared.saveTokens(login.tokens);
  });

  group('auth', () {
    test('login returns a usable token pair and a student profile', () async {
      final login = await auth.login(username: username, password: password);

      expect(login.tokens.accessToken, isNotEmpty);
      expect(login.tokens.refreshToken, isNotEmpty);
      expect(login.tokens.accessExpiresAt, isNotNull, reason: 'JWT exp must be readable');
      expect(login.tokens.isAccessExpiringSoon(), isFalse, reason: 'a fresh token is not expiring');
      expect(login.user.isStudent, isTrue);

      // Backend issue: the login payload never carries the avatar, so the app
      // has to follow up with GET /auth/me/.
      expect(login.user.profileImage, isNull);
    });

    test('GET /auth/me/ fills in the avatar and subjects the login omits', () async {
      final me = await auth.fetchMe();

      expect(me.id, greaterThan(0));
      expect(me.username, username.toLowerCase());
      expect(me.fullName, isNotEmpty);
      expect(me.isStudent, isTrue);
      expect(me.subjects, isNotEmpty);
      for (final subject in me.subjects) {
        expect(subject.id, greaterThan(0), reason: 'nested {id, subject:{id}} must resolve');
      }
    });

    test('subjects are public and need app-side icons', () async {
      final subjects = await auth.fetchSubjects();

      expect(subjects, isNotEmpty);
      expect(subjects.every((s) => s.displayName.isNotEmpty), isTrue);
      // Backend issue: `icon` is "" or null for every subject.
      expect(subjects.every((s) => (s.icon ?? '').isEmpty), isTrue);
    });

    test('an expiring token is refreshed and the session survives', () async {
      final refreshed = await api.refreshAccessToken();

      expect(refreshed, isNotNull);
      expect(refreshed, isNotEmpty);
      expect(sessionExpired, isFalse);
      // The refreshed token must work for an authenticated call.
      expect((await auth.fetchMe()).id, greaterThan(0));
    });
  });

  group('quizzes', () {
    test('list paginates and exposes quiz_id, not id', () async {
      final first = await tests.fetchQuizzes(page: 1, size: 2);

      expect(first.items, isNotEmpty);
      expect(first.total, greaterThan(0));
      expect(first.items.every((q) => q.id > 0), isTrue, reason: 'parsed from quiz_id');
      expect(first.items.every((q) => q.title.isNotEmpty), isTrue);

      if (first.hasMore) {
        final second = await tests.fetchQuizzes(page: 2, size: 2);
        final firstIds = first.items.map((q) => q.id).toSet();
        expect(second.items.any((q) => firstIds.contains(q.id)), isFalse,
            reason: 'page 2 must not repeat page 1');
      }
    });

    test('an empty search is dropped rather than sent as search=', () async {
      // The backend rejects `search=` (it requires minLength 1), so ApiClient
      // strips empty query values. This call must therefore succeed.
      final result = await tests.fetchQuizzes(search: '', page: 1, size: 1);
      expect(result.items, isNotEmpty);
    });

    test('detail returns questions without options, question detail adds them', () async {
      final list = await tests.fetchQuizzes(page: 1, size: 1);
      final detail = await tests.fetchQuiz(list.items.first.id);

      expect(detail.id, list.items.first.id);
      expect(detail.questions, isNotEmpty);
      expect(detail.questions.every((q) => q.text.isNotEmpty), isTrue);
      expect(
        detail.questions.every((q) => Difficulty.values.contains(q.difficulty)),
        isTrue,
        reason: 'every backend spelling must normalize',
      );

      final question = await tests.fetchQuestion(detail.questions.first.id);
      expect(question.options, isNotEmpty);
      expect(question.options.map((o) => o.label).toList(), _sortedLabels(question.options.length));
      expect(question.options.where((o) => o.isCorrect == true), hasLength(1));
    });
  });

  group('sessions', () {
    test('history separates finished sessions from unfinished ones', () async {
      final page = await sessions.fetchHistory(page: 1, size: 100);

      expect(page.items, isNotEmpty);
      for (final item in page.items) {
        expect(item.sessionId, greaterThan(0));
        if (item.isFinished) {
          expect(item.totalQuestions, isNotNull);
          expect(item.percent, inInclusiveRange(0, 100));
        } else {
          // Unfinished rows must not pretend to have a score.
          expect(item.correctAnswers, isNull);
          expect(item.percent, 0.0);
          expect(item.durationMinutes, isNull);
        }
      }
    });

    test('session info parses the +05:00 offsets the backend sends', () async {
      final sessionId = await _anyFinishedSession(sessions);
      final info = await sessions.fetchInfo(sessionId);

      expect(info.sessionId, sessionId);
      expect(info.quizId, greaterThan(0));
      expect(info.startedAt, isNotNull);
      expect(info.deadlineAt, isNotNull);
      expect(info.deadlineAt!.isAfter(info.startedAt!), isTrue);
      expect(info.durationMinutes, greaterThan(0));
    });

    test('questions load with labels sorted and no correct answer leaked', () async {
      final sessionId = await _anySinglePlayerSession(sessions);
      final loaded = await sessions.fetchQuestions(sessionId);

      expect(loaded.questions, isNotEmpty);
      for (final question in loaded.questions) {
        expect(question.options, isNotEmpty);
        expect(question.options.map((o) => o.label).toList(), _sortedLabels(question.options.length));
        expect(question.options.every((o) => o.isCorrect == null), isTrue,
            reason: 'the play screen must never receive is_correct');
      }
    });

    test('review marks the correct option and survives the question_id bug', () async {
      final sessionId = await _anyFinishedSession(sessions);
      final review = await sessions.fetchReview(sessionId);

      expect(review, isNotEmpty);
      for (final item in review) {
        // `id` is the question; `question_id` is the quiz id. If the model read
        // the wrong field, every item would share one id.
        expect(item.question.id, greaterThan(0));
        expect(item.question.options, isNotEmpty);
        expect(item.question.options.where((o) => o.isCorrect == true), hasLength(1));
        if (item.isAnswered) {
          expect(item.isCorrect ^ item.isWrong, isTrue, reason: 'answered is either right or wrong');
        }
      }
      expect(review.map((i) => i.question.id).toSet(), hasLength(review.length),
          reason: 'question ids must be distinct (the quiz id would collapse them)');
    });

    test('a result can be rebuilt from review when the finish payload is gone', () async {
      final sessionId = await _anyFinishedSession(sessions);
      final review = await sessions.fetchReview(sessionId);
      final rebuilt = FinishResult.fromReview(sessionId, review);

      expect(rebuilt.totalQuestions, review.length);
      expect(rebuilt.correctAnswers + rebuilt.wrongAnswers, rebuilt.answeredQuestions);
      expect(rebuilt.answeredQuestions, lessThanOrEqualTo(rebuilt.totalQuestions));
      // No endpoint replays spend_time, so it must stay unset rather than faked.
      expect(rebuilt.spendSeconds, isNull);
    });

    test('leaderboard is ranked on the client with unfinished players last', () async {
      final sessionId = await _anyMultiplayerSession(sessions) ?? await _anyFinishedSession(sessions);
      final board = await sessions.fetchLeaderboard(sessionId);

      expect(board, isNotEmpty);
      expect(board.first.rank, 1);

      final scored = board.where((e) => e.score != null).toList();
      final unscored = board.where((e) => e.score == null).toList();
      if (scored.isNotEmpty && unscored.isNotEmpty) {
        expect(board.indexOf(unscored.first), greaterThan(board.indexOf(scored.last)),
            reason: 'null scores must sort last, not first as the API returns them');
      }
      for (var i = 1; i < scored.length; i++) {
        expect(scored[i - 1].score!, greaterThanOrEqualTo(scored[i].score!));
      }
      // spend_time_seconds arrives as a string here and as an int elsewhere.
      expect(board.every((e) => e.spendSeconds == null || e.spendSeconds! >= 0), isTrue);
    });
  });

  group('error mapping', () {
    test('an unknown quiz raises an ApiException with a message to show', () async {
      await expectLater(
        tests.fetchQuiz(999999999),
        throwsA(
          isA<Exception>().having((e) => e.toString(), 'message', isNotEmpty),
        ),
      );
    });

    test('a bad password is rejected without clearing the live session', () async {
      await expectLater(
        auth.login(username: username, password: 'definitely-not-the-password'),
        throwsA(isA<Exception>()),
      );
      expect(sessionExpired, isFalse);
      expect((await auth.fetchMe()).id, greaterThan(0));
    });
  });
}

/// Labels `A`, `B`, `C`… used to assert option ordering.
List<String> _sortedLabels(int count) =>
    List.generate(count, (i) => String.fromCharCode('A'.codeUnitAt(0) + i));

Future<int> _anyFinishedSession(SessionRepository repo) async {
  final page = await repo.fetchHistory(page: 1, size: 100);
  final finished = page.items.where((i) => i.isFinished);
  expect(finished, isNotEmpty, reason: 'the test account needs one finished session');
  return finished.first.sessionId;
}

Future<int> _anySinglePlayerSession(SessionRepository repo) async {
  final page = await repo.fetchHistory(page: 1, size: 100);
  final single = page.items.where((i) => i.isFinished && !i.isMultiplayer);
  expect(single, isNotEmpty, reason: 'the test account needs one finished single-player session');
  return single.first.sessionId;
}

Future<int?> _anyMultiplayerSession(SessionRepository repo) async {
  final page = await repo.fetchHistory(page: 1, size: 100);
  final multi = page.items.where((i) => i.isFinished && i.isMultiplayer);
  return multi.isEmpty ? null : multi.first.sessionId;
}

/// In-memory [TokenStorage] so the live test needs no platform keystore.
class _MemoryTokenStorage extends TokenStorage {
  _MemoryTokenStorage() {
    shared = this;
  }

  static late _MemoryTokenStorage shared;

  AuthTokens? _tokens;
  Map<String, dynamic>? _user;

  @override
  Future<AuthTokens?> readTokens() async => _tokens;

  @override
  Future<void> saveTokens(AuthTokens tokens) async => _tokens = tokens;

  @override
  Future<Map<String, dynamic>?> readUserJson() async => _user;

  @override
  Future<void> saveUserJson(Map<String, dynamic> user) async => _user = user;

  @override
  Future<void> clear() async {
    _tokens = null;
    _user = null;
  }
}
