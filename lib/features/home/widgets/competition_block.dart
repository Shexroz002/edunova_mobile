import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';

/// Creating a competition and joining one, side by side.
///
/// They used to sit apart: a "Musobaqa" card here, and a "Jonli sessiya" tile
/// in the action grid. That tile calls `joinByCode()` and lands in the same
/// lobby the card's flow creates, so it was joining a competition all along —
/// "jonli sessiya" is the backend's word for it (`multiplayer session`), not a
/// student's. Naming it properly put two "Musobaqa" blocks in two places, so
/// they are one block with two buttons.
class CompetitionBlock extends StatelessWidget {
  const CompetitionBlock({super.key, required this.onCreate, required this.onJoin});

  final VoidCallback onCreate;

  /// Opens the join-code sheet.
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final warning = context.readable(AppColors.warning);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.tint(AppColors.warning, 0x2B),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.emoji_events_rounded, size: 20, color: warning),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Musobaqa',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Do‘stlaringiz bilan bellashing',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: c.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _Button(
                    icon: Icons.emoji_events_rounded,
                    label: 'Yaratish',
                    onTap: onCreate,
                    filled: true,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: _Button(
                    icon: Icons.sensors_rounded,
                    label: 'Kod bilan kirish',
                    onTap: onJoin,
                    filled: false,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.filled,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  /// `brand` under white text reaches only 4.1:1; `brandDark` clears 6:1 and is
  /// the same indigo one step down.
  static const _fill = AppColors.brandDark;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = filled ? Colors.white : context.readable(AppColors.brand);

    return Material(
      color: filled ? _fill : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: filled ? null : Border.all(color: c.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: tone),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tone),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
