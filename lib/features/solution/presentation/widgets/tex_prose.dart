/// Text helpers for solution prose that may carry LaTeX.
///
/// The model is asked to put every formula in prose between `$…$`, and mostly
/// does; a collapsed step once read "\angle ACB = 68^\circ" because it did not.
/// These keep such slips — and replies stored before the rule — readable.
library;

final _trigger = RegExp(r'\\[a-zA-Z]+|[\^_]');
final _dollarSpan = RegExp(r'\$[^$]*\$');

/// Wraps formulas written without `$…$` so they render as maths.
///
/// Only text with a backslash command, `^` or `_` is touched; Uzbek prose has
/// none of them. A formula is grown from such a token over its neighbours that
/// read as maths — variables, numbers, operators — and stops at a word.
String wrapBareTex(String text) {
  if (!_trigger.hasMatch(text)) return text;
  // \( … \) and \[ … \] are delimiters MathText already understands.
  if (text.contains(r'\(') || text.contains(r'\[')) return text;
  final out = StringBuffer();
  var from = 0;
  for (final match in _dollarSpan.allMatches(text)) {
    out
      ..write(_wrapSegment(text.substring(from, match.start)))
      ..write(match[0]);
    from = match.end;
  }
  out.write(_wrapSegment(text.substring(from)));
  return out.toString();
}

final _operator = RegExp(r'^[=+\-−·×÷/<>≤≥≠±:,.;()\[\]|]+$');
final _variable = RegExp(r'^[A-Za-z]\d*[,.]?$');
final _points = RegExp(r'^[A-Z]{2,4}[,.]?$');
final _number = RegExp(r'^-?\d+([.,]\d+)?[°%]?[,.]?$');
final _call = RegExp(r'^[A-Za-z]\([^)]*\)[,.]?$');
const _differentials = {'dx', 'dy', 'dt', 'dz'};

bool _isTex(String token) => _trigger.hasMatch(token);

bool _isGlue(String token) =>
    _operator.hasMatch(token) ||
    _variable.hasMatch(token) ||
    _points.hasMatch(token) ||
    _number.hasMatch(token) ||
    _call.hasMatch(token) ||
    _differentials.contains(token);

int _braceBalance(String text) => '{'.allMatches(text).length - '}'.allMatches(text).length;

String _wrapSegment(String segment) {
  if (!_trigger.hasMatch(segment)) return segment;
  // Tokens and the whitespace after each, so the text is rebuilt exactly.
  final parts = RegExp(r'(\S+)(\s*)').allMatches(segment).toList();
  final lead = parts.isEmpty ? segment : segment.substring(0, parts.first.start);
  final tokens = [for (final p in parts) p[1]!];
  final gaps = [for (final p in parts) p[2]!];

  final inMath = List<bool>.filled(tokens.length, false);
  var i = 0;
  while (i < tokens.length) {
    if (!_isTex(tokens[i])) {
      i++;
      continue;
    }
    var start = i;
    while (start > 0 && !inMath[start - 1] && _isGlue(tokens[start - 1])) {
      start--;
    }
    var end = i;
    while (end + 1 < tokens.length && (_isTex(tokens[end + 1]) || _isGlue(tokens[end + 1]))) {
      end++;
    }
    // A group split by spaces, such as "\frac{x \cdot f(x)}{…}", must close.
    var span = [for (var k = start; k <= end; k++) tokens[k]].join(' ');
    while (_braceBalance(span) > 0 && end + 1 < tokens.length) {
      end++;
      span = [for (var k = start; k <= end; k++) tokens[k]].join(' ');
    }
    if (_braceBalance(span) == 0) {
      for (var k = start; k <= end; k++) {
        inMath[k] = true;
      }
    }
    i = end + 1;
  }

  final out = StringBuffer(lead);
  var k = 0;
  while (k < tokens.length) {
    if (!inMath[k]) {
      out
        ..write(tokens[k])
        ..write(gaps[k]);
      k++;
      continue;
    }
    final run = StringBuffer();
    while (k < tokens.length && inMath[k]) {
      run.write(tokens[k]);
      if (k + 1 < tokens.length && inMath[k + 1]) run.write(gaps[k]);
      k++;
    }
    // Sentence punctuation stays outside the formula.
    final body = run.toString();
    final tail = RegExp(r'[,.;:]$').firstMatch(body)?[0] ?? '';
    out
      ..write('\$${body.substring(0, body.length - tail.length)}\$$tail')
      ..write(gaps[k - 1]);
  }
  return out.toString();
}

const _symbols = {
  'cdot': '·', 'times': '×', 'div': '÷', 'int': '∫', 'sum': '∑', 'angle': '∠',
  'circ': '°', 'pi': 'π', 'alpha': 'α', 'beta': 'β', 'gamma': 'γ', 'delta': 'δ',
  'Delta': 'Δ', 'theta': 'θ', 'lambda': 'λ', 'mu': 'μ', 'omega': 'ω', 'phi': 'φ',
  'varphi': 'φ', 'le': '≤', 'leq': '≤', 'ge': '≥', 'geq': '≥', 'neq': '≠', 'ne': '≠',
  'pm': '±', 'infty': '∞', 'to': '→', 'Rightarrow': '⇒', 'approx': '≈', 'in': '∈',
  'cup': '∪', 'cap': '∩', 'perp': '⊥', 'parallel': '∥', 'triangle': '△', 'degree': '°',
};
const _dropped = {'left', 'right', 'displaystyle', 'quad', 'qquad', 'limits'};
const _superscript = {
  '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴', '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹',
  '+': '⁺', '-': '⁻', '=': '⁼', '(': '⁽', ')': '⁾', 'n': 'ⁿ', 'i': 'ⁱ', 'x': 'ˣ', 'y': 'ʸ',
};
const _subscript = {
  '0': '₀', '1': '₁', '2': '₂', '3': '₃', '4': '₄', '5': '₅', '6': '₆', '7': '₇', '8': '₈', '9': '₉',
  '+': '₊', '-': '₋', '=': '₌', '(': '₍', ')': '₎', 'n': 'ₙ', 'i': 'ᵢ', 'x': 'ₓ',
};

String _script(String body, Map<String, String> table, String marker) {
  final chars = body.split('');
  if (chars.every(table.containsKey)) return chars.map((c) => table[c]).join();
  return body.length == 1 ? '$marker$body' : '$marker($body)';
}

String _group(String body) => RegExp(r'^[\w.,]+$').hasMatch(body.trim()) ? body.trim() : '(${body.trim()})';

/// One line of plain text for a list row or a header, LaTeX turned into
/// symbols: "∫ (x · f(x))/(x²+1) dx", never "\int \frac{…}".
///
/// A preview only — the full solution draws the real maths.
String texPreview(String text) {
  var s = text.replaceAll(RegExp(r'\s+'), ' ');
  for (var pass = 0; pass < 3; pass++) {
    s = s.replaceAllMapped(
      RegExp(r'\\[dt]?frac\{([^{}]*)\}\{([^{}]*)\}'),
      (m) => '${_group(m[1]!)}/${_group(m[2]!)}',
    );
  }
  s = s
      .replaceAllMapped(RegExp(r'\\sqrt\[([^\]]*)\]\{([^{}]*)\}'),
          (m) => '${_script(m[1]!, _superscript, '^')}√${_group(m[2]!)}')
      .replaceAllMapped(RegExp(r'\\sqrt\{([^{}]*)\}'), (m) => '√${_group(m[1]!)}')
      .replaceAllMapped(RegExp(r'\\(?:text|mathrm|mathbf|operatorname)\{([^{}]*)\}'), (m) => m[1]!)
      .replaceAll(RegExp(r'\^\{?\\circ\}?'), '°')
      .replaceAllMapped(RegExp(r'\^\{([^{}]*)\}'), (m) => _script(m[1]!, _superscript, '^'))
      .replaceAllMapped(RegExp(r'\^(\w)'), (m) => _script(m[1]!, _superscript, '^'))
      .replaceAllMapped(RegExp(r'_\{([^{}]*)\}'), (m) => _script(m[1]!, _subscript, '_'))
      .replaceAllMapped(RegExp(r'_(\w)'), (m) => _script(m[1]!, _subscript, '_'))
      .replaceAll(RegExp(r'\\[,;:! ]'), ' ')
      .replaceAllMapped(RegExp(r'\\([a-zA-Z]+)'), (m) {
        final name = m[1]!;
        if (_dropped.contains(name)) return '';
        return _symbols[name] ?? name;
      })
      .replaceAll(RegExp(r'[{}$]'), '')
      .replaceAll(RegExp(r' {2,}'), ' ');
  return s.trim();
}
