import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/brand.dart';
import '../../../../core/widgets/paged_list_view.dart';
import '../../../../core/widgets/search_field.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../friends/data/friends_repository.dart';
import '../../../friends/domain/friend_models.dart';
import '../../data/chat_repository.dart';
import '../chat_list_controller.dart';

/// Picks a contact to message. Returns the chat id to open, or `null`.
Future<int?> showNewChatSheet(BuildContext context) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useRootNavigator: true,
    backgroundColor: context.colors.bgCard,
    builder: (_) => const NewChatSheet(),
  );
}

/// Contact list that opens (or reuses) a private chat on tap.
///
/// `POST /chats/private` is idempotent — it returns the existing chat when one
/// already exists — so tapping a contact you already message just opens it.
class NewChatSheet extends ConsumerStatefulWidget {
  const NewChatSheet({super.key});

  @override
  ConsumerState<NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends ConsumerState<NewChatSheet> {
  String _query = '';
  int? _pending;

  Future<void> _open(UserBrief user) async {
    setState(() => _pending = user.id);
    try {
      final chat = await ref.read(chatRepositoryProvider).openPrivateChat(user.id);
      await ref.read(chatListProvider.notifier).ensureChat(chat.id);
      if (!mounted) return;
      Navigator.of(context).pop(chat.id);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _pending = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  Text(
                    'Yangi suhbat',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: c.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: c.textSecondary,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SearchField(
                hint: 'Ism yoki @username',
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: PagedListView<FriendContact>(
                reloadKey: _query,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                spacing: 8,
                fetchPage: (page) => ref.read(friendsRepositoryProvider).fetchFriends(
                      search: _query.isEmpty ? null : _query,
                      page: page,
                    ),
                empty: const EmptyView(
                  icon: Icons.person_search_outlined,
                  title: 'Do\'st topilmadi',
                  subtitle: 'Avval Do\'stlar bo\'limidan kimnidir qo\'shing',
                ),
                itemBuilder: (_, contact) => _ContactRow(
                  user: contact.friend,
                  busy: _pending == contact.friend.id,
                  onTap: _pending == null ? () => _open(contact.friend) : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One tappable contact.
class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.user, required this.busy, this.onTap});

  final UserBrief user;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            UserAvatar(name: user.fullName, imageUrl: user.profileImage, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
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
                    user.handle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: c.textMuted),
                  ),
                ],
              ),
            ),
            if (busy)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(Icons.chevron_right_rounded, color: c.textMuted),
          ],
        ),
      ),
    );
  }
}
