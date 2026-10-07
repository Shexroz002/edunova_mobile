"""Sertifikat varianti JSON ini bazaga yozishdan oldin tekshiradi.

Namunaviy testning ichki invariantlari shunchalik qattiqki, AI ning ko'p
xatosi odam ko'rmasdan oldin shu yerda ushlanadi.
"""
from collections import Counter
from decimal import Decimal

POINTS_CHOICE = {Decimal("1.3"), Decimal("2.2")}
TOTAL = Decimal("100.0")


def validate(exam: dict) -> list[str]:
    e: list[str] = []
    tasks = exam["tasks"]

    # 1. Umumiy ball aniq 100,0
    total = sum(Decimal(str(t["points"])) for t in tasks)
    if total != TOTAL:
        e.append(f"ball yig'indisi {total}, 100.0 bo'lishi kerak")

    # 2. Raqamlash: 1..32 yopiq, 33..35 moslashtirish, 36..45 ochiq (a va b)
    nums = [t["number"] for t in tasks]
    kutilgan = ([str(i) for i in range(1, 36)] +
                [f"{i}{p}" for i in range(36, 46) for p in ("a", "b")])
    if nums != kutilgan:
        yetmagan = set(kutilgan) - set(nums)
        ortiqcha = set(nums) - set(kutilgan)
        if yetmagan: e.append(f"yetishmayotgan katak: {sorted(yetmagan)[:5]}")
        if ortiqcha: e.append(f"ortiqcha katak: {sorted(ortiqcha)[:5]}")
        if not yetmagan and not ortiqcha: e.append("kataklar tartibi buzilgan")

    by_num = {t["number"]: t for t in tasks}

    # 3. 1-qism: 4 variant, aniq bitta to'g'ri, ball 1,3 yoki 2,2
    for i in range(1, 33):
        t = by_num.get(str(i))
        if not t: continue
        opts = t.get("options") or []
        if [o["label"] for o in opts] != list("ABCD"):
            e.append(f"{i}: variantlar A,B,C,D emas ({[o['label'] for o in opts]})")
        ok = sum(1 for o in opts if o.get("is_correct"))
        if ok != 1:
            e.append(f"{i}: to'g'ri variant soni {ok}, 1 bo'lishi kerak")
        if Decimal(str(t["points"])) not in POINTS_CHOICE:
            e.append(f"{i}: ball {t['points']}, 1.3 yoki 2.2 bo'lishi kerak")

    # 4. 2-qism: bitta guruh, 6 umumiy variant, har biri 2,2 ball
    grp = {by_num[str(i)].get("group") for i in (33, 34, 35) if str(i) in by_num}
    if len(grp) != 1 or None in grp:
        e.append("33-35 bitta umumiy guruhda emas")
    for i in (33, 34, 35):
        t = by_num.get(str(i))
        if t and Decimal(str(t["points"])) != Decimal("2.2"):
            e.append(f"{i}: ball {t['points']}, 2.2 bo'lishi kerak")
    pool = exam.get("groups", {}).get(list(grp)[0] if grp and None not in grp else "", {}).get("options", [])
    if pool and [o["label"] for o in pool] != list("ABCDEF"):
        e.append(f"33-35 umumiy ro'yxati A..F emas ({[o['label'] for o in pool]})")

    # 5. 3-qism: a) 1,5 va b) 1,7; kalit bor; birlik yo'q
    for i in range(36, 46):
        for part, ball in (("a", "1.5"), ("b", "1.7")):
            t = by_num.get(f"{i}{part}")
            if not t: continue
            if Decimal(str(t["points"])) != Decimal(ball):
                e.append(f"{i}{part}: ball {t['points']}, {ball} bo'lishi kerak")
            ans = t.get("answers") or []
            if not ans:
                e.append(f"{i}{part}: kalit yo'q")
            for a in ans:
                if any(u in str(a).lower() for u in ("cm", "sm", "m²", "kg", "$", "°", "gradus")):
                    e.append(f"{i}{part}: kalitda birlik bor -> {a!r}")
            if t.get("answer_format") == "expression" and len(ans) < 2:
                e.append(f"{i}{part}: simvolik javobga kamida 2 yozuv kerak")

    # 6. Kalitlar taqsimoti: bir harf 60% dan ko'p bo'lsa shubhali
    keys = Counter(o["label"] for i in range(1, 33)
                   if (t := by_num.get(str(i))) for o in (t.get("options") or [])
                   if o.get("is_correct"))
    if keys:
        harf, n = keys.most_common(1)[0]
        if n / sum(keys.values()) > 0.6:
            e.append(f"kalitlarning {n}/{sum(keys.values())} tasi '{harf}' — AI bir xil javob bergan bo'lishi mumkin")
    return e
