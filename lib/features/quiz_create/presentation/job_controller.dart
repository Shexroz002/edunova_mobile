import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/realtime/socket_service.dart';
import '../../../core/utils/json_utils.dart';
import '../data/quiz_create_repository.dart';
import '../domain/quiz_job.dart';

/// What the progress view renders while a job runs.
class JobState {
  const JobState({required this.job, this.socketStatus = SocketStatus.idle, this.timedOut = false});

  final QuizJob job;
  final SocketStatus socketStatus;

  /// Set when the job made no progress for [JobController.stallTimeout].
  final bool timedOut;

  JobState copyWith({QuizJob? job, SocketStatus? socketStatus, bool? timedOut}) => JobState(
        job: job ?? this.job,
        socketStatus: socketStatus ?? this.socketStatus,
        timedOut: timedOut ?? this.timedOut,
      );
}

/// Follows one generation job to its end.
///
/// The socket is the fast path and the 3 s poll is the fallback, exactly as
/// `docs/api-notes.md` §11 requires: the worker publishes to Redis, so a
/// dropped socket would otherwise leave the screen frozen. Whichever source
/// reports a final status first wins.
class JobController extends AutoDisposeFamilyNotifier<JobState, QuizJob> {
  /// Give up when nothing changes for this long. The backend retries the AI
  /// three times and has no deadline of its own, so a job can hang forever
  /// (see `docs/BACKEND_ISSUES.md`).
  static const stallTimeout = Duration(minutes: 6);

  static const _pollInterval = Duration(seconds: 3);

  SocketService? _socket;
  StreamSubscription<Json>? _messages;
  StreamSubscription<SocketStatus>? _status;
  Timer? _poll;
  Timer? _stall;

  @override
  JobState build(QuizJob arg) {
    ref.onDispose(_stop);

    if (!arg.isFinal) {
      _connect(arg.id);
      _startPolling(arg.id);
      _restartStallTimer();
    }
    return JobState(job: arg);
  }

  void _connect(String jobId) {
    // The trailing slash is required; without it the upgrade 404s.
    final socket = ref.read(socketFactoryProvider).create('/ws/jobs/$jobId/');
    _socket = socket;
    _messages =
        socket.messages.listen((frame) => _apply(QuizJob.fromJson(frame, fallbackId: jobId)));
    _status = socket.statusChanges.listen((s) => state = state.copyWith(socketStatus: s));
    socket.connect();
  }

  void _startPolling(String jobId) {
    _poll = Timer.periodic(_pollInterval, (_) async {
      try {
        _apply(await ref.read(quizCreateRepositoryProvider).fetchJob(jobId));
      } on ApiException {
        // A transient failure is not worth surfacing: the next tick retries,
        // and the stall timer ends the wait if it never recovers.
      }
    });
  }

  void _restartStallTimer() {
    _stall?.cancel();
    _stall = Timer(stallTimeout, () {
      state = state.copyWith(timedOut: true);
      _stop();
    });
  }

  void _apply(QuizJob update) {
    final merged = state.job.mergedWith(update);
    final changed = merged.status != state.job.status || merged.progress != state.job.progress;
    state = state.copyWith(job: merged);
    if (changed) _restartStallTimer();
    if (merged.isFinal) _stop();
  }

  /// Releases the socket and both timers. Safe to call more than once.
  ///
  /// The server keeps a socket open after sending a snapshot of an
  /// already-finished job, so the client has to close it itself.
  void _stop() {
    _messages?.cancel();
    _status?.cancel();
    _socket?.close();
    _socket = null;
    _poll?.cancel();
    _poll = null;
    _stall?.cancel();
    _stall = null;
  }
}

/// Tracks the job passed as the family argument.
final jobControllerProvider =
    NotifierProvider.autoDispose.family<JobController, JobState, QuizJob>(JobController.new);
