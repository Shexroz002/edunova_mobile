import '../../../core/utils/json_utils.dart';

/// Chat kind as the backend spells it (`ChatType` in `app/models/chat/chats.py`).
enum ChatKind {
  private,
  group,
  channel;

  /// Reads both spellings: `GET /chats` lower-cases it, `ChatResponse` does not.
  static ChatKind parse(String? raw) => switch (raw?.toLowerCase()) {
        'group' => ChatKind.group,
        'channel' => ChatKind.channel,
        _ => ChatKind.private,
      };

  bool get isGroup => this != ChatKind.private;
}

/// Last message preview carried by a `GET /chats` row.
///
/// `id` is always `null` today: the server caches the text on `chats` but not
/// the Mongo id (see `docs/BACKEND_ISSUES.md`), so it cannot be used to jump.
class LastMessagePreview {
  const LastMessagePreview({
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.id,
    this.senderName,
  });

  final String? id;
  final int senderId;
  final String? senderName;
  final String text;
  final DateTime? createdAt;

  factory LastMessagePreview.fromJson(Json json) => LastMessagePreview(
        id: asString(json['id']),
        senderId: asInt(json['sender_id']) ?? 0,
        senderName: asString(json['sender_name']),
        text: asString(json['text']) ?? '',
        createdAt: parseUtcDate(json['created_at']),
      );
}

/// One row of `GET /chats`.
class ChatListItem {
  const ChatListItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.unreadCount,
    this.avatar,
    this.isOnline,
    this.lastSeen,
    this.lastMessage,
    this.updatedAt,
  });

  final int id;
  final ChatKind kind;
  final String title;
  final String? avatar;

  /// Only private chats carry presence; it is the *other* member's.
  final bool? isOnline;
  final DateTime? lastSeen;

  final LastMessagePreview? lastMessage;
  final int unreadCount;
  final DateTime? updatedAt;

  /// Sort key: newest activity first, chats without any message last.
  DateTime get sortedAt =>
      updatedAt ?? lastMessage?.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  factory ChatListItem.fromJson(Json json) {
    final last = json['last_message'];
    return ChatListItem(
      id: asInt(json['id']) ?? 0,
      kind: ChatKind.parse(asString(json['type'])),
      title: asString(json['title']) ?? '',
      avatar: asString(json['avatar']),
      isOnline: json['is_online'] is bool ? json['is_online'] as bool : null,
      lastSeen: parseUtcDate(json['last_seen']),
      lastMessage: last is Map
          ? LastMessagePreview.fromJson(Map<String, dynamic>.from(last))
          : null,
      unreadCount: asInt(json['unread_count']) ?? 0,
      updatedAt: parseUtcDate(json['updated_at']),
    );
  }

  ChatListItem copyWith({
    String? title,
    bool? isOnline,
    DateTime? lastSeen,
    LastMessagePreview? lastMessage,
    int? unreadCount,
    DateTime? updatedAt,
  }) =>
      ChatListItem(
        id: id,
        kind: kind,
        title: title ?? this.title,
        avatar: avatar,
        isOnline: isOnline ?? this.isOnline,
        lastSeen: lastSeen ?? this.lastSeen,
        lastMessage: lastMessage ?? this.lastMessage,
        unreadCount: unreadCount ?? this.unreadCount,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

/// A chat as returned by `POST /chats/private`, `POST /chats/group` and
/// `GET /chats/my` (the backend's `ChatResponse`).
class ChatSummary {
  const ChatSummary({
    required this.id,
    required this.name,
    required this.kind,
    required this.ownerId,
    this.description,
    this.avatarUrl,
    this.lastMessageText,
    this.lastMessageCreatedAt,
  });

  final int id;
  final String name;
  final ChatKind kind;
  final int ownerId;
  final String? description;
  final String? avatarUrl;
  final String? lastMessageText;
  final DateTime? lastMessageCreatedAt;

  factory ChatSummary.fromJson(Json json) => ChatSummary(
        id: asInt(json['id']) ?? 0,
        name: asString(json['name']) ?? '',
        kind: ChatKind.parse(asString(json['chat_type']) ?? asString(json['type'])),
        ownerId: asInt(json['owner_id']) ?? 0,
        description: asString(json['description']),
        avatarUrl: asString(json['avatar_url']),
        lastMessageText: asString(json['last_message_text']),
        lastMessageCreatedAt: parseUtcDate(json['last_message_created_at']),
      );
}

/// One member row inside `GET /chats/{id}`.
class ChatMember {
  const ChatMember({
    required this.userId,
    required this.username,
    required this.role,
    required this.isOnline,
    this.firstName,
    this.lastName,
    this.profileImage,
    this.lastReadMessageId,
    this.joinedAt,
  });

  final int userId;
  final String username;
  final String? firstName;
  final String? lastName;
  final String? profileImage;

  /// The member's read cursor (a Mongo message id), used for read receipts.
  final String? lastReadMessageId;
  final String role;
  final DateTime? joinedAt;
  final bool isOnline;

  bool get isAdmin => role.toLowerCase() == 'admin';

  /// Falls back to the username when both name fields are blank.
  String get fullName {
    final name = '${firstName ?? ''} ${lastName ?? ''}'.trim();
    return name.isEmpty ? username : name;
  }

  factory ChatMember.fromJson(Json json) => ChatMember(
        userId: asInt(json['user_id']) ?? 0,
        username: asString(json['username']) ?? '',
        firstName: asString(json['first_name']),
        lastName: asString(json['last_name']),
        profileImage: asString(json['profile_image']),
        lastReadMessageId: asString(json['last_read_message_id']),
        role: asString(json['role']) ?? 'member',
        joinedAt: parseUtcDate(json['joined_at']),
        isOnline: asBool(json['is_online']),
      );
}

/// `GET /chats/{id}` — chat metadata plus every member.
class ChatDetail {
  const ChatDetail({
    required this.id,
    required this.name,
    required this.kind,
    required this.ownerId,
    required this.membersCount,
    required this.members,
    this.description,
    this.avatarUrl,
    this.directKey,
  });

  final int id;
  final String name;
  final ChatKind kind;
  final int ownerId;
  final String? description;
  final String? avatarUrl;
  final String? directKey;
  final int membersCount;
  final List<ChatMember> members;

  /// The other participant of a private chat, or `null` for a group.
  ChatMember? otherMember(int currentUserId) {
    if (kind.isGroup) return null;
    for (final member in members) {
      if (member.userId != currentUserId) return member;
    }
    return null;
  }

  /// Title to show: a group keeps its name, a private chat shows the peer.
  String titleFor(int currentUserId) {
    if (kind.isGroup) return name;
    return otherMember(currentUserId)?.fullName ?? name;
  }

  factory ChatDetail.fromJson(Json json) => ChatDetail(
        id: asInt(json['id']) ?? 0,
        name: asString(json['name']) ?? '',
        kind: ChatKind.parse(asString(json['type'])),
        ownerId: asInt(json['owner_id']) ?? 0,
        description: asString(json['description']),
        avatarUrl: asString(json['avatar_url']),
        directKey: asString(json['direct_key']),
        membersCount: asInt(json['members_count']) ?? 0,
        members: asJsonList(json['members']).map(ChatMember.fromJson).toList(),
      );
}
