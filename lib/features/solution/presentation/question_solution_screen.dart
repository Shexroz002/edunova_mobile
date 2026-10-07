import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../core/widgets/state_views.dart';
import '../data/solution_repository.dart';
import '../domain/solution_models.dart';
import 'solution_controllers.dart';
import 'solution_view.dart';
import 'widgets/dispute_card.dart';
import 'widgets/feedback_card.dart';
import 'widgets/solution_arrival.dart';
import 'widgets/solution_delayed.dart';
import 'widgets/waiting_view.dart';

/// The step-by-step solution of a question from a finished test.
class QuestionSolutionScreen extends ConsumerWidget {
  const QuestionSolutionScreen({super.key, required this.questionId, this.chosen, this.subject});

  final int questionId;

  /// The option the student picked, if any.
  final String? chosen;

  /// The question's subject, for the waiting board and its tips.
  final String? subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = (questionId: questionId, chosen: chosen);
    final state = ref.watch(explanationControllerProvider(args));
    final controller = ref.read(explanationControllerProvider(args).notifier);

    return Scaffold(
      appBar: const PageAppBar(title: Text('Yechim'), showFriends: false),
      body: SafeArea(
        top: false,
        bottom: false,
        child: state.when(
          loading: () => const LoadingView(),
          error: (error, _) => error is SolutionTimeout
              ? SolutionDelayed(
                  problem: state.valueOrNull?.questionText,
                  note: 'Xizmat hozir band. Birozdan keyin qayta urinib ko‘ring.',
                  onRetry: controller.retry,
                )
              : ErrorView(
                  message: error is ApiException ? error.message : 'Yechimni yuklab bo‘lmadi.',
                  onRetry: controller.retry,
                ),
          data: (result) => ArrivalSwitcher(
            isWaiting: result.status == ExplanationStatus.pending,
            celebrate: result.status == ExplanationStatus.ready,
            steps: result.solution?.steps.length,
            waiting: WaitingView(
              problem: result.questionText,
              subject: subject,
              leaveHint: 'Yechim tayyor bo‘lgach shu savolni qayta ochganingizda ko‘rasiz.',
            ),
            ready: switch (result.status) {
              ExplanationStatus.disputed => ListView(
                  padding: const EdgeInsets.all(16),
                  children: [DisputeCard(result: result)],
                ),
              ExplanationStatus.ready => SolutionView(
                  solution: result.solution!,
                  problem: result.questionText,
                  option: result.correctOption,
                  footer: result.explanationId == null
                      ? null
                      : FeedbackCard(
                          onSend: (verdict) => ref
                              .read(solutionRepositoryProvider)
                              .feedback(explanationId: result.explanationId, verdict: verdict),
                        ),
                  finishLabel: 'Yopish',
                  onFinish: () => Navigator.of(context).maybePop(),
                ),
              _ => EmptyView(
                  icon: Icons.menu_book_outlined,
                  title: 'Yechim yo‘q',
                  subtitle: result.message,
                ),
            },
          ),
        ),
      ),
    );
  }
}
