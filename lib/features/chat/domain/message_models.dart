import '../../../core/utils/json_utils.dart';

/// Attachment kinds the backend actually stores (verified against the live
/// `messages` collection), plus [other] for anything new.
enum AttachmentKind {
  image,
  video,
  voice,
  videoMessage,
  audio,
  pdf,
  file,
  other;

  static AttachmentKind parse(String? raw) => switch (raw?.toLowerCase()) {
        'image' => AttachmentKind.image,
        'video' => AttachmentKind.video,
        'voice' => AttachmentKind.voice,
        'video_message' => AttachmentKind.videoMessage,
        'audio' => AttachmentKind.audio,
        'pdf' => AttachmentKind.pdf,
        'file' => AttachmentKind.file,
        _ => AttachmentKind.other,
      };

  /// Rendered as a framed thumbnail rather than a file row.
  bool get isVisual =>
      this == AttachmentKind.image ||
      this == AttachmentKind.video ||
      this == AttachmentKind.videoMessage;

  /// Played inline with a waveform.
  bool get isAudio => this == AttachmentKind.voice || this == AttachmentKind.audio;
}

/// One entry of a message's `attachments` array.
///
/// The shape is what the web client writes, **not** the unused `Attachment`
/// pydantic schema: `{type, file_id, file_name, file_url, mime_type, size}`.
class MessageAttachment {
  const MessageAttachment({
    required this.kind,
    required this.fileName,
    required this.fileUrl,
    this.fileId,
    this.mimeType,
    this.size,
  });

  final AttachmentKind kind;
  final String? fileId;
  final String fileName;
  final String fileUrl;
  final String? mimeType;
  final int? size;

  /// Human size, e.g. `1,8 MB`. Empty when the server did not send one.
  String get readableSize {
    final bytes = size;
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} MB';
  }

  factory MessageAttachment.fromJson(Json json) => MessageAttachment(
        kind: AttachmentKind.parse(asString(json['type'])),
        fileId: asString(json['file_id']),
        fileName: asString(json['file_name']) ?? 'Fayl',
        fileUrl: asString(json['file_url']) ?? '',
        mimeType: asString(json['mime_type']),
        size: asInt(json['size']),
      );

  Json toJson() => {
        'type': kind.name == 'videoMessage' ? 'video_message' : kind.name,
        if (fileId != null) 'file_id': fileId,
        'file_name': fileName,
        'file_url': fileUrl,
        if (mimeType != null) 'mime_type': mimeType,
        if (size != null) 'size': size,
      };
}

/// One emoji and everyone who reacted with it: `{emoji, user_ids}`.
class MessageReaction {
  const MessageReaction({required this.emoji, required this.userIds});

  final String emoji;
  final List<int> userIds;

  int get count => userIds.length;

  bool reactedBy(int userId) => userIds.contains(userId);

  factory MessageReaction.fromJson(Json json) => MessageReaction(
        emoji: asString(json['emoji']) ?? '',
        userIds: (json['user_ids'] is List)
            ? (json['user_ids'] as List).map(asInt).whereType<int>().toList()
            : const [],
      );

  /// Applies a `message:reaction_add` frame, which only says added/removed.
  MessageReaction toggled(int userId, {required bool added}) {
    final ids = [...userIds];
    if (added) {
      if (!ids.contains(userId)) ids.add(userId);
    } else {
      ids.remove(userId);
    }
    return MessageReaction(emoji: emoji, userIds: ids);
  }
}

/// Where a forwarded message came from.
///
/// Tolerant on purpose: normal messages carry `""` here, not `null`.
class ForwardedFrom {
  const ForwardedFrom({this.senderName, this.senderId, this.chatId, this.originalCreatedAt});

  final String? senderName;
  final int? senderId;
  final int? chatId;
  final DateTime? originalCreatedAt;

  String get label => senderName?.trim().isNotEmpty == true ? senderName!.trim() : 'Noma\'lum';

  static ForwardedFrom? tryParse(dynamic value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    if (json.isEmpty) return null;
    return ForwardedFrom(
      senderName: asString(json['sender_name']),
      senderId: asInt(json['sender_id']),
      chatId: asInt(json['chat_id']),
      originalCreatedAt: parseUtcDate(json['original_created_at']),
    );
  }
}

/// The `reply_message` lookup the history pipeline adds: `{sender_id, text}`.
class ReplyPreview {
  const ReplyPreview({required this.senderId, required this.text});

  final int senderId;
  final String text;

  static ReplyPreview? tryParse(dynamic value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    if (json.isEmpty) return null;
    return ReplyPreview(
      senderId: asInt(json['sender_id']) ?? 0,
      text: asString(json['text']) ?? '',
    );
  }
}

/// Delivery state of a message this device sent.
///
/// The socket suppresses the sender's own echo, so [sent] comes from the
/// `message:ack` frame and [read] from a peer's `message:read`.
enum DeliveryState { pending, sent, read, failed }

/// A chat message document.
class Message {
  const Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.createdAt,
    this.text,
    this.replyToMessageId,
    this.replyPreview,
    this.forwardedFrom,
    this.attachments = const [],
    this.reactions = const [],
    this.mentions = const [],
    this.viewsCount = 0,
    this.edited = false,
    this.deleted = false,
    this.editedAt,
    this.deliveryState,
    this.clientMessageId,
    this.senderName,
  });

  /// Mongo `_id`. For a not-yet-acknowledged message this is the local
  /// [clientMessageId] so the bubble has a stable key.
  final String id;
  final int chatId;
  final int senderId;
  final String? senderName;
  final String? text;
  final String? replyToMessageId;
  final ReplyPreview? replyPreview;
  final ForwardedFrom? forwardedFrom;
  final List<MessageAttachment> attachments;
  final List<MessageReaction> reactions;
  final List<int> mentions;
  final int viewsCount;
  final bool edited;
  final bool deleted;
  final DateTime createdAt;
  final DateTime? editedAt;

  /// Set only on messages this device sent.
  final DeliveryState? deliveryState;
  final String? clientMessageId;

  bool get hasText => text?.trim().isNotEmpty == true;

  bool get isPending => deliveryState == DeliveryState.pending;

  /// True while the bubble still shows the optimistic local id.
  bool get isLocal => clientMessageId != null && clientMessageId == id;

  factory Message.fromJson(Json json) {
    final id = asString(json['_id']) ?? asString(json['id']) ?? '';
    return Message(
      id: id,
      chatId: asInt(json['chat_id']) ?? 0,
      senderId: asInt(json['sender_id']) ?? 0,
      senderName: asString(json['sender_name']),
      text: asString(json['text']),
      replyToMessageId: asString(json['reply_to_message_id']),
      replyPreview: ReplyPreview.tryParse(json['reply_message']),
      forwardedFrom: ForwardedFrom.tryParse(json['forwarded_from']),
      attachments: asJsonList(json['attachments']).map(MessageAttachment.fromJson).toList(),
      reactions: asJsonList(json['reactions']).map(MessageReaction.fromJson).toList(),
      mentions: (json['mentions'] is List)
          ? (json['mentions'] as List).map(asInt).whereType<int>().toList()
          : const [],
      viewsCount: asInt(json['views_count']) ?? 0,
      edited: asBool(json['edited']),
      deleted: asBool(json['deleted']),
      createdAt: parseUtcDate(json['created_at']) ?? DateTime.now(),
      editedAt: parseUtcDate(json['edited_at']),
    );
  }

  Message copyWith({
    String? id,
    String? text,
    bool? edited,
    bool? deleted,
    DateTime? editedAt,
    List<MessageReaction>? reactions,
    DeliveryState? deliveryState,
    int? viewsCount,
  }) =>
      Message(
        id: id ?? this.id,
        chatId: chatId,
        senderId: senderId,
        senderName: senderName,
        text: text ?? this.text,
        replyToMessageId: replyToMessageId,
        replyPreview: replyPreview,
        forwardedFrom: forwardedFrom,
        attachments: attachments,
        reactions: reactions ?? this.reactions,
        mentions: mentions,
        viewsCount: viewsCount ?? this.viewsCount,
        edited: edited ?? this.edited,
        deleted: deleted ?? this.deleted,
        createdAt: createdAt,
        editedAt: editedAt ?? this.editedAt,
        deliveryState: deliveryState ?? this.deliveryState,
        clientMessageId: clientMessageId,
      );
}
