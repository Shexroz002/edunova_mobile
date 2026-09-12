import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/utils/json_utils.dart';
import '../../session/domain/session_models.dart';
import '../domain/competition_models.dart';

/// Multiplayer sessions: create, join, lobby, invite, start, leave.
///
/// Paths (including trailing slashes) follow the live OpenAPI exactly.
class CompetitionRepository {
  CompetitionRepository(this._api);

  final ApiClient _api;

  static const _base = '/api/v1/student/sessions/multiplayer';

  /// Shortest and longest competition the client allows.
  ///
  /// The schema declares no bounds at all, so these mirror the web's rule.
  static const minMinutes = 1;
  static const maxMinutes = 180;

  /// Creates a competition and returns its lobby info.
  ///
  /// The `201` body leaves `quiz_name` and `subject_name` null, so the caller
  /// should refresh with [fetchInfo] before showing the lobby header.
  Future<SessionInfo> create({
    required int quizId,
    required int durationMinutes,
    int? maxParticipants,
  }) async {
    final data = await _api.post('$_base/create/', data: {
      'quiz_id': quizId,
      'duration_minutes': durationMinutes.clamp(minMinutes, maxMinutes),
      if (maxParticipants != null) 'max_participants': maxParticipants,
    }) as Json;
    return SessionInfo.fromJson(data);
  }

  /// Joins by code and returns the session id.
  ///
  /// The backend compares the code **case-sensitively**, so it is uppercased
  /// and stripped of spaces here rather than at every call site.
  Future<int> joinByCode(String code) async {
    final data = await _api.post(
      '$_base/join/',
      data: {'session_code': normalizeCode(code)},
    ) as Json;
    return asInt(data['id']) ?? 0;
  }

  /// Uppercases a typed join code and removes spaces.
  static String normalizeCode(String raw) => raw.replaceAll(RegExp(r'\s'), '').toUpperCase();

  /// Lobby header data (quiz name, code, status, participant id).
  Future<SessionInfo> fetchInfo(int sessionId) async {
    final data = await _api.get('$_base/$sessionId/info/') as Json;
    return SessionInfo.fromJson(data);
  }

  /// Everyone who has ever joined, including participants who left.
  Future<List<SessionParticipant>> fetchParticipants(int sessionId) async {
    final data = await _api.get(
      '$_base/$sessionId/participants/',
      query: {'page': 1, 'size': 100},
    ) as Json;
    return PageResult.fromJson(data, SessionParticipant.fromJson).items;
  }

  /// Host only: starts the session, which broadcasts `session_started`.
  Future<StartSessionResult> start(int sessionId) async {
    final data = await _api.post('$_base/$sessionId/start/') as Json;
    return StartSessionResult.fromJson(data);
  }

  /// Leaves the room. The participant is marked `disconnected`, not removed.
  Future<void> leave({required int sessionId, required int participantId}) =>
      _api.post('$_base/leave/', data: {'session_id': sessionId, 'participant_id': participantId});

  /// Sends a test invite notification. `session_code` is a required query parameter.
  Future<void> invite({
    required int sessionId,
    required String joinCode,
    required int recipientId,
  }) =>
      _api.post(
        '$_base/$sessionId/invite/',
        query: {'session_code': joinCode},
        data: {'recipient_id': recipientId},
      );

  /// Contacts that can be invited (the student's friends).
  Future<List<InvitableContact>> fetchContacts({String? search}) async {
    final data = await _api.get(
      '/api/v1/users/contact/list/',
      query: {'search': search, 'page': 1, 'size': 100},
    ) as Json;
    return PageResult.fromJson(data, InvitableContact.fromContactJson).items;
  }
}

/// Provides [CompetitionRepository].
final competitionRepositoryProvider = Provider<CompetitionRepository>(
  (ref) => CompetitionRepository(ref.watch(apiClientProvider)),
);
