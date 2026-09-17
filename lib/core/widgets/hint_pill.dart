import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Quiet explanatory note on its own surface.
///
/// Replaces the loose grey sentences that used to sit under cards: a hint that
/// matters enough to keep on screen also deserves a container, and a warning
/// tone when it is a caveat rather than a fact.
class HintPill extends StatelessWidget {
  const HintPill({super.key, required this.text, this.icon, this.tone});

  final String text;
  final IconData? icon;

  /// Colours the whole pill. Defaults to the neutral muted tone.
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final accent = tone == null ? c.textMuted : context.readable(tone!);
    final neutral = tone == null;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: neutral ? c.bgCard : AppColors.tint(accent, 0x1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: neutral ? c.border : AppColors.tint(accent, 0x52)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon ?? Icons.info_outline_rounded, size: 16, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, height: 1.5, color: accent),
            ),
          ),
        ],
      ),
    );
  }
}
