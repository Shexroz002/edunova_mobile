import 'package:flutter/material.dart';

import '../../../../core/realtime/socket_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/responsive.dart';

/// Pinned status line and action at the foot of the waiting room.
///
/// The start button used to sit at the end of a long scroll, with its
/// requirement hint as loose grey text under it and the joiner's version as yet
/// another card in the middle of the page. One bar carries all of it, and the
/// connection is allowed to override the status line — a dropped socket is the
/// one thing worth interrupting for.
class LobbyBottomBar extends StatelessWidget {
  const LobbyBottomBar({
    super.key,
    required this.isHost,
    required this.canStart,
    required this.starting,
    required this.presentCount,
    required this.socketStatus,
    required this.onStart,
  });

  final bool isHost;
  final bool canStart;
  final bool starting;
  final int presentCount;
  final SocketStatus socketStatus;
  final Future<void> Function() onStart;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: EdgeInsets.fromLTRB(context.pagePadding, 12, context.pagePadding, 16),
      decoration: BoxDecoration(
        color: c.bgCard,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: ContentConstraint(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Status(
              isHost: isHost,
              canStart: canStart,
              presentCount: presentCount,
              socketStatus: socketStatus,
            ),
            const SizedBox(height: 10),
            if (isHost)
              _StartButton(enabled: canStart && !starting, starting: starting, onStart: onStart)
            else
              const _WaitingButton(),
          ],
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({
    required this.isHost,
    required this.canStart,
    required this.presentCount,
    required this.socketStatus,
  });

  final bool isHost;
  final bool canStart;
  final int presentCount;
  final SocketStatus socketStatus;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final (icon, color, text) = switch (socketStatus) {
      SocketStatus.connected || SocketStatus.idle => isHost
          ? (
              canStart ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
              canStart ? context.readable(AppColors.success) : c.textMuted,
              canStart ? '$presentCount ishtirokchi tayyor' : 'Kamida 2 kishi kerak',
            )
          : (
              Icons.hourglass_empty_rounded,
              c.textMuted,
              'Tashkilotchi boshlashini kutmoqda',
            ),
      SocketStatus.connecting => (
          Icons.wifi_tethering_rounded,
          c.textMuted,
          'Xonaga ulanmoqda',
        ),
      SocketStatus.reconnecting => (
          Icons.wifi_rounded,
          context.readable(AppColors.warning),
          'Qayta ulanmoqda',
        ),
      _ => (
          Icons.wifi_off_rounded,
          context.readable(AppColors.error),
          'Ulanish uzildi — qayta ulanmoqda',
        ),
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ),
      ],
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.enabled, required this.starting, required this.onStart});

  final bool enabled;
  final bool starting;
  final Future<void> Function() onStart;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Material(
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: enabled ? _gradient : null,
          color: enabled ? null : c.bgInner,
          border: enabled ? null : Border.all(color: c.border),
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
                Flexible(
                  child: Text(
                    'Testni boshlash',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: enabled || starting ? Colors.white : c.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const _gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.brand, AppColors.violet],
  );
}

/// A joiner has nothing to press; the wait itself is the state.
class _WaitingButton extends StatelessWidget {
  const _WaitingButton();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: c.bgInner,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.accent),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'Test boshlanishini kutmoqda',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
