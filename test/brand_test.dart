import 'package:edunova_mobile/core/theme/app_theme.dart';
import 'package:edunova_mobile/core/widgets/brand.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String _asset(WidgetTester tester) {
  final image = tester.widget<Image>(find.byType(Image)).image as AssetImage;
  return image.assetName;
}

Future<void> _pump(WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: const Scaffold(body: Center(child: BrandTitle(size: 28))),
    ),
  );
  await tester.pump();
}

void main() {
  group('BrandTitle', () {
    testWidgets('takes the on-dark lockup in dark mode', (tester) async {
      // The supplied artwork writes "Edu" in navy, which is unreadable on
      // bgCard; the dark variant remaps that navy to white.
      await _pump(tester, AppTheme.dark());
      expect(_asset(tester), 'assets/branding/lockup_dark.png');
    });

    testWidgets('and the supplied one in light mode', (tester) async {
      await _pump(tester, AppTheme.light());
      expect(_asset(tester), 'assets/branding/lockup_light.png');
    });

    testWidgets('sizes by height and lets the width follow the artwork',
        (tester) async {
      await _pump(tester, AppTheme.dark());
      expect(tester.widget<Image>(find.byType(Image)).height, 28);
      expect(tester.widget<Image>(find.byType(Image)).width, isNull);
    });
  });
}
