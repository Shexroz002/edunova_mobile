import 'package:edunova_mobile/core/network/api_client.dart';
import 'package:edunova_mobile/core/utils/json_utils.dart';
import 'package:edunova_mobile/core/storage/token_storage.dart';
import 'package:edunova_mobile/core/theme/app_theme.dart';
import 'package:edunova_mobile/features/results/presentation/widgets/result_row.dart';
import 'package:edunova_mobile/features/session/data/session_repository.dart';
import 'package:edunova_mobile/features/session/domain/session_models.dart';
import 'package:edunova_mobile/features/tests/data/tests_repository.dart';
import 'package:edunova_mobile/features/tests/domain/quiz.dart';
import 'package:edunova_mobile/features/tests/presentation/start_test_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A test started with no time limit, and the way back into an open one.
///
/// The server decides both: it leaves `deadline_at` null when no duration was
/// asked for, and reports `status` plus `attempt_finished` on every history row
/// so the client knows which of them is still open.

/// Records the calls a repository makes, and answers them with fixed JSON.
class _RecordingApi extends ApiClient {
  _RecordingApi(this.response)
      : super(tokenStorage: TokenStorage(), onSessionExpired: () {});

  final dynamic response;
  String? path;
  Map<String, dynamic>? query;
  Object? body;

  @override
  Future<dynamic> post(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    bool auth = true,
    String? contentType,
  }) async {
    this.path = path;
    this.query = query;
    body = data;
    return response;
  }

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query, bool auth = true}) async {
    this.path = path;
    this.query = query;
    return response;
  }
}

HistoryItem row({
  String? status = 'running',
  bool attemptFinished = false,
  int? limitMinutes,
  DateTime? deadlineAt,
  int? correct,
  int? total,
  int? answeredCount,
}) =>
    HistoryItem(
      sessionId: 7,
      rank: 1,
      createdAt: DateTime.utc(2026, 9, 22, 9),
      title: 'Kasrlar bo\'yicha test',
      subject: 'Matematika',
      status: status,
      attemptFinished: attemptFinished,
      limitMinutes: limitMinutes,
      deadlineAt: deadlineAt,
      correctAnswers: correct,
      wrongAnswers: 0,
      totalQuestions: total,
      answeredCount: answeredCount,
    );

class _FakeTestsRepository extends TestsRepository {
  _FakeTestsRepository() : super(_RecordingApi(null));

  @override
  Future<PageResult<QuizSummary>> fetchQuizzes({String? search, int page = 1, int size = 20}) async =>
      const PageResult(items: [], total: 0, page: 1, size: 1, pages: 1);
}

/// Records what the sheet asked the server to start.
class _SpySessionRepository extends SessionRepository {
  _SpySessionRepository() : super(_RecordingApi(null));

  int? minutes;
  bool called = false;

  @override
  Future<StartedSession> startSinglePlayer({required int quizId, int? minutes}) async {
    called = true;
    this.minutes = minutes;
    return const StartedSession(sessionId: 1, resumed: false);
  }
}

const _quiz = QuizSummary(
  id: 3,
  title: "Kasrlar bo'yicha test",
  subject: 'Matematika',
  questionCount: 10,
  isNew: false,
  source: QuizSource.ai,
  canEdit: true,
);

void main() {
  group('starting a test', () {
    test('no limit means the duration is left out of the request', () async {
      final api = _RecordingApi({'session_id': 12});

      final started = await SessionRepository(api).startSinglePlayer(quizId: 3);

      expect(started.sessionId, 12);
      expect(started.resumed, isFalse);
      // Sending `duration_minute` at all — even 0 — would be a timed test, and
      // the endpoint rejects anything that is not greater than zero.
      expect(api.query, isEmpty);
    });

    test('a chosen limit is sent as before', () async {
      final api = _RecordingApi({'session_id': 12});

      await SessionRepository(api).startSinglePlayer(quizId: 3, minutes: 30);

      expect(api.query, {'duration_minute': 30});
    });

    test('an open session is reported as resumed', () async {
      // The server ignored the duration just picked and handed back the
      // session already in progress; the sheet says so rather than letting a
      // half-spent clock look like a bug.
      final api = _RecordingApi({'session_id': 42, 'resumed': true});

      final started = await SessionRepository(api).startSinglePlayer(quizId: 3, minutes: 30);

      expect(started.sessionId, 42);
      expect(started.resumed, isTrue);
    });

    test('saved answers come back keyed by question', () async {
      final api = _RecordingApi([
        {'question_id': 5, 'selected_option': 'A'},
        {'question_id': 6, 'selected_option': 'C'},
      ]);

      final answers = await SessionRepository(api).fetchSavedAnswers(7);

      expect(answers, {5: 'A', 6: 'C'});
    });
  });

  group('the time picker', () {
    Future<_SpySessionRepository> open(WidgetTester tester) async {
      final sessions = _SpySessionRepository();
      tester.view.physicalSize = const Size(1170, 2340);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(ProviderScope(
        overrides: [
          testsRepositoryProvider.overrideWithValue(_FakeTestsRepository()),
          sessionRepositoryProvider.overrideWithValue(sessions),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showStartTestSheet(context, quiz: _quiz),
                  child: const Text('och'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('och'));
      await tester.pumpAndSettle();
      return sessions;
    }

    testWidgets('opens on no limit, so not choosing means not timed', (tester) async {
      // The recommendation used to be preselected, which made "I picked
      // nothing" start a 30-minute test the student never asked for.
      final sessions = await open(tester);

      await tester.tap(find.text('Boshlash'));
      await tester.pumpAndSettle();

      expect(sessions.called, isTrue);
      expect(sessions.minutes, isNull);
    });

    testWidgets('picking a limit starts a timed test', (tester) async {
      final sessions = await open(tester);

      await tester.tap(find.text('30 daqiqa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Boshlash'));
      await tester.pumpAndSettle();

      expect(sessions.minutes, 30);
    });

    testWidgets('and can be put back to no limit', (tester) async {
      final sessions = await open(tester);

      await tester.tap(find.text('30 daqiqa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vaqtsiz'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Boshlash'));
      await tester.pumpAndSettle();

      expect(sessions.minutes, isNull);
    });
  });

  group('how far an unfinished test got', () {
    // Nothing is scored until the test is handed in, so a session still in
    // progress carries zeroes for right and wrong. Saying "javob berilmagan"
    // on the strength of those would deny answers the server is holding.
    test('comes from the stored answer count, not the score', () {
      final item = row(limitMinutes: 10, total: 5, correct: 0, answeredCount: 1);

      expect(item.answered, 1);
    });

    test('a scored attempt still counts right plus wrong', () {
      final item = row(
        status: 'finished',
        attemptFinished: true,
        correct: 3,
        total: 10,
        answeredCount: 99, // stale, and must be ignored
      );

      expect(item.answered, 3);
    });

    testWidgets('an abandoned timed test says how far it got', (tester) async {
      tester.view.physicalSize = const Size(1170, 900);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: ResultRow(
            item: row(
              limitMinutes: 10,
              deadlineAt: DateTime.now().toUtc().add(const Duration(minutes: 8)),
              total: 5,
              correct: 0,
              answeredCount: 1,
            ),
            onOpen: () {},
            onLeaderboard: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('1/5 javob berilgan'), findsOneWidget);
      // Timed: no way back in.
      expect(find.text('Davom ettirish'), findsNothing);
    });
  });

  group('a row with no questions to count', () {
    testWidgets('says nothing was answered rather than "0/0"', (tester) async {
      // Old sessions come back with null counts. A ratio built out of them
      // states a fact the server never gave.
      tester.view.physicalSize = const Size(1170, 900);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: ResultRow(
            item: HistoryItem.fromJson(const {
              'session_id': 3,
              'rank': 1,
              'title': 'Eritmalar haqida Test',
              'subject': 'Kimyo',
              'created_at': '2026-09-01T09:00:00Z',
              'status': 'finished',
              'attempt_finished': true,
            }),
            onOpen: () {},
            onLeaderboard: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('javob berilmagan'), findsOneWidget);
      expect(find.textContaining('0/0'), findsNothing);
      expect(find.textContaining('%'), findsNothing);
    });
  });

  group('the row the server really sends', () {
    // Captured from a live untimed session (local backend, revision
    // 20260922_0006) after two answers had been stored. The counts are all
    // zero on purpose: storing an answer creates the attempt, but nothing is
    // scored until the test is handed in.
    const live = {
      'session_id': 97,
      'user_id': 10,
      'title': 'Aritmetik Progressiya Testi',
      'subject': 'Fizika',
      'rank': 1,
      'participant_count': 1,
      'correct_answers': 0,
      'wrong_answers': 0,
      'total_questions': 0,
      'finished_at': null,
      'created_at': '2026-09-23T05:21:33.935777Z',
      'status': 'running',
      'duration_minutes': null,
      'deadline_at': null,
      'attempt_finished': false,
    };

    test('parses as an open, untimed test', () {
      final item = HistoryItem.fromJson(live);

      expect(item.canResume, isTrue);
      expect(item.limitMinutes, isNull);
      expect(item.deadlineAt, isNull);
      // Zeroed counts must not read as a finished nought-out-of-nought result.
      expect(item.isFinished, isFalse);
      expect(item.isComplete, isFalse);
    });

    testWidgets('and renders the button rather than a score', (tester) async {
      tester.view.physicalSize = const Size(1170, 900);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: ResultRow(
            item: HistoryItem.fromJson(live),
            onOpen: () {},
            onLeaderboard: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'Davom ettirish'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
      expect(find.byIcon(Icons.pause_circle_outline_rounded), findsNothing);
    });
  });

  group('the same session once it is handed in', () {
    // The row above, captured again after the student finished it having
    // answered two of ten.
    const live = {
      'session_id': 97,
      'user_id': 10,
      'title': 'Aritmetik Progressiya Testi',
      'subject': 'Fizika',
      'rank': 1,
      'participant_count': 1,
      'correct_answers': 1,
      'wrong_answers': 1,
      'total_questions': 10,
      'finished_at': '2026-09-23T05:22:12.411543Z',
      'created_at': '2026-09-23T05:21:33.935777Z',
      'status': 'finished',
      'duration_minutes': null,
      'deadline_at': null,
      'attempt_finished': true,
    };

    test('is a result, and no longer resumable', () {
      final item = HistoryItem.fromJson(live);

      expect(item.canResume, isFalse);
      expect(item.isFinished, isTrue);
      // Two of ten: a result, but not a complete one.
      expect(item.answered, 2);
      expect(item.isComplete, isFalse);
    });

    testWidgets('so it shows its score, not the button', (tester) async {
      tester.view.physicalSize = const Size(1170, 900);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: ResultRow(
            item: HistoryItem.fromJson(live),
            onOpen: () {},
            onLeaderboard: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Davom ettirish'), findsNothing);
      expect(find.byIcon(Icons.pause_circle_outline_rounded), findsNothing);
      expect(find.text('10%'), findsOneWidget);
      expect(find.textContaining('2/10 javob berilgan'), findsOneWidget);
    });
  });

  group('an untimed session', () {
    test('has no deadline, so it never runs out', () {
      final info = SessionInfo.fromJson(const {
        'session_id': 7,
        'quiz_id': 3,
        'host_id': 1,
        'join_code': 'ABC123',
        'status': 'running',
        'duration_minutes': null,
        'questions_count': 10,
        'session_type': 'individual',
        'started_at': '2026-09-22T09:00:00Z',
        'deadline_at': null,
      });

      expect(info.durationMinutes, isNull);
      expect(info.deadlineAt, isNull);
    });
  });

  group('which rows can be picked up again', () {
    test('an open untimed session can', () {
      expect(row().canResume, isTrue);
    });

    test('a timed one cannot, even with minutes still on the clock', () {
      // Choosing a limit is choosing to sit the test in one go. The clock runs
      // while the student is away, so letting them back in would hand them a
      // test with time already spent — and the server refuses to reopen it
      // anyway.
      expect(
        row(limitMinutes: 30, deadlineAt: DateTime.now().toUtc().add(const Duration(minutes: 25)))
            .canResume,
        isFalse,
      );
    });

    test('nor once its window has passed', () {
      expect(
        row(limitMinutes: 30, deadlineAt: DateTime.now().toUtc().subtract(const Duration(minutes: 1)))
            .canResume,
        isFalse,
      );
    });

    test('a scored attempt cannot, whatever the session says', () {
      expect(row(attemptFinished: true).canResume, isFalse);
    });

    test('nor can a finished session', () {
      expect(row(status: 'finished', attemptFinished: true, correct: 4, total: 5).canResume, isFalse);
    });

    test('an older server that says nothing is treated as finished', () {
      final parsed = HistoryItem.fromJson(const {
        'session_id': 7,
        'rank': 1,
        'created_at': '2026-09-22T09:00:00Z',
        'correct_answers': 4,
        'wrong_answers': 1,
        'total_questions': 5,
      });

      expect(parsed.canResume, isFalse);
    });
  });

  group('the results row', () {
    Future<void> pump(WidgetTester tester, HistoryItem item, {VoidCallback? onOpen}) async {
      tester.view.physicalSize = const Size(390, 300);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: ResultRow(item: item, onOpen: onOpen ?? () {}, onLeaderboard: () {}),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('the button runs the test rather than opening a result', (tester) async {
      var opened = false;
      await pump(tester, row(), onOpen: () => opened = true);

      await tester.tap(find.text('Davom ettirish'));
      await tester.pumpAndSettle();
      expect(opened, isTrue);
    });

    testWidgets('offers to carry on with an open test', (tester) async {
      await pump(tester, row());

      expect(find.widgetWithText(FilledButton, 'Davom ettirish'), findsOneWidget);
      // The arrow into a result sheet would be a second, different promise.
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    });

    testWidgets('a test that was handed in shows what it scored', (tester) async {
      await pump(tester, row(status: 'finished', attemptFinished: true, correct: 4, total: 5));

      expect(find.text('Davom ettirish'), findsNothing);
      expect(find.text('80%'), findsOneWidget);
      // The marker is gone: a handed-in test is a result, however much of it
      // was attempted.
      expect(find.byIcon(Icons.pause_circle_outline_rounded), findsNothing);
      expect(find.textContaining('4/5 javob berilgan'), findsOneWidget);
    });

    testWidgets('a finished session with a couple of answers scores on all of them',
        (tester) async {
      // Two right out of ten asked is 20 %, not "unfinished": the eight left
      // blank are eight the student did not get, and the session is closed.
      await pump(
        tester,
        row(status: 'finished', attemptFinished: true, correct: 2, total: 10),
      );

      expect(find.text('20%'), findsOneWidget);
      expect(find.byIcon(Icons.pause_circle_outline_rounded), findsNothing);
      expect(find.textContaining('2/10 javob berilgan'), findsOneWidget);
    });

    testWidgets('an old server that sends neither status nor the flag behaves as before',
        (tester) async {
      // Production has not been updated yet: no `status`, no
      // `attempt_finished`. The row must still mark the gap and must not offer
      // to resume a session it knows nothing about.
      final parsed = HistoryItem.fromJson(const {
        'session_id': 7,
        'rank': 1,
        'title': "Kasrlar bo'yicha test",
        'subject': 'Matematika',
        'created_at': '2026-09-22T09:00:00Z',
        'correct_answers': 2,
        'wrong_answers': 0,
        'total_questions': 10,
      });
      await pump(tester, parsed);

      expect(find.text('20%'), findsOneWidget);
      expect(find.text('Davom ettirish'), findsNothing);
    });

    testWidgets('a finished one still shows its score', (tester) async {
      await pump(tester, row(status: 'finished', attemptFinished: true, correct: 5, total: 5));

      expect(find.text('Davom ettirish'), findsNothing);
      expect(find.text('100%'), findsOneWidget);
    });
  });
}
