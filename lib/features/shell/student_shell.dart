import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/responsive.dart';

/// A bottom-nav / rail destination.
class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon, {String? short})
      : shortLabel = short ?? label;

  final String label;

  /// The phone bar shows "Asosiy" where the rail has room for the full wording.
  final String shortLabel;

  final IconData icon;
  final IconData selectedIcon;
}

/// Adaptive root layout for signed-in students.
///
/// * Phone (< 600 dp): bottom [NavigationBar].
/// * Tablet (≥ 600 dp): [NavigationRail] on the left, extended on large screens.
///
/// Each tab keeps its own navigation stack (go_router `StatefulShellRoute`).
class StudentShell extends StatelessWidget {
  const StudentShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// Order must match the branches in `app_router.dart`.
  ///
  /// Guruhlar, Do'stlar and Suhbatlar used to sit here too. They are full-screen
  /// pages now: Do'stlar opens from the header button on every tab page, and
  /// private chats open from a friend's row.
  static const _destinations = [
    _Destination(
      'Bosh sahifa',
      Icons.space_dashboard_outlined,
      Icons.space_dashboard_rounded,
      short: 'Asosiy',
    ),
    _Destination('Statistika', Icons.bar_chart_outlined, Icons.bar_chart_rounded),
    _Destination('Profil', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  void _onSelect(int index) {
    // Tapping the active tab again pops it back to its root page.
    navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    return context.isTablet ? _buildTablet(context) : _buildPhone(context);
  }

  Widget _buildPhone(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
        // Six labels used to share this width, so they wrapped onto a second
        // line and collided once the reader raised the system font size, and the
        // bar had to be held back from scaling. Three have room to scale freely.
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _onSelect,
          destinations: [
            for (final d in _destinations)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: d.shortLabel,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTablet(BuildContext context) {
    final c = context.colors;
    final extended = context.isLargeScreen;

    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            right: false,
            // The rail lays its brand and destinations out in a Column that does
            // not scroll, so a short viewport (landscape phone, or a tablet with
            // the keyboard open) overflows it. Letting it scroll while still
            // filling the full height keeps every destination reachable.
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
                        child: extended ? const BrandTitle(size: 34) : const BrandMark(size: 36),
                      ),
                      destinations: [
                        for (final d in _destinations)
                          NavigationRailDestination(
                            icon: Icon(d.icon),
                            selectedIcon: Icon(d.selectedIcon),
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
