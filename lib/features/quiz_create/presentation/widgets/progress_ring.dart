import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Circular progress with its own label in the middle.
///
/// Two arcs are drawn: the value arc, which animates to each new percentage,
/// and a faint sweep that keeps turning while the job runs. Without the sweep
/// the ring looks frozen between the backend's steps, which are up to forty
/// seconds apart.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.percent,
    required this.color,
    required this.trackColor,
    required this.child,
    this.size = 134,
    this.stroke = 10,
    this.spinning = true,
  });

  final int percent;
  final Color color;
  final Color trackColor;

  /// Rendered in the middle of the ring.
  final Widget child;

  final double size;
  final double stroke;

  /// Turn the sweep off once the job is finished.
  final bool spinning;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(end: percent / 100),
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            builder: (_, value, __) => CustomPaint(
              size: Size.square(size),
              painter: _RingPainter(value: value, color: color, track: trackColor, stroke: stroke),
            ),
          ),
          if (spinning) _Sweep(size: size, stroke: stroke, color: color),
          child,
        ],
      ),
    );
  }
}

/// The turning hint arc.
class _Sweep extends StatefulWidget {
  const _Sweep({required this.size, required this.stroke, required this.color});

  final double size;
  final double stroke;
  final Color color;

  @override
  State<_Sweep> createState() => _SweepState();
}

class _SweepState extends State<_Sweep> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _SweepPainter(color: widget.color, stroke: widget.stroke),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.value,
    required this.color,
    required this.track,
    required this.stroke,
  });

  final double value;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2 + 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;

    canvas.drawArc(arc, 0, 2 * math.pi, false, base);
    if (value <= 0) return;

    canvas.drawArc(
      arc,
      -math.pi / 2,
      2 * math.pi * value,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.track != track;
}

class _SweepPainter extends CustomPainter {
  const _SweepPainter({required this.color, required this.stroke});

  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final arc = (Offset.zero & size).deflate(stroke / 2 + 2);
    canvas.drawArc(
      arc,
      -math.pi / 2,
      math.pi / 6,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.42),
    );
  }

  @override
  bool shouldRepaint(_SweepPainter old) => old.color != color;
}
