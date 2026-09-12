import 'package:flutter/material.dart';

/// Letter grade for a score percentage (same thresholds as the web results page).
class Grade {
  const Grade._(this.letter, this.label, this.color);

  /// `A+`, `A`, `B`, `C` or `D`.
  final String letter;

  /// Uzbek performance word shown beside the score, worded and bucketed as the
  /// web's `getPerformanceLabel`: A'lo ≥80, Yaxshi ≥60, Qoniqarli ≥40, Zaif.
  final String label;
  final Color color;

  /// Grade for [percent] in 0..100.
  /// Letter thresholds stay as they are (they label history cards); the word
  /// follows the web's four buckets.
  factory Grade.of(double percent) {
    if (percent >= 90) return const Grade._('A+', "A'lo", Color(0xFF22C55E));
    if (percent >= 80) return const Grade._('A', "A'lo", Color(0xFF34D399));
    if (percent >= 60) return const Grade._('B', 'Yaxshi', Color(0xFFFBBF24));
    if (percent >= 40) return const Grade._('C', 'Qoniqarli', Color(0xFFFB923C));
    return const Grade._('D', 'Zaif', Color(0xFFEF4444));
  }
}
