import 'package:edunova_mobile/core/theme/app_theme.dart';
import 'package:edunova_mobile/core/utils/formatters.dart';
import 'package:edunova_mobile/core/widgets/quiz/option_tile.dart';
import 'package:edunova_mobile/features/home/widgets/mistakes_row.dart';
import 'package:edunova_mobile/features/mistakes/domain/mistake_models.dart';
import 'package:edunova_mobile/features/mistakes/presentation/widgets/due_card.dart';
import 'package:edunova_mobile/features/mistakes/presentation/widgets/review_question.dart';
import 'package:edunova_mobile/features/mistakes/presentation/widgets/review_summary.dart';
import 'package:edunova_mobile/features/mistakes/presentation/widgets/subject_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 10, 5, 9);

const _question = MistakeQuestion(
  questionId: 7,
  questionText: 'x² − 5x + 6 = 0 ildizlari yig‘indisi nechaga teng?',
  subject: 'matematika',
  topic: 'Kvadrat tenglamalar',
  wrongCount: 2,
  correctOption: 'A',
  options: [
    MistakeOption(label: 'A', text: '5'),
    MistakeOption(label: 'B', text: '6'),
    MistakeOption(label: 'C', text: '−5'),
  ],
);

MistakeAnswerResult _result({
  bool correct = false,
  bool cleared = false,
  int streak = 0,
}) =>
    MistakeAnswerResult(
      questionId: 7,
      isCorrect: correct,
      streak: streak,
      cleared: cleared,
      remainingDue: 4,
      correctOption: 'A',
    );

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  ThemeData? theme,
  // ReviewSummary fills the screen with Spacers, the way the review route
  // places it; a scroll view would give it unbounded height.
  bool scroll = true,
}) async {
  tester.view.physicalSize = const Size(390, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.dark(),
      home: Scaffold(
        body: scroll
            ? SingleChildScrollView(
                child: Padding(padding: const EdgeInsets.all(16), child: child),
              )
            : child,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('formatUntil', () {
    test('names the near future rather than collapsing it to "hozir"', () {
      // formatRelativeShort answers "how long ago" and returns "hozir" for any
      // future date, which a review schedule cannot use.
      expect(formatUntil(_now.add(const Duration(hours: 2)), now: _now), 'bugun');
      expect(formatUntil(DateTime(2026, 10, 6), now: _now), 'ertaga');
      expect(formatUntil(DateTime(2026, 10, 8), now: _now), '3 kundan keyin');
      expect(formatRelativeShort(DateTime(2026, 10, 6), now: _now), 'hozir');
    });

    test('falls back to a date beyond a week', () {
      expect(formatUntil(DateTime(2026, 10, 20), now: _now), formatDate(DateTime(2026, 10, 20)));
    });

    test('counts calendar days, not elapsed hours', () {
      // 23:00 today to 01:00 tomorrow is two hours and still "ertaga".
      expect(
        formatUntil(DateTime(2026, 10, 6, 1), now: DateTime(2026, 10, 5, 23)),
        'ertaga',
      );
    });
  });

  group('MistakeOverview', () {
    test('parses the counts the bank screen needs', () {
      final overview = MistakeOverview.fromJson({
        'total': 42,
        'due': 12,
        'cleared_last_30_days': 31,
        'subjects': [
          {'subject': 'Matematika', 'total': 18, 'due': 6},
          {'subject': 'Ingliz tili', 'total': 3, 'due': 0, 'next_due_at': '2026-10-06T05:00:00'},
        ],
      });

      expect(overview.total, 42);
      expect(overview.due, 12);
      expect(overview.clearedLast30Days, 31);
      expect(overview.subjects, hasLength(2));
      expect(overview.subjects.last.nextDueAt, isNotNull);
      expect(overview.isEmpty, isFalse);
    });

    test('a missing body is an empty bank, not a crash', () {
      expect(MistakeOverview.fromJson(null).isEmpty, isTrue);
    });
  });

  group('DueCard', () {
    testWidgets('leads with the count and names the busiest subjects',
        (tester) async {
      await _pump(
        tester,
        DueCard(
          overview: MistakeOverview.fromJson({
            'total': 42,
            'due': 12,
            'subjects': [
              {'subject': 'Matematika', 'total': 18, 'due': 6},
              {'subject': 'Fizika', 'total': 14, 'due': 4},
              {'subject': 'Ingliz tili', 'total': 3, 'due': 0},
            ],
          }),
          onStart: () {},
        ),
      );

      expect(find.text('12 ta savol'), findsOneWidget);
      expect(find.text('Matematika 6 · Fizika 4'), findsOneWidget);
      expect(find.text('Takrorlashni boshlash'), findsOneWidget);
    });
  });

  group('MistakeSubjectRow', () {
    testWidgets('a subject with nothing due cannot be reviewed', (tester) async {
      var tapped = false;
      await _pump(
        tester,
        MistakeSubjectRow(
          subject: MistakeSubject(
            subject: 'ingliz tili',
            total: 3,
            due: 0,
            nextDueAt: DateTime.now().add(const Duration(days: 1)),
          ),
          onTap: () => tapped = true,
        ),
      );

      expect(find.text('Ingliz tili'), findsOneWidget);
      expect(find.textContaining('qaytadi'), findsOneWidget);

      await tester.tap(find.text('Ingliz tili'));
      expect(tapped, isFalse, reason: 'no practising ahead of schedule');
    });

    testWidgets('a due subject opens its own review', (tester) async {
      var tapped = false;
      await _pump(
        tester,
        MistakeSubjectRow(
          subject: const MistakeSubject(subject: 'matematika', total: 18, due: 6),
          onTap: () => tapped = true,
        ),
      );

      expect(find.text('6 tasi bugun'), findsOneWidget);
      await tester.tap(find.text('Matematika'));
      expect(tapped, isTrue);
    });
  });

  group('ReviewQuestion', () {
    Widget question({MistakeAnswerResult? result, String? chosen}) => ReviewQuestion(
          question: _question,
          progress: 0.25,
          chosen: chosen,
          result: result,
          sending: false,
          error: null,
          onChoose: (_) {},
          onNext: () {},
          isLast: false,
        );

    /// The state each option is drawn in, by label.
    Map<String, OptionState> states(WidgetTester tester) => {
          for (final tile in tester.widgetList<OptionTile>(find.byType(OptionTile)))
            tile.label: tile.state,
        };

    testWidgets('hides the answer until the student has chosen', (tester) async {
      await _pump(tester, question());

      expect(states(tester).values, everyElement(OptionState.idle));
      expect(find.text('Keyingi savol'), findsNothing);
    });

    testWidgets('marks the right answer and the student\'s own beside it',
        (tester) async {
      // A test measures and withholds; a review teaches and shows.
      await _pump(tester, question(chosen: 'C', result: _result()));

      expect(states(tester), {
        'A': OptionState.correct,
        'B': OptionState.idle,
        'C': OptionState.wrong,
      });
      expect(find.textContaining('2-marta xato qildingiz'), findsOneWidget);
      expect(find.text('Keyingi savol'), findsOneWidget);
    });

    testWidgets('says the question is gone once it is cleared', (tester) async {
      await _pump(
        tester,
        question(chosen: 'A', result: _result(correct: true, cleared: true, streak: 2)),
      );

      expect(find.textContaining('o‘zlashtirdingiz'), findsOneWidget);
      expect(find.textContaining('qaytadi'), findsNothing);
    });

    testWidgets('a first correct answer promises one more pass', (tester) async {
      await _pump(
        tester,
        question(chosen: 'A', result: _result(correct: true, streak: 1)),
      );

      expect(find.textContaining('yana bir marta qaytadi'), findsOneWidget);
    });

    testWidgets('renders in light mode too', (tester) async {
      await _pump(tester, question(chosen: 'C', result: _result()), theme: AppTheme.light());
      expect(tester.takeException(), isNull);
    });

    testWidgets('draws LaTeX instead of printing its source', (tester) async {
      // The review first shipped with a plain Text, so a maths question read
      // "$\\frac{7}{8}$ dan ..." on the device.
      const latex = MistakeQuestion(
        questionId: 9,
        questionText: r'$\frac{7}{8}$ dan $\frac{1}{4}$ ni ayiring.',
        subject: 'matematika',
        wrongCount: 1,
        correctOption: 'C',
        options: [
          MistakeOption(label: 'A', text: r'$\frac{6}{4}$'),
          MistakeOption(label: 'C', text: r'$\frac{5}{8}$'),
        ],
      );

      await _pump(
        tester,
        ReviewQuestion(
          question: latex,
          progress: 0.5,
          chosen: null,
          result: null,
          sending: false,
          error: null,
          onChoose: (_) {},
          onNext: () {},
          isLast: true,
        ),
      );

      expect(find.byType(Math), findsWidgets);
      expect(find.textContaining(r'\frac'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('ReviewSummary', () {
    testWidgets('leads with what was mastered, not a score', (tester) async {
      await _pump(
        tester,
        ReviewSummary(correct: 9, wrong: 3, cleared: 4, onClose: () {}),
        scroll: false,
      );

      expect(find.text('4'), findsOneWidget);
      expect(find.text('ta savolni o‘zlashtirdingiz'), findsOneWidget);
      expect(find.text('8'), findsOneWidget, reason: '9 + 3 − 4 return');
      // A percentage here would invite comparison with test results.
      expect(find.textContaining('%'), findsNothing);
      expect(find.textContaining('Natijalarga yozilmaydi'), findsOneWidget);
    });
  });

  group('MistakesRow', () {
    MistakeOverview bank({required int total, required int due, DateTime? next}) =>
        MistakeOverview(
          total: total,
          due: due,
          clearedLast30Days: 0,
          subjects: const [],
          nextDueAt: next,
        );

    testWidgets('counts what is due and badges it', (tester) async {
      await _pump(tester, MistakesRow(overview: bank(total: 12, due: 5), onTap: () {}));

      expect(find.text('5 ta savol bugun takrorlashga tayyor'), findsOneWidget);
      expect(find.text('5'), findsOneWidget, reason: 'the badge');
    });

    testWidgets('stays on a quiet day, so the bank keeps an entry point', (tester) async {
      // The row is the only route to /mistakes: hiding it whenever nothing is
      // due would make the bank's own screens unreachable.
      await _pump(
        tester,
        MistakesRow(
          overview: bank(total: 12, due: 0, next: DateTime(2026, 10, 6)),
          onTap: () {},
        ),
      );

      expect(find.textContaining('12 ta savol'), findsOneWidget);
      expect(find.textContaining('takrorlashga tayyor'), findsNothing);
      expect(find.text('0'), findsNothing, reason: 'no badge for an empty queue');
    });

    testWidgets('the title fits a 360 dp phone without being clipped', (tester) async {
      // "Xatolarim" was chosen partly because it fits: at 14.5 w800 the row
      // leaves about 215 dp beside the icon and the badge, which "Xatolarni
      // takrorlash" (286 dp) would overflow into an ellipsis.
      await _pump(tester, MistakesRow(overview: bank(total: 12, due: 5), onTap: () {}));

      final title = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.text('Xatolarim'),
          matching: find.byType(RichText),
        ),
      );
      expect(title.didExceedMaxLines, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('is left out entirely while the bank is empty', (tester) async {
      expect(bank(total: 0, due: 0).isEmpty, isTrue);
    });
  });
}
