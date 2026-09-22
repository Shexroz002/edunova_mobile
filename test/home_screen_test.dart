import 'package:edunova_mobile/core/theme/app_theme.dart';
import 'package:edunova_mobile/features/analytics/domain/analytics_models.dart';
import 'package:edunova_mobile/features/auth/domain/auth_user.dart';
import 'package:edunova_mobile/features/home/widgets/competition_block.dart';
import 'package:edunova_mobile/features/home/widgets/hello_row.dart';
import 'package:edunova_mobile/features/home/widgets/quick_actions.dart';
import 'package:edunova_mobile/features/analytics/presentation/subject_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

SubjectStats _subject(String name, int correct, int total) => SubjectStats(
      subject: name,
      correct: correct,
      wrong: total - correct,
      total: total,
      percent: total == 0 ? 0 : correct / total * 100,
    );

AuthUser _user({String? school, String? grade}) => AuthUser(
      id: 1,
      username: 'shehroz1',
      firstName: 'Shehroz',
      lastName: 'Toshpo‘latov',
      schoolName: school,
      educationLevel: grade,
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
  group('SubjectStats.merged', () {
    test('folds spellings of one subject and reweighs the percentage', () {
      // The backend groups by the stored name, so "fizika" and "Fizika" arrive
      // as two rows for the same subject (BACKEND_ISSUES 52).
      final merged = SubjectStats.merged([
        _subject('fizika', 25, 61),
        _subject('Fizika', 2, 5),
      ]);

      expect(merged, hasLength(1));
      expect(merged.single.correct, 27);
      expect(merged.single.total, 66);
      // 27/66 = 40.9%, not the 40.5% an average of the two would give.
      expect(merged.single.percent, closeTo(40.9, 0.1));
    });

    test('keeps the capitalised spelling whichever order they arrive in', () {
      expect(SubjectStats.merged([_subject('fizika', 1, 2), _subject('Fizika', 1, 2)])
          .single.subject, 'Fizika');
      expect(SubjectStats.merged([_subject('Fizika', 1, 2), _subject('fizika', 1, 2)])
          .single.subject, 'Fizika');
    });

    test('leaves genuinely different subjects alone', () {
      final merged = SubjectStats.merged([
        _subject('Fizika', 1, 2),
        _subject('Kimyo', 1, 2),
      ]);
      expect(merged, hasLength(2));
    });
  });

  group('SubjectList', () {
    testWidgets('puts the weakest subject first, so the order is the advice',
        (tester) async {
      await _pump(
        tester,
        SubjectList(
          subjects: [_subject('Ingliz tili', 22, 37), _subject('Fizika', 25, 61)],
          onPractise: (_) {},
        ),
      );

      final names = tester.widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .where((d) => d == 'Fizika' || d == 'Ingliz tili')
          .toList();
      expect(names, ['Fizika', 'Ingliz tili']);
    });

    testWidgets('rounds the percentage instead of showing two decimals',
        (tester) async {
      // The old card printed "59.46%", which is precision nobody can act on.
      await _pump(tester, SubjectList(subjects: [_subject('Ingliz tili', 22, 37)],
          onPractise: (_) {}));

      expect(find.text('59%'), findsOneWidget);
      expect(find.text('59.46%'), findsNothing);
    });

    testWidgets('a row hands its subject back, which is how it starts a test',
        (tester) async {
      String? practised;
      await _pump(tester, SubjectList(subjects: [_subject('Fizika', 1, 2)],
          onPractise: (subject) => practised = subject));

      await tester.tap(find.text('Fizika'));
      expect(practised, 'Fizika');
    });

    testWidgets('capitalises a name the quiz author typed in lower case',
        (tester) async {
      // Merging only settles duplicates; a subject used once in lower case
      // would otherwise sit next to a capitalised one.
      await _pump(tester, SubjectList(subjects: [_subject('matematika', 1, 4)],
          onPractise: (_) {}));

      expect(find.text('Matematika'), findsOneWidget);
      expect(find.text('matematika'), findsNothing);
    });

    testWidgets('but hands the stored name back, which is what filters quizzes',
        (tester) async {
      String? practised;
      await _pump(tester, SubjectList(subjects: [_subject('matematika', 1, 4)],
          onPractise: (subject) => practised = subject));

      await tester.tap(find.text('Matematika'));
      expect(practised, 'matematika');
    });

    testWidgets('a merged subject appears once', (tester) async {
      await _pump(
        tester,
        SubjectList(
          subjects: [_subject('fizika', 25, 61), _subject('Fizika', 2, 5)],
          onPractise: (_) {},
        ),
      );
      expect(find.text('Fizika'), findsOneWidget);
      expect(find.text('fizika'), findsNothing);
    });
  });

  group('HelloRow', () {
    testWidgets('greets by first name on one line', (tester) async {
      await _pump(
        tester,
        HelloRow(user: _user(school: '42-maktab', grade: '11-sinf'), onCompleteProfile: () {}),
      );

      expect(find.textContaining('Shehroz'), findsOneWidget);
      expect(find.text('42-maktab · 11-sinf'), findsOneWidget);
    });

    testWidgets('asks for the missing profile instead of apologising for it',
        (tester) async {
      // This used to read "Maktab nomi kiritilmagan • Sinf ko'rsatilmagan".
      var tapped = false;
      await _pump(tester, HelloRow(user: _user(), onCompleteProfile: () => tapped = true));

      expect(find.text('Maktab va sinfni kiriting'), findsOneWidget);
      expect(find.textContaining('kiritilmagan'), findsNothing);

      await tester.tap(find.text('Maktab va sinfni kiriting'));
      expect(tapped, isTrue);
    });

    testWidgets('shows whichever half of the profile is filled in', (tester) async {
      await _pump(tester, HelloRow(user: _user(grade: '11-sinf'), onCompleteProfile: () {}));
      expect(find.text('11-sinf'), findsOneWidget);
    });
  });

  group('CompetitionBlock', () {
    testWidgets('carries both directions of a competition', (tester) async {
      // "Jonli sessiya" was the backend's word for joining one, and it sat in
      // the action grid, away from the card that creates one.
      var created = false;
      var joined = false;
      await _pump(
        tester,
        CompetitionBlock(onCreate: () => created = true, onJoin: () => joined = true),
      );

      expect(find.text('Musobaqa'), findsOneWidget);
      expect(find.textContaining('Jonli'), findsNothing);

      await tester.tap(find.text('Yaratish'));
      await tester.tap(find.text('Kod bilan kirish'));
      expect(created, isTrue);
      expect(joined, isTrue);
    });

    testWidgets('keeps both buttons at the 44 dp floor', (tester) async {
      await _pump(tester, CompetitionBlock(onCreate: () {}, onJoin: () {}));

      for (final label in ['Yaratish', 'Kod bilan kirish']) {
        final button =
            find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first;
        expect(tester.getSize(button).height, greaterThanOrEqualTo(44), reason: label);
      }
    });

    testWidgets('renders in light mode too', (tester) async {
      await _pump(tester, CompetitionBlock(onCreate: () {}, onJoin: () {}),
          theme: AppTheme.light());
      expect(tester.takeException(), isNull);
    });
  });

  group('QuickActions', () {
    Widget row() => QuickActions(
          actions: [
            QuickAction(
                icon: Icons.add_box_outlined,
                color: const Color(0xFF34D399),
                label: 'Test yaratish',
                onTap: () {}),
            QuickAction(
                icon: Icons.play_circle_outline_rounded,
                color: const Color(0xFF818CF8),
                label: 'Testlar',
                onTap: () {}),
            QuickAction(
                icon: Icons.history_rounded,
                color: const Color(0xFFF59E0B),
                label: 'Natijalar',
                onTap: () {}),
          ],
        );

    testWidgets('fits three tiles on one row without overflowing', (tester) async {
      await _pump(tester, row());

      expect(find.text('Test yaratish'), findsOneWidget);
      expect(find.text('Testlar'), findsOneWidget);
      expect(find.text('Natijalar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('every tile clears the 44 dp target', (tester) async {
      await _pump(tester, row());

      for (final label in ['Test yaratish', 'Testlar', 'Natijalar']) {
        final tile = find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first;
        final size = tester.getSize(tile);
        expect(size.width, greaterThanOrEqualTo(44), reason: label);
        expect(size.height, greaterThanOrEqualTo(44), reason: label);
      }
    });

    testWidgets('survives a large system font', (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: MediaQuery.withClampedTextScaling(
              minScaleFactor: 1.5,
              maxScaleFactor: 1.5,
              child: Padding(padding: const EdgeInsets.all(16), child: row()),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
