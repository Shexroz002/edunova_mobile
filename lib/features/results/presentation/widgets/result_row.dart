import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/subject_style.dart';
import '../../../session/domain/session_models.dart';

/// One finished — or abandoned — test in the history list.
///
/// The card this replaces was 248 dp and said the same score four ways: a
/// percent pill, a grade letter, a progress bar and `✓0 ✗5 ?30` chips. At 64 dp
/// the score is stated once, and its colour carries the band. Forty-two results
/// went from about eighteen screens to five and a half.
class ResultRow extends StatelessWidget {
  const ResultRow({
    super.key,
    required this.item,
    required this.onOpen,
    required this.onLeaderboard,
  });

  final HistoryItem item;

  /// Opens the result sheet.
  final VoidCallback onOpen;

  /// Opens the leaderboard. Reached from the rank chip, so only a competition
  /// ever calls it.
  final VoidCallback onLeaderboard;

  /// Score bands. A weak result is amber rather than red: the list is a record,
  /// not a verdict, and half of these rows are practice.
  static Color scoreColor(BuildContext context, double percent) {
    if (percent >= 80) return context.readable(AppColors.success);
    if (percent >= 50) return context.readable(AppColors.brand);
    return context.readable(AppColors.warning);
  }

  /// Subject, then either what the test cost or how far it got.
  String get _meta {
    final subject = SubjectStyle.displayName(item.subject);
    final parts = [if (subject.isNotEmpty) subject];

    if (item.canResume) {
      parts.add('davom ettirish mumkin');
      return parts.join(' · ');
    }

    if (!item.isComplete) {
      final total = item.totalQuestions ?? 0;
      parts.add(total == 0
          ? 'javob berilmagan'
          : '${item.answered}/$total javob berilgan');
      return parts.join(' · ');
    }

    parts.add('${item.totalQuestions} ta savol');
    final minutes = item.durationMinutes;
    if (minutes != null && minutes > 0) parts.add(formatMinutes(minutes));
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = SubjectStyle.of(item.subject);

    return Material(
      color: c.bgCard,
      borderRadius: BorderRadius.circular(15),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: c.border),
          ),
          padding: const EdgeInsets.all(12),
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
                      item.title ?? 'Test',
                      // Real titles run to "Fizika: mustahkamlash uchun test";
                      // one line clipped most of them even after the row was
                      // cleared of buttons.
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                        color: c.textPrimary,
                      ),
                    ),
                    SizedBox(height: item.isMultiplayer ? 0 : 4),
                    Row(
                      children: [
                        // The rank sits on the meta line rather than beside the
                        // score: in the trailing group it, the percentage and
                        // the chevron together left the title 119 dp, and
                        // "Fizika: mustahkamlash uchun test" clipped even
                        // across two lines. Here the title gets 176 dp.
                        if (item.isMultiplayer) ...[
                          _RankChip(item: item, onTap: onLeaderboard),
                          const SizedBox(width: 7),
                        ],
                        Flexible(
                          child: Text(
                            _meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11.5, color: c.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 9),
              if (item.canResume)
                // Bu yagona satr turi: uni ochish natijani ko'rish emas,
                // testni davom ettirish demakdir. Yozuv o'rniga belgi -
                // "Davom ettirish" pilli sarlavhani kesib qo'yadi, matni esa
                // pastdagi qatorda turibdi.
                Tooltip(
                  message: 'Davom ettirish',
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    size: 20,
                    color: context.readable(AppColors.brand),
                  ),
                )
              else if (item.isComplete)
                Text(
                  formatPercent(item.percent),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: scoreColor(context, item.percent),
                  ),
                )
              else
                // `0% · D` read exactly like failing the test, though the
                // student had answered 5 of 30 questions and walked away. The
                // meta line already says how far they got, so the marker here
                // stays an icon rather than a pill wide enough to clip titles.
                Tooltip(
                  message: 'Tugallanmagan',
                  child: Icon(Icons.pause_circle_outline_rounded,
                      size: 20, color: c.textMuted),
                ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, size: 20, color: c.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rank in a competition, and the way into its leaderboard.
///
/// "Reyting" used to be a button on every row, solo tests included, where the
/// leaderboard holds one person: you. The chip replaces it where it means
/// something, and says the placing while it is at it.
///
/// The visible pill is 22 dp so it sits on the meta line without pushing the
/// title around, but a control has to be reachable: the tap area around it is
/// padded to the 44 dp floor, which is what makes a competition row taller than
/// a solo one.
class _RankChip extends StatelessWidget {
  const _RankChip({required this.item, required this.onTap});

  final HistoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final warning = context.readable(AppColors.warning);

    return SizedBox(
      height: 44,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          // Without a width factor the Center stretches across the meta row and
          // pushes the text out of it.
          child: Center(
            widthFactor: 1,
            child: Container(
              height: 22,
              padding: const EdgeInsets.symmetric(horizontal: 7),
              decoration: BoxDecoration(
                color: AppColors.tint(warning, 0x24),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.tint(warning, 0x57)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.emoji_events_rounded, size: 11, color: warning),
                  const SizedBox(width: 3),
                  Text(
                    '${item.rank}/${item.participantCount}',
                    style:
                        TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: warning),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
