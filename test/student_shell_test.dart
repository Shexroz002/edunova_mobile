import 'package:edunova_mobile/core/theme/app_theme.dart';
import 'package:edunova_mobile/features/shell/student_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Layout tests for the adaptive shell.
///
/// The rail regression comes from a real device: rotating a 360 dp phone to
/// landscape makes it 820×360 dp, which is wide enough (≥ 600) to switch to the
/// rail but too short for the brand plus the labelled destinations. Before the
/// fix that overflowed by 73 px on a Redmi 2409BRN2CY.
void main() {
  /// Minimal router that renders [StudentShell] over one stub branch per tab.
  GoRouter buildRouter() => GoRouter(
        initialLocation: '/home',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (_, __, shell) => StudentShell(navigationShell: shell),
            branches: [
              for (final path in ['/home', '/statistics', '/profile'])
                StatefulShellBranch(
                  routes: [
                    GoRoute(path: path, builder: (_, __) => Center(child: Text('page $path')))
                  ],
                ),
            ],
          ),
        ],
      );

  Future<void> pumpAt(WidgetTester tester, Size size, {double textScale = 1.0}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.dark(),
        routerConfig: buildRouter(),
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: child!,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the phone bar carries three tabs, not six', (tester) async {
    await pumpAt(tester, const Size(360, 820));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    for (final label in ['Asosiy', 'Statistika', 'Profil']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    // Moved out of the bar: Do'stlar to the header button, the other two to
    // full-screen pages.
    for (final gone in ['Guruhlar', "Do'stlar", 'Suhbatlar', 'Bosh sahifa']) {
      expect(find.text(gone), findsNothing, reason: gone);
    }
  });

  testWidgets('three labels have room to scale, where six did not', (tester) async {
    // The bar used to be clamped to 1.1 because six labels collided; the rest
    // of the app scales freely and now so does the bar.
    await pumpAt(tester, const Size(360, 820), textScale: 1.5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('landscape phone switches to the rail without overflowing', (tester) async {
    await pumpAt(tester, const Size(820, 360));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull,
        reason: 'the rail must not overflow on a short viewport');
  });

  testWidgets('a very short viewport keeps every destination reachable by scrolling',
      (tester) async {
    await pumpAt(tester, const Size(820, 260));

    expect(tester.takeException(), isNull);

    // The rail is wrapped in a scroll view, so the Scrollable is its ancestor.
    final scrollable = find.ancestor(
      of: find.byType(NavigationRail),
      matching: find.byType(Scrollable),
    );
    expect(scrollable, findsWidgets, reason: 'the rail must be scrollable when it does not fit');

    await tester.scrollUntilVisible(find.text('Profil').first, 80, scrollable: scrollable.first);
    expect(find.text('Profil'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet shows the rail, large screens extend it', (tester) async {
    await pumpAt(tester, const Size(800, 1000));
    final compact = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(compact.extended, isFalse);
    expect(compact.labelType, NavigationRailLabelType.all);

    // The rail has room for the full wording the phone bar shortens.
    expect(find.text('Bosh sahifa'), findsOneWidget);
    expect(find.text('Asosiy'), findsNothing);

    await pumpAt(tester, const Size(1200, 1000));
    final extended = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(extended.extended, isTrue);
    expect(extended.labelType, NavigationRailLabelType.none);
  });
}
