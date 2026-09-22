import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// The page's single primary action: start a test.
///
/// It used to be 173 dp, most of it a decorative ▶ circle, an "ASOSIY" eyebrow
/// and a subtitle that repeated the title. The page also offered a second way
/// in — the "Testlar — barcha testlarni oching" tile directly beneath it — so
/// neither read as primary. That tile moved into the action row; this card is
/// now the only hero, at 130 dp.
class PlayHero extends StatelessWidget {
  const PlayHero({super.key, required this.onStart, this.isFirstTest = false});

  final VoidCallback onStart;

  /// Names the moment for a student who has not taken a test yet.
  final bool isFirstTest;

  @override
  Widget build(BuildContext context) {
    // The web runs a three-stop gradient that ends in blue, and opens on a
    // different colour per theme; a flat indigo-to-purple pair reads far more
    // purple than the site.
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
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.play_arrow_rounded, size: 27, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isFirstTest ? 'Birinchi testingiz' : 'Test ishlash',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Fan va vaqtni tanlang',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.white.withValues(alpha: 0.80),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow_rounded, size: 19, color: Color(0xFF4338CA)),
                      SizedBox(width: 7),
                      Text(
                        'Boshlash',
                        style: TextStyle(
                          fontSize: 14.5,
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
