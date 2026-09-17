import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../data/chat_repository.dart';
import '../data/chat_socket.dart';
import '../domain/chat_models.dart';
import 'chat_providers.dart';

/// How long a `typing:update` keeps the row in the "yozmoqda..." state.
const _typingLinger = Duration(seconds: 4);

/// Presence events are coalesced into one list refresh.
const _presenceDebounce = Duration(seconds: 2);

/// The chat list plus the per-row typing flag.
class ChatListState {
  const ChatListState({this.chats = const [], this.typingChatIds = const {}});

  final List<ChatListItem> chats;
  final Set<int> typingChatIds;

  ChatListState copyWith({List<ChatListItem>? chats, Set<int>? typingChatIds}) => ChatListState(
        chats: chats ?? this.chats,
        typingChatIds: typingChatIds ?? this.typingChatIds,
      );
}

/// Loads `GET /chats` and then keeps it live from the socket.
///
/// Rows are re-sorted on every change, so the chat with the newest activity
/// stays on top exactly as the server would order it.
class ChatListController extends AsyncNotifier<ChatListState> {
  StreamSubscription<ChatEvent>? _subscription;
  final _typingTimers = <int, Timer>{};
  Timer? _presenceRefresh;

  /// Peer user id per private chat, learned from chat details we have opened.
  ///
  /// `GET /chats` returns the peer's name and avatar but not their id, so a
  /// `presence:update` cannot be matched to a row on its own. Rows we know
  /// flip immediately; the rest are corrected by the debounced refresh.
  final _peerByChat = <int, int>{};

  @override
  Future<ChatListState> build() async {
    final socket = ref.watch(chatSocketProvider);
    if (socket != null) {
      _subscription = socket.events.listen(_onEvent);
    }
    ref.onDispose(() {
      _subscription?.cancel();
      _presenceRefresh?.cancel();
      for (final timer in _typingTimers.values) {
        timer.cancel();
      }
      _typingTimers.clear();
    });

    final chats = await ref.read(chatRepositoryProvider).fetchChats();
    return ChatListState(chats: _sorted(chats));
  }

  /// Re-reads the list from the server (pull-to-refresh).
  Future<void> refresh() async {
    final chats = await ref.read(chatRepositoryProvider).fetchChats();
    state = AsyncData((state.valueOrNull ?? const ChatListState()).copyWith(chats: _sorted(chats)));
  }

  /// Clears the unread badge once the room is open.
  void markRead(int chatId) => _patch(chatId, (chat) => chat.copyWith(unreadCount: 0));

  /// Records which user a private chat belongs to, so their presence can be
  /// applied to the row. Called when a room loads its detail.
  void rememberPeer(int chatId, int userId) => _peerByChat[chatId] = userId;

  /// Adds a chat that was just created, without waiting for a refresh.
  Future<void> ensureChat(int chatId) async {
    final current = state.valueOrNull;
    if (current != null && current.chats.any((c) => c.id == chatId)) return;
    await refresh();
  }

  // ── Socket ─────────────────────────────────────────────────────────────

  void _onEvent(ChatEvent event) {
    switch (event) {
      case MessageNewEvent(:final chatId, :final message):
        final me = ref.read(authControllerProvider).user?.id;
        _clearTyping(chatId);
        _patch(chatId, (chat) {
          final mine = message.senderId == me;
          return chat.copyWith(
            lastMessage: LastMessagePreview(
              id: message.id,
              senderId: message.senderId,
              senderName: message.senderName,
              text: _previewOf(message.text, message.attachments.isNotEmpty),
              createdAt: message.createdAt,
            ),
            updatedAt: message.createdAt,
            unreadCount: mine ? chat.unreadCount : chat.unreadCount + 1,
          );
        });

      case MessageAckEvent(:final chatId, :final createdAt):
        // Our own message: the list has no echo of it, so bump the row here.
        _patch(chatId, (chat) => chat.copyWith(updatedAt: createdAt ?? DateTime.now()));

      case MessageDeletedEvent(:final chatId, :final previewText, :final previewAt):
        _patch(
          chatId,
          (chat) => chat.copyWith(
            lastMessage: previewText == null
                ? null
                : LastMessagePreview(
                    senderId: chat.lastMessage?.senderId ?? 0,
                    text: previewText,
                    createdAt: previewAt,
                  ),
          ),
        );

      case MessageReadEvent(:final chatId, :final readerId):
        // Read on another device of ours clears the badge here too.
        if (readerId == ref.read(authControllerProvider).user?.id) markRead(chatId);

      case TypingEvent(:final chatId, :final userId):
        if (userId == ref.read(authControllerProvider).user?.id) return;
        _setTyping(chatId);

      case PresenceEvent(:final userId, :final online, :final lastSeenAt):
        // Rows whose peer we know flip at once...
        for (final entry in _peerByChat.entries) {
          if (entry.value != userId) continue;
          _patch(
            entry.key,
            (chat) => chat.copyWith(isOnline: online, lastSeen: lastSeenAt),
          );
        }
        // ...and the rest are corrected by re-reading the list, which is the
        // only place the peer of an unopened chat is resolved.
        _schedulePresenceRefresh();

      case _:
        break;
    }
  }

  /// Coalesces a burst of presence events into one `GET /chats`.
  void _schedulePresenceRefresh() {
    _presenceRefresh?.cancel();
    _presenceRefresh = Timer(_presenceDebounce, () {
      refresh().catchError((_) {
        // A failed presence refresh must never surface as a list error.
      });
    });
  }

  void _setTyping(int chatId) {
    final current = state.valueOrNull;
    if (current == null) return;
    _typingTimers[chatId]?.cancel();
    _typingTimers[chatId] = Timer(_typingLinger, () => _clearTyping(chatId));
    state = AsyncData(current.copyWith(typingChatIds: {...current.typingChatIds, chatId}));
  }

  void _clearTyping(int chatId) {
    _typingTimers.remove(chatId)?.cancel();
    final current = state.valueOrNull;
    if (current == null || !current.typingChatIds.contains(chatId)) return;
    state = AsyncData(
      current.copyWith(typingChatIds: {...current.typingChatIds}..remove(chatId)),
    );
  }

  void _patch(int chatId, ChatListItem Function(ChatListItem) update) {
    final current = state.valueOrNull;
    if (current == null) return;

    final chats = [...current.chats];
    final index = chats.indexWhere((chat) => chat.id == chatId);
    if (index == -1) return;

    chats[index] = update(chats[index]);
    state = AsyncData(current.copyWith(chats: _sorted(chats)));
  }

  List<ChatListItem> _sorted(List<ChatListItem> chats) {
    final copy = [...chats]..sort((a, b) => b.sortedAt.compareTo(a.sortedAt));
    return copy;
  }

  /// What a row shows when the message is an attachment with no caption.
  static String _previewOf(String? text, bool hasAttachment) {
    final trimmed = text?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    return hasAttachment ? 'Biriktirma' : '';
  }
}

/// The live chat list.
final chatListProvider =
    AsyncNotifierProvider<ChatListController, ChatListState>(ChatListController.new);

/// Total unread across all chats, for the tab badge.
final chatUnreadTotalProvider = Provider<int>((ref) {
  final chats = ref.watch(chatListProvider).valueOrNull?.chats ?? const [];
  return chats.fold<int>(0, (sum, chat) => sum + chat.unreadCount);
});
