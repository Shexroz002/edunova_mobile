import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/subject_style.dart';
import '../domain/analytics_models.dart';

/// Per-subject accuracy, weakest first, each row a way into a test.
///
/// Shared by the home page and Statistika, which drew two different lists of
/// the same data — one merged and capitalised its subject names, the other did
/// not, so "Fizika 41 %" and "fizika 41 %" stood in one app.
///
/// The home page shows the bare rows; Statistika adds the counts behind each
/// percentage. Either way the list is a launcher rather than a report: tapping
/// a row opens the test picker filtered to that subject, and the weakest
/// subject sits first, so the order itself answers "what should I practise
/// next".
class SubjectList extends StatelessWidget {
  const SubjectList({
    super.key,
    required this.subjects,
    required this.onPractise,
    this.showCounts = false,
    this.tint,
  });

  final List<SubjectStats> subjects;

  /// Called with the subject name as it is stored, which is what filters
  /// quizzes — never the capitalised form.
  final ValueChanged<String> onPractise;

  /// Adds "22 / 37 to'g'ri" under the bar. Statistika is where that belongs;
  /// on the home page it is one fact too many.
  final bool showCounts;

  /// Row background. Statistika draws the rows inside a card, so they take the
  /// inner surface instead of the card one.
  final Color? tint;

  /// Merged spellings, weakest first.
  static List<SubjectStats> ordered(List<SubjectStats> rows) {
    final merged = SubjectStats.merged(rows);
    merged.sort((a, b) => a.percent.compareTo(b.percent));
    return merged;
  }

  @override
  Widget build(BuildContext context) {
    final rows = ordered(subjects);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, subject) in rows.indexed) ...[
          if (index > 0) const SizedBox(height: 10),
          _SubjectRow(
            stats: subject,
            showCounts: showCounts,
            tint: tint,
            onTap: () => onPractise(subject.subject),
          ),
        ],
      ],
    );
  }
}

class _SubjectRow extends StatelessWidget {
  const _SubjectRow({
    required this.stats,
    required this.onTap,
    required this.showCounts,
    this.tint,
  });

  final SubjectStats stats;
  final VoidCallback onTap;
  final bool showCounts;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = SubjectStyle.of(stats.subject);
    final accent = context.readable(style.color);
    final brand = context.readable(AppColors.brand);

    return Material(
      color: tint ?? c.bgCard,
      borderRadius: BorderRadius.circular(15),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // The whole row is the target, so the ▶ chip can stay small.
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: tint == null ? Border.all(color: c.border) : null,
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
                child: Icon(style.icon, size: 19, color: accent),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      SubjectStyle.displayName(stats.subject),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: (stats.percent / 100).clamp(0, 1),
                        minHeight: 5,
                        backgroundColor: tint == null ? c.bgInner : c.border,
                        valueColor: AlwaysStoppedAnimation(brand),
                      ),
                    ),
                    if (showCounts) ...[
                      const SizedBox(height: 5),
                      Text(
                        // The wrong count is the difference; saying it as well
                        // was the third statement of one fact.
                        '${stats.correct} / ${stats.total} to‘g‘ri',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10.5, color: c.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 11),
              Text(
                // Two decimals ("59.46%") add no accuracy and stop the column
                // from lining up.
                formatPercent(stats.percent),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: brand,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: c.border),
                ),
                child: Icon(Icons.play_arrow_rounded, size: 18, color: brand),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
