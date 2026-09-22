import 'package:edunova_mobile/core/network/api_client.dart';
import 'package:edunova_mobile/core/storage/token_storage.dart';
import 'package:edunova_mobile/core/theme/app_theme.dart';
import 'package:edunova_mobile/features/results/presentation/widgets/result_row.dart';
import 'package:edunova_mobile/features/session/data/session_repository.dart';
import 'package:edunova_mobile/features/session/domain/session_models.dart';
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

    test('a timed one can while its window lasts', () {
      expect(
        row(limitMinutes: 30, deadlineAt: DateTime.now().toUtc().add(const Duration(minutes: 5)))
            .canResume,
        isTrue,
      );
    });

    test('but not once the window has passed', () {
      // The sweep closes it within the minute; until then the row must not
      // offer a test the server would refuse.
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
    Future<void> pump(WidgetTester tester, HistoryItem item) async {
      tester.view.physicalSize = const Size(390, 300);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: ResultRow(item: item, onOpen: () {}, onLeaderboard: () {}),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('offers to carry on with an open test', (tester) async {
      await pump(tester, row());

      expect(find.byIcon(Icons.play_circle_fill_rounded), findsOneWidget);
      expect(find.textContaining('davom ettirish mumkin'), findsOneWidget);
      expect(find.byIcon(Icons.pause_circle_outline_rounded), findsNothing);
    });

    testWidgets('a test that was handed in keeps its marker', (tester) async {
      await pump(tester, row(status: 'finished', attemptFinished: true, correct: 4, total: 5));

      expect(find.byIcon(Icons.play_circle_fill_rounded), findsNothing);
      expect(find.byIcon(Icons.pause_circle_outline_rounded), findsOneWidget);
      expect(find.textContaining('4/5 javob berilgan'), findsOneWidget);
    });

    testWidgets('a finished one still shows its score', (tester) async {
      await pump(tester, row(status: 'finished', attemptFinished: true, correct: 5, total: 5));

      expect(find.byIcon(Icons.play_circle_fill_rounded), findsNothing);
      expect(find.text('100%'), findsOneWidget);
    });
  });
}
