import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/responsive.dart';
import '../chat/presentation/chat_list_controller.dart';

/// A bottom-nav / rail destination.
class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Adaptive root layout for signed-in students.
///
/// * Phone (< 600 dp): bottom [NavigationBar].
/// * Tablet (≥ 600 dp): [NavigationRail] on the left, extended on large screens.
///
/// Each tab keeps its own navigation stack (go_router `StatefulShellRoute`).
class StudentShell extends ConsumerWidget {
  const StudentShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// Order must match the branches in `app_router.dart`.
  static const _destinations = [
    _Destination('Bosh sahifa', Icons.space_dashboard_outlined, Icons.space_dashboard_rounded),
    _Destination('Guruhlar', Icons.school_outlined, Icons.school_rounded),
    _Destination("Do'stlar", Icons.people_outline_rounded, Icons.people_rounded),
    _Destination('Suhbatlar', Icons.forum_outlined, Icons.forum_rounded),
    _Destination('Statistika', Icons.bar_chart_outlined, Icons.bar_chart_rounded),
    _Destination('Profil', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  void _onSelect(int index) {
    // Tapping the active tab again pops it back to its root page.
    navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Unread chats badge the Suhbatlar tab from anywhere in the app.
    final unread = ref.watch(chatUnreadTotalProvider);
    return context.isTablet
        ? _buildTablet(context, unread)
        : _buildPhone(context, unread);
  }

  /// Wraps a destination icon in a count badge (Suhbatlar only).
  Widget _icon(int index, IconData icon, int unread) {
    if (index != _chatIndex || unread == 0) return Icon(icon);
    return Badge(
      label: Text(unread > 99 ? '99+' : '$unread'),
      backgroundColor: AppColors.brand,
      child: Icon(icon),
    );
  }

  /// Index of the Suhbatlar tab in [_destinations].
  static const _chatIndex = 3;

  Widget _buildPhone(BuildContext context, int unread) {
    final c = context.colors;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _onSelect,
          destinations: [
            for (final (index, d) in _destinations.indexed)
              NavigationDestination(
                icon: _icon(index, d.icon, unread),
                selectedIcon: _icon(index, d.selectedIcon, unread),
                label: d.label,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTablet(BuildContext context, int unread) {
    final c = context.colors;
    final extended = context.isLargeScreen;

    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            right: false,
            // The rail lays its brand and five destinations out in a Column that
            // does not scroll, so a short viewport (landscape phone, or a tablet
            // with the keyboard open) overflows it. Letting it scroll while
            // still filling the full height keeps every destination reachable.
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: NavigationRail(
                      extended: extended,
                      minExtendedWidth: 220,
                      selectedIndex: navigationShell.currentIndex,
                      onDestinationSelected: _onSelect,
                      labelType:
                          extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                      leading: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: extended ? const BrandTitle(size: 30) : const BrandMark(size: 36),
                      ),
                      destinations: [
                        for (final (index, d) in _destinations.indexed)
                          NavigationRailDestination(
                            icon: _icon(index, d.icon, unread),
                            selectedIcon: _icon(index, d.selectedIcon, unread),
                            label: Text(d.label),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          VerticalDivider(width: 1, thickness: 1, color: c.border),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}
