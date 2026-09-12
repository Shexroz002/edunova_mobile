import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../utils/math_segments.dart';

/// Renders question text with embedded LaTeX (`$…$`, `$$…$$`, `\(…\)`, `\[…\]`).
///
/// Invalid formulas fall back to their source text; the widget never throws.
/// Terminal escape codes left by the AI generator are stripped first.
class MathText extends StatelessWidget {
  const MathText(this.text, {super.key, this.style, this.textAlign = TextAlign.start});

  final String text;
  final TextStyle? style;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
    final segments = parseMathSegments(text);

    if (segments.every((s) => !s.isMath)) {
      return Text(segments.map((s) => s.value).join(), style: effectiveStyle, textAlign: textAlign);
    }

    return Text.rich(
      TextSpan(
        style: effectiveStyle,
        children: [
          for (final segment in segments)
            if (segment.isMath)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: _Formula(segment: segment, style: effectiveStyle),
              )
            else
              TextSpan(text: segment.value),
        ],
      ),
      textAlign: textAlign,
    );
  }
}

class _Formula extends StatelessWidget {
  const _Formula({required this.segment, required this.style});

  final MathSegment segment;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final math = Math.tex(
      segment.value,
      mathStyle: segment.isDisplay ? MathStyle.display : MathStyle.text,
      textStyle: style,
      onErrorFallback: (_) => Text(segment.value, style: style),
    );

    // Long formulas scroll horizontally instead of overflowing.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(vertical: segment.isDisplay ? 6 : 2),
      child: math,
    );
  }
}
