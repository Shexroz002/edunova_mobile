import 'package:edunova_mobile/core/theme/app_theme.dart';
import 'package:edunova_mobile/features/tests/domain/quiz.dart';
import 'package:edunova_mobile/features/tests/presentation/start_test_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _quiz = QuizSummary(
  id: 91,
  title: 'Eritmalar haqida Test',
  subject: 'Kimyo',
  questionCount: 10,
  isNew: false,
  source: QuizSource.ai,
);

const _long = QuizSummary(
  id: 89,
  title: 'Matematika test savollari',
  subject: 'Matematika',
  questionCount: 30,
  isNew: false,
  source: QuizSource.ai,
);

Future<void> _open(WidgetTester tester, {QuizSummary? quiz, ThemeData? theme}) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: theme ?? AppTheme.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showStartTestSheet(context, quiz: quiz),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('showStartTestSheet', () {
    testWidgets('asks for a quiz when the caller has none', (tester) async {
      // The home hero used to push the whole list instead: list -> quiz ->
      // detail -> time sheet, four screens for one intention.
      await _open(tester);

      expect(find.text('Test ishlash'), findsOneWidget);
      expect(find.text('Testni tanlang va vaqt limitini belgilang'), findsOneWidget);
      expect(find.text('Testni tanlang...'), findsOneWidget);
      expect(find.text('Boshlash'), findsOneWidget);
    });

    testWidgets('shows a preselected quiz with its subject and count',
        (tester) async {
      await _open(tester, quiz: _quiz);

      expect(find.text('Eritmalar haqida Test'), findsOneWidget);
      expect(find.text('Kimyo · 10 ta savol'), findsOneWidget);
      expect(find.text('Testni tanlang...'), findsNothing);
    });

    testWidgets('suggests ten minutes for a ten-question quiz', (tester) async {
      // suggestedMinutes is one minute per question, at least ten.
      await _open(tester, quiz: _quiz);
      expect(find.textContaining('10 daqiqa tavsiya'), findsOneWidget);
    });

    testWidgets('and thirty for a thirty-question one', (tester) async {
      await _open(tester, quiz: _long);
      expect(find.textContaining('30 daqiqa tavsiya'), findsOneWidget);
    });

    testWidgets('offers every limit the web does', (tester) async {
      await _open(tester, quiz: _quiz);

      for (final label in ['10 daqiqa', '15 daqiqa', '45 daqiqa', '1 soat', '2 soat']) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      expect(kTestTimeOptions, [10, 15, 20, 30, 45, 60, 90, 120]);
    });

    testWidgets('keeps every limit chip at the 40 dp floor', (tester) async {
      await _open(tester, quiz: _quiz);

      final chip = find
          .ancestor(of: find.text('1 soat'), matching: find.byType(InkWell))
          .first;
      final size = tester.getSize(chip);
      expect(size.height, greaterThanOrEqualTo(40));
      // A chip that stretched across the Wrap row would be far wider.
      expect(size.width, lessThan(140));
    });

    testWidgets('says the recommendation waits for a quiz', (tester) async {
      await _open(tester);

      expect(find.textContaining('Test tanlangach'), findsOneWidget);
      expect(find.textContaining('tavsiya etiladi'), findsNothing);
    });

    testWidgets('renders in light mode too', (tester) async {
      await _open(tester, quiz: _quiz, theme: AppTheme.light());
      expect(tester.takeException(), isNull);
    });
  });
}
