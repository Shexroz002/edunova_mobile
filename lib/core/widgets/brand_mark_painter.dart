import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Draws the EduNova mark: an open book under a four-pointed nova spark.
///
/// The same geometry as the launcher icon, so the app and the home screen show
/// one logo. Kept as a painter rather than an asset so it stays sharp at every
/// size and can take any colour.
class BrandMarkPainter extends CustomPainter {
  const BrandMarkPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final s = size.shortestSide;
    final cx = size.width / 2;

    _book(canvas, paint, cx, size.height * 0.615, s * 0.56);
    _spark(canvas, paint, cx, size.height * 0.295, s * 0.155);
  }

  /// Two pages meeting at a central spine.
  void _book(Canvas canvas, Paint paint, double cx, double cy, double w) {
    final h = w * 0.52;
    final gap = w * 0.045;

    for (final sign in [-1.0, 1.0]) {
      final path = Path()
        ..moveTo(cx + gap * sign, cy - h * 0.34)
        ..lineTo(cx + w * 0.5 * sign, cy - h * 0.56)
        ..lineTo(cx + w * 0.5 * sign, cy + h * 0.44)
        ..lineTo(cx + gap * sign, cy + h * 0.66)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  /// Four-pointed spark with a narrow waist.
  void _spark(Canvas canvas, Paint paint, double cx, double cy, double r) {
    const waist = 0.26;
    final k = r * waist;
    final path = Path();

    for (var i = 0; i < 4; i++) {
      final tip = (90 * i - 90) * math.pi / 180;
      final side = tip + math.pi / 4;
      final tipPoint = Offset(cx + r * math.cos(tip), cy + r * math.sin(tip));
      final sidePoint = Offset(cx + k * math.cos(side), cy + k * math.sin(side));
      if (i == 0) {
        path.moveTo(tipPoint.dx, tipPoint.dy);
      } else {
        path.lineTo(tipPoint.dx, tipPoint.dy);
      }
      path.lineTo(sidePoint.dx, sidePoint.dy);
    }
    canvas.drawPath(path..close(), paint);
  }

  @override
  bool shouldRepaint(BrandMarkPainter oldDelegate) => oldDelegate.color != color;
}
