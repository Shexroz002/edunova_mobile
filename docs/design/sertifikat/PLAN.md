# Milliy sertifikat rejimi — tahlil va reja

> **TO'XTATILGAN** (egasining qarori, 2026-10-05): aniq qaror qabul qilinmaguncha
> qurilmaydi. Bu hujjat — faqat taklif. Kodga, bazaga va migratsiyalarga tegilmagan.

Holat: **taklif**. Dizayn: `sertifikat.html`. Manba: matematika namunaviy testi va
rasmiy javoblar varaqasi (2026-10-05 da o'rganildi).

## 1. Imtihon tuzilmasi (hujjatdan aniqlangan)

| Qism | Topshiriq | Javob usuli | Ball | Jami |
|---|---|---|---|---|
| 1 | 1–32 | A/B/C/D, bitta to'g'ri | 10 ta × 1,3 va 22 ta × 2,2 | **61,4** |
| 2 | 33–35 | A–F **umumiy** ro'yxatdan, bitta kontekst | 3 × 2,2 | **6,6** |
| 3 | 36–45 | yozma javob, har birida a) va b) | 10 × (1,5 + 1,7) | **32,0** |
| | **45 topshiriq · 55 javob katagi** | | | **100,0** |

Yig'indi aniq 100,0 chiqdi — bu ball qiymatlari to'g'ri o'qilganini tasdiqlaydi.

Javoblar varaqasidagi fanlar: **Matematika, Fizika, Kimyo, Biologiya, Tarix, Geografiya**.
Oltalasi ham `subjects` jadvalida bor.

Davomiylik: **150 daqiqa** (egasining qarori, 2026-10-05 — rasmiy hujjatda yozilmagan).

## 1a. Daraja xom balldan kelib chiqmaydi — bu eng muhim topilma

`Baholash_mezoni.pdf` ga ko'ra daraja uch bosqichda hisoblanadi:

1. Javoblar **Rasch modeli** bilan baholanadi va qobiliyat θ topiladi;
2. `Z = (θ − μ) / σ` — bu yerda μ va σ **o'sha imtihonni topshirgan butun oqimning**
   o'rtachasi va standart tafovuti;
3. `T = 50 + 10Z` — standart ball. Daraja shu **T** dan olinadi.

Ya'ni egasidan kelgan chegaralar (A+ ≥ 70, A 65–69,9, …) **T shkalasiga** tegishli,
testdan olingan 100 ballik xom natijaga emas. Ikkalasi bir xil raqam emas: T = 50 —
bu oqimning o'rtasi, kim qancha yozganiga qarab har safar boshqa joyga tushadi.

Hujjatning 2-sahifasi buni tasdiqlaydi: sertifikat T-balli OTM test ballariga
`Ball × 93/65` formulasi bilan o'tkaziladi va jadvaldagi sakkizta qiymatning hammasi
shu formulaga aniq mos keldi (64,9 → 92,86; 46 → 65,82).

**Oqibati:** ilova bitta o'quvchining javobidan **rasmiy darajani hisoblay olmaydi**.
Oqim yo'q — μ va σ yo'q.

Uch yo'l bor:

1. **Faqat xom ball** ko'rsatiladi (100 dan), daraja umuman aytilmaydi. Halol, lekin
   o'quvchiga «men qayerdaman» degan javobni bermaydi.
2. **Taxminiy daraja** — egasining chegaralari xom ballga qo'llanadi va ekranda
   *taxminiy* deb belgilanadi. Oddiy, lekin rasmiy natijadan farq qilishi mumkin.
3. **EduNova oqimi bo'yicha** — o'sha variantni ishlagan barcha foydalanuvchilar
   bo'yicha μ va σ hisoblanadi, T chiqariladi. Bu rasmiy mexanizmning aynan o'zi,
   faqat oqim kichikroq. Variantda kamida ~30 ta urinish yig'ilgach ishlay boshlaydi.

**Tavsiyam: 2 bilan boshlash, 3 ni ustiga qurish.** Ikkalasi bir ustunda yashamaydi,
shuning uchun `cert_attempts` da **ikkita** ball saqlanadi: `raw_score` (har doim bor,
aniq) va `t_score` (oqim yetarli bo'lganda to'ladi). Daraja `t_score` bor bo'lsa undan,
bo'lmasa `raw_score` dan olinadi va ekranda qaysi biri ekani aytiladi.

Ekranda hech qachon shunchaki «A daraja» deyilmaydi: yo «taxminiy A daraja», yo
«EduNova oqimida A daraja». Rasmiy darajani faqat Davlat test markazi beradi.

### Til fanlari boshqacha
Hujjatning 3–4 sahifasi: o'zbek/rus/qoraqalpoq tili va adabiyotida **yozma ish** bor
(24 ballik mezon → 75 ballik shkala, ekspertlar baholaydi, ikki bo'limning o'rtachasi
olinadi). Bu butunlay boshqa model va **birinchi bosqichga kirmaydi**.

## 2. Hozirgi sxema buni ko'tara olmaydi

Ilovaning butun savol modeli bitta shaklga qurilgan: `questions` + `options.is_correct`,
javob esa `attempt_answers.selected_option` (varchar(5)). Bu **faqat 1-qismni** ifodalaydi,
u ham to'liq emas.

| Kerak | Hozir bormi | Izoh |
|---|---|---|
| Savolga ball qiymati | **yo'q** | `questions` da `difficulty` matn bor, ball yo'q |
| Umumiy kontekst (33–35, 36–45) | **yo'q** | savollarni guruhlash mexanizmi yo'q |
| A–F umumiy variantlar ro'yxati | **yo'q** | `options` har bir savolga alohida bog'langan |
| Yozma javob | **yo'q** | variantsiz javob saqlanmaydi, tekshirilmaydi |
| Bitta topshiriqda a) va b) | **yo'q** | |
| Qisman ball (1,5 olib 1,7 ni yo'qotish) | **yo'q** | `quiz_attempts.score` — butun son |

Ya'ni **100 balldan 38,6 tasi** (2- va 3-qism) bugungi sxemada umuman ifodalanmaydi.

## 3. Foydasi bormi — ha, va blok imtihondan ko'ra ko'proq

Avvalgi blok imtihon rejasini **kontent o'ldirgandi**: majburiy Tarix 30 ta savol bilan
butun featureni 3 ta takrorlanmas imtihonga cheklagan edi. Sertifikatda bu muammo **yo'q**,
chunki sertifikat bitta fanga beriladi — matematika varianti uchun faqat matematika kerak,
bazada esa 755 ta yaroqli matematika savoli bor.

Yana uchta sabab:

1. **Imtihon yil davomida bo'ladi**, DTM kabi yiliga bir marta emas. Ya'ni featureda
   mavsumiylik yo'q.
2. **Natija aniq va shaxsiy** — ball emas, sertifikat va daraja. O'quvchi nima uchun
   ishlayotganini biladi.
3. **Format ochiq e'lon qilingan**, ya'ni ilova uni aynan takrorlashi mumkin.

Rostini aytganda, xarajat ham bor:

- **3-qism 32 ball** — bu yangi kod (javob tekshirish dvigateli) va yangi kontent
  (qabul qilinadigan javoblar ro'yxati). Mavjud 755 savolning bittasi ham bunga yaramaydi.
- **Javobni avtomatik tekshirish — eng xavfli joy.** «3,5» va «3.5», «7/2», «√3», «33⅓»
  bir xil javobning turli yozuvi. Noto'g'ri tekshirilgan javob o'quvchining ishonchini
  butunlay yo'qotadi, va bu xato jim ketadi.
- Variantlar **qo'lda kiritilishi** kerak: 45 topshiriq, 55 javob, har biri tekshirilgan.
  AI generatori bunga yaramaydi — namunaviy test rasmiy manba, uni generatsiya qilib
  bo'lmaydi.

**Tavsiyam: qilish kerak, lekin bir fandan va to'liq.** Matematikadan 2–3 ta to'liq variant,
uchchala qism bilan. «Faqat 1-qism» deb chiqarish eng yomon variant: o'quvchi 61,4 balllik
mashqda yaxshi natija ko'rib, 32 ballik qismga tayyorlanmagan holda imtihonga boradi.

## 4. Jadvallar — 7 ta yangi, mavjudlariga tegilmaydi

Siz aytganingizdek, butunlay alohida. Hammasi `cert_` prefiksi bilan. Mavjud `questions`,
`options`, `quiz_sessions`, `attempt_answers` ga **bir dona ustun ham qo'shilmaydi**, ya'ni
teacher paneli, Telegram bot va web ilovaga ta'sir nol.

### `cert_grade_bands` — daraja chegaralari
Chegaralar o'zgaradi, shuning uchun kodda emas, jadvalda.

| Ustun | Tur | Izoh |
|---|---|---|
| `id` | int PK | |
| `grade` | varchar(3) | A+, A, B+, B, C+, C |
| `min_score` | numeric(5,2) | 70.00, 65.00, 60.00, 55.00, 50.00, 46.00 |
| `max_score` | numeric(5,2) null | null = yuqori chegarasiz |
| `scale` | enum(raw, t) | qaysi shkalaga tegishli |
| `note` | varchar(200) null | "OTM test sinovida maksimal ball beriladi" (A+ va A) |

Egasining chegaralari (2026-10-05): A+ ≥ 70 · A 65–69,9 · B+ 60–64,9 · B 55–59,9 ·
C+ 50–54,9 · C 46–49,9. 46 dan past — sertifikat berilmaydi.

### `cert_exams` — variant (imtihon varaqasi)
| Ustun | Tur | Izoh |
|---|---|---|
| `id` | int PK | |
| `subject_id` | FK → subjects | |
| `title` | varchar(200) | "Matematika · 3-variant" |
| `variant_no` | int | |
| `total_score` | numeric(5,2) | 100.00 |
| `duration_minutes` | int | 150 (default) |
| `is_active` | bool | tayyorlanmagan variant ko'rinmaydi |
| `source` | varchar(50) | namunaviy / qo'lda / AI |

### `cert_sections` — qismlar
| Ustun | Tur | Izoh |
|---|---|---|
| `exam_id` | FK → cert_exams | cascade |
| `kind` | enum(choice, matching, open) | **uch qism uch xil ishlaydi** |
| `title` | varchar(120) | |
| `position` | int | |
| `instructions` | text null | |

### `cert_groups` — umumiy kontekst
33–35 bitta matn va chizmani bo'lishadi; 36–45 da esa stem bor, a) va b) undan oqadi.
Ikkalasi ham bitta mexanizm.

| Ustun | Tur | Izoh |
|---|---|---|
| `section_id` | FK → cert_sections | |
| `body` | text null | umumiy matn |
| `table_markdown` | text null | |
| `image_url` | varchar(500) null | |
| `position` | int | |

### `cert_tasks` — bitta javob katagi
Qo'shimcha ustun: `answer_format` enum(integer, decimal, fraction, expression) — 4a ga qarang.

| Ustun | Tur | Izoh |
|---|---|---|
| `section_id` | FK → cert_sections | |
| `group_id` | FK → cert_groups, null | |
| `number` | varchar(8) | "14", "33", "38a", "38b" |
| `position` | int | 1..55 |
| `points` | numeric(4,2) | 1.30 / 2.20 / 1.50 / 1.70 |
| `body` | text null | guruhda bo'lsa qisqa savol |
| `table_markdown`, `image_url` | | |
| `answer_kind` | enum(option, text) | |

Muhim qaror: **bir qator = bir javob katagi**, topshiriq emas. Shuning uchun 38a va 38b
ikkita qator. Ball har bir katakka tegishli, qisman ball shundan o'zi kelib chiqadi.

### `cert_options` — variantlar
| Ustun | Tur | Izoh |
|---|---|---|
| `task_id` | FK → cert_tasks, null | 1-qism uchun |
| `group_id` | FK → cert_groups, null | **2-qism uchun: A–F guruhga tegishli** |
| `label` | varchar(2) | A..F |
| `text` | text | |
| `is_correct` | bool | guruh variantida ishlatilmaydi |

`task_id` yoki `group_id` — bittasi to'ldiriladi (CheckConstraint).
2-qismda to'g'ri javob variantda emas, `cert_task_answers` da yoziladi.

### `cert_task_answers` — qabul qilinadigan javoblar
| Ustun | Tur | Izoh |
|---|---|---|
| `task_id` | FK → cert_tasks | |
| `value` | varchar(100) | normallashtirilgan ko'rinish |
| `is_primary` | bool | natijada ko'rsatiladigani |

Bitta topshiriqda bir nechta qator: `3,5` · `3.5` · `7/2`. Normallashtirish qoidalari
(probel olib tashlash, `.`→`,`, kasrni qisqartirish) servisda, migratsiyada emas.

### `cert_attempts` — urinish
`user_id`, `exam_id`, `status` enum(running, finished, expired), `started_at`,
`deadline_at` (index), `finished_at`, `total_score` numeric(5,2), `max_score` numeric(5,2),
`raw_score` numeric(5,2) null, `t_score` numeric(5,2) null, `grade` varchar(3) null,
`grade_scale` enum(raw, t) null. `Index(user_id, status)`, `Index(exam_id, status)`.

`max_score` nusxa sifatida saqlanadi — variant keyin o'zgarsa ham eski natija buzilmaydi.
`Index(exam_id, status)` oqim statistikasi uchun: bitta variantning barcha tugagan
urinishlari bo'yicha μ va σ shu indeks ustida hisoblanadi.

### `cert_attempt_answers` — javoblar
`attempt_id`, `task_id`, `selected_option` varchar(2) null, `text_value` varchar(100) null,
`is_correct` bool, `awarded_points` numeric(4,2), `is_flagged` bool, `answered_at`.
`UniqueConstraint(attempt_id, task_id)` — upsert.

### Xatolarim bilan bog'lanish: yo'q
`mistake_reviews.question_id` → `questions.id` FK. Sertifikat topshiriqlari `cert_tasks` da
yashaydi, ya'ni ularni mavjud bankka **qo'shib bo'lmaydi** — buning uchun FK ni buzish
kerak bo'lardi. Birinchi bosqichda sertifikat xatolari o'z ichida qoladi («Javoblarni ko'rib
chiqish»). Keyin kerak bo'lsa alohida `cert_mistake_reviews` qo'shiladi.

### Statistikaga ta'sir: yo'q
`cert_attempts` alohida. Natijalar ro'yxati, o'rtacha ball va Statistika tabi tegilmaydi.
100 ballik natijani foizlik o'rtachaga qo'shish ikkalasini ham ma'nosiz qiladi.

## 4a. Javobni tekshirish — o'lchangan xavf

Namunaviy testning 20 ta ochiq javob katagi turiga qarab ajratildi:

| Tur | Katak | Ball | Misol |
|---|---|---|---|
| Butun son | 9 | 14,4 | ildizlar soni, gradus, dollar |
| O'nlik/kasr | 6 | 9,6 | 3,5 · 4/3 · 33⅓ |
| **Simvolik** | **5** | **8,0** | π/8 · √15/2 · nisbatlar |

Normallashtirish prototipi sinab ko'rildi. Oddiy sonlarda ishonchli: `16` · `16,0` ·
`16.00`, `-1` · `−1` · `– 1` (uch xil tire), `3,5` · `3.5` · `7/2` — hammasi mos tushdi.
Yiqilgan joylar ikki xil sababga bo'lindi:

- **Tuzatiladigan xatolar:** `+16` dagi ortiqcha, `33 1/3` dagi probel. Bir necha qator kod.
- **Tamoman tuzatib bo'lmaydigan:** `pi/8` ⟷ `π/8`, `sqrt(15)/2` ⟷ `√15/2`,
  `1,3333` ⟷ `4/3`. Bularni hech qanday normallashtirish ishonchli hal qilmaydi.

### Yechim: javob turini muallif tanlaydi, klaviatura esa kiritishni cheklaydi

`cert_tasks.answer_format` enum(integer, decimal, fraction, expression):

| Format | Klaviatura | Tekshirish |
|---|---|---|
| integer | 0–9, − | normallashtirgandan keyin aniq taqqoslash |
| decimal | 0–9, −, vergul | `Fraction` orqali qiymat taqqoslash |
| fraction | 0–9, −, / | `Fraction` orqali, `8/6` = `4/3` |
| expression | faqat π, √, /, raqamlar | `cert_task_answers` ro'yxati bilan taqqoslash |

Asosiy fikr: **o'quvchi `pi` deb yoza olmaydi**, chunki klaviaturada `p` harfi yo'q —
faqat `π` tugmasi bor. Tizim klaviaturasi ochilmaydi. Shu bilan simvolik javoblardagi
xavfning kattasi kiritish bosqichida yo'q qilinadi, tekshirish bosqichida emas.

Qoladigan xavf: bitta qiymatning bir nechta to'g'ri yozuvi (`√15/2` va `0,5√15`).
Buni muallif `cert_task_answers` ga bir nechta qator qo'shib yopadi. Variantiga 1–2 ta
katak — ya'ni 100 balldan ~3 ball.

### Muallif uchun qoidalar
- **Kalitda birlik yozilmaydi.** `52`, `52 cm²` emas. Birlik savol matnida turadi
  (haqiqiy testda ham shunday: «yuzini (cm²) toping»).
- **Taqribiy qiymat kalit bo'lmaydi.** Javob `4/3` bo'lsa, `1,33` qabul qilinmaydi;
  format `fraction` qilinadi.
- Har bir simvolik katakka **kamida ikkita** qabul qilinadigan yozuv kiritiladi.

## 4b. AI bilan kontent kiritish va uni tekshirish

Egasining qarori (2026-10-05): PDF dan AI orqali JSON ga o'tkaziladi, javoblarni ham
AI beradi. Bu ishlaydi, lekin **AI ikkita butunlay boshqa ishni qiladi** va ularning
xato darajasi bir xil emas:

| Ish | Xato darajasi | Mexanik tekshirib bo'ladimi |
|---|---|---|
| **Chiqarib olish** (matn, variant, ball, raqamlash) | past | **ha, to'liq** |
| **Yechish** (to'g'ri javobni topish) | yuqori | qisman |

Shuning uchun ikkita alohida nazorat qatlami kerak.

### Qatlam 1 — mexanik validator (odamsiz, qattiq to'siq)

Namunaviy testning ichki invariantlari shunchalik qattiqki, chiqarib olishdagi xatolarning
deyarli hammasi shu yerda ushlanadi:

- ball yig'indisi **aniq 100,0**;
- kataklar `1..35` + `36a..45b`, uzilishsiz, takrorsiz;
- 1–32: variantlar aynan `A,B,C,D`, **aniq bitta** to'g'ri, ball `1,3` yoki `2,2`;
- 33–35: bitta umumiy guruh, umumiy ro'yxat aynan `A..F`, ball `2,2`;
- 36a/36b: ball `1,5` va `1,7`, kalit bor, **kalitda birlik yo'q**, simvolik javobga
  kamida ikkita yozuv;
- kalitlar taqsimoti: bitta harf 60% dan ko'p bo'lsa — AI bir xil javob bergan.

Prototip yozilib sinaldi: ettita sun'iy buzilgan variantning (ball noto'g'ri o'qilgan,
savol tushib qolgan, ikkita to'g'ri belgilangan, ro'yxat A–D qilingan, kalitda birlik,
simvolik javob yolg'iz, hammasi «C») **yettitasi ham ushlandi**. To'g'ri variant esa
xatosiz o'tdi.

Bu validator importning majburiy qismi: o'tmagan variant bazaga **umuman yozilmaydi**.

### Qatlam 2 — javobni tekshirish

Validator tuzilmani tekshiradi, javobni emas. AI ishonch bilan noto'g'ri variantni
tanlasa, yuqoridagi tekshiruvlardan bemalol o'tadi. To'rtta mustaqil nazorat:

1. **Uch marta mustaqil yechish.** AI dan javob uch marta (yoki uch xil model bilan)
   alohida so'raladi. Uchalasi mos kelmasa — odamga. Kelishmovchilik qiyinlikning
   ishonchli belgisi; moslik kafolat emas, lekin ishonchni sezilarli oshiradi.
2. **Mashina bilan yechish (sympy).** AI dan faqat javob emas, **tekshirish mumkin
   bo'lgan oraliq natija** so'raladi (tenglama ildizlari, ifoda, hosila). Keyin sympy
   uni mustaqil hisoblaydi. Sinab ko'rildi: 1, 5, 14 va 16-savollar to'liq avtomatik
   yechildi va javoblari tasdiqlandi.
3. **Qiymatni variantga mexanik moslash.** 1-qismda javob — A/B/C/D dan biri. Hisoblangan
   qiymat variantlarga **kod orqali** moslanadi. Hech biriga mos kelmasa yoki ikkitasiga
   mos kelsa — odamga. Bu nazorat zarurligi demo paytida isbotlandi: hisoblangan qiymat
   to'g'ri (15) bo'lsa ham, uni qo'lda harfga bog'lashda xato ketdi. Qiymat→harf
   bog'lanishi **hech qachon qo'lda yoki AI tomonidan** qilinmaydi.
4. **Chizmali savollar har doim odamga.** Bu variantda 8 ta chizma bor (27, 33–35, 38,
   39, 41, 42, 43, 45). Ularni sympy tekshira olmaydi, chunki javob chizmani
   o'qishga bog'liq. Eng yuqori xavf shu yerda.

### Qatlam 3 — ishga tushgandan keyin (eng kuchli, lekin kechikkan)
`cert_tasks` ga `needs_review` bayrog'i qo'yiladi va javoblar taqsimoti kuzatiladi:
agar o'quvchilarning 80% i `B` ni tanlasa, kalit esa `C` bo'lsa — kalit deyarli aniq
noto'g'ri. Bu psixometriyadagi oddiy item analysis va u tekin ishlaydi.

Shuning uchun birinchi variant **«sinov»** holatida chiqariladi: natija ko'rsatiladi,
lekin dastlabki ~50 urinish kalitlarni tekshirish uchun ishlatiladi.

### `cert_tasks.verification` holati
enum(`ai_only`, `machine_verified`, `human_verified`, `disputed`).
**Variant `is_active` bo'la olmaydi**, agar ichida bitta ham `ai_only` katak qolsa.
Bu — featureni yolg'ondan saqlaydigan yagona qattiq qoida.

### Nechta katak odamga qoladi
Taxminan: 55 katakdan ~25–30 tasi mashina bilan tasdiqlanadi (algebra, tenglama,
hosila, integral, ehtimollik), ~8 tasi chizmali — har doim odamga, qolgani uch marta
yechish natijasiga qarab. Ya'ni **~20–25 katak** odam ko'zidan o'tadi. Bu hammasini
qo'lda kiritishdan ancha kam, lekin nolga tushmaydi va tushmasligi ham kerak.

## 5. Endpointlar — `/api/v1/student/certificates`

| Metod | Yo'l | Nima qiladi |
|---|---|---|
| GET | `/subjects/` | 6 fan + har birida nechta tayyor variant, eng yaxshi ball |
| GET | `/subjects/{id}/exams/` | Variantlar ro'yxati, ishlangani belgisi bilan |
| GET | `/active/` | Ochiq urinish bo'lsa qaytaradi |
| POST | `/exams/{id}/start/` | Urinish ochadi, `deadline_at` qo'yadi, 409 — ochiq urinish bor |
| GET | `/attempts/{id}/` | To'liq varaqa: qismlar, guruhlar, topshiriqlar, berilgan javoblar |
| PUT | `/attempts/{id}/answers/{task_id}/` | Javobni yozadi (upsert), **natija qaytarmaydi** |
| PUT | `/attempts/{id}/flag/{task_id}/` | Shubhali belgisi |
| POST | `/attempts/{id}/finish/` | Ball va daraja hisoblanadi, 409 — yopilgan |
| GET | `/attempts/{id}/result/` | Ball, qism kesimi, har bir javob to'g'ri/xato + kalit |
| GET | `/history/` | Urinishlar va ball dinamikasi |

Ikki qoida blok imtihondagidek: **javob endpointi to'g'riligini aytmaydi** va **varaqada
kalit bo'lmaydi** — aks holda javobni trafikdan ko'rish mumkin.

Vaqtni mavjud `finalize_expired_quiz_sessions` Celery vazifasi yopadi (unga shu jadval ham
qo'shiladi).

## 5a. Tizimga ta'siri — o'lchangan

Backend: **321 fayl, 26 832 qator**. Mobil: **164 fayl, 32 635 qator**.
O'lchov birligi sifatida yaqinda qurilgan Xatolarim olindi — u ham shu shakldagi ish edi.

| | Xatolarim (fakt) | Sertifikat (baho) |
|---|---|---|
| Jadval | 1 | 8 |
| Endpoint | 3 | 10 |
| Savol turi | 1 | 3 + javob tekshirish |
| Backend kodi | 719 qator | ~2000 qator |
| Mobil kodi | 1362 qator | ~2800 qator |
| **Tegilgan mavjud fayl** | **3 (+11 qator)** | **~4 (+15 qator)** |

Tegiladigan mavjud fayllar: `student/quiz/router.py` (yo'nalish ro'yxatdan o'tadi),
`models/__init__.py` (import), `celery_app.py` (muddati o'tgan urinishni yopish).
Hammasi qo'shimcha — bir dona mavjud qator o'zgartirilmaydi.

Ya'ni kodning **0,06%** iga tegiladi. `questions` 24 ta faylda, `attempt_answers` 11 ta
faylda ishlatilgan — shularning bittasi ham ochilmaydi. Teacher paneli, Telegram bot va
web ilova uchun bu feature ko'rinmaydi.

### Tayyor turgan narsalar
Mobil tomonda render qismi allaqachon bor va ishlab turibdi: `MathText` (LaTeX),
`MarkdownTable` (jadval), `QuestionPicture` (chizma), `OptionTile` (variant).
Ya'ni 1-qism ekrani mavjud vidjetlardan yig'iladi. Yangi chiziladigani — faqat
matematik klaviatura va javoblar varaqasi.

## 6. Fazalar

| Faza | Ish |
|---|---|
| **1** | 7 jadval + migratsiya. Mavjud jadvallarga tegilmaydi |
| **2** | Admin/seed: matematika namunaviy testini kiritish (45 topshiriq, 55 javob) |
| **3** | Javob tekshirish dvigateli + normallashtirish, **birinchi navbatda testlari bilan** |
| **4** | 10 endpoint |
| **5** | Mobil: fan tanlash, tuzilma ekrani, tarix |
| **6** | Mobil: 1-qism va javoblar varaqasi |
| **7** | Mobil: 2-qism (moslashtirish) va 3-qism (klaviatura bilan) |
| **8** | Natija, daraja, javoblarni ko'rib chiqish |
| **9** | Planshet, ikki tema, 55 katakda ishlash tezligi |

3-faza boshqalaridan oldin, chunki u eng xavfli: javob noto'g'ri tekshirilsa, qolgan
hammasi ma'nosiz.

## 7. Egasining qarorlari (2026-10-05)

| | Qaror |
|---|---|
| Davomiylik | **150 daqiqa**, variantda o'zgartirsa bo'ladi |
| Daraja chegaralari | A+ ≥ 70 · A 65–69,9 · B+ 60–64,9 · B 55–59,9 · C+ 50–54,9 · C 46–49,9 |
| Kontent | **qo'lda kiritiladi**, namunaviy PDF qanday bo'lsa shundayligicha |
| Qisman ball | **ha** — a) va b) alohida baholanadi |
| Moslashtirishda takror harf | **ruxsat**, varaqa ham taqiqlamaydi |

A+ va A darajali sertifikat OTM bakalavriatiga kirish test sinovlarida o'sha fandan
maksimal ball beradi (1-fan 93, 2-fan 63). Pastroq darajalar proporsional:
`T-ball × 93/65`. Bu natija ekranida aytib o'tilishi kerak — o'quvchi nima uchun
ishlayotganini shundan biladi.

## 8. Hal qilinishi kerak bo'lgan bitta savol

Darajani qanday ko'rsatamiz? 1a-bo'limda uchta yo'l bor. Mening taklifim — xom ballga
qo'llangan **«taxminiy daraja»**, keyinchalik EduNova oqimi bo'yicha haqiqiy T-ballga
o'tish. Agar «taxminiy» so'zi ortiqcha deb hisoblasangiz, aytasiz — lekin u bo'lmasa
ilova o'quvchiga Davlat test markazi beradigan natijani va'da qilib qo'yadi.
