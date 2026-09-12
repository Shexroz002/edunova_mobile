import '../../../core/utils/json_utils.dart';

/// Lifecycle of a quiz-generation job.
enum JobStatus {
  queued,
  processing,
  completed,
  failed;

  /// Nothing more will arrive for a job in this state.
  bool get isFinal => this == completed || this == failed;

  static JobStatus parse(String? value) => switch (value?.toLowerCase().trim()) {
        'processing' => processing,
        'completed' => completed,
        'failed' => failed,
        _ => queued,
      };
}

/// A PDF or AI quiz-generation job.
///
/// The same shape comes back from three places — the `POST` that starts it,
/// `GET /quiz-generator/jobs/{id}`, and the `/ws/jobs/{id}/` frames — except
/// that the `POST` carries `task_id` and no `quiz_id`, so every field is
/// optional.
class QuizJob {
  const QuizJob({
    required this.id,
    required this.status,
    required this.progress,
    this.message,
    this.quizId,
    this.questionCount,
    this.error,
  });

  final String id;
  final JobStatus status;

  /// 0–100. **Also 100 on failure**, so never infer success from it.
  final int progress;

  /// Uzbek progress text written by the backend; safe to show.
  final String? message;

  /// Only set once `status == completed`.
  final int? quizId;
  final int? questionCount;

  /// Raw upstream error, in English, often quoting the AI provider — logged
  /// but never shown (`docs/BACKEND_ISSUES.md`).
  final String? error;

  bool get isFinal => status.isFinal;
  bool get isDone => status == JobStatus.completed && quizId != null;

  factory QuizJob.fromJson(Json json, {String? fallbackId}) => QuizJob(
        id: asString(json['job_id']) ?? fallbackId ?? '',
        status: JobStatus.parse(asString(json['status'])),
        progress: (asInt(json['progress']) ?? 0).clamp(0, 100),
        message: asString(json['message']),
        quizId: asInt(json['quiz_id']),
        questionCount: asInt(json['question_count']),
        error: asString(json['error']),
      );

  QuizJob mergedWith(QuizJob update) => QuizJob(
        id: update.id.isEmpty ? id : update.id,
        status: update.status,
        progress: update.progress,
        message: update.message ?? message,
        quizId: update.quizId ?? quizId,
        questionCount: update.questionCount ?? questionCount,
        error: update.error ?? error,
      );
}

/// How the student wants the quiz built.
enum CreateMethod { pdf, ai }

/// Limits the backend really enforces, so the form can refuse early.
class CreateLimits {
  const CreateLimits._();

  /// `settings.MAX_PDF_SIZE` is 5 MB. The web says "Maksimal: 10 MB", which is
  /// wrong — a bigger file is accepted by the picker and then rejected with
  /// "Fayl saqlanmadi".
  static const maxPdfBytes = 5 * 1024 * 1024;

  /// The backend sets no bounds; the web's form allows 5–50 and the AI prompt
  /// is written for that range.
  static const minQuestions = 5;
  static const maxQuestions = 50;
  static const defaultQuestions = 20;
}
