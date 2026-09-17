import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../data/chat_repository.dart';
import '../data/chat_socket.dart';
import '../domain/chat_models.dart';
import '../domain/message_models.dart';
import 'chat_list_controller.dart';
import 'chat_providers.dart';

const _pageSize = 40;
const _typingLinger = Duration(seconds: 4);

/// Everything one open chat room renders.
class ChatRoomState {
  const ChatRoomState({
    this.detail,
    this.messages = const [],
    this.hasMore = true,
    this.loadingMore = false,
    this.typingUserIds = const {},
    this.replyTo,
    this.editing,
  });

  final ChatDetail? detail;

  /// Oldest first, the order the list renders in.
  final List<Message> messages;
  final bool hasMore;
  final bool loadingMore;
  final Set<int> typingUserIds;

  /// Message the composer is replying to.
  final Message? replyTo;

  /// Message the composer is editing.
  final Message? editing;

  ChatRoomState copyWith({
    ChatDetail? detail,
    List<Message>? messages,
    bool? hasMore,
    bool? loadingMore,
    Set<int>? typingUserIds,
    Message? replyTo,
    Message? editing,
    bool clearReplyTo = false,
    bool clearEditing = false,
  }) =>
      ChatRoomState(
        detail: detail ?? this.detail,
        messages: messages ?? this.messages,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
        typingUserIds: typingUserIds ?? this.typingUserIds,
        replyTo: clearReplyTo ? null : (replyTo ?? this.replyTo),
        editing: clearEditing ? null : (editing ?? this.editing),
      );
}

/// One chat room: history over HTTP, everything live over `/ws/chat`.
class ChatRoomController extends FamilyAsyncNotifier<ChatRoomState, int> {
  StreamSubscription<ChatEvent>? _subscription;
  final _typingTimers = <int, Timer>{};
  Timer? _typingThrottle;
  int _counter = 0;

  /// Ids we have already reported as read, so scrolling does not re-send them.
  final _reported = <String>{};

  int get _chatId => arg;

  int? get _me => ref.read(authControllerProvider).user?.id;

  @override
  Future<ChatRoomState> build(int arg) async {
    final socket = ref.watch(chatSocketProvider);
    if (socket != null) _subscription = socket.events.listen(_onEvent);

    ref.onDispose(() {
      _subscription?.cancel();
      _typingThrottle?.cancel();
      for (final timer in _typingTimers.values) {
        timer.cancel();
      }
      _typingTimers.clear();
    });

    final repo = ref.read(chatRepositoryProvider);
    final detail = await repo.fetchChatDetail(arg);
    final messages = await repo.fetchHistory(arg, limit: _pageSize);

    // Seed presence from the snapshot so the header is right before any frame.
    final presence = ref.read(presenceProvider.notifier);
    for (final member in detail.members) {
      presence.seed(member.userId, online: member.isOnline);
    }

    final withReceipts = _applyPeerCursor(messages, _peerCursor(detail));
    Future.microtask(() {
      _reportRead(withReceipts);
      // The chat list cannot tell which user a private row belongs to, so tell
      // it here: its presence dot then follows the same live events we do.
      final peer = detail.otherMember(_me ?? 0);
      if (peer != null) {
        ref.read(chatListProvider.notifier).rememberPeer(arg, peer.userId);
      }
    });

    return ChatRoomState(
      detail: detail,
      messages: withReceipts,
      hasMore: messages.length >= _pageSize,
    );
  }

  // ── Reading ────────────────────────────────────────────────────────────

  /// Loads the previous page when the user scrolls to the top.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.loadingMore) return;
    if (current.messages.isEmpty) return;

    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final older = await ref.read(chatRepositoryProvider).fetchHistory(
            _chatId,
            limit: _pageSize,
            beforeId: current.messages.first.id,
          );
      final merged = [..._applyPeerCursor(older, _peerCursor(current.detail)), ...current.messages];
      state = AsyncData(current.copyWith(
        messages: merged,
        hasMore: older.length >= _pageSize,
        loadingMore: false,
      ));
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }

  /// Re-reads detail and the newest page.
  Future<void> refresh() async {
    final repo = ref.read(chatRepositoryProvider);
    final detail = await repo.fetchChatDetail(_chatId);
    final messages = await repo.fetchHistory(_chatId, limit: _pageSize);
    state = AsyncData(ChatRoomState(
      detail: detail,
      messages: _applyPeerCursor(messages, _peerCursor(detail)),
      hasMore: messages.length >= _pageSize,
    ));
  }

  // ── Writing ────────────────────────────────────────────────────────────

  /// Sends a text message, or commits the edit when one is in progress.
  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final current = state.valueOrNull;
    if (current == null) return;

    final editing = current.editing;
    if (editing != null) {
      _socket?.editMessage(messageId: editing.id, newText: trimmed);
      _replace(editing.id, (m) => m.copyWith(text: trimmed, edited: true));
      state = AsyncData(state.value!.copyWith(clearEditing: true));
      return;
    }

    _post(text: trimmed, replyTo: current.replyTo);
  }

  /// Uploads a file and posts it as an attachment message.
  Future<void> sendAttachment(
    File file, {
    required String mimeType,
    AttachmentKind? kind,
    String? caption,
  }) async {
    final attachment = await ref.read(chatRepositoryProvider).uploadAttachment(
          file,
          mimeType: mimeType,
          kind: kind,
        );
    _post(text: caption, attachments: [attachment], replyTo: state.valueOrNull?.replyTo);
  }

  void _post({String? text, List<MessageAttachment> attachments = const [], Message? replyTo}) {
    final me = _me;
    final current = state.valueOrNull;
    if (me == null || current == null) return;

    final clientId = _newClientId();
    final optimistic = Message(
      id: clientId,
      clientMessageId: clientId,
      chatId: _chatId,
      senderId: me,
      text: text,
      attachments: attachments,
      replyToMessageId: replyTo?.id,
      replyPreview: replyTo == null
          ? null
          : ReplyPreview(senderId: replyTo.senderId, text: replyTo.text ?? 'Biriktirma'),
      createdAt: DateTime.now(),
      deliveryState: DeliveryState.pending,
    );

    final sent = _socket?.sendMessage(
          chatId: _chatId,
          clientMessageId: clientId,
          text: text,
          replyToMessageId: replyTo?.id,
          attachments: attachments,
        ) ??
        false;

    state = AsyncData(current.copyWith(
      messages: [
        ...current.messages,
        sent ? optimistic : optimistic.copyWith(deliveryState: DeliveryState.failed),
      ],
      clearReplyTo: true,
    ));
  }

  /// Forwards [message] into another chat.
  void forward(Message message, {required int toChatId, required String senderName}) {
    _socket?.forwardMessage(
      chatId: toChatId,
      originalMessageId: message.id,
      senderName: senderName,
      clientMessageId: _newClientId(),
    );
  }

  /// Soft-deletes own message.
  void delete(Message message) {
    _socket?.deleteMessage(messageId: message.id);
    _replace(message.id, (m) => m.copyWith(deleted: true));
  }

  /// Toggles one emoji, optimistically.
  void toggleReaction(Message message, String emoji) {
    final me = _me;
    if (me == null) return;
    _socket?.toggleReaction(messageId: message.id, emoji: emoji);

    final existing = message.reactions.where((r) => r.emoji == emoji).firstOrNull;
    final added = existing == null || !existing.reactedBy(me);
    _applyReaction(message.id, emoji: emoji, userId: me, added: added);
  }

  /// Throttled `typing:update` — one frame per two seconds while typing.
  void notifyTyping() {
    if (_typingThrottle?.isActive ?? false) return;
    _typingThrottle = Timer(const Duration(seconds: 2), () {});
    _socket?.typing(chatId: _chatId);
  }

  /// Leaves a group chat and stops listening to its channel.
  Future<void> leave() async {
    await ref.read(chatRepositoryProvider).leaveChat(_chatId);
    _socket?.leaveChat(chatId: _chatId);
    await ref.read(chatListProvider.notifier).refresh();
  }

  // ── Composer ───────────────────────────────────────────────────────────

  void setReplyTo(Message? message) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(replyTo: message, clearReplyTo: message == null));
  }

  void setEditing(Message? message) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(editing: message, clearEditing: message == null));
  }

  // ── Socket ─────────────────────────────────────────────────────────────

  ChatSocket? get _socket => ref.read(chatSocketProvider);

  void _onEvent(ChatEvent event) {
    final current = state.valueOrNull;
    if (current == null) return;

    switch (event) {
      case MessageNewEvent(:final chatId, :final message) when chatId == _chatId:
        if (current.messages.any((m) => m.id == message.id)) return;
        _clearTyping(message.senderId);
        state = AsyncData(current.copyWith(messages: [...current.messages, message]));
        _reportRead([message]);

      case MessageAckEvent(:final chatId, :final messageId, :final clientMessageId)
          when chatId == _chatId && clientMessageId != null:
        _replace(
          clientMessageId,
          (m) => m.copyWith(id: messageId, deliveryState: DeliveryState.sent),
        );

      case MessageEditedEvent(:final chatId, :final messageId, :final newContent, :final editedAt)
          when chatId == _chatId:
        _replace(messageId, (m) => m.copyWith(text: newContent, edited: true, editedAt: editedAt));

      case MessageDeletedEvent(:final chatId, :final messageId) when chatId == _chatId:
        _replace(messageId, (m) => m.copyWith(deleted: true));

      case MessageReactionEvent(
            :final chatId,
            :final messageId,
            :final emoji,
            :final added,
            :final userId
          )
          when chatId == _chatId:
        if (userId == _me) return; // already applied optimistically
        _applyReaction(messageId, emoji: emoji, userId: userId, added: added);

      case MessageReadEvent(:final chatId, :final messageId, :final readerId)
          when chatId == _chatId:
        if (readerId == _me) return;
        state = AsyncData(state.value!.copyWith(
          messages: _applyPeerCursor(state.value!.messages, messageId),
        ));

      case TypingEvent(:final chatId, :final userId) when chatId == _chatId:
        if (userId == _me) return;
        _setTyping(userId);

      case _:
        break;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  /// The peer's read cursor from the REST snapshot.
  ///
  /// In a group the earliest cursor is used, so a tick only turns double once
  /// everyone has caught up.
  String? _peerCursor(ChatDetail? detail) {
    final me = _me;
    if (detail == null || me == null) return null;
    final cursors = detail.members
        .where((m) => m.userId != me)
        .map((m) => m.lastReadMessageId)
        .whereType<String>()
        .toList();
    if (cursors.isEmpty) return null;
    cursors.sort();
    return cursors.first;
  }

  /// Gives our own messages their delivery state.
  ///
  /// Anything the server handed back is at least stored, so it starts at
  /// [DeliveryState.sent]; those at or before the peer's [cursor] are read.
  /// Mongo ObjectIds start with a timestamp, so their hex strings sort in
  /// creation order and a plain comparison is enough.
  List<Message> _applyPeerCursor(List<Message> messages, String? cursor) {
    final me = _me;
    if (me == null) return messages;
    return [
      for (final message in messages)
        if (message.senderId != me || message.deliveryState == DeliveryState.pending)
          message
        else if (cursor != null && message.id.compareTo(cursor) <= 0)
          message.copyWith(deliveryState: DeliveryState.read)
        else
          message.copyWith(deliveryState: DeliveryState.sent),
    ];
  }

  /// Tells the server we have seen these incoming messages.
  void _reportRead(List<Message> messages) {
    final me = _me;
    if (me == null) return;
    final fresh = messages
        .where((m) => m.senderId != me && !m.isLocal && !_reported.contains(m.id))
        .map((m) => m.id)
        .toList();
    if (fresh.isEmpty) return;
    _reported.addAll(fresh);

    // The socket frame moves the SQL cursor and gives the sender their receipt;
    // the HTTP call flips `is_read` on the Mongo documents.
    fresh.sort();
    _socket?.markRead(messageId: fresh.last);
    unawaited(
      ref.read(chatRepositoryProvider).markAsRead(fresh).catchError((_) {}),
    );
    ref.read(chatListProvider.notifier).markRead(_chatId);
  }

  void _applyReaction(
    String messageId, {
    required String emoji,
    required int userId,
    required bool added,
  }) {
    _replace(messageId, (message) {
      final reactions = [...message.reactions];
      final index = reactions.indexWhere((r) => r.emoji == emoji);
      if (index == -1) {
        if (!added) return message;
        reactions.add(MessageReaction(emoji: emoji, userIds: [userId]));
      } else {
        final updated = reactions[index].toggled(userId, added: added);
        if (updated.count == 0) {
          reactions.removeAt(index);
        } else {
          reactions[index] = updated;
        }
      }
      return message.copyWith(reactions: reactions);
    });
  }

  void _replace(String id, Message Function(Message) update) {
    final current = state.valueOrNull;
    if (current == null) return;

    final messages = [...current.messages];
    final index = messages.indexWhere((message) => message.id == id);
    if (index == -1) return;

    messages[index] = update(messages[index]);
    state = AsyncData(current.copyWith(messages: messages));
  }

  void _setTyping(int userId) {
    final current = state.valueOrNull;
    if (current == null) return;
    _typingTimers[userId]?.cancel();
    _typingTimers[userId] = Timer(_typingLinger, () => _clearTyping(userId));
    state = AsyncData(current.copyWith(typingUserIds: {...current.typingUserIds, userId}));
  }

  void _clearTyping(int userId) {
    _typingTimers.remove(userId)?.cancel();
    final current = state.valueOrNull;
    if (current == null || !current.typingUserIds.contains(userId)) return;
    state = AsyncData(
      current.copyWith(typingUserIds: {...current.typingUserIds}..remove(userId)),
    );
  }

  String _newClientId() =>
      'local-${DateTime.now().microsecondsSinceEpoch}-${_counter++}-${Random().nextInt(9999)}';
}

/// One chat room, keyed by chat id.
final chatRoomProvider =
    AsyncNotifierProviderFamily<ChatRoomController, ChatRoomState, int>(ChatRoomController.new);
