import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Question difficulty, normalized from the backend's inconsistent strings
/// (`oson`, `o‘rta`, `o'rta`, `o'son`, `qiyin`, `easy`, `medium`, `hard`...).
enum Difficulty {
  easy,
  medium,
  hard,
  unknown;

  /// Parses any backend difficulty string; returns [unknown] for anything else.
  static Difficulty parse(String? raw) {
    if (raw == null) return Difficulty.unknown;
    final value = raw.toLowerCase().trim().replaceAll(RegExp("['‘’ʻʼ`]"), '');

    if (value.startsWith('oson') || value.startsWith('osn') || value == 'easy') {
      return Difficulty.easy;
    }
    if (value.contains('rta') || value == 'medium') return Difficulty.medium;
    if (value.startsWith('qiy') || value == 'hard') return Difficulty.hard;
    // "o'son" loses its apostrophe and becomes "oson" above; anything else is unknown.
    return Difficulty.unknown;
  }

  /// Uzbek label shown in chips.
  String get label => switch (this) {
        Difficulty.easy => 'Oson',
        Difficulty.medium => "O'rta",
        Difficulty.hard => 'Qiyin',
        Difficulty.unknown => "Noma'lum",
      };

  /// The spelling the backend stores, for `PUT /question/{id}/edit`.
  ///
  /// `unknown` maps to the medium value, since the column is a plain string and
  /// writing "unknown" back would make the question unclassifiable.
  String get apiValue => switch (this) {
        Difficulty.easy => 'oson',
        Difficulty.hard => 'qiyin',
        _ => "o'rta",
      };

  /// The three values a student can choose in the editor.
  static const editable = [Difficulty.easy, Difficulty.medium, Difficulty.hard];

  /// Accent color used by difficulty chips (same as the web).
  Color get color => switch (this) {
        Difficulty.easy => AppColors.success,
        Difficulty.medium => const Color(0xFFFBBF24),
        Difficulty.hard => AppColors.error,
        Difficulty.unknown => const Color(0xFF94A3B8),
      };
}
