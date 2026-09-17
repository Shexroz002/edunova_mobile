import 'package:edunova_mobile/core/theme/app_theme.dart';
import 'package:edunova_mobile/features/auth/data/auth_repository.dart';
import 'package:edunova_mobile/features/auth/domain/auth_user.dart';
import 'package:edunova_mobile/features/auth/presentation/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Layout tests for registration.
///
/// Both steps used to run past the right edge of a phone: the step indicator by
/// 68 px on every screen, and a subject chip by 19 px as soon as the list held
/// "Ona tili va adabiyoti". Nothing failed loudly — the strip only shows in
/// debug — so these pin the widths down.
const _subjects = [
  Subject(id: 1, name: 'Matematika', icon: '📐'),
  Subject(id: 2, name: 'Fizika', icon: '⚛️'),
  Subject(id: 3, name: 'Kimyo', icon: '🧪'),
  Subject(id: 4, name: 'Biologiya', icon: '🧬'),
  // The longest name the live database holds.
  Subject(id: 5, name: 'Ona tili va adabiyoti', icon: '📚'),
  Subject(id: 6, name: 'Ingliz tili', icon: '🇬🇧'),
  Subject(id: 7, name: 'Tarix', icon: '🏛️'),
  Subject(id: 8, name: 'Geografiya', icon: '🌍'),
];

void main() {
  Future<void> pumpAt(
    WidgetTester tester,
    Size size, {
    bool dark = true,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [subjectsProvider.overrideWith((ref) async => _subjects)],
        child: MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: const RegisterScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Fills step 1 with valid values and moves on to the subjects.
  Future<void> goToSubjects(WidgetTester tester) async {
    await tester.enterText(find.widgetWithText(TextField, 'Ismingiz'), 'Ali');
    await tester.enterText(find.widgetWithText(TextField, 'Familiyangiz'), 'Valiyev');
    await tester.enterText(find.widgetWithText(TextField, 'masalan: ali_valiyev'), 'alivaliyev');
    await tester.enterText(find.widgetWithText(TextField, 'Kamida 8 belgi'), 'parol1234');
    await tester.pumpAndSettle();
    // At a large text scale the card outgrows the viewport, so scroll first.
    await tester.ensureVisible(find.text('Keyingi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keyingi'));
    await tester.pumpAndSettle();
  }

  for (final (label, size) in [
    ('narrow phone', const Size(320, 720)),
    ('common phone', const Size(360, 800)),
    ('large phone', const Size(430, 932)),
  ]) {
    testWidgets('step 1 fits a $label', (tester) async {
      await pumpAt(tester, size);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the subjects step fits a $label', (tester) async {
      await pumpAt(tester, size);
      await goToSubjects(tester);
      expect(tester.takeException(), isNull);
    });
  }

  // A pupil who has enlarged the system font broke this screen: "Orqaga" wrapped
  // onto two lines inside its half of the button row, and the step labels no
  // longer fitted beside each other.
  for (final scale in [1.3, 1.6]) {
    testWidgets('step 1 survives a ${scale}x system font', (tester) async {
      await pumpAt(tester, const Size(360, 800), textScale: scale);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the subjects step survives a ${scale}x system font', (tester) async {
      await pumpAt(tester, const Size(360, 800), textScale: scale);
      await goToSubjects(tester);
      expect(tester.takeException(), isNull);

      // One line, never "Orqag / a".
      await tester.ensureVisible(find.text('Orqaga'));
      final back = tester.widget<Text>(find.text('Orqaga'));
      expect(back.maxLines, 1);
    });
  }

  testWidgets('only the current step is named', (tester) async {
    await pumpAt(tester, const Size(360, 800));
    expect(find.text("Ma'lumotlar"), findsOneWidget);
    expect(find.text('Fanlar'), findsNothing);

    await goToSubjects(tester);
    expect(find.text('Fanlar'), findsOneWidget);
    expect(find.text("Ma'lumotlar"), findsNothing);
  });

  testWidgets('step 1 fits in light mode too', (tester) async {
    await pumpAt(tester, const Size(360, 800), dark: false);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the counter counts towards the minimum', (tester) async {
    await pumpAt(tester, const Size(390, 844));
    await goToSubjects(tester);

    expect(find.text('0 / 2 ta tanlandi'), findsOneWidget);
    await tester.tap(find.text('Matematika'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 2 ta tanlandi'), findsOneWidget);
  });

  testWidgets('submitting without enough subjects explains why', (tester) async {
    await pumpAt(tester, const Size(390, 844));
    await goToSubjects(tester);

    // The header carries the same words, so target the button.
    await tester.tap(find.text("Ro'yxatdan o'tish").last);
    await tester.pumpAndSettle();
    expect(find.text('Kamida 2 ta fan tanlang'), findsOneWidget);
  });

  testWidgets('a fixed field stops being red while typing', (tester) async {
    await pumpAt(tester, const Size(390, 844));
    await tester.tap(find.text('Keyingi'));
    await tester.pumpAndSettle();
    expect(find.text("Ism kamida 2 ta harf bo'lsin"), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Ismingiz'), 'Ali');
    await tester.pumpAndSettle();

    // The name clears on its own; the untouched fields stay flagged.
    expect(find.text("Ism kamida 2 ta harf bo'lsin"), findsNothing);
    expect(find.text('Foydalanuvchi nomi kiritilmadi'), findsOneWidget);
  });

  testWidgets('the username is shaped as it is typed', (tester) async {
    await pumpAt(tester, const Size(390, 844));
    final field = find.widgetWithText(TextField, 'masalan: ali_valiyev');

    await tester.enterText(field, 'Ali Valiyev');
    await tester.pumpAndSettle();

    // The server lowercases and rejects spaces, so the field does it first.
    expect(tester.widget<TextField>(field).controller!.text, 'alivaliyev');
  });

  testWidgets('a failed submit puts the caret on the first problem', (tester) async {
    await pumpAt(tester, const Size(390, 844));
    await tester.enterText(find.widgetWithText(TextField, 'Ismingiz'), 'Ali');
    await tester.enterText(find.widgetWithText(TextField, 'Familiyangiz'), 'Valiyev');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Keyingi'));
    await tester.pumpAndSettle();

    // Names are fine, so the username is the first thing left to fix.
    final username = tester.widget<TextField>(find.widgetWithText(TextField, 'masalan: ali_valiyev'));
    expect(username.focusNode?.hasFocus, isTrue);
  });

  testWidgets('the password rule is guidance before it is an error', (tester) async {
    await pumpAt(tester, const Size(390, 844));
    expect(find.textContaining("Kamida 8 ta belgi"), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Kamida 8 belgi'), 'parol1234');
    await tester.pumpAndSettle();
    expect(find.text('Parol yetarli uzunlikda'), findsOneWidget);
  });

  testWidgets('step 1 validation keeps the user on step 1', (tester) async {
    await pumpAt(tester, const Size(390, 844));
    await tester.tap(find.text('Keyingi'));
    await tester.pumpAndSettle();

    expect(find.text("Ism kamida 2 ta harf bo'lsin"), findsOneWidget);
    expect(find.text('Foydalanuvchi nomi kiritilmadi'), findsOneWidget);
    expect(find.text("Kamida 8 ta belgi bo'lsin"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
