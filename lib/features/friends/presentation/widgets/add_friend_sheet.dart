import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/brand.dart';
import '../../../../core/widgets/paged_list_view.dart';
import '../../../../core/widgets/search_field.dart';
import '../../../../core/widgets/state_views.dart';
import '../../data/friends_repository.dart';
import '../../domain/friend_models.dart';

/// Opens the "Do'st qo'shish" sheet. Returns `true` when at least one contact
/// was added, so the caller can reload its list.
Future<bool?> showAddFriendSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    // Without the root navigator the sheet stops at the tab bar and clips its
    // last row.
    useRootNavigator: true,
    backgroundColor: context.colors.bgCard,
    builder: (_) => const AddFriendSheet(),
  );
}

/// Search for users and add them as contacts, like the web `AddFriendModal`.
///
/// With an empty query it shows `contact/suggestions/`; typing switches to
/// `users/search`, which also returns people who are already contacts — those
/// rows show "Do'st" instead of an add button.
class AddFriendSheet extends ConsumerStatefulWidget {
  const AddFriendSheet({super.key});

  @override
  ConsumerState<AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends ConsumerState<AddFriendSheet> {
  String _query = '';
  int _total = 0;
  bool _addedAny = false;

  /// Users added in this sheet, so their rows flip without a refetch.
  final _added = <int>{};
  int? _pending;

  Future<void> _add(UserBrief user) async {
    setState(() => _pending = user.id);
    try {
      await ref.read(friendsRepositoryProvider).addContact(user.id);
      if (!mounted) return;
      setState(() {
        _added.add(user.id);
        _addedAny = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${user.fullName} do'stlarga qo'shildi")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiException.from(e).message)),
      );
    } finally {
      if (mounted) setState(() => _pending = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repository = ref.read(friendsRepositoryProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_addedAny);
      },
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, _) => Column(
          children: [
            _Header(onClose: () => Navigator.of(context).pop(_addedAny)),
            Divider(height: 1, color: c.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: SearchField(
                hint: 'Ism yoki username...',
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Container(
              width: double.infinity,
              color: c.accentMuted,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              child: Text(
                _query.isEmpty
                    ? '$_total foydalanuvchi topildi'
                    : '$_total foydalanuvchi · "$_query" bo\'yicha',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: c.textSecondary,
                ),
              ),
            ),
            Expanded(
              child: PagedListView<UserSearchResult>(
                reloadKey: _query,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                spacing: 10,
                fetchPage: (page) => _query.isEmpty
                    ? repository.fetchSuggestions(page: page)
                    : repository.searchUsers(search: _query, page: page),
                onLoaded: (items, total) {
                  if (total != _total) setState(() => _total = total);
                },
                empty: EmptyView(
                  icon: Icons.search_rounded,
                  title: 'Foydalanuvchi topilmadi',
                  subtitle: _query.isEmpty
                      ? 'Taklif qilinadigan foydalanuvchilar topilmadi'
                      : '"$_query" bo\'yicha natija yo\'q',
                ),
                itemBuilder: (context, result) => _UserTile(
                  result: result,
                  isContact: result.isContact || _added.contains(result.user.id),
                  loading: _pending == result.user.id,
                  onAdd: () => _add(result.user),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 12, 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.accentMuted,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.tint(AppColors.brand, 0x40)),
            ),
            child: Icon(Icons.person_add_alt_1_rounded, size: 20, color: c.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Do'st qo'shish",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
                Text(
                  "Yangi do'stlar toping",
                  style: TextStyle(fontSize: 12, color: c.textMuted),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: Icon(Icons.close_rounded, color: c.textMuted),
            tooltip: 'Yopish',
          ),
        ],
      ),
    );
  }
}

/// One search result with its add / already-a-friend action.
class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.result,
    required this.isContact,
    required this.loading,
    required this.onAdd,
  });

  final UserSearchResult result;
  final bool isContact;
  final bool loading;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final user = result.user;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.bgInner,
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
          const SizedBox(width: 10),
          if (isContact)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.tint(AppColors.success),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_rounded, size: 15, color: AppColors.success),
                  SizedBox(width: 5),
                  Text(
                    "Do'st",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 38,
              child: FilledButton.icon(
                onPressed: loading ? null : onAdd,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                icon: loading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.person_add_alt_1_rounded, size: 16),
                label: const Text("Qo'shish", style: TextStyle(fontSize: 13)),
              ),
            ),
        ],
      ),
    );
  }
}
