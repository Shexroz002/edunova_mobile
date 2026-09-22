import 'package:edunova_mobile/core/theme/app_theme.dart';
import 'package:edunova_mobile/features/auth/domain/auth_user.dart';
import 'package:edunova_mobile/features/auth/presentation/auth_controller.dart';
import 'package:edunova_mobile/features/profile/presentation/profile_screen.dart';
import 'package:edunova_mobile/features/profile/presentation/widgets/detail_row.dart';
import 'package:edunova_mobile/features/profile/presentation/widgets/identity_card.dart';
import 'package:edunova_mobile/core/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

AuthUser _user({String? school, String? grade, String? email}) => AuthUser(
      id: 1,
      username: 'shehroz1',
      firstName: 'Shehroz',
      lastName: 'Toshpo‘latov',
      email: email,
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
  group('Tanlangan fanlar', () {
    testWidgets('chips sit side by side rather than one per row',
        (tester) async {
      // A Container with a non-null `alignment` fills the constraints a Wrap
      // hands it, which gave every subject a row of its own.
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            currentUserProvider.overrideWithValue(
              const AuthUser(
                id: 1,
                username: 'shehroz1',
                firstName: 'Shehroz',
                lastName: 'Toshpo‘latov',
                subjects: [
                  Subject(id: 1, name: 'Fizika'),
                  Subject(id: 2, name: 'Matematika'),
                ],
              ),
            ),
          ],
          child: MaterialApp(theme: AppTheme.light(), home: const ProfileScreen()),
        ),
      );
      await tester.pump();

      final fizika = tester.getSize(find.text('Fizika'));
      expect(fizika.width, lessThan(120), reason: 'a chip must hug its label');
      // Both chips on one line.
      expect(
        tester.getTopLeft(find.text('Fizika')).dy,
        tester.getTopLeft(find.text('Matematika')).dy,
      );
    });
  });

  group('IdentityCard', () {
    testWidgets('carries the name and handle, and nothing to report',
        (tester) async {
      // The gradient header used to hold sessions, correct answers and the
      // average — the fourth copy of them in the app.
      await _pump(tester, IdentityCard(user: _user(grade: '11-sinf'), onEdit: () {}));

      expect(find.text('Shehroz Toshpo‘latov'), findsOneWidget);
      expect(find.text('@shehroz1'), findsOneWidget);
      expect(find.text('Sessiyalar'), findsNothing);
      expect(find.text("To'g'ri javob"), findsNothing);
      // "11-sinf • O'quvchi" said the class a second time and named a role
      // every user of this app shares.
      expect(find.textContaining('O‘quvchi'), findsNothing);
      expect(find.textContaining('11-sinf'), findsNothing);
    });

    testWidgets('offers the photo change a reader expects from the avatar',
        (tester) async {
      var edited = false;
      await _pump(tester, IdentityCard(user: _user(), onEdit: () => edited = true));

      expect(find.byIcon(Icons.photo_camera_rounded), findsOneWidget);
      await tester.tap(find.text('Shehroz Toshpo‘latov'));
      expect(edited, isTrue);
    });

    testWidgets('renders in light mode too', (tester) async {
      await _pump(tester, IdentityCard(user: _user(), onEdit: () {}),
          theme: AppTheme.light());
      expect(tester.takeException(), isNull);
    });
  });

  group('DetailRow', () {
    testWidgets('asks to be filled instead of printing a dash', (tester) async {
      await _pump(
        tester,
        DetailRow(icon: Icons.apartment_rounded, label: 'Maktab', onTap: () {}),
      );

      expect(find.text('Kiritilmagan'), findsOneWidget);
      expect(find.text('—'), findsNothing);
    });

    testWidgets('an empty row leads to editing, like a filled one',
        (tester) async {
      // Editing used to be reachable only from a tile below the subjects card.
      var edited = 0;
      await _pump(
        tester,
        Column(
          children: [
            DetailRow(
              icon: Icons.mail_outline_rounded,
              label: 'Email',
              value: 'shehroz@mail.uz',
              onTap: () => edited++,
            ),
            DetailRow(
              icon: Icons.apartment_rounded,
              label: 'Maktab',
              onTap: () => edited++,
              isLast: true,
            ),
          ],
        ),
      );

      await tester.tap(find.text('shehroz@mail.uz'));
      await tester.tap(find.text('Kiritilmagan'));
      expect(edited, 2);
    });

    testWidgets('treats blank strings as unfilled', (tester) async {
      await _pump(
        tester,
        DetailRow(
          icon: Icons.phone_outlined,
          label: 'Telefon',
          value: '   ',
          onTap: () {},
        ),
      );
      expect(find.text('Kiritilmagan'), findsOneWidget);
    });

    testWidgets('clears the 44 dp target', (tester) async {
      await _pump(
        tester,
        DetailRow(
          icon: Icons.mail_outline_rounded,
          label: 'Email',
          value: 'shehroz@mail.uz',
          onTap: () {},
        ),
      );

      final row = find.ancestor(of: find.text('Email'), matching: find.byType(InkWell)).first;
      expect(tester.getSize(row).height, greaterThanOrEqualTo(44));
    });

    testWidgets('a long value ellipses rather than pushing the chevron out',
        (tester) async {
      await _pump(
        tester,
        DetailRow(
          icon: Icons.apartment_rounded,
          label: 'Maktab',
          value: '42-son umumiy o‘rta ta’lim maktabi, Toshkent shahri',
          onTap: () {},
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });
  });
}
