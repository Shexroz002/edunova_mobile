import 'package:flutter/material.dart';

import '../../../../core/network/media_url.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/brand.dart';
import '../../domain/app_notification.dart';

/// One notification, laid out like the web `StudentNotificationsPage.tsx`:
/// a coloured icon tile, the heading, an inset message panel, badge pills,
/// the actions, and a footer with the relative time and a dismiss button.
///
/// "Rad etish" and the dismiss button are local only — the backend has no
/// reject or delete endpoint, and the web does the same.
class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    required this.onOpen,
    required this.onAccept,
    required this.onDecline,
    required this.onDismiss,
    this.busy = false,
    this.actionsHidden = false,
  });

  final AppNotification notification;

  /// Opens the competition result.
  final VoidCallback onOpen;

  /// Joins a session invite, or accepts a friend request.
  final VoidCallback onAccept;

  /// Declines an invite or request (local only).
  final VoidCallback onDecline;

  /// Removes the notification from the list (local only).
  final VoidCallback onDismiss;

  final bool busy;

  /// True once the student has acted, so the buttons disappear.
  final bool actionsHidden;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final unread = !notification.isRead;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: unread ? c.accentMuted : c.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: unread ? c.accentBorder : c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (notification.senderName != null &&
              notification.kind != NotificationKind.competitionResult) ...[
            Row(
              children: [
                UserAvatar(
                  name: notification.senderName!,
                  imageUrl: MediaUrl.resolve(notification.senderImage),
                  size: 26,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    notification.senderName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconTile(kind: notification.kind),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.displayTitle,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _Body(notification: notification),
                    if (notification.kind == NotificationKind.testInvite &&
                        notification.sessionCode != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.description_outlined, size: 14, color: c.textMuted),
                          const SizedBox(width: 6),
                          Text(
                            'Kod: ${notification.sessionCode}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: c.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (notification.kind == NotificationKind.competitionResult) ...[
                      const SizedBox(height: 10),
                      _Badges(notification: notification),
                    ],
                    if (!actionsHidden && _hasActions) ...[
                      const SizedBox(height: 12),
                      _Actions(
                        notification: notification,
                        busy: busy,
                        onOpen: onOpen,
                        onAccept: onAccept,
                        onDecline: onDecline,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                formatRelative(notification.createdAt),
                style: TextStyle(fontSize: 12, color: c.textMuted),
              ),
              const Spacer(),
              InkWell(
                onTap: onDismiss,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.delete_outline_rounded, size: 18, color: c.textMuted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool get _hasActions => switch (notification.kind) {
        NotificationKind.competitionResult => notification.resultSessionId != null,
        NotificationKind.testInvite => notification.sessionCode != null,
        NotificationKind.friendRequest => notification.friendId != null,
        NotificationKind.other => false,
      };
}

/// Rounded square icon tile in the notification's accent colour.
class _IconTile extends StatelessWidget {
  const _IconTile({required this.kind});

  final NotificationKind kind;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (icon, color) = switch (kind) {
      NotificationKind.competitionResult => (Icons.emoji_events_rounded, AppColors.warning),
      NotificationKind.testInvite => (Icons.description_rounded, AppColors.brand),
      NotificationKind.friendRequest => (Icons.person_add_alt_rounded, AppColors.success),
      NotificationKind.other => (Icons.notifications_rounded, c.textMuted),
    };

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}

/// Inset message panel. Competition results get the web's congratulation
/// sentence with the quiz name and the place emphasised.
class _Body extends StatelessWidget {
  const _Body({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final base = TextStyle(fontSize: 13, height: 1.5, color: c.textSecondary);

    final Widget text;
    if (notification.kind == NotificationKind.competitionResult &&
        notification.quizTitle != null &&
        notification.rank != null) {
      text = Text.rich(
        TextSpan(
          style: base,
          children: [
            const TextSpan(text: 'Tabriklaymiz! Siz '),
            TextSpan(
              text: '“${notification.quizTitle}”',
              style: TextStyle(fontWeight: FontWeight.w700, color: c.textPrimary),
            ),
            const TextSpan(text: ' musobaqasida '),
            TextSpan(
              text: "${notification.rank}-o'rin",
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.warning),
            ),
            const TextSpan(text: 'ni egalladingiz.'),
          ],
        ),
      );
    } else {
      text = Text(notification.displayMessage, style: base);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.bgInner,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: text,
    );
  }
}

/// Medal and percentage pills under a competition result.
class _Badges extends StatelessWidget {
  const _Badges({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final medal = notification.medalLabel;
    final percent = notification.percentLabel;
    if (medal == null && percent == null) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (medal != null)
          _Badge(
            label: medal,
            color: AppColors.warning,
            leading: notification.rankMedal,
          ),
        if (percent != null) _Badge(label: percent, color: AppColors.brand),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color, this.leading});

  final String label;
  final Color color;
  final String? leading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[
            Text(leading!, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.notification,
    required this.busy,
    required this.onOpen,
    required this.onAccept,
    required this.onDecline,
  });

  final AppNotification notification;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    if (notification.kind == NotificationKind.competitionResult) {
      return Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: busy ? null : onOpen,
          icon: const Icon(Icons.visibility_outlined, size: 16),
          label: const Text("Ko'rish"),
          style: FilledButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
        ),
      );
    }

    // Side by side, as on the web. The labels are short enough to fit the
    // column left of the icon tile on a 360 dp phone.
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: busy ? null : onAccept,
            icon: const Icon(Icons.check_rounded, size: 15),
            label: Text(
              busy ? 'Kutilmoqda...' : 'Qabul qilish',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: busy ? null : onDecline,
            icon: const Icon(Icons.close_rounded, size: 15),
            label: const Text('Rad etish', maxLines: 1, overflow: TextOverflow.ellipsis),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
          ),
        ),
      ],
    );
  }
}
