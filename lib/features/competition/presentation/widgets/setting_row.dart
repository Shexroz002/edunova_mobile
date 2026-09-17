import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// One competition setting: its current value, a stepper and the presets.
///
/// Both settings arrive with a usable default, so nothing is hidden behind a
/// step that has to be opened — the value and the way to change it are on
/// screen from the first frame.
class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.note,
    required this.value,
    required this.unit,
    required this.min,
    required this.max,
    required this.step,
    required this.presets,
    required this.onChanged,
  });

  final IconData icon;
  final Color color;
  final String label;

  /// Short characterisation of the current value, e.g. `Kichik guruh`.
  final String note;

  final int value;
  final String unit;
  final int min;
  final int max;
  final int step;
  final List<int> presets;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final accent = context.readable(color);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.tint(accent, 0x29),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: AppColors.tint(accent, 0x52)),
              ),
              child: Icon(icon, size: 18, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(note, style: TextStyle(fontSize: 12, color: c.textMuted)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _Stepper(
              value: value,
              unit: unit,
              accent: accent,
              onMinus: value > min ? () => onChanged((value - step).clamp(min, max)) : null,
              onPlus: value < max ? () => onChanged((value + step).clamp(min, max)) : null,
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Full width rather than indented under the label: the five presets
        // need 267 dp and an indent left only 268, so the last one wrapped.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in presets)
              _Preset(
                value: preset,
                selected: preset == value,
                accent: accent,
                onTap: () => onChanged(preset),
              ),
          ],
        ),
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.unit,
    required this.accent,
    required this.onMinus,
    required this.onPlus,
  });

  final int value;
  final String unit;
  final Color accent;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RoundButton(icon: Icons.remove_rounded, accent: accent, onTap: onMinus),
        const SizedBox(width: 6),
        SizedBox(
          width: 48,
          child: Column(
            children: [
              Text(
                '$value',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 17,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  color: c.textPrimary,
                ),
              ),
              Text(
                unit,
                maxLines: 1,
                style: TextStyle(fontSize: 10.5, color: c.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        _RoundButton(icon: Icons.add_rounded, accent: accent, onTap: onPlus),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.accent, required this.onTap});

  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onTap != null;

    return Material(
      color: enabled ? AppColors.tint(accent, 0x29) : c.bgInner,
      borderRadius: BorderRadius.circular(13),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: enabled ? AppColors.tint(accent, 0x57) : c.border),
          ),
          child: Icon(icon, size: 18, color: enabled ? accent : c.textMuted),
        ),
      ),
    );
  }
}

class _Preset extends StatelessWidget {
  const _Preset({
    required this.value,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final int value;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Material(
      color: selected ? AppColors.tint(accent, 0x24) : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 40,
          // The floor keeps a one-digit preset at 44 dp without an `alignment`,
          // which would stretch the chip across the whole Wrap row.
          constraints: const BoxConstraints(minWidth: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? AppColors.tint(accent, 0x8C) : c.border),
          ),
          child: Center(
            widthFactor: 1,
            child: Text(
              '$value',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? accent : c.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
