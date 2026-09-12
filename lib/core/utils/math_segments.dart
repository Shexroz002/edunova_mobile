/// Parsing helpers for question text that mixes plain text and LaTeX.
library;

/// A piece of question text: plain text or a LaTeX formula.
class MathSegment {
  const MathSegment.text(this.value)
      : isMath = false,
        isDisplay = false;
  const MathSegment.math(this.value, {this.isDisplay = false}) : isMath = true;

  final String value;
  final bool isMath;

  /// `$$...$$` or `\[...\]` (block style) instead of inline.
  final bool isDisplay;

  @override
  String toString() => isMath ? (isDisplay ? '[[$value]]' : '[$value]') : value;
}

final _ansiEscape = RegExp(r'\x1B\[[0-9;]*m');
final _ansiLiteral = RegExp(r'\\u001b\[[0-9;]*m', caseSensitive: false);
final _mathPattern = RegExp(
  r'\$\$([\s\S]+?)\$\$|\\\[([\s\S]+?)\\\]|\\\(([\s\S]+?)\\\)|\$([^\$]+?)\$',
);

/// Removes terminal color codes that the AI generator sometimes leaves in
/// question text (both real ESC bytes and the literal text `\u001b[23m`).
String cleanQuestionText(String input) =>
    input.replaceAll(_ansiEscape, '').replaceAll(_ansiLiteral, '');

/// Splits [input] into text and math segments.
///
/// Supported delimiters: `$$…$$`, `\[…\]` (display) and `$…$`, `\(…\)` (inline).
List<MathSegment> parseMathSegments(String input) {
  final text = cleanQuestionText(input);
  final segments = <MathSegment>[];
  var cursor = 0;

  for (final match in _mathPattern.allMatches(text)) {
    if (match.start > cursor) segments.add(MathSegment.text(text.substring(cursor, match.start)));
    final display = match.group(1) ?? match.group(2);
    final inline = match.group(3) ?? match.group(4);
    final formula = (display ?? inline ?? '').trim();
    if (formula.isNotEmpty) {
      segments.add(MathSegment.math(formula, isDisplay: display != null));
    }
    cursor = match.end;
  }
  if (cursor < text.length) segments.add(MathSegment.text(text.substring(cursor)));
  return segments;
}

/// Plain-text preview: formulas keep their LaTeX source without delimiters.
String plainPreview(String input) =>
    parseMathSegments(input).map((s) => s.value).join().replaceAll(RegExp(r'\s+'), ' ').trim();
