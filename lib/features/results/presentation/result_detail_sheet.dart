import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/grade.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/quiz/badges.dart';
import '../../session/domain/session_models.dart';

/// Opens the "Ko'rish" sheet for one finished session.
Future<void> showResultDetailSheet(BuildContext context, {required HistoryItem item}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useRootNavigator: true,
    backgroundColor: context.colors.bgCard,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      maxChildSize: 0.95,
      builder: (_, controller) => _ResultDetailSheet(item: item, scrollController: controller),
    ),
  );
}

/// Score breakdown of one session, as on the web's "Ko'rish" modal.
///
/// Everything shown comes from the history row itself, so the sheet opens
/// without a request. The web also lists a "Quiz ID", which means nothing to a
/// student and is left out.
class _ResultDetailSheet extends StatelessWidget {
  const _ResultDetailSheet({required this.item, required this.scrollController});

  final HistoryItem item;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final total = item.totalQuestions ?? 0;
    final correct = item.correctAnswers ?? 0;
    final wrong = item.wrongAnswers ?? 0;
    final skipped = (total - correct - wrong).clamp(0, total);
    final grade = Grade.of(item.percent);
    final date = item.finishedAt ?? item.createdAt;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SubjectIconTile(item.subject, size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.subject ?? 'Fan',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              item.title ?? 'Test',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: c.textPrimary),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatPercent(item.percent),
                  style: TextStyle(
                    fontSize: 40,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: grade.color,
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text('ball', style: TextStyle(fontSize: 12, color: c.textMuted)),
                ),
                const Spacer(),
                GradeBadge(item.percent),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _Tally(
                    value: correct,
                    label: "To'g'ri",
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Tally(value: wrong, label: "Noto'g'ri", color: AppColors.error),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Tally(
                    value: skipped,
                    label: "O'tkazilgan",
                    color: c.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _Progress(correct: correct, wrong: wrong, skipped: skipped, total: total),
            const SizedBox(height: 18),
            _DetailRow(
              icon: Icons.help_outline_rounded,
              label: 'Savollar',
              value: '$total ta',
            ),
            if (item.isMultiplayer) ...[
              _DetailRow(
                icon: Icons.groups_outlined,
                label: 'Ishtirokchilar',
                value: "${item.participantCount} ta o'quvchi",
              ),
              _DetailRow(
                icon: Icons.emoji_events_outlined,
                label: 'Reyting',
                value: '#${item.rank} / ${item.participantCount}',
              ),
            ],
            _DetailRow(
              icon: Icons.schedule_rounded,
              label: 'Vaqt',
              // The backend only records start and finish, so an unfinished or
              // same-minute session has no duration to show.
              value: item.durationMinutes == null ? '—' : '${item.durationMinutes} daqiqa',
            ),
            if (date != null)
              _DetailRow(
                icon: Icons.calendar_today_rounded,
                label: 'Sana',
                value: formatDateTime(date),
                isLast: true,
              ),
            const SizedBox(height: 22),
            GradientButton(
              label: 'Xatolar tahlilini ochish',
              icon: Icons.fact_check_outlined,
              onPressed: () {
                Navigator.of(context).pop();
                context.push('/session/${item.sessionId}/review');
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// One of the three counts above the progress bar.
class _Tally extends StatelessWidget {
  const _Tally({required this.value, required this.label, required this.color});

  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.tint(color, dark ? 0x1C : 0x12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.tint(color, dark ? 0x3D : 0x33)),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(fontSize: 20, height: 1, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

/// Segmented bar with its legend, as on the web.
class _Progress extends StatelessWidget {
  const _Progress({
    required this.correct,
    required this.wrong,
    required this.skipped,
    required this.total,
  });

  final int correct;
  final int wrong;
  final int skipped;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Umumiy progress',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textSecondary),
            ),
            const Spacer(),
            Text(
              '$correct / $total',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 8,
            child: total == 0
                ? ColoredBox(color: c.bgInner)
                : Row(
                    // A Row gives its children a loose cross-axis constraint,
                    // so an empty ColoredBox would collapse to zero height and
                    // the bar would not be drawn at all.
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (correct > 0)
                        Expanded(flex: correct, child: const ColoredBox(color: AppColors.success)),
                      if (wrong > 0)
                        Expanded(flex: wrong, child: const ColoredBox(color: AppColors.error)),
                      if (skipped > 0)
                        Expanded(flex: skipped, child: ColoredBox(color: c.textMuted)),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            const _LegendDot(color: AppColors.success, label: "To'g'ri"),
            if (wrong > 0) const _LegendDot(color: AppColors.error, label: 'Xato'),
            if (skipped > 0) _LegendDot(color: c.textMuted, label: "O'tkazilgan"),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: c.textMuted),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontSize: 13, color: c.textSecondary)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary),
          ),
        ],
      ),
    );
  }
}
