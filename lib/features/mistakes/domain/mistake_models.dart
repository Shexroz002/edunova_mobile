import '../../../core/utils/json_utils.dart';

/// One subject's share of the mistake bank.
class MistakeSubject {
  const MistakeSubject({
    required this.subject,
    required this.total,
    required this.due,
    this.nextDueAt,
  });

  final String subject;

  /// Open questions in this subject.
  final int total;

  /// How many of them are ready to review now.
  final int due;

  /// When the next one returns, null while some are already due.
  final DateTime? nextDueAt;

  factory MistakeSubject.fromJson(Json json) => MistakeSubject(
        subject: asString(json['subject']) ?? 'Boshqa',
        total: asInt(json['total']) ?? 0,
        due: asInt(json['due']) ?? 0,
        nextDueAt: parseUtcDate(json['next_due_at']),
      );
}

/// What the bank screen shows before a review starts.
class MistakeOverview {
  const MistakeOverview({
    required this.total,
    required this.due,
    required this.clearedLast30Days,
    required this.subjects,
    this.nextDueAt,
  });

  final int total;
  final int due;
  final int clearedLast30Days;
  final List<MistakeSubject> subjects;
  final DateTime? nextDueAt;

  static const empty = MistakeOverview(
    total: 0,
    due: 0,
    clearedLast30Days: 0,
    subjects: [],
  );

  /// Nothing has ever been missed, so there is no bank to show.
  bool get isEmpty => total == 0;

  factory MistakeOverview.fromJson(Json? json) {
    if (json == null) return empty;
    return MistakeOverview(
      total: asInt(json['total']) ?? 0,
      due: asInt(json['due']) ?? 0,
      clearedLast30Days: asInt(json['cleared_last_30_days']) ?? 0,
      nextDueAt: parseUtcDate(json['next_due_at']),
      subjects: asJsonList(json['subjects']).map(MistakeSubject.fromJson).toList(),
    );
  }
}

/// One answer choice of a question under review.
class MistakeOption {
  const MistakeOption({required this.label, required this.text});

  final String label;
  final String text;

  factory MistakeOption.fromJson(Json json) => MistakeOption(
        label: asString(json['label']) ?? '',
        text: asString(json['text']) ?? '',
      );
}

/// A question served for review.
///
/// The correct option comes down with it: a review is practice, not a test, so
/// the answer is revealed as soon as the student has chosen.
class MistakeQuestion {
  const MistakeQuestion({
    required this.questionId,
    required this.questionText,
    required this.options,
    required this.wrongCount,
    this.subject,
    this.topic,
    this.tableMarkdown,
    this.imageUrls = const [],
    this.correctOption,
  });

  final int questionId;
  final String questionText;
  final String? subject;
  final String? topic;
  final String? tableMarkdown;
  final List<String> imageUrls;
  final List<MistakeOption> options;
  final String? correctOption;

  /// How many times the student has missed this question.
  final int wrongCount;

  factory MistakeQuestion.fromJson(Json json) => MistakeQuestion(
        questionId: asInt(json['question_id']) ?? 0,
        questionText: asString(json['question_text']) ?? '',
        subject: asString(json['subject']),
        topic: asString(json['topic']),
        tableMarkdown: asString(json['table_markdown']),
        imageUrls: [
          for (final value in (json['image_urls'] as List? ?? const []))
            if (asString(value) != null) asString(value)!,
        ],
        options: asJsonList(json['options']).map(MistakeOption.fromJson).toList(),
        correctOption: asString(json['correct_option']),
        wrongCount: asInt(json['wrong_count']) ?? 1,
      );
}

/// What one review answer did to the schedule.
class MistakeAnswerResult {
  const MistakeAnswerResult({
    required this.questionId,
    required this.isCorrect,
    required this.streak,
    required this.cleared,
    required this.remainingDue,
    this.correctOption,
    this.nextDueAt,
  });

  final int questionId;
  final bool isCorrect;

  /// Correct answers in a row, 0..2.
  final int streak;

  /// True when the question has left the bank for good.
  final bool cleared;

  final int remainingDue;
  final String? correctOption;
  final DateTime? nextDueAt;

  factory MistakeAnswerResult.fromJson(Json? json) {
    final data = json ?? const <String, dynamic>{};
    return MistakeAnswerResult(
      questionId: asInt(data['question_id']) ?? 0,
      isCorrect: asBool(data['is_correct']),
      streak: asInt(data['streak']) ?? 0,
      cleared: asBool(data['cleared']),
      remainingDue: asInt(data['remaining_due']) ?? 0,
      correctOption: asString(data['correct_option']),
      nextDueAt: parseUtcDate(data['next_due_at']),
    );
  }
}
