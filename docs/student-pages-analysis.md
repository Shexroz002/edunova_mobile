# EduNova o'quvchi ilovasi: sahifalar tahlili (Flutter uchun)

**Sana:** 2026-09-11
**Manba:** jonli frontend (`127.0.0.1:5174`), jonli backend va Swagger (`127.0.0.1:8000`), `shehroz` akkaunti (rol: `student`), frontend va backend kodi.
**Qamrov:** o'quvchi qismining barcha sahifalari. Chat sahifasi kirmaydi.

Tahlil faqat o'qish orqali qilindi. Test boshlash, sessiya yaratish, qo'shilish kabi ma'lumot o'zgartiradigan amallar bajarilmadi. Shu sababli test ishlash va kutish xonasi sahifalari brauzerda ochilmay, kod orqali tahlil qilindi.

---

## 1. Qisqa xulosa

- Jami **18 ta ekran**, ularning ustiga **8 ta modal yoki bottom sheet** bor.
- Ma'lumotlarning katta qismi real API'dan keladi. Lekin **sezilarli qismi soxta (mock)**: XP, streak, daraja, yutuqlar, haftalik faollik, onlayn holat, savol bo'yicha to'g'ri javob foizi va boshqalar (4-bo'lim). Flutter'da bular uchun qaror kerak: yashirish yoki backend qo'shish.
- **Jonli backend zip'dagi koddan yangiroq.** Farqlar:
  - sessiya javoblarida `deadline_at` bor;
  - vaqtlar `+05:00` offset bilan keladi;
  - sessiya `finished` holatiga o'tadi;
  - bildirishnomalar sahifalangan va 3 xil turda keladi.

  Flutter uchun asosiy manba jonli Swagger bo'ladi.
- Web'da bir nechta xato bor, ular Flutter'ga ko'chmasligi kerak (5-bo'lim).
- Web'da planshet layouti yo'q. Flutter'da uni noldan loyihalaymiz (7-bo'lim).

---

## 2. Flutter navigatsiya xaritasi

**Pastki tablar (5 ta).** Web'da 6 ta edi, Chat olib tashlandi:

| Tab | Web route | Flutter route |
|---|---|---|
| Bosh sahifa | `/student` | `/home` |
| Guruhlar | `/student/group` | `/groups` |
| Do'stlar | `/student/friends` | `/friends` |
| Statistika | `/student/statistics` | `/statistics` |
| Profil | `/student/profile` | `/profile` |

**Ichki sahifalar** (tab ustiga ochiladi):

| Ekran | Web route | Flutter route |
|---|---|---|
| Testlar ro'yxati | `/student/tests` | `/tests` |
| Test tafsiloti | `/student/tests/:id` | `/tests/:quizId` |
| Test ishlash | `/student/test-taking/:sessionId?quiz_id=` | `/session/:sessionId/play` |
| Test natijasi | `/student/test-results/:sessionId` (router state) | `/session/:sessionId/result` |
| Xatolar tahlili | `/student/error-analysis/:sessionId` | `/session/:sessionId/review` |
| Natijalar tarixi | `/student/results?session_id=` | `/results` |
| Musobaqa yaratish | `/student/competition` | `/competition/new` |
| Kutish xonasi | `/student/waiting-room?session_id=` | `/session/:sessionId/lobby` |
| Guruh tafsiloti | `/student/group/:id` | `/groups/:groupId` |
| Guruh sessiya natijasi | `/student/session-results/:id` (state: groupId) | `/groups/:groupId/sessions/:sessionId` |
| Bildirishnomalar | `/student/notifications` | `/notifications` |
| Profilni tahrirlash | `/student/edit-profile` | `/profile/edit` |

Web'da bir nechta sahifa ma'lumotni **router state** orqali oladi (`groupId`, test natijasi). Sahifa yangilansa, bu ma'lumot yo'qoladi. Flutter'da hamma kerakli ID'lar route parametri bo'ladi.

---

## 3. Ekranlar bo'yicha tahlil

Belgilar: 🟢 real API · 🟡 hisoblangan yoki taxmin qilingan · 🔴 soxta (mock) · **S/M/L/XL** — murakkablik.

### 3.1. Login · S · *1-bosqichda tayyor*
- Username va parol. So'rov: `POST /api/v1/auth/me/`, OAuth2 form ko'rinishida.
- Google va Telegram tugmalari ishlamaydi. Flutter'da ular yo'q.
- Jonli akkauntning roli `student`, web esa ro'yxatdan o'tganda `schoolboy` yuboradi. Flutter ikkalasini ham qabul qiladi.

### 3.2. Ro'yxatdan o'tish · M · *1-bosqichda tayyor*
- Web'da 3 qadam bor: ma'lumotlar, rol, fanlar. Flutter'da 2 qadam, chunki rol doim o'quvchi.
- Qoidalar: parol kamida 8 belgi, o'quvchi kamida 2 ta fan tanlaydi.
- API: `GET /subject/list/`, `POST /auth/register/`.

### 3.3. Bosh sahifa (`/student`) · XL
**Bo'limlar (yuqoridan pastga):**
1. 🟡 Salomlashuv (vaqtga qarab: tong, kun yoki kech) va ism. Ostida "maktab • sinf" qatori.
2. 🔴 **4 ta statistika kartasi**: "40 jami test", "7 kun streak", "1560 XP", "#4 o'rin". Qiymatlar kodga qattiq yozilgan (`StudentHomePage.tsx:170-173`).
3. "Test ishlash" asosiy kartasi. `StartTestModal` ochiladi: test tanlash, vaqt tanlash, `start-single-player`, keyin test ishlash. "~15 min" yozuvi 🔴 qattiq yozilgan.
4. Tezkor amallar:
   - **Test yaratish** — `CreateQuizModal`, PDF yoki AI orqali;
   - **Testlar**;
   - **Natijalar**;
   - **Jonli sessiyaga qo'shilish** — kod kiritiladi, `POST multiplayer/join/`, keyin kutish xonasi.
5. Multiplayer kartasi Musobaqa sahifasiga olib boradi. "+12 do'st onlayn" 🔴 soxta.
6. 🟢 "Mening fanlarim" (`analytics/subjects`): har bir fan uchun foiz, to'g'ri, xato, jami javob, birinchi va so'nggi urinish sanasi.

**Realtime:** `ws/notifications/{userId}`. Test taklifi kelganda popup, bildirishnoma belgisidagi son yangilanadi.

**Flutter:**
- Soxta kartalar o'rniga `analytics/overall/cards`dan real qiymatlar: jami sessiyalar, to'g'ri javoblar, o'rtacha ball.
- Streak, XP va o'rin uchun backend'da manba yo'q, qaror kerak.
- Planshetda 2 ustun: chapda amallar, o'ngda fanlar.

### 3.4. Testlar ro'yxati (`/student/tests`) · M
- Qidiruv 300 ms kechikish (debounce) bilan ishlaydi. Yuqorida hisoblagichlar: "24 ta test", "N ta yangi", "N ta fan".
- **Test kartasida:**
  - fan belgisi, YANGI, turi (AI yoki PDF);
  - 🟡 qiyinlik — savollar sonidan taxmin qilinadi: 30 va undan ko'p bo'lsa "Qiyin", 15 dan boshlab "O'rta";
  - 🟡 davomiylik — `max(10, savollar soni)` daqiqa;
  - 🔴 ishtirokchilar soni doim "0 ta".
- **Amallar:**
  - **Testni boshlash** — vaqt tanlanadi va `start-single-player?duration_minute=` chaqiriladi;
  - **Multiplayer** — Musobaqa sahifasiga test oldindan tanlangan holda o'tadi;
  - kartani bosish tafsilotga olib boradi.
- ⚠️ Web faqat birinchi 50 ta testni yuklaydi. Flutter'da cheksiz scroll bo'ladi (`page`/`size`).

### 3.5. Test tafsiloti (`/student/tests/:id`) · XL
- **Sarlavha:**
  - 🟢 nom, tavsif, fan, tur, savollar soni;
  - 🔴 "Faol" holati, "0 urinish";
  - 🔴 yaratilgan sana har doim bugungi sana bo'lib ko'rinadi.
- 🟢 Qiyinlik bo'yicha taqsimot: nechta oson, o'rta va qiyin savol. Bu savollarning `difficulty` maydonidan olinadi.
- **Savollar ro'yxati:** raqam, matn (KaTeX formulalar bilan), mavzu, qiyinlik. 🔴 to'g'ri javob foizi soxta: oson 88%, o'rta 67%, qiyin 42%.
- **Amallar:**
  - **Testni boshlash** — ⚠️ web xatosi: quiz ID sessiya ID sifatida ishlatiladi va sessiya ochilmaydi. Flutter'da avval `start-single-player` chaqiriladi.
  - **Testni tahrirlash** — web teacher endpointini ishlatadi (`PUT /teacher/quizzes/{id}/`), chunki student endpointi 500 qaytaradi.
  - **Savolni ko'rish** — `QuestionDetailModal` (`GET question/detail/{id}`).
  - **Savolni tahrirlash** — to'liq muharrir: matn, mavzu, qiyinlik, markdown jadval quruvchi, rasm yuklash va o'chirish, to'g'ri javobni belgilash.
- **Flutter:** avval ko'rish va boshlash qismi. Muharrir keyingi bosqichda va asosan planshet uchun.

### 3.6. Test ishlash (`/student/test-taking/:sessionId`) · XL, eng muhim ekran
- **Yuklash:**
  - savollar: `GET multiplayer/{id}/questions/` (yakka o'yin uchun ham);
  - sessiya ma'lumoti: `GET multiplayer/{id}/info/`.
- **Taymer:** `deadline_at` (bo'lmasa `finished_at`) va qurilma soati asosida. 10 daqiqadan kam qolsa sariq, 5 daqiqadan kam qolsa qizil.
- **Savol ko'rinishi:**
  - fan, mavzu, qiyinlik;
  - matndagi KaTeX formulalar (`$…$`), markdown jadval, rasmlar;
  - A–D variantlari.
- **Holat saqlanadi:** javoblar va joriy savol `localStorage`da, sessiya bo'yicha. Sahifa yangilansa, tiklanadi.
- **Navigatsiya:** oldingi va keyingi savol. "Savollar xaritasi" modalida raqamlar javob berilgan yoki berilmaganiga qarab ranglanadi.
- **Multiplayer uchun qo'shimcha:**
  - har bir javobda `POST multiplayer/{id}/answer` (faqat jonli monitoring uchun);
  - har bir savol almashganda `change/question/order`.
- **Yakunlash:**
  - tasdiqlash modalida javob berilgan va berilmagan savollar soni ko'rsatiladi;
  - so'ng `POST {id}/finish-single-player/` barcha javoblar bilan yuboriladi;
  - natija sahifasiga natija obyekti bilan o'tiladi.
- **Avtomatik yakunlash:**
  - vaqt tugaganda;
  - WebSocket'dan `session_finished` kelganda (xabar ko'rsatiladi, 1.6 soniyadan keyin yuboriladi).
- **Flutter:**
  - vaqt jonli backenddagi `+05:00` offsetli `deadline_at` bo'yicha;
  - ilova qayta ochilganda (`AppLifecycle`) qolgan vaqt qayta hisoblanadi;
  - orqaga qaytishda tasdiqlash so'raladi (`PopScope`);
  - holat `shared_preferences`ga saqlanadi;
  - planshetda savollar xaritasi yon panelda doim ko'rinadi.

### 3.7. Test natijasi (`/student/test-results/:sessionId`) · M
- Ma'lumot router state'dan keladi (`FinishQuizResponse`). 🔴 **State bo'lmasa, soxta natija ko'rsatiladi** ("Fan olimpiadasi - 2026", 18/30). Bu jonli tekshiruvda tasdiqlandi.
- **Bo'limlar:**
  - ball halqasi (%) va baho so'zi;
  - to'g'ri, xato va javobsiz soni;
  - vaqt, aniqlik, umumiy ball;
  - 🟢 mavzular tahlili (`topic_statistic`), "Barchasi" va "Zaif" filtri bilan;
  - 🟡 "AI tavsiyalar" — zaif mavzular klientning o'zida hisoblanadi;
  - tugmalar: **Xatolar tahlili**, **Yangi test**.
- **Flutter:** natija route orqali uzatiladi. Keyinroq ochilsa, natijani qayta beradigan endpoint yo'q. Yechim: xatolar tahlili ma'lumotidan qayta hisoblash.

### 3.8. Xatolar tahlili (`/student/error-analysis/:sessionId`) · M
- 🟢 `GET {id}/single-player-error-analysis/`.
- Savollar birma-bir ko'rsatiladi ("1 / 5 savol"). Filtr: Barchasi, Xato, Javobsiz. Savollar xaritasi ham bor.
- Variantlarda to'g'ri javob yashil, o'quvchining xato tanlovi qizil. Ostida "Siz bu savolga to'g'ri javob bergansiz!" kabi xabar.
- ⚠️ Backend xatolari:
  - multiplayer'da qo'shilgan o'yinchiga **host'ning javoblari** ko'rsatiladi;
  - `question_id` maydonida aslida quiz ID keladi, shuning uchun savol ID sifatida `id` ishlatiladi.

### 3.9. Natijalar tarixi (`/student/results`) · L
- **Umumiy kartalar:**
  - 🟢 o'rtacha ball halqasi, sessiyalar soni, eng yuqori natija, jami savollar;
  - 🔴 "Jami vaqt: 683d" — "d" bu daqiqa, qiymat noto'g'ri: tugallanmagan sessiyalar ham qo'shilib ketadi.
- Saralash: Barchasi, Eng yaxshi, Eng yomon.
- **Natija kartasida:** nom, fan, davomiylik, sana, foiz, baho harfi (A–D), to'g'ri, xato, jami, o'rin (#1/2).
- **Amallar:**
  - **Ko'rish** — batafsil modal;
  - **Reyting** — reyting modali (`GET {id}/leaderboard/`).
- 🟢 `GET me/history/` ishlatiladi, cheksiz scroll bilan. `?session_id=` parametri bo'lsa, o'sha natija ochiladi (bildirishnomadan kelganda).
- ⚠️ Tugallanmagan sessiyalar (`correct_answers: null`) ham ro'yxatda turibdi. Jonli ma'lumotda 21 tadan 2 tasi shunday. Flutter'da ular alohida belgilanadi.

### 3.10. Musobaqa yaratish (`/student/competition`) · L (Flutter'da M)
- 3 qadamli wizard:
  1. test tanlash (qidiruvli ro'yxat);
  2. ishtirokchilar soni (`max_participants`, backend buni tekshirmaydi);
  3. davomiylik (1–180 daqiqa).
- So'ng `POST multiplayer/create/` chaqiriladi. Muvaffaqiyat modalida qo'shilish kodi ko'rsatiladi (nusxalash mumkin), keyin kutish xonasiga o'tiladi.
- **Flutter:** `Stepper` yoki 3 qadamli bottom sheet. Kod uchun `Clipboard` va `share_plus`.

### 3.11. Kutish xonasi (`/student/waiting-room?session_id=`) · L
- 🟢 Yuklash: `info/`, `participants/`, WebSocket `/ws/quiz/sessions/{id}`.
- **Bo'limlar:**
  - qo'shilish kodi (nusxalash, ulashish);
  - test ma'lumoti;
  - ishtirokchilar ro'yxati, "N/M tayyor" holati bilan.
- **Host uchun:** "Boshlash" tugmasi. U kamida 2 ishtirokchi va kamida 2 "tayyor" bo'lganda ochiladi. Host o'zi hech qachon "tayyor" bo'lmaydi, shuning uchun amalda 2 ta qo'shilgan o'yinchi kerak. Tugma `POST start/` chaqiradi.
- **Hodisalar:**
  - `participant_joined`, `participant_read` (ya'ni "ready"), `participant_reconnected`, `participant_disconnected`;
  - `session_started` kelganda test ishlashga o'tiladi;
  - `chat_message`.
- **Boshqa amallar:**
  - do'stlarni taklif qilish (`InviteFriendsModal`: kontaktlar va `invite/`);
  - chiqish (tasdiqlash, keyin `leave/`).
- 🔴 "Tayyor" tugmasi va "chiqarib yuborish" faqat ekranda ishlaydi, backendga yuborilmaydi. Avatar bo'lmasa `pravatar.cc` rasmi qo'yiladi.
- Xonaning o'z chat'i bor. Bu Chat sahifasi emas, lekin shu yerda qaror kerak (8-bo'lim).
- Sessiya allaqachon `running` bo'lsa, to'g'ridan-to'g'ri test ishlashga o'tiladi.

### 3.12. Guruhlar (`/student/group`) · S–M
- Qidiruv, saralash (nom, fan yoki faollik bo'yicha), ko'rinishni almashtirish (to'r yoki ro'yxat).
- 🟢 **Karta:** nom, fan, tavsif, o'quvchilar, testlar, o'rtacha %, so'nggi faollik (nisbiy vaqt), "Batafsil".
- ⚠️ Rang xaritasi to'liq emas: backend `VIOLET` yuboradi, web'da u yo'q. Holat qiymati `ACTIVE` yoki `ARCHIVED`.

### 3.13. Guruh tafsiloti (`/student/group/:id`) · L
- 🟢 **Sarlavha:** fan, tavsif, holat, o'quvchilar, testlar, o'rtacha ball, so'nggi faollik (`detail-card`).
- 🟢 **Leaderboard:** eng yaxshi 3 o'quvchi podiumda (`students-performance`).
- 🟢 **Testlar** (`sessions`): nom, o'rtacha, "2/6 ta", sana, **Ko'rish** (sessiya natijasiga olib boradi).
  - ⚠️ Sana "M09 11" ko'rinishida chiqadi — formatlash xatosi.
- 🟢 **O'quvchilar ko'rsatkichi:** to'g'ri, xato, o'rtacha. "Barcha N ta o'quvchini ko'rsatish" tugmasi va daraja izohi (A'lo, O'rta, Past).

### 3.14. Guruh sessiya natijasi (`/student/session-results/:id`) · M
- 🟢 **Ma'lumot:** `results/{sid}`, `question-accuracy/{sid}`, `leaderboard/{sid}`.
- **Bo'limlar:**
  - holat, test nomi, sana, ishtirokchilar, davomiylik;
  - o'rtacha, eng yuqori va eng past ball, eng qiyin savol;
  - podium;
  - savollar aniqligi (Q1…Qn, oson, o'rta yoki qiyin);
  - o'quvchilar jadvali (ball, to'g'ri, vaqt);
  - **PDF yuklab olish**.
- ⚠️ `groupId` faqat router state'dan olinadi, sahifa yangilansa buziladi. ⚠️ Podium tartibi ham noto'g'ri: 5% natija 10% dan yuqorida turibdi.
- **Flutter:** PDF uchun `pdf` va `printing` paketlari (ulashish yoki saqlash).

### 3.15. Bildirishnomalar (`/student/notifications`) · M
- 🟢 `GET notifications/?page&size` (jonli backendda sahifalangan).
- Filtrlar: Barchasi, Testlar, Do'stlar, Tizim. Kun bo'yicha guruhlanadi (BUGUN, OLDINGI). Vaqt nisbiy ko'rsatiladi ("2 daqiqa oldin").
- **Jonli bazadagi 3 tur:**

| Tur | Payload | Ko'rinishi va amallar |
|---|---|---|
| `competition_result` | `session_id, quiz_id, quiz_title, rank, participants_count, score, total_questions, score_percent, wrong_answers, spend_time_seconds` | medal, foiz, **Ko'rish** (`/results?session_id=` ga) |
| `test_invite_notification` | `session_code` | kod, **Qabul qilish** (`join/` va kutish xonasi), **Rad etish** |
| `friend_request` | `friend_id` | **Qabul qilish** (`contact/create/{id}`), **Rad etish** |

- "Rad etish" faqat ekranda ishlaydi, backend endpointi yo'q.
- Amallar: bittasini o'qilgan qilish (`PATCH {id}/read/`), hammasini o'qilgan qilish (`PATCH read-all/`).

### 3.16. Do'stlar (`/student/friends`) · S
- 🟢 Kontaktlar ro'yxati (`contact/list/`), qidiruv.
- 🔴 "Hozir onlayn — 0 do'st" va har bir do'stda "Faol emas" — onlayn holat soxta, backend bunday ma'lumot bermaydi.
- **"Qo'shish" tugmasi** `AddFriendModal`ni ochadi:
  - foydalanuvchi qidirish (`users/search`);
  - tavsiyalar (`contact/suggestions/`);
  - do'st qo'shish (`contact/create/{id}`).
- Har bir do'stda chat tugmasi bor. **Flutter'da u olib tashlanadi** yoki "Musobaqaga taklif" tugmasiga almashtiriladi.

### 3.17. Statistika (`/student/statistics`) · S–M
- **4 ta karta:**
  - 🟢 jami sessiyalar, o'rtacha % va to'g'ri javoblar (`overall/cards`);
  - 🔴 "Jami XP" — sessiyalar soni × 39.
- 🔴 **Haftalik faollik grafigi:** `[4,7,3,8,5,2,6]` kodga qattiq yozilgan.
- 🟢 Fanlar bo'yicha natija (`analytics/subjects`): to'g'ri va xato foizi.
- 🟢 AI tavsiyasi (`analytics/recommendation`, qoidalarga asoslangan matn): kuchli tomonlar, yaxshilash kerak bo'lgan joylar, keyingi maqsad. Har birida tugma bor.
- 💡 `analytics/topic?subject=` endpointi bor, lekin web uni ishlatmaydi. Flutter'da "Mavzular" bo'limi sifatida qo'shsa bo'ladi.

### 3.18. Profil (`/student/profile`) · S (asosan soxta)
- 🟢 Real qismlar: ism, sinf, rol.
- 🔴 **Qolgani soxta:**
  - "Daraja 8", "Top 10%", "1,560 XP", "40 test", "7 kun streak";
  - darajaga yetish progressi (1560/2000);
  - 6 ta yutuq ("10 test yutdim", "7 kunlik streak", "1000 XP", "90%+ ball", "5 do'st", "Barcha fanlar").
- Havolalar: Profilni tahrirlash, Sozlamalar, Chiqish.
- **Flutter:** 1-bosqichdagi profil ekrani faqat real ma'lumotni ko'rsatadi. O'yinlashtirish uchun qaror kerak.

### 3.19. Profilni tahrirlash (`/student/edit-profile`) · M
- 🟡 Profil to'ldirilganlik foizi.
- 🟢 **Avatar yuklash:** `PUT users/{id}/avatar/`, multipart maydoni `avatar`, faqat jpg, png yoki webp, 5 MB gacha.
- 🟢 **Maydonlar:** ism, familiya, email, telefon, maktab, sinf (`education_level`: "1-sinf" … "11-sinf", "Universitet"), fanlar (`subject_ids`). Saqlash: `PUT users/{id}/`.
- 🔴 Backend `null` qaytarsa, web soxta qiymat qo'yadi va shu qiymat saqlanib ketadi: `shehrozbek@example.com`, "67-Maktab Paryiq", "8-sinf". Bu boshqa foydalanuvchida email yoki telefon takrorlanishiga olib keladi (500 xatosi).
- 🔴 "Parolni o'zgartirish" uchun backend endpointi yo'q. Flutter'da bu band yashiriladi.

### Modallar va bottom sheet'lar

| Modal | Qayerda | Nima qiladi | Flutter |
|---|---|---|---|
| `StartTestModal` | Bosh sahifa | test qidirish, tanlash, vaqt chiplari | bottom sheet |
| `TestTimeModal` | Testlar | vaqt tanlash (chiplar) | bottom sheet |
| `CreateQuizModal` | Bosh sahifa | **PDF**: fayl, `pdf-jobs`. **AI**: fan, tavsif, savollar soni, `quiz/generate`. Progress `/ws/jobs/{id}/` orqali, bo'lmasa har 3 soniyada so'rov; ish ID'si saqlanib, keyin davom ettiriladi | to'liq ekranli sahifa, `file_picker` |
| `QuizCreatedSuccessModal` | Bosh sahifa | test tayyor bo'lganda xabar va testga o'tish | dialog |
| `QuestionDetailModal` | Tafsilot | savol, variantlar, to'g'ri javob | bottom sheet |
| `AddFriendModal` | Do'stlar | qidiruv, tavsiyalar, qo'shish | sahifa yoki sheet |
| `InviteFriendsModal` | Kutish xonasi | kontaktlar, taklif yuborish | bottom sheet |
| Kod kiritish | Bosh sahifa | 6 belgili sessiya kodi, `join/` | bottom sheet, katta harflar |

---

## 4. Soxta (mock) UI: qaror kerak

| # | Joy | Soxta narsa | Taklif |
|---|---|---|---|
| 1 | Bosh sahifa | 40 test, 7 kun streak, 1560 XP, #4 o'rin | real `overall/cards`; streak, XP va o'rinni yashirish yoki backend qo'shish |
| 2 | Bosh sahifa | "+12 do'st onlayn", "~15 min" | olib tashlash |
| 3 | Testlar | ishtirokchilar "0 ta"; qiyinlik va davomiylik taxminiy | ishtirokchilarni olib tashlash; qiyinlikni "N savol" bilan almashtirish |
| 4 | Test tafsiloti | "Faol", bugungi sana, "0 urinish", savol bo'yicha 88/67/42% | olib tashlash (statistika endpointi yo'q) |
| 5 | Test natijasi | state bo'lmasa soxta natija | route orqali uzatish, bo'lmasa qayta hisoblash |
| 6 | Natijalar | "Jami vaqt" noto'g'ri | faqat tugallangan sessiyalarni hisoblash |
| 7 | Kutish xonasi | "Tayyor" va "chiqarib yuborish" faqat ekranda; pravatar | yashirish yoki backend endpointi |
| 8 | Do'stlar | onlayn holat | yashirish |
| 9 | Statistika | XP = sessiyalar × 39; haftalik grafik | grafikni `me/history` asosida hisoblash yoki yashirish |
| 10 | Profil | daraja, XP, streak, top %, yutuqlar | faqat real ma'lumot; o'yinlashtirish uchun backend kerak |
| 11 | Profilni tahrirlash | soxta standart qiymatlar; parolni o'zgartirish | bo'sh maydonlarni yubormaslik; parol bandini yashirish |

---

## 5. Web xatolari (Flutter'ga ko'chmasligi kerak)

1. Test tafsilotidagi "Testni boshlash" quiz ID'ni sessiya ID sifatida ishlatadi.
2. Sessiya natijasi va test natijasi sahifalari router state'ga bog'liq, yangilanganda buziladi.
3. Guruhdagi test sanasi "M09 11" ko'rinishida chiqadi.
4. Guruh sessiyasi podiumi noto'g'ri tartiblangan.
5. Natijalardagi "Jami vaqt" noto'g'ri hisoblanadi.
6. Testlar ro'yxati faqat 50 tagacha yuklanadi.
7. Profilni tahrirlashda soxta qiymatlar saqlanib ketadi.
8. Rasm havolalari `127.0.0.1:8000` ga yo'naltirilgan, telefonda ular ochilmaydi. Flutter'da `MediaUrl` bu havolalarni to'g'rilaydi.
9. Kutish xonasida Start tugmasi amalda 2 ta qo'shilgan o'yinchini talab qiladi.

---

## 6. Jonli backend'da tasdiqlangan ma'lumot shakllari

- **Sessiya vaqtlari** (`started_at`, `deadline_at`, `finished_at`) `+05:00` offset bilan keladi, masalan `2026-09-09T09:58:27.263592+05:00`.
- `created_at` va tarixdagi `finished_at` `Z` (UTC) bilan keladi.
- Host'ning `joined_at` qiymati offsetsiz keladi (`2026-09-09T04:58:12.012307`), bu UTC vaqti.
- **Rasmlar:** `http://127.0.0.1:8000/media/avatars/…jpg`. Mobil qurilmada qayta yozish kerak.
- **Satr ko'rinishidagi sonlar:** `average: "30.77"`, `spend_time_seconds: "31.294116"`.
- **Qiyinlik qiymatlari:** `"oson"`, `"o‘rta"` (ichida ‘ belgisi bor), `"qiyin"`. Solishtirishdan oldin normallashtirish kerak.
- **Fan belgisi** (`icon`): `""` yoki `null`. Flutter o'z ikonkasini fan nomi yoki `type` bo'yicha tanlaydi.
- **Test turlari:** `AI_GENERATE`, `PDF`. Jonli bazada qo'lda yaratilgan test yo'q.
- `table_markdown` hozirgi testlarda bo'sh, lekin qo'llab-quvvatlash kerak.

---

## 7. Bir marta yoziladigan umumiy widgetlar

| Widget | Qayerda ishlatiladi |
|---|---|
| `MathText` (`$…$`, `$$…$$`, `\(…\)`) | test ishlash, tafsilot, xatolar tahlili, savol modallari |
| `MarkdownTable` | savol matni |
| `QuestionView` + `OptionTile` (oddiy, tanlangan, to'g'ri, xato) | test ishlash, xatolar tahlili |
| `QuestionMapSheet` | test ishlash, xatolar tahlili |
| `CountdownTimer` | test ishlash |
| `QuizCard`, `DifficultyChip`, `SubjectBadge` | testlar, bosh sahifa, musobaqa |
| `ScoreRing`, `GradeBadge`, `StatCard` | natija, natijalar, statistika, guruh |
| `ResultCard`, `LeaderboardRow`, `Podium` | natijalar, guruh, sessiya natijasi |
| `NotificationTile` (3 tur) | bildirishnomalar |
| `CodeInputSheet`, `CopyCodeTile` | bosh sahifa, musobaqa, kutish xonasi |
| `UserAvatar`, `EmptyView`, `ErrorView`, `SearchField`, `FilterChips` | hamma joyda (bir qismi 1-bosqichda tayyor) |
| `SocketService` (qayta ulanish, heartbeat) | kutish xonasi, test ishlash, bildirishnomalar, test yaratish |

**Planshet (600 dp va undan keng):**
- ro'yxat va tafsilot yonma-yon: natijalar, guruhlar, bildirishnomalar;
- test ishlashda savollar xaritasi yon panelda;
- statistika va bosh sahifada 2 ustun.

---

## 8. Qaror kerak bo'lgan savollar

1. **O'yinlashtirish** (XP, streak, daraja, yutuqlar, o'rin): yashiramizmi yoki backend qo'shiladimi?
2. **Kutish xonasidagi chat** (`chat_message`): bu Chat sahifasi emas. Qoldiramizmi?
3. **"Tayyor" va "chiqarib yuborish"**: hozir faqat ekranda ishlaydi. Yashiramizmi yoki backend endpointi qo'shiladimi?
4. **Savol muharriri** o'quvchi uchun mobil ilovada kerakmi? Faqat planshetdami yoki keyingi bosqichdami?
5. **Haftalik faollik grafigi**: tarixdan hisoblaymizmi yoki backend endpointi qilinadimi?
6. **Push-bildirishnomalar** (ilova yopiq bo'lganda): hozircha faqat WebSocket orqali, keyin FCM bilan.

---

## 9. Yangilangan bosqichlar

| Bosqich | Ekranlar | Holat |
|---|---|---|
| 1 | Skelet, login, ro'yxatdan o'tish, shell (5 tab), oddiy profil | kod yozilgan, tekshirilmagan |
| 2 | Testlar ro'yxati, test tafsiloti (ko'rish), test boshlash modali, **test ishlash**, test natijasi, xatolar tahlili, natijalar tarixi va reyting | — |
| 3 | Kod bilan qo'shilish, musobaqa yaratish, **kutish xonasi** (WebSocket), do'stlarni taklif qilish, bildirishnomalar va ularning WebSocket'i | — |
| 4 | Guruhlar, guruh tafsiloti, guruh sessiya natijasi va PDF | — |
| 5 | To'liq bosh sahifa, statistika (`fl_chart`), do'stlar va do'st qo'shish, profilni tahrirlash va avatar | — |
| 6 | Test yaratish (PDF yoki AI, job progress), savol muharriri (planshet uchun) | — |
