import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/header_button.dart';
import '../notifications_controller.dart';

/// App-bar bell that opens the notification list and shows the unread count.
///
/// The count is seeded from the REST list and then kept live by the
/// `notification_count_update` frames of `/ws/notifications/{userId}`.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final unread = ref.watch(unreadCountProvider);

    return HeaderButton(
      tooltip: 'Bildirishnomalar',
      onTap: () => context.push('/notifications'),
      icon: Icons.notifications_none_rounded,
      iconColor: c.textSecondary,
      badge: unread > 0 ? const HeaderDot() : null,
    );
  }
}
