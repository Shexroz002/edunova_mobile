import 'package:edunova_mobile/core/network/api_client.dart';
import 'package:edunova_mobile/core/realtime/socket_service.dart';
import 'package:edunova_mobile/core/storage/token_storage.dart';
import 'package:edunova_mobile/core/utils/math_segments.dart';
import 'package:edunova_mobile/core/widgets/quiz/markdown_table.dart';
import 'package:edunova_mobile/features/session/data/session_repository.dart';
import 'package:edunova_mobile/features/session/domain/session_models.dart';
import 'package:edunova_mobile/features/session/presentation/play/play_controller.dart';
import 'package:edunova_mobile/features/tests/domain/quiz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory repository: returns fixed data and records finish calls.
class _FakeSessionRepository extends SessionRepository {
  _FakeSessionRepository({required this.deadline})
      : super(ApiClient(tokenStorage: TokenStorage(), onSessionExpired: () {}));

  final DateTime deadline;
  Map<int, String>? finishedWith;

  static const _question = {
    'id': 0,
    'question_text': 'Q',
    'options': [
      {'label': 'B', 'text': 'b'},
      {'label': 'A', 'text': 'a'},
    ],
  };

  @override
  Future<SessionInfo> fetchInfo(int sessionId) async => SessionInfo.fromJson({
        'session_id': sessionId,
        'quiz_id': 1,
        'host_id': 1,
        'join_code': 'ABC123',
        'status': 'running',
        'duration_minutes': 10,
        'questions_count': 2,
        'session_type': 'individual',
        'deadline_at': deadline.toUtc().toIso8601String(),
      });

  @override
  Future<SessionQuestions> fetchQuestions(int sessionId) async => SessionQuestions.fromJson({
        'session_id': sessionId,
        'quiz_id': 1,
        'status': 'running',
        'deadline_at': deadline.toUtc().toIso8601String(),
        'questions': [
          {..._question, 'id': 11},
          {..._question, 'id': 12},
        ],
      });

  @override
  Future<FinishResult> finish({required int sessionId, required Map<int, String> answers}) async {
    finishedWith = Map.of(answers);
    return FinishResult.fromJson({
      'session_id': sessionId,
      'total_questions': 2,
      'answered_questions': answers.length,
      'correct_answers': 1,
      'wrong_answers': answers.length - 1,
      'topic_statistic': <Object>[],
    });
  }
}

void main() {
  group('parseMathSegments', () {
    test('splits inline and display math', () {
      final segments = parseMathSegments(r'Hisoblang $x^2$ va $$\frac{1}{2}$$ tamom');
      expect(segments.map((s) => s.toString()).toList(), ['Hisoblang ', '[x^2]', ' va ', '[[\\frac{1}{2}]]', ' tamom']);
    });

    test('supports \\( \\) and \\[ \\] delimiters', () {
      final segments = parseMathSegments(r'a \(b\) c \[d\]');
      expect(segments.where((s) => s.isMath).map((s) => s.value), ['b', 'd']);
    });

    test('strips ANSI escape codes left by the AI generator', () {
      const raw = '\$[3m\\sqrt{x}\\u001b[23m\$ tenglama';
      final segments = parseMathSegments(raw);
      expect(segments.first.isMath, isTrue);
      expect(segments.first.value, r'\sqrt{x}');
      expect(plainPreview(raw), r'\sqrt{x} tenglama');
    });

    test('plain text stays one segment', () {
      expect(parseMathSegments('Oddiy matn').single.isMath, isFalse);
    });
  });

  test('MarkdownTable.parse skips separator rows', () {
    final rows = MarkdownTable.parse('| Fan | Ball |\n| --- | :---: |\n| Matematika | 95 |');
    expect(rows, [
      ['Fan', 'Ball'],
      ['Matematika', '95'],
    ]);
  });

  test('AnswerOption.listFrom sorts by label', () {
    final options = AnswerOption.listFrom([
      {'label': 'C', 'text': 'c'},
      {'label': 'A', 'text': 'a', 'is_correct': true},
    ]);
    expect(options.map((o) => o.label), ['A', 'C']);
    expect(options.first.isCorrect, isTrue);
  });

  test('LeaderboardEntry.ranked puts unfinished last and shares equal ranks', () {
    final ranked = LeaderboardEntry.ranked([
      LeaderboardEntry.fromJson({'user_id': 1, 'first_name': 'Nil'}),
      LeaderboardEntry.fromJson({'user_id': 2, 'score': 3, 'total_questions': 5, 'spend_time_seconds': '40.5'}),
      LeaderboardEntry.fromJson({'user_id': 3, 'score': 4, 'total_questions': 5, 'spend_time_seconds': '90'}),
      LeaderboardEntry.fromJson({'user_id': 4, 'score': 3, 'total_questions': 5, 'spend_time_seconds': '40.5'}),
    ]);
    expect(ranked.map((e) => e.userId), [3, 2, 4, 1]);
    expect(ranked.map((e) => e.rank), [1, 2, 2, 0]);
  });

  test('FinishResult.fromReview counts correct, wrong and skipped', () {
    ReviewItem item(int id, String? selected, String topic) => ReviewItem.fromJson({
          'id': id,
          'question_text': 'Q$id',
          'topic': topic,
          'options': [
            {'label': 'A', 'text': 'a', 'is_correct': true},
            {'label': 'B', 'text': 'b', 'is_correct': false},
          ],
          'user_select_option': selected,
        });

    final result = FinishResult.fromReview(9, [item(1, 'A', 'T1'), item(2, 'B', 'T1'), item(3, null, 'T2')]);
    expect(result.correctAnswers, 1);
    expect(result.wrongAnswers, 1);
    expect(result.skipped, 1);
    expect(result.topics.firstWhere((t) => t.name == 'T1').total, 2);
  });

  group('PlayController', () {
    late SharedPreferences prefs;
    const sockets = SocketFactory(_noToken, _noToken);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('saves answers, restores them and submits all of them', () async {
      final now = DateTime(2026, 9, 11, 12);
      final repo = _FakeSessionRepository(deadline: now.add(const Duration(minutes: 5)));

      final first = PlayController(sessionId: 7, repository: repo, prefs: prefs, sockets: sockets, clock: () => now);
      await first.load();
      expect(first.questions.first.options.map((o) => o.label), ['A', 'B']);
      expect(first.remaining, const Duration(minutes: 5));
      first.select('A');
      first.next();
      first.dispose();

      final second = PlayController(sessionId: 7, repository: repo, prefs: prefs, sockets: sockets, clock: () => now);
      await second.load();
      expect(second.index, 1);
      expect(second.answers, {11: 'A'});

      second.select('B');
      await second.submit();
      expect(repo.finishedWith, {11: 'A', 12: 'B'});
      expect(second.result, isNotNull);
      expect(prefs.getString('play_progress_7'), isNull);
      second.dispose();
    });

    test('auto-submits when the deadline has already passed', () async {
      final now = DateTime(2026, 9, 11, 12);
      final repo = _FakeSessionRepository(deadline: now.subtract(const Duration(seconds: 1)));
      final controller =
          PlayController(sessionId: 8, repository: repo, prefs: prefs, sockets: sockets, clock: () => now);

      await controller.load();
      await Future<void>.delayed(Duration.zero);
      expect(repo.finishedWith, isEmpty);
      expect(controller.result, isNotNull);
      controller.dispose();
    });
  });
}

Future<String?> _noToken() async => null;
