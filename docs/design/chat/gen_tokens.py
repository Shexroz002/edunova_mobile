"""Design tokens lifted verbatim from lib/core/theme/app_colors.dart."""

DARK = {
    "name": "Dark",
    "bgBase": "#0F172A",
    "bgCard": "#1E293B",
    "bgInner": "#0F172A",
    "border": "#334155",
    "textPrimary": "#F8FAFC",
    "textSecondary": "#94A3B8",
    "textMuted": "#64748B",
    "accent": "#818CF8",
    "accentMuted": "rgba(99,102,241,0.10)",
    "accentBorder": "rgba(99,102,241,0.20)",
    "cardShadow": "0 4px 24px rgba(0,0,0,0.30)",
    # Chat-specific surfaces derived from the tokens above.
    "bubbleIn": "#1E293B",
    "bubbleInBorder": "#334155",
    "bubbleOut": "#4F46E5",
    "bubbleOutText": "#FFFFFF",
    "bubbleOutMeta": "rgba(255,255,255,0.62)",
    "quoteBg": "rgba(15,23,42,0.55)",
    "quoteBgOut": "rgba(0,0,0,0.18)",
    "composer": "#0F172A",
    "sheet": "#1E293B",
    "scrim": "rgba(2,6,23,0.72)",
    "skeleton": "#243244",
}

LIGHT = {
    "name": "Light",
    "bgBase": "#F8FAFC",
    "bgCard": "#FFFFFF",
    "bgInner": "#F1F5F9",
    "border": "#E2E8F0",
    "textPrimary": "#0F172A",
    "textSecondary": "#64748B",
    "textMuted": "#94A3B8",
    "accent": "#6366F1",
    "accentMuted": "rgba(99,102,241,0.08)",
    "accentBorder": "rgba(99,102,241,0.20)",
    "cardShadow": "0 1px 3px rgba(15,23,42,0.06), 0 4px 12px rgba(15,23,42,0.04)",
    "bubbleIn": "#FFFFFF",
    "bubbleInBorder": "#E2E8F0",
    "bubbleOut": "#6366F1",
    "bubbleOutText": "#FFFFFF",
    "bubbleOutMeta": "rgba(255,255,255,0.70)",
    "quoteBg": "rgba(241,245,249,0.90)",
    "quoteBgOut": "rgba(255,255,255,0.18)",
    "composer": "#FFFFFF",
    "sheet": "#FFFFFF",
    "scrim": "rgba(15,23,42,0.40)",
    "skeleton": "#E8EDF3",
}

# Brand + semantic colours are identical in both themes.
BRAND = "#6366F1"
VIOLET = "#8B5CF6"
BLUE = "#3B82F6"
SKY = "#38BDF8"
EMERALD = "#34D399"
SUCCESS = "#22C55E"
ERROR = "#EF4444"
WARNING = "#F59E0B"

FONT = ("-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, "
        "'Helvetica Neue', Arial, sans-serif")
