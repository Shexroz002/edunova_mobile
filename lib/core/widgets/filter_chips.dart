import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// One option of [FilterChips].
class FilterOption<T> {
  const FilterOption(this.value, this.label, {this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// Horizontally scrollable single-select pill chips (web "Barchasi / Eng yaxshi..." style).
class FilterChips<T> extends StatelessWidget {
  const FilterChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.padding = EdgeInsets.zero,
  });

  final List<FilterOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (final option in options) ...[
            _Pill(
              label: option.label,
              icon: option.icon,
              active: option.value == selected,
              onTap: () => onSelected(option.value),
              colors: c,
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.active,
    required this.onTap,
    required this.colors,
    this.icon,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final AppColors colors;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final foreground = active ? colors.accent : colors.textSecondary;
    return Material(
      color: active ? colors.accentMuted : colors.bgCard,
      shape: StadiumBorder(side: BorderSide(color: active ? colors.accentBorder : colors.border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: foreground),
                const SizedBox(width: 6)
              ],
              Text(
                label,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
