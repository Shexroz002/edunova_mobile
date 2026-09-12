import '../../../core/utils/json_utils.dart';

/// The notification kinds the student app acts on.
///
/// The backend enum is wider (`friend_accepted`, `test_reminder`, …) but only
/// these three appear in live data with a payload the app can use; everything
/// else renders as a plain informational tile.
enum NotificationKind {
  competitionResult,
  testInvite,
  friendRequest,
  other;

  static NotificationKind parse(String? raw) => switch (raw?.toLowerCase().trim()) {
        'competition_result' => NotificationKind.competitionResult,
        'test_invite_notification' => NotificationKind.testInvite,
        'friend_request' => NotificationKind.friendRequest,
        _ => NotificationKind.other,
      };
}

/// Filter chips above the notification list.
enum NotificationFilter {
  all('Barchasi'),
  tests('Testlar'),
  friends("Do'stlar"),
  system('Tizim');

  const NotificationFilter(this.label);

  final String label;

  /// True when [kind] belongs in this filter.
  bool matches(NotificationKind kind) => switch (this) {
        NotificationFilter.all => true,
        NotificationFilter.tests =>
          kind == NotificationKind.competitionResult || kind == NotificationKind.testInvite,
        NotificationFilter.friends => kind == NotificationKind.friendRequest,
        NotificationFilter.system => kind == NotificationKind.other,
      };
}

/// One row of `GET /api/v1/notifications/`, or a frame pushed over
/// `/ws/notifications/{userId}`.
///
/// The pushed payload omits `is_read` and `created_at`, so a socket
/// notification is treated as unread and stamped with its arrival time.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
    this.actionType,
    this.payload = const {},
    this.senderName,
    this.senderImage,
  });

  final int id;
  final NotificationKind kind;
  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAt;
  final String? actionType;
  final Json payload;
  final String? senderName;
  final String? senderImage;

  factory AppNotification.fromJson(Json json, {DateTime? fallbackDate}) {
    final sender = json['sender'] is Map
        ? Map<String, dynamic>.from(json['sender'] as Map)
        : const <String, dynamic>{};
    final senderName = [asString(sender['first_name']), asString(sender['last_name'])]
        .whereType<String>()
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .join(' ');

    return AppNotification(
      id: asInt(json['id']) ?? 0,
      kind: NotificationKind.parse(asString(json['type'])),
      title: asString(json['title']) ?? '',
      message: asString(json['message']) ?? '',
      // Absent on socket frames: a freshly pushed notification is unread.
      isRead: json.containsKey('is_read') ? asBool(json['is_read']) : false,
      createdAt: parseUtcDate(json['created_at']) ?? fallbackDate ?? DateTime.now().toUtc(),
      actionType: asString(json['action_type']),
      payload:
          json['payload'] is Map ? Map<String, dynamic>.from(json['payload'] as Map) : const {},
      senderName: senderName.isEmpty ? null : senderName,
      senderImage: asString(sender['profile_image']),
    );
  }

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        kind: kind,
        title: title,
        message: message,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
        actionType: actionType,
        payload: payload,
        senderName: senderName,
        senderImage: senderImage,
      );

  /// Session code carried by a test invite.
  String? get sessionCode => asString(payload['session_code']);

  /// User id carried by a friend request.
  int? get friendId => asInt(payload['friend_id']);

  /// Session id carried by a competition result.
  int? get resultSessionId => asInt(payload['session_id']);

  /// Title shown on the tile. The server writes `competition_result` titles in
  /// English (`"Competition result"`), so that one is replaced with the web's
  /// fixed Uzbek heading.
  String get displayTitle =>
      kind == NotificationKind.competitionResult ? 'Musobaqa natijasi' : title;

  /// Quiz name of a competition result, used in the congratulation sentence.
  String? get quizTitle => asString(payload['quiz_title']);

  /// Finishing position of a competition result.
  int? get rank => asInt(payload['rank']);

  /// Score percentage of a competition result, when present.
  double? get scorePercent => asDouble(payload['score_percent']);

  /// Fallback body used when a competition result has no rank or quiz name.
  static const competitionFallbackMessage =
      "Musobaqa natijangiz tayyor. Natijangiz va reytingni ko'rish uchun quyidagi tugmani bosing.";

  /// Body for everything except a competition result, which the tile renders as
  /// rich text from [quizTitle] and [rank].
  String get displayMessage => kind == NotificationKind.competitionResult
      ? (quizTitle == null || rank == null ? competitionFallbackMessage : '')
      : message;

  /// `2-o'rin medali`, shown as an amber badge.
  String? get medalLabel => rank == null ? null : "$rank-o'rin medali";

  /// `5% natija`, shown next to the medal badge.
  String? get percentLabel {
    final percent = scorePercent;
    return percent == null ? null : '${percent.round()}% natija';
  }

  /// Medal shown for the first three places.
  String? get rankMedal => switch (rank) {
        1 => '🥇',
        2 => '🥈',
        3 => '🥉',
        _ => null,
      };
}
