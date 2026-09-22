import 'package:edunova_mobile/core/theme/app_theme.dart';
import 'package:edunova_mobile/features/analytics/domain/analytics_models.dart';
import 'package:edunova_mobile/features/analytics/presentation/subject_list.dart';
import 'package:edunova_mobile/features/statistics/widgets/advice_block.dart';
import 'package:edunova_mobile/features/statistics/widgets/weekly_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _monday = DateTime(2026, 9, 14);

DailyActivity _day(int offset, {int total = 0, int done = 0}) => DailyActivity(
      day: _monday.add(Duration(days: offset)),
      total: total,
      done: done,
    );

SubjectStats _subject(String name, int correct, int total) => SubjectStats(
      subject: name,
      correct: correct,
      wrong: total - correct,
      total: total,
      percent: total == 0 ? 0 : correct / total * 100,
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
  group('WeeklyChart', () {
    final week = [
      _day(0, total: 2, done: 1),
      _day(1, total: 1, done: 1),
      _day(2, total: 4, done: 2),
      _day(3, total: 1),
      _day(4, total: 3, done: 2),
      _day(5, total: 1, done: 1),
      _day(6),
    ];

    testWidgets('summarises the week by what was actually finished',
        (tester) async {
      // The chart counted sessions started, so a test opened and left after
      // five questions stood as tall as one answered to the end.
      await _pump(tester, WeeklyChart(days: week));

      expect(find.text('12 ta sessiya · 7 tasi tugallangan'), findsOneWidget);
      expect(find.text('Tugallangan'), findsOneWidget);
      expect(find.text('Tashlab ketilgan'), findsOneWidget);
    });

    testWidgets('says so plainly when nothing was done', (tester) async {
      await _pump(tester, WeeklyChart(days: [for (var i = 0; i < 7; i++) _day(i)]));
      expect(find.text('Bu hafta test ishlanmagan'), findsOneWidget);
    });

    testWidgets('labels every weekday and survives a week of zeros',
        (tester) async {
      await _pump(tester, WeeklyChart(days: [for (var i = 0; i < 7; i++) _day(i)]));

      for (final label in ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sha', 'Ya']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('every bar sits on the same baseline', (tester) async {
      // Flexing the two parts of a bar left the finished share unpainted, and
      // the gap it took up lifted mixed days above the others.
      await _pump(tester, WeeklyChart(days: week));

      final tops = [
        for (final label in ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sha', 'Ya'])
          tester.getTopLeft(find.text(label)).dy,
      ];
      expect(tops.toSet(), hasLength(1), reason: 'weekday labels must line up');
    });

    testWidgets('draws one bar per day, on a fixed track', (tester) async {
      // Every bar is one painter, so a mixed day cannot end up with its
      // finished share unpainted and the gap pushing it off the baseline.
      await _pump(tester, WeeklyChart(days: week));

      final bars = find.descendant(
        of: find.byType(WeeklyChart),
        matching: find.byType(CustomPaint),
      );
      // Seven bars plus the legend's hatched swatch, among the framework's own
      // painters, so this only asserts the floor.
      expect(bars.evaluate().length, greaterThanOrEqualTo(8));
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders in light mode too', (tester) async {
      await _pump(tester, WeeklyChart(days: week), theme: AppTheme.light());
      expect(tester.takeException(), isNull);
    });
  });

  group('SubjectList with counts', () {
    testWidgets('adds the counts Statistika needs and the home page does not',
        (tester) async {
      await _pump(
        tester,
        SubjectList(
          subjects: [_subject('Ingliz tili', 22, 37)],
          showCounts: true,
          onPractise: (_) {},
        ),
      );

      expect(find.text('59%'), findsOneWidget);
      expect(find.text('22 / 37 to‘g‘ri'), findsOneWidget);
      // The wrong count is the difference; stating it too was the third
      // statement of one fact, next to "✓59% ✗41%".
      expect(find.textContaining('xato'), findsNothing);
      expect(find.text('41%'), findsNothing);
    });

    testWidgets('leaves the counts off by default', (tester) async {
      await _pump(
        tester,
        SubjectList(subjects: [_subject('Ingliz tili', 22, 37)], onPractise: (_) {}),
      );
      expect(find.text('22 / 37 to‘g‘ri'), findsNothing);
    });

    testWidgets('merges and capitalises here too, weakest first',
        (tester) async {
      // Statistika drew its own list, so one app showed "Fizika 41%" on the
      // home page and "fizika 41%" here (BACKEND_ISSUES 52).
      await _pump(
        tester,
        SubjectList(
          subjects: [
            _subject('Ingliz tili', 22, 37),
            _subject('fizika', 25, 61),
            _subject('Fizika', 2, 5),
          ],
          showCounts: true,
          onPractise: (_) {},
        ),
      );

      expect(find.text('fizika'), findsNothing);
      expect(find.text('Fizika'), findsOneWidget);
      expect(find.text('27 / 66 to‘g‘ri'), findsOneWidget);

      final names = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .where((d) => d == 'Fizika' || d == 'Ingliz tili')
          .toList();
      expect(names, ['Fizika', 'Ingliz tili']);
    });

    testWidgets('hands back the stored name, which is what filters quizzes',
        (tester) async {
      String? practised;
      await _pump(
        tester,
        SubjectList(
          subjects: [_subject('fizika', 25, 61)],
          showCounts: true,
          onPractise: (subject) => practised = subject,
        ),
      );

      await tester.tap(find.text('Fizika'));
      expect(practised, 'fizika');
    });
  });

  group('AdviceBlock', () {
    const block = RecommendationBlock(
      title: 'Yaxshilash kerak',
      text: 'matematika fanida natijani yaxshilash uchun imkoniyat bor. Hozirgi '
          "ko'rsatkich 26.7%. Muntazam mashq va xatolar ustida ishlash bu "
          "fandagi o'sishni tezlashtiradi.",
    );

    testWidgets('clamps the backend text until it is opened', (tester) async {
      // Three blocks of this ran to about 550 dp of prose.
      await _pump(
        tester,
        const AdviceBlock(
          block: block,
          color: Color(0xFFF59E0B),
          icon: Icons.trending_up_rounded,
        ),
      );

      Text body() => tester.widget<Text>(find.textContaining('matematika fanida'));
      expect(body().maxLines, 2);
      expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);

      await tester.tap(find.text('Yaxshilash kerak'));
      await tester.pumpAndSettle();

      expect(body().maxLines, isNull);
      expect(find.byIcon(Icons.expand_less_rounded), findsOneWidget);
    });

    testWidgets('its action names the subject rather than the whole list',
        (tester) async {
      // All three blocks used to push /tests, leaving the student to find the
      // subject the advice had just named.
      var practised = false;
      await _pump(
        tester,
        AdviceBlock(
          block: block,
          color: const Color(0xFFF59E0B),
          icon: Icons.trending_up_rounded,
          actionLabel: 'Matematika bo‘yicha mashq qilish',
          onAction: () => practised = true,
        ),
      );

      await tester.tap(find.text('Matematika bo‘yicha mashq qilish'));
      expect(practised, isTrue);
    });

    testWidgets('shows no action when there is nowhere to go', (tester) async {
      await _pump(
        tester,
        const AdviceBlock(
          block: block,
          color: Color(0xFF22C55E),
          icon: Icons.thumb_up_alt_outlined,
        ),
      );
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    });
  });
}
