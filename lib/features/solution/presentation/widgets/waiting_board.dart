import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'solution_tex.dart';

/// The board while a solution is being written: chalk lines, a pencil at the
/// edge of the line being written, symbols drifting at the side.
///
/// The formulas are well-known school ones, never the student's own problem:
/// they say "something is being written" without looking like an answer.
/// With reduced motion switched on the board stands still.
class WaitingBoard extends StatefulWidget {
  const WaitingBoard({super.key, required this.physics});

  final bool physics;

  @override
  State<WaitingBoard> createState() => _WaitingBoardState();
}

class _WaitingBoardState extends State<WaitingBoard> with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _clock
        ..stop()
        ..value = 0.75;
    } else if (!_clock.isAnimating) {
      _clock.repeat();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  List<String> get _lines => widget.physics
      ? const [r'F = m \cdot a', r'v = \frac{s}{t}', r'E = mgh']
      : const [r'D = b^2 - 4ac', r'a^2 + b^2 = c^2', r'x = \frac{-b \pm \sqrt{D}}{2a}'];

  List<String> get _symbols => widget.physics ? const ['F', 'g', 'Δ'] : const ['√', 'π', '∑'];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final drift = AppColors.tint(context.readable(AppColors.brand), 0x66);
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 168,
        decoration: BoxDecoration(
          color: c.bgInner,
          gradient: RadialGradient(
            center: const Alignment(0, -1.3),
            radius: 1.25,
            colors: [AppColors.tint(AppColors.brand, 0x3D), AppColors.tint(AppColors.brand, 0x00)],
          ),
          border: Border.all(color: AppColors.tint(AppColors.brand, 0x5C)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: AnimatedBuilder(
          animation: _clock,
          builder: (context, _) {
            final t = _clock.value;
            // The last line writes itself out over three quarters of a cycle,
            // holds, then starts again.
            final reveal = t < 0.75 ? 0.12 + 0.88 * (t / 0.75) : 1.0;
            final wave = math.sin(t * 2 * math.pi * 3);
            return Stack(
              children: [
                for (final (i, (dx, dy, size)) in const [(22.0, 14.0, 26.0), (64.0, 108.0, 21.0), (16.0, 76.0, 20.0)].indexed)
                  Positioned(
                    right: dx,
                    top: dy + 5 * math.sin((t + i / 3) * 2 * math.pi),
                    child: Transform.rotate(
                      angle: 0.07 * math.sin((t + i / 3) * 2 * math.pi),
                      child: Text(
                        _symbols[i],
                        style: TextStyle(fontFamily: 'serif', fontSize: size, color: drift),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 60, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BoardFormula(_lines[0], size: 18),
                      BoardFormula(_lines[1], size: 18),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: ClipRect(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                widthFactor: reveal,
                                child: BoardFormula(_lines[2], size: 18),
                              ),
                            ),
                          ),
                          Transform.translate(
                            offset: Offset(1.5 * wave, -2.5 * wave.abs()),
                            child: Transform.rotate(
                              angle: -0.12 * wave,
                              child: const Text('✏️', style: TextStyle(fontSize: 20)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // A light sweeping along the bottom edge: the board is busy.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 3,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(-3 + 6 * t, 0),
                        end: Alignment(-1 + 6 * t, 0),
                        colors: [
                          AppColors.tint(AppColors.brand, 0x00),
                          AppColors.brand,
                          AppColors.violet,
                          AppColors.tint(AppColors.violet, 0x00),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
