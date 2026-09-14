"""Message bubbles and the composer."""

from gen_tokens import BRAND, SKY, EMERALD, ERROR, WARNING, SUCCESS
from gen_parts import icon, solid_icon, avatar

MAXW = 268


def ticks(t, state, out=True):
    """Delivery state: clock = queued, check = server ack, checks = read."""
    color = t["bubbleOutMeta"] if out else t["textMuted"]
    if state == "read":
        return icon("checks", 15, "#A5F3FC" if out else t["accent"], 2)
    if state == "sent":
        return icon("check", 15, color, 2)
    if state == "pending":
        return icon("clock", 13, color, 2)
    return ""


def meta(t, time, state=None, out=True, edited=False):
    """Time + optional 'tahrirlangan' + delivery ticks."""
    color = t["bubbleOutMeta"] if out else t["textMuted"]
    ed = (f'<span style="font-size:11px;color:{color}">tahrirlangan</span>'
          f'<span style="font-size:11px;color:{color}">·</span>') if edited else ""
    return (
        f'<div style="display:flex;align-items:center;justify-content:flex-end;gap:4px;'
        f'margin-top:3px">{ed}'
        f'<span style="font-size:11px;color:{color};font-variant-numeric:tabular-nums">{time}</span>'
        f'{ticks(t, state, out) if state else ""}</div>'
    )


def quote(t, name, text, out=False):
    """Reply preview inside a bubble."""
    bg = t["quoteBgOut"] if out else t["quoteBg"]
    bar = "#FFFFFF" if out else t["accent"]
    nm = "#FFFFFF" if out else t["accent"]
    tx = t["bubbleOutMeta"] if out else t["textSecondary"]
    return (
        f'<div style="display:flex;gap:8px;padding:6px 8px;margin-bottom:6px;'
        f'border-radius:8px;background:{bg};overflow:hidden">'
        f'<span style="flex:0 0 auto;width:3px;border-radius:2px;background:{bar}"></span>'
        f'<span style="min-width:0">'
        f'<span style="display:block;font-size:12.5px;font-weight:700;color:{nm}">{name}</span>'
        f'<span style="display:block;font-size:12.5px;color:{tx};white-space:nowrap;'
        f'overflow:hidden;text-overflow:ellipsis">{text}</span></span></div>'
    )


def fwd_header(t, name, out=False):
    """'Uzatilgan' header, from the message's forwarded_from object."""
    c = "#FFFFFF" if out else t["accent"]
    sub = t["bubbleOutMeta"] if out else t["textSecondary"]
    return (
        f'<div style="display:flex;align-items:center;gap:5px;margin-bottom:5px">'
        f'{icon("forward", 13, c, 2)}'
        f'<span style="font-size:12px;font-weight:600;color:{c}">Uzatilgan:</span>'
        f'<span style="font-size:12px;color:{sub}">{name}</span></div>'
    )


def reactions(t, items, out=False):
    """Reaction pills, one per emoji with its user_ids count."""
    pills = ""
    for emoji, count, mine in items:
        bg = t["accentMuted"] if mine else (t["bgInner"] if not out else t["bgCard"])
        bd = t["accent"] if mine else t["border"]
        pills += (
            f'<span style="display:inline-flex;align-items:center;gap:4px;height:26px;'
            f'padding:0 8px;border-radius:13px;background:{bg};border:1px solid {bd}">'
            f'<span style="font-size:13px;line-height:1">{emoji}</span>'
            f'<span style="font-size:12px;font-weight:600;color:{t["textPrimary"]};'
            f'font-variant-numeric:tabular-nums">{count}</span></span>'
        )
    justify = "flex-end" if out else "flex-start"
    return (f'<div style="display:flex;gap:5px;margin-top:5px;justify-content:{justify}">'
            f'{pills}</div>')


def bubble(t, *, out, body, time=None, state=None, edited=False, reacts=None,
           tail=True, pad="9px 12px", av=None, highlight=False):
    """One message row: optional avatar + bubble + reactions."""
    if out:
        bg, fg, bd = t["bubbleOut"], t["bubbleOutText"], "transparent"
        radius = f'16px {"4px" if tail else "16px"} 16px 16px'
        align = "flex-end"
    else:
        bg, fg, bd = t["bubbleIn"], t["textPrimary"], t["bubbleInBorder"]
        radius = f'{"4px" if tail else "16px"} 16px 16px 16px'
        align = "flex-start"

    glow = (f'box-shadow:0 0 0 2px {t["accent"]},0 8px 24px rgba(99,102,241,0.35);'
            if highlight else f'box-shadow:{t["cardShadow"]};')
    inner = (
        f'<div style="max-width:{MAXW}px;padding:{pad};border-radius:{radius};'
        f'background:{bg};color:{fg};border:1px solid {bd};{glow}'
        f'font-size:14.5px;line-height:1.42;word-break:break-word">'
        f'{body}{meta(t, time, state, out, edited) if time else ""}</div>'
    )
    react = reactions(t, reacts, out) if reacts else ""
    col = (f'<div style="display:flex;flex-direction:column;align-items:{align};'
           f'min-width:0">{inner}{react}</div>')

    if av and not out:
        return (f'<div style="display:flex;align-items:flex-end;gap:8px;'
                f'justify-content:flex-start">{av}{col}</div>')
    return (f'<div style="display:flex;justify-content:{align}">{col}</div>')


def text_bubble(t, text, **kw):
    return bubble(t, body=f'<div>{text}</div>', **kw)


def deleted_bubble(t, out, time):
    """A soft-deleted message: the server keeps the row, the client greys it out."""
    body = (
        f'<div style="display:flex;align-items:center;gap:6px;font-style:italic;'
        f'font-size:13.5px;color:{t["textMuted"]}">'
        f'{icon("trash", 14, t["textMuted"], 1.8)}Xabar o\'chirildi</div>'
    )
    bd = t["border"]
    align = "flex-end" if out else "flex-start"
    radius = "16px 4px 16px 16px" if out else "4px 16px 16px 16px"
    return (
        f'<div style="display:flex;justify-content:{align}">'
        f'<div style="max-width:{MAXW}px;padding:9px 12px;border-radius:{radius};'
        f'background:transparent;border:1px dashed {bd}">{body}'
        f'<div style="text-align:right;font-size:11px;color:{t["textMuted"]};'
        f'margin-top:2px">{time}</div></div></div>'
    )


def day_pill(t, text):
    return (
        f'<div style="display:flex;justify-content:center;margin:4px 0 2px 0">'
        f'<span style="padding:4px 12px;border-radius:12px;background:{t["bgCard"]};'
        f'border:1px solid {t["border"]};font-size:11.5px;font-weight:600;'
        f'color:{t["textSecondary"]}">{text}</span></div>'
    )


def unread_line(t, text="O'qilmagan xabarlar"):
    """Marker drawn at the reader's last_read_message_id cursor."""
    return (
        f'<div style="display:flex;align-items:center;gap:10px;margin:6px 0 2px 0">'
        f'<span style="flex:1;height:1px;background:{t["accentBorder"]}"></span>'
        f'<span style="font-size:11px;font-weight:700;color:{t["accent"]};'
        f'letter-spacing:0.3px">{text}</span>'
        f'<span style="flex:1;height:1px;background:{t["accentBorder"]}"></span></div>'
    )


def typing_bubble(t, av):
    """typing:update from another member."""
    dots = "".join(
        f'<span style="width:6px;height:6px;border-radius:50%;'
        f'background:{t["textMuted"]};opacity:{o}"></span>' for o in (1, 0.6, 0.3)
    )
    return (
        f'<div style="display:flex;align-items:flex-end;gap:8px">{av}'
        f'<div style="display:flex;align-items:center;gap:4px;padding:12px 14px;'
        f'border-radius:4px 16px 16px 16px;background:{t["bubbleIn"]};'
        f'border:1px solid {t["bubbleInBorder"]}">{dots}</div></div>'
    )


def composer(t, placeholder="Xabar yozing...", reply=None):
    """Input row. Mic shows while the field is empty, send once there is text."""
    rep = ""
    if reply:
        rep = (
            f'<div style="display:flex;align-items:center;gap:10px;padding:8px 12px;'
            f'border-bottom:1px solid {t["border"]}">'
            f'{icon("reply", 17, t["accent"], 2)}'
            f'<span style="flex:1;min-width:0">'
            f'<span style="display:block;font-size:12.5px;font-weight:700;'
            f'color:{t["accent"]}">{reply[0]}</span>'
            f'<span style="display:block;font-size:12.5px;color:{t["textSecondary"]};'
            f'white-space:nowrap;overflow:hidden;text-overflow:ellipsis">{reply[1]}</span></span>'
            f'{icon("close", 18, t["textMuted"], 2)}</div>'
        )
    return (
        f'<div style="flex:0 0 auto;background:{t["composer"]};'
        f'border-top:1px solid {t["border"]}">{rep}'
        f'<div style="display:flex;align-items:flex-end;gap:8px;padding:8px 10px 14px 10px">'
        f'<span style="display:flex;align-items:center;justify-content:center;width:44px;'
        f'height:44px">{icon("attach", 23, t["textSecondary"], 1.9)}</span>'
        f'<div style="flex:1;display:flex;align-items:center;gap:8px;min-height:44px;'
        f'padding:0 8px 0 14px;border-radius:22px;background:{t["bgInner"]};'
        f'border:1px solid {t["border"]}">'
        f'<span style="flex:1;font-size:14.5px;color:{t["textMuted"]}">{placeholder}</span>'
        f'{icon("smile", 21, t["textMuted"], 1.9)}</div>'
        f'<span style="display:flex;align-items:center;justify-content:center;width:44px;'
        f'height:44px;border-radius:22px;background:{BRAND}">'
        f'{icon("mic", 22, "#FFFFFF", 1.9)}</span></div></div>'
    )
