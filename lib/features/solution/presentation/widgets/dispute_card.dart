import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/solution_models.dart';

/// Two independent solutions agree on one option; the answer key says another.
///
/// Said plainly, because in the data seen so far the key was the wrong side
/// more often than not — and a student who picked the agreed option was
/// probably right all along.
class DisputeCard extends StatelessWidget {
  const DisputeCard({super.key, required this.result});

  final ExplanationResult result;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = result.studentMayBeRight ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.tint(tone, 0x17),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.tint(tone, 0x66), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('⚖️', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  result.studentMayBeRight ? 'Siz haq bo‘lishingiz mumkin' : 'Javob kaliti tekshiruvda',
                  style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, letterSpacing: -0.2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            result.message ?? '',
            style: TextStyle(fontSize: 14, height: 1.55, color: c.textPrimary),
          ),
          if (result.modelOption != null && result.correctOption != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _Chip(label: 'Yechim: ${result.modelOption}', tone: AppColors.success),
                const SizedBox(width: 8),
                _Chip(label: 'Kalit: ${result.correctOption}', tone: AppColors.warning),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.tone});

  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.tint(tone, 0x29),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: context.readable(tone)),
      ),
    );
  }
}
