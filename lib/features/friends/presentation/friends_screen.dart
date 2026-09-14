import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/paged_list_view.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/state_views.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/presentation/chat_list_controller.dart';
import '../data/friends_repository.dart';
import '../domain/friend_models.dart';
import 'widgets/add_friend_sheet.dart';

/// Contacts, laid out like the web `StudentFriendsPage.tsx`.
///
/// The web's green "Hozir onlayn — N do'st" banner, the per-row online dot and
/// "Faol emas" text are mock: no endpoint reports presence, so they are hidden
/// (`CLAUDE.md` default decision 2). The row's chat button opens a private chat.
class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  String _query = '';
  int _count = 0;

  /// Rebuilds the list after a contact is added in the sheet.
  int _reload = 0;

  Future<void> _openAddFriend() async {
    final added = await showAddFriendSheet(context);
    if (added == true && mounted) setState(() => _reload++);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final padding = context.pagePadding;

    return Scaffold(
      appBar: const PageAppBar(title: Text("Do'stlar")),
      body: ContentConstraint(
        child: PagedListView<FriendContact>(
          reloadKey: '$_query#$_reload',
          // A single friend row across a tablet is mostly empty space.
          columns: context.isTablet ? 2 : 1,
          padding: EdgeInsets.fromLTRB(padding, 0, padding, 28),
          spacing: 10,
          fetchPage: (page) => ref
              .read(friendsRepositoryProvider)
              .fetchFriends(search: _query.isEmpty ? null : _query, page: page),
          onLoaded: (items, total) {
            if (total != _count) setState(() => _count = total);
          },
          header: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Do'stlaringiz bilan raqobatlashing",
                style: TextStyle(fontSize: 13, color: c.textMuted),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: SearchField(
                      hint: "Do'st qidirish...",
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _AddButton(onTap: _openAddFriend),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Icon(Icons.people_alt_rounded, size: 18, color: c.accent),
                  const SizedBox(width: 8),
                  Text(
                    "Mening do'stlarim",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                    decoration: BoxDecoration(
                      color: c.accentMuted,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$_count',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: c.accent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
          empty: EmptyView(
            icon: Icons.people_outline_rounded,
            title: "Do'stlar topilmadi",
            subtitle:
                _query.isEmpty ? "Yangi do'stlar qo'shing" : '"$_query" bo\'yicha natija yo\'q',
          ),
          itemBuilder: (context, contact) => _FriendTile(friend: contact.friend),
        ),
      ),
    );
  }
}

/// Gradient "Qo'shish" button beside the search field.
class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: GradientButton.brandGradient,
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: onTap,
          child: const SizedBox(
            height: 48,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Icon(Icons.person_add_alt_1_rounded, size: 18, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    "Qo'shish",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One contact row: avatar, name, handle, a teacher badge and a chat button.
class _FriendTile extends ConsumerStatefulWidget {
  const _FriendTile({required this.friend});

  final UserBrief friend;

  @override
  ConsumerState<_FriendTile> createState() => _FriendTileState();
}

class _FriendTileState extends ConsumerState<_FriendTile> {
  bool _opening = false;

  /// Opens (or reuses) the private chat and pushes the room.
  Future<void> _openChat() async {
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

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          UserAvatar(name: friend.fullName, imageUrl: friend.profileImage, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  friend.handle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: c.textMuted),
                ),
              ],
            ),
          ),
          if (isTeacher)
            Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.tint(AppColors.warning),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                "O'qituvchi",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.warning,
                ),
              ),
            ),
          IconButton(
            onPressed: _opening ? null : _openChat,
            tooltip: 'Xabar yozish',
            icon: _opening
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.chat_bubble_outline_rounded, size: 20, color: c.accent),
          ),
        ],
      ),
    );
  }
}
