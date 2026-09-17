import 'package:edunova_mobile/core/theme/app_colors.dart';
import 'package:edunova_mobile/core/theme/app_theme.dart';
import 'package:edunova_mobile/features/competition/presentation/widgets/quiz_choice_card.dart';
import 'package:edunova_mobile/features/competition/presentation/widgets/setting_row.dart';
import 'package:edunova_mobile/features/tests/domain/quiz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _quiz = QuizSummary(
  id: 96,
  title: 'Dinamika Qonunlari Bo‘yicha Test',
  subject: 'Fizika',
  questionCount: 5,
  isNew: false,
  source: QuizSource.ai,
);

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
  group('SettingRow', () {
    Widget row({
      int value = 4,
      int min = 2,
      int max = 100,
      ValueChanged<int>? onChanged,
    }) {
      return SettingRow(
        icon: Icons.people_alt_rounded,
        color: AppColors.success,
        label: 'Ishtirokchilar',
        note: 'Kichik guruh',
        value: value,
        unit: 'kishi',
        min: min,
        max: max,
        step: 1,
        presets: const [2, 4, 6, 10, 20],
        onChanged: onChanged ?? (_) {},
      );
    }

    testWidgets('shows the value and its presets without being opened',
        (tester) async {
      // The old screen hid both settings behind a collapsed step that showed
      // neither the value nor the control.
      await _pump(tester, row());

      expect(find.text('Ishtirokchilar'), findsOneWidget);
      expect(find.text('Kichik guruh'), findsOneWidget);
      expect(find.text('4'), findsWidgets);
      expect(find.text('kishi'), findsOneWidget);
      for (final preset in [2, 6, 10, 20]) {
        expect(find.text('$preset'), findsOneWidget);
      }
    });

    testWidgets('steps by one and jumps to a preset', (tester) async {
      var value = 4;
      await _pump(tester, row(onChanged: (v) => value = v));

      await tester.tap(find.byIcon(Icons.add_rounded));
      expect(value, 5);

      await tester.tap(find.byIcon(Icons.remove_rounded));
      expect(value, 3);

      await tester.tap(find.text('20'));
      expect(value, 20);
    });

    testWidgets('disables the minus at the lower bound', (tester) async {
      var touched = false;
      await _pump(tester, row(value: 2, onChanged: (_) => touched = true));

      await tester.tap(find.byIcon(Icons.remove_rounded));
      expect(touched, isFalse);

      await tester.tap(find.byIcon(Icons.add_rounded));
      expect(touched, isTrue);
    });

    testWidgets('keeps every control at the 44 dp floor', (tester) async {
      // The stepper buttons were 36 dp and the presets 30 dp in the draft.
      await _pump(tester, row());

      for (final icon in [Icons.remove_rounded, Icons.add_rounded]) {
        final button = find.ancestor(of: find.byIcon(icon), matching: find.byType(InkWell)).first;
        final size = tester.getSize(button);
        expect(size.width, greaterThanOrEqualTo(44), reason: '$icon width');
        expect(size.height, greaterThanOrEqualTo(44), reason: '$icon height');
      }

      final preset = find.ancestor(of: find.text('20'), matching: find.byType(InkWell)).first;
      final size = tester.getSize(preset);
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(40));
    });

    testWidgets('sizes each preset to its label, not to the row', (tester) async {
      // A Container with an `alignment` fills its incoming constraints, so
      // every chip took a whole row inside the Wrap. The row is 308 dp wide
      // here, so a stretched chip is unmistakable.
      await _pump(tester, row());

      for (final label in ['2', '20']) {
        final chip = find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first;
        expect(tester.getSize(chip).width, lessThan(120), reason: 'chip "$label" is stretched');
      }
    });
  });

  group('QuizChoiceCard', () {
    testWidgets('asks for a quiz when none is chosen', (tester) async {
      await _pump(
        tester,
        QuizChoiceCard(quiz: null, hasQuizzes: true, onPick: () {}, onCreateQuiz: () {}),
      );

      expect(find.text('Testni tanlang'), findsOneWidget);
      expect(find.text('Qaysi test bo‘yicha bellashasiz?'), findsOneWidget);
    });

    testWidgets('shows the chosen quiz with its subject and question count',
        (tester) async {
      await _pump(
        tester,
        QuizChoiceCard(quiz: _quiz, hasQuizzes: true, onPick: () {}, onCreateQuiz: () {}),
      );

      expect(find.text('Dinamika Qonunlari Bo‘yicha Test'), findsOneWidget);
      expect(find.text('Fizika · 5 ta savol'), findsOneWidget);
    });

    testWidgets('sends a student with no quizzes to Test yaratish',
        (tester) async {
      // `quiz_list` filters by user_id, so a new student has nothing to pick
      // and used to be shown an empty picker sheet.
      var created = false;
      await _pump(
        tester,
        QuizChoiceCard(
          quiz: null,
          hasQuizzes: false,
          onPick: () {},
          onCreateQuiz: () => created = true,
        ),
      );

      expect(find.text('Sizda hali test yo‘q'), findsOneWidget);
      expect(find.text('Testni tanlang'), findsNothing);

      await tester.tap(find.text('Test yaratish'));
      expect(created, isTrue);
    });

    testWidgets('a pending check keeps the picker rather than hiding it',
        (tester) async {
      // hasQuizzes is optimistic while the count is unknown; a preselected quiz
      // must never be replaced by the empty state either.
      await _pump(
        tester,
        QuizChoiceCard(quiz: _quiz, hasQuizzes: false, onPick: () {}, onCreateQuiz: () {}),
      );

      expect(find.text('Sizda hali test yo‘q'), findsNothing);
      expect(find.text('Dinamika Qonunlari Bo‘yicha Test'), findsOneWidget);
    });

    testWidgets('renders in light mode too', (tester) async {
      await _pump(
        tester,
        QuizChoiceCard(quiz: _quiz, hasQuizzes: true, onPick: () {}, onCreateQuiz: () {}),
        theme: AppTheme.light(),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
