import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 44×44 bordered square button used by the header actions.
///
/// Ported from the web's mobile header (`StudentLayout.tsx`): a `rounded-xl`
/// tile with a 1 px border, rather than a bare icon. The web draws it at 36 dp;
/// both Material and iOS ask for 44 as the smallest comfortable target, and the
/// icon inside stays the same size.
class HeaderButton extends StatelessWidget {
  const HeaderButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.background,
    this.border,
    this.iconColor,
    this.badge,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  /// Defaults to the page-inner surface, as the web's `bgButton` does.
  final Color? background;
  final Color? border;
  final Color? iconColor;

  /// Drawn over the top-right corner, e.g. the unread dot.
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Material(
          color: background ?? c.bgInner,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              clipBehavior: Clip.none,
              // Without this the bordered box shrinks to the icon and the Stack
              // parks it in the top-left corner instead of the middle.
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: border ?? c.border),
                  ),
                  child: Center(
                    child: Icon(icon, size: 17, color: iconColor ?? c.textSecondary),
                  ),
                ),
                if (badge != null) Positioned(top: 8, right: 8, child: badge!),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small red dot with a ring in the header colour, as on the web.
class HeaderDot extends StatelessWidget {
  const HeaderDot({super.key, this.size = 8});

  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.error,
        shape: BoxShape.circle,
        border: Border.all(color: c.bgCard, width: 2),
      ),
    );
  }
}
