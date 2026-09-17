import 'dart:io';

import 'package:edunova_mobile/core/theme/app_colors.dart';
import 'package:edunova_mobile/core/theme/app_theme.dart';
import 'package:edunova_mobile/features/quiz_create/presentation/widgets/method_card.dart';
import 'package:edunova_mobile/features/quiz_create/presentation/widgets/pdf_picker.dart';
import 'package:edunova_mobile/features/quiz_create/presentation/widgets/step_rail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget child, {ThemeData? theme}) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.dark(),
      home: Scaffold(
        body: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(16), child: child)),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('StepRail', () {
    testWidgets('names all three steps whichever one is running', (tester) async {
      for (final step in CreateStep.values) {
        await _pump(tester, StepRail(current: step));
        for (final name in CreateStep.values) {
          expect(find.text(name.label), findsOneWidget, reason: '${step.label} da ${name.label}');
        }
      }
    });

    testWidgets('ticks the steps behind the current one and numbers the rest',
        (tester) async {
      await _pump(tester, const StepRail(current: CreateStep.job));

      // Usul and Ma'lumot are behind, so both carry a tick and neither shows
      // its number any more.
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
      expect(find.text('1'), findsNothing);
      expect(find.text('2'), findsNothing);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('the first step has nothing ticked', (tester) async {
      await _pump(tester, const StepRail(current: CreateStep.method));

      expect(find.byIcon(Icons.check_rounded), findsNothing);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });
  });

  group('MethodCard', () {
    testWidgets('leads with who the method is for, then the facts', (tester) async {
      await _pump(
        tester,
        MethodCard(
          icon: Icons.upload_file_rounded,
          color: AppColors.blue,
          title: 'PDF fayldan',
          who: 'Darslik yoki konspekt bo‘lsa',
          facts: const ['Matnli PDF, 5 MB gacha', 'Odatda 2–3 daqiqa'],
          onTap: () {},
        ),
      );

      expect(find.text('PDF fayldan'), findsOneWidget);
      expect(find.text('Darslik yoki konspekt bo‘lsa'), findsOneWidget);
      expect(find.text('Matnli PDF, 5 MB gacha'), findsOneWidget);
      expect(find.text('Odatda 2–3 daqiqa'), findsOneWidget);
      // The old card ended in a bare adjective, which decided nothing.
      expect(find.text('Avtomatik'), findsNothing);
      expect(find.text('Intellektual'), findsNothing);
    });

    testWidgets('is tappable', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        MethodCard(
          icon: Icons.auto_awesome_rounded,
          color: AppColors.violet,
          title: 'AI bilan yaratish',
          who: 'Faqat mavzu bo‘lsa',
          facts: const ['Fan va mavzuni yozasiz'],
          onTap: () => taps++,
        ),
      );

      await tester.tap(find.text('AI bilan yaratish'));
      expect(taps, 1);
    });
  });

  group('PdfPicker', () {
    Widget picker({File? file, int? bytes}) => PdfPicker(
          file: file,
          bytes: bytes,
          onPick: () {},
          onClear: () {},
        );

    testWidgets('states both requirements before anything is picked', (tester) async {
      // They used to appear as "Maksimal: 5 MB" only, and the text-layer rule
      // not at all — a student learnt it from a failed job.
      await _pump(tester, picker());

      expect(find.text('PDF faylni tanlang'), findsOneWidget);
      expect(find.text('Matn tanlanadigan PDF bo‘lsin'), findsOneWidget);
      expect(find.text('Hajmi 5 MB dan oshmasin'), findsOneWidget);
    });

    testWidgets('shows the picked file with its size', (tester) async {
      await _pump(
        tester,
        picker(file: File('/tmp/edunova/fizika_8_sinf.pdf'), bytes: 1489920),
      );

      expect(find.text('fizika_8_sinf.pdf'), findsOneWidget);
      expect(find.text('1.42 MB'), findsOneWidget);
      expect(find.textContaining('5 MB dan katta'), findsNothing);
    });

    testWidgets('calls out a file over the limit', (tester) async {
      await _pump(
        tester,
        picker(file: File('/tmp/edunova/algebra.pdf'), bytes: 8 * 1024 * 1024),
      );

      expect(find.text('8.00 MB — 5 MB dan katta'), findsOneWidget);
    });

    testWidgets('keeps the remove button at the 44 dp floor', (tester) async {
      await _pump(
        tester,
        picker(file: File('/tmp/edunova/fizika.pdf'), bytes: 1024),
      );

      final size = tester.getSize(find.byIcon(Icons.delete_outline_rounded).hitTestable());
      expect(size.width, greaterThanOrEqualTo(18));

      final target = tester.getSize(
        find.ancestor(
          of: find.byIcon(Icons.delete_outline_rounded),
          matching: find.byType(InkWell),
        ).first,
      );
      expect(target.width, greaterThanOrEqualTo(44));
      expect(target.height, greaterThanOrEqualTo(44));
    });

    testWidgets('renders in light mode too', (tester) async {
      await _pump(tester, picker(), theme: AppTheme.light());
      expect(tester.takeException(), isNull);

      await _pump(
        tester,
        picker(file: File('/tmp/edunova/fizika.pdf'), bytes: 1024),
        theme: AppTheme.light(),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
