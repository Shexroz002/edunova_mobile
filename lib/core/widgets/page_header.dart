import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';

/// In-page header used by the full-screen student pages: a bordered back
/// button, the page title and a muted subtitle.
///
/// The web puts this inside the page rather than in the top bar, so the app bar
/// stays free for the shell. On a phone it also keeps the title readable at two
/// lines instead of truncating it into an app bar.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
    this.titleMaxLines = 2,
  });

  final String title;
  final String? subtitle;

  /// Defaults to popping the route.
  final VoidCallback? onBack;

  /// Optional action shown at the end of the row.
  final Widget? trailing;

  final int titleMaxLines;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SquareIconButton(
          icon: Icons.arrow_back_rounded,
          tooltip: 'Orqaga',
          onPressed: onBack ?? () => context.pop(),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: titleMaxLines,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  color: c.textPrimary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: c.textMuted),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 10), trailing!],
      ],
    );
  }
}

/// 44×44 bordered icon button, the affordance the web uses beside page titles.
class SquareIconButton extends StatelessWidget {
  const SquareIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.filled = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final button = Material(
      color: filled ? AppColors.brand : c.bgCard,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: filled ? AppColors.brand : c.border, width: 1.5),
          ),
          child: Icon(
            icon,
            size: 18,
            color: filled ? Colors.white : c.textSecondary,
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
