import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'solution_tex.dart';

// Written and checked by hand, never generated: whatever the student reads
// while waiting must be right. Maths goes between $…$ like any solution prose.

const _mathTips = [
  r'Kvadrat tenglamada $D > 0$ bo‘lsa — ikkita ildiz, $D = 0$ — bitta, $D < 0$ — haqiqiy ildiz yo‘q.',
  r'Manfiy sonni manfiy songa ko‘paytirsangiz, musbat son chiqadi: $(-3) \cdot (-4) = 12$.',
  r'Nolga bo‘lib bo‘lmaydi. Lekin nolni istalgan songa bo‘lsangiz, nol chiqadi.',
  r'Uchburchakning ichki burchaklari yig‘indisi doim $180^\circ$.',
  r'Pifagor teoremasi faqat to‘g‘ri burchakli uchburchakda: $a^2 + b^2 = c^2$.',
  r'Kasrlarni qo‘shishdan oldin maxrajlarini bir xil qiling: $\frac{1}{2} + \frac{1}{3} = \frac{5}{6}$.',
  r'Noldan farqli har qanday sonning nolinchi darajasi birga teng: $a^0 = 1$.',
  r'Arifmetik progressiyada har qadamda bir xil son qo‘shiladi: $a_n = a_1 + (n-1)d$.',
  r'Foiz — yuzdan bir ulush: $20\%$ bu $\frac{20}{100} = 0{,}2$.',
  r'Javobni topgach, uni shartga qo‘yib tekshiring — xato shu yerda ko‘rinadi.',
];

const _physicsTips = [
  r'Kuch birligi — nyuton: $1\ \text{N} = 1\ \text{kg} \cdot \text{m/s}^2$.',
  r'Erkin tushish tezlanishi taxminan $9{,}8\ \text{m/s}^2$. Masalalarda ko‘pincha $10$ deb olinadi — shartni o‘qing.',
  r'Tezlik — yo‘lning vaqtga nisbati: $v = \frac{s}{t}$.',
  r'Avval birliklarni bir xil qiling: $72\ \text{km/soat} = 20\ \text{m/s}$.',
  r'Nyutonning ikkinchi qonuni: $F = m \cdot a$.',
  r'Yechishdan oldin «Berilgan» va «Topish kerak»ni yozib oling.',
  r'Potensial energiya $E_p = mgh$: balandlik ortsa, energiya ham ortadi.',
  r'Zichlik — massaning hajmga nisbati: $\rho = \frac{m}{V}$. Suvniki taxminan $1000\ \text{kg/m}^3$.',
  r'Kinetik energiya $E_k = \frac{mv^2}{2}$: tezlik ikki marta ortsa, energiya to‘rt marta ortadi.',
  r'Ish — kuch va yo‘l ko‘paytmasi: $A = F \cdot s$, kuch yo‘l bo‘ylab yo‘nalgan bo‘lsa.',
];

const _generalTips = [
  r'Shartni ikki marta o‘qing: birinchisida — nima berilgan, ikkinchisida — nima so‘ralgan.',
  r'Javobni topgach, uni shartga qo‘yib tekshiring.',
  r'Qiyin masalada avval soddaroq holatni yechib ko‘ring.',
  r'Birliklarni yozib boring — ular xatoni ko‘rsatib qo‘yadi.',
  r'Xatoni topish yechimning o‘zidan ham muhimroq: u keyingi safar yordam beradi.',
];

/// The tips for a subject; general study habits when the subject is unknown.
List<String> tipsFor(String? subject) {
  final s = (subject ?? '').toLowerCase();
  if (s.contains('fiz')) return _physicsTips;
  if (s.contains('mat') || s.contains('alg') || s.contains('geom')) return _mathTips;
  return _generalTips;
}

/// "💡 Bilasizmi?" — one short rule, so the wait teaches something.
class TipCard extends StatelessWidget {
  const TipCard({super.key, required this.tips, required this.index});

  final List<String> tips;

  /// Which tip is showing; it wraps around.
  final int index;

  @override
  Widget build(BuildContext context) {
    final amber = context.readable(AppColors.warning);
    final shown = index % tips.length;
    const dots = 4;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.tint(AppColors.warning, 0x21), AppColors.tint(AppColors.warning, 0x0A)],
        ),
        border: Border.all(color: AppColors.tint(AppColors.warning, 0x61)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('💡 BILASIZMI?',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.3, color: amber)),
              const Spacer(),
              for (var i = 0; i < dots; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: i == shown % dots ? 14 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    color: i == shown % dots ? amber : AppColors.tint(amber, 0x4D),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 7),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: Align(
              key: ValueKey(shown),
              alignment: Alignment.centerLeft,
              child: ProseMath(tips[shown], style: const TextStyle(fontSize: 14, height: 1.5)),
            ),
          ),
        ],
      ),
    );
  }
}
