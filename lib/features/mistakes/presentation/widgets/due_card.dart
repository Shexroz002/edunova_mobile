import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/mistake_models.dart';

/// The one action of the bank screen: start today's review.
///
/// Phrased as a count rather than a score, because a review is practice: it
/// writes nothing to Natijalar and does not move the student's average.
class DueCard extends StatelessWidget {
  const DueCard({super.key, required this.overview, required this.onStart});

  final MistakeOverview overview;
  final VoidCallback onStart;

  /// "Matematika 6 · Fizika 4", longest queue first.
  String get _breakdown => overview.subjects
      .where((s) => s.due > 0)
      .take(3)
      .map((s) => '${s.subject} ${s.due}')
      .join(' · ');

  @override
  Widget build(BuildContext context) {
    final gradient = context.isDark
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4C1D95), Color(0xFF6366F1), Color(0xFF3B82F6)],
            stops: [0, 0.55, 1],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6366F1), Color(0xFF4F46E5), Color(0xFF3B82F6)],
            stops: [0, 0.60, 1],
          );

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(color: Color(0x4D6366F1), blurRadius: 24, offset: Offset(0, 6)),
          ],
        ),
        child: InkWell(
          onTap: onStart,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'BUGUN TAKRORLASH',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${overview.due} ta savol',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                    color: Colors.white,
                  ),
                ),
                if (_breakdown.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    _breakdown,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Container(
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF4338CA)),
                      SizedBox(width: 8),
                      Text(
                        'Takrorlashni boshlash',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF4338CA),
                        ),
                      ),
                    ],
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
