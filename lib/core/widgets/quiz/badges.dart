import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../utils/difficulty.dart';
import '../../utils/grade.dart';
import '../../utils/subject_style.dart';

/// Small colored pill with optional icon.
class Pill extends StatelessWidget {
  const Pill({super.key, required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.tint(color),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.tint(color, 0x40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The fill stays bright; the label takes the readable twin, which on
          // a light surface is several steps darker.
          if (icon != null) ...[
            Icon(icon, size: 12, color: context.readable(color)),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: context.readable(color),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Oson / O'rta / Qiyin" pill.
class DifficultyChip extends StatelessWidget {
  const DifficultyChip(this.difficulty, {super.key});

  final Difficulty difficulty;

  @override
  Widget build(BuildContext context) {
    if (difficulty == Difficulty.unknown) return const SizedBox.shrink();
    return Pill(label: difficulty.label, color: difficulty.color);
  }
}

/// Subject name pill with the subject icon.
class SubjectBadge extends StatelessWidget {
  const SubjectBadge(this.subject, {super.key});

  final String? subject;

  @override
  Widget build(BuildContext context) {
    final style = SubjectStyle.of(subject);
    return Pill(label: subject ?? "Noma'lum fan", color: style.color, icon: style.icon);
  }
}

/// Rounded square with the subject icon (card leading).
class SubjectIconTile extends StatelessWidget {
  const SubjectIconTile(this.subject, {super.key, this.size = 44});

  final String? subject;
  final double size;

  @override
  Widget build(BuildContext context) {
    final style = SubjectStyle.of(subject);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.tint(style.color),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(style.icon, color: context.readable(style.color), size: size * 0.5),
    );
  }
}

/// Letter grade square (A+, A, B, C, D).
class GradeBadge extends StatelessWidget {
  const GradeBadge(this.percent, {super.key, this.size = 36});

  final double percent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final grade = Grade.of(percent);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.tint(grade.color),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.tint(grade.color, 0x55)),
      ),
      child: Text(
        grade.letter,
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.w800,
          color: context.readable(grade.color),
        ),
      ),
    );
  }
}

/// Circular score indicator with the percentage in the middle.
class ScoreRing extends StatelessWidget {
  const ScoreRing({super.key, required this.percent, this.size = 120, this.caption});

  final double percent;
  final double size;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = Grade.of(percent).color;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: percent <= 0 ? 0.0 : (percent >= 100 ? 1.0 : percent / 100),
            strokeWidth: size * 0.08,
            backgroundColor: c.border,
            valueColor: AlwaysStoppedAnimation(color),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${percent.round()}%',
                  style: TextStyle(
                      fontSize: size * 0.24, fontWeight: FontWeight.w800, color: c.textPrimary),
                ),
                if (caption != null)
                  Text(caption!, style: TextStyle(fontSize: size * 0.1, color: c.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
