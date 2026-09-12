import 'package:flutter/material.dart';

/// EduNova design tokens, ported 1:1 from the web `ThemeContext.tsx`.
///
/// Access in widgets via `context.colors` (see [AppColorsX]).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bgBase,
    required this.bgCard,
    required this.bgInner,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.accentMuted,
    required this.accentBorder,
    required this.cardShadow,
  });

  // ── Brand & semantic colors (same in both themes) ──────────────────────
  static const brand = Color(0xFF6366F1); // indigo-500
  static const brandLight = Color(0xFF818CF8); // indigo-400
  static const brandDark = Color(0xFF4F46E5); // indigo-600
  static const violet = Color(0xFF8B5CF6);
  static const purple = Color(0xFF7C3AED);
  static const blue = Color(0xFF3B82F6);
  static const sky = Color(0xFF38BDF8);
  static const emerald = Color(0xFF34D399); // the web's "Test yaratish" accent
  static const success = Color(0xFF22C55E);
  static const error = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);

  /// Gradient used on the top accent bar of cards (login, dialogs).
  static const accentBarGradient = LinearGradient(colors: [brand, violet, blue]);

  /// Logo tile gradient.
  static const logoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [purple, brand],
  );

  // ── Surfaces & text (theme dependent) ─────────────────────────────────
  final Color bgBase;
  final Color bgCard;
  final Color bgInner;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color accentMuted;
  final Color accentBorder;

  /// The web's `shadowCard`. Light cards are lifted off the page; dark ones
  /// only get a faint depth shadow, which is why the two themes read so
  /// differently when it is missing.
  final List<BoxShadow> cardShadow;

  static const dark = AppColors(
    bgBase: Color(0xFF0F172A),
    bgCard: Color(0xFF1E293B),
    bgInner: Color(0xFF0F172A),
    border: Color(0xFF334155),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFF94A3B8),
    textMuted: Color(0xFF64748B),
    accent: brandLight,
    accentMuted: Color(0x1A6366F1), // rgba(99,102,241,0.10)
    accentBorder: Color(0x336366F1), // rgba(99,102,241,0.20)
    cardShadow: [BoxShadow(color: Color(0x4D000000), blurRadius: 24, offset: Offset(0, 4))],
  );

  static const light = AppColors(
    bgBase: Color(0xFFF8FAFC),
    bgCard: Color(0xFFFFFFFF),
    bgInner: Color(0xFFF1F5F9),
    border: Color(0xFFE2E8F0),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF64748B),
    textMuted: Color(0xFF94A3B8),
    accent: brand,
    accentMuted: Color(0x146366F1), // rgba(99,102,241,0.08)
    accentBorder: Color(0x336366F1),
    cardShadow: [
      BoxShadow(color: Color(0x0F0F172A), blurRadius: 3, offset: Offset(0, 1)),
      BoxShadow(color: Color(0x0A0F172A), blurRadius: 12, offset: Offset(0, 4)),
    ],
  );

  /// Soft translucent background for a colored icon/badge (≈12% alpha).
  static Color tint(Color color, [int alpha = 0x1F]) => color.withAlpha(alpha);

  @override
  AppColors copyWith({
    Color? bgBase,
    Color? bgCard,
    Color? bgInner,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? accent,
    Color? accentMuted,
    Color? accentBorder,
    List<BoxShadow>? cardShadow,
  }) {
    return AppColors(
      bgBase: bgBase ?? this.bgBase,
      bgCard: bgCard ?? this.bgCard,
      bgInner: bgInner ?? this.bgInner,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      accent: accent ?? this.accent,
      accentMuted: accentMuted ?? this.accentMuted,
      accentBorder: accentBorder ?? this.accentBorder,
      cardShadow: cardShadow ?? this.cardShadow,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      bgBase: mix(bgBase, other.bgBase),
      bgCard: mix(bgCard, other.bgCard),
      bgInner: mix(bgInner, other.bgInner),
      border: mix(border, other.border),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      textMuted: mix(textMuted, other.textMuted),
      accent: mix(accent, other.accent),
      accentMuted: mix(accentMuted, other.accentMuted),
      accentBorder: mix(accentBorder, other.accentBorder),
      cardShadow: t < 0.5 ? cardShadow : other.cardShadow,
    );
  }
}

/// Shortcuts to the EduNova theme from a [BuildContext].
extension AppColorsX on BuildContext {
  /// Current EduNova color tokens.
  AppColors get colors => Theme.of(this).extension<AppColors>() ?? AppColors.dark;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
