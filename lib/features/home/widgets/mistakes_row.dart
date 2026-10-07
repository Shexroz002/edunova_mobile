import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../mistakes/domain/mistake_models.dart';

/// The way into the mistake bank.
///
/// Hidden only while the bank is empty — a row about nothing would be a daily
/// reminder of nothing. Once there are questions in it the row stays, quietly,
/// even on a day with nothing due: it is the only way into the bank, and
/// hiding it would make the screen unreachable.
class MistakesRow extends StatelessWidget {
  const MistakesRow({super.key, required this.overview, required this.onTap});

  final MistakeOverview overview;

  final VoidCallback onTap;

  bool get _due => overview.due > 0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final warning = context.readable(AppColors.warning);
    final tone = _due ? warning : c.textMuted;
    final next = overview.nextDueAt;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _due
                  ? AppColors.tint(AppColors.warning, 0x2B)
                  : AppColors.tint(c.textMuted, 0x24),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.refresh_rounded, size: 20, color: tone),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Xatolarim',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _due
                      ? '${overview.due} ta savol bugun takrorlashga tayyor'
                      : next == null
                          ? '${overview.total} ta savol navbatda'
                          : '${overview.total} ta savol · '
                              '${formatUntil(next)} qaytadi',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: _due ? FontWeight.w700 : FontWeight.w400,
                    color: tone,
                  ),
                ),
              ],
            ),
          ),
          // The badge counts what is waiting, so a quiet day carries none.
          if (_due) ...[
            const SizedBox(width: 9),
            Container(
              constraints: const BoxConstraints(minWidth: 26),
              height: 26,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: AppColors.brandDark,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Center(
                widthFactor: 1,
                child: Text(
                  '${overview.due}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, size: 20, color: c.textMuted),
        ],
      ),
    );
  }
}
