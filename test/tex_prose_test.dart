import 'package:edunova_mobile/features/solution/presentation/widgets/tex_prose.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('wrapBareTex', () {
    test('wraps a formula that came without dollars', () {
      // Seen on the device: two collapsed steps read as raw LaTeX.
      expect(wrapBareTex(r'\angle ABC = 90^\circ'), r'$\angle ABC = 90^\circ$');
      expect(wrapBareTex(r'\angle ACB = 68^\circ'), r'$\angle ACB = 68^\circ$');
    });

    test('keeps the words outside the formula', () {
      expect(wrapBareTex(r'Burchak \angle B = 90^\circ ga teng.'), r'Burchak $\angle B = 90^\circ$ ga teng.');
      expect(wrapBareTex('x^2 ni topamiz'), r'$x^2$ ni topamiz');
    });

    test('keeps a group split by spaces whole', () {
      expect(
        wrapBareTex(r"Agar \int \frac{x \cdot f(x)}{x^2+1} dx = x^3 + C bo'lsa"),
        r"Agar $\int \frac{x \cdot f(x)}{x^2+1} dx = x^3 + C$ bo'lsa",
      );
    });

    test('wraps each formula of a sentence separately', () {
      expect(
        wrapBareTex(r"15. Agar a = 6^{3x-2y} va b = 6^{3x+2y} bo'lsa"),
        r"15. Agar $a = 6^{3x-2y}$ va $b = 6^{3x+2y}$ bo'lsa",
      );
    });

    test('leaves alone what needs no help', () {
      expect(wrapBareTex('AD = DC = BD'), 'AD = DC = BD');
      expect(wrapBareTex(r'Ayirma $d = 3$.'), r'Ayirma $d = 3$.');
      expect(wrapBareTex('Kuch, N (Nyuton)'), 'Kuch, N (Nyuton)');
      expect(wrapBareTex(r'\(x^2\) ni toping'), r'\(x^2\) ni toping');
    });

    test('does not wrap a formula whose braces never close', () {
      expect(wrapBareTex(r'\frac{1}{2'), r'\frac{1}{2');
    });
  });

  group('texPreview', () {
    test('turns the history rows on the device into readable text', () {
      expect(
        texPreview(r"Agar $\int \frac{x \cdot f(x)}{x^2+1} dx = x^3 + C$ bo'lsa"),
        "Agar ∫ (x · f(x))/(x²+1) dx = x³ + C bo'lsa",
      );
      expect(
        texPreview(r"15. Agar $a = 6^{3x-2y}$ va $b = 6^{3x+2y}$ bo'lsa"),
        "15. Agar a = 6³ˣ⁻²ʸ va b = 6³ˣ⁺²ʸ bo'lsa",
      );
    });

    test('knows the common school symbols', () {
      expect(texPreview(r'\angle ACB = 68^\circ'), '∠ ACB = 68°');
      expect(texPreview(r'$\sqrt{2} \cdot \pi \le x_1$'), '√2 · π ≤ x₁');
      expect(texPreview(r'$\sqrt[4]{ab}$'), '⁴√ab');
      expect(texPreview(r'$m = 2\ \text{kg}$'), 'm = 2 kg');
    });

    test('falls back to a caret when a power has no superscript form', () {
      expect(texPreview(r'$e^{ab}$'), 'e^(ab)');
    });

    test('leaves plain text untouched', () {
      expect(texPreview("To‘g‘ri to‘rtburchak 4 va 5"), "To‘g‘ri to‘rtburchak 4 va 5");
    });
  });
}
