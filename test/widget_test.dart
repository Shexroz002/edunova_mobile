import 'package:edunova_mobile/core/theme/app_theme.dart';
import 'package:edunova_mobile/core/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('PrimaryButton shows label and spinner while loading', (tester) async {
    var taps = 0;

    Widget wrap(bool loading) => MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: PrimaryButton(label: 'Kirish', loading: loading, onPressed: () => taps++),
          ),
        );

    await tester.pumpWidget(wrap(false));
    expect(find.text('Kirish'), findsOneWidget);
    await tester.tap(find.byType(PrimaryButton));
    expect(taps, 1);

    await tester.pumpWidget(wrap(true));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Kirish'), findsNothing);
  });
}
