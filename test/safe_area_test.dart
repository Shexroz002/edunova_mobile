import 'package:edunova_mobile/core/theme/app_theme.dart';
import 'package:edunova_mobile/features/session/domain/session_models.dart';
import 'package:edunova_mobile/features/session/presentation/result_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression: the result page's last action must clear the system navigation
/// bar.
///
/// Reported from a real phone — "Yangi test yechish" was drawn underneath the
/// gesture bar, so it was visible but swallowed every tap. Full-screen routes
/// have no bottom bar of their own to reserve that space, so they need the
/// bottom safe-area inset themselves.
void main() {
  const navigationBar = 48.0;

  const result = FinishResult(
    sessionId: 1,
    totalQuestions: 5,
    answeredQuestions: 5,
    correctAnswers: 5,
    wrongAnswers: 0,
    topics: [],
  );

  Future<void> pump(WidgetTester tester, {required double bottomInset}) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewPadding = FakeViewPadding(bottom: bottomInset);
    tester.view.padding = FakeViewPadding(bottom: bottomInset);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const ResultScreen(sessionId: 1, initial: result),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the last action clears the system navigation bar', (tester) async {
    await pump(tester, bottomInset: navigationBar);

    final button = find.text('Yangi test yechish');
    expect(button, findsOneWidget);

    // Scroll it into view the way a student would.
    await tester.dragUntilVisible(button, find.byType(ListView), const Offset(0, -120));
    await tester.pumpAndSettle();

    final bottom = tester.getRect(button).bottom;
    final usable = tester.view.physicalSize.height / tester.view.devicePixelRatio - navigationBar;
    expect(
      bottom,
      lessThanOrEqualTo(usable),
      reason: 'the button is drawn under the navigation bar and cannot be tapped',
    );
  });

  testWidgets('the whole page is still reachable without an inset', (tester) async {
    await pump(tester, bottomInset: 0);

    final button = find.text('Yangi test yechish');
    await tester.dragUntilVisible(button, find.byType(ListView), const Offset(0, -120));
    await tester.pumpAndSettle();

    expect(tester.getRect(button).bottom, lessThanOrEqualTo(720));
  });
}
