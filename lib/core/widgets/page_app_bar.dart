import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';
import '../theme/app_colors.dart';
import 'header_button.dart';

/// Flat app bar used by all tab pages: page background, no tint, bold title and
/// a shortcut to Do'stlar on the right.
///
/// That slot held the light/dark toggle until Do'stlar stopped being a tab.
/// The toggle itself is not lost — Profil has carried the same switch all
/// along, which is where the setting belongs.
class PageAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PageAppBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.showFriends = true,
    this.leading,
  });

  final Widget title;

  /// Replaces the automatic back button, e.g. to intercept a wizard step.
  final Widget? leading;
  final List<Widget> actions;

  /// Off wherever the theme toggle was already off, and on Do'stlar itself.
  final bool showFriends;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return AppBar(
      // The web's mobile header sits on the card surface with a hairline under
      // it, not on the page background.
      backgroundColor: c.bgCard,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: Border(bottom: BorderSide(color: c.border)),
      centerTitle: false,
      titleSpacing: 16,
      leading: leading,
      iconTheme: IconThemeData(color: c.textSecondary),
      titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary),
      title: title,
      actions: [
        if (showFriends) ...[
          HeaderButton(
            tooltip: "Do'stlar",
            onTap: () => context.push(Routes.friends),
            icon: Icons.people_alt_rounded,
            background: AppColors.tint(AppColors.brand, context.isDark ? 0x1F : 0x1A),
            border: AppColors.tint(AppColors.brand, 0x4D),
            iconColor: context.readable(AppColors.brand),
          ),
          const SizedBox(width: 8),
        ],
        ...actions,
        // The web's header keeps its px-4 gutter on the right.
        const SizedBox(width: 16),
      ],
    );
  }
}
