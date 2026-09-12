import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/media_url.dart';
import '../../../core/realtime/socket_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/brand.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/state_views.dart';
import '../domain/competition_models.dart';
import 'lobby_controller.dart';
import 'widgets/invite_friends_sheet.dart';
import 'widgets/join_code_card.dart';

/// Waiting room for a multiplayer session.
///
/// Laid out to match the web `StudentWaitingRoomPage.tsx`: an in-page header
/// with the connection pill, the gradient code card, a green "add friend"
/// button, the amber session-info card, the participant list, and the start
/// button with its requirement hint.
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_leaving) _confirmLeave();
      },
      child: Scaffold(
        body: SafeArea(
          child: state.when(
            loading: () => const LoadingView(),
            error: (error, _) => ErrorView(
              message: ApiException.from(error).message,
              onRetry: () => ref.invalidate(provider),
            ),
            data: (data) => RefreshIndicator(
              onRefresh: () => ref.read(provider.notifier).refresh(),
              child: _LobbyBody(
                state: data,
                isHost: ref.read(provider.notifier).isHost,
                canStart: ref.read(provider.notifier).canStart,
                starting: _starting,
                onBack: _confirmLeave,
                onStart: _start,
                onInvite: (userId) => ref.read(provider.notifier).invite(userId),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Phone: one column. Tablet: code and session info beside the participants.
class _LobbyBody extends StatelessWidget {
  const _LobbyBody({
    required this.state,
    required this.isHost,
    required this.canStart,
    required this.starting,
    required this.onBack,
    required this.onStart,
    required this.onInvite,
  });

  final LobbyState state;
  final bool isHost;
  final bool canStart;
  final bool starting;
  final VoidCallback onBack;
  final Future<void> Function() onStart;
  final Future<void> Function(int userId) onInvite;

  @override
  Widget build(BuildContext context) {
    final info = state.info;

    final codeColumn = [
      JoinCodeCard(code: info.joinCode, quizName: info.quizName),
      const SizedBox(height: 14),
      _AddFriendButton(onInvite: onInvite),
      const SizedBox(height: 14),
      _SessionInfoCard(state: state),
    ];

    final peopleColumn = [
      _ParticipantsCard(state: state),
      if (isHost) ...[
        const SizedBox(height: 14),
        _StartButton(
          canStart: canStart,
          starting: starting,
          presentCount: state.present.length,
          onStart: onStart,
        ),
      ] else ...[
        const SizedBox(height: 14),
        _WaitingHint(),
      ],
    ];

    return ContentConstraint(
      child: ListView(
        padding: EdgeInsets.fromLTRB(context.pagePadding, 0, context.pagePadding, 28),
        children: [
          _LobbyHeader(state: state, onBack: onBack),
          const SizedBox(height: 18),
          if (context.isTablet)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Column(children: codeColumn)),
                const SizedBox(width: 16),
                Expanded(child: Column(children: peopleColumn)),
              ],
            )
          else ...[...codeColumn, const SizedBox(height: 14), ...peopleColumn],
        ],
      ),
    );
  }
}

/// Back button, title, `Kutish xonasi · <quiz>` and the connection pill.
class _LobbyHeader extends StatelessWidget {
  const _LobbyHeader({required this.state, required this.onBack});

  final LobbyState state;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (statusLabel, statusColor) = switch (state.socketStatus) {
      SocketStatus.connected => ('Ulangan', AppColors.success),
      SocketStatus.connecting => ('Ulanmoqda', AppColors.brand),
      SocketStatus.reconnecting => ('Qayta ulanmoqda', AppColors.warning),
      _ => ('Ulanish uzildi', AppColors.error),
    };

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SquareIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Chiqish',
                onPressed: onBack,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Do'stlar bilan Test",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 14, color: c.textMuted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Kutish xonasi · ${state.info.quizName ?? "Test"}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, color: c.textMuted),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _Pill(
                      icon: Icons.wifi_rounded,
                      label: statusLabel,
                      color: statusColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(height: 1, thickness: 1, color: c.border),
        ],
      ),
    );
  }
}

/// Small tinted status pill.
class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

/// Full-width green gradient button, as on the web.
class _AddFriendButton extends StatelessWidget {
  const _AddFriendButton({required this.onInvite});

  final Future<void> Function(int userId) onInvite;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF22C55E), Color(0xFF10B981)],
          ),
        ),
        child: InkWell(
          onTap: () => showInviteFriendsSheet(context, onInvite: onInvite),
          child: const SizedBox(
            height: 52,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_add_alt_rounded, size: 18, color: Colors.white),
                SizedBox(width: 10),
                Text(
                  "Do'st qo'shish",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Amber "Sessiya ma'lumotlari" card with label/value rows.
class _SessionInfoCard extends StatelessWidget {
  const _SessionInfoCard({required this.state});

  final LobbyState state;

  @override
  Widget build(BuildContext context) {
    final info = state.info;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 15, color: AppColors.warning),
              SizedBox(width: 8),
              Text(
                "Sessiya ma'lumotlari",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoRow(label: 'Davomiyligi:', value: formatMinutes(info.durationMinutes)),
          const SizedBox(height: 6),
          _InfoRow(label: 'Savollar:', value: '${info.questionsCount} ta'),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: c.textMuted)),
        Text(
          value,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textSecondary),
        ),
      ],
    );
  }
}

/// Participants card: header with the ready pill, then one row per person.
class _ParticipantsCard extends StatelessWidget {
  const _ParticipantsCard({required this.state});

  final LobbyState state;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final present = state.present;
    // The backend keeps rows for people who left; show them last, dimmed.
    final gone = state.participants.where((p) => !p.status.isPresent).toList();
    final allReady = present.isNotEmpty && state.readyCount == present.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: c.accentMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.people_alt_rounded, size: 17, color: c.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ishtirokchilar',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
              ),
              _Pill(
                icon: Icons.check_circle_outline_rounded,
                label: '${state.readyCount}/${present.length} tayyor',
                color: allReady ? AppColors.success : AppColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final participant in [...present, ...gone])
            _ParticipantTile(participant: participant),
          const SizedBox(height: 6),
          Divider(height: 18, thickness: 1, color: c.border),
          Column(
            children: [
              Icon(Icons.wifi_tethering_rounded, size: 26, color: c.textMuted),
              const SizedBox(height: 8),
              Text(
                'Hozircha ${present.length} ishtirokchi qo\'shildi',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: c.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({required this.participant});

  final SessionParticipant participant;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final gone = !participant.status.isPresent;
    final statusColor = switch (participant.status) {
      ParticipantStatus.ready => AppColors.success,
      ParticipantStatus.finished => AppColors.brand,
      ParticipantStatus.disconnected => c.textMuted,
      ParticipantStatus.joined => AppColors.warning,
    };

    return Opacity(
      opacity: gone ? 0.5 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                UserAvatar(
                  name: participant.displayName,
                  imageUrl: MediaUrl.resolve(participant.profileImage),
                  size: 42,
                ),
                if (!gone)
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.bgCard, width: 2),
                      ),
                    ),
                  ),
              ],
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
                          participant.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                      if (participant.isHost) ...[
                        const SizedBox(width: 8),
                        const _Pill(
                          icon: Icons.workspace_premium_rounded,
                          label: 'Host',
                          color: AppColors.warning,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  _Pill(label: participant.status.label, color: statusColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Host's start button: indigo gradient when enabled, muted when not.
class _StartButton extends StatelessWidget {
  const _StartButton({
    required this.canStart,
    required this.starting,
    required this.presentCount,
    required this.onStart,
  });

  final bool canStart;
  final bool starting;
  final int presentCount;
  final Future<void> Function() onStart;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = canStart && !starting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: enabled ? JoinCodeCard.gradient : null,
              color: enabled ? null : c.bgInner,
            ),
            child: InkWell(
              onTap: enabled ? onStart : null,
              child: SizedBox(
                height: 54,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (starting)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    else
                      Icon(
                        Icons.play_arrow_rounded,
                        size: 22,
                        color: enabled ? Colors.white : c.textMuted,
                      ),
                    const SizedBox(width: 10),
                    Text(
                      'Testni boshlash',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: enabled ? Colors.white : c.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (!canStart) ...[
          const SizedBox(height: 8),
          Text(
            presentCount <= 1 ? 'Kamida 2 kishi kerak' : 'Barcha shartlar bajarilmagan',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: c.textMuted),
          ),
        ],
      ],
    );
  }
}

/// Shown to joiners instead of the start button.
class _WaitingHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Icon(Icons.hourglass_empty_rounded, size: 26, color: c.textMuted),
          const SizedBox(height: 8),
          Text(
            'Tashkilotchi boshlaganda test avtomatik ochiladi',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: c.textMuted),
          ),
        ],
      ),
    );
  }
}
