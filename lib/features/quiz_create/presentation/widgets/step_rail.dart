import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// The three steps of quiz creation, in order.
enum CreateStep {
  method('Usul'),
  form('Ma‘lumot'),
  job('Tayyorlash');

  const CreateStep(this.label);

  /// Short name shown on the rail.
  final String label;
}

/// Shows which of the three creation steps is running.
///
/// The flow has always had three steps, but nothing said so — only a small grey
/// line whose text changed. The rail replaces it, so a student can see what is
/// behind them and what is still to come.
class StepRail extends StatelessWidget {
  const StepRail({super.key, required this.current});

  final CreateStep current;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final done = context.readable(AppColors.emerald);

    return Row(
      children: [
        for (final step in CreateStep.values) ...[
          if (step.index > 0)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: step.index <= current.index
                      ? done.withValues(alpha: 0.45)
                      : c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          _StepChip(step: step, current: current),
        ],
      ],
    );
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip({required this.step, required this.current});

  final CreateStep step;
  final CreateStep current;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final done = step.index < current.index;
    final active = step == current;
    final accent = context.readable(AppColors.violet);
    final tone = done
        ? context.readable(AppColors.emerald)
        : active
            ? accent
            : c.textMuted;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: done
              ? _Mark(
                  background: AppColors.tint(tone, 0x29),
                  border: AppColors.tint(tone, 0x73),
                  child: Icon(Icons.check_rounded, size: 12, color: tone),
                )
              : active
                  ? _Mark(
                      background: accent,
                      child: Text(
                        '${step.index + 1}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : _Mark(
                      background: c.bgInner,
                      border: c.border,
                      child: Text(
                        '${step.index + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: c.textMuted,
                        ),
                      ),
                    ),
        ),
        const SizedBox(width: 7),
        Text(
          step.label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            color: tone,
          ),
        ),
      ],
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark({required this.background, required this.child, this.border});

  final Color background;
  final Color? border;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: border == null ? null : Border.all(color: border!),
      ),
      child: child,
    );
  }
}
