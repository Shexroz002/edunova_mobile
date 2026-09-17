import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/realtime/socket_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/auth_controller.dart';
import 'lobby_controller.dart';
import 'widgets/invite_friends_sheet.dart';
import 'widgets/join_code_card.dart';
import 'widgets/lobby_bottom_bar.dart';
import 'widgets/participants_card.dart';

/// Waiting room for a multiplayer session.
///
/// Two cards and a pinned action: the code with the session it opens, then who
/// is in the room. The header no longer scrolls away, so the connection pill
/// stays visible — which matters most in the one place it used to disappear.
///
/// Joining the room socket is what marks a student ready on the server, so
/// there is no ready button (`CLAUDE.md` default decision 4). Kick and room
/// chat are out of scope.
class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key, required this.sessionId});

  final int sessionId;

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> with WidgetsBindingObserver {
  bool _leaving = false;
  bool _starting = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final controller = ref.read(lobbyControllerProvider(widget.sessionId).notifier);
      controller.resumeSocket();
      controller.refresh();
    }
  }

  /// Replaces the lobby with the play screen once the session starts.
  void _goToPlay() {
    if (_navigated || !mounted) return;
    _navigated = true;
    context.pushReplacement('/session/${widget.sessionId}/play');
  }

  Future<void> _start() async {
    setState(() => _starting = true);
    try {
      await ref.read(lobbyControllerProvider(widget.sessionId).notifier).start();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sessiyadan chiqasizmi?'),
        content: const Text("Chiqsangiz, qayta qo'shilish uchun kod kerak bo'ladi."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Chiqish'),
          ),
        ],
      ),
    );
    if (leave != true || !mounted) return;

    setState(() => _leaving = true);
    try {
      await ref.read(lobbyControllerProvider(widget.sessionId).notifier).leave();
      if (mounted) context.pop();
    } on ApiException catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Xonadan chiqishda xatolik yuz berdi')),
        );
      }
    } finally {
      if (mounted) setState(() => _leaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = lobbyControllerProvider(widget.sessionId);
    final state = ref.watch(provider);

    ref.listen(provider, (_, next) {
      final value = next.value;
      if (value == null) return;
      if (value.started) _goToPlay();
      final finished = value.finishedMessage;
      if (finished != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(finished)));
      }
    });

    final data = state.value;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_leaving) _confirmLeave();
      },
      child: Scaffold(
        appBar: PageAppBar(
          title: const Text("Do'stlar bilan Test"),
          showThemeToggle: false,
          leading: IconButton(
            onPressed: _confirmLeave,
            icon: Icon(Icons.arrow_back_rounded, color: context.colors.textSecondary),
            tooltip: 'Chiqish',
          ),
          actions: [
            if (data != null) _ConnectionPill(status: data.socketStatus),
          ],
        ),
        body: SafeArea(
          top: false,
          child: state.when(
            loading: () => const LoadingView(),
            error: (error, _) => ErrorView(
              message: ApiException.from(error).message,
              onRetry: () => ref.invalidate(provider),
            ),
            data: (data) {
              final notifier = ref.read(provider.notifier);
              return Column(
                children: [
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: notifier.refresh,
                      child: _LobbyBody(
                        state: data,
                        isHost: notifier.isHost,
                        currentUserId: ref.read(authControllerProvider).user?.id,
                        onInvite: (userId) => notifier.invite(userId),
                      ),
                    ),
                  ),
                  LobbyBottomBar(
                    isHost: notifier.isHost,
                    canStart: notifier.canStart,
                    starting: _starting,
                    presentCount: data.present.length,
                    socketStatus: data.socketStatus,
                    onStart: _start,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Phone: one column. Tablet: the code beside the participants.
class _LobbyBody extends StatelessWidget {
  const _LobbyBody({
    required this.state,
    required this.isHost,
    required this.currentUserId,
    required this.onInvite,
  });

  final LobbyState state;
  final bool isHost;
  final int? currentUserId;
  final Future<void> Function(int userId) onInvite;

  @override
  Widget build(BuildContext context) {
    final code = JoinCodeCard(info: state.info);
    final people = ParticipantsCard(
      participants: state.participants,
      currentUserId: currentUserId,
      // Inviting is the host's job, so a joiner does not see the row.
      onInvite: isHost ? () => showInviteFriendsSheet(context, onInvite: onInvite) : null,
    );

    return ListView(
      padding: EdgeInsets.all(context.pagePadding),
      children: [
        ContentConstraint(
          child: context.isTablet
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: code),
                    const SizedBox(width: 16),
                    Expanded(child: people),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [code, const SizedBox(height: 12), people],
                ),
        ),
      ],
    );
  }
}

/// Live socket state, kept in the app bar where it cannot scroll away.
class _ConnectionPill extends StatelessWidget {
  const _ConnectionPill({required this.status});

  final SocketStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      SocketStatus.connected => (
          'Ulangan',
          context.readable(AppColors.success),
          Icons.wifi_rounded,
        ),
      SocketStatus.connecting || SocketStatus.idle => (
          'Ulanmoqda',
          context.readable(AppColors.brand),
          Icons.wifi_tethering_rounded,
        ),
      SocketStatus.reconnecting => (
          'Qayta ulanmoqda',
          context.readable(AppColors.warning),
          Icons.wifi_rounded,
        ),
      SocketStatus.closed => (
          'Uzildi',
          context.readable(AppColors.error),
          Icons.wifi_off_rounded,
        ),
    };

    return Center(
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.tint(color, 0x1F),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.tint(color, 0x4D)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
