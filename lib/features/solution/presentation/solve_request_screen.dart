import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../core/widgets/state_views.dart';
import '../data/solution_repository.dart';
import '../domain/solution_models.dart';
import 'solution_controllers.dart';
import 'solution_view.dart';
import 'widgets/feedback_card.dart';
import 'widgets/solution_arrival.dart';
import 'widgets/solution_delayed.dart';
import 'widgets/waiting_view.dart';

/// A student's own problem: waiting, then the solution, or why there is none.
class SolveRequestScreen extends ConsumerWidget {
  const SolveRequestScreen({super.key, required this.requestId});

  final int requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(solveRequestControllerProvider(requestId));
    final controller = ref.read(solveRequestControllerProvider(requestId).notifier);

    return Scaffold(
      appBar: const PageAppBar(title: Text('Yechim'), showFriends: false),
      body: SafeArea(
        top: false,
        bottom: false,
        child: state.when(
          loading: () => const LoadingView(),
          error: (error, _) => error is SolutionTimeout
              ? SolutionDelayed(
                  problem: state.valueOrNull?.text,
                  note: 'Xizmat hozir band. Masalangiz saqlangan — qayta urinish limitingizdan olinmaydi.',
                  onRetry: controller.retry,
                )
              : ErrorView(
                  message: error is ApiException ? error.message : 'Yechimni yuklab bo‘lmadi.',
                  onRetry: controller.retry,
                ),
          data: (item) => ArrivalSwitcher(
            isWaiting: item.status == SolveStatus.pending || item.status == SolveStatus.recognized,
            celebrate: item.status == SolveStatus.done && item.solution != null,
            steps: item.solution?.steps.length,
            waiting: WaitingView(
              problem: item.text,
              subject: item.subject,
              leaveHint: 'Tayyor yechim «Masala yechish → Oxirgi yechimlar»da turadi.',
            ),
            ready: switch (item.status) {
              SolveStatus.failed => _Failed(item: item, onRetry: controller.retry),
              _ => item.solution == null
                  ? const EmptyView(icon: Icons.menu_book_outlined, title: 'Yechimni ko‘rsatib bo‘lmadi')
                  : SolutionView(
                      solution: item.solution!,
                      problem: item.text,
                      footer: FeedbackCard(
                        onSend: (verdict) =>
                            ref.read(solutionRepositoryProvider).feedback(solveRequestId: item.id, verdict: verdict),
                      ),
                      finishLabel: 'Yangi masala',
                      onFinish: () => context.go(Routes.solve),
                    ),
            },
          ),
        ),
      ),
    );
  }
}

/// No solution. Either the problem itself was incomplete — then the student
/// fixes the text — or the model was busy, and asking again costs nothing.
class _Failed extends StatelessWidget {
  const _Failed({required this.item, required this.onRetry});

  final SolveRequestItem item;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final modelBusy = item.retryable;
    // The server says which it is — busy for a moment, or the service's daily
    // quota spent until tomorrow — so its message is shown, not a fixed line.
    final reason = item.message?.trim();
    return EmptyView(
      icon: modelBusy ? Icons.cloud_off_rounded : Icons.edit_note_rounded,
      title: modelBusy ? 'Yechib bo‘lmadi' : 'Masalada nimadir yetishmayapti',
      subtitle: modelBusy
          ? [if (reason != null && reason.isNotEmpty) reason, 'Qayta urinish limitingizdan olinmaydi.'].join('\n')
          : item.message,
      actionLabel: modelBusy ? 'Qayta urinish' : 'Yangi masala',
      actionIcon: modelBusy ? Icons.refresh_rounded : Icons.add_rounded,
      onAction: modelBusy ? onRetry : () => context.go(Routes.solve),
    );
  }
}
