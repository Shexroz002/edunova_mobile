import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/state_views.dart';
import '../../competition/data/competition_repository.dart';
import '../data/notifications_repository.dart';
import '../domain/app_notification.dart';
import 'notifications_controller.dart';
import 'widgets/notification_tile.dart';

/// Notification list with filters, day grouping and live arrivals.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  NotificationFilter _filter = NotificationFilter.all;
  List<AppNotification> _items = const [];
  StreamSubscription<AppNotification>? _arrivals;
  bool _loading = true;
  bool _markingAll = false;
  int? _busyId;
  String? _error;

  /// Ids the student acted on, so the buttons disappear (no reject endpoint).
  final _acted = <int>{};

  /// Ids removed from the list locally (the backend has no delete endpoint).
  final _dismissed = <int>{};

  @override
  void initState() {
    super.initState();
    _load();
    // Pushed notifications prepend to the list while the screen is open.
    final stream = ref.read(notificationStreamProvider);
    _arrivals = stream?.arrivals.listen((notification) {
      if (!mounted) return;
      setState(() => _items = [notification, ..._items.where((n) => n.id != notification.id)]);
    });
  }

  @override
  void dispose() {
    _arrivals?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref.read(notificationsRepositoryProvider).fetchPage(page: 1, size: 100);
      if (!mounted) return;
      setState(() => _items = page.items);
      // The list is already here, so hand the badge the count instead of
      // making it fetch the same 100 rows again.
      ref.read(unreadCountProvider.notifier).setCount(page.items.where((n) => !n.isRead).length);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(AppNotification notification) async {
    if (notification.isRead) return;
    setState(() => _items = _replace(notification.copyWith(isRead: true)));
    try {
      await ref.read(notificationsRepositoryProvider).markRead(notification.id);
      ref.read(unreadCountProvider.notifier).setCount(_items.where((n) => !n.isRead).length);
    } on ApiException {
      // Put the unread badge back if the server refused.
      if (mounted) setState(() => _items = _replace(notification));
    }
  }

  Future<void> _markAllRead() async {
    setState(() => _markingAll = true);
    try {
      await ref.read(notificationsRepositoryProvider).markAllRead();
      if (!mounted) return;
      setState(() => _items = [for (final n in _items) n.copyWith(isRead: true)]);
      ref.read(unreadCountProvider.notifier).setCount(0);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  List<AppNotification> _replace(AppNotification updated) => [
        for (final n in _items)
          if (n.id == updated.id) updated else n
      ];

  Future<void> _accept(AppNotification notification) async {
    setState(() => _busyId = notification.id);
    try {
      switch (notification.kind) {
        case NotificationKind.testInvite:
          final code = notification.sessionCode;
          if (code == null) return;
          final sessionId = await ref.read(competitionRepositoryProvider).joinByCode(code);
          await _markRead(notification);
          if (mounted) context.push('/session/$sessionId/lobby');
        case NotificationKind.friendRequest:
          final friendId = notification.friendId;
          if (friendId == null) return;
          await ref.read(notificationsRepositoryProvider).acceptFriend(friendId);
          await _markRead(notification);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Do'st qo'shildi")),
            );
          }
        case NotificationKind.competitionResult:
        case NotificationKind.other:
          break;
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) {
        setState(() {
          _busyId = null;
          _acted.add(notification.id);
        });
      }
    }
  }

  /// "Ko'rish" on a competition result opens Natijalar and lets that page show
  /// the session's leaderboard, so the student lands where the result lives
  /// instead of getting a sheet stacked over the notification list.
  Future<void> _open(AppNotification notification) async {
    final sessionId = notification.resultSessionId;
    if (sessionId == null) return;
    await _markRead(notification);
    if (mounted) context.push('${Routes.results}?sessionId=$sessionId');
  }

  void _decline(AppNotification notification) {
    setState(() => _acted.add(notification.id));
    _markRead(notification);
  }

  /// Removes the row locally, exactly as the web's trash button does.
  void _dismiss(AppNotification notification) {
    setState(() => _dismissed.add(notification.id));
    if (!notification.isRead) _markRead(notification);
  }

  List<AppNotification> get _visible =>
      _items.where((n) => !_dismissed.contains(n.id) && _filter.matches(n.kind)).toList();

  @override
  Widget build(BuildContext context) {
    final unread = _visible.where((n) => !n.isRead).length;

    return Scaffold(
      appBar: const PageAppBar(title: Text('Bildirishnomalar')),
      // A full-screen route has neither a rail to narrow it nor a bottom bar of
      // its own, so the column is capped like a tab page and keeps clear of the
      // system navigation bar.
      body: SafeArea(
        top: false,
        child: ContentConstraint(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(context.pagePadding, 14, context.pagePadding, 14),
                child: _Header(
                  unread: unread,
                  busy: _markingAll,
                  onMarkAll: _markAllRead,
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(context.pagePadding, 0, context.pagePadding, 12),
                child: _FilterDropdown(
                  value: _filter,
                  onChanged: (value) => setState(() => _filter = value),
                ),
              ),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _items.isEmpty) return const LoadingView();
    final error = _error;
    if (error != null && _items.isEmpty) return ErrorView(message: error, onRetry: _load);

    final visible = _visible;
    if (visible.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: const [
            SizedBox(height: 80),
            EmptyView(
              icon: Icons.notifications_none_rounded,
              title: "Bildirishnomalar yo'q",
              subtitle: "Yangi bildirishnomalar paydo bo'lganda bu yerda ko'rinadi",
            ),
          ],
        ),
      );
    }

    // Group by day, exactly as the web does: BUGUN then OLDINGI.
    final today = visible.where((n) => isToday(n.createdAt)).toList();
    final earlier = visible.where((n) => !isToday(n.createdAt)).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          context.pagePadding,
          8,
          context.pagePadding,
          24,
        ),
        children: [
          if (today.isNotEmpty) ...[
            const _SectionLabel('BUGUN'),
            for (final n in today) _tile(n),
          ],
          if (earlier.isNotEmpty) ...[
            const _SectionLabel('OLDINGI'),
            for (final n in earlier) _tile(n),
          ],
        ],
      ),
    );
  }

  Widget _tile(AppNotification notification) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: NotificationTile(
          notification: notification,
          busy: _busyId == notification.id,
          actionsHidden: _acted.contains(notification.id),
          onOpen: () => _open(notification),
          onAccept: () => _accept(notification),
          onDecline: () => _decline(notification),
          onDismiss: () => _dismiss(notification),
        ),
      );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: context.colors.textMuted,
          ),
        ),
      );
}

/// Single-select filter, matching the web's dropdown above the list.
/// Unread count and the mark-all action, under the app bar.
///
/// The title itself lives in the app bar, beside the theme toggle, so this row
/// only carries the count and the button — which is why they fit one line on a
/// phone where the title plus the button never did.
class _Header extends StatelessWidget {
  const _Header({required this.unread, required this.busy, required this.onMarkAll});

  final int unread;
  final bool busy;
  final VoidCallback onMarkAll;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (unread == 0) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          "Hammasi o'qilgan",
          style: TextStyle(fontSize: 13, color: c.textMuted),
        ),
      );
    }

    return Row(
      children: [
        Text(
          '$unread ta yangi',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.accent),
        ),
        const Spacer(),
        _MarkAllButton(busy: busy, onTap: onMarkAll),
      ],
    );
  }
}

/// Tinted pill, as the web styles this action.
class _MarkAllButton extends StatelessWidget {
  const _MarkAllButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Material(
      color: c.accentMuted,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.accentBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: c.accent),
                )
              else
                Icon(Icons.done_all_rounded, size: 15, color: c.accent),
              const SizedBox(width: 7),
              Text(
                busy ? 'Kutilmoqda...' : "Barchasini o'qilgan qilish",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({required this.value, required this.onChanged});

  final NotificationFilter value;
  final ValueChanged<NotificationFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(Icons.filter_alt_outlined, size: 18, color: c.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<NotificationFilter>(
                value: value,
                isExpanded: true,
                borderRadius: BorderRadius.circular(14),
                dropdownColor: c.bgCard,
                icon: Icon(Icons.expand_more_rounded, color: c.textSecondary),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
                items: [
                  for (final filter in NotificationFilter.values)
                    DropdownMenuItem(value: filter, child: Text(filter.label)),
                ],
                onChanged: (selected) => selected == null ? null : onChanged(selected),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
