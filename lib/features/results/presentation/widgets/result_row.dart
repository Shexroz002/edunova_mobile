import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/subject_style.dart';
import '../../../session/domain/session_models.dart';

/// One finished — or abandoned — test in the history list.
///
/// The card this replaces was 248 dp and said the same score four ways: a
/// percent pill, a grade letter, a progress bar and `✓0 ✗5 ?30` chips. At 64 dp
/// the score is stated once, and its colour carries the band. Forty-two results
/// went from about eighteen screens to five and a half.
class ResultRow extends StatelessWidget {
  const ResultRow({
    super.key,
    required this.item,
    required this.onOpen,
    required this.onLeaderboard,
  });

  final HistoryItem item;

  /// Opens the result sheet.
  final VoidCallback onOpen;

  /// Opens the leaderboard. Reached from the rank chip, so only a competition
  /// ever calls it.
  final VoidCallback onLeaderboard;

  /// Score bands. A weak result is amber rather than red: the list is a record,
  /// not a verdict, and half of these rows are practice.
  static Color scoreColor(BuildContext context, double percent) {
    if (percent >= 80) return context.readable(AppColors.success);
    if (percent >= 50) return context.readable(AppColors.brand);
    return context.readable(AppColors.warning);
  }

  /// Subject, then either what the test cost or how far it got.
  String get _meta {
    final subject = SubjectStyle.displayName(item.subject);
    final parts = [if (subject.isNotEmpty) subject];

    // Davom ettiriladigan satrda o'ng tomonda tugma turadi va nima qilish
    // mumkinligini o'zi aytadi; meta qatoriga faqat fan qoladi, aks holda
    // tugma bilan ikkisi bir-birini siqib qo'yadi.
    if (item.canResume) return parts.join(' · ');

    // Yakunlangan test - natija, nechta savol javobsiz qolganidan qat'i
    // nazar. Javobsizlari foizga allaqachon kirgan, shuning uchun bu yerda
    // qancha javob berilgani va qancha vaqt ketgani aytiladi.
    final total = item.totalQuestions ?? 0;
    parts.add(switch (total) {
      // Savollar soni yo'q - aytadigan nisbat ham yo'q. "0/0" hech narsani
      // bildirmaydi.
      0 => 'javob berilmagan',
      _ when item.answered >= total => '$total ta savol',
      _ => '${item.answered}/$total javob berilgan',
    });
    final spent = item.spentLabel;
    if (spent != null) parts.add(spent);
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = SubjectStyle.of(item.subject);

    return Material(
      color: c.bgCard,
      borderRadius: BorderRadius.circular(15),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: c.border),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.tint(style.color, 0x2B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(style.icon, size: 19, color: context.readable(style.color)),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.title ?? 'Test',
                          // Real titles run to "Fizika: mustahkamlash uchun test";
                          // one line clipped most of them even after the row was
                          // cleared of buttons.
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.1,
                            color: c.textPrimary,
                          ),
                        ),
                        SizedBox(height: item.isMultiplayer ? 0 : 4),
                        Row(
                          children: [
                            // The rank sits on the meta line rather than beside the
                            // score: in the trailing group it, the percentage and
                            // the chevron together left the title 119 dp, and
                            // "Fizika: mustahkamlash uchun test" clipped even
                            // across two lines. Here the title gets 176 dp.
                            if (item.isMultiplayer) ...[
                              _RankChip(item: item, onTap: onLeaderboard),
                              const SizedBox(width: 7),
                            ],
                            Flexible(
                              child: Text(
                                _meta,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11.5, color: c.textMuted),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Davom ettiriladigan satrda o'ng tomon bo'sh qoladi: pastdagi
                  // tugma ham testning tugallanmaganini aytadi, ham qayerga olib
                  // borishini. Yoniga yana "tugallanmagan" belgisi va strelka
                  // qo'yish o'sha gapni uch marta takrorlash bo'lardi.
                  if (!item.canResume) ...[
                    const SizedBox(width: 9),
                    // Yakunlangan test har doim o'z foizini oladi - javobsiz
                    // qolgan savollari bo'lsa ham; ular ballga kirgan.
                    // Baholanmagani (masalan, ilova majburan yopilgan vaqtli
                    // sessiya) esa hech qanday raqam ko'rsatmaydi: u hali
                    // natija emas, va supurgi uni deadline'da yopadi.
                    if (item.isFinished)
                      Text(
                        formatPercent(item.percent),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: scoreColor(context, item.percent),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right_rounded, size: 20, color: c.textMuted),
                  ],
                ],
              ),
              // Sarlavha yonida "Davom ettirish" uchun joy yo'q - u yerda
              // tugma sarlavhani 90 dp gacha siqib qo'yadi. O'z qatorida esa
              // hech narsani kesmaydi va tugallanmagan testni ro'yxatda
              // darhol ajratib turadi.
              if (item.canResume) ...[
                const SizedBox(height: 10),
                _ResumeButton(onPressed: onOpen),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Takes the student back into a test they have not finished.
class _ResumeButton extends StatelessWidget {
  const _ResumeButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final brand = context.readable(AppColors.brand);

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.play_arrow_rounded, size: 18),
        label: const Text('Davom ettirish'),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.tint(brand, 0x29),
          foregroundColor: brand,
          elevation: 0,
          minimumSize: const Size(0, 38),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        ),
      ),
    );
  }
}

/// Rank in a competition, and the way into its leaderboard.
///
/// "Reyting" used to be a button on every row, solo tests included, where the
/// leaderboard holds one person: you. The chip replaces it where it means
/// something, and says the placing while it is at it.
///
/// The visible pill is 22 dp so it sits on the meta line without pushing the
/// title around, but a control has to be reachable: the tap area around it is
/// padded to the 44 dp floor, which is what makes a competition row taller than
/// a solo one.
class _RankChip extends StatelessWidget {
  const _RankChip({required this.item, required this.onTap});

  final HistoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final warning = context.readable(AppColors.warning);

    return SizedBox(
      height: 44,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          // Without a width factor the Center stretches across the meta row and
          // pushes the text out of it.
          child: Center(
            widthFactor: 1,
            child: Container(
              height: 22,
              padding: const EdgeInsets.symmetric(horizontal: 7),
              decoration: BoxDecoration(
                color: AppColors.tint(warning, 0x24),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.tint(warning, 0x57)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.emoji_events_rounded, size: 11, color: warning),
                  const SizedBox(width: 3),
                  Text(
                    '${item.rank}/${item.participantCount}',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: warning),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
