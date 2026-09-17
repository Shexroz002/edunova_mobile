import 'package:edunova_mobile/core/theme/app_theme.dart';
import 'package:edunova_mobile/features/tests/domain/quiz.dart';
import 'package:edunova_mobile/features/tests/presentation/quiz_card.dart';
import 'package:edunova_mobile/features/tests/presentation/system_quiz_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A quiz with no owner comes from the shared library: the card says so, and
/// its detail page — which would list every question — stays closed.
QuizSummary quiz({required bool canEdit, int questionCount = 10}) => QuizSummary(
      id: 1,
      title: 'Matematika: asosiy bilimlar testi',
      subject: 'Matematika',
      questionCount: questionCount,
      isNew: false,
      source: QuizSource.ai,
      canEdit: canEdit,
    );

Future<void> pumpCard(
  WidgetTester tester, {
  required bool canEdit,
  VoidCallback? onOpen,
  VoidCallback? onStart,
}) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: QuizCard(
          quiz: quiz(canEdit: canEdit),
          onOpen: onOpen ?? () {},
          onStart: onStart ?? () {},
          onCompete: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the badge', () {
    testWidgets('a system quiz is labelled as one', (tester) async {
      await pumpCard(tester, canEdit: false);

      expect(find.text('Tizim testi'), findsOneWidget);
      // How it was generated is our business, not the student's.
      expect(find.text('AI'), findsNothing);
    });

    testWidgets('the student\'s own quiz still shows where it came from', (tester) async {
      await pumpCard(tester, canEdit: true);

      expect(find.text('AI'), findsOneWidget);
      expect(find.text('Tizim testi'), findsNothing);
    });

    testWidgets('a system quiz can still be started from the card', (tester) async {
      var started = false;
      await pumpCard(tester, canEdit: false, onStart: () => started = true);

      await tester.tap(find.text('Boshlash'));
      await tester.pumpAndSettle();
      expect(started, isTrue);
    });
  });

  group('the notice', () {
    Future<void> open(
      WidgetTester tester, {
      required VoidCallback onStart,
      bool canStart = true,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () =>
                      showSystemQuizNotice(context, onStart: onStart, canStart: canStart),
                  child: const Text('och'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('och'));
      await tester.pumpAndSettle();
    }

    testWidgets('says what it is and offers the way forward', (tester) async {
      await open(tester, onStart: () {});

      expect(find.text('Tizim testi'), findsOneWidget);
      expect(find.textContaining('kutubxonasidan'), findsOneWidget);
      expect(find.text('Boshlash'), findsOneWidget);
      expect(find.text('Yopish'), findsOneWidget);
    });

    testWidgets('starting from the dialog closes it and runs the test', (tester) async {
      var started = false;
      await open(tester, onStart: () => started = true);

      await tester.tap(find.text('Boshlash'));
      await tester.pumpAndSettle();

      expect(started, isTrue);
      expect(find.text('Tizim testi'), findsNothing);
    });

    testWidgets('an empty quiz is not offered a start it cannot honour', (tester) async {
      await open(tester, onStart: () {}, canStart: false);

      expect(find.text('Boshlash'), findsNothing);
      expect(find.textContaining("savollar yo'q"), findsOneWidget);
      expect(find.text('Yopish'), findsOneWidget);
    });
  });
}
