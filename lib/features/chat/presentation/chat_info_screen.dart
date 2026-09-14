import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/chat_models.dart';
import 'chat_providers.dart';
import 'chat_room_controller.dart';
import 'chat_time.dart';
import 'widgets/chat_avatar.dart';

/// Chat details: who is in it, who is online, and the way out of a group.
///
/// The web shows media counters here; no endpoint reports them, so they are
/// left out rather than filled with made-up numbers.
class ChatInfoScreen extends ConsumerWidget {
  const ChatInfoScreen({super.key, required this.chatId});

  final int chatId;

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.colors.bgCard,
        title: const Text('Guruhdan chiqish'),
        content: const Text('Suhbat ro\'yxatingizdan olib tashlanadi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Bekor qilish'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Chiqish', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(chatRoomProvider(chatId).notifier).leave();
      if (!context.mounted) return;
      context.go('/chats');
    } on ApiException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final me = ref.watch(authControllerProvider).user?.id ?? 0;
    final state = ref.watch(chatRoomProvider(chatId));
    final presence = ref.watch(presenceProvider);

    return Scaffold(
      appBar: const PageAppBar(title: Text('Ma\'lumot')),
      body: state.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: '$error',
          onRetry: () => ref.invalidate(chatRoomProvider(chatId)),
        ),
        data: (room) {
          final detail = room.detail;
          if (detail == null) {
            return const EmptyView(icon: Icons.forum_outlined, title: 'Ma\'lumot yo\'q');
          }

          bool isOnline(ChatMember member) =>
              presence[member.userId]?.online ?? member.isOnline;
          final onlineCount = detail.members.where(isOnline).length;
          final peer = detail.otherMember(me);

          return ListView(
            padding: const EdgeInsets.only(bottom: 28),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 20),
                decoration: BoxDecoration(
                  color: c.bgCard,
                  border: Border(bottom: BorderSide(color: c.border)),
                ),
                child: Column(
                  children: [
                    ChatAvatar(
                      name: detail.titleFor(me),
                      imageUrl: peer?.profileImage ?? detail.avatarUrl,
                      kind: detail.kind,
                      size: 84,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      detail.titleFor(me),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _Subtitle(
                      detail: detail,
                      onlineCount: onlineCount,
                      peerOnline: peer == null ? null : isOnline(peer),
                      peerLastSeen: peer == null ? null : presence[peer.userId]?.lastSeenAt,
                    ),
                    if (detail.description?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 10),
                      Text(
                        detail.description!,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13.5, color: c.textSecondary, height: 1.4),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'A\'ZOLAR',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: c.textMuted,
                  ),
                ),
              ),
              for (final member in detail.members)
                _MemberRow(member: member, isMe: member.userId == me, online: isOnline(member)),
              if (detail.kind.isGroup) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: InkWell(
                    onTap: () => _leave(context, ref),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.tint(AppColors.error, 0x14),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.tint(AppColors.error, 0x4D)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout_rounded, size: 19, color: AppColors.error),
                          SizedBox(width: 9),
                          Text(
                            'Guruhdan chiqish',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Member count and online count, or the peer's presence in a private chat.
class _Subtitle extends StatelessWidget {
  const _Subtitle({
    required this.detail,
    required this.onlineCount,
    this.peerOnline,
    this.peerLastSeen,
  });

  final ChatDetail detail;
  final int onlineCount;
  final bool? peerOnline;
  final DateTime? peerLastSeen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (!detail.kind.isGroup) {
      final text = peerOnline == true
          ? 'onlayn'
          : formatLastSeen(peerLastSeen) ?? 'oflayn';
      return Text(
        text,
        style: TextStyle(
          fontSize: 13.5,
          color: peerOnline == true ? AppColors.success : c.textSecondary,
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${detail.membersCount} a\'zo',
          style: TextStyle(fontSize: 13.5, color: c.textSecondary),
        ),
        if (onlineCount > 0) ...[
          Text(' · ', style: TextStyle(fontSize: 13.5, color: c.textSecondary)),
          Text(
            '$onlineCount ta onlayn',
            style: const TextStyle(fontSize: 13.5, color: AppColors.success),
          ),
        ],
      ],
    );
  }
}

/// One member with their live presence.
class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member, required this.isMe, required this.online});

  final ChatMember member;
  final bool isMe;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        children: [
          ChatAvatar(
            name: member.fullName,
            imageUrl: member.profileImage,
            size: 44,
            online: online,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                    if (member.isAdmin) _Tag(label: 'admin', color: c.accent),
                    if (isMe) _Tag(label: 'siz', color: c.textMuted),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  online ? 'onlayn' : 'oflayn',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: online ? AppColors.success : c.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '@${member.username}',
            style: TextStyle(fontSize: 12, color: c.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Small pill after a member's name.
class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.tint(color, 0x1F),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.tint(color, 0x4D)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
