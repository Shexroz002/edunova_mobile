import 'package:edunova_mobile/core/theme/app_theme.dart';
import 'package:edunova_mobile/features/auth/presentation/auth_controller.dart';
import 'package:edunova_mobile/features/results/presentation/leaderboard_sheet.dart';
import 'package:edunova_mobile/features/session/domain/session_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The rating sheet takes the height of its content.
///
/// It used to be a `DraggableScrollableSheet` pinned at 72 % of the screen, so
/// a session with one participant floated above a screenful of empty sheet.
void main() {
  const screen = Size(360, 720);

  List<LeaderboardEntry> entries(int count) => [
        for (var i = 0; i < count; i++)
          LeaderboardEntry(
            userId: i + 1,
            fullName: 'Ishtirokchi ${i + 1}',
            score: 10 - (i % 10),
            totalQuestions: 20,
            rank: i + 1,
          ),
      ];

  Future<double> sheetHeight(WidgetTester tester, int count) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(null),
          sessionLeaderboardProvider(1).overrideWith((ref) async => entries(count)),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showLeaderboardSheet(context, sessionId: 1, title: 'Test'),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final height = tester.getSize(find.byType(SingleChildScrollView).first).height;

    // Dismiss it, so a test can measure twice.
    await tester.tapAt(const Offset(180, 10));
    await tester.pumpAndSettle();
    return height;
  }

  testWidgets('one participant makes a short sheet', (tester) async {
    final height = await sheetHeight(tester, 1);

    expect(height, lessThan(screen.height / 2),
        reason: 'a solo participant should not fill half the screen');
  });

  testWidgets('a long list is capped by the screen and scrolls', (tester) async {
    final height = await sheetHeight(tester, 40);

    expect(height, lessThanOrEqualTo(screen.height));
    expect(find.byType(Scrollable), findsWidgets);
  });

  testWidgets('the sheet grows with the list', (tester) async {
    final short = await sheetHeight(tester, 1);
    final longer = await sheetHeight(tester, 5);

    expect(longer, greaterThan(short));
  });
}
