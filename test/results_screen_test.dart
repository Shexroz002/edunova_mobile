import 'package:edunova_mobile/core/theme/app_theme.dart';
import 'package:edunova_mobile/core/utils/formatters.dart';
import 'package:edunova_mobile/features/results/presentation/results_screen.dart';
import 'package:edunova_mobile/features/results/presentation/widgets/result_row.dart';
import 'package:edunova_mobile/features/session/domain/session_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 9, 19, 12);

HistoryItem _item({
  int sessionId = 1,
  String title = 'Matematika test savollari',
  String subject = 'matematika',
  int? correct = 13,
  int? wrong = 17,
  int? total = 30,
  int participants = 1,
  int rank = 1,
  DateTime? finished,
  int minutesTaken = 22,
}) {
  final created = finished ?? _now;
  return HistoryItem(
    sessionId: sessionId,
    title: title,
    subject: subject,
    rank: rank,
    participantCount: participants,
    correctAnswers: correct,
    wrongAnswers: wrong,
    totalQuestions: total,
    createdAt: created,
    finishedAt: correct == null ? null : created.add(Duration(minutes: minutesTaken)),
  );
}

Future<void> _pump(WidgetTester tester, Widget child, {ThemeData? theme}) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.dark(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('historyGroup', () {
    test('names the recent days and falls back to the month', () {
      expect(historyGroup(_now, now: _now), 'Bugun');
      expect(historyGroup(_now.subtract(const Duration(days: 1)), now: _now), 'Kecha');
      expect(historyGroup(_now.subtract(const Duration(days: 4)), now: _now), 'Bu hafta');
      expect(historyGroup(DateTime(2026, 9, 5), now: _now), 'Sentyabr');
    });

    test('adds the year once it is not the current one', () {
      expect(historyGroup(DateTime(2025, 11, 3), now: _now), 'Noyabr 2025');
    });

    test('counts calendar days, not elapsed hours', () {
      // 23:30 yesterday to 00:30 today is one hour apart and still "Kecha".
      expect(
        historyGroup(DateTime(2026, 9, 18, 23, 30), now: DateTime(2026, 9, 19, 0, 30)),
        'Kecha',
      );
    });
  });

  group('ResultGroup', () {
    test('keeps rows in the order they arrive, under one heading each', () {
      final groups = ResultGroup.of([
        _item(sessionId: 1, finished: _now),
        _item(sessionId: 2, finished: _now.subtract(const Duration(days: 1))),
        _item(sessionId: 3, finished: _now.subtract(const Duration(days: 1, hours: 3))),
        _item(sessionId: 4, finished: DateTime(2026, 9, 2)),
      ], now: _now);

      expect(groups.map((g) => g.label).toList(), ['Bugun', 'Kecha', 'Sentyabr']);
      expect(groups[1].items.map((i) => i.sessionId).toList(), [2, 3]);
    });
  });

  group('HistoryItem.isComplete', () {
    test('a fully answered test is complete', () {
      expect(_item(correct: 13, wrong: 17, total: 30).isComplete, isTrue);
    });

    test('answering five of thirty is not, even though isFinished is true', () {
      // `isFinished` only catches null counts; this row carries real zeros.
      final walked = _item(correct: 0, wrong: 5, total: 30);
      expect(walked.isFinished, isTrue);
      expect(walked.isComplete, isFalse);
      expect(walked.answered, 5);
    });

    test('a session with no counts at all is not complete', () {
      expect(_item(correct: null, wrong: null, total: 30).isComplete, isFalse);
    });
  });

  group('ResultRow', () {
    Widget row(HistoryItem item, {VoidCallback? onOpen, VoidCallback? onLeaderboard}) =>
        ResultRow(
          item: item,
          onOpen: onOpen ?? () {},
          onLeaderboard: onLeaderboard ?? () {},
        );

    testWidgets('states the score once, with the meta line beside it',
        (tester) async {
      // The card this replaces said it four ways: a percent pill, a grade
      // letter, a progress bar and count chips.
      await _pump(tester, row(_item()));

      expect(find.text('43%'), findsOneWidget);
      expect(find.text('Matematika test savollari'), findsOneWidget);
      expect(find.text('Matematika · 30 ta savol · 22 daqiqa'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('a test handed in with gaps is still a result', (tester) async {
      // Live row from the device: 0 correct, 5 wrong, 30 questions — the
      // student answered five and handed it in. The session is over, so the
      // score stands; the meta line says how much of it was attempted.
      await _pump(tester, row(_item(correct: 0, wrong: 5, total: 30)));

      expect(find.text('0%'), findsOneWidget);
      expect(find.byIcon(Icons.pause_circle_outline_rounded), findsNothing);
      expect(find.textContaining('5/30 javob berilgan'), findsOneWidget);
    });

    testWidgets('a session that reported nothing claims no score', (tester) async {
      // Null counts mean the attempt was never scored, so there is no result
      // to state — and calling it 0 % would invent one.
      await _pump(tester, row(_item(correct: null, wrong: null, total: 30)));

      expect(find.textContaining('%'), findsNothing);
      expect(find.byIcon(Icons.pause_circle_outline_rounded), findsNothing);
    });

    testWidgets('names the placing only for a competition, and opens it',
        (tester) async {
      // Solo sessions had a "Reyting" button too, where the leaderboard holds
      // one person: you.
      await _pump(tester, row(_item()));
      expect(find.byIcon(Icons.emoji_events_rounded), findsNothing);

      var opened = false;
      await _pump(
        tester,
        row(_item(participants: 5, rank: 2), onLeaderboard: () => opened = true),
      );
      expect(find.text('2/5'), findsOneWidget);

      await tester.tap(find.text('2/5'));
      expect(opened, isTrue);
    });

    testWidgets('the rank chip clears the 44 dp control floor', (tester) async {
      // The pill itself is 22 dp so it fits the meta line; the tap area around
      // it is what has to be reachable.
      await _pump(tester, row(_item(participants: 5, rank: 2)));

      final target =
          find.ancestor(of: find.text('2/5'), matching: find.byType(InkWell)).first;
      expect(tester.getSize(target).height, greaterThanOrEqualTo(44));
    });

    testWidgets('tapping the chip does not also open the result sheet',
        (tester) async {
      var opened = false;
      var leaderboard = false;
      await _pump(
        tester,
        row(
          _item(participants: 5, rank: 2),
          onOpen: () => opened = true,
          onLeaderboard: () => leaderboard = true,
        ),
      );

      await tester.tap(find.text('2/5'));
      await tester.pump();
      expect(leaderboard, isTrue);
      expect(opened, isFalse);
    });

    testWidgets('a long title keeps its width when a rank chip is present',
        (tester) async {
      // With the chip beside the score, the title had 119 dp and clipped even
      // across two lines; on the meta line it leaves the title 176 dp.
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: row(_item(
                title: 'Fizika: mustahkamlash uchun test',
                participants: 2,
                rank: 1,
              )),
            ),
          ),
        ),
      );
      await tester.pump();

      final title = tester.getSize(find.text('Fizika: mustahkamlash uchun test'));
      expect(title.width, greaterThan(160));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the row itself is the one way in', (tester) async {
      var opened = false;
      await _pump(tester, row(_item(), onOpen: () => opened = true));

      expect(find.text("Ko'rish"), findsNothing);
      expect(find.text('Reyting'), findsNothing);

      await tester.tap(find.text('Matematika test savollari'));
      expect(opened, isTrue);
    });

    testWidgets('capitalises the stored subject name', (tester) async {
      await _pump(tester, row(_item(subject: 'fizika', total: 10, correct: 5, wrong: 5)));
      expect(find.textContaining('Fizika · '), findsOneWidget);
    });

    testWidgets('colours the score by band, amber rather than red when weak',
        (tester) async {
      Color colourOf(WidgetTester t, String label) =>
          t.widget<Text>(find.text(label)).style!.color!;

      await _pump(tester, row(_item(correct: 27, wrong: 3, total: 30)));
      final good = colourOf(tester, '90%');

      await _pump(tester, row(_item(correct: 6, wrong: 24, total: 30)));
      final weak = colourOf(tester, '20%');

      expect(good, isNot(weak));
      expect(weak, isNot(const Color(0xFFEF4444)));
    });

    testWidgets('leaves room for a long title at a large font', (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: MediaQuery.withClampedTextScaling(
              minScaleFactor: 1.4,
              maxScaleFactor: 1.4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: row(_item(
                  title: 'Arifmetik va geometrik progressiyalar bo‘yicha katta test',
                  participants: 8,
                  rank: 3,
                )),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('gives a long title two lines instead of clipping it',
        (tester) async {
      // Live titles run this long: one line showed "Fizika: mustahka…".
      await _pump(tester, row(_item(
        title: 'Fizika: mustahkamlash uchun test',
        participants: 2,
        rank: 1,
      )));

      final title = tester.widget<Text>(find.text('Fizika: mustahkamlash uchun test'));
      expect(title.maxLines, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders in light mode too', (tester) async {
      await _pump(tester, row(_item()), theme: AppTheme.light());
      expect(tester.takeException(), isNull);
    });
  });
}
