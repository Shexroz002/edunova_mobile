import 'package:edunova_mobile/core/theme/app_theme.dart';
import 'package:edunova_mobile/features/solution/presentation/widgets/solution_arrival.dart';
import 'package:edunova_mobile/features/solution/presentation/widgets/solution_delayed.dart';
import 'package:edunova_mobile/features/solution/presentation/widgets/waiting_board.dart';
import 'package:edunova_mobile/features/solution/presentation/widgets/waiting_tips.dart';
import 'package:edunova_mobile/features/solution/presentation/widgets/waiting_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget child, {ThemeData? theme, bool reduceMotion = false}) async {
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: const Size(390, 1400), disableAnimations: reduceMotion),
      child: MaterialApp(theme: theme ?? AppTheme.dark(), home: Scaffold(body: child)),
    ),
  );
  await tester.pump();
}

Future<void> _wait(WidgetTester tester, Duration duration) async {
  for (var s = 0; s < duration.inSeconds; s++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

const _view = WaitingView(
  problem: r'$2x^2 - 5x - 3 = 0$ tenglamaning ildizlari yig‘indisini toping.',
  subject: 'matematika',
  leaveHint: 'Yechim tayyor bo‘lgach «Oxirgi yechimlar»da turadi.',
);

void main() {
  group('WaitingView', () {
    testWidgets('shows the problem that was sent, as readable text', (tester) async {
      await _pump(tester, _view);
      expect(find.text('SIZNING MASALANGIZ'), findsOneWidget);
      expect(find.textContaining('2x² − 5x − 3 = 0'), findsNothing, reason: 'LaTeX minus stays "-"');
      expect(find.textContaining('2x² - 5x - 3 = 0'), findsOneWidget);
      expect(find.textContaining(r'\'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('names the stages in words and moves through them with time', (tester) async {
      await _pump(tester, _view);
      expect(find.text('Masalani o‘qiyapmiz…'), findsOneWidget);
      expect(find.text('Masala o‘qilmoqda'), findsOneWidget);
      expect(find.text('💡 BILASIZMI?'), findsNothing, reason: 'the first stage has the board to itself');

      await _wait(tester, const Duration(seconds: 7));
      expect(find.text('Yechim yo‘lini tanlayapmiz…'), findsOneWidget);
      expect(find.text('Masala o‘qildi'), findsOneWidget);
      expect(find.text('💡 BILASIZMI?'), findsOneWidget);

      await _wait(tester, const Duration(seconds: 20));
      expect(find.text('Javobni tekshiryapmiz…'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('never closes the last stage by time', (tester) async {
      // The server reports no progress: only a real answer may tick it.
      await _pump(tester, _view);
      await _wait(tester, const Duration(seconds: 120));
      expect(find.text('Javob tekshirilmoqda'), findsOneWidget);
      expect(find.text('Javob tekshirildi'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('after a long wait says so and offers a way out', (tester) async {
      await _pump(tester, _view);
      expect(find.text('Bosh sahifaga qaytish'), findsNothing);
      await _wait(tester, const Duration(seconds: 46));
      expect(find.text('Odatdagidan biroz uzoqroq ketyapti'), findsOneWidget);
      expect(find.text('Bosh sahifaga qaytish'), findsOneWidget);
      expect(find.textContaining('Kutib o‘tirishingiz shart emas'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('draws in light mode too', (tester) async {
      await _pump(
        tester,
        const WaitingView(problem: 'Kuchni toping.', subject: 'fizika', leaveHint: 'x'),
        theme: AppTheme.light(),
      );
      await _wait(tester, const Duration(seconds: 8));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('the board', () {
    testWidgets('stands still when the phone asks for reduced motion', (tester) async {
      await _pump(tester, const WaitingBoard(physics: false), reduceMotion: true);
      // A running animation would never settle.
      await tester.pumpAndSettle();
      expect(find.byType(Math), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });
  });

  group('tips', () {
    test('match the subject', () {
      expect(tipsFor('fizika').first, contains('nyuton'));
      expect(tipsFor('Matematika').first, contains('Kvadrat'));
      expect(tipsFor('kimyo'), isNot(same(tipsFor('fizika'))));
      expect(tipsFor(null), isNotEmpty);
    });

    testWidgets('every tip draws its maths, none shows LaTeX source', (tester) async {
      // Written by hand, so a broken formula would be ours: check them all.
      for (final subject in ['matematika', 'fizika', null]) {
        final tips = tipsFor(subject);
        for (var i = 0; i < tips.length; i++) {
          await _pump(tester, TipCard(tips: tips, index: i));
          expect(find.textContaining(r'\', findRichText: true), findsNothing, reason: tips[i]);
          expect(tester.takeException(), isNull, reason: tips[i]);
        }
      }
    });
  });

  group('ArrivalSwitcher', () {
    Widget switcher({required bool waiting, bool celebrate = true}) => ArrivalSwitcher(
          isWaiting: waiting,
          celebrate: celebrate,
          steps: 4,
          waiting: const Text('kutish'),
          ready: const Text('yechim'),
        );

    testWidgets('a seen wait ends with a moment of "Yechim tayyor!"', (tester) async {
      await _pump(tester, switcher(waiting: true));
      expect(find.text('kutish'), findsOneWidget);
      await _pump(tester, switcher(waiting: false));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Yechim tayyor!'), findsOneWidget);
      expect(find.text('4 qadam · birma-bir ko‘rasiz'), findsOneWidget);
      expect(find.text('Javob tekshirildi'), findsOneWidget, reason: 'now the last stage may close');
      await tester.pump(ArrivalSwitcher.moment);
      await tester.pumpAndSettle();
      expect(find.text('yechim'), findsOneWidget);
    });

    testWidgets('a solution that was already there opens straight away', (tester) async {
      await _pump(tester, switcher(waiting: false));
      expect(find.text('yechim'), findsOneWidget);
      expect(find.text('Yechim tayyor!'), findsNothing);
    });

    testWidgets('a wait that ends in a failure is not celebrated', (tester) async {
      await _pump(tester, switcher(waiting: true));
      await _pump(tester, switcher(waiting: false, celebrate: false));
      await tester.pumpAndSettle();
      expect(find.text('Yechim tayyor!'), findsNothing);
      expect(find.text('yechim'), findsOneWidget);
    });
  });

  group('SolutionDelayed', () {
    testWidgets('keeps the problem in view and offers a free retry', (tester) async {
      var retried = 0;
      await _pump(
        tester,
        SolutionDelayed(problem: 'Kuchni toping.', note: 'Xizmat hozir band.', onRetry: () => retried++),
      );
      expect(find.text('Yechim kechikyapti'), findsOneWidget);
      expect(find.text('Kuchni toping.'), findsOneWidget);
      await tester.tap(find.text('Qayta urinish'));
      expect(retried, 1);
      expect(find.text('Bosh sahifaga qaytish'), findsOneWidget);
    });
  });
}
