import '../../../core/network/media_url.dart';
import '../../../core/utils/difficulty.dart';
import '../../../core/utils/json_utils.dart';

/// How a quiz was created (`quiz_generate_type`).
enum QuizSource {
  ai,
  pdf,
  manual,
  unknown;

  /// Parses `AI_GENERATE | PDF | MANUAL | UNDEFINED`.
  static QuizSource parse(String? raw) => switch (raw?.toUpperCase()) {
        'AI_GENERATE' => QuizSource.ai,
        'PDF' => QuizSource.pdf,
        'MANUAL' => QuizSource.manual,
        _ => QuizSource.unknown,
      };

  /// Short label shown on quiz cards.
  String get label => switch (this) {
        QuizSource.ai => 'AI',
        QuizSource.pdf => 'PDF',
        QuizSource.manual => "Qo'lda",
        QuizSource.unknown => 'Test',
      };
}

/// A quiz in `GET /student/quizzes/list` (the student's own quizzes).
class QuizSummary {
  const QuizSummary({
    required this.id,
    required this.title,
    required this.questionCount,
    required this.isNew,
    required this.source,
    this.description,
    this.subject,
    this.createdAt,
  });

  final int id;
  final String title;
  final String? description;
  final String? subject;
  final int questionCount;
  final bool isNew;
  final QuizSource source;
  final DateTime? createdAt;

  /// Suggested time limit in minutes (one minute per question, at least 10).
  int get suggestedMinutes => questionCount < 10 ? 10 : questionCount;

  factory QuizSummary.fromJson(Json json) => QuizSummary(
        id: asInt(json['quiz_id']) ?? asInt(json['id']) ?? 0,
        title: asString(json['title']) ?? 'Nomsiz test',
        description: asString(json['description']),
        subject: asString(json['subject']),
        questionCount: asInt(json['question_count']) ?? 0,
        isNew: asBool(json['is_new']),
        source: QuizSource.parse(asString(json['quiz_generate_type'])),
        createdAt: parseUtcDate(json['created_at']),
      );
}

/// A question row in the quiz detail (no options).
class QuizQuestionBrief {
  const QuizQuestionBrief({
    required this.id,
    required this.text,
    required this.difficulty,
    this.topic,
  });

  final int id;
  final String text;
  final String? topic;
  final Difficulty difficulty;

  factory QuizQuestionBrief.fromJson(Json json) => QuizQuestionBrief(
        id: asInt(json['id']) ?? 0,
        text: asString(json['question_text']) ?? '',
        topic: asString(json['topic']),
        difficulty: Difficulty.parse(asString(json['difficulty'])),
      );
}

/// `GET /student/quizzes/{id}/`.
class QuizDetail {
  const QuizDetail({
    required this.id,
    required this.title,
    required this.source,
    required this.questions,
    this.description,
    this.subject,
  });

  final int id;
  final String title;
  final String? description;
  final String? subject;
  final QuizSource source;
  final List<QuizQuestionBrief> questions;

  /// Number of questions with the given difficulty.
  int countOf(Difficulty difficulty) => questions.where((q) => q.difficulty == difficulty).length;

  /// Same suggestion rule as [QuizSummary.suggestedMinutes].
  int get suggestedMinutes => questions.length < 10 ? 10 : questions.length;

  factory QuizDetail.fromJson(Json json) {
    final questions = asJsonList(json['questions']).map(QuizQuestionBrief.fromJson).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return QuizDetail(
      id: asInt(json['id']) ?? 0,
      title: asString(json['title']) ?? 'Nomsiz test',
      description: asString(json['description']),
      subject: asString(json['subject']),
      source: QuizSource.parse(asString(json['quiz_generate_type'])),
      questions: questions,
    );
  }
}

/// An answer option; [isCorrect] is known only in detail/review responses.
class AnswerOption {
  const AnswerOption({required this.label, required this.text, this.id, this.isCorrect});

  /// Only `question/detail/{id}` returns it; the play endpoints do not, and the
  /// editor needs it for `update-correct-option`.
  final int? id;

  /// Option letter: `A`, `B`, `C`, `D`...
  final String label;
  final String text;
  final bool? isCorrect;

  factory AnswerOption.fromJson(Json json) => AnswerOption(
        id: asInt(json['id']),
        label: asString(json['label']) ?? '?',
        text: asString(json['text']) ?? '',
        isCorrect: json['is_correct'] is bool ? json['is_correct'] as bool : null,
      );

  /// Parses and sorts options by label (the API does not guarantee order).
  static List<AnswerOption> listFrom(dynamic value) =>
      asJsonList(value).map(AnswerOption.fromJson).toList()
        ..sort((a, b) => a.label.compareTo(b.label));
}

/// One image attached to a question.
class QuestionImage {
  const QuestionImage({required this.id, required this.url});

  final int id;

  /// Absolute URL, already resolved against the API host.
  final String url;

  /// `null` when the row has no usable URL.
  static QuestionImage? fromJson(Json json) {
    final url = MediaUrl.resolve(asString(json['image_url']));
    if (url == null) return null;
    return QuestionImage(id: asInt(json['id']) ?? 0, url: url);
  }
}

/// A full question: text, table, images and options.
///
/// Used for playing (`/multiplayer/{id}/questions/`), question detail and review.
class QuestionContent {
  const QuestionContent({
    required this.id,
    required this.text,
    required this.difficulty,
    required this.options,
    this.subject,
    this.topic,
    this.tableMarkdown,
    this.images = const [],
  });

  final int id;
  final String text;
  final String? subject;
  final String? topic;
  final Difficulty difficulty;
  final String? tableMarkdown;

  /// Attached images, with the ids the delete endpoint needs.
  final List<QuestionImage> images;

  /// Loadable image URLs, in order.
  List<String> get imageUrls => [for (final image in images) image.url];
  final List<AnswerOption> options;

  /// The option marked as correct, if the response contains it.
  AnswerOption? get correctOption {
    for (final option in options) {
      if (option.isCorrect == true) return option;
    }
    return null;
  }

  factory QuestionContent.fromJson(Json json) => QuestionContent(
        id: asInt(json['id']) ?? 0,
        text: asString(json['question_text']) ?? '',
        subject: asString(json['subject']),
        topic: asString(json['topic']),
        difficulty: Difficulty.parse(asString(json['difficulty'])),
        tableMarkdown: asString(json['table_markdown']),
        images: [
          for (final image in asJsonList(json['images']))
            if (QuestionImage.fromJson(image) case final parsed?) parsed,
        ],
        options: AnswerOption.listFrom(json['options']),
      );
}
