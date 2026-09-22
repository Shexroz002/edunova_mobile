import 'package:edunova_mobile/core/theme/app_theme.dart';
import 'package:edunova_mobile/features/session/domain/session_models.dart';
import 'package:edunova_mobile/features/session/presentation/result_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

FinishResult _result({
  int total = 10,
  int answered = 10,
  int correct = 8,
  int wrong = 2,
  int? seconds = 372,
  List<TopicStat> topics = const [],
}) =>
    FinishResult(
      sessionId: 1,
      totalQuestions: total,
      answeredQuestions: answered,
      correctAnswers: correct,
      wrongAnswers: wrong,
      spendSeconds: seconds,
      topics: topics,
    );

const _two = [
  TopicStat(name: 'Trigonometriya', total: 6, correct: 2),
  TopicStat(name: 'Progressiyalar', total: 4, correct: 3),
];

Future<void> _pump(WidgetTester tester, FinishResult result, {ThemeData? theme}) async {
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: theme ?? AppTheme.dark(),
        home: ResultScreen(sessionId: 1, initial: result),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('the summary', () {
    testWidgets('states the score once instead of six times', (tester) async {
      await _pump(tester, _result(topics: _two));

      expect(find.text('80%'), findsOneWidget);
      expect(find.text("A'lo"), findsOneWidget);
      expect(find.text('10 ta savoldan 8 tasi to‘g‘ri'), findsOneWidget);

      // Gone: the sentence that repeated the tiles, the accuracy percentage
      // and the grade letter.
      expect(find.textContaining('Yakunlandi'), findsNothing);
      expect(find.text('Aniqlik'), findsNothing);
      expect(find.text('Baho'), findsNothing);
      expect(find.text('A'), findsNothing);
    });

    testWidgets('keeps the time, the one fact the ring does not carry',
        (tester) async {
      await _pump(tester, _result());

      expect(find.text('Vaqt'), findsOneWidget);
      expect(find.text('To‘g‘ri'), findsOneWidget);
      expect(find.text('Xato'), findsOneWidget);
    });

    testWidgets('names skipped questions in words, not a second percentage',
        (tester) async {
      // The ring is correct/total; "Aniqlik" was correct/answered, so a test
      // with skipped questions showed two percentages and explained neither.
      await _pump(tester, _result(total: 20, answered: 15, correct: 8, wrong: 7));

      expect(find.text('5 ta savolga javob bermadingiz'), findsOneWidget);
      expect(find.text('Javobsiz'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);
      // 8/15 = 53%, the old "Aniqlik" figure.
      expect(find.text('53%'), findsNothing);
    });

    testWidgets('leaves the skipped tile out when nothing was skipped',
        (tester) async {
      await _pump(tester, _result());

      expect(find.text('Javobsiz'), findsNothing);
      expect(find.textContaining('javob bermadingiz'), findsNothing);
    });
  });

  group('the topics section', () {
    testWidgets('appears once there are two topics to compare', (tester) async {
      await _pump(tester, _result(topics: _two));

      expect(find.text('MAVZULAR TAHLILI'), findsOneWidget);
      expect(find.text('Trigonometriya'), findsOneWidget);
      expect(find.text('Progressiyalar'), findsOneWidget);
    });

    testWidgets('is hidden for a single topic, which only repeats the ring',
        (tester) async {
      // A question with no topic is filed under "Umumiy", so a quiz without
      // topics produces exactly one row whose percentage is the overall score.
      await _pump(
        tester,
        _result(topics: const [TopicStat(name: 'Umumiy', total: 10, correct: 8)]),
      );

      expect(find.text('MAVZULAR TAHLILI'), findsNothing);
      expect(find.text('Umumiy'), findsNothing);
      // The score itself is still on screen, once.
      expect(find.text('80%'), findsOneWidget);
    });

    testWidgets('is hidden when the endpoint returns no topics at all',
        (tester) async {
      await _pump(tester, _result());

      expect(find.text('MAVZULAR TAHLILI'), findsNothing);
      expect(find.textContaining("ma'lumot yo'q"), findsNothing);
    });

    testWidgets('names what to go over again', (tester) async {
      await _pump(tester, _result(topics: _two));
      expect(find.textContaining('Takrorlash tavsiya etiladi'), findsOneWidget);
    });

    testWidgets('answers the weak filter rather than showing an empty state',
        (tester) async {
      await _pump(
        tester,
        _result(topics: const [
          TopicStat(name: 'Trigonometriya', total: 4, correct: 4),
          TopicStat(name: 'Progressiyalar', total: 4, correct: 3),
        ]),
      );

      await tester.tap(find.text('Zaif 0'));
      await tester.pump();

      expect(find.text('Zaif mavzular yo‘q — ajoyib!'), findsOneWidget);
    });
  });

  group('the actions', () {
    testWidgets('puts the review above the topic list', (tester) async {
      // It used to sit below the whole list, about 760 dp down the page.
      await _pump(tester, _result(topics: _two));

      final review = tester.getTopLeft(find.text('Xatolar tahlili')).dy;
      final topics = tester.getTopLeft(find.text('MAVZULAR TAHLILI')).dy;
      expect(review, lessThan(topics));
    });

    testWidgets('offers a new test at the foot of the page', (tester) async {
      await _pump(tester, _result(topics: _two));

      final again = tester.getTopLeft(find.text('Yangi test yechish')).dy;
      final review = tester.getTopLeft(find.text('Xatolar tahlili')).dy;
      expect(again, greaterThan(review));
    });

    testWidgets('renders in light mode too', (tester) async {
      await _pump(tester, _result(topics: _two), theme: AppTheme.light());
      expect(tester.takeException(), isNull);
    });
  });
}
