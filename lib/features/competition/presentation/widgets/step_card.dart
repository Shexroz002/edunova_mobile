import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// One numbered step of the competition flow.
///
/// Mirrors the web's `StepCard`: a coloured number badge, title, subtitle and
/// the step's control. A finished step collapses to a single summary row that
/// can be tapped to reopen it — on a phone that keeps the whole flow on one
/// screen instead of pushing the call to action far down.
class StepCard extends StatelessWidget {
  const StepCard({
    super.key,
    required this.step,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.done,
    required this.expanded,
    required this.onTap,
    this.summary,
    this.child,
  });

  final int step;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  /// True once the step has a value.
  final bool done;

  /// True while the step's control is shown.
  final bool expanded;

  /// Reopens a collapsed step.
  final VoidCallback onTap;

  /// One-line recap shown while collapsed.
  final String? summary;

  /// The step's control, shown while expanded.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: expanded ? color.withValues(alpha: 0.4) : c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: expanded ? null : onTap,
            borderRadius: BorderRadius.circular(10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: done ? 1 : 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: done
                      ? const Icon(Icons.check_rounded, size: 20, color: Colors.white)
                      : Icon(icon, size: 19, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$step-qadam',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        expanded ? subtitle : (summary ?? subtitle),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: expanded ? c.textMuted : c.textSecondary,
                          fontWeight: expanded ? FontWeight.w400 : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!expanded) Icon(Icons.edit_outlined, size: 18, color: c.textMuted),
              ],
            ),
          ),
          if (expanded && child != null) ...[
            const SizedBox(height: 16),
            child!,
          ],
        ],
      ),
    );
  }
}

/// Number control used by the participant and duration steps.
///
/// The web pairs preset buttons with a typed number; on a phone the typed field
/// is replaced by a minus/plus stepper so the keyboard never has to open.
class NumberStepper extends StatelessWidget {
  const NumberStepper({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.presets,
    required this.unit,
    required this.color,
    required this.onChanged,
    this.helperText,
  });

  final int value;
  final int min;
  final int max;
  final int step;
  final List<int> presets;
  final String unit;
  final Color color;
  final ValueChanged<int> onChanged;
  final String? helperText;

  void _nudge(int delta) => onChanged((value + delta).clamp(min, max));

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: c.bgInner,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              _RoundButton(
                icon: Icons.remove_rounded,
                color: color,
                onPressed: value > min ? () => _nudge(-step) : null,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '$value',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                      ),
                    ),
                    Text(
                      unit,
                      style: TextStyle(fontSize: 12, color: c.textMuted),
                    ),
                  ],
                ),
              ),
              _RoundButton(
                icon: Icons.add_rounded,
                color: color,
                onPressed: value < max ? () => _nudge(step) : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in presets)
              ChoiceChip(
                label: Text('$preset'),
                selected: preset == value,
                onSelected: (_) => onChanged(preset),
                showCheckmark: false,
                selectedColor: color.withValues(alpha: 0.14),
                side: BorderSide(color: preset == value ? color : c.border),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: preset == value ? color : c.textSecondary,
                ),
              ),
          ],
        ),
        if (helperText != null) ...[
          const SizedBox(height: 10),
          Text(helperText!, style: TextStyle(fontSize: 12, color: c.textMuted)),
        ],
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.color, required this.onPressed});

  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final c = context.colors;

    return Material(
      color: enabled ? color.withValues(alpha: 0.14) : c.bgCard,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, size: 22, color: enabled ? color : c.textMuted),
        ),
      ),
    );
  }
}
