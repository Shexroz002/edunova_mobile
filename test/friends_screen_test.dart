import 'package:edunova_mobile/core/theme/app_theme.dart';
import 'package:edunova_mobile/features/friends/domain/friend_models.dart';
import 'package:edunova_mobile/features/friends/presentation/widgets/friend_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

UserBrief _friend({
  int id = 5,
  String first = 'Shehroz',
  String last = 'Toshpo‘latov',
  String username = 'shehroz1',
  String? role,
}) =>
    UserBrief(
      id: id,
      firstName: first,
      lastName: last,
      username: username,
      role: role,
    );

Future<void> _pump(WidgetTester tester, UserBrief friend, {ThemeData? theme}) async {
  tester.view.physicalSize = const Size(360, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: theme ?? AppTheme.dark(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: FriendTile(friend: friend),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('friend row', () {
    testWidgets('the whole row is the target, not just the icon',
        (tester) async {
      // The row used to do nothing; the only working target was the chat icon
      // at its right edge.
      await _pump(tester, _friend());

      final row = find
          .ancestor(of: find.text('Shehroz Toshpo‘latov'), matching: find.byType(InkWell))
          .last;
      final size = tester.getSize(row);
      expect(size.height, greaterThanOrEqualTo(44));
      expect(size.width, greaterThan(250), reason: 'the row itself must be tappable');
    });

    testWidgets('keeps the chat button as its own 44 dp target', (tester) async {
      await _pump(tester, _friend());

      final button = find
          .ancestor(
            of: find.byIcon(Icons.chat_bubble_outline_rounded),
            matching: find.byType(InkWell),
          )
          .first;
      final size = tester.getSize(button);
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    });

    testWidgets('a teacher badge sits under the name, not beside it',
        (tester) async {
      // Beside the name it clipped it: the list read "Shehroz Toshp…".
      await _pump(tester, _friend(role: 'teacher'));

      expect(find.text("O'qituvchi"), findsOneWidget);
      expect(find.text('Shehroz Toshpo‘latov'), findsOneWidget);

      final name = tester.getTopLeft(find.text('Shehroz Toshpo‘latov')).dy;
      final badge = tester.getTopLeft(find.text("O'qituvchi")).dy;
      expect(badge, greaterThan(name), reason: 'the badge belongs on the handle line');
    });

    testWidgets('a long name is not clipped by the badge', (tester) async {
      await _pump(tester, _friend(first: 'Abdurahmonjon', last: 'Toshpo‘latov', role: 'teacher'));

      final name = tester.widget<Text>(find.text('Abdurahmonjon Toshpo‘latov'));
      expect(name.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    });

    testWidgets('carries no chevron beside the chat button', (tester) async {
      // Two arrows for one destination: the chat button already says where the
      // row goes.
      await _pump(tester, _friend());
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    });

    testWidgets('shows no badge for a student', (tester) async {
      await _pump(tester, _friend());
      expect(find.text("O'qituvchi"), findsNothing);
    });

    testWidgets('renders in light mode too', (tester) async {
      await _pump(tester, _friend(role: 'teacher'), theme: AppTheme.light());
      expect(tester.takeException(), isNull);
    });
  });
}
