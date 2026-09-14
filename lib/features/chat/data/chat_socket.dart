import 'dart:async';

import '../../../core/realtime/socket_service.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/message_models.dart';

/// Frame types on `/ws/chat`, mirroring the backend's `EventType`.
class ChatEventType {
  ChatEventType._();

  static const messageNew = 'message:new';
  static const messageForward = 'message:forward';
  static const messageAck = 'message:ack';
  static const messageEdited = 'message:edited';
  static const messageDeleted = 'message:deleted';
  static const messageReactionAdd = 'message:reaction_add';
  static const messageRead = 'message:read';
  static const typingUpdate = 'typing:update';
  static const presenceUpdate = 'presence:update';
  static const chatCreated = 'chat:created';
  static const chatLeaved = 'chat:leaved';
  static const heartbeat = 'heartbeat:heartbeat';
  static const error = 'error';
  static const connectionReady = 'connection:ready';
}

/// A decoded incoming frame.
sealed class ChatEvent {
  const ChatEvent();
}

/// The socket is up; [origin] identifies this connection server-side.
class ConnectionReadyEvent extends ChatEvent {
  const ConnectionReadyEvent({this.origin, this.channels = 0});

  final String? origin;
  final int channels;
}

/// A new message (or a forwarded one) arrived in [chatId].
class MessageNewEvent extends ChatEvent {
  const MessageNewEvent({required this.chatId, required this.message});

  final int chatId;
  final Message message;
}

/// The server stored a message this device sent and assigned it [messageId].
class MessageAckEvent extends ChatEvent {
  const MessageAckEvent({
    required this.chatId,
    required this.messageId,
    this.clientMessageId,
    this.createdAt,
  });

  final int chatId;
  final String messageId;

  /// Echo of the id we generated, used to reconcile the optimistic bubble.
  final String? clientMessageId;
  final DateTime? createdAt;
}

/// A message's text changed.
class MessageEditedEvent extends ChatEvent {
  const MessageEditedEvent({
    required this.chatId,
    required this.messageId,
    this.newContent,
    this.editedAt,
  });

  final int chatId;
  final String messageId;
  final String? newContent;
  final DateTime? editedAt;
}

/// A message was soft-deleted.
class MessageDeletedEvent extends ChatEvent {
  const MessageDeletedEvent({
    required this.chatId,
    required this.messageId,
    this.previewText,
    this.previewAt,
  });

  final int chatId;
  final String messageId;

  /// The chat's new last message, so the list row can follow along.
  final String? previewText;
  final DateTime? previewAt;
}

/// Someone added or removed one reaction.
class MessageReactionEvent extends ChatEvent {
  const MessageReactionEvent({
    required this.chatId,
    required this.messageId,
    required this.emoji,
    required this.added,
    required this.userId,
  });

  final int chatId;
  final String messageId;
  final String emoji;
  final bool added;
  final int userId;
}

/// A member moved their read cursor to [messageId].
class MessageReadEvent extends ChatEvent {
  const MessageReadEvent({
    required this.chatId,
    required this.messageId,
    required this.readerId,
    this.readAt,
  });

  final int chatId;
  final String messageId;
  final int readerId;
  final DateTime? readAt;
}

/// Someone is typing in [chatId].
class TypingEvent extends ChatEvent {
  const TypingEvent({required this.chatId, required this.userId});

  final int chatId;
  final int userId;
}

/// A contact came online or went away.
class PresenceEvent extends ChatEvent {
  const PresenceEvent({required this.userId, required this.online, this.lastSeenAt});

  final int userId;
  final bool online;
  final DateTime? lastSeenAt;
}

/// The server refused the last action (not a member, message gone, ...).
class ChatErrorEvent extends ChatEvent {
  const ChatErrorEvent({required this.detail, this.forEvent});

  final String detail;

  /// The client frame that was rejected, e.g. `message:new`.
  final String? forEvent;
}

/// Typed client for `/ws/chat`.
///
/// Wraps [SocketService] (auth, backoff, heartbeat) and turns raw frames into
/// [ChatEvent]s. One instance is shared by the chat list and every open room,
/// because the backend subscribes a connection to all of the user's chats.
class ChatSocket {
  ChatSocket(this._socket);

  final SocketService _socket;

  final _events = StreamController<ChatEvent>.broadcast();
  StreamSubscription<Json>? _subscription;

  /// This connection's server-side id, echoed in `connection:ready`.
  String? origin;

  /// Decoded frames.
  Stream<ChatEvent> get events => _events.stream;

  /// Connection status, for the "reconnecting" banner.
  Stream<SocketStatus> get statusChanges => _socket.statusChanges;

  SocketStatus get status => _socket.status;

  /// Connects and starts decoding.
  void start() {
    _subscription ??= _socket.messages.listen(_onFrame);
    _socket.connect();
  }

  /// Reconnects after the app returns to the foreground.
  Future<void> resume() => _socket.reconnectNow();

  // ── Outgoing ───────────────────────────────────────────────────────────

  /// Sends a message. [clientMessageId] comes back in `message:ack`.
  bool sendMessage({
    required int chatId,
    required String clientMessageId,
    String? text,
    String? replyToMessageId,
    List<MessageAttachment> attachments = const [],
    List<int> mentions = const [],
  }) =>
      _socket.send({
        'type': ChatEventType.messageNew,
        'chat_id': chatId,
        'client_message_id': clientMessageId,
        if (text != null) 'text': text,
        if (replyToMessageId != null) 'reply_to_message_id': replyToMessageId,
        'attachments': attachments.map((a) => a.toJson()).toList(),
        'mentions': mentions,
      });

  /// Opens a private chat with [targetUserId] and posts the first message in
  /// one round trip; the ack carries the new `chat_id`.
  bool createChat({
    required int targetUserId,
    required String text,
    required String clientMessageId,
  }) =>
      _socket.send({
        'type': ChatEventType.chatCreated,
        'target_user_id': targetUserId,
        'text': text,
        'client_message_id': clientMessageId,
      });

  /// Copies [originalMessageId] into [chatId].
  bool forwardMessage({
    required int chatId,
    required String originalMessageId,
    required String senderName,
    required String clientMessageId,
  }) =>
      _socket.send({
        'type': ChatEventType.messageForward,
        'chat_id': chatId,
        'original_message_id': originalMessageId,
        'sender_name': senderName,
        'client_message_id': clientMessageId,
      });

  /// Edits own message. The server derives the chat from the message itself.
  bool editMessage({required String messageId, required String newText}) => _socket.send({
        'type': ChatEventType.messageEdited,
        'message_id': messageId,
        'new_text': newText,
      });

  /// Soft-deletes own message.
  bool deleteMessage({required String messageId}) => _socket.send({
        'type': ChatEventType.messageDeleted,
        'message_id': messageId,
      });

  /// Toggles one emoji on a message.
  bool toggleReaction({required String messageId, required String emoji}) => _socket.send({
        'type': ChatEventType.messageReactionAdd,
        'message_id': messageId,
        'emoji': emoji,
      });

  /// Moves this user's read cursor to [messageId].
  bool markRead({required String messageId}) => _socket.send({
        'type': ChatEventType.messageRead,
        'message_id': messageId,
      });

  /// Tells the other members that we are typing.
  bool typing({required int chatId}) => _socket.send({
        'type': ChatEventType.typingUpdate,
        'chat_id': chatId,
      });

  /// Unsubscribes this connection from a chat we just left.
  bool leaveChat({required int chatId}) => _socket.send({
        'type': ChatEventType.chatLeaved,
        'chat_id': chatId,
      });

  // ── Incoming ───────────────────────────────────────────────────────────

  void _onFrame(Json frame) {
    final event = decodeChatFrame(frame);
    if (event == null) return;
    if (event is ConnectionReadyEvent) origin = event.origin;
    _events.add(event);
  }

  /// Closes the socket and the event stream.
  Future<void> dispose() async {
    await _subscription?.cancel();
    await _socket.close();
    await _events.close();
  }
}

/// Turns one raw frame into a [ChatEvent], or `null` when it is not one we use.
///
/// Split out of [ChatSocket] so it can be unit-tested without a socket.
ChatEvent? decodeChatFrame(Json frame) {
  final type = asString(frame['type']);
  // `chat_id` arrives as an int in most frames, but `typing:update` gets it
  // from the Redis channel name, where it is a string.
  final chatId = asInt(frame['chat_id']) ?? 0;
  final body = frame['message'] is Map
      ? Map<String, dynamic>.from(frame['message'] as Map)
      : const <String, dynamic>{};

  switch (type) {
    case ChatEventType.connectionReady:
      return ConnectionReadyEvent(
        origin: asString(frame['origin']),
        channels: asInt(frame['subscribed_channels']) ?? 0,
      );

    case ChatEventType.messageNew:
    case ChatEventType.messageForward:
      if (body.isEmpty) return null;
      return MessageNewEvent(chatId: chatId, message: _messageFromFrame(body, chatId));

    case ChatEventType.messageAck:
      final id = asString(frame['message_id']);
      if (id == null) return null;
      return MessageAckEvent(
        chatId: chatId,
        messageId: id,
        clientMessageId: asString(frame['client_message_id']),
        createdAt: parseUtcDate(frame['created_at']),
      );

    case ChatEventType.messageEdited:
      final id = asString(body['id']);
      if (id == null) return null;
      return MessageEditedEvent(
        chatId: chatId,
        messageId: id,
        newContent: asString(body['new_content']),
        editedAt: parseUtcDate(body['edited_at']),
      );

    case ChatEventType.messageDeleted:
      final id = asString(body['id']);
      if (id == null) return null;
      final preview = frame['chat_preview'] is Map
          ? Map<String, dynamic>.from(frame['chat_preview'] as Map)
          : const <String, dynamic>{};
      return MessageDeletedEvent(
        chatId: chatId,
        messageId: id,
        previewText: asString(preview['last_message_text']),
        previewAt: parseUtcDate(preview['last_message_at']),
      );

    case ChatEventType.messageReactionAdd:
      final id = asString(body['message_id']);
      final emoji = asString(body['emoji']);
      if (id == null || emoji == null) return null;
      return MessageReactionEvent(
        chatId: chatId,
        messageId: id,
        emoji: emoji,
        added: asBool(body['added'], fallback: true),
        userId: asInt(body['sender_id']) ?? 0,
      );

    case ChatEventType.messageRead:
      // Named plural, but the server publishes a single id.
      final id = asString(frame['message_ids']);
      if (id == null) return null;
      return MessageReadEvent(
        chatId: chatId,
        messageId: id,
        readerId: asInt(frame['reader_id']) ?? 0,
        readAt: parseUtcDate(frame['read_at']),
      );

    case ChatEventType.typingUpdate:
      return TypingEvent(chatId: chatId, userId: asInt(frame['sender_id']) ?? 0);

    case ChatEventType.presenceUpdate:
      final userId = asInt(frame['user_id']);
      if (userId == null) return null;
      return PresenceEvent(
        userId: userId,
        online: asString(frame['status']) == 'online',
        lastSeenAt: parseUtcDate(frame['last_seen_at']),
      );

    case ChatEventType.error:
      return ChatErrorEvent(
        detail: asString(frame['detail']) ?? 'Amal bajarilmadi',
        forEvent: asString(frame['event']),
      );

    default:
      return null;
  }
}

/// Builds a [Message] from a broadcast frame.
///
/// The socket payload is **not** the Mongo document: the text is `content` and
/// the id is `message_id`, so `Message.fromJson` cannot be used here.
Message _messageFromFrame(Json body, int chatId) {
  final attachments = asJsonList(body['attachments']).map(MessageAttachment.fromJson).toList();
  return Message(
    id: asString(body['message_id']) ?? asString(body['id']) ?? '',
    chatId: chatId,
    senderId: asInt(body['sender_id']) ?? 0,
    senderName: asString(body['sender_name']),
    text: asString(body['content']),
    replyToMessageId: asString(body['reply_to_message_id']),
    forwardedFrom: ForwardedFrom.tryParse(body['forwarded_from']),
    attachments: attachments,
    mentions: (body['mentions'] is List)
        ? (body['mentions'] as List).map(asInt).whereType<int>().toList()
        : const [],
    createdAt: parseUtcDate(body['created_at']) ?? DateTime.now(),
  );
}
