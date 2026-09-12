import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Indigo gradient call to action, as used across the web student pages.
///
/// Falls back to a muted filled button when disabled, so a blocked action still
/// reads as a button rather than disappearing.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.enabled = true,
    this.loading = false,
    this.height = 50,
    this.gradient = brandGradient,
  });

  /// `#6366F1 → #A78BFA`, the gradient the web uses for primary actions.
  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.brand, Color(0xFFA78BFA)],
  );

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool enabled;
  final bool loading;
  final double height;
  final LinearGradient gradient;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final active = enabled && !loading;

    return Material(
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: active ? gradient : null,
          color: active ? null : c.bgInner,
        ),
        child: InkWell(
          onTap: active ? onPressed : null,
          child: SizedBox(
            height: height,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                else if (icon != null)
                  Icon(icon, size: 20, color: active ? Colors.white : c.textMuted),
                if (loading || icon != null) const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: active || loading ? Colors.white : c.textMuted,
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
}
