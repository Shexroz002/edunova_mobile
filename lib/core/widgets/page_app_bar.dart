import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme/app_colors.dart';
import 'header_button.dart';

/// Flat app bar used by all tab pages: page background, no tint,
/// bold title and a light/dark toggle on the right.
class PageAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const PageAppBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.showThemeToggle = true,
    this.leading,
  });

  final Widget title;

  /// Replaces the automatic back button, e.g. to intercept a wizard step.
  final Widget? leading;
  final List<Widget> actions;
  final bool showThemeToggle;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final isDark = context.isDark;

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
        if (showThemeToggle) ...[
          // The web puts the theme toggle first, then the bell.
          // Amber tile with an indigo moon in light mode, indigo tile with an
          // amber sun in dark — exactly how the web flips it.
          HeaderButton(
            tooltip: 'Mavzuni almashtirish',
            onTap: ref.read(themeModeProvider.notifier).toggle,
            icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            background: AppColors.tint(
              isDark ? AppColors.brand : AppColors.warning,
              isDark ? 0x1F : 0x1A,
            ),
            border: AppColors.tint(isDark ? AppColors.brand : AppColors.warning, 0x4D),
            iconColor: isDark ? const Color(0xFFFBBF24) : AppColors.brand,
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
