import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/solution_repository.dart';
import '../domain/solution_models.dart';

/// How often a screen asks again while the server is still writing.
const solutionPollEvery = Duration(seconds: 3);

/// After this long the screen stops asking and offers a manual retry instead.
///
/// Longer than the server's four minutes after which a pending row is treated
/// as lost and queued again: a shorter window gave up before that recovery
/// could ever run, and a task lost in a worker restart spun forever.
const solutionPollFor = Duration(minutes: 5);

/// Polling gave up. A state of its own, so the screen rebuilds into the
/// "taking too long" view instead of a spinner nobody is updating.
class SolutionTimeout implements Exception {
  const SolutionTimeout();
}

/// Polls before giving up. Counted, not timed: each poll waits for the previous
/// reply, so this is at least [solutionPollFor] on a phone and exact in a test.
final int _maxPolls = solutionPollFor.inSeconds ~/ solutionPollEvery.inSeconds;

/// The question and the option the student picked.
typedef ExplanationArgs = ({int questionId, String? chosen});

/// A bank question's solution, re-read while it is still being written.
class ExplanationController extends AutoDisposeFamilyAsyncNotifier<ExplanationResult, ExplanationArgs> {
  Timer? _timer;
  int _polls = 0;

  @override
  Future<ExplanationResult> build(ExplanationArgs arg) async {
    ref.onDispose(() => _timer?.cancel());
    final result = await ref.read(solutionRepositoryProvider).explanation(arg.questionId, chosen: arg.chosen);
    _schedule(result.status == ExplanationStatus.pending);
    return result;
  }

  /// True once polling has given up; the screen offers "Qayta urinish".
  bool get timedOut => _polls >= _maxPolls;

  void _schedule(bool pending) {
    _timer?.cancel();
    if (!pending) return;
    if (timedOut) {
      // Keeps the last reply, so the "taking too long" view can still show
      // the problem that was sent.
      state = AsyncError<ExplanationResult>(const SolutionTimeout(), StackTrace.current).copyWithPrevious(state);
      return;
    }
    _timer = Timer(solutionPollEvery, () async {
      _polls++;
      final next = await AsyncValue.guard(
        () => ref.read(solutionRepositoryProvider).explanation(arg.questionId, chosen: arg.chosen),
      );
      state = next;
      _schedule(next.valueOrNull?.status == ExplanationStatus.pending);
    });
  }

  /// Starts over after a time-out or an error.
  Future<void> retry() async {
    _polls = 0;
    state = const AsyncLoading();
    ref.invalidateSelf();
  }
}

/// Provides [ExplanationController].
final explanationControllerProvider =
    AsyncNotifierProvider.autoDispose.family<ExplanationController, ExplanationResult, ExplanationArgs>(
  ExplanationController.new,
);

/// A student's own problem, re-read while it is being solved.
class SolveRequestController extends AutoDisposeFamilyAsyncNotifier<SolveRequestItem, int> {
  Timer? _timer;
  int _polls = 0;

  @override
  Future<SolveRequestItem> build(int arg) async {
    ref.onDispose(() => _timer?.cancel());
    final item = await ref.read(solutionRepositoryProvider).request(arg);
    _schedule(item.isWorking);
    return item;
  }

  /// True once polling has given up.
  bool get timedOut => _polls >= _maxPolls;

  void _schedule(bool working) {
    _timer?.cancel();
    if (!working) return;
    if (timedOut) {
      // Keeps the last reply, so the "taking too long" view can still show
      // the problem that was sent.
      state = AsyncError<SolveRequestItem>(const SolutionTimeout(), StackTrace.current).copyWithPrevious(state);
      return;
    }
    _timer = Timer(solutionPollEvery, () async {
      _polls++;
      final next = await AsyncValue.guard(() => ref.read(solutionRepositoryProvider).request(arg));
      state = next;
      _schedule(next.valueOrNull?.isWorking ?? false);
    });
  }

  /// Sends a failed problem again. The server does not count it twice.
  Future<void> retry() async {
    final current = state.valueOrNull;
    _polls = 0;
    if (current != null && current.status == SolveStatus.failed) {
      state = const AsyncLoading();
      state = await AsyncValue.guard(() => ref.read(solutionRepositoryProvider).retry(arg));
      _schedule(state.valueOrNull?.isWorking ?? false);
      return;
    }
    state = const AsyncLoading();
    ref.invalidateSelf();
  }
}

/// Provides [SolveRequestController].
final solveRequestControllerProvider =
    AsyncNotifierProvider.autoDispose.family<SolveRequestController, SolveRequestItem, int>(
  SolveRequestController.new,
);
