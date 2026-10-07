import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/subject_style.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../core/widgets/hint_pill.dart';
import '../../../../core/widgets/quiz/markdown_table.dart';
import '../../../../core/widgets/quiz/math_text.dart';
import '../../../../core/widgets/quiz/option_tile.dart';
import '../../../../core/widgets/quiz/question_picture.dart';
import '../../../solution/presentation/mistake_sheet.dart';
import '../../domain/mistake_models.dart';

/// One question under review, before and after the student has chosen.
///
/// Once an answer is sent the correct option is marked and the student's own
/// choice is marked beside it. That is the point of the bank: a test measures,
/// a review teaches, so the answer cannot wait until the end.
class ReviewQuestion extends StatelessWidget {
  const ReviewQuestion({
    super.key,
    required this.question,
    required this.progress,
    required this.chosen,
    required this.result,
    required this.sending,
    required this.error,
    required this.onChoose,
    required this.onNext,
    required this.isLast,
  });

  final MistakeQuestion question;
  final double progress;

  /// The label the student tapped, set before the answer comes back.
  final String? chosen;

  final MistakeAnswerResult? result;
  final bool sending;
  final String? error;
  final ValueChanged<String> onChoose;
  final VoidCallback onNext;
  final bool isLast;

  bool get _answered => result != null;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final table = question.tableMarkdown;
    final meta = [
      SubjectStyle.displayName(question.subject),
      if (question.topic?.trim().isNotEmpty == true) question.topic!.trim(),
    ].where((part) => part.isNotEmpty).join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: progress.clamp(0, 1),
            minHeight: 4,
            backgroundColor: c.bgInner,
            valueColor: AlwaysStoppedAnimation(context.readable(AppColors.brand)),
          ),
        ),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            meta.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: c.textMuted,
            ),
          ),
        ],
        const SizedBox(height: 8),
        MathText(
          question.questionText,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            height: 1.4,
            letterSpacing: -0.2,
            color: c.textPrimary,
          ),
        ),
        if (table != null && table.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          MarkdownTable(table),
        ],
        for (final url in question.imageUrls) ...[
          const SizedBox(height: 12),
          QuestionPicture(url: url),
        ],
        const SizedBox(height: 14),
        for (final option in question.options) ...[
          OptionTile(
            label: option.label,
            text: option.text,
            state: _stateOf(option.label),
            onTap: _answered || sending ? null : () => onChoose(option.label),
          ),
          const SizedBox(height: 9),
        ],
        if (error != null) ...[
          const SizedBox(height: 4),
          HintPill(text: error!, icon: Icons.error_outline_rounded, tone: AppColors.error),
        ],
        if (_answered) ...[
          const SizedBox(height: 6),
          _Verdict(result: result!, wrongCount: question.wrongCount),
          const SizedBox(height: 8),
          _SolutionLink(
            questionId: question.questionId,
            chosen: chosen,
            correct: result!.isCorrect,
            subject: question.subject,
          ),
          const SizedBox(height: 8),
          GradientButton(
            label: isLast ? 'Yakunlash' : 'Keyingi savol',
            icon: Icons.arrow_forward_rounded,
            height: 50,
            onPressed: onNext,
          ),
        ],
      ],
    );
  }

  OptionState _stateOf(String label) {
    final answer = result;
    if (answer == null) return chosen == label ? OptionState.selected : OptionState.idle;
    if (answer.correctOption != null && label == answer.correctOption) {
      return OptionState.correct;
    }
    if (label == chosen) return OptionState.wrong;
    return OptionState.idle;
  }
}

class _Verdict extends StatelessWidget {
  const _Verdict({required this.result, required this.wrongCount});

  final MistakeAnswerResult result;
  final int wrongCount;

  @override
  Widget build(BuildContext context) {
    if (result.cleared) {
      return const HintPill(
        text: 'Bu savolni o‘zlashtirdingiz — ketma-ket ikki marta to‘g‘ri javob berdingiz.',
        icon: Icons.check_circle_outline_rounded,
        tone: AppColors.success,
      );
    }
    if (result.isCorrect) {
      return const HintPill(
        text: 'To‘g‘ri. Mustahkamlash uchun savol yana bir marta qaytadi.',
        icon: Icons.check_rounded,
        tone: AppColors.success,
      );
    }
    return HintPill(
      text: wrongCount > 1
          ? 'Bu savolda $wrongCount-marta xato qildingiz — ertaga yana qaytadi.'
          : 'Savol ertaga yana qaytadi.',
      icon: Icons.refresh_rounded,
      tone: AppColors.warning,
    );
  }
}


/// The way from a review answer to its step-by-step solution.
///
/// A wrong answer asks "where did I go wrong?" first — the option the student
/// picked is known, so the sheet can point at the step. A right one only
/// offers the full solution, quietly, so it never slows a fast review down.
class _SolutionLink extends StatelessWidget {
  const _SolutionLink({required this.questionId, required this.chosen, required this.correct, this.subject});

  final int questionId;
  final String? chosen;
  final bool correct;
  final String? subject;

  @override
  Widget build(BuildContext context) {
    final wrong = !correct && chosen != null;
    return OutlinedButton.icon(
      onPressed: wrong
          ? () => showMistakeSheet(context, questionId: questionId, chosen: chosen!, subject: subject)
          : () => context.push(Routes.questionSolutionPath(questionId, chosen: chosen, subject: subject)),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(46),
        side: BorderSide(color: context.colors.border, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        foregroundColor: context.colors.textPrimary,
      ),
      icon: Text(wrong ? '🤔' : '📖', style: const TextStyle(fontSize: 15)),
      label: Text(
        wrong ? 'Qayerda adashdim?' : 'Yechimini ko‘rish',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    );
  }
}
