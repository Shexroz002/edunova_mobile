import 'package:edunova_mobile/core/theme/app_theme.dart';
import 'package:edunova_mobile/features/tests/domain/quiz.dart';
import 'package:edunova_mobile/features/tests/presentation/widgets/quiz_row.dart';
import 'package:edunova_mobile/features/tests/presentation/system_quiz_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A quiz with no owner comes from the shared library: the row says so, and
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
        body: QuizRow(
          quiz: quiz(canEdit: canEdit),
          onOpen: onOpen ?? () {},
          onStart: onStart ?? () {},
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

    testWidgets('the student\'s own quiz carries no badge at all', (tester) async {
      // Where a quiz came from — AI or a PDF — says nothing about taking it,
      // so that badge went with the card. "Tizim testi" stayed because it
      // explains why the row opens a notice instead of a detail page.
      await pumpCard(tester, canEdit: true);

      expect(find.text('AI'), findsNothing);
      expect(find.text('Tizim testi'), findsNothing);
    });

    testWidgets('a system quiz can still be started from the row', (tester) async {
      var started = false;
      await pumpCard(tester, canEdit: false, onStart: () => started = true);

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();
      expect(started, isTrue);
    });
  });

  group('the row', () {
    testWidgets('says the subject, the count and how long it takes',
        (tester) async {
      // The card said all that plus a description that restated the title,
      // three badges, a creation date and two buttons — 298 dp for one quiz.
      await pumpCard(tester, canEdit: true);

      expect(find.text('Matematika · 10 savol · ~10 daqiqa'), findsOneWidget);
      expect(find.text('Boshlash'), findsNothing);
      expect(find.text('Musobaqa'), findsNothing);
    });

    testWidgets('stays under 100 dp', (tester) async {
      await pumpCard(tester, canEdit: true);

      final row = find.byType(QuizRow);
      expect(tester.getSize(row).height, lessThan(100));
    });

    testWidgets('locks a quiz whose questions are not ready', (tester) async {
      var started = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: QuizRow(
              quiz: quiz(canEdit: true, questionCount: 0),
              onOpen: () {},
              onStart: () => started = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
      expect(find.textContaining('savol yo‘q'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.lock_outline_rounded));
      expect(started, isFalse);
    });

    testWidgets('the row opens the detail, the button starts the test',
        (tester) async {
      var opened = false;
      var started = false;
      await pumpCard(
        tester,
        canEdit: true,
        onOpen: () => opened = true,
        onStart: () => started = true,
      );

      await tester.tap(find.text('Matematika: asosiy bilimlar testi'));
      expect(opened, isTrue);
      expect(started, isFalse);

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      expect(started, isTrue);
    });

    testWidgets('renders in light mode too', (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: QuizRow(quiz: quiz(canEdit: false), onOpen: () {}, onStart: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
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
