import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/paged_list_view.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/state_views.dart';
import '../data/friends_repository.dart';
import '../domain/friend_models.dart';
import 'widgets/add_friend_sheet.dart';
import 'widgets/friend_tile.dart';

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
    final padding = context.pagePadding;

    return Scaffold(
      appBar: PageAppBar(
        title: const Text("Do'stlar"),
        showFriends: false,
        actions: [
          // The gradient button this replaces stood beside the search field and
          // competed with it, though adding a friend happens once and searching
          // happens every time.
          IconButton(
            onPressed: _openAddFriend,
            tooltip: "Do'st qo'shish",
            icon: const Icon(Icons.person_add_alt_rounded),
          ),
        ],
      ),
      body: ContentConstraint(
        child: PagedListView<FriendContact>(
          reloadKey: '$_query#$_reload',
          // A single friend row across a tablet is mostly empty space.
          columns: context.isTablet ? 2 : 1,
          padding: EdgeInsets.fromLTRB(padding, 12, padding, 28),
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
              // "Do'stlaringiz bilan raqobatlashing" used to sit here. It was
              // decoration, and the page offers no way to compete from it.
              SearchField(
                hint: "Do'st qidirish...",
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 14),
              _CountLine(count: _count),
              const SizedBox(height: 10),
            ],
          ),
          empty: EmptyView(
            icon: Icons.people_outline_rounded,
            title: _query.isEmpty ? "Hali do'st yo'q" : "Do'stlar topilmadi",
            subtitle: _query.isEmpty
                ? "Do'st qo'shing — keyin ular bilan yozishasiz."
                : '"$_query" bo\'yicha natija yo\'q',
            actionLabel: _query.isEmpty ? "Do'st qo'shish" : null,
            onAction: _query.isEmpty ? _openAddFriend : null,
          ),
          itemBuilder: (context, contact) => FriendTile(friend: contact.friend),
        ),
      ),
    );
  }
}

/// How many friends are listed.
///
/// This was a "Mening do'stlarim" heading with a count pill beside it — a title
/// for the one thing the page contains, on a page already titled Do'stlar.
class _CountLine extends StatelessWidget {
  const _CountLine({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Text(
      "$count TA DO'ST",
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: context.colors.textMuted,
      ),
    );
  }
}
