import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/brand.dart';
import '../../../chat/data/chat_repository.dart';
import '../../../chat/presentation/chat_list_controller.dart';
import '../../domain/friend_models.dart';

/// One contact row: avatar, name, handle, a teacher badge and a chat button.
///
/// The row itself did nothing — the only working target was the 48 dp chat
/// icon at its right edge, so tapping the other 300 dp of it was silently
/// ignored. The whole row opens the chat now; the icon stays because it says
/// what the tap will do.
class FriendTile extends ConsumerStatefulWidget {
  const FriendTile({super.key, required this.friend});

  final UserBrief friend;

  @override
  ConsumerState<FriendTile> createState() => FriendTileState();
}

class FriendTileState extends ConsumerState<FriendTile> {
  bool _opening = false;

  /// Opens (or reuses) the private chat and pushes the room.
  Future<void> _openChat() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final chat = await ref.read(chatRepositoryProvider).openPrivateChat(widget.friend.id);
      await ref.read(chatListProvider.notifier).ensureChat(chat.id);
      if (!mounted) return;
      context.push('/chats/${chat.id}');
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final friend = widget.friend;
    final isTeacher = friend.role?.toLowerCase().trim() == 'teacher';

    return Material(
      color: c.bgCard,
      borderRadius: BorderRadius.circular(15),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _openChat,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: c.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              UserAvatar(name: friend.fullName, imageUrl: friend.profileImage, size: 44),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      friend.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        // Beside the name the badge clipped it — the list read
                        // "Shehroz Toshp…" on a 360 dp phone.
                        if (isTeacher) ...[
                          _RoleBadge(),
                          const SizedBox(width: 7),
                        ],
                        Flexible(
                          child: Text(
                            friend.handle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11.5, color: c.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 9),
              // No chevron beside it: the chat button already says what the row
              // does, and two arrows for one destination is one too many.
              _ChatButton(loading: _opening, onTap: _openChat),
            ],
          ),
        ),
      ),
    );
  }
}

/// Marks a contact who teaches, on the handle line.
class _RoleBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final warning = context.readable(AppColors.warning);

    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: AppColors.tint(warning, 0x24),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.tint(warning, 0x52)),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          "O'qituvchi",
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: warning),
        ),
      ),
    );
  }
}

/// The chat affordance, kept as its own target inside the tappable row.
class _ChatButton extends StatelessWidget {
  const _ChatButton({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.readable(AppColors.brand);

    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: loading ? null : onTap,
          customBorder: const CircleBorder(),
          child: Center(
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.tint(AppColors.brand, 0x24),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.tint(AppColors.brand, 0x42)),
              ),
              child: loading
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.chat_bubble_outline_rounded, size: 18, color: brand),
            ),
          ),
        ),
      ),
    );
  }
}
