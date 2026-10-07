import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/subject_style.dart';
import '../../domain/mistake_models.dart';

/// One subject in the bank: how many are open, and when they come back.
///
/// Grouped by subject because that is how a student plans study time — "an hour
/// of maths today" — and the topic sits inside the question itself.
class MistakeSubjectRow extends StatelessWidget {
  const MistakeSubjectRow({super.key, required this.subject, required this.onTap});

  final MistakeSubject subject;
  final VoidCallback onTap;

  bool get _due => subject.due > 0;

  /// "6 tasi bugun" while something is ready, otherwise when it returns.
  String _meta(BuildContext context) {
    if (_due) return '${subject.due} tasi bugun';
    final next = subject.nextDueAt;
    if (next == null) return 'navbatda';
    return '${formatUntil(next)} qaytadi';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = SubjectStyle.of(subject.subject);
    final brand = context.readable(AppColors.brand);
    final warning = context.readable(AppColors.warning);

    return Material(
      color: c.bgCard,
      borderRadius: BorderRadius.circular(15),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // Only a subject with something due can be reviewed on its own.
        onTap: _due ? onTap : null,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: c.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.tint(style.color, 0x2B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(style.icon, size: 19, color: context.readable(style.color)),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      SubjectStyle.displayName(subject.subject),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _meta(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: _due ? FontWeight.w700 : FontWeight.w400,
                        color: _due ? warning : c.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${subject.total}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: _due ? brand : c.textMuted,
                ),
              ),
              if (_due) ...[
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, size: 18, color: c.textMuted),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
