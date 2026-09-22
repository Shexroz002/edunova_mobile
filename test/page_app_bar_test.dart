import 'package:edunova_mobile/core/theme/app_theme.dart';
import 'package:edunova_mobile/core/widgets/page_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Router with one stub page per route the header can reach.
GoRouter _router({bool showFriends = true}) => GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, __) => Scaffold(
            appBar: PageAppBar(title: const Text('Bosh sahifa'), showFriends: showFriends),
          ),
        ),
        GoRoute(
          path: '/friends',
          builder: (_, __) => const Scaffold(
            appBar: PageAppBar(title: Text("Do'stlar"), showFriends: false),
            body: Center(child: Text("Do'stlar sahifasi")),
          ),
        ),
      ],
    );

Future<void> _pump(WidgetTester tester, {bool showFriends = true, ThemeData? theme}) async {
  tester.view.physicalSize = const Size(390, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp.router(
      theme: theme ?? AppTheme.dark(),
      routerConfig: _router(showFriends: showFriends),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('PageAppBar', () {
    testWidgets('offers Do‘stlar where the theme toggle used to sit', (tester) async {
      // Do'stlar left the bottom bar, so the header carries it. The toggle is
      // not lost — Profil has had the same switch all along.
      await _pump(tester);

      expect(find.byIcon(Icons.people_alt_rounded), findsOneWidget);
      expect(find.byIcon(Icons.light_mode_rounded), findsNothing);
      expect(find.byIcon(Icons.dark_mode_rounded), findsNothing);
    });

    testWidgets('tapping it opens the Do‘stlar page', (tester) async {
      await _pump(tester);

      await tester.tap(find.byIcon(Icons.people_alt_rounded));
      await tester.pumpAndSettle();

      expect(find.text("Do'stlar sahifasi"), findsOneWidget);
    });

    testWidgets('pushes rather than replaces, so the page can be left again',
        (tester) async {
      await _pump(tester);
      await tester.tap(find.byIcon(Icons.people_alt_rounded));
      await tester.pumpAndSettle();

      // A `go` would leave nothing to pop and strand the student there.
      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('keeps the 44 dp target', (tester) async {
      await _pump(tester);

      final button = find
          .ancestor(of: find.byIcon(Icons.people_alt_rounded), matching: find.byType(InkWell))
          .first;
      final size = tester.getSize(button);
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    });

    testWidgets('hidden where the caller turns it off', (tester) async {
      await _pump(tester, showFriends: false);
      expect(find.byIcon(Icons.people_alt_rounded), findsNothing);
    });

    testWidgets('renders in light mode too', (tester) async {
      await _pump(tester, theme: AppTheme.light());
      expect(tester.takeException(), isNull);
    });
  });
}
