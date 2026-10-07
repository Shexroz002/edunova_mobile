# Blok imtihon rejimi — reja

> **TO'XTATILGAN** (egasining qarori, 2026-10-05): aniq qaror qabul qilinmaguncha
> qurilmaydi. Bu hujjat — faqat taklif. Kodga, bazaga va migratsiyalarga tegilmagan.

Holat: **taklif**. Egasining tasdig'ini kutmoqda. Dizayn: `blok.html`.

## 1. Nima quriladi

To'liq imtihon taqlidi: bitta o'tirishda 90 savol, 3 soat, 189 ballik shkala.
Xatolarimdan farqi tamoman boshqa maqsadda: Xatolarim **o'rgatadi** (javob darhol ochiladi),
blok imtihon **o'lchaydi** (javob faqat yakunda ochiladi, pauza yo'q, vaqt serverda yuradi).

## 2. Eng muhim cheklov: kontent yetishmaydi

Bu kod muammosi emas, va uni kod hal qilmaydi.

| Fan | Yaroqli savol | Bir o'tirishga kerak | Nechta takrorlanmas imtihon |
|---|---|---|---|
| Matematika | 755 | 30 + 10 | 18 |
| Fizika | 402 | 30 | 13 |
| Biologiya | 240 | 30 | 8 |
| Kimyo | 215 | 30 | 7 |
| Ona tili va adabiyot | 70 | 10 | **7** |
| **Tarix** | **30** | **10** | **3** |
| Geografiya | 30 | 30 | 1 |
| Ingliz tili | 30 | — | — |

Majburiy fanlar har bir blokda bor, ya'ni **Tarix butun featureni 3 ta takrorlanmas
imtihonga cheklaydi**. To'rtinchi o'tirishda o'quvchi aynan o'sha savollarni ko'radi va
bu featureni bir hafta ichida o'ldiradi.

Uch yo'l bor, qaysi birini tanlash egasiniki:

1. **Kontent to'ldiriladi** — Tarix va Ona tiliga ~300 tadan savol. Ilovada AI generator
   bor (`ai_test_generator` navbati), ya'ni bu texnik emas, sifat nazorati masalasi.
2. **Qisqa format** — majburiy fanlarsiz, faqat 2 blok fani (60 savol, 2 soat, 156 ball).
   Bugungi kontent bunga yetadi va formatni keyin to'liq qilish mumkin.
3. **Kutiladi** — kontent tayyor bo'lgunicha feature boshlanmaydi.

Tavsiyam: **2-variant bilan boshlash**. Ishlaydigan qisqa imtihon, ishlamaydigan to'liq
imtihondan yaxshi, va shkalani keyin kengaytirish bitta `exam_block_subjects` qatori.

## 3. Nega mavjud jadvallarga sig'maydi

Ikkita devor bor:

- `quiz_sessions.quiz_id` — sessiya **bitta** quizga tegishli, quiz esa bitta fanga.
  Blok imtihon 3 fanni qamraydi.
- `questions.quiz_id` — savol **bitta** quizga tegishli (FK savolning o'zida).
  Ya'ni mavjud savollardan yangi "imtihon quizi" yasab bo'lmaydi: savolni ko'chirish
  kerak bo'ladi, bu esa statistikani va Xatolarim bog'lanishini buzadi.

Shuning uchun blok imtihon mavjud `quizzes`/`quiz_sessions` ni qayta ishlatmaydi,
`questions.id` ga to'g'ridan-to'g'ri murojaat qiladigan o'z jadvallarini oladi.

## 4. Jadval o'zgarishlari

Hammasi yangi. Mavjud jadvallarga **o'zgarish yo'q** — bir dona ustun ham qo'shilmaydi,
ya'ni teacher, Telegram bot va web ilovaga ta'sir nol.

### `exam_blocks` — bloklar katalogi
| Ustun | Tur | Izoh |
|---|---|---|
| `id` | int PK | |
| `name` | varchar(120) | "Matematika · Fizika" |
| `description` | text null | |
| `duration_minutes` | int | 180 |
| `is_active` | bool | o'chirilgan blok ro'yxatda turadi, lekin boshlanmaydi |
| `sort_order` | int | |

### `exam_block_subjects` — blok tarkibi va ball og'irligi
| Ustun | Tur | Izoh |
|---|---|---|
| `id` | int PK | |
| `block_id` | FK → exam_blocks | cascade |
| `subject_id` | FK → subjects | |
| `question_count` | int | 30 yoki 10 |
| `points_per_question` | numeric(4,2) | 3.10 / 2.10 / 1.10 |
| `position` | int | savollar shu tartibda joylashadi |

Imtihon formati shu yerda **ma'lumot** sifatida yashaydi, kodda emas. DTM shkalasi
o'zgarsa, migratsiya emas, qator tahriri kifoya. Bitta fan bir blokda ikki marta kelishi
mumkin (Matematika 1-blok 30×3.1 va majburiy 10×1.1) — shuning uchun `position` bor,
`UniqueConstraint(block_id, subject_id)` esa **yo'q**.

### `exam_sessions` — bitta o'tirish
| Ustun | Tur | Izoh |
|---|---|---|
| `id` | int PK | |
| `user_id` | FK → users | index |
| `block_id` | FK → exam_blocks | |
| `status` | enum(running, finished, expired) | |
| `started_at` | timestamptz | |
| `deadline_at` | timestamptz | index — vaqt shu yerda, klientda emas |
| `finished_at` | timestamptz null | |
| `total_score` | numeric(6,2) null | 134.10 |
| `max_score` | numeric(6,2) | 189.00 — blok o'zgarsa ham tarix buzilmasin |
| `correct_count` / `answered_count` | int | yakunda yoziladi |

`Index(user_id, status)` — ochiq sessiyani topish uchun.

### `exam_session_questions` — o'sha o'tirishning savol varaqasi
| Ustun | Tur | Izoh |
|---|---|---|
| `id` | int PK | |
| `exam_session_id` | FK → exam_sessions | cascade |
| `question_id` | FK → questions | |
| `subject_id` | FK → subjects | |
| `position` | int | 1..90 |
| `points` | numeric(4,2) | tanlangan paytdagi og'irlik nusxasi |

`UniqueConstraint(exam_session_id, position)` va `(exam_session_id, question_id)`.
Varaqa boshlanishida **bir marta** yoziladi va qotadi: ilovani qayta ochganda savollar
aralashib ketmaydi.

### `exam_answers` — javoblar
| Ustun | Tur | Izoh |
|---|---|---|
| `id` | int PK | |
| `exam_session_id` | FK → exam_sessions | cascade |
| `question_id` | FK → questions | |
| `selected_option` | varchar(5) null | null = tozalandi |
| `is_correct` | bool | |
| `is_flagged` | bool | "belgilab qo'yish" ham serverda — telefon almashsa yo'qolmaydi |
| `answered_at` | timestamptz | |

`UniqueConstraint(exam_session_id, question_id)` — upsert.

### Xatolarim bilan bog'lanish
`MistakeRepository.missing_question_ids` hozir faqat `attempt_answers` ni o'qiydi.
Unga `exam_answers` dan `is_correct = false` bo'lganlar **UNION** qilib qo'shiladi
(`_answerable` filtri bilan birga). Boshqa o'zgarish kerak emas — blok imtihondagi
xatolar o'z-o'zidan Xatolarimga tushadi.

### Statistikaga ta'sir
**Yo'q.** `exam_sessions` alohida jadval, ya'ni Natijalar ro'yxati, o'rtacha ball va
Statistika tabi tegilmaydi. 189 ballik natijani foizlik o'rtachaga qo'shish ikkalasini
ham ma'nosiz qiladi. Imtihon tarixi o'z ekranida yashaydi.

## 5. Endpointlar

Hammasi `/api/v1/student/exams` ostida.

| Metod | Yo'l | Nima qiladi |
|---|---|---|
| GET | `/blocks/` | Bloklar + har birining tayyorligi (`available_questions`, `ready`) |
| GET | `/active/` | Ochiq sessiya bo'lsa qaytaradi (ilova qayta ochilganda) |
| POST | `/blocks/{id}/start/` | Varaqani tanlaydi, `deadline_at` qo'yadi, 409 — ochiq sessiya bor bo'lsa |
| GET | `/{id}/` | Varaqa + berilgan javoblar + qolgan vaqt |
| PUT | `/{id}/answers/{question_id}/` | Javobni yozadi yoki tozalaydi (upsert), **natija qaytarmaydi** |
| PUT | `/{id}/flag/{question_id}/` | Belgini qo'yadi/oladi |
| POST | `/{id}/finish/` | Ballni hisoblaydi, yopadi, 409 — allaqachon yopilgan |
| GET | `/{id}/result/` | Ball, bo'limlar kesimi, xato savollar ro'yxati |
| GET | `/history/` | Urinishlar + ball dinamikasi |

Ikki qoida:
- **Javob endpointi to'g'ri/noto'g'risini qaytarmaydi.** Imtihon paytida klient kalitni
  bilmasligi kerak — aks holda javobni trafikdan ko'rish mumkin.
- **Varaqa savollarida `is_correct` bo'lmaydi.** Kalit faqat `/result/` da ochiladi.

Vaqt tugaganini kim yopadi: mavjud `finalize_expired_quiz_sessions` Celery vazifasi
har 60 soniyada ishlaydi — unga shu jadval ham qo'shiladi.

## 6. Fazalar

| Faza | Ish | Natija |
|---|---|---|
| **1** | 5 ta jadval + migratsiya + seed (2 blok) | `alembic upgrade head` o'tadi, bloklar bazada |
| **2** | Repo + servis: varaqa tanlash, ball hisoblash | Testlar servis darajasida o'tadi |
| **3** | 9 ta endpoint + Xatolarim UNION | Har biri real ma'lumotda 200 qaytaradi |
| **4** | Mobil: blok tanlash, brifing, tarix | Imtihonsiz ham ko'rish mumkin |
| **5** | Mobil: imtihon ekrani + xarita + taymer + resume | Asosiy ish shu yerda |
| **6** | Mobil: natija + Xatolarimga qo'shish | Oqim to'liq yopiladi |
| **7** | Planshet, ikki tema, 90 savolda ishlash tezligi | Yakuniy sayqal |

Har fazadan keyin: `flutter analyze` toza, `flutter test` o'tadi, endpointlar haqiqiy
ma'lumotda chaqiriladi, `PROGRESS.md` yangilanadi.

## 7. Ochiq savollar

1. **Format** — to'liq 90/189 (kontent kutiladi) yoki qisqa 60/156 (bugun ishlaydi)?
2. **Blok ro'yxati** — qaysi juftliklar kerak? Bugungi kontent faqat
   Matematika·Fizika va Biologiya·Kimyo ni ko'taradi.
3. **Imtihonni tashlab ketish** — vaqt tugashidan oldin chiqib ketsa, natija
   saqlansinmi yoki "tashlandi" deb belgilansinmi?
4. **Kuniga nechta** — cheklov bo'lsinmi? 3 soatlik imtihonni kuniga uch marta
   ishlash foydadan ko'ra charchatadi.
5. **Grant chegarasi** — dizaynda "Grant chegarasiga yaqin" deb yozilgan. Bu raqamlar
   yo'nalishga qarab har xil; qaerdan olinadi yoki olib tashlanadimi?
