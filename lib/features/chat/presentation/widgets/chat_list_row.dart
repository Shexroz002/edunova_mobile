import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../domain/chat_models.dart';
import '../chat_time.dart';
import 'chat_avatar.dart';

/// One row of the Suhbatlar list.
class ChatListRow extends ConsumerWidget {
  const ChatListRow({
    super.key,
    required this.chat,
    required this.onTap,
    this.typing = false,
  });

  final ChatListItem chat;

  /// Someone is typing in this chat right now.
  final bool typing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final me = ref.watch(authControllerProvider).user?.id;
    final last = chat.lastMessage;
    final mine = last != null && last.senderId == me;
    final stamp = chat.sortedAt.millisecondsSinceEpoch == 0 ? '' : formatChatStamp(chat.sortedAt);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            ChatAvatar(
              name: chat.title,
              imageUrl: chat.avatar,
              kind: chat.kind,
              size: 52,
              online: chat.isOnline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          chat.title.trim().isEmpty ? 'Suhbat' : chat.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        stamp,
                        style: TextStyle(fontSize: 11.5, color: c.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: typing
                            ? Text(
                                'yozmoqda...',
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: c.accent,
                                ),
                              )
                            : _Preview(last: last, mine: mine),
                      ),
                      if (chat.unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        _UnreadBadge(count: chat.unreadCount),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Last-message line: a tick for our own message, then the text.
class _Preview extends StatelessWidget {
  const _Preview({required this.last, required this.mine});

  final LastMessagePreview? last;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (last == null) {
      return Text(
        'Xabar yo\'q',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 13.5, color: c.textMuted),
      );
    }

    final text = last!.text.trim();
    // An attachment-only message stores an empty text, so name it instead of
    // rendering a blank row.
    final empty = text.isEmpty;

    return Row(
      children: [
        if (mine) ...[
          Icon(Icons.done_rounded, size: 15, color: c.textMuted),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Text(
            empty ? 'Biriktirma' : text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              color: empty ? c.textMuted : c.textSecondary,
              fontStyle: empty ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ),
      ],
    );
  }
}

/// Indigo unread pill.
class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      height: 22,
      padding: EdgeInsets.symmetric(horizontal: count > 9 ? 6 : 0),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.brand,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}
