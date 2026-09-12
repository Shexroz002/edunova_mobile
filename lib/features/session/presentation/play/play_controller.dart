import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/realtime/socket_service.dart';
import '../../../tests/domain/quiz.dart';
import '../../data/session_repository.dart';
import '../../domain/session_models.dart';

/// State and logic of the play (test-taking) screen.
///
/// * Loads session info + questions, restores saved progress.
/// * Counts down to the deadline and auto-submits at zero.
/// * Multiplayer: reports answers / navigation and listens for
///   `session_finished` on the session room socket.
/// * Persists answers after every change so an app restart loses nothing.
class PlayController extends ChangeNotifier {
  PlayController({
    required this.sessionId,
    required SessionRepository repository,
    required SharedPreferences prefs,
    required SocketFactory sockets,
    DateTime Function()? clock,
  })  : _repository = repository,
        _prefs = prefs,
        _sockets = sockets,
        _now = clock ?? DateTime.now;

  final int sessionId;
  final SessionRepository _repository;
  final SharedPreferences _prefs;
  final SocketFactory _sockets;
  final DateTime Function() _now;

  // ── State ────────────────────────────────────────────────────────────────
  bool loading = true;
  String? loadError;
  SessionInfo? info;
  List<QuestionContent> questions = const [];
  final Map<int, String> answers = {};
  int index = 0;
  DateTime? deadline;
  Duration remaining = Duration.zero;
  bool submitting = false;
  String? submitError;
  FinishResult? result;

  /// True after the host ended the session (answers are being submitted).
  bool finishedByHost = false;

  Timer? _ticker;
  Timer? _retryTimer;
  SocketService? _socket;
  StreamSubscription<Map<String, dynamic>>? _socketSubscription;
  bool _disposed = false;

  String get _storageKey => 'play_progress_$sessionId';

  /// Question on screen, or null before loading.
  QuestionContent? get current => questions.isEmpty ? null : questions[index];

  /// Number of answered questions.
  int get answeredCount => answers.length;

  /// Number of questions in the session.
  int get total => questions.length;

  /// Public/group sessions sync answers and navigation for live monitoring.
  bool get isMultiplayer => info?.type.isMultiplayer ?? false;

  /// False when the session has no deadline (no countdown shown).
  bool get hasTimer => deadline != null;

  /// True on the last question (shows the finish button).
  bool get isLast => index >= questions.length - 1;

  /// Selected label for [question], if any.
  String? answerOf(QuestionContent question) => answers[question.id];

  // ── Lifecycle ────────────────────────────────────────────────────────────

  /// Loads everything needed to play; safe to call again after an error.
  Future<void> load() async {
    loading = true;
    loadError = null;
    _notify();
    try {
      final results = await Future.wait<Object>([
        _repository.fetchInfo(sessionId),
        _repository.fetchQuestions(sessionId),
      ]);
      final sessionInfo = results[0] as SessionInfo;
      final data = results[1] as SessionQuestions;

      info = sessionInfo;
      questions = data.questions;
      deadline = data.deadlineAt ??
          sessionInfo.deadlineAt ??
          _deadlineFrom(data.startedAt ?? sessionInfo.startedAt, sessionInfo.durationMinutes);
      _restoreProgress();
      loading = false;
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
      _tick(); // also auto-submits right away if time is already up
      _notify();

      if (isMultiplayer) {
        _connectRoom();
        _reportOrder();
      }
    } catch (e) {
      loading = false;
      loadError = ApiException.from(e).message;
      _notify();
    }
  }

  /// Call when the app returns to the foreground.
  void onResume() {
    _tick();
    _socket?.reconnectNow();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _retryTimer?.cancel();
    _socketSubscription?.cancel();
    _socket?.close();
    super.dispose();
  }

  // ── User actions ─────────────────────────────────────────────────────────

  /// Selects [label] for the current question.
  void select(String label) {
    final question = current;
    if (question == null || result != null || submitting) return;
    answers[question.id] = label;
    _saveProgress();
    _notify();
    if (isMultiplayer) {
      _quietly(() =>
          _repository.reportAnswer(sessionId: sessionId, questionId: question.id, label: label));
    }
  }

  /// Moves to question [target] (0-based).
  void goTo(int target) {
    if (target < 0 || target >= questions.length || target == index) return;
    index = target;
    _saveProgress();
    _notify();
    if (isMultiplayer) _reportOrder();
  }

  /// Moves to the next question.
  void next() => goTo(index + 1);

  /// Moves to the previous question.
  void previous() => goTo(index - 1);

  /// Sends all answers and scores the attempt. Safe to call repeatedly.
  Future<void> submit({bool automatic = false}) async {
    if (submitting || result != null) return;
    submitting = true;
    submitError = null;
    _notify();
    try {
      result = await _repository.finish(sessionId: sessionId, answers: Map.of(answers));
      _ticker?.cancel();
      await _prefs.remove(_storageKey);
    } catch (e) {
      submitError = ApiException.from(e).message;
      // Time is up or the host finished: keep retrying in the background.
      if (automatic) {
        _retryTimer?.cancel();
        _retryTimer = Timer(const Duration(seconds: 5), () => submit(automatic: true));
      }
    } finally {
      submitting = false;
      _notify();
    }
  }

  // ── Internals ────────────────────────────────────────────────────────────

  DateTime? _deadlineFrom(DateTime? startedAt, int minutes) =>
      startedAt == null || minutes <= 0 ? null : startedAt.add(Duration(minutes: minutes));

  void _tick() {
    final end = deadline;
    if (end == null || result != null) return;
    final left = end.difference(_now());
    remaining = left.isNegative ? Duration.zero : left;
    if (remaining == Duration.zero && !submitting) {
      _ticker?.cancel();
      submit(automatic: true);
    }
    _notify();
  }

  void _connectRoom() {
    final socket =
        _sockets.create('/ws/quiz/sessions/$sessionId', heartbeat: const {'event': 'ping'});
    _socket = socket;
    _socketSubscription = socket.messages.listen((message) {
      if (message['event'] == 'session_finished' && result == null) {
        finishedByHost = true;
        _notify();
        Future<void>.delayed(const Duration(milliseconds: 1600), () {
          if (!_disposed) submit(automatic: true);
        });
      }
    });
    socket.connect();
  }

  void _reportOrder() {
    final participantId = info?.currentParticipantId;
    if (participantId == null) return;
    _quietly(() => _repository.reportQuestionOrder(
          sessionId: sessionId,
          participantId: participantId,
          order: index + 1,
        ));
  }

  void _restoreProgress() {
    final raw = _prefs.getString(_storageKey);
    if (raw == null) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final validIds = questions.map((q) => q.id).toSet();
      final saved = (data['answers'] as Map<String, dynamic>? ?? const {});
      for (final entry in saved.entries) {
        final id = int.tryParse(entry.key);
        if (id != null && validIds.contains(id) && entry.value is String) {
          answers[id] = entry.value as String;
        }
      }
      final savedIndex = data['index'];
      if (savedIndex is int && savedIndex >= 0 && savedIndex < questions.length) index = savedIndex;
    } catch (_) {
      _prefs.remove(_storageKey);
    }
  }

  void _saveProgress() {
    final data = {
      'answers': {for (final entry in answers.entries) '${entry.key}': entry.value},
      'index': index,
    };
    _prefs.setString(_storageKey, jsonEncode(data));
  }

  void _quietly(Future<void> Function() action) {
    action().catchError((Object error) {
      debugPrint('Live sync failed: $error');
    });
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}
