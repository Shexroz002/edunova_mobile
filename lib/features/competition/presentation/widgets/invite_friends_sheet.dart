import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/media_url.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/brand.dart';
import '../../../../core/widgets/search_field.dart';
import '../../../../core/widgets/state_views.dart';
import '../../data/competition_repository.dart';
import '../../domain/competition_models.dart';

/// Lets the host invite contacts into a waiting session.
Future<void> showInviteFriendsSheet(
  BuildContext context, {
  required Future<void> Function(int userId) onInvite,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.colors.bgCard,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (_, scrollController) => _InviteFriendsSheet(
        onInvite: onInvite,
        scrollController: scrollController,
      ),
    ),
  );
}

class _InviteFriendsSheet extends ConsumerStatefulWidget {
  const _InviteFriendsSheet({required this.onInvite, required this.scrollController});

  final Future<void> Function(int userId) onInvite;
  final ScrollController scrollController;

  @override
  ConsumerState<_InviteFriendsSheet> createState() => _InviteFriendsSheetState();
}

class _InviteFriendsSheetState extends ConsumerState<_InviteFriendsSheet> {
  String _search = '';
  late Future<List<InvitableContact>> _future = _load();

  /// User ids already invited in this sheet, so each is only sent once.
  final _invited = <int>{};
  int? _sending;

  Future<List<InvitableContact>> _load() => ref
      .read(competitionRepositoryProvider)
      .fetchContacts(search: _search.isEmpty ? null : _search);

  void _reload() => setState(() => _future = _load());

  Future<void> _invite(InvitableContact contact) async {
    setState(() => _sending = contact.userId);
    try {
      await widget.onInvite(contact.userId);
      if (!mounted) return;
      setState(() => _invited.add(contact.userId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${contact.fullName} taklif qilindi')),
      );
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sending = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Do‘stlarni taklif qilish",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.textPrimary),
          ),
          const SizedBox(height: 12),
          SearchField(
            hint: "Do‘stlarni izlash...",
            initialValue: _search,
            onChanged: (value) {
              _search = value;
              _reload();
            },
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<InvitableContact>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingView();
                }
                if (snapshot.hasError) {
                  return ErrorView(
                    message: ApiException.from(snapshot.error!).message,
                    onRetry: _reload,
                  );
                }
                final contacts = snapshot.data ?? const <InvitableContact>[];
                if (contacts.isEmpty) {
                  return EmptyView(
                    icon: Icons.person_search_rounded,
                    title: _search.isEmpty ? "Do‘stlar yo‘q" : 'Hech kim topilmadi',
                    subtitle: _search.isEmpty
                        ? "Avval «Do‘stlar» bo‘limida do‘st qo‘shing"
                        : "Boshqa ism bilan qidirib ko‘ring",
                  );
                }
                return ListView.separated(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.only(bottom: 20),
                  itemCount: contacts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, index) {
                    final contact = contacts[index];
                    final invited = _invited.contains(contact.userId);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: UserAvatar(
                        name: contact.fullName,
                        imageUrl: MediaUrl.resolve(contact.profileImage),
                      ),
                      title: Text(
                        contact.fullName,
                        style: TextStyle(fontWeight: FontWeight.w600, color: c.textPrimary),
                      ),
                      subtitle:
                          Text('@${contact.username}', style: TextStyle(color: c.textSecondary)),
                      trailing: invited
                          ? const Icon(Icons.check_circle_rounded, color: AppColors.success)
                          : TextButton(
                              onPressed: _sending == null ? () => _invite(contact) : null,
                              child: _sending == contact.userId
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('Taklif'),
                            ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
