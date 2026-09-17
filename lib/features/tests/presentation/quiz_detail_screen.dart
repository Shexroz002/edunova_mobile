import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/difficulty.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/quiz/badges.dart';
import '../../../core/widgets/quiz/math_text.dart';
import '../../../core/widgets/quiz/option_tile.dart';
import '../../../core/widgets/quiz/question_view.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/state_views.dart';
import '../data/tests_repository.dart';
import '../domain/quiz.dart';
import 'start_test_sheet.dart';

/// Quiz detail loaded by id (auto-disposed when the screen closes).
final quizDetailProvider = FutureProvider.autoDispose.family<QuizDetail, int>(
  (ref, quizId) => ref.watch(testsRepositoryProvider).fetchQuiz(quizId),
);

/// Quiz overview: info, difficulty split, question list and "start".
///
/// Question editing is planned for phase 6.
class QuizDetailScreen extends ConsumerWidget {
  const QuizDetailScreen({super.key, required this.quizId});

  final int quizId;

  Future<void> _start(BuildContext context, QuizDetail quiz) async {
    final sessionId = await showStartTestSheet(context, quiz: quiz.asSummary);
    if (sessionId != null && context.mounted) context.push('/session/$sessionId/play');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(quizDetailProvider(quizId));

    return Scaffold(
      body: SafeArea(
        child: detail.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            message: ApiException.from(e).message,
            onRetry: () => ref.invalidate(quizDetailProvider(quizId)),
          ),
          data: (quiz) => RefreshIndicator(
            onRefresh: () => ref.refresh(quizDetailProvider(quizId).future),
            child: ListView(
              padding: EdgeInsets.fromLTRB(context.pagePadding, 8, context.pagePadding, 28),
              children: [
                ContentConstraint(
                  maxWidth: 760,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PageHeader(title: quiz.title, subtitle: quiz.subject),
                      const SizedBox(height: 16),
                      _Header(quiz: quiz, onStart: () => _start(context, quiz)),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Savollar',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: context.colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${quiz.questions.length} ta savol ko‘rsatilmoqda',
                                  style: TextStyle(fontSize: 13, color: context.colors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          Pill(
                            label: '${quiz.questions.length} ta jami',
                            color: AppColors.brandLight,
                            icon: Icons.list_alt_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (quiz.questions.isEmpty)
                        const EmptyView(icon: Icons.help_outline_rounded, title: "Savollar yo'q"),
                      for (var i = 0; i < quiz.questions.length; i++) ...[
                        _QuestionRow(
                          number: i + 1,
                          question: quiz.questions[i],
                          quizId: quizId,
                          canEdit: quiz.canEdit,
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.quiz, required this.onStart});

  final QuizDetail quiz;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Accent strip across the top of the card, as on the web.
          const SizedBox(
            height: 4,
            child: DecoratedBox(decoration: BoxDecoration(gradient: AppColors.accentBarGradient)),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SubjectIconTile(quiz.subject, size: 52),
                    const SizedBox(width: 14),
                    Expanded(
                      // The page header above already names the quiz; repeating it
                      // here costs a phone screen more than it helps.
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              SubjectBadge(quiz.subject),
                              Pill(label: quiz.source.label, color: AppColors.sky),
                              Pill(
                                  label: '${quiz.questions.length} savol',
                                  color: AppColors.brandLight),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (quiz.description != null) ...[
                  const SizedBox(height: 12),
                  Text(quiz.description!, style: TextStyle(fontSize: 14, color: c.textSecondary)),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    for (final difficulty in const [
                      Difficulty.easy,
                      Difficulty.medium,
                      Difficulty.hard
                    ]) ...[
                      Expanded(
                          child: _DifficultyCount(
                              difficulty: difficulty, count: quiz.countOf(difficulty))),
                      if (difficulty != Difficulty.hard) const SizedBox(width: 8),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                GradientButton(
                  label: 'Testni boshlash',
                  icon: Icons.play_arrow_rounded,
                  enabled: quiz.questions.isNotEmpty,
                  onPressed: onStart,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DifficultyCount extends StatelessWidget {
  const _DifficultyCount({required this.difficulty, required this.count});

  final Difficulty difficulty;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.tint(difficulty.color, 0x14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.tint(difficulty.color, 0x40)),
      ),
      child: Column(
        children: [
          Text(
            '$count ta',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: difficulty.color),
          ),
          const SizedBox(height: 2),
          Text(
            '${difficulty.label} savollar',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _QuestionRow extends ConsumerWidget {
  const _QuestionRow({
    required this.number,
    required this.question,
    required this.quizId,
    required this.canEdit,
  });

  final int number;
  final QuizQuestionBrief question;

  /// Needed to refresh this list once the editor closes.
  final int quizId;

  /// The quiz's `is_update`. A catalogue quiz belongs to nobody, and the
  /// question editor is owner-scoped, so offering it would only 404.
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return AppCard(
      onTap: () => _openPreview(context, ref),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.accentMuted, borderRadius: BorderRadius.circular(8)),
            child: Text('$number', style: TextStyle(fontWeight: FontWeight.w800, color: c.accent)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MathText(question.text,
                    style: TextStyle(fontSize: 14, color: c.textPrimary, height: 1.4)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DifficultyChip(question.difficulty),
                    if (question.topic != null)
                      Text(question.topic!, style: TextStyle(fontSize: 12, color: c.textMuted)),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: c.textMuted),
        ],
      ),
    );
  }

  /// Shows the preview and, when the student asks to edit, opens the editor and
  /// reloads both this list and the preview once it closes.
  Future<void> _openPreview(BuildContext context, WidgetRef ref) async {
    final wantsEdit = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.colors.bgCard,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, controller) => _QuestionPreviewSheet(
          questionId: question.id,
          number: number,
          scrollController: controller,
          canEdit: canEdit,
        ),
      ),
    );

    if (wantsEdit != true || !context.mounted) return;
    await context.push('/questions/${question.id}/edit');
    ref.invalidate(questionPreviewProvider(question.id));
    ref.invalidate(quizDetailProvider(quizId));
  }
}

/// One question with its options and the correct answer highlighted.
final questionPreviewProvider = FutureProvider.autoDispose.family<QuestionContent, int>(
  (ref, questionId) => ref.watch(testsRepositoryProvider).fetchQuestion(questionId),
);

class _QuestionPreviewSheet extends ConsumerWidget {
  const _QuestionPreviewSheet({
    required this.questionId,
    required this.number,
    required this.scrollController,
    required this.canEdit,
  });

  final int questionId;
  final int number;

  /// Hides the edit action on a quiz the student does not own.
  final bool canEdit;

  /// Comes from the draggable sheet, so dragging and scrolling agree.
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final question = ref.watch(questionPreviewProvider(questionId));
    return SafeArea(
      child: question.when(
        loading: () => const SizedBox(height: 200, child: LoadingView()),
        error: (e, _) => SizedBox(
          height: 260,
          child: ErrorView(
            message: ApiException.from(e).message,
            onRetry: () => ref.invalidate(questionPreviewProvider(questionId)),
          ),
        ),
        data: (q) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              QuestionView(
                question: q,
                header: Text(
                  '$number-savol',
                  style:
                      TextStyle(fontWeight: FontWeight.w800, color: context.colors.textSecondary),
                ),
                stateOf: (option) =>
                    option.isCorrect == true ? OptionState.correct : OptionState.idle,
              ),
              if (canEdit) ...[
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  // The row that opened this sheet does the navigating, so it
                  // can refresh the list when the editor closes.
                  onPressed: () => Navigator.of(context).pop(true),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor: context.colors.accent,
                    side: BorderSide(color: context.colors.border),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 19),
                  label: const Text('Tahrirlash'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
