import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/quiz/badges.dart';
import '../domain/quiz.dart';

/// Card in the tests list, laid out like the web `StudentTestsPage.tsx`:
/// subject icon tile, badge row, title, description, a meta row and the
/// actions.
///
/// The web's "0 ta" participant count and its guessed difficulty pill are left
/// out: both are invented client-side and `CLAUDE.md` default decision 2 says
/// to drop them. The real question count carries that information instead.
class QuizCard extends StatelessWidget {
  const QuizCard({
    super.key,
    required this.quiz,
    required this.onOpen,
    required this.onStart,
    required this.onCompete,
  });

  final QuizSummary quiz;
  final VoidCallback onOpen;
  final VoidCallback onStart;

  /// Opens the competition flow with this quiz preselected.
  final VoidCallback onCompete;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final created = quiz.createdAt;
    final empty = quiz.questionCount == 0;

    return Material(
      color: c.bgCard,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SubjectIconTile(quiz.subject),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            SubjectBadge(quiz.subject),
                            if (quiz.isNew)
                              const Pill(
                                label: 'YANGI',
                                color: Color(0xFFA78BFA),
                                icon: Icons.auto_awesome_rounded,
                              ),
                            // A quiz nobody owns comes from the shared
                            // library. How it was generated is our business,
                            // not the student's, so the badge says whose it is
                            // instead of where it came from.
                            if (!quiz.canEdit)
                              const Pill(
                                label: 'Tizim testi',
                                color: AppColors.emerald,
                                icon: Icons.verified_outlined,
                              )
                            else
                              Pill(
                                label: quiz.source.label,
                                color: AppColors.sky,
                                icon: quiz.source == QuizSource.ai
                                    ? Icons.auto_awesome_rounded
                                    : Icons.picture_as_pdf_outlined,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          quiz.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                            color: c.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (quiz.description != null) ...[
                const SizedBox(height: 10),
                Text(
                  quiz.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, height: 1.45, color: c.textSecondary),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetaChip(icon: Icons.help_outline_rounded, text: '${quiz.questionCount} savol'),
                  _MetaChip(
                    icon: Icons.timer_outlined,
                    text: '~${formatMinutes(quiz.suggestedMinutes)}',
                  ),
                  if (created != null)
                    _MetaChip(icon: Icons.calendar_today_outlined, text: formatDate(created)),
                ],
              ),
              const SizedBox(height: 14),
              // Two equal halves: on a 360 dp phone a 3:2 split truncated
              // "Musobaqa", and the card itself already opens the detail.
              Row(
                children: [
                  Expanded(
                    child: GradientButton(
                      icon: Icons.play_arrow_rounded,
                      label: 'Boshlash',
                      enabled: !empty,
                      height: 46,
                      onPressed: onStart,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: empty ? null : onCompete,
                      icon: const Icon(Icons.groups_rounded, size: 18),
                      label: const Text('Musobaqa', maxLines: 1, overflow: TextOverflow.ellipsis),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rounded meta chip (`30 savol`, `~30 daqiqa`, date).
class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.bgInner,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c.textMuted),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}
