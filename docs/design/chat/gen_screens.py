"""The seven chat artboards, rendered for either theme."""

from gen_tokens import BRAND, VIOLET, SKY, EMERALD, SUCCESS, ERROR, WARNING
from gen_parts import (W, H, icon, solid_icon, avatar, group_avatar, shell, appbar,
                       action_btn, badge, divider, section_label)
MEDIA_H = 1080
STATES_H = 940

from gen_bubbles import (bubble, text_bubble, deleted_bubble, day_pill, unread_line,
                         typing_bubble, composer, quote, fwd_header, meta, ticks,
                         reactions, MAXW)


def scroll(t, children, pad="10px 16px 12px 16px", gap=8, bg=None):
    return (f'<div style="flex:1 1 auto;overflow:hidden;display:flex;'
            f'flex-direction:column;gap:{gap}px;padding:{pad};'
            f'background:{bg or t["bgBase"]}">{children}</div>')


def search_field(t, placeholder="Qidirish"):
    return (
        f'<div style="padding:10px 16px 6px 16px;background:{t["bgCard"]}">'
        f'<div style="display:flex;align-items:center;gap:9px;height:42px;padding:0 12px;'
        f'border-radius:12px;background:{t["bgInner"]};border:1px solid {t["border"]}">'
        f'{icon("search", 18, t["textMuted"], 1.9)}'
        f'<span style="font-size:14.5px;color:{t["textMuted"]}">{placeholder}</span>'
        f'</div></div>'
    )


# ── 1. Suhbatlar ─────────────────────────────────────────────────────────
def chat_row(t, av, title, preview, time, *, unread=0, state=None, typing=False,
             muted_preview=False, kind=None):
    if typing:
        prev = (f'<span style="font-size:13.5px;color:{t["accent"]};font-weight:600">'
                f'yozmoqda...</span>')
    else:
        color = t["textMuted"] if muted_preview else t["textSecondary"]
        tick = (f'<span style="display:inline-flex;margin-right:4px;vertical-align:-2px">'
                f'{ticks(t, state, out=False)}</span>') if state else ""
        if kind:
            tick += (f'<span style="display:inline-flex;margin-right:5px;'
                     f'vertical-align:-3px">{icon(kind, 15, t["textMuted"], 1.9)}</span>')
        prev = (f'<span style="font-size:13.5px;color:{color};white-space:nowrap;'
                f'overflow:hidden;text-overflow:ellipsis;display:block">{tick}{preview}</span>')
    right = badge(unread, t) if unread else ""
    return (
        f'<div style="display:flex;align-items:center;gap:12px;padding:10px 16px;'
        f'background:{t["bgCard"]}">{av}'
        f'<div style="flex:1 1 auto;min-width:0;display:flex;flex-direction:column;gap:3px">'
        f'<div style="display:flex;align-items:baseline;gap:8px">'
        f'<span style="flex:1;min-width:0;font-size:15.5px;font-weight:650;'
        f'white-space:nowrap;overflow:hidden;text-overflow:ellipsis;'
        f'color:{t["textPrimary"]}">{title}</span>'
        f'<span style="font-size:11.5px;color:{t["textMuted"]};flex:0 0 auto">{time}</span>'
        f'</div>'
        f'<div style="display:flex;align-items:center;gap:8px">'
        f'<span style="flex:1;min-width:0">{prev}</span>{right}</div>'
        f'</div></div>'
    )


def screen_chats(t):
    rows = "".join([
        chat_row(t, avatar("ST", 52, True, t), "Shehroz Toshpo'latov", "", "14:32",
                 unread=3, typing=True),
        divider(t),
        chat_row(t, group_avatar(52, t), "Matematika 10-A",
                 "Aziz: Uy vazifasi yuklandi", "13:58", unread=12),
        divider(t),
        chat_row(t, avatar("DK", 52, False, t), "Dilnoza Karimova",
                 "Rahmat! Ertaga ko'rishamiz", "13:05", state="read"),
        divider(t),
        chat_row(t, avatar("BR", 52, True, t), "Bekzod Rahimov",
                 "Rasm", "Kecha", state="sent", kind="image"),
        divider(t),
        chat_row(t, avatar("NY", 52, False, t), "Nodira Yusupova",
                 "Ovozli xabar · 0:14", "Dush", muted_preview=True, kind="mic"),
        divider(t),
        chat_row(t, avatar("AK", 52, False, t), "Aziz Karimov",
                 "Xabar o'chirildi", "12-sen", muted_preview=True),
    ])
    body = (
        appbar(t, "Suhbatlar",
               actions=action_btn(t, "search") + action_btn(t, "compose", t["accent"]))
        + search_field(t)
        + f'<div style="flex:1 1 auto;overflow:hidden;background:{t["bgCard"]}">{rows}</div>'
    )
    return shell(t, body, bg=t["bgCard"])


# ── 2. Suhbat ────────────────────────────────────────────────────────────
def screen_room(t):
    av_sm = avatar("ST", 30, None, t)
    msgs = "".join([
        day_pill(t, "9-sentabr"),
        text_bubble(t, "Salom! Bugungi test bo'yicha savolim bor edi.",
                    out=False, time="14:20", av=av_sm),
        text_bubble(t, "Albatta, so'rang.", out=True, time="14:21", state="read"),
        bubble(t, out=False, av=av_sm, time="14:23",
               body=quote(t, "Siz", "Albatta, so'rang.")
               + "<div>3-savolda javob varianti xato ko'rinadi. Tekshirib bera olasizmi?</div>",
               reacts=[("❤️", 1, True)]),
        text_bubble(t, "Tekshirdim — hammasi to'g'ri, shart matnini diqqat bilan o'qing.",
                    out=True, time="14:25", state="read", edited=True),
        unread_line(t),
        bubble(t, out=False, av=av_sm, time="14:31",
               body=fwd_header(t, "Aziz Karimov")
               + "<div>Ertangi darsga 12-mavzuni tayyorlab kelinglar.</div>"),
        deleted_bubble(t, out=True, time="14:32"),
        typing_bubble(t, av_sm),
    ])
    header_av = avatar("ST", 38, True, t)
    body = (
        appbar(t, "Shehroz Toshpo'latov", subtitle=("onlayn", SUCCESS),
               avatar_html=header_av, actions=action_btn(t, "info"))
        + scroll(t, msgs)
        + composer(t)
    )
    return shell(t, body)


# ── 3. Biriktirmalar ─────────────────────────────────────────────────────
def media_frame(t, inner, w=214, h=142):
    return (f'<div style="width:{w}px;height:{h}px;border-radius:12px;overflow:hidden;'
            f'position:relative;background:{t["bgInner"]};'
            f'border:1px solid {t["border"]}">{inner}</div>')


def placeholder_art(t, tint):
    """Marked placeholder: no real photo ships in the mockup."""
    return (
        f'<div style="width:100%;height:100%;display:flex;align-items:center;'
        f'justify-content:center;background:linear-gradient(135deg,{tint}33,{tint}14)">'
        f'{icon("image", 30, tint, 1.6)}</div>'
    )


def file_tile(t, name, sub, tint, ico, out=False):
    fg = "#FFFFFF" if out else t["textPrimary"]
    sub_c = t["bubbleOutMeta"] if out else t["textSecondary"]
    return (
        f'<div style="display:flex;align-items:center;gap:11px;width:214px">'
        f'<span style="display:flex;align-items:center;justify-content:center;flex:0 0 auto;'
        f'width:42px;height:42px;border-radius:11px;background:{tint}26;'
        f'border:1px solid {tint}59">{icon(ico, 21, tint, 1.9)}</span>'
        f'<span style="min-width:0;flex:1">'
        f'<span style="display:block;font-size:14px;font-weight:600;color:{fg};'
        f'white-space:nowrap;overflow:hidden;text-overflow:ellipsis">{name}</span>'
        f'<span style="display:block;font-size:12px;color:{sub_c};margin-top:1px">{sub}</span>'
        f'</span></div>'
    )


def waveform(t, color, bars=26, played=10):
    import math
    spans = ""
    for i in range(bars):
        hgt = 5 + int(13 * abs(math.sin(i * 1.1)) )
        c = color if i < played else f'{color}59'
        spans += (f'<span style="width:2.5px;height:{hgt}px;border-radius:2px;'
                  f'background:{c}"></span>')
    return (f'<span style="display:flex;align-items:center;gap:2.5px;height:22px;'
            f'flex:1">{spans}</span>')


def screen_media(t):
    av_sm = avatar("BR", 30, None, t)
    voice_body = (
        f'<div style="display:flex;align-items:center;gap:10px;width:214px">'
        f'<span style="display:flex;align-items:center;justify-content:center;'
        f'width:36px;height:36px;border-radius:18px;background:#FFFFFF29;flex:0 0 auto">'
        f'{solid_icon("play", 17, "#FFFFFF")}</span>'
        f'{waveform(t, "#FFFFFF")}'
        f'<span style="font-size:11.5px;color:{t["bubbleOutMeta"]};'
        f'font-variant-numeric:tabular-nums">0:14</span></div>'
    )
    round_video = (
        f'<div style="display:flex;align-items:center;gap:10px">'
        f'<span style="position:relative;width:106px;height:106px;border-radius:53px;'
        f'overflow:hidden;border:2px solid {t["accentBorder"]};display:flex;'
        f'align-items:center;justify-content:center;'
        f'background:linear-gradient(135deg,{VIOLET}33,{BRAND}14)">'
        f'{icon("video", 26, t["accent"], 1.6)}'
        f'<span style="position:absolute;bottom:8px;font-size:10.5px;font-weight:600;'
        f'padding:1px 6px;border-radius:8px;background:rgba(2,6,23,0.6);color:#FFF">0:07</span>'
        f'</span></div>'
    )
    upload = (
        f'<div style="display:flex;align-items:center;gap:11px;width:214px">'
        f'<span style="position:relative;display:flex;align-items:center;'
        f'justify-content:center;flex:0 0 auto;width:42px;height:42px;border-radius:11px;'
        f'background:#FFFFFF29">'
        f'<svg width="42" height="42" viewBox="0 0 42 42" style="position:absolute;'
        f'transform:rotate(-90deg)">'
        f'<circle cx="21" cy="21" r="17" fill="none" stroke="#FFFFFF3D" stroke-width="3"/>'
        f'<circle cx="21" cy="21" r="17" fill="none" stroke="#FFFFFF" stroke-width="3" '
        f'stroke-linecap="round" stroke-dasharray="107" stroke-dashoffset="43"/></svg>'
        f'{icon("close", 15, "#FFFFFF", 2)}</span>'
        f'<span style="min-width:0;flex:1">'
        f'<span style="display:block;font-size:14px;font-weight:600;color:#FFFFFF">'
        f'dars-reja.pdf</span>'
        f'<span style="display:block;font-size:12px;color:{t["bubbleOutMeta"]};'
        f'margin-top:1px">60% · 2,4 MB / 4,1 MB</span></span></div>'
    )
    rejected = (
        f'<div style="display:flex;align-items:flex-start;gap:9px;padding:10px 12px;'
        f'border-radius:12px;background:{ERROR}1A;border:1px solid {ERROR}4D">'
        f'{icon("alert", 18, ERROR, 1.9)}'
        f'<span style="flex:1;min-width:0">'
        f'<span style="display:block;font-size:13px;font-weight:600;color:{ERROR}">'
        f'Fayl yuborilmadi</span>'
        f'<span style="display:block;font-size:12.5px;color:{t["textSecondary"]};'
        f'margin-top:2px;line-height:1.35">\'image/svg+xml\' turdagi fayl qabul '
        f'qilinmaydi</span></span></div>'
    )

    msgs = "".join([
        day_pill(t, "Bugun"),
        bubble(t, out=False, av=av_sm, time="09:12", pad="5px 5px 6px 5px",
               body=media_frame(t, placeholder_art(t, SKY))
               + f'<div style="padding:6px 7px 0 7px;font-size:14px">Doskadagi misol</div>'),
        bubble(t, out=False, av=av_sm, time="09:13", pad="5px", tail=False,
               body=media_frame(t,
                   placeholder_art(t, VIOLET)
                   + f'<span style="position:absolute;inset:0;display:flex;'
                     f'align-items:center;justify-content:center">'
                     f'<span style="display:flex;align-items:center;justify-content:center;'
                     f'width:46px;height:46px;border-radius:23px;'
                     f'background:rgba(2,6,23,0.55)">{solid_icon("play", 20, "#FFF")}</span>'
                     f'</span>'
                   + f'<span style="position:absolute;right:8px;bottom:8px;font-size:11px;'
                     f'font-weight:600;padding:2px 6px;border-radius:8px;'
                     f'background:rgba(2,6,23,0.65);color:#FFF">1:24</span>')),
        bubble(t, out=True, time="09:20", state="read", body=voice_body),
        bubble(t, out=False, av=av_sm, time="09:24", pad="5px", tail=False,
               body=round_video),
        bubble(t, out=False, av=av_sm, time="09:31",
               body=file_tile(t, "matematika-testi.pdf", "PDF · 1,8 MB", ERROR, "doc")),
        bubble(t, out=True, time="09:33", state="sent",
               body=file_tile(t, "Sonlar nazariyasi.mp3", "Audio · 3:42", EMERALD,
                              "music", out=True)),
        bubble(t, out=True, time="09:34", state="pending", body=upload),
        f'<div style="padding:0 2px">{rejected}</div>',
    ])
    body = (
        appbar(t, "Bekzod Rahimov", subtitle=("oxirgi faollik 09:40", t["textSecondary"]),
               avatar_html=avatar("BR", 38, False, t), actions=action_btn(t, "info"))
        + scroll(t, msgs, gap=9)
        + composer(t)
    )
    return shell(t, body, h=MEDIA_H)


# ── 4. Amallar ───────────────────────────────────────────────────────────
def sheet_row(t, ico, label, color=None, last=False):
    c = color or t["textPrimary"]
    bd = "" if last else f'border-bottom:1px solid {t["border"]};'
    return (
        f'<div style="display:flex;align-items:center;gap:14px;height:52px;padding:0 18px;'
        f'{bd}">{icon(ico, 20, c, 1.9)}'
        f'<span style="font-size:15px;font-weight:550;color:{c}">{label}</span></div>'
    )


def screen_actions(t):
    emojis = "".join(
        f'<span style="display:flex;align-items:center;justify-content:center;width:44px;'
        f'height:44px;border-radius:22px;{"background:" + t["accentMuted"] + ";" if sel else ""}'
        f'font-size:23px;line-height:1">{e}</span>'
        for e, sel in [("❤️", True), ("\U0001F44D", False), ("\U0001F602", False),
                       ("\U0001F62E", False), ("\U0001F622", False), ("\U0001F64F", False)]
    )
    emoji_bar = (
        f'<div style="display:flex;align-items:center;gap:2px;padding:5px 8px;'
        f'border-radius:26px;background:{t["sheet"]};border:1px solid {t["border"]};'
        f'box-shadow:{t["cardShadow"]}">{emojis}'
        f'<span style="display:flex;align-items:center;justify-content:center;width:44px;'
        f'height:44px;border-radius:22px;background:{t["bgInner"]}">'
        f'{icon("plus", 19, t["textSecondary"], 2)}</span></div>'
    )
    sheet = (
        f'<div style="border-radius:16px;overflow:hidden;background:{t["sheet"]};'
        f'border:1px solid {t["border"]};box-shadow:{t["cardShadow"]}">'
        + sheet_row(t, "reply", "Javob berish")
        + sheet_row(t, "pencil", "Tahrirlash")
        + sheet_row(t, "copy", "Nusxa olish")
        + sheet_row(t, "forward", "Uzatish")
        + sheet_row(t, "trash", "O'chirish", ERROR, last=True)
        + '</div>'
    )
    behind = "".join([
        day_pill(t, "Bugun"),
        text_bubble(t, "Salom! Bugungi test bo'yicha savolim bor edi.",
                    out=False, time="14:20", av=avatar("ST", 30, None, t)),
    ])
    focused = text_bubble(
        t, "Tekshirdim — hammasi to'g'ri, shart matnini diqqat bilan o'qing.",
        out=True, time="14:25", state="read", highlight=True)

    overlay = (
        f'<div style="position:absolute;inset:0;background:{t["scrim"]};'
        f'backdrop-filter:blur(1.5px);display:flex;flex-direction:column;'
        f'justify-content:flex-end;gap:12px;padding:16px">'
        f'<div style="display:flex;justify-content:flex-end">{emoji_bar}</div>'
        f'{focused}{sheet}'
        f'<div style="height:2px"></div></div>'
    )
    body = (
        appbar(t, "Shehroz Toshpo'latov", subtitle=("onlayn", SUCCESS),
               avatar_html=avatar("ST", 38, True, t), actions=action_btn(t, "info"))
        + scroll(t, behind)
        + composer(t)
    )
    return shell(t, body + overlay)


# ── 5. Uzatish / yangi suhbat ────────────────────────────────────────────
def pick_row(t, av, title, sub, checked=False):
    box = (
        f'<span style="display:flex;align-items:center;justify-content:center;flex:0 0 auto;'
        f'width:24px;height:24px;border-radius:12px;'
        f'background:{BRAND if checked else "transparent"};'
        f'border:2px solid {BRAND if checked else t["border"]}">'
        f'{icon("check", 14, "#FFFFFF", 2.6) if checked else ""}</span>'
    )
    return (
        f'<div style="display:flex;align-items:center;gap:12px;padding:9px 16px">'
        f'{av}<div style="flex:1;min-width:0">'
        f'<div style="font-size:15px;font-weight:600;white-space:nowrap;overflow:hidden;'
        f'text-overflow:ellipsis;color:{t["textPrimary"]}">{title}</div>'
        f'<div style="font-size:12.5px;color:{t["textSecondary"]};margin-top:1px">{sub}</div>'
        f'</div>{box}</div>'
    )


def screen_picker(t):
    preview = (
        f'<div style="margin:12px 16px 6px 16px;padding:10px 12px;border-radius:12px;'
        f'background:{t["accentMuted"]};border:1px solid {t["accentBorder"]}">'
        f'<div style="display:flex;align-items:center;gap:6px;margin-bottom:4px">'
        f'{icon("forward", 14, t["accent"], 2)}'
        f'<span style="font-size:12px;font-weight:700;color:{t["accent"]}">'
        f'Uzatilayotgan xabar</span></div>'
        f'<div style="font-size:13.5px;color:{t["textSecondary"]};line-height:1.4">'
        f'Ertangi darsga 12-mavzuni tayyorlab kelinglar.</div></div>'
    )
    rows = "".join([
        section_label(t, "So'nggi suhbatlar"),
        pick_row(t, avatar("ST", 44, True, t), "Shehroz Toshpo'latov", "onlayn", True),
        pick_row(t, group_avatar(44, t), "Matematika 10-A", "24 a'zo"),
        pick_row(t, avatar("DK", 44, False, t), "Dilnoza Karimova", "oxirgi faollik 13:05"),
        section_label(t, "Do'stlar"),
        pick_row(t, avatar("BR", 44, True, t), "Bekzod Rahimov", "@bekzod"),
        pick_row(t, avatar("NY", 44, False, t), "Nodira Yusupova", "@nodira"),
        pick_row(t, avatar("AK", 44, False, t), "Aziz Karimov", "@aziz", True),
        pick_row(t, avatar("MG", 44, True, t), "Malika G'aniyeva", "@malika"),
    ])
    send_bar = (
        f'<div style="flex:0 0 auto;display:flex;align-items:center;gap:12px;'
        f'padding:12px 16px 18px 16px;background:{t["bgCard"]};'
        f'border-top:1px solid {t["border"]}">'
        f'<span style="flex:1;font-size:13.5px;color:{t["textSecondary"]}">'
        f'2 ta suhbat tanlandi</span>'
        f'<span style="display:flex;align-items:center;justify-content:center;gap:8px;'
        f'height:48px;padding:0 22px;border-radius:12px;background:{BRAND};'
        f'color:#FFFFFF;font-size:15px;font-weight:600">Uzatish'
        f'{icon("send", 18, "#FFFFFF", 2)}</span></div>'
    )
    body = (
        appbar(t, "Uzatish", leading=icon("close", 24, t["textPrimary"], 2))
        + search_field(t, "Ism yoki @username")
        + preview
        + f'<div style="flex:1 1 auto;overflow:hidden">{rows}</div>'
        + send_bar
    )
    return shell(t, body, bg=t["bgCard"])


# ── 6. Ma'lumot ──────────────────────────────────────────────────────────
def member_row(t, av, name, handle, role=None, online=False):
    tag = ""
    if role:
        tag = (f'<span style="padding:2px 8px;border-radius:8px;font-size:11px;'
               f'font-weight:700;background:{t["accentMuted"]};color:{t["accent"]};'
               f'border:1px solid {t["accentBorder"]}">{role}</span>')
    status = ("onlayn" if online else "oxirgi faollik 10:50")
    scolor = SUCCESS if online else t["textMuted"]
    return (
        f'<div style="display:flex;align-items:center;gap:12px;padding:9px 16px">{av}'
        f'<div style="flex:1;min-width:0">'
        f'<div style="display:flex;align-items:center;gap:8px">'
        f'<span style="font-size:15px;font-weight:600;white-space:nowrap;overflow:hidden;'
        f'text-overflow:ellipsis;color:{t["textPrimary"]}">{name}</span>{tag}</div>'
        f'<div style="font-size:12.5px;color:{scolor};margin-top:1px">{status}</div></div>'
        f'<span style="font-size:12px;color:{t["textMuted"]}">{handle}</span></div>'
    )


def screen_info(t):
    head = (
        f'<div style="display:flex;flex-direction:column;align-items:center;gap:10px;'
        f'padding:22px 16px 20px 16px;background:{t["bgCard"]};'
        f'border-bottom:1px solid {t["border"]}">'
        f'{group_avatar(84, t)}'
        f'<div style="font-size:20px;font-weight:700;letter-spacing:-0.3px">'
        f'Matematika 10-A</div>'
        f'<div style="font-size:13.5px;color:{t["textSecondary"]}">'
        f'24 a\'zo · <span style="color:{SUCCESS}">6 ta onlayn</span></div></div>'
    )
    stats = ""
    for label, value, tint, ico in [("Rasm", "128", SKY, "image"),
                                    ("Fayl", "31", VIOLET, "doc"),
                                    ("Ovozli", "54", EMERALD, "music")]:
        stats += (
            f'<div style="flex:1;display:flex;flex-direction:column;align-items:center;'
            f'gap:6px;padding:14px 8px;border-radius:16px;background:{t["bgCard"]};'
            f'border:1px solid {t["border"]};box-shadow:{t["cardShadow"]}">'
            f'{icon(ico, 20, tint, 1.9)}'
            f'<span style="font-size:17px;font-weight:700;color:{t["textPrimary"]};'
            f'font-variant-numeric:tabular-nums">{value}</span>'
            f'<span style="font-size:11.5px;color:{t["textMuted"]}">{label}</span></div>'
        )
    stats = f'<div style="display:flex;gap:10px;padding:14px 16px 6px 16px">{stats}</div>'

    members = "".join([
        section_label(t, "A'zolar"),
        member_row(t, avatar("AK", 44, True, t), "Aziz Karimov", "@aziz", "admin", True),
        member_row(t, avatar("ST", 44, True, t), "Shehroz Toshpo'latov", "@shehroz",
                   "siz", True),
        member_row(t, avatar("DK", 44, False, t), "Dilnoza Karimova", "@dilnoza"),
        member_row(t, avatar("BR", 44, True, t), "Bekzod Rahimov", "@bekzod",
                   online=True),
    ])
    leave = (
        f'<div style="padding:10px 16px 20px 16px">'
        f'<div style="display:flex;align-items:center;justify-content:center;gap:9px;'
        f'height:48px;border-radius:12px;background:{ERROR}14;'
        f'border:1px solid {ERROR}4D">{icon("exit", 19, ERROR, 1.9)}'
        f'<span style="font-size:15px;font-weight:600;color:{ERROR}">Guruhdan chiqish</span>'
        f'</div></div>'
    )
    body = (
        appbar(t, "Ma'lumot")
        + f'<div style="flex:1 1 auto;overflow:hidden">{head}{stats}{members}{leave}</div>'
    )
    return shell(t, body)


# ── 7. Holatlar ──────────────────────────────────────────────────────────
def panel(t, label, inner):
    return (
        f'<div style="display:flex;flex-direction:column;gap:8px">'
        f'<div style="font-size:11px;font-weight:700;letter-spacing:0.6px;'
        f'text-transform:uppercase;color:{t["textMuted"]}">{label}</div>'
        f'<div style="border-radius:16px;background:{t["bgCard"]};'
        f'border:1px solid {t["border"]};overflow:hidden">{inner}</div></div>'
    )


def skeleton_row(t, w1, w2):
    bar = lambda w, h: (f'<span style="display:block;width:{w};height:{h}px;'
                        f'border-radius:{h // 2}px;background:{t["skeleton"]}"></span>')
    return (
        f'<div style="display:flex;align-items:center;gap:12px;padding:11px 14px">'
        f'<span style="width:46px;height:46px;border-radius:23px;'
        f'background:{t["skeleton"]};flex:0 0 auto"></span>'
        f'<span style="flex:1;display:flex;flex-direction:column;gap:7px">'
        f'{bar(w1, 11)}{bar(w2, 9)}</span></div>'
    )


def screen_states(t):
    loading = skeleton_row(t, "58%", "84%") + skeleton_row(t, "44%", "70%")

    empty = (
        f'<div style="display:flex;flex-direction:column;align-items:center;gap:9px;'
        f'padding:26px 24px">'
        f'<span style="display:flex;align-items:center;justify-content:center;width:56px;'
        f'height:56px;border-radius:28px;background:{t["accentMuted"]};'
        f'border:1px solid {t["accentBorder"]}">{icon("chat", 26, t["accent"], 1.7)}</span>'
        f'<span style="font-size:15.5px;font-weight:650">Hali suhbat yo\'q</span>'
        f'<span style="font-size:13px;color:{t["textSecondary"]};text-align:center;'
        f'line-height:1.45">Do\'stlaringizdan birini tanlab<br>birinchi xabarni yuboring</span>'
        f'<span style="display:flex;align-items:center;justify-content:center;gap:8px;'
        f'height:44px;padding:0 20px;margin-top:4px;border-radius:12px;background:{BRAND};'
        f'color:#FFFFFF;font-size:14.5px;font-weight:600">'
        f'{icon("compose", 17, "#FFFFFF", 2)}Yangi suhbat</span></div>'
    )

    error = (
        f'<div style="display:flex;flex-direction:column;align-items:center;gap:9px;'
        f'padding:22px 24px">'
        f'<span style="display:flex;align-items:center;justify-content:center;width:52px;'
        f'height:52px;border-radius:26px;background:{ERROR}1A;'
        f'border:1px solid {ERROR}40">{icon("alert", 24, ERROR, 1.8)}</span>'
        f'<span style="font-size:15px;font-weight:650">Suhbatlar yuklanmadi</span>'
        f'<span style="font-size:13px;color:{t["textSecondary"]};text-align:center">'
        f'Internet aloqasini tekshiring</span>'
        f'<span style="display:flex;align-items:center;justify-content:center;gap:8px;'
        f'height:44px;padding:0 20px;margin-top:4px;border-radius:12px;'
        f'background:transparent;border:1px solid {t["border"]};'
        f'color:{t["textPrimary"]};font-size:14.5px;font-weight:600">'
        f'{icon("refresh", 17, t["textPrimary"], 2)}Qayta urinish</span></div>'
    )

    offline = (
        f'<div style="display:flex;align-items:center;gap:10px;padding:12px 14px;'
        f'background:{WARNING}14">{icon("offline", 19, WARNING, 1.9)}'
        f'<span style="flex:1;font-size:13.5px;font-weight:600;color:{t["textPrimary"]}">'
        f'Ulanish uzildi — qayta ulanmoqda...</span>'
        f'<span style="width:16px;height:16px;border-radius:8px;'
        f'border:2px solid {WARNING}59;border-top-color:{WARNING}"></span></div>'
    )

    forbidden = (
        f'<div style="display:flex;align-items:flex-start;gap:11px;padding:14px">'
        f'<span style="display:flex;align-items:center;justify-content:center;flex:0 0 auto;'
        f'width:38px;height:38px;border-radius:19px;background:{ERROR}1A">'
        f'{icon("lock", 19, ERROR, 1.9)}</span>'
        f'<span style="flex:1;min-width:0">'
        f'<span style="display:block;font-size:14px;font-weight:650;'
        f'color:{t["textPrimary"]}">Siz bu chat a\'zosi emassiz</span>'
        f'<span style="display:block;font-size:12.5px;color:{t["textSecondary"]};'
        f'margin-top:3px;line-height:1.4">Server 403 qaytardi. Suhbat ro\'yxatga '
        f'qaytariladi.</span></span></div>'
    )

    body = (
        appbar(t, "Holatlar", leading=icon("back", 24, t["textPrimary"], 2))
        + f'<div style="flex:1 1 auto;overflow:hidden;display:flex;flex-direction:column;'
          f'gap:14px;padding:16px">'
        + panel(t, "Yuklanmoqda", loading)
        + panel(t, "Bo'sh", empty)
        + panel(t, "Xato", error)
        + panel(t, "Ulanish", offline)
        + panel(t, "Ruxsat yo'q (403)", forbidden)
        + '</div>'
    )
    return shell(t, body, h=STATES_H)


SCREENS = [
    ("Chats", "Suhbatlar", screen_chats, H),
    ("Room", "Suhbat", screen_room, H),
    ("Media", "Biriktirmalar", screen_media, MEDIA_H),
    ("Actions", "Xabar amallari", screen_actions, H),
    ("Picker", "Uzatish", screen_picker, H),
    ("Info", "Chat ma'lumoti", screen_info, H),
    ("States", "Holatlar", screen_states, STATES_H),
]
