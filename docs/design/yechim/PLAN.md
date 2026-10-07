# Masala yechimi — reja

Holat: **qurildi** (2026-10-05). Dizayn: `yechim.html`. Ish jarayoni va topilmalar: `PROGRESS.md`.

> Rejadan ikki chetlanish, ikkalasi ham sinovdan keyin:
> 1. **Modelga to'g'ri javob aytilmaydi** (4-bo'limda aytilardi). Sinalgan 5 savoldan 4 tasida
>    kalitning o'zi xato chiqdi; javob aytilgan model xato javobga ham ravon "yechim" yozadi.
>    Model mustaqil yechadi, natija kalit bilan solishtiriladi, ikki raund boshqa variantda
>    kelishsa — "bahsli" holat.
> 2. **Rang belgilari `\hla`, `\hlb`, `\hlc`**, `\v1` emas: JSON da `\v` qochish belgisi emas va
>    javobda qator uzilishiga aylandi; LaTeX da esa `\v` allaqachon band buyruq.

## 1. Ikki rejim — va ular bir xil emas

| | A. Bank savoli | B. O'z masalasi |
|---|---|---|
| Qayerda | Xatolarim, test natijasini ko'rish | «Masala yechish» ekrani |
| To'g'ri javob | **ma'lum** (`options.is_correct`) | noma'lum |
| AI nima qiladi | **tushuntiradi** | yechadi |
| Ishonchlilik | yuqori — natija kalit bilan tekshiriladi | past-o'rta |
| Qachon hisoblanadi | **bir marta**, oldindan | har safar jonli |
| Narxi | bir savolga bir marta | har bir so'rov |

Eng muhim arxitektura qarori shu jadvaldan chiqadi: **bank savollari uchun yechim — bu
kontent, suhbat emas.** Har bir savolga bir marta yaratiladi, kalit bilan tekshiriladi,
saqlanadi va hamma o'quvchiga bir xil, tekshirilgan holda beriladi. Jonli AI faqat
o'quvchining o'z masalasi uchun kerak.

Tavsiya etilgan tartib: **avval A**, keyin B. A arzonroq, ishonchliroq va o'quvchi eng
ko'p «nega?» deb so'raydigan joyda turadi — hozirgina xato qilganda.

## 2. Mavjud AI integratsiyasi (2026-10-05 da o'rganildi)

Bor va qayta ishlatiladi:
- `app/services/ai/base.py` — `AIProvider` protokoli, provayderlar almashtiriladigan.
- `GeminiProvider` — `response_mime_type="application/json"` va `response_schema` bilan
  **tuzilgan JSON chiqishi allaqachon ishlaydi**. Yechim uchun aynan shu kerak: AI erkin
  matn emas, sxemaga mos qadamlar ro'yxatini qaytaradi.
- Og'ir AI ishi Celery vazifalarida yuradi (`quiz_tasks.py`, `ai_test_generator` navbati),
  progress callback bilan. Yechim ham shu yo'ldan boradi.

Yetishmaydi:
- Protokolda faqat quizga xos metodlar bor (`parse_quiz_from_pdf`,
  `generate_quiz_from_description`). Yangi metod kerak: `explain_problem(...)`.
- **Model:** `.env` da `GEMINI_MODEL=gemini-2.5-flash-lite` — oilaning eng yengil darajasi.
  Ko'p qadamli matematik fikrlash uchun «thinking» yoqilgan kuchliroq model kerak.
  Qaysi biri — **taxmin qilmasdan o'lchanadi**, 6-bo'limga qarang.

Mobil tomonda:
- Yangi rang tokenlari kerak — `AppColors` ga `mathVar1..3`. Kontrast o'lchandi, uchalasi ham
  ikkala temada karta va doska fonida 4.5:1 dan yuqori:

  | Token | Qorong'i | Yorug' |
  |---|---|---|
  | `mathVar1` (a) | `#38BDF8` — 6.8 / 8.7 | `#0369A1` — 5.9 / 5.4 |
  | `mathVar2` (b) | `#C4B5FD` — 7.9 / 10.0 | `#7C3AED` — 5.7 / 5.2 |
  | `mathVar3` (c) | `#F472B6` — 5.5 / 7.0 | `#BE185D` — 6.0 / 5.5 |

  Yorug' temadagi birinchi tanlov (`#0284C7`, `#DB2777`) o'lchovdan o'tmadi va almashtirildi.
  Yashil, qizil va sariq ataylab ishlatilmagan — ilovada ular «to'g'ri / xato / ogohlantirish»
  degani, o'zgaruvchi rangida esa chalkashtiradi.
- `MathText` (flutter_math_fork 0.7.4) yechim uchun yetarli. Sinab ko'rildi va to'rttasi ham
  xatosiz chizildi: `\textcolor` bilan rangli ajratish, `\dfrac{-b \pm \sqrt{D}}{2a}`,
  `\boxed{F = 10\ \text{N}}`, va uzun ifoda ichida rangli bo'lak.
- `image_picker` stackda bor — rasm kiritish uchun yangi paket kerak emas.

## 3. Yechim formati (AI qaytaradigan JSON)

> 2026-10-05: birinchi variant rad etildi — «maktab o'quvchisi tushunishi qiyin».
> Sababi: tushuntirish formulada edi, so'zda emas (qadam nomi 2–5 so'z, qolgani belgilar),
> qisqa yo'l (Viyet) tanlangan edi, va hisob tashlab ketilgan edi. Yangi format quyida.

Har bir qadam ikki qismdan iborat: **`say`** — o'qituvchi aytadigan oddiy gap, va
**`board`** — doskada yoziladigan qatorlar, hisobi bilan to'liq.

```json
{
  "kind": "math | physics | word",
  "asked": "Tenglamaning ikkita yechimini topamiz. Keyin 1 ni har biriga bo'lib, chiqqan sonlarni qo'shamiz.",
  "plan":  ["Tenglamadagi sonlarni yozib olamiz", "Diskriminantni topamiz",
            "Ikkala yechimni topamiz", "Ifodani hisoblaymiz"],
  "values": [
    {"name": "a", "label": "x² oldidagi son",   "value": "2",  "color": 1},
    {"name": "b", "label": "x oldidagi son",    "value": "-5", "color": 2},
    {"name": "c", "label": "yolg'iz turgan son", "value": "-3", "color": 3}
  ],
  "given": [], "find": [],
  "tape":  null,
  "steps": [
    {
      "title":   "Diskriminantni topamiz",
      "say":     "Diskriminant (D harfi bilan yoziladi) tenglamaning nechta yechimi borligini ko'rsatadi.",
      "board": [
        {"tex": "D = \\hlb{b}^2 - 4 \\cdot \\hla{a} \\cdot \\hlc{c}", "role": "formula"},
        {"tex": "D = (\\hlb{-5})^2 - 4 \\cdot \\hla{2} \\cdot (\\hlc{-3})"},
        {"tex": "D = 25 + 24"},
        {"tex": "D = 49", "role": "result"}
      ],
      "summary": "D = 49",
      "tip":     null,
      "simpler": ["(−5)² — bu −5 ni o'ziga ko'paytirish: (−5)·(−5) = 25.",
                  "4 · 2 · (−3) = 8 · (−3) = −24.",
                  "25 dan −24 ni ayirish — 24 ni qo'shish bilan bir xil: 25 + 24 = 49."],
      "rule":    "minus × minus = plyus"
    }
  ],
  "answer":   {"tex": "-\\frac{5}{3}", "value": "-5/3", "words": "minus uchdan besh", "unit": null},
  "check":    {"say": "x = 3 ni tenglamaga qo'yamiz:", "tex": "2 \\cdot 9 - 5 \\cdot 3 - 3 = 0"},
  "shortcut": {"title": "Viyet teoremasi", "steps": []},
  "real_life": null,
  "hints": {
    "C": {"headline": "Siz deyarli to'g'ri yechgansiz — faqat minus belgisi yo'qolgan.",
          "right_tex": "\\frac13 - 2 = -\\frac53", "wrong_tex": "\\frac53",
          "why": "Ikkinchi yechim manfiy: x₂ = −½. Shuning uchun 1 : (−½) = −2 — bu ham manfiy.",
          "tip": "Javobni tanlashdan oldin: «ishorasi to'g'rimi?»"}
  }
}
```

Maydonlar nima uchun:
- `asked` va `plan` — 1-ekran. Yechimdan oldin savol oddiy tilga o'giriladi va yo'l ko'rsatiladi.
- `values` — masaladagi sonlar va ularning rangi. Ilova masala matnida ham, doskada ham
  o'sha sonni o'sha rangda chizadi.
- `\v1{…}` `\v2{…}` `\v3{…}` — AI rang **tanlamaydi**, faqat qaysi qiymat ekanini belgilaydi.
  Ilova ularni temaga qarab `\textcolor` ga almashtiradi (5-bo'limdagi tokenlar).
- `summary` — qadam tugagach yig'iladigan yashil qator («D = 49»).
- `simpler` — «Tushunmadim» bosilganda. Bank savollari uchun oldindan yaratiladi.
- `tip` — faqat shu qadamda **ko'p uchraydigan** xato bo'lsa (ishora, birlik, maxraj).
- `tape` — matnli masala uchun chiziq rasmi:
  `{"total": "175 kg", "parts": [{"label": "1-kun", "expr": "x", "weight": 1}, …]}`.
- `real_life` — fizikada javobga ma'no beradi («10 N — taxminan 1 litr suvli shisha»).
- `shortcut` — qisqa yo'l, oxirida yopiq holda. Asosiy yechim **doim maktab usuli**.

### AI uchun yozish qoidalari (promptga kiradi va validator tekshiradi)
| Qoida | Mexanik tekshiriladimi |
|---|---|
| `say` — 1–2 gap, har biri 18 so'zdan oshmaydi, «biz» shaklida («topamiz») | ha |
| Yangi atama birinchi marta qavs ichida tushuntiriladi | yo'q — namunada tekshiriladi |
| `board` da har bir amal alohida qatorda: 25 + 24 yoziladi, keyin 49 | qisman — qator soni |
| Maktab usuli birinchi; qisqa yo'l faqat `shortcut` da | yo'q |
| `simpler` — har gapda bitta amal, raqamlar so'z bilan izohlanadi | ha — gap uzunligi |
| `answer.words` — kasr o'zbekcha o'qilishi bilan («uchdan besh») | ha — bo'sh emas |
| Fizikada har bir qiymat birligi bilan, formula ostida har harf va birligi | ha |
| Matnli masalada 1-qadam noma'lumni belgilaydi va **nega aynan shuni** aytadi | yo'q |

## 4. Ishonchlilik

### A rejimi: kalit bilan mexanik tekshirish
AI ga savol **va to'g'ri javob** beriladi: «shu javobga qanday kelinadi, tushuntir».
Keyin `answer.value` kalit bilan **kod orqali** solishtiriladi (sertifikat rejasidagi
qiymat→variant moslash funksiyasi bilan bir xil). Mos kelmasa — yechim saqlanmaydi va
qayta yaratiladi; ikki marta mos kelmasa `rejected` bo'ladi va odamga tushadi.

Tanlangan noto'g'ri variant ham beriladi — shunda «Nega B, C emas?» degan **aniq**
tushuntirish chiqadi (dizayndagi 7-ekran: «Siz ishorani yo'qotdingiz»).

### B rejimi: uch himoya
1. **Tasdiqlash ekrani** (dizayn, 2-ekran). Rasm noto'g'ri o'qilsa (−5 o'rniga 5), AI
   *boshqa masalani* mukammal yechadi va o'quvchi xatoni sezmaydi. Eng jim xato shu —
   va u yechimdan **oldin** ushlanadi.
2. **`check` maydoni** — javob shartga qayta qo'yiladi. AI o'z xatosini ko'pincha shu
   yerda ochib qo'yadi; `check` natijasi `answer` bilan mos kelmasa, yechim «ishonchsiz»
   deb belgilanadi.
3. **«Xato ko'rdingizmi?»** — har bir yechim ostida. Bu yagona sifat o'lchovi.

### Ikkala rejim: fikr
«Tushunarli bo'ldimi? 👍/🤔» — bitta tugma. Yechim to'g'ri, lekin tushunarsiz bo'lishi
mumkin; buni faqat o'quvchi aytadi.

## 5. Jadvallar — 3 ta yangi, mavjudlariga tegilmaydi

### `question_explanations` — bank savollari uchun (A rejimi)
| Ustun | Tur | Izoh |
|---|---|---|
| `id` | int PK | |
| `question_id` | FK → questions, **unique** | bir savolga bitta yechim |
| `payload` | JSONB | 3-bo'limdagi sxema |
| `status` | enum(generated, verified, rejected, reported) | |
| `matches_key` | bool | mexanik tekshiruv natijasi |
| `model` | varchar(80) | qaysi model yaratdi — keyin solishtirish uchun |
| `helpful_count`, `unclear_count`, `report_count` | int | |
| `created_at`, `verified_at` | timestamptz | |

`mistake_hint` bu yerda **saqlanmaydi**, chunki u tanlangan variantga bog'liq: savolga
uchta noto'g'ri variant bor, ya'ni uchta har xil izoh. Ular `payload.hints` ichida
`{"A": "...", "C": "...", "D": "..."}` ko'rinishida turadi.

### `solve_requests` — o'quvchining o'z masalasi (B rejimi)
| Ustun | Tur | Izoh |
|---|---|---|
| `id` | int PK | |
| `user_id` | FK → users | index |
| `subject` | varchar(30) | |
| `input_text` | text | tasdiqlangan matn |
| `input_image_url` | varchar(500) null | |
| `status` | enum(pending, done, failed) | |
| `payload` | JSONB null | |
| `model`, `latency_ms` | | sifat va narxni kuzatish uchun |
| `created_at` | timestamptz | |

`Index(user_id, created_at)` — kunlik limit shu indeks ustida sanaladi.

### `explanation_feedback`
`user_id`, `explanation_id` null, `solve_request_id` null (bittasi to'ldiriladi —
CheckConstraint), `verdict` enum(helpful, unclear, wrong), `comment` null, `created_at`.
`UniqueConstraint(user_id, explanation_id)` — bir o'quvchi bir marta ovoz beradi.

## 6. Endpointlar

| Metod | Yo'l | Nima qiladi |
|---|---|---|
| GET | `/student/questions/{id}/explanation/?chosen=C` | A: tayyor yechim + tanlangan variantga izoh. Hali yo'q bo'lsa 202 va fon vazifasi |
| POST | `/student/solve/` | B: rasm yoki matn → `solve_request` (`pending`), Celery vazifasi |
| POST | `/student/solve/recognize/` | B: faqat rasmni o'qiydi, tasdiqlash ekrani uchun |
| GET | `/student/solve/{id}/` | B: holat va natija (polling) |
| GET | `/student/solve/history/` | Oxirgi yechimlar |
| POST | `/student/explanations/feedback/` | 👍 / 🤔 / xato |

`/solve/recognize/` alohida, chunki tasdiqlash ekrani yechimdan **oldin** keladi:
avval o'qiymiz, o'quvchi tasdiqlaydi, keyin yechamiz. Ikkalasini bitta chaqiruvga
birlashtirish o'sha tasdiqlashni ma'nosiz qiladi.

## 7. Fazalar

| Faza | Ish | Nima uchun shu tartibda |
|---|---|---|
| **0** | **Model o'lchovi** — 100 ta matematika va 50 ta fizika savoli (kaliti ma'lum), 2–3 model, «javob kalit bilan mos» foizi va narxi | Qaysi modelni olish — taxmin emas, raqam bo'lsin. Bankda kaliti ma'lum 755 matematika savoli bor, ya'ni bu o'lchov bugun mumkin |
| 1 | `question_explanations` + `explain_problem()` + kalit tekshiruvi | A rejimining asosi |
| 2 | Bank savollariga oldindan yaratish (Celery, kecha) | O'quvchi kutmaydi |
| 3 | Mobil: Xatolarimda «Nega?» varag'i + to'liq yechim ekrani | Eng qimmatli joy |
| 4 | `solve_requests` + rasm o'qish + tasdiqlash | B rejimi |
| 5 | Mobil: kiritish, tasdiqlash, kutish, yechim | |
| 6 | Fikr, limit, planshet, ikki tema | |

## 8. Ochiq savollar

1. **Kunlik limit** — B rejimi har so'rovda pul turadi va uy vazifasini ko'chirish uchun
   ishlatiladi. Kuniga nechta? (Dizaynda 10 deb olingan.)
2. **Uy vazifasi** — qadamlarning birma-bir ochilishi ko'chirishni sekinlashtiradi, lekin
   to'xtatmaydi. Bu qabul qilinadimi, yoki B rejimi faqat bankdagi o'xshash masalaga
   yo'naltirsinmi?
3. **Model va narx** — 0-faza natijasiga qarab tanlanadi. Byudjet chegarasi bormi?
4. **Til** — yechim faqat o'zbekchami (lotin)? Rus guruhlari bormi?
5. **Fanlar** — faqat matematika va fizikami, yoki kimyo ham (u ham hisob-kitobli)?
