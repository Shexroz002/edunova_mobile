import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/quiz/math_text.dart';
import 'tex_prose.dart';

final _mark = RegExp(r'\\hl([abc])\{');
const _index = {'a': 1, 'b': 2, 'c': 3};

String _hex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// Replaces the solution's colour marks with this theme's colours.
///
/// The server never stores a colour, only which value a number is:
/// `\hla{2}` is value 1. The hex comes from the theme here, so the same
/// solution reads correctly in dark and light.
String paintTex(BuildContext context, String tex) => tex.replaceAllMapped(
      _mark,
      (m) => '\\textcolor{${_hex(context.mathValue(_index[m[1]]!))}}{',
    );

final _decimalComma = RegExp(r'(\d),(\d)');

/// A plain number such as "1,5" made safe for LaTeX, where a bare comma is
/// followed by a space and would read "1, 5".
String texNumber(String value) => value.replaceAllMapped(_decimalComma, (m) => '${m[1]}{,}${m[2]}');

/// One line written on the board, drawn as display maths.
///
/// Long lines scroll sideways instead of overflowing a phone screen; a line
/// that fails to parse falls back to its source rather than to nothing.
class BoardFormula extends StatelessWidget {
  const BoardFormula(this.tex, {super.key, this.size = 19, this.muted = false, this.bold = false});

  final String tex;
  final double size;

  /// A formula before substitution is written quieter than the working.
  final bool muted;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = TextStyle(
      fontSize: size,
      color: muted ? c.textMuted : c.textPrimary,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // Room between board lines: a weak reader loses the line in a tight stack.
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Math.tex(
        paintTex(context, tex),
        mathStyle: MathStyle.display,
        textStyle: style,
        onErrorFallback: (_) => Text(tex, style: style.copyWith(fontSize: size - 4)),
      ),
    );
  }
}

/// Plain sentences with `$…$` maths inside, colour marks included.
///
/// A formula the model wrote without its dollars is wrapped first, so it is
/// drawn as maths and never shown as "\angle ACB = 68^\circ".
class ProseMath extends StatelessWidget {
  const ProseMath(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MathText(
      paintTex(context, wrapBareTex(text)),
      style: TextStyle(fontSize: 15, height: 1.55, color: c.textPrimary).merge(style),
    );
  }
}
