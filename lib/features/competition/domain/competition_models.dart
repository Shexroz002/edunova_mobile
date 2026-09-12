import '../../../core/utils/json_utils.dart';

/// Live state of a participant in a session room.
///
/// The backend never deletes a participant: leaving only flips the status to
/// `disconnected` and the row stays in `participants/`, so the lobby has to
/// separate "still here" from "left" itself.
enum ParticipantStatus {
  joined,
  ready,
  disconnected,
  finished;

  /// Unknown spellings fall back to [joined].
  static ParticipantStatus parse(String? raw) => switch (raw?.toLowerCase().trim()) {
        'ready' => ParticipantStatus.ready,
        'disconnected' => ParticipantStatus.disconnected,
        'finished' => ParticipantStatus.finished,
        _ => ParticipantStatus.joined,
      };

  /// True while the participant still counts towards the room.
  bool get isPresent => this != ParticipantStatus.disconnected;

  /// Uzbek label shown on the participant tile.
  String get label => switch (this) {
        ParticipantStatus.ready => 'Tayyor',
        ParticipantStatus.disconnected => 'Chiqib ketdi',
        ParticipantStatus.finished => 'Yakunladi',
        ParticipantStatus.joined => 'Kutilmoqda',
      };
}

/// One row of `GET /student/sessions/multiplayer/{id}/participants/`.
class SessionParticipant {
  const SessionParticipant({
    required this.participantId,
    required this.userId,
    required this.nickname,
    required this.isHost,
    required this.status,
    this.firstName,
    this.lastName,
    this.profileImage,
    this.joinedAt,
  });

  final int participantId;
  final int userId;
  final String nickname;
  final bool isHost;
  final ParticipantStatus status;
  final String? firstName;
  final String? lastName;
  final String? profileImage;

  /// Arrives without an offset (`2026-09-11T16:38:41.167808`) and is UTC.
  final DateTime? joinedAt;

  /// Full name, falling back to the nickname when the name is missing.
  String get displayName {
    final name = [firstName, lastName]
        .whereType<String>()
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .join(' ');
    return name.isEmpty ? nickname : name;
  }

  factory SessionParticipant.fromJson(Json json) => SessionParticipant(
        participantId: asInt(json['participant_id']) ?? 0,
        userId: asInt(json['user_id']) ?? 0,
        nickname: asString(json['nickname']) ?? '',
        isHost: asBool(json['is_host']),
        status: ParticipantStatus.parse(asString(json['participant_status'])),
        firstName: asString(json['first_name']),
        lastName: asString(json['last_name']),
        profileImage: asString(json['profile_image']),
        joinedAt: parseUtcDate(json['joined_at']),
      );

  /// Builds a participant from a `participant_joined` socket payload.
  factory SessionParticipant.fromJoinedEvent(Json data) => SessionParticipant(
        participantId: asInt(data['participant_id']) ?? 0,
        userId: asInt(data['user_id']) ?? 0,
        nickname: asString(data['nickname']) ?? '',
        isHost: asBool(data['is_host']),
        status: ParticipantStatus.parse(asString(data['status'])),
        firstName: asString(data['first_name']),
        lastName: asString(data['last_name']),
        profileImage: asString(data['profile_image']),
        joinedAt: parseUtcDate(data['joined_at']),
      );

  SessionParticipant copyWith({ParticipantStatus? status}) => SessionParticipant(
        participantId: participantId,
        userId: userId,
        nickname: nickname,
        isHost: isHost,
        status: status ?? this.status,
        firstName: firstName,
        lastName: lastName,
        profileImage: profileImage,
        joinedAt: joinedAt,
      );
}

/// Events the room socket `/ws/quiz/sessions/{id}` sends to a participant.
///
/// The backend's own spelling is inconsistent, so both `participant_ready`
/// (what the source broadcasts) and `participant_read` (what an earlier live
/// capture recorded) map to [participantReady].
enum RoomEvent {
  participantJoined,
  participantReady,
  participantReconnected,
  participantDisconnected,
  sessionStarted,
  sessionFinished,
  unknown;

  static RoomEvent parse(String? raw) => switch (raw) {
        'participant_joined' => RoomEvent.participantJoined,
        'participant_ready' || 'participant_read' => RoomEvent.participantReady,
        'participant_reconnected' => RoomEvent.participantReconnected,
        'participant_disconnected' => RoomEvent.participantDisconnected,
        'session_started' => RoomEvent.sessionStarted,
        'session_finished' => RoomEvent.sessionFinished,
        _ => RoomEvent.unknown,
      };
}

/// Result of `POST /student/sessions/multiplayer/{id}/start/`.
class StartSessionResult {
  const StartSessionResult({
    required this.sessionId,
    required this.status,
    required this.participantsCount,
    this.startedAt,
    this.deadlineAt,
  });

  final int sessionId;
  final String status;
  final int participantsCount;
  final DateTime? startedAt;
  final DateTime? deadlineAt;

  factory StartSessionResult.fromJson(Json json) => StartSessionResult(
        sessionId: asInt(json['id']) ?? 0,
        status: asString(json['status']) ?? '',
        participantsCount: asInt(json['participants_count']) ?? 0,
        startedAt: parseUtcDate(json['started_at']),
        deadlineAt: parseUtcDate(json['deadline_at']),
      );
}

/// A contact that can be invited to a session.
class InvitableContact {
  const InvitableContact({
    required this.userId,
    required this.username,
    required this.fullName,
    this.profileImage,
  });

  final int userId;
  final String username;
  final String fullName;
  final String? profileImage;

  /// Parses a row of `GET /users/contact/list/` (`{id, friend: {...}}`).
  factory InvitableContact.fromContactJson(Json json) {
    final friend = json['friend'] is Map ? Map<String, dynamic>.from(json['friend'] as Map) : json;
    final name = [asString(friend['first_name']), asString(friend['last_name'])]
        .whereType<String>()
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .join(' ');
    final username = asString(friend['username']) ?? '';
    return InvitableContact(
      userId: asInt(friend['id']) ?? 0,
      username: username,
      fullName: name.isEmpty ? username : name,
      profileImage: asString(friend['profile_image']),
    );
  }
}
