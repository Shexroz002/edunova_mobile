import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/realtime/socket_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/chat_models.dart';
import '../domain/message_models.dart';
import 'audio_playback_controller.dart';
import 'chat_providers.dart';
import 'chat_room_controller.dart';
import 'round_video_controller.dart';
import 'chat_time.dart';
import 'widgets/chat_avatar.dart';
import 'widgets/chat_composer.dart';
import 'widgets/connection_banner.dart';
import 'widgets/forward_sheet.dart';
import 'widgets/message_actions_sheet.dart';
import 'widgets/message_bubble.dart';

/// One open conversation.
///
/// History comes from `GET /messages/chat/{id}`; everything after that — new
/// messages, edits, deletions, reactions, read receipts, typing and presence —
/// arrives on `/ws/chat`.
class ChatRoomScreen extends ConsumerStatefulWidget {
  const ChatRoomScreen({super.key, required this.chatId});

  final int chatId;

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    // Media must not keep playing after the room is closed.
    ref.read(audioPlaybackProvider.notifier).stop();
    ref.read(roundVideoProvider.notifier).stop();
    super.dispose();
  }

  /// The list is reversed, so "near the end" means the oldest message.
  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
      ref.read(chatRoomProvider(widget.chatId).notifier).loadMore();
    }
  }

  ChatRoomController get _controller => ref.read(chatRoomProvider(widget.chatId).notifier);

  Future<void> _onLongPress(Message message, bool isOwn, int me) async {
    final result = await showMessageActions(
      context,
      message: message,
      isOwn: isOwn,
      currentUserId: me,
    );
    if (result == null || !mounted) return;

    if (result.emoji != null) {
      _controller.toggleReaction(message, result.emoji!);
      return;
    }

    switch (result.action!) {
      case MessageAction.reply:
        _controller.setReplyTo(message);
      case MessageAction.edit:
        _controller.setEditing(message);
      case MessageAction.copy:
        await Clipboard.setData(ClipboardData(text: message.text ?? ''));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nusxa olindi')));
        }
      case MessageAction.forward:
        await _forward(message);
      case MessageAction.delete:
        await _confirmDelete(message);
    }
  }

  Future<void> _forward(Message message) async {
    final targets = await showForwardSheet(context, message: message);
    if (targets == null || targets.isEmpty || !mounted) return;
    final me = ref.read(authControllerProvider).user;
    for (final chatId in targets) {
      _controller.forward(
        message,
        toChatId: chatId,
        senderName: me?.fullName ?? '',
      );
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${targets.length} ta suhbatga uzatildi')),
    );
  }

  Future<void> _confirmDelete(Message message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.colors.bgCard,
        title: const Text('Xabarni o\'chirish'),
        content: const Text('Bu xabar hamma uchun o\'chiriladi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Bekor qilish'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('O\'chirish', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) _controller.delete(message);
  }

  Future<void> _attach(File file, String mimeType, AttachmentKind? kind) async {
    try {
      await _controller.sendAttachment(file, mimeType: mimeType, kind: kind);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authControllerProvider).user?.id ?? 0;
    final state = ref.watch(chatRoomProvider(widget.chatId));
    final status = ref.watch(chatSocketStatusProvider).valueOrNull;

    // Server-side refusals (not a member, message gone) surface as one snack.
    ref.listen(chatErrorProvider, (_, next) {
      final error = next.valueOrNull;
      if (error == null || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.detail)));
    });

    return Scaffold(
      appBar: _RoomAppBar(chatId: widget.chatId, currentUserId: me),
      body: Column(
        children: [
          if (status == SocketStatus.reconnecting) const ConnectionBanner(),
          Expanded(
            child: state.when(
              loading: () => const LoadingView(),
              error: (error, _) => ErrorView(
                message: '$error',
                onRetry: () => ref.invalidate(chatRoomProvider(widget.chatId)),
              ),
              data: (room) => _MessageList(
                room: room,
                currentUserId: me,
                scroll: _scroll,
                onLongPress: _onLongPress,
                onReactionTap: (message, emoji) => _controller.toggleReaction(message, emoji),
              ),
            ),
          ),
          if (state.hasValue)
            ChatComposer(
              currentUserId: me,
              replyTo: state.value!.replyTo,
              editing: state.value!.editing,
              onCancelContext: () {
                _controller.setReplyTo(null);
                _controller.setEditing(null);
              },
              onSend: _controller.send,
              onAttach: _attach,
              onTyping: _controller.notifyTyping,
            ),
        ],
      ),
    );
  }
}

/// Header with the peer's live presence, or a group's member count.
class _RoomAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const _RoomAppBar({required this.chatId, required this.currentUserId});

  final int chatId;
  final int currentUserId;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final room = ref.watch(chatRoomProvider(chatId)).valueOrNull;
    final detail = room?.detail;
    final presence = ref.watch(presenceProvider);

    final peer = detail?.otherMember(currentUserId);
    final live = peer == null ? null : presence[peer.userId];
    final online = live?.online ?? peer?.isOnline ?? false;

    final typing = room?.typingUserIds.isNotEmpty ?? false;
    final (subtitle, subtitleColor) = switch ((typing, detail?.kind, online)) {
      (true, _, _) => ('yozmoqda...', c.accent),
      (_, ChatKind.group, _) => ('${detail?.membersCount ?? 0} a\'zo', c.textSecondary),
      (_, _, true) => ('onlayn', AppColors.success),
      _ => (formatLastSeen(live?.lastSeenAt), c.textSecondary),
    };

    return AppBar(
      backgroundColor: c.bgCard,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: Border(bottom: BorderSide(color: c.border)),
      titleSpacing: 0,
      iconTheme: IconThemeData(color: c.textSecondary),
      title: InkWell(
        onTap: detail == null ? null : () => context.push('/chats/$chatId/info'),
        child: Row(
          children: [
            ChatAvatar(
              name: detail?.titleFor(currentUserId) ?? '',
              imageUrl: peer?.profileImage ?? detail?.avatarUrl,
              kind: detail?.kind ?? ChatKind.private,
              size: 38,
              online: detail?.kind.isGroup == true ? null : online,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    detail?.titleFor(currentUserId) ?? 'Suhbat',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: subtitleColor,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          onPressed: detail == null ? null : () => context.push('/chats/$chatId/info'),
          icon: const Icon(Icons.info_outline_rounded),
          tooltip: 'Ma\'lumot',
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

/// The reversed thread: newest at the bottom, day separators between days.
class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.room,
    required this.currentUserId,
    required this.scroll,
    required this.onLongPress,
    required this.onReactionTap,
  });

  final ChatRoomState room;
  final int currentUserId;
  final ScrollController scroll;
  final void Function(Message message, bool isOwn, int me) onLongPress;
  final void Function(Message message, String emoji) onReactionTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (room.messages.isEmpty) {
      return const EmptyView(
        icon: Icons.waving_hand_outlined,
        title: 'Hozircha xabar yo\'q',
        subtitle: 'Birinchi bo\'lib yozing',
      );
    }

    final items = _buildItems(room, currentUserId);

    return ListView.builder(
      controller: scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: items.length + (room.loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        // reverse: true renders index 0 at the bottom.
        final item = items[items.length - 1 - index];
        return switch (item) {
          _DayItem(:final date) => _DaySeparator(date: date),
          _TypingItem(:final name) => _TypingBubble(name: name),
          _MessageItem(
            :final message,
            :final isOwn,
            :final showAvatar,
            :final tail,
            :final senderName,
            :final senderImage,
          ) =>
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MessageBubble(
                message: message,
                outgoing: isOwn,
                currentUserId: currentUserId,
                senderName: senderName,
                senderImage: senderImage,
                showAvatar: showAvatar,
                tail: tail,
                onLongPress: () => onLongPress(message, isOwn, currentUserId),
                onReactionTap: (emoji) => onReactionTap(message, emoji),
              ),
            ),
        };
      },
    ).withBackground(c.bgBase);
  }
}

/// Flattens messages into rows, inserting day separators and the typing bubble.
List<_RoomItem> _buildItems(ChatRoomState room, int currentUserId) {
  final detail = room.detail;
  final isGroup = detail?.kind.isGroup ?? false;
  final items = <_RoomItem>[];
  DateTime? lastDay;
  int? lastSender;

  for (var i = 0; i < room.messages.length; i++) {
    final message = room.messages[i];
    final day = DateTime(
      message.createdAt.toLocal().year,
      message.createdAt.toLocal().month,
      message.createdAt.toLocal().day,
    );
    if (lastDay == null || day != lastDay) {
      items.add(_DayItem(day));
      lastDay = day;
      lastSender = null;
    }

    final isOwn = message.senderId == currentUserId;
    final member = detail?.members.where((m) => m.userId == message.senderId).firstOrNull;
    final startsRun = lastSender != message.senderId;

    items.add(_MessageItem(
      message: message,
      isOwn: isOwn,
      // In a group every incoming run starts with the sender's avatar.
      showAvatar: isGroup && !isOwn && startsRun,
      tail: startsRun,
      senderName: isGroup && !isOwn && startsRun ? member?.fullName : null,
      senderImage: member?.profileImage,
    ));
    lastSender = message.senderId;
  }

  for (final userId in room.typingUserIds) {
    final member = detail?.members.where((m) => m.userId == userId).firstOrNull;
    items.add(_TypingItem(member?.fullName));
  }

  return items;
}

sealed class _RoomItem {
  const _RoomItem();
}

class _DayItem extends _RoomItem {
  const _DayItem(this.date);

  final DateTime date;
}

class _TypingItem extends _RoomItem {
  const _TypingItem(this.name);

  final String? name;
}

class _MessageItem extends _RoomItem {
  const _MessageItem({
    required this.message,
    required this.isOwn,
    required this.showAvatar,
    required this.tail,
    this.senderName,
    this.senderImage,
  });

  final Message message;
  final bool isOwn;
  final bool showAvatar;
  final bool tail;
  final String? senderName;
  final String? senderImage;
}

/// Centred `Bugun` / `Kecha` / date pill.
class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: c.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border),
          ),
          child: Text(
            formatDaySeparator(date),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: c.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Three dots while someone types.
class _TypingBubble extends StatelessWidget {
  const _TypingBubble({this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 38),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: c.bgCard,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: c.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final opacity in [1.0, 0.6, 0.3]) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: c.textMuted.withValues(alpha: opacity),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ],
            ),
          ),
          if (name != null) ...[
            const SizedBox(width: 8),
            Text(
              '$name yozmoqda',
              style: TextStyle(fontSize: 12, color: c.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Paints the page background behind the thread.
extension on Widget {
  Widget withBackground(Color color) => ColoredBox(color: color, child: this);
}
