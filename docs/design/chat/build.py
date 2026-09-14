"""Writes every .dc.html artboard plus canvas.json."""

import json
import pathlib

from gen_tokens import DARK, LIGHT, FONT, BRAND
from gen_parts import W, H
from gen_screens import SCREENS

OUT = pathlib.Path(__file__).parent

TEMPLATE = """<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
  <style>
    body {{ margin: 0; background: {page}; font-family: {font}; }}
    * {{ box-sizing: border-box; }}
    a {{ color: {link}; text-decoration: none; }}
    a:hover {{ color: {linkHover}; }}
  </style>
</helmet>
{content}
</x-dc>
</body>
</html>
"""


def write_artboard(name, theme, render):
    html = TEMPLATE.format(
        page=theme["bgBase"],
        font=FONT,
        link=theme["accent"],
        linkHover=BRAND,
        content=render(theme),
    )
    (OUT / f"{name}.dc.html").write_text(html, encoding="utf-8")
    return f"{name}.dc.html"


def main():
    artboards = []
    pages = [{"id": "page-1", "name": "Dark"}, {"id": "page-2", "name": "Light"}]

    for page_id, theme, suffix in [("page-1", DARK, "Dark"), ("page-2", LIGHT, "Light")]:
        row_h = max(h for *_, h in SCREENS)
        for index, (key, label, render, height) in enumerate(SCREENS):
            # The entry artboard must be Main; it is the dark chat list.
            name = "Main" if (suffix == "Dark" and key == "Chats") else f"{key}{suffix}"
            file = write_artboard(name, theme, render)
            artboards.append({
                "file": file,
                "x": (index % 4) * (W + 80),
                "y": (index // 4) * (row_h + 120),
                "w": W,
                "h": height,
                "title": f"{label} · {suffix}",
                "page": page_id,
            })

    canvas = {
        "artboards": artboards,
        "annotations": [
            {
                "id": "events",
                "x": 0,
                "y": -190,
                "w": 860,
                "page": "page-1",
                "text": (
                    "EduNova · chat\n"
                    "Ranglar lib/core/theme/app_colors.dart dan 1:1 olingan. "
                    "Telefon ramkasi 390x844.\n\n"
                    "Suhbat ekrani WS eventlarini ko'rsatadi: message:new, "
                    "message:ack (soat -> bitta belgi), message:read (ikkita belgi), "
                    "message:edited (tahrirlangan), message:deleted, "
                    "message:reaction_add, message:forward, typing:update, "
                    "presence:update (sarlavhadagi holat)."
                ),
            },
            {
                "id": "media-note",
                "x": 940,
                "y": -190,
                "w": 430,
                "page": "page-1",
                "text": (
                    "Biriktirma turlari bazadagi real qiymatlardan: image, video, "
                    "voice, video_message, audio, pdf, file.\n"
                    "Rasmlar o'rniga belgilangan placeholder ishlatilgan."
                ),
            },
            {
                "id": "light-note",
                "x": 0,
                "y": -130,
                "w": 620,
                "page": "page-2",
                "text": (
                    "Light tema — bir xil tuzilma, faqat tokenlar almashgan "
                    "(bgBase #F8FAFC, bgCard #FFFFFF, border #E2E8F0, accent #6366F1). "
                    "Ikkala tema bitta manbadan generatsiya qilingan, shuning uchun "
                    "tuzilishi aynan bir xil."
                ),
            },
        ],
        "pages": pages,
        "launch": {"view": "canvas", "page": "page-1"},
    }
    (OUT / "canvas.json").write_text(json.dumps(canvas, indent=2, ensure_ascii=False),
                                     encoding="utf-8")
    print(f"{len(artboards)} artboard + canvas.json")
    for a in artboards:
        print(" ", a["file"], a["title"])


if __name__ == "__main__":
    main()
