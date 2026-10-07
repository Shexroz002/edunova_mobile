import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/gradient_button.dart';
import 'problem_card.dart';

/// The wait gave up: not an error, a delay — and asking again is free.
class SolutionDelayed extends StatelessWidget {
  const SolutionDelayed({super.key, this.problem, required this.note, required this.onRetry});

  /// The problem, shown so the student sees it was not lost.
  final String? problem;

  /// Why, in plain words, and what asking again costs.
  final String note;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = problem?.trim() ?? '';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 84,
                height: 84,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  color: AppColors.tint(AppColors.warning, 0x24),
                  border: Border.all(color: AppColors.tint(AppColors.warning, 0x73), width: 1.5),
                ),
                child: const Text('⏳', style: TextStyle(fontSize: 38)),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Yechim kechikyapti',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                note,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.5, color: c.textSecondary),
              ),
            ),
            if (text.isNotEmpty) ...[
              const SizedBox(height: 16),
              ProblemCard(text: text, label: false),
            ],
            const SizedBox(height: 16),
            GradientButton(label: 'Qayta urinish', icon: Icons.refresh_rounded, height: 52, onPressed: onRetry),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => context.go(Routes.home),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: BorderSide(color: c.border, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                foregroundColor: c.textPrimary,
              ),
              icon: const Icon(Icons.home_outlined, size: 19),
              label: const Text('Bosh sahifaga qaytish', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
