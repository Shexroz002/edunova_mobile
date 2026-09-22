import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// One tile in [QuickActions].
class QuickAction {
  const QuickAction({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;

  /// One or two words: the tiles sit side by side, so a sentence will not fit.
  final String label;

  final VoidCallback onTap;
}

/// The page's secondary actions, one row of tiles.
///
/// This was a 2 × 2 grid of 146 dp tiles — 292 dp — because each one carried a
/// description ("PDF yoki AI orqali test yarating"). Those are read once and
/// are in the way every day after. Icon and label alone fit one row at 88 dp,
/// and every tile stays far above the 44 dp target.
class QuickActions extends StatelessWidget {
  const QuickActions({super.key, required this.actions});

  final List<QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, action) in actions.indexed) ...[
            if (index > 0) const SizedBox(width: 9),
            Expanded(child: _Tile(action: action)),
          ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.action});

  final QuickAction action;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Material(
      color: c.bgCard,
      borderRadius: BorderRadius.circular(15),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: action.onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: c.border),
          ),
          padding: const EdgeInsets.fromLTRB(6, 11, 6, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.tint(action.color, 0x2B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(action.icon, size: 19, color: context.readable(action.color)),
              ),
              const SizedBox(height: 7),
              Text(
                action.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                  color: c.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
