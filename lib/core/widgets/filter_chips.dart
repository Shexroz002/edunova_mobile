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
    this.wrap = false,
    this.segmented = false,
  });

  final List<FilterOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final EdgeInsetsGeometry padding;

  /// Lets the chips flow onto a second line instead of scrolling out of sight.
  /// The web does this on a narrow screen, where a clipped chip reads as a
  /// layout bug rather than something scrollable.
  final bool wrap;

  /// Splits the width evenly between the options, like a segmented control.
  /// For a short, fixed set this beats both scrolling and wrapping on a phone:
  /// everything stays visible on one line and the targets get wider.
  final bool segmented;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final pills = [
      for (final option in options)
        _Pill(
          label: option.label,
          icon: option.icon,
          active: option.value == selected,
          onTap: () => onSelected(option.value),
          colors: c,
          compact: segmented,
        ),
    ];

    if (segmented) {
      return Padding(
        padding: padding,
        child: Row(
          children: [
            for (var i = 0; i < pills.length; i++) ...[
              Expanded(child: pills[i]),
              if (i < pills.length - 1) const SizedBox(width: 8),
            ],
          ],
        ),
      );
    }

    if (wrap) {
      return Padding(
        padding: padding,
        child: Wrap(spacing: 8, runSpacing: 8, children: pills),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (final pill in pills) ...[pill, const SizedBox(width: 8)],
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
    this.compact = false,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final AppColors colors;
  final IconData? icon;

  /// Tightens the paddings so three chips fit one phone row.
  final bool compact;

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
          padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: compact ? 14 : 16, color: foreground),
                SizedBox(width: compact ? 5 : 6),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 12 : 13,
                    fontWeight: FontWeight.w600,
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
