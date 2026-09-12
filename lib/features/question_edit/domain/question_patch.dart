import '../../../core/utils/difficulty.dart';
import '../../tests/domain/quiz.dart';

/// The fields `PUT /api/v1/question/{id}/edit` accepts.
///
/// The backend applies `model_dump(exclude_unset=True)`, so only what changed
/// needs to be sent. `subject` is a plain string there, not a subject id.
class QuestionPatch {
  const QuestionPatch({this.questionText, this.topic, this.difficulty, this.tableMarkdown});

  final String? questionText;
  final String? topic;

  /// `oson` | `o'rta` | `qiyin`, as the generator writes them.
  final String? difficulty;
  final String? tableMarkdown;

  bool get isEmpty =>
      questionText == null && topic == null && difficulty == null && tableMarkdown == null;

  Map<String, dynamic> toJson() => {
        if (questionText != null) 'question_text': questionText,
        if (topic != null) 'topic': topic,
        if (difficulty != null) 'difficulty': difficulty,
        if (tableMarkdown != null) 'table_markdown': tableMarkdown,
      };

  /// Builds the diff between the loaded question and the edited form.
  static QuestionPatch diff({required QuestionContent before, required QuestionForm after}) {
    final text = after.text.trim();
    final topic = after.topic.trim();
    return QuestionPatch(
      questionText: text == before.text ? null : text,
      topic: topic == (before.topic ?? '') ? null : topic,
      difficulty: after.difficulty == before.difficulty ? null : after.difficulty.apiValue,
    );
  }
}

/// What the editor holds while the student types.
class QuestionForm {
  const QuestionForm({
    required this.text,
    required this.topic,
    required this.difficulty,
    required this.correctOptionId,
  });

  final String text;
  final String topic;
  final Difficulty difficulty;

  /// `null` only for a question whose options came back without ids.
  final int? correctOptionId;

  factory QuestionForm.of(QuestionContent question) => QuestionForm(
        text: question.text,
        topic: question.topic ?? '',
        difficulty: question.difficulty,
        correctOptionId: question.correctOption?.id,
      );

  /// The question text is the one field the backend cannot do without.
  String? validate() => text.trim().isEmpty ? "Savol matni bo'sh bo'lmasligi kerak" : null;

  QuestionForm copyWith({
    String? text,
    String? topic,
    Difficulty? difficulty,
    int? correctOptionId,
  }) =>
      QuestionForm(
        text: text ?? this.text,
        topic: topic ?? this.topic,
        difficulty: difficulty ?? this.difficulty,
        correctOptionId: correctOptionId ?? this.correctOptionId,
      );
}
