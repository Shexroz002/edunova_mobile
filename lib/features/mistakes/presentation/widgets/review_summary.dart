import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/gradient_button.dart';

/// The end of a review.
///
/// Not a score: the headline is how many questions left the bank, because that
/// is what the student actually achieved. A percentage here would invite
/// comparison with test results, which this deliberately is not.
class ReviewSummary extends StatelessWidget {
  const ReviewSummary({
    super.key,
    required this.correct,
    required this.wrong,
    required this.cleared,
    required this.onClose,
  });

  final int correct;
  final int wrong;

  /// Questions that reached two correct answers in a row and left the bank.
  final int cleared;

  final VoidCallback onClose;

  int get _returning => correct + wrong - cleared;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final success = context.readable(AppColors.success);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.tint(AppColors.success, 0x24),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(Icons.check_rounded, size: 34, color: success),
          ),
          const SizedBox(height: 14),
          Text(
            '$cleared',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.4,
              height: 1,
              color: success,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'ta savolni o‘zlashtirdingiz',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            cleared > 0
                ? 'Ketma-ket ikki marta to‘g‘ri javob berdingiz.'
                : 'Savollar o‘z muddatida yana qaytadi.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, height: 1.5, color: c.textMuted),
          ),
          const SizedBox(height: 20),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Tile(value: '$correct', label: 'To‘g‘ri', color: AppColors.success),
                const SizedBox(width: 8),
                _Tile(value: '$wrong', label: 'Xato', color: AppColors.error),
                const SizedBox(width: 8),
                _Tile(value: '$_returning', label: 'Qaytadi', color: AppColors.warning),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Bu mashq Natijalarga yozilmaydi va\no‘rtacha ballingizga ta’sir qilmaydi.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, height: 1.5, color: c.textMuted),
          ),
          const Spacer(),
          GradientButton(label: 'Yopish', height: 50, onPressed: onClose),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.value, required this.label, required this.color});

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
        decoration: BoxDecoration(
          color: c.bgCard,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: c.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: context.readable(color),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: c.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
