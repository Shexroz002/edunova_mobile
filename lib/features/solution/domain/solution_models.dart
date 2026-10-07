import '../../../core/utils/json_utils.dart';

final _break = RegExp(r'\s*\n\s*');

/// A solution sentence on one line; a break inside one is a model artefact.
String _prose(dynamic value) => (asString(value) ?? '').replaceAll(_break, ' ').trim();

List<String> _strings(dynamic value) => [
      for (final item in (value is List ? value : const []))
        if (_prose(item).isNotEmpty) _prose(item),
    ];

/// What a student is shown when a solution names a key number of the problem.
class MathValue {
  const MathValue({required this.name, required this.label, required this.value, required this.color});

  final String name;
  final String label;
  final String value;

  /// 1, 2 or 3; the board marks the same number with `\hla`, `\hlb`, `\hlc`.
  final int color;

  factory MathValue.fromJson(Json json) => MathValue(
        name: asString(json['name']) ?? '',
        label: asString(json['label']) ?? '',
        value: asString(json['value']) ?? '',
        color: asInt(json['color']) ?? 1,
      );
}

/// A physics "Berilgan" row: a value with its unit.
class GivenValue {
  const GivenValue({
    required this.symbol,
    required this.value,
    required this.unit,
    required this.label,
    required this.color,
  });

  final String symbol;
  final String value;
  final String unit;
  final String label;
  final int color;

  factory GivenValue.fromJson(Json json) => GivenValue(
        symbol: asString(json['symbol']) ?? '',
        value: asString(json['value']) ?? '',
        unit: asString(json['unit']) ?? '',
        label: asString(json['label']) ?? '',
        color: asInt(json['color']) ?? 1,
      );
}

/// A physics "Topish kerak" row.
class FindItem {
  const FindItem({required this.symbol, required this.label, required this.unit});

  final String symbol;
  final String label;
  final String unit;

  factory FindItem.fromJson(Json json) => FindItem(
        symbol: asString(json['symbol']) ?? '',
        label: asString(json['label']) ?? '',
        unit: asString(json['unit']) ?? '',
      );
}

/// One letter under a formula: what it means and its unit.
class LegendLine {
  const LegendLine({required this.symbol, required this.meaning, required this.unit});

  final String symbol;
  final String meaning;
  final String unit;

  factory LegendLine.fromJson(Json json) => LegendLine(
        symbol: asString(json['symbol']) ?? '',
        meaning: asString(json['meaning']) ?? '',
        unit: asString(json['unit']) ?? '',
      );
}

/// The physics formula card: the formula and every letter explained.
class FormulaCard {
  const FormulaCard({required this.name, required this.tex, required this.legend});

  final String name;
  final String tex;
  final List<LegendLine> legend;

  static FormulaCard? fromJson(dynamic json) {
    if (json is! Json) return null;
    final tex = asString(json['tex'])?.trim() ?? '';
    if (tex.isEmpty) return null;
    return FormulaCard(
      name: asString(json['name']) ?? '',
      tex: tex,
      legend: asJsonList(json['legend']).map(LegendLine.fromJson).toList(),
    );
  }
}

/// One part of a word problem's bar: a label, an expression and its share.
class TapePart {
  const TapePart({required this.label, required this.expr, required this.weight});

  final String label;
  final String expr;
  final double weight;

  factory TapePart.fromJson(Json json) => TapePart(
        label: asString(json['label']) ?? '',
        expr: asString(json['expr']) ?? '',
        weight: (asDouble(json['weight']) ?? 1).clamp(0.1, 100).toDouble(),
      );
}

/// A word problem drawn as one bar split into parts, with the total above it.
class TapeSpec {
  const TapeSpec({required this.total, required this.parts});

  final String total;
  final List<TapePart> parts;

  static TapeSpec? fromJson(dynamic json) {
    if (json is! Json) return null;
    final parts = asJsonList(json['parts']).map(TapePart.fromJson).toList();
    if (parts.length < 2) return null;
    return TapeSpec(total: asString(json['total']) ?? '', parts: parts);
  }
}

/// What a line on the board is for; a formula is drawn quieter than a step.
enum BoardRole { formula, step, result }

/// One line written on the board.
class BoardLine {
  const BoardLine({required this.tex, required this.role});

  final String tex;
  final BoardRole role;

  factory BoardLine.fromJson(Json json) => BoardLine(
        tex: asString(json['tex'])?.trim() ?? '',
        role: switch (asString(json['role'])) {
          'formula' => BoardRole.formula,
          'result' => BoardRole.result,
          _ => BoardRole.step,
        },
      );
}

/// One step: what the teacher says and what is written on the board.
class SolutionStep {
  const SolutionStep({
    required this.title,
    required this.say,
    required this.board,
    required this.summary,
    required this.simpler,
    this.tip,
    this.rule,
  });

  final String title;

  /// One or two plain sentences; may hold `$…$` maths.
  final String say;
  final List<BoardLine> board;

  /// The step's result, shown once the step is collapsed.
  final String summary;

  /// "Tushunmadim": the same step again, one operation per sentence.
  final List<String> simpler;
  final String? tip;
  final String? rule;

  factory SolutionStep.fromJson(Json json) => SolutionStep(
        title: asString(json['title'])?.trim() ?? '',
        say: _prose(json['say']),
        board: asJsonList(json['board']).map(BoardLine.fromJson).where((l) => l.tex.isNotEmpty).toList(),
        summary: asString(json['summary'])?.trim() ?? '',
        simpler: _strings(json['simpler']),
        tip: _prose(json['tip']).nonEmpty,
        rule: asString(json['rule'])?.trim().nonEmpty,
      );
}

/// The final answer, in LaTeX and read aloud.
class SolutionAnswer {
  const SolutionAnswer({required this.tex, required this.words});

  final String tex;

  /// How to read the answer: "minus uchdan besh".
  final String words;

  factory SolutionAnswer.fromJson(dynamic json) {
    final map = json is Json ? json : const <String, dynamic>{};
    return SolutionAnswer(
      tex: asString(map['tex'])?.trim() ?? '',
      words: asString(map['words'])?.trim() ?? '',
    );
  }
}

/// Substituting the answer back: one sentence and one line.
class SolutionCheck {
  const SolutionCheck({required this.say, required this.tex});

  final String say;
  final String tex;

  static SolutionCheck? fromJson(dynamic json) {
    if (json is! Json) return null;
    final tex = asString(json['tex'])?.trim() ?? '';
    if (tex.isEmpty) return null;
    return SolutionCheck(say: asString(json['say'])?.trim() ?? '', tex: tex);
  }
}

/// The faster way, offered closed at the end for curious students.
class SolutionShortcut {
  const SolutionShortcut({required this.title, required this.say, required this.board});

  final String title;
  final String say;
  final List<String> board;

  static SolutionShortcut? fromJson(dynamic json) {
    if (json is! Json) return null;
    final board = _strings(json['board']);
    if (board.isEmpty) return null;
    return SolutionShortcut(
      title: asString(json['title']) ?? '',
      say: asString(json['say']) ?? '',
      board: board,
    );
  }
}

/// What a solution is about; it decides the intro card.
enum SolutionKind { math, physics, word }

/// A full step-by-step solution, as the server stores it.
class Solution {
  const Solution({
    required this.kind,
    required this.asked,
    required this.plan,
    required this.values,
    required this.given,
    required this.find,
    required this.steps,
    required this.answer,
    this.formula,
    this.tape,
    this.check,
    this.shortcut,
    this.realLife,
  });

  final SolutionKind kind;
  final String asked;
  final List<String> plan;
  final List<MathValue> values;
  final List<GivenValue> given;
  final List<FindItem> find;
  final FormulaCard? formula;
  final TapeSpec? tape;
  final List<SolutionStep> steps;
  final SolutionAnswer answer;
  final SolutionCheck? check;
  final SolutionShortcut? shortcut;
  final String? realLife;

  bool get isPhysics => kind == SolutionKind.physics && given.isNotEmpty;

  /// Null when the payload has nothing to show: no steps or no answer.
  static Solution? fromJson(dynamic json) {
    if (json is! Json) return null;
    final steps = asJsonList(json['steps']).map(SolutionStep.fromJson).where((s) => s.board.isNotEmpty).toList();
    final answer = SolutionAnswer.fromJson(json['answer']);
    if (steps.isEmpty || answer.tex.isEmpty) return null;
    return Solution(
      kind: switch (asString(json['kind'])) {
        'physics' => SolutionKind.physics,
        'word' => SolutionKind.word,
        _ => SolutionKind.math,
      },
      asked: _prose(json['asked']),
      plan: _strings(json['plan']),
      values: asJsonList(json['values']).map(MathValue.fromJson).toList(),
      given: asJsonList(json['given']).map(GivenValue.fromJson).toList(),
      find: asJsonList(json['find']).map(FindItem.fromJson).toList(),
      formula: FormulaCard.fromJson(json['formula']),
      tape: TapeSpec.fromJson(json['tape']),
      steps: steps,
      answer: answer,
      check: SolutionCheck.fromJson(json['check']),
      shortcut: SolutionShortcut.fromJson(json['shortcut']),
      realLife: _prose(json['real_life']).nonEmpty,
    );
  }
}

/// How the student's own wrong option probably came about.
class SolutionHint {
  const SolutionHint({
    required this.option,
    required this.headline,
    required this.rightTex,
    required this.wrongTex,
    required this.why,
    required this.tip,
  });

  final String option;
  final String headline;
  final String rightTex;
  final String wrongTex;
  final String why;
  final String tip;

  static SolutionHint? fromJson(dynamic json) {
    if (json is! Json) return null;
    return SolutionHint(
      option: asString(json['option']) ?? '',
      headline: _prose(json['headline']),
      rightTex: asString(json['right_tex'])?.trim() ?? '',
      wrongTex: asString(json['wrong_tex'])?.trim() ?? '',
      why: _prose(json['why']),
      tip: _prose(json['tip']),
    );
  }
}

/// Where a bank question's solution stands.
enum ExplanationStatus { ready, pending, unavailable, disputed }

/// The server's reply for a bank question.
class ExplanationResult {
  const ExplanationResult({
    required this.status,
    this.explanationId,
    this.questionText,
    this.correctOption,
    this.modelOption,
    this.studentMayBeRight = false,
    this.solution,
    this.hint,
    this.message,
  });

  final ExplanationStatus status;
  final int? explanationId;

  /// The question as the student saw it, for the intro.
  final String? questionText;
  final String? correctOption;

  /// In a dispute: the option two independent solutions agreed on.
  final String? modelOption;
  final bool studentMayBeRight;
  final Solution? solution;
  final SolutionHint? hint;
  final String? message;

  factory ExplanationResult.fromJson(Json? json) {
    final map = json ?? const <String, dynamic>{};
    final solution = Solution.fromJson(map['solution']);
    var status = switch (asString(map['status'])) {
      'ready' => ExplanationStatus.ready,
      'pending' => ExplanationStatus.pending,
      'disputed' => ExplanationStatus.disputed,
      _ => ExplanationStatus.unavailable,
    };
    // A ready reply the app cannot draw is no better than none.
    if (status == ExplanationStatus.ready && solution == null) status = ExplanationStatus.unavailable;
    return ExplanationResult(
      status: status,
      explanationId: asInt(map['explanation_id']),
      questionText: asString(map['question_text']),
      correctOption: asString(map['correct_option']),
      modelOption: asString(map['model_option']),
      studentMayBeRight: asBool(map['student_may_be_right']),
      solution: solution,
      hint: SolutionHint.fromJson(map['hint']),
      message: asString(map['message']),
    );
  }
}

/// Where a student's own problem stands.
enum SolveStatus { recognized, pending, done, failed }

/// A problem the student brought in, and its solution once there is one.
class SolveRequestItem {
  const SolveRequestItem({
    required this.id,
    required this.status,
    required this.subject,
    required this.text,
    this.imageUrl,
    this.solution,
    this.message,
    this.retryable = false,
    this.createdAt,
  });

  final int id;
  final SolveStatus status;
  final String subject;
  final String text;
  final String? imageUrl;
  final Solution? solution;
  final String? message;

  /// Failed for lack of the model: asking again may work and costs nothing.
  final bool retryable;
  final DateTime? createdAt;

  bool get isWorking => status == SolveStatus.pending;

  factory SolveRequestItem.fromJson(Json? json) {
    final map = json ?? const <String, dynamic>{};
    return SolveRequestItem(
      id: asInt(map['id']) ?? 0,
      status: switch (asString(map['status'])) {
        'recognized' => SolveStatus.recognized,
        'pending' => SolveStatus.pending,
        'done' => SolveStatus.done,
        _ => SolveStatus.failed,
      },
      subject: asString(map['subject']) ?? 'matematika',
      text: asString(map['text']) ?? '',
      imageUrl: asString(map['image_url']),
      solution: Solution.fromJson(map['solution']),
      message: asString(map['message']),
      retryable: asBool(map['retryable']),
      createdAt: parseUtcDate(map['created_at']),
    );
  }
}

/// How many problems the student can still bring in today.
class SolveQuota {
  const SolveQuota({required this.limit, required this.used, required this.left});

  final int limit;
  final int used;
  final int left;

  factory SolveQuota.fromJson(Json? json) {
    final map = json ?? const <String, dynamic>{};
    final limit = asInt(map['limit']) ?? 0;
    final used = asInt(map['used']) ?? 0;
    return SolveQuota(limit: limit, used: used, left: asInt(map['left']) ?? (limit - used).clamp(0, limit));
  }
}

/// What the server read off a photo, waiting for the student's confirmation.
class RecognizeResult {
  const RecognizeResult({
    required this.requestId,
    required this.readable,
    required this.text,
    required this.subject,
    required this.multiple,
    this.imageUrl,
    this.quota,
  });

  final int requestId;
  final bool readable;
  final String text;
  final String subject;
  final bool multiple;
  final String? imageUrl;
  final SolveQuota? quota;

  factory RecognizeResult.fromJson(Json? json) {
    final map = json ?? const <String, dynamic>{};
    return RecognizeResult(
      requestId: asInt(map['request_id']) ?? 0,
      readable: asBool(map['readable']),
      text: asString(map['text']) ?? '',
      subject: asString(map['subject']) ?? 'matematika',
      multiple: asBool(map['multiple']),
      imageUrl: asString(map['image_url']),
      quota: map['quota'] is Json ? SolveQuota.fromJson(map['quota'] as Json) : null,
    );
  }
}

extension on String {
  String? get nonEmpty => isEmpty ? null : this;
}
