import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/session_models.dart';

/// Quiz sessions: start, play, finish, review, history, leaderboard.
///
/// Paths (including trailing slashes) follow the live OpenAPI exactly.
/// What `start-single-player` gave back.
class StartedSession {
  const StartedSession({required this.sessionId, required this.resumed});

  final int sessionId;

  /// The student already had this quiz open, so this is that session rather
  /// than a new one — and for a timed test the clock is where they left it,
  /// not back at the full duration they may have just picked.
  final bool resumed;
}

class SessionRepository {
  SessionRepository(this._api);

  final ApiClient _api;

  static const _base = '/api/v1/student/sessions';

  /// Starts a single-player session; returns the new session id.
  ///
  /// A null [minutes] starts it with no time limit: the server sets no
  /// deadline, nothing closes the session behind the student, and they can
  /// come back to it whenever they like. Omitting the parameter is what tells
  /// the server that — sending a number, any number, is a timed test.
  ///
  /// If the student already has this quiz open, the server hands that session
  /// back instead of starting a new one, so a timed test cannot be restarted
  /// for a fresh clock.
  Future<StartedSession> startSinglePlayer({required int quizId, int? minutes}) async {
    final data = await _api.post(
      '$_base/$quizId/start-single-player/',
      query: {if (minutes != null) 'duration_minute': minutes},
    ) as Json;
    return StartedSession(
      sessionId: asInt(data['session_id']) ?? 0,
      resumed: asBool(data['resumed']),
    );
  }

  /// Answers already stored for an unfinished session.
  ///
  /// The play screen keeps its own copy on the device; this is what makes a
  /// test resumable on a second phone, or after the app is reinstalled.
  Future<Map<int, String>> fetchSavedAnswers(int sessionId) async {
    final data = await _api.get('$_base/$sessionId/my-answers/');
    return {
      for (final row in asJsonList(data))
        if (asInt(row['question_id']) case final id?)
          if (asString(row['selected_option']) case final label?) id: label,
    };
  }

  /// Stores one answer as it is given, for any session type.
  Future<void> saveAnswer({
    required int sessionId,
    required int questionId,
    required String label,
  }) =>
      _api.post(
        '$_base/$sessionId/answer',
        data: {'question_id': questionId, 'selected_option': label},
      );

  /// Session info (works for single and multiplayer sessions).
  Future<SessionInfo> fetchInfo(int sessionId) async {
    final data = await _api.get('$_base/multiplayer/$sessionId/info/') as Json;
    return SessionInfo.fromJson(data);
  }

  /// Ordered questions with options (without correct answers).
  Future<SessionQuestions> fetchQuestions(int sessionId) async {
    final data = await _api.get('$_base/multiplayer/$sessionId/questions/') as Json;
    return SessionQuestions.fromJson(data);
  }

  /// Multiplayer only: reports the question the participant is looking at (1-based).
  Future<void> reportQuestionOrder({
    required int sessionId,
    required int participantId,
    required int order,
  }) =>
      _api.post(
        '$_base/multiplayer/$sessionId/change/question/order',
        data: {'question_order_id': order, 'participant_id': participantId},
      );

  /// Saves all answers and scores the attempt (single AND multiplayer).
  ///
  /// [answers] maps question id → option label. Safe to retry.
  Future<FinishResult> finish({required int sessionId, required Map<int, String> answers}) async {
    final body = [
      for (final entry in answers.entries)
        {'question_id': entry.key, 'selected_option': entry.value},
    ];
    final data = await _api.post('$_base/$sessionId/finish-single-player/', data: body) as Json;
    return FinishResult.fromJson(data);
  }

  /// Per-question review with the correct option and the student's choice.
  Future<List<ReviewItem>> fetchReview(int sessionId) async {
    final data = await _api.get('$_base/$sessionId/single-player-error-analysis/');
    final items = asJsonList(data).map(ReviewItem.fromJson).toList()
      ..sort((a, b) => a.question.id.compareTo(b.question.id));
    return items;
  }

  /// One page of the student's session history (newest first).
  Future<PageResult<HistoryItem>> fetchHistory(
      {String? search, int page = 1, int size = 50}) async {
    final data = await _api.get(
      '$_base/me/history/',
      query: {'search': search, 'page': page, 'size': size},
    ) as Json;
    return PageResult.fromJson(data, HistoryItem.fromJson);
  }

  /// All history rows (follows pages, capped at [maxItems]).
  Future<List<HistoryItem>> fetchAllHistory({int maxItems = 500}) async {
    final items = <HistoryItem>[];
    var page = 1;
    while (items.length < maxItems) {
      final result = await fetchHistory(page: page, size: 100);
      items.addAll(result.items);
      if (!result.hasMore || result.items.isEmpty) break;
      page++;
    }
    return items;
  }

  /// Session leaderboard, ranked on the client (the API has no rank field).
  Future<List<LeaderboardEntry>> fetchLeaderboard(int sessionId) async {
    final data =
        await _api.get('$_base/$sessionId/leaderboard/', query: {'page': 1, 'size': 100}) as Json;
    final page = PageResult.fromJson(data, LeaderboardEntry.fromJson);
    return LeaderboardEntry.ranked(page.items);
  }
}

/// Provides [SessionRepository].
final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepository(ref.watch(apiClientProvider)),
);
