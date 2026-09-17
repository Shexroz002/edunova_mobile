import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/subject_style.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../tests/domain/quiz.dart';

/// The one real decision on the competition screen: which quiz.
///
/// Everything else has a default, so this card carries the page. It also owns
/// the case a new student lands in: `quiz_list` filters by `user_id`, so
/// somebody who has never made a quiz has nothing to pick and needs to be sent
/// to Test yaratish rather than shown an empty picker.
class QuizChoiceCard extends StatelessWidget {
  const QuizChoiceCard({
    super.key,
    required this.quiz,
    required this.onPick,
    required this.hasQuizzes,
    required this.onCreateQuiz,
  });

  final QuizSummary? quiz;
  final VoidCallback onPick;

  /// False only once the list is known to be empty; a pending or failed check
  /// keeps the picker, which is the harmless way to be wrong.
  final bool hasQuizzes;

  final VoidCallback onCreateQuiz;

  @override
  Widget build(BuildContext context) {
    if (!hasQuizzes && quiz == null) return _NoQuiz(onCreateQuiz: onCreateQuiz);

    final c = context.colors;
    final brand = context.readable(AppColors.brand);
    final selected = quiz;
    final style = selected == null ? null : SubjectStyle.of(selected.subject);
    final accent = style == null ? brand : context.readable(style.color);

    return AppCard(
      borderColor: AppColors.tint(brand, 0x80),
      onTap: onPick,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.tint(accent, 0x29),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.tint(accent, 0x52)),
            ),
            child: Icon(style?.icon ?? Icons.search_rounded, size: 22, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: selected == null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Testni tanlang',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        "Qaysi test bo‘yicha bellashasiz?",
                        style: TextStyle(fontSize: 12.5, color: c.textMuted),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selected.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.3,
                          fontWeight: FontWeight.w800,
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${selected.subject ?? "Fan ko‘rsatilmagan"} · '
                        '${selected.questionCount} ta savol',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                      ),
                    ],
                  ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, color: c.textMuted),
        ],
      ),
    );
  }
}

/// Shown to a student who has no quiz to compete with yet.
class _NoQuiz extends StatelessWidget {
  const _NoQuiz({required this.onCreateQuiz});

  final VoidCallback onCreateQuiz;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.tint(c.textMuted, 0x29),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.border),
              ),
              child: Icon(Icons.menu_book_outlined, size: 25, color: c.textMuted),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Sizda hali test yo‘q',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.textPrimary),
          ),
          const SizedBox(height: 5),
          Text(
            'Musobaqa uchun kamida bitta test kerak.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, height: 1.5, color: c.textMuted),
          ),
          const SizedBox(height: 14),
          GradientButton(
            label: 'Test yaratish',
            icon: Icons.auto_awesome_rounded,
            onPressed: onCreateQuiz,
          ),
        ],
      ),
    );
  }
}
