import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'math_text.dart';

/// Visual state of an answer option.
enum OptionState {
  /// Not selected (while playing) or neutral (review).
  idle,

  /// Selected by the student while playing.
  selected,

  /// Correct answer (review).
  correct,

  /// Student's wrong choice (review).
  wrong,
}

/// One answer option: letter circle + text (may contain LaTeX) + state icon.
class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.label,
    required this.text,
    this.state = OptionState.idle,
    this.onTap,
  });

  final String label;
  final String text;
  final OptionState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final accent = switch (state) {
      OptionState.idle => c.textSecondary,
      OptionState.selected => AppColors.brand,
      OptionState.correct => AppColors.success,
      OptionState.wrong => AppColors.error,
    };
    final active = state != OptionState.idle;

    return Material(
      color: active ? AppColors.tint(accent, 0x1A) : c.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: active ? accent : c.border, width: active ? 1.8 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active ? accent : c.bgInner,
                    border: Border.all(color: active ? accent : c.border),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: active ? Colors.white : c.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MathText(
                    text,
                    style: TextStyle(fontSize: 15, color: c.textPrimary, height: 1.35),
                  ),
                ),
                if (state == OptionState.correct)
                  const Icon(Icons.check_circle_rounded, color: AppColors.success)
                else if (state == OptionState.wrong)
                  const Icon(Icons.cancel_rounded, color: AppColors.error)
                else if (state == OptionState.selected)
                  const Icon(Icons.radio_button_checked_rounded, color: AppColors.brand),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
