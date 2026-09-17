#!/usr/bin/env python3
"""Seed the EduNova database with school subjects and one ready quiz per subject.

Run it once after a deploy. For every subject in :data:`SUBJECTS` it writes:

* one row in ``subjects`` (an existing subject is kept, only blank
  ``type`` / ``icon`` columns are filled in);
* one row in ``quizzes`` with ``user_id = NULL`` so the quiz belongs to nobody;
* ten rows in ``questions`` - five ``oson``, three ``o'rta`` and two ``qiyin``;
* four rows in ``options`` per question, exactly one of them correct.

Everything happens in one transaction, and the script is idempotent: a quiz
whose title already exists as an unassigned quiz is left untouched, so running
it again after a deploy adds nothing and changes nothing. ``--replace`` rewrites
those quizzes instead.

It needs only what the backend already installs: SQLAlchemy 2 and asyncpg.

Usage
-----
    export DATABASE_URL='postgresql+asyncpg://user:password@host:5432/quiz'
    python3 seed_subjects.py              # write the missing subjects and quizzes
    python3 seed_subjects.py --dry-run    # show what would be written
    python3 seed_subjects.py --replace    # rewrite the quizzes that already exist
"""

from __future__ import annotations

import argparse
import asyncio
import os
import sys

from sqlalchemy import (
    Boolean,
    Column,
    Integer,
    MetaData,
    String,
    Table,
    Text,
    delete,
    insert,
    select,
)
from sqlalchemy.dialects.postgresql import ENUM as PGEnum
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncConnection, create_async_engine
from sqlalchemy.sql import func

EASY = "oson"
MEDIUM = "o'rta"
HARD = "qiyin"

#: Difficulty mix every quiz must follow.
EXPECTED_MIX = {EASY: 5, MEDIUM: 3, HARD: 2}

#: Option labels, in order.
LABELS = ("A", "B", "C", "D")

#: The backend's ``quiz_generate_type`` enum; the script never creates it,
#: it only names it so PostgreSQL accepts the value without a cast.
QUIZ_GENERATE_TYPE = PGEnum(
    "AI_GENERATE",
    "PDF",
    "MANUAL",
    "UNDEFINED",
    name="quiz_generate_type",
    create_type=False,
)

#: These quizzes are written by hand, not generated.
GENERATE_TYPE = "MANUAL"

metadata = MetaData()

#: Only the columns this script writes; ``created_at`` / ``updated_at`` come
#: from the server defaults, so the script never has to know the time zone.
subjects_table = Table(
    "subjects",
    metadata,
    Column("id", Integer, primary_key=True),
    Column("name", String(100), nullable=False, unique=True),
    Column("type", String(100)),
    Column("icon", String(25)),
)

quizzes_table = Table(
    "quizzes",
    metadata,
    Column("id", Integer, primary_key=True),
    Column("title", String(1500), nullable=False),
    Column("subject", String(255)),
    Column("description", Text),
    Column("quiz_generate_type", QUIZ_GENERATE_TYPE),
    Column("user_id", Integer),
)

questions_table = Table(
    "questions",
    metadata,
    Column("id", Integer, primary_key=True),
    Column("quiz_id", Integer, nullable=False),
    Column("question_text", Text, nullable=False),
    Column("subject", String(100)),
    Column("difficulty", String(50)),
    Column("topic", String(255)),
)

options_table = Table(
    "options",
    metadata,
    Column("id", Integer, primary_key=True),
    Column("question_id", Integer, nullable=False),
    Column("label", String(5), nullable=False),
    Column("text", String(2000), nullable=False),
    Column("is_correct", Boolean, nullable=False),
)


def question(text: str, difficulty: str, topic: str, options: list[str], answer: int) -> dict:
    """Build one question; ``answer`` is the 0-based index of the correct option."""
    return {
        "text": text,
        "difficulty": difficulty,
        "topic": topic,
        "options": options,
        "answer": answer,
    }


#: Every subject, its quiz and the ten questions of that quiz.
SUBJECTS: list[dict] = [
    {
        "name": "Matematika",
        "type": "math",
        "icon": "calculator",
        "quiz_title": "Matematika: asosiy bilimlar testi",
        "quiz_description": "Arifmetika, algebra va geometriya asoslari bo'yicha "
                            "10 ta savoldan iborat boshlang'ich daraja testi.",
        "questions": [
            question("7 × 8 amalining natijasi nechaga teng?", EASY, "Arifmetika",
                     ["48", "54", "56", "63"], 2),
            question("144 sonining kvadrat ildizi nechaga teng?", EASY, "Arifmetika",
                     ["12", "14", "16", "24"], 0),
            question("200 sonining 25 foizi nechaga teng?", EASY, "Foiz",
                     ["25", "40", "50", "75"], 2),
            question("Uchburchakning ichki burchaklari yig'indisi necha gradus?", EASY, "Geometriya",
                     ["90°", "180°", "270°", "360°"], 1),
            question("x + 5 = 12 tenglamada x nechaga teng?", EASY, "Tenglamalar",
                     ["5", "6", "7", "17"], 2),
            question("Radiusi 5 sm bo'lgan doiraning yuzi nechaga teng? (π ≈ 3,14)", MEDIUM, "Geometriya",
                     ["31,4 sm²", "78,5 sm²", "157 sm²", "25 sm²"], 1),
            question("2x − 3 = 11 tenglamaning ildizi nechaga teng?", MEDIUM, "Tenglamalar",
                     ["4", "5", "7", "8"], 2),
            question("Arifmetik progressiyada a₁ = 3, d = 4 bo'lsa, a₁₀ nechaga teng?", MEDIUM, "Progressiya",
                     ["36", "39", "40", "43"], 1),
            question("x² − 5x + 6 = 0 tenglama ildizlarining yig'indisi nechaga teng?", HARD, "Kvadrat tenglama",
                     ["−5", "1", "5", "6"], 2),
            question("log₂32 + log₂2 ifodaning qiymati nechaga teng?", HARD, "Logarifm",
                     ["5", "6", "7", "16"], 1),
        ],
    },
    {
        "name": "Fizika",
        "type": "physics",
        "icon": "zap",
        "quiz_title": "Fizika: asosiy bilimlar testi",
        "quiz_description": "Mexanika, energiya va elektr asoslari bo'yicha "
                            "10 ta savoldan iborat boshlang'ich daraja testi.",
        "questions": [
            question("Tezlikning SI tizimidagi o'lchov birligi qaysi?", EASY, "O'lchov birliklari",
                     ["m/s", "km/soat", "N", "J"], 0),
            question("Yorug'likning vakuumdagi tezligi taxminan nechaga teng?", EASY, "Optika",
                     ["3 000 km/s", "30 000 km/s", "300 000 km/s", "3 000 000 km/s"], 2),
            question("Kuchning SI tizimidagi o'lchov birligi qaysi?", EASY, "O'lchov birliklari",
                     ["Joul", "Vatt", "Nyuton", "Paskal"], 2),
            question("Yer yuzasida erkin tushish tezlanishi taxminan nechaga teng?", EASY, "Mexanika",
                     ["5,6 m/s²", "9,8 m/s²", "10,8 m/s²", "12 m/s²"], 1),
            question("Normal atmosfera bosimida suv necha gradusda qaynaydi?", EASY, "Issiqlik",
                     ["0 °C", "50 °C", "100 °C", "212 °C"], 2),
            question("Massasi 2 kg bo'lgan jismga 6 N kuch ta'sir etsa, tezlanish nechaga teng?", MEDIUM, "Dinamika",
                     ["2 m/s²", "3 m/s²", "8 m/s²", "12 m/s²"], 1),
            question("10 soniyada 500 J ish bajarilgan bo'lsa, quvvat nechaga teng?", MEDIUM, "Ish va quvvat",
                     ["5 Vt", "50 Vt", "500 Vt", "5000 Vt"], 1),
            question("Massasi 4 kg, tezligi 3 m/s bo'lgan jismning kinetik energiyasi nechaga teng?", MEDIUM, "Energiya",
                     ["6 J", "12 J", "18 J", "36 J"], 2),
            question("2 Ω va 3 Ω qarshiliklar parallel ulansa, umumiy qarshilik nechaga teng?", HARD, "Elektr toki",
                     ["0,6 Ω", "1,2 Ω", "2,5 Ω", "5 Ω"], 1),
            question("Matematik mayatnik uzunligi 4 marta oshirilsa, uning tebranish davri qanday o'zgaradi?",
                     HARD, "Tebranishlar",
                     ["2 marta kamayadi", "O'zgarmaydi", "2 marta ortadi", "4 marta ortadi"], 2),
        ],
    },
    {
        "name": "Kimyo",
        "type": "chemistry",
        "icon": "flask",
        "quiz_title": "Kimyo: asosiy bilimlar testi",
        "quiz_description": "Elementlar, formulalar va reaksiyalar bo'yicha "
                            "10 ta savoldan iborat boshlang'ich daraja testi.",
        "questions": [
            question("Suvning kimyoviy formulasi qaysi?", EASY, "Formulalar",
                     ["H₂O", "CO₂", "O₂", "NaCl"], 0),
            question("Kislorod elementining kimyoviy belgisi qaysi?", EASY, "Elementlar",
                     ["O", "Os", "K", "Ox"], 0),
            question("Osh tuzining kimyoviy formulasi qaysi?", EASY, "Formulalar",
                     ["KCl", "NaCl", "NaOH", "HCl"], 1),
            question("Vodorod elementining davriy jadvaldagi tartib raqami nechaga teng?", EASY, "Davriy jadval",
                     ["1", "2", "8", "12"], 0),
            question("Davriy jadvaldagi eng yengil element qaysi?", EASY, "Davriy jadval",
                     ["Geliy", "Vodorod", "Litiy", "Uglerod"], 1),
            question("pH ko'rsatkichi 7 ga teng bo'lgan eritma qanday muhitga ega?", MEDIUM, "Eritmalar",
                     ["Kislotali", "Ishqoriy", "Neytral", "To'yingan"], 2),
            question("Suvning molyar massasi nechaga teng?", MEDIUM, "Mol hisoblari",
                     ["16 g/mol", "18 g/mol", "20 g/mol", "22 g/mol"], 1),
            question("Karbonat angidrid (CO₂) molekulasi nechta atomdan iborat?", MEDIUM, "Formulalar",
                     ["2", "3", "4", "5"], 1),
            question("2H₂ + O₂ → 2H₂O reaksiyasida 4 mol vodorod uchun necha mol kislorod kerak?",
                     HARD, "Reaksiya tenglamalari",
                     ["1 mol", "2 mol", "4 mol", "8 mol"], 1),
            question("Quyidagi metallardan qaysi biri xlorid kislota bilan reaksiyaga kirishmaydi?",
                     HARD, "Metallar aktivligi",
                     ["Rux (Zn)", "Temir (Fe)", "Magniy (Mg)", "Mis (Cu)"], 3),
        ],
    },
    {
        "name": "Biologiya",
        "type": "biology",
        "icon": "leaf",
        "quiz_title": "Biologiya: asosiy bilimlar testi",
        "quiz_description": "Hujayra, organizm va irsiyat asoslari bo'yicha "
                            "10 ta savoldan iborat boshlang'ich daraja testi.",
        "questions": [
            question("O'simliklar fotosintez jarayonida qaysi gazni yutadi?", EASY, "Fotosintez",
                     ["Kislorod", "Karbonat angidrid", "Azot", "Vodorod"], 1),
            question("Inson organizmida qonni haydab turadigan organ qaysi?", EASY, "Odam anatomiyasi",
                     ["Jigar", "O'pka", "Yurak", "Buyrak"], 2),
            question("Hujayraning irsiy axborotini saqlaydigan organoid qaysi?", EASY, "Hujayra",
                     ["Ribosoma", "Yadro", "Vakuola", "Lizosoma"], 1),
            question("Voyaga yetgan inson skeleti taxminan nechta suyakdan iborat?", EASY, "Odam anatomiyasi",
                     ["106", "206", "306", "406"], 1),
            question("Inson qonining nechta guruhi mavjud?", EASY, "Qon",
                     ["2", "3", "4", "6"], 2),
            question("Fotosintez jarayoni hujayraning qaysi organoidida boradi?", MEDIUM, "Fotosintez",
                     ["Mitoxondriya", "Xloroplast", "Ribosoma", "Golji apparati"], 1),
            question("Hujayraning \"energiya stansiyasi\" deb ataladigan organoidi qaysi?", MEDIUM, "Hujayra",
                     ["Yadro", "Mitoxondriya", "Vakuola", "Xloroplast"], 1),
            question("DNK molekulasida adeninga qaysi nukleotid komplementar?", MEDIUM, "Genetika",
                     ["Guanin", "Sitozin", "Timin", "Uratsil"], 2),
            question("Aa × Aa chatishtirishda avlodda fenotip bo'yicha qanday nisbat kuzatiladi?",
                     HARD, "Genetika",
                     ["1 : 1", "3 : 1", "9 : 3 : 3 : 1", "1 : 2 : 1"], 1),
            question("Oqsil sintezining translatsiya bosqichi hujayraning qayerida boradi?",
                     HARD, "Molekulyar biologiya",
                     ["Yadroda", "Ribosomada", "Lizosomada", "Golji apparatida"], 1),
        ],
    },
    {
        "name": "Tarix",
        "type": "history",
        "icon": "graduate",
        "quiz_title": "Tarix: asosiy bilimlar testi",
        "quiz_description": "Vatan tarixi va jahon tarixining muhim sanalari bo'yicha "
                            "10 ta savoldan iborat boshlang'ich daraja testi.",
        "questions": [
            question("Amir Temur davlatining poytaxti qaysi shahar bo'lgan?", EASY, "Temuriylar davri",
                     ["Buxoro", "Samarqand", "Xiva", "Toshkent"], 1),
            question("O'zbekiston mustaqilligi qaysi yilda e'lon qilingan?", EASY, "Mustaqillik",
                     ["1989", "1990", "1991", "1992"], 2),
            question("Ikkinchi jahon urushi qaysi yilda tugagan?", EASY, "Jahon tarixi",
                     ["1939", "1943", "1945", "1947"], 2),
            question("Registon majmuasi qaysi shaharda joylashgan?", EASY, "Me'moriy yodgorliklar",
                     ["Buxoro", "Samarqand", "Shahrisabz", "Xiva"], 1),
            question("Buyuk ipak yo'li asosan qaysi mintaqalarni bog'lagan?", EASY, "Savdo yo'llari",
                     ["Xitoy va Yevropani", "Afrika va Amerikani",
                      "Hindiston va Avstraliyani", "Rossiya va Yaponiyani"], 0),
            question("Amir Temur qaysi yilda tug'ilgan?", MEDIUM, "Temuriylar davri",
                     ["1316", "1326", "1336", "1346"], 2),
            question("Mirzo Ulug'bek birinchi navbatda qaysi soha olimi sifatida mashhur?", MEDIUM, "Ilm-fan tarixi",
                     ["Tibbiyot", "Astronomiya", "Geografiya", "Kimyo"], 1),
            question("Zahiriddin Muhammad Bobur qaysi davlatga asos solgan?", MEDIUM, "Boburiylar",
                     ["Safaviylar davlati", "Usmonlilar imperiyasi",
                      "Boburiylar saltanati", "Somoniylar davlati"], 2),
            question("1402-yilgi Anqara jangida Amir Temur kimni mag'lub etgan?", HARD, "Temuriylar davri",
                     ["Sulton Boyazid I ni", "To'xtamishxonni", "Shohruhni", "Sulton Mahmudni"], 0),
            question("Somoniylar davlatining poytaxti qaysi shahar bo'lgan?", HARD, "O'rta asrlar",
                     ["Samarqand", "Buxoro", "Urganch", "Marv"], 1),
        ],
    },
    {
        "name": "Geografiya",
        "type": "geography",
        "icon": "leaf",
        "quiz_title": "Geografiya: asosiy bilimlar testi",
        "quiz_description": "Tabiiy geografiya va O'zbekiston geografiyasi bo'yicha "
                            "10 ta savoldan iborat boshlang'ich daraja testi.",
        "questions": [
            question("O'zbekiston Respublikasining poytaxti qaysi shahar?", EASY, "O'zbekiston geografiyasi",
                     ["Samarqand", "Toshkent", "Buxoro", "Namangan"], 1),
            question("Yer yuzidagi eng katta okean qaysi?", EASY, "Okeanlar",
                     ["Atlantika okeani", "Hind okeani", "Tinch okeani", "Shimoliy Muz okeani"], 2),
            question("Yer yuzidagi eng baland tog' cho'qqisi qaysi?", EASY, "Tog'lar",
                     ["Everest (Jomolungma)", "Elbrus", "Kilimanjaro", "Mont-Blan"], 0),
            question("O'zbekistonda nechta viloyat mavjud?", EASY, "O'zbekiston geografiyasi",
                     ["10", "12", "14", "16"], 1),
            question("Sahroi Kabir qaysi qit'ada joylashgan?", EASY, "Qit'alar",
                     ["Osiyo", "Afrika", "Avstraliya", "Janubiy Amerika"], 1),
            question("O'zbekistondagi eng uzun daryo qaysi?", MEDIUM, "Daryolar",
                     ["Sirdaryo", "Amudaryo", "Zarafshon", "Chirchiq"], 1),
            question("Yer o'z o'qi atrofida bir marta necha soatda aylanadi?", MEDIUM, "Yer harakati",
                     ["12 soat", "24 soat", "365 soat", "48 soat"], 1),
            question("O'zbekiston nechta davlat bilan chegaradosh?", MEDIUM, "O'zbekiston geografiyasi",
                     ["3", "4", "5", "6"], 2),
            question("Yer yuzidagi eng chuqur ko'l qaysi?", HARD, "Ko'llar",
                     ["Kaspiy dengizi", "Baykal", "Tanganika", "Viktoriya"], 1),
            question("O'zbekistonning eng baland cho'qqisi qaysi?", HARD, "Tog'lar",
                     ["Chimyon", "Xazrat Sulton", "Beshtor", "Oqtosh"], 1),
        ],
    },
    {
        "name": "Ona tili va adabiyoti",
        "type": "native_language",
        "icon": "graduate",
        "quiz_title": "Ona tili va adabiyoti: asosiy bilimlar testi",
        "quiz_description": "O'zbek tili qoidalari va o'zbek adabiyoti bo'yicha "
                            "10 ta savoldan iborat boshlang'ich daraja testi.",
        "questions": [
            question("Hozirgi o'zbek lotin alifbosida nechta harf bor?", EASY, "Alifbo",
                     ["26", "29", "33", "36"], 1),
            question("\"Alpomish\" asari qaysi janrga mansub?", EASY, "Xalq og'zaki ijodi",
                     ["She'r", "Doston", "Roman", "Hikoya"], 1),
            question("Alisher Navoiyning \"Xamsa\" asari nechta dostondan iborat?", EASY, "Navoiy ijodi",
                     ["3", "4", "5", "6"], 2),
            question("Gapning bosh bo'laklari qaysilar?", EASY, "Sintaksis",
                     ["Ega va kesim", "Aniqlovchi va to'ldiruvchi",
                      "Hol va aniqlovchi", "Kesim va hol"], 0),
            question("\"Kitob\" so'zi qaysi so'z turkumiga mansub?", EASY, "Morfologiya",
                     ["Ot", "Sifat", "Fe'l", "Ravish"], 0),
            question("\"O'tkan kunlar\" romanining muallifi kim?", MEDIUM, "XX asr adabiyoti",
                     ["Cho'lpon", "Abdulla Qodiriy", "Oybek", "Abdulla Qahhor"], 1),
            question("So'zning ma'no anglatuvchi o'zgarmas qismi qanday ataladi?", MEDIUM, "Morfologiya",
                     ["Qo'shimcha", "O'zak", "Bo'g'in", "Urg'u"], 1),
            question("\"Sarob\" romanining muallifi kim?", MEDIUM, "XX asr adabiyoti",
                     ["Abdulla Qodiriy", "Abdulla Qahhor", "Oybek", "Cho'lpon"], 1),
            question("Alisher Navoiy \"Xamsa\"sining birinchi dostoni qaysi?", HARD, "Navoiy ijodi",
                     ["Farhod va Shirin", "Hayrat ul-abror",
                      "Layli va Majnun", "Saddi Iskandariy"], 1),
            question("\"Navoiy\" tarixiy romanining muallifi kim?", HARD, "XX asr adabiyoti",
                     ["Oybek", "G'afur G'ulom", "Said Ahmad", "Pirimqul Qodirov"], 0),
        ],
    },
    {
        "name": "Ingliz tili",
        "type": "english",
        "icon": "graduate",
        "quiz_title": "Ingliz tili: asosiy bilimlar testi",
        "quiz_description": "Lug'at boyligi va grammatika asoslari bo'yicha "
                            "10 ta savoldan iborat boshlang'ich daraja testi.",
        "questions": [
            question("\"Book\" so'zi o'zbek tilida nimani anglatadi?", EASY, "Lug'at",
                     ["Daftar", "Kitob", "Ruchka", "Stol"], 1),
            question("Bo'sh o'rinni to'ldiring: \"I ___ a student.\"", EASY, "To be fe'li",
                     ["is", "are", "am", "be"], 2),
            question("\"Apple\" so'zi o'zbek tilida nimani anglatadi?", EASY, "Lug'at",
                     ["Olma", "Nok", "Uzum", "Anor"], 0),
            question("\"Child\" so'zining ko'plik shakli qaysi?", EASY, "Ot ko'pligi",
                     ["childs", "childes", "children", "childrens"], 2),
            question("\"Good morning\" iborasi qanday tarjima qilinadi?", EASY, "Muomala iboralari",
                     ["Xayrli kech", "Xayrli tong", "Xayrli tun", "Xayr"], 1),
            question("Bo'sh o'rinni to'ldiring: \"She ___ to school every day.\"", MEDIUM, "Present Simple",
                     ["go", "goes", "going", "gone"], 1),
            question("\"Go\" fe'lining Past Simple shakli qaysi?", MEDIUM, "Past Simple",
                     ["goed", "gone", "went", "going"], 2),
            question("Bo'sh o'rinni to'ldiring: \"There ___ three books on the table.\"", MEDIUM, "There is / there are",
                     ["is", "are", "was", "be"], 1),
            question("Bo'sh o'rinni to'ldiring: \"If I ___ rich, I would travel the world.\"",
                     HARD, "Conditionals",
                     ["am", "was", "were", "will be"], 2),
            question("Bo'sh o'rinni to'ldiring: \"He said he ___ finished the work.\"",
                     HARD, "Reported speech",
                     ["has", "had", "have", "having"], 1),
        ],
    },
]


def validate() -> None:
    """Fail before touching the database when the embedded content is malformed."""
    total = sum(EXPECTED_MIX.values())
    for subject in SUBJECTS:
        name = subject["name"]
        questions = subject["questions"]
        if len(questions) != total:
            raise SystemExit(f"{name}: {len(questions)} ta savol, {total} ta bo'lishi kerak")
        mix: dict[str, int] = {}
        for item in questions:
            mix[item["difficulty"]] = mix.get(item["difficulty"], 0) + 1
            if len(item["options"]) != len(LABELS):
                raise SystemExit(
                    f"{name}: \"{item['text'][:40]}\" savolida {len(LABELS)} ta variant bo'lishi kerak"
                )
            if not 0 <= item["answer"] < len(LABELS):
                raise SystemExit(f"{name}: \"{item['text'][:40]}\" savolining javob indeksi xato")
        if mix != EXPECTED_MIX:
            raise SystemExit(f"{name}: qiyinlik taqsimoti {mix}, kutilgani {EXPECTED_MIX}")


async def upsert_subject(connection: AsyncConnection, subject: dict) -> int:
    """Insert the subject when it is new, and return its id either way.

    An existing subject is never overwritten: only a missing or empty ``type``
    or ``icon`` is filled in, because those two are cosmetic and someone may
    have set them by hand.
    """
    statement = pg_insert(subjects_table).values(
        name=subject["name"],
        type=subject["type"],
        icon=subject["icon"],
    )
    statement = statement.on_conflict_do_update(
        index_elements=[subjects_table.c.name],
        set_={
            "type": func.coalesce(
                func.nullif(subjects_table.c.type, ""), statement.excluded.type
            ),
            "icon": func.coalesce(
                func.nullif(subjects_table.c.icon, ""), statement.excluded.icon
            ),
        },
    ).returning(subjects_table.c.id)
    return await connection.scalar(statement)


async def insert_quiz(connection: AsyncConnection, subject: dict) -> int:
    """Write the quiz with all of its questions and options, and return its id."""
    quiz_id = await connection.scalar(
        insert(quizzes_table)
        .values(
            title=subject["quiz_title"],
            subject=subject["name"],
            description=subject["quiz_description"],
            quiz_generate_type=GENERATE_TYPE,
            user_id=None,  # the quiz belongs to nobody
        )
        .returning(quizzes_table.c.id)
    )

    for item in subject["questions"]:
        question_id = await connection.scalar(
            insert(questions_table)
            .values(
                quiz_id=quiz_id,
                question_text=item["text"],
                subject=subject["name"],
                difficulty=item["difficulty"],
                topic=item["topic"],
            )
            .returning(questions_table.c.id)
        )
        await connection.execute(
            insert(options_table),
            [
                {
                    "question_id": question_id,
                    "label": label,
                    "text": text,
                    "is_correct": index == item["answer"],
                }
                for index, (label, text) in enumerate(zip(LABELS, item["options"]))
            ],
        )
    return quiz_id


async def seed_subject(connection: AsyncConnection, subject: dict, *, replace: bool) -> str:
    """Seed one subject and report what happened: ``created``, ``replaced`` or ``skipped``."""
    await upsert_subject(connection, subject)

    existing = await connection.scalar(
        select(quizzes_table.c.id).where(
            quizzes_table.c.user_id.is_(None),
            quizzes_table.c.title == subject["quiz_title"],
        )
    )
    if existing is not None and not replace:
        return "skipped"

    action = "created"
    if existing is not None:
        # Cascades remove the questions, options and sessions of the old quiz.
        await connection.execute(delete(quizzes_table).where(quizzes_table.c.id == existing))
        action = "replaced"

    await insert_quiz(connection, subject)
    return action


def normalize_dsn(dsn: str) -> str:
    """Return the DSN with the asyncpg driver, whatever form the deploy uses."""
    for prefix in ("postgresql+asyncpg://", "postgres+asyncpg://"):
        if dsn.startswith(prefix):
            return dsn
    for prefix in ("postgresql+psycopg2://", "postgresql+psycopg://", "postgresql://", "postgres://"):
        if dsn.startswith(prefix):
            return "postgresql+asyncpg://" + dsn[len(prefix):]
    raise SystemExit(f"DSN tanilmadi: {dsn.split('://')[0]}://...")


async def seed(dsn: str, *, replace: bool) -> dict[str, str]:
    """Run the whole seed in a single transaction and return the per-subject result."""
    engine = create_async_engine(normalize_dsn(dsn), echo=False, pool_pre_ping=True)
    try:
        async with engine.begin() as connection:
            return {
                subject["name"]: await seed_subject(connection, subject, replace=replace)
                for subject in SUBJECTS
            }
    finally:
        await engine.dispose()


def report(results: dict[str, str]) -> None:
    """Print one line per subject plus a short summary."""
    width = max(len(name) for name in results)
    for name, action in results.items():
        print(f"  {name.ljust(width)}  {action}")
    counts: dict[str, int] = {}
    for action in results.values():
        counts[action] = counts.get(action, 0) + 1
    print("  " + ", ".join(f"{action}: {count}" for action, count in sorted(counts.items())))


def main(argv: list[str] | None = None) -> int:
    """Parse the arguments, validate the content and seed the database."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--dsn",
        default=os.environ.get("DATABASE_URL", ""),
        help="PostgreSQL DSN; defaults to the DATABASE_URL environment variable.",
    )
    parser.add_argument(
        "--replace",
        action="store_true",
        help="Rewrite an already seeded quiz. This drops its questions and sessions.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Validate the content and print what would be written, without a database.",
    )
    args = parser.parse_args(argv)

    validate()

    if args.dry_run:
        for subject in SUBJECTS:
            mix = " / ".join(
                str(sum(1 for q in subject["questions"] if q["difficulty"] == level))
                for level in (EASY, MEDIUM, HARD)
            )
            print(f"  {subject['name']}: \"{subject['quiz_title']}\", "
                  f"{len(subject['questions'])} ta savol ({mix})")
        print(f"  {len(SUBJECTS)} ta fan, {len(SUBJECTS)} ta test tekshirildi.")
        return 0

    if not args.dsn:
        parser.error("DSN yo'q: DATABASE_URL muhit o'zgaruvchisini bering yoki --dsn ishlating.")

    results = asyncio.run(seed(args.dsn, replace=args.replace))
    report(results)
    return 0


if __name__ == "__main__":
    sys.exit(main())
