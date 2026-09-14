"""Shared building blocks for the EduNova chat artboards."""

from gen_tokens import FONT, BRAND, VIOLET, BLUE, SKY, EMERALD, SUCCESS, ERROR, WARNING

W, H = 390, 844

# ── Icons ────────────────────────────────────────────────────────────────
# Stroke-based, 24px grid, one consistent style.
PATHS = {
    "back": '<path d="M15 18l-6-6 6-6"/>',
    "search": '<circle cx="11" cy="11" r="7"/><path d="M20.5 20.5L16.9 16.9"/>',
    "compose": '<path d="M4 20h16"/><path d="M14.5 4.5l3 3L8 17l-4 1 1-4z"/>',
    "info": '<circle cx="12" cy="12" r="9"/><path d="M12 11v5"/><path d="M12 7.6v.9"/>',
    "send": '<path d="M21 3L3 10.5l7.2 2.9L13.5 21z"/><path d="M10.2 13.4L21 3"/>',
    "attach": '<path d="M20 11.5l-7.8 7.8a4.5 4.5 0 01-6.4-6.4l8.2-8.2a3 3 0 014.2 4.2l-8.1 8.1a1.5 1.5 0 01-2.1-2.1l7.4-7.4"/>',
    "mic": '<rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 11a7 7 0 0014 0"/><path d="M12 18v3"/>',
    "smile": '<circle cx="12" cy="12" r="9"/><path d="M8.5 14.5a4.5 4.5 0 007 0"/><path d="M9 9.5v.6"/><path d="M15 9.5v.6"/>',
    "check": '<path d="M4 12.5l5 5L20 6.5"/>',
    "checks": '<path d="M2 12.5l4.5 4.5L15 8.5"/><path d="M9.5 15.2L11 16.8 19.5 8"/>',
    "clock": '<circle cx="12" cy="12" r="9"/><path d="M12 7.5V12l3 2"/>',
    "play": '<path d="M8 5.5l10 6.5-10 6.5z"/>',
    "users": '<circle cx="9" cy="8" r="3.4"/><path d="M3 19a6 6 0 0112 0"/><path d="M16 5.2a3.4 3.4 0 010 5.6"/><path d="M17.5 14.4A6 6 0 0121 19"/>',
    "reply": '<path d="M9 7L4 12l5 5"/><path d="M4 12h9a6 6 0 016 6v1"/>',
    "forward": '<path d="M15 7l5 5-5 5"/><path d="M20 12h-9a6 6 0 00-6 6v1"/>',
    "pencil": '<path d="M14.5 4.5l5 5L9 20l-5.5 1.5L5 16z"/><path d="M13 6l5 5"/>',
    "copy": '<rect x="9" y="9" width="11" height="11" rx="2.5"/><path d="M15 6.5A2.5 2.5 0 0012.5 4H6.5A2.5 2.5 0 004 6.5v6A2.5 2.5 0 006.5 15"/>',
    "trash": '<path d="M4 7h16"/><path d="M9.5 7V5h5v2"/><path d="M6.5 7l1 13h9l1-13"/>',
    "pin": '<path d="M9 3h6l-1 6 4 3.5V15H6v-2.5L10 9z"/><path d="M12 15v6"/>',
    "close": '<path d="M6 6l12 12"/><path d="M18 6L6 18"/>',
    "refresh": '<path d="M20 12a8 8 0 11-2.6-5.9"/><path d="M20 4v4.5h-4.5"/>',
    "offline": '<path d="M3 3l18 18"/><path d="M8.5 15.5a5 5 0 016 0"/><path d="M5 12a10 10 0 013.2-2.2"/><path d="M19 12a10 10 0 00-7.6-2.9"/><path d="M12 19.5v.01"/>',
    "alert": '<path d="M12 4l9 16H3z"/><path d="M12 10v4"/><path d="M12 17v.01"/>',
    "lock": '<rect x="4.5" y="10" width="15" height="10" rx="2.5"/><path d="M8 10V7.5a4 4 0 018 0V10"/>',
    "chat": '<path d="M20 12a7.5 7.5 0 01-10.9 6.7L4 20l1.4-4.6A7.5 7.5 0 1120 12z"/>',
    "doc": '<path d="M14 3H7.5A2.5 2.5 0 005 5.5v13A2.5 2.5 0 007.5 21h9a2.5 2.5 0 002.5-2.5V8z"/><path d="M14 3v5h5"/>',
    "image": '<rect x="3.5" y="4.5" width="17" height="15" rx="2.5"/><circle cx="9" cy="10" r="1.8"/><path d="M20 16l-4.5-4.5L6 20"/>',
    "video": '<rect x="3" y="6" width="12.5" height="12" rx="2.5"/><path d="M15.5 11l5.5-3v8l-5.5-3z"/>',
    "music": '<path d="M9 18V6l10-2v12"/><circle cx="6.5" cy="18" r="2.5"/><circle cx="16.5" cy="16" r="2.5"/>',
    "chevron": '<path d="M9 6l6 6-6 6"/>',
    "exit": '<path d="M14 4h4.5A1.5 1.5 0 0120 5.5v13a1.5 1.5 0 01-1.5 1.5H14"/><path d="M10 8l-4 4 4 4"/><path d="M6 12h9"/>',
    "plus": '<path d="M12 5v14"/><path d="M5 12h14"/>',
}


def icon(name, size=22, color="currentColor", sw=1.8):
    """One inline SVG icon from [PATHS]."""
    return (
        f'<svg width="{size}" height="{size}" viewBox="0 0 24 24" fill="none" '
        f'stroke="{color}" stroke-width="{sw}" stroke-linecap="round" '
        f'stroke-linejoin="round" style="flex:0 0 auto;display:block">{PATHS[name]}</svg>'
    )


def solid_icon(name, size=22, color="currentColor"):
    """Filled variant, used for the play triangle."""
    return (
        f'<svg width="{size}" height="{size}" viewBox="0 0 24 24" fill="{color}" '
        f'stroke="none" style="flex:0 0 auto;display:block">{PATHS[name]}</svg>'
    )


# ── Avatars ──────────────────────────────────────────────────────────────
# Never green: the presence dot is SUCCESS green and must stay readable on top.
AVATAR_TINTS = {
    "ST": (BRAND, "#FFFFFF"),
    "DK": (VIOLET, "#FFFFFF"),
    "BR": (SKY, "#082F49"),
    "NY": (BLUE, "#FFFFFF"),
    "AK": (WARNING, "#3B2600"),
    "MG": ("#4F46E5", "#FFFFFF"),
}


def avatar(initials, size=48, online=None, t=None, ring=False):
    """Initials avatar with an optional presence dot.

    `online=True` paints the green dot, `False` a muted one, `None` none.
    """
    bg, fg = AVATAR_TINTS.get(initials, (BRAND, "#FFFFFF"))
    font = max(11, int(size * 0.36))
    dot = ""
    if online is not None:
        d = max(10, int(size * 0.26))
        color = SUCCESS if online else t["textMuted"]
        dot = (
            f'<span style="position:absolute;right:-1px;bottom:-1px;width:{d}px;'
            f'height:{d}px;border-radius:50%;background:{color};'
            f'border:2.5px solid {t["bgCard"]};box-sizing:border-box"></span>'
        )
    border = f'box-shadow:0 0 0 2px {t["accentBorder"]};' if ring else ""
    return (
        f'<span style="position:relative;flex:0 0 auto;width:{size}px;height:{size}px">'
        f'<span style="display:flex;align-items:center;justify-content:center;'
        f'width:{size}px;height:{size}px;border-radius:50%;background:{bg};color:{fg};'
        f'font-size:{font}px;font-weight:700;letter-spacing:0.3px;{border}">{initials}</span>'
        f'{dot}</span>'
    )


def group_avatar(size=48, t=None):
    """Indigo tile used for group chats."""
    return (
        f'<span style="display:flex;align-items:center;justify-content:center;flex:0 0 auto;'
        f'width:{size}px;height:{size}px;border-radius:50%;'
        f'background:linear-gradient(135deg,{VIOLET},{BRAND})">'
        f'{icon("users", int(size * 0.5), "#FFFFFF", 1.9)}</span>'
    )


# ── Chrome ───────────────────────────────────────────────────────────────
def shell(t, body, bg=None, h=None):
    """The phone root. No fake status bar: the OS draws the real one."""
    return (
        f'<div style="width:{W}px;height:{h or H}px;background:{bg or t["bgBase"]};'
        f'color:{t["textPrimary"]};font-family:{FONT};display:flex;'
        f'flex-direction:column;overflow:hidden;position:relative;'
        f'-webkit-font-smoothing:antialiased">{body}</div>'
    )


def appbar(t, title, subtitle=None, leading=None, actions="", avatar_html=None):
    """Top bar matching PageAppBar: 56dp row over a 1px border."""
    lead = leading if leading is not None else icon("back", 24, t["textPrimary"], 2)
    av = avatar_html or ""
    sub = ""
    if subtitle:
        sub = (f'<div style="font-size:12px;color:{subtitle[1]};margin-top:1px;'
               f'font-weight:500">{subtitle[0]}</div>')
    return (
        f'<div style="display:flex;align-items:center;gap:12px;padding:14px 12px 12px 12px;'
        f'background:{t["bgCard"]};border-bottom:1px solid {t["border"]};flex:0 0 auto">'
        f'<span style="display:flex;align-items:center;justify-content:center;width:40px;'
        f'height:40px;margin:-8px -6px -8px -4px">{lead}</span>'
        f'{av}'
        f'<div style="flex:1 1 auto;min-width:0">'
        f'<div style="font-size:17px;font-weight:700;letter-spacing:-0.2px;'
        f'white-space:nowrap;overflow:hidden;text-overflow:ellipsis">{title}</div>{sub}</div>'
        f'<div style="display:flex;align-items:center;gap:4px">{actions}</div>'
        f'</div>'
    )


def action_btn(t, name, color=None, size=22):
    """44dp tap target around an app-bar icon."""
    return (
        f'<span style="display:flex;align-items:center;justify-content:center;'
        f'width:44px;height:44px">{icon(name, size, color or t["textSecondary"], 1.9)}</span>'
    )


def badge(count, t):
    """Unread pill."""
    text = "99+" if count > 99 else str(count)
    pad = "0 6px" if count > 9 else "0"
    return (
        f'<span style="display:inline-flex;align-items:center;justify-content:center;'
        f'min-width:22px;height:22px;padding:{pad};border-radius:11px;background:{BRAND};'
        f'color:#FFFFFF;font-size:11.5px;font-weight:700">{text}</span>'
    )


def divider(t, inset=76):
    return (f'<div style="height:1px;background:{t["border"]};margin-left:{inset}px;'
            f'flex:0 0 auto"></div>')


def section_label(t, text):
    return (
        f'<div style="padding:16px 16px 8px 16px;font-size:12px;font-weight:700;'
        f'letter-spacing:0.6px;text-transform:uppercase;color:{t["textMuted"]}">{text}</div>'
    )
