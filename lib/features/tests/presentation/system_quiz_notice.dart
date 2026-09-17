import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Explains why a system quiz has no detail page.
///
/// Quizzes from the shared library belong to nobody: the backend returns
/// `is_update: false` for them and refuses every edit. Opening the detail would
/// also lay the questions out one by one, which is the answer sheet for a test
/// the student has not taken yet — so the card sends them here instead.
///
/// The dialog is not a dead end: it offers the one thing they came to do.
Future<void> showSystemQuizNotice(
  BuildContext context, {
  required VoidCallback onStart,
  bool canStart = true,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final c = dialogContext.colors;

      return AlertDialog(
        backgroundColor: c.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.tint(AppColors.emerald),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.tint(AppColors.emerald, 0x40)),
              ),
              child: const Icon(Icons.verified_outlined, color: AppColors.emerald, size: 24),
            ),
            const SizedBox(height: 14),
            Text(
              'Tizim testi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: c.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          canStart
              ? 'Bu test EduNova kutubxonasidan. Savollarini oldindan ochib '
                  "bo'lmaydi — ularni test davomida ko'rasiz."
              : 'Bu test EduNova kutubxonasidan. Unda hozircha savollar yo\'q.',
          style: TextStyle(fontSize: 14, height: 1.5, color: c.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: TextButton.styleFrom(
              foregroundColor: c.textSecondary,
              minimumSize: const Size(0, 44),
            ),
            child: const Text('Yopish'),
          ),
          if (canStart)
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onStart();
              },
              icon: const Icon(Icons.play_arrow_rounded, size: 19),
              label: const Text('Boshlash'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
        ],
      );
    },
  );
}
