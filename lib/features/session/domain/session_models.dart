import '../../../core/utils/json_utils.dart';
import '../../tests/domain/quiz.dart';

/// Session type from the backend.
enum SessionType {
  individual,
  group,
  public;

  /// Unknown values fall back to [individual].
  static SessionType parse(String? raw) => switch (raw?.toLowerCase()) {
        'group' => SessionType.group,
        'public' => SessionType.public,
        _ => SessionType.individual,
      };

  /// Multiplayer sessions report answers and navigation for live monitoring.
  bool get isMultiplayer => this != SessionType.individual;
}

/// `GET /student/sessions/multiplayer/{id}/info/` (also works for single player).
class SessionInfo {
  const SessionInfo({
    required this.sessionId,
    required this.quizId,
    required this.hostId,
    required this.joinCode,
    required this.status,
    required this.durationMinutes,
    required this.questionsCount,
    required this.type,
    this.quizName,
    this.subjectName,
    this.startedAt,
    this.deadlineAt,
    this.finishedAt,
    this.currentParticipantId,
  });

  final int sessionId;
  final int quizId;
  final String? quizName;
  final String? subjectName;
  final int hostId;
  final String joinCode;

  /// `waiting | running | finished`.
  final String status;
  final int durationMinutes;
  final int questionsCount;
  final DateTime? startedAt;
  final DateTime? deadlineAt;
  final DateTime? finishedAt;
  final SessionType type;

  /// The caller's participant id (needed for leave / question order).
  final int? currentParticipantId;

  bool get isRunning => status == 'running';
  bool get isWaiting => status == 'waiting';
  bool get isFinished => status == 'finished';

  factory SessionInfo.fromJson(Json json) => SessionInfo(
        sessionId: asInt(json['session_id']) ?? 0,
        quizId: asInt(json['quiz_id']) ?? 0,
        quizName: asString(json['quiz_name']),
        subjectName: asString(json['subject_name']),
        hostId: asInt(json['host_id']) ?? 0,
        joinCode: asString(json['join_code']) ?? '',
        status: asString(json['status'])?.toLowerCase() ?? 'running',
        durationMinutes: asInt(json['duration_minutes']) ?? 0,
        questionsCount: asInt(json['questions_count']) ?? 0,
        startedAt: parseTashkentDate(json['started_at']),
        deadlineAt: parseTashkentDate(json['deadline_at']),
        finishedAt: parseTashkentDate(json['finished_at']),
        type: SessionType.parse(asString(json['session_type'])),
        currentParticipantId: asInt(json['current_participant_id']),
      );
}

/// `GET /student/sessions/multiplayer/{id}/questions/`.
class SessionQuestions {
  const SessionQuestions({
    required this.sessionId,
    required this.quizId,
    required this.status,
    required this.questions,
    this.startedAt,
    this.deadlineAt,
    this.finishedAt,
  });

  final int sessionId;
  final int quizId;
  final String status;
  final DateTime? startedAt;
  final DateTime? deadlineAt;
  final DateTime? finishedAt;

  /// Ordered by question id; the 1-based index is the server's question order.
  final List<QuestionContent> questions;

  factory SessionQuestions.fromJson(Json json) => SessionQuestions(
        sessionId: asInt(json['session_id']) ?? 0,
        quizId: asInt(json['quiz_id']) ?? 0,
        status: asString(json['status'])?.toLowerCase() ?? 'running',
        startedAt: parseTashkentDate(json['started_at']),
        deadlineAt: parseTashkentDate(json['deadline_at']),
        finishedAt: parseTashkentDate(json['finished_at']),
        questions: asJsonList(json['questions']).map(QuestionContent.fromJson).toList(),
      );
}

/// Per-topic result inside [FinishResult].
class TopicStat {
  const TopicStat({required this.name, required this.total, required this.correct});

  final String name;
  final int total;
  final int correct;

  /// 0..100.
  double get percent => total == 0 ? 0.0 : correct * 100 / total;

  factory TopicStat.fromJson(Json json) => TopicStat(
        name: asString(json['topic_name']) ?? 'Umumiy',
        total: asInt(json['total_questions']) ?? 0,
        correct: asInt(json['correct_answers']) ?? 0,
      );
}

/// Result of finishing a session (`FinishQuizResponse`).
class FinishResult {
  const FinishResult({
    required this.sessionId,
    required this.totalQuestions,
    required this.answeredQuestions,
    required this.correctAnswers,
    required this.wrongAnswers,
    required this.topics,
    this.spendSeconds,
  });

  final int sessionId;
  final int totalQuestions;
  final int answeredQuestions;
  final int correctAnswers;
  final int wrongAnswers;

  /// Time spent in seconds (null when unknown).
  final int? spendSeconds;
  final List<TopicStat> topics;

  /// Questions left unanswered.
  int get skipped {
    final value = totalQuestions - answeredQuestions;
    return value < 0 ? 0 : value;
  }

  /// Score in percent (0..100).
  double get percent => totalQuestions == 0 ? 0.0 : correctAnswers * 100 / totalQuestions;

  /// Correct answers among the answered ones (0..100).
  double get accuracy => answeredQuestions == 0 ? 0.0 : correctAnswers * 100 / answeredQuestions;

  factory FinishResult.fromJson(Json json) => FinishResult(
        sessionId: asInt(json['session_id']) ?? 0,
        totalQuestions: asInt(json['total_questions']) ?? 0,
        answeredQuestions: asInt(json['answered_questions']) ?? 0,
        correctAnswers: asInt(json['correct_answers']) ?? asInt(json['score']) ?? 0,
        wrongAnswers: asInt(json['wrong_answers']) ?? 0,
        spendSeconds: asInt(json['spend_time']),
        topics: asJsonList(json['topic_statistic']).map(TopicStat.fromJson).toList(),
      );

  /// Rebuilds a result from the review data (used when the result screen is
  /// opened without the finish response, e.g. from history).
  factory FinishResult.fromReview(int sessionId, List<ReviewItem> items) {
    final byTopic = <String, List<ReviewItem>>{};
    for (final item in items) {
      byTopic.putIfAbsent(item.question.topic ?? 'Umumiy', () => []).add(item);
    }
    return FinishResult(
      sessionId: sessionId,
      totalQuestions: items.length,
      answeredQuestions: items.where((i) => i.isAnswered).length,
      correctAnswers: items.where((i) => i.isCorrect).length,
      wrongAnswers: items.where((i) => i.isWrong).length,
      topics: [
        for (final entry in byTopic.entries)
          TopicStat(
            name: entry.key,
            total: entry.value.length,
            correct: entry.value.where((i) => i.isCorrect).length,
          ),
      ],
    );
  }
}

/// One question in `single-player-error-analysis`.
class ReviewItem {
  const ReviewItem({required this.question, this.selected, this.selectedIsCorrect});

  /// Question with options (options include `isCorrect`).
  final QuestionContent question;

  /// The label the student picked, or null when unanswered.
  final String? selected;
  final bool? selectedIsCorrect;

  bool get isAnswered => selected != null;
  bool get isCorrect =>
      isAnswered && (selectedIsCorrect ?? question.correctOption?.label == selected);
  bool get isWrong => isAnswered && !isCorrect;

  factory ReviewItem.fromJson(Json json) => ReviewItem(
        // `id` is the question id; `question_id` is actually the quiz id (backend bug).
        question: QuestionContent.fromJson(json),
        selected: asString(json['user_select_option']),
        selectedIsCorrect: json['user_select_option_is_correct'] is bool
            ? json['user_select_option_is_correct'] as bool
            : null,
      );
}

/// A row of `GET /student/sessions/me/history/`.
class HistoryItem {
  const HistoryItem({
    required this.sessionId,
    required this.rank,
    required this.createdAt,
    this.title,
    this.subject,
    this.participantCount,
    this.correctAnswers,
    this.wrongAnswers,
    this.totalQuestions,
    this.finishedAt,
  });

  final int sessionId;
  final String? title;
  final String? subject;
  final int rank;
  final int? participantCount;
  final int? correctAnswers;
  final int? wrongAnswers;
  final int? totalQuestions;
  final DateTime? finishedAt;
  final DateTime? createdAt;

  /// Unfinished sessions come back with null counts.
  bool get isFinished => correctAnswers != null && totalQuestions != null;

  bool get isMultiplayer => (participantCount ?? 1) > 1;

  /// Score in percent (0..100), 0 when unfinished.
  double get percent {
    final total = totalQuestions ?? 0;
    return total == 0 ? 0.0 : (correctAnswers ?? 0) * 100 / total;
  }

  /// Minutes between session creation and finish (both UTC), or null.
  int? get durationMinutes {
    final start = createdAt;
    final end = finishedAt;
    if (!isFinished || start == null || end == null) return null;
    final minutes = end.difference(start).inMinutes;
    return minutes < 0 ? null : minutes;
  }

  factory HistoryItem.fromJson(Json json) => HistoryItem(
        sessionId: asInt(json['session_id']) ?? 0,
        title: asString(json['title']),
        subject: asString(json['subject']),
        rank: asInt(json['rank']) ?? 1,
        participantCount: asInt(json['participant_count']),
        correctAnswers: asInt(json['correct_answers']),
        wrongAnswers: asInt(json['wrong_answers']),
        totalQuestions: asInt(json['total_questions']),
        finishedAt: parseUtcDate(json['finished_at']),
        createdAt: parseUtcDate(json['created_at']),
      );
}

/// A participant row in session / group leaderboards.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.userId,
    required this.fullName,
    this.profileImage,
    this.score,
    this.wrongAnswers,
    this.totalQuestions,
    this.spendSeconds,
    this.rank = 0,
  });

  final int userId;
  final String fullName;
  final String? profileImage;

  /// Correct answers count; null when the participant did not finish.
  final int? score;
  final int? wrongAnswers;
  final int? totalQuestions;
  final double? spendSeconds;

  /// 1-based rank computed on the client (0 = not ranked).
  final int rank;

  double get percent {
    final total = totalQuestions ?? 0;
    return total == 0 ? 0.0 : (score ?? 0) * 100 / total;
  }

  LeaderboardEntry withRank(int value) => LeaderboardEntry(
        userId: userId,
        fullName: fullName,
        profileImage: profileImage,
        score: score,
        wrongAnswers: wrongAnswers,
        totalQuestions: totalQuestions,
        spendSeconds: spendSeconds,
        rank: value,
      );

  factory LeaderboardEntry.fromJson(Json json) {
    final name =
        '${asString(json['first_name']) ?? ''} ${asString(json['last_name']) ?? ''}'.trim();
    return LeaderboardEntry(
      userId: asInt(json['user_id']) ?? 0,
      fullName: name.isEmpty ? "O'quvchi" : name,
      profileImage: asString(json['profile_image']),
      score: asInt(json['score']),
      wrongAnswers: asInt(json['wrong_answers']),
      totalQuestions: asInt(json['total_questions']),
      spendSeconds: asDouble(json['spend_time_seconds']),
    );
  }

  /// Sorts by score (nulls last), then by time, and assigns ranks
  /// (equal score and time share a rank).
  static List<LeaderboardEntry> ranked(List<LeaderboardEntry> entries) {
    final sorted = [...entries]..sort((a, b) {
        if (a.score == null && b.score != null) return 1;
        if (b.score == null && a.score != null) return -1;
        final byScore = (b.score ?? 0).compareTo(a.score ?? 0);
        if (byScore != 0) return byScore;
        return (a.spendSeconds ?? double.infinity).compareTo(b.spendSeconds ?? double.infinity);
      });

    final result = <LeaderboardEntry>[];
    for (var i = 0; i < sorted.length; i++) {
      final entry = sorted[i];
      if (entry.score == null) {
        result.add(entry.withRank(0));
        continue;
      }
      final previous = i > 0 ? result[i - 1] : null;
      final sameAsPrevious = previous != null &&
          previous.score == entry.score &&
          previous.spendSeconds == entry.spendSeconds;
      result.add(entry.withRank(sameAsPrevious ? previous.rank : i + 1));
    }
    return result;
  }
}
