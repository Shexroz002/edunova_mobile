import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/realtime/socket_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/state_views.dart';
import '../domain/chat_models.dart';
import 'chat_list_controller.dart';
import 'chat_providers.dart';
import 'widgets/chat_list_row.dart';
import 'widgets/connection_banner.dart';
import 'widgets/new_chat_sheet.dart';

/// The Suhbatlar tab: every chat the student is a member of.
///
/// Seeded from `GET /chats` and kept live by `/ws/chat`, so a new message,
/// a deletion or someone typing lands here without a refresh.
class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});

  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

/// Presence keys live 60 s in Redis and expire **without** an event, so a peer
/// that dropped off silently would otherwise stay green here forever. The room
/// re-reads on open; the list polls at the same cadence as the TTL.
const _presencePoll = Duration(seconds: 60);

class _ChatsScreenState extends ConsumerState<ChatsScreen>
    with WidgetsBindingObserver {
  String _query = '';
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _poll = Timer.periodic(_presencePoll, (_) => _refreshQuietly());
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the background: the snapshot is certainly stale.
    if (state == AppLifecycleState.resumed) _refreshQuietly();
  }

  /// Refreshes without ever turning the list into an error state.
  void _refreshQuietly() {
    if (!mounted) return;
    ref.read(chatListProvider.notifier).refresh().catchError((_) {});
  }

  Future<void> _openNewChat() async {
    final chatId = await showNewChatSheet(context);
    if (chatId != null && mounted) context.push('/chats/$chatId');
  }

  List<ChatListItem> _visible(List<ChatListItem> chats) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return chats;
    return chats.where((chat) => chat.title.toLowerCase().contains(query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = ref.watch(chatListProvider);
    final status = ref.watch(chatSocketStatusProvider).valueOrNull;

    return Scaffold(
      appBar: PageAppBar(
        title: const Text('Suhbatlar'),
        actions: [
          IconButton(
            onPressed: _openNewChat,
            icon: const Icon(Icons.edit_square, size: 22),
            color: c.accent,
            tooltip: 'Yangi suhbat',
          ),
        ],
      ),
      body: Column(
        children: [
          if (status == SocketStatus.reconnecting || status == SocketStatus.connecting)
            const ConnectionBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: SearchField(
              hint: 'Qidirish',
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: ContentConstraint(
              child: state.when(
                loading: () => const LoadingView(),
                error: (error, _) => ErrorView(
                  message: '$error',
                  onRetry: () => ref.invalidate(chatListProvider),
                ),
                data: (data) {
                  final chats = _visible(data.chats);
                  if (chats.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: ref.read(chatListProvider.notifier).refresh,
                      child: ListView(
                        children: [
                          SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
                          _EmptyChats(
                            searching: _query.trim().isNotEmpty,
                            onCreate: _openNewChat,
                          ),
                        ],
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: ref.read(chatListProvider.notifier).refresh,
                    child: ListView.separated(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: chats.length,
                      separatorBuilder: (_, __) => Padding(
                        padding: const EdgeInsets.only(left: 76),
                        child: Divider(height: 1, thickness: 1, color: c.border),
                      ),
                      itemBuilder: (_, index) {
                        final chat = chats[index];
                        return ChatListRow(
                          chat: chat,
                          typing: data.typingChatIds.contains(chat.id),
                          onTap: () => context.push('/chats/${chat.id}'),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nothing to show yet — or nothing matching the search.
class _EmptyChats extends StatelessWidget {
  const _EmptyChats({required this.searching, required this.onCreate});

  final bool searching;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    if (searching) {
      return const EmptyView(
        icon: Icons.search_off_rounded,
        title: 'Hech narsa topilmadi',
        subtitle: 'Boshqa ism bilan qidirib ko\'ring',
      );
    }
    return Column(
      children: [
        const EmptyView(
          icon: Icons.forum_outlined,
          title: 'Hali suhbat yo\'q',
          subtitle: 'Do\'stlaringizdan birini tanlab\nbirinchi xabarni yuboring',
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.edit_square, size: 18),
          label: const Text('Yangi suhbat'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.brand,
            foregroundColor: Colors.white,
            minimumSize: const Size(180, 44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
