import '../../../core/utils/json_utils.dart';

/// `GET /student/quizzes/analytics/overall/cards`.
///
/// The whole object can come back `null`, and `average` is a **string**
/// (`"30.77"`), so every field is parsed defensively.
class OverallStats {
  const OverallStats({
    required this.totalSessions,
    required this.correctAnswers,
    required this.averagePercent,
  });

  final int totalSessions;
  final int correctAnswers;
  final double averagePercent;

  static const empty = OverallStats(totalSessions: 0, correctAnswers: 0, averagePercent: 0);

  factory OverallStats.fromJson(Json? json) {
    if (json == null) return empty;
    return OverallStats(
      totalSessions: asInt(json['total_quiz_session']) ?? 0,
      correctAnswers: asInt(json['correct_answer']) ?? 0,
      averagePercent: asDouble(json['average']) ?? 0,
    );
  }
}

/// One row of `GET /student/quizzes/analytics/subjects`.
class SubjectStats {
  const SubjectStats({
    required this.subject,
    required this.correct,
    required this.wrong,
    required this.total,
    required this.percent,
    this.firstAttempt,
    this.lastAttempt,
  });

  final String subject;
  final int correct;
  final int wrong;
  final int total;
  final double percent;

  /// `date` values (no time part).
  final DateTime? firstAttempt;
  final DateTime? lastAttempt;

  factory SubjectStats.fromJson(Json json) => SubjectStats(
        subject: asString(json['subject_name']) ?? 'Fan',
        correct: asInt(json['correct_answer']) ?? 0,
        wrong: asInt(json['wrong_answer']) ?? 0,
        total: asInt(json['total_answer']) ?? 0,
        percent: asDouble(json['percentage']) ?? 0,
        firstAttempt: parseUtcDate(json['first_attempt_date']),
        lastAttempt: parseUtcDate(json['last_attempt_date']),
      );
}

/// One block of `GET /student/quizzes/analytics/recommendation`.
class RecommendationBlock {
  const RecommendationBlock({required this.title, required this.text, this.icon});

  final String title;
  final String text;
  final String? icon;

  static RecommendationBlock? fromJson(dynamic value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    final text = asString(json['text']);
    if (text == null || text.isEmpty) return null;
    return RecommendationBlock(
      title: asString(json['title']) ?? '',
      text: text,
      icon: asString(json['icon']),
    );
  }
}

/// Rule-based study advice. The endpoint is typed `any`, so every field is
/// optional and the screen hides whatever is missing.
class Recommendation {
  const Recommendation({
    required this.title,
    required this.subtitle,
    this.badge,
    this.strongSides,
    this.improvement,
    this.nextGoal,
  });

  final String title;
  final String subtitle;
  final String? badge;
  final RecommendationBlock? strongSides;
  final RecommendationBlock? improvement;
  final RecommendationBlock? nextGoal;

  /// True when there is nothing worth rendering.
  bool get isEmpty => strongSides == null && improvement == null && nextGoal == null;

  factory Recommendation.fromJson(Json? json) {
    if (json == null) {
      return const Recommendation(title: 'AI tavsiyasi', subtitle: '');
    }
    return Recommendation(
      title: asString(json['title']) ?? 'AI tavsiyasi',
      subtitle: asString(json['subtitle']) ?? '',
      badge: asString(json['badge']),
      strongSides: RecommendationBlock.fromJson(json['strong_sides']),
      improvement: RecommendationBlock.fromJson(json['improvement']),
      nextGoal: RecommendationBlock.fromJson(json['next_goal']),
    );
  }
}

/// Sessions started on one day, for the weekly activity chart.
class DailyActivity {
  const DailyActivity({required this.day, required this.count});

  /// Local midnight of the day.
  final DateTime day;
  final int count;

  /// Uzbek weekday abbreviation, as on the web chart.
  String get label => switch (day.weekday) {
        DateTime.monday => 'Du',
        DateTime.tuesday => 'Se',
        DateTime.wednesday => 'Ch',
        DateTime.thursday => 'Pa',
        DateTime.friday => 'Ju',
        DateTime.saturday => 'Sha',
        _ => 'Ya',
      };

  /// Counts sessions per day over the last 7 days, oldest first.
  ///
  /// The web hard-codes `[4,7,3,8,5,2,6]`; `CLAUDE.md` default decision 3 says
  /// to compute it from history instead. History only records when a session
  /// was created, so this counts **sessions started**, and the chart says so.
  static List<DailyActivity> lastWeek(Iterable<DateTime?> startedAt, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final midnight = DateTime(today.year, today.month, today.day);
    final days = [for (var i = 6; i >= 0; i--) midnight.subtract(Duration(days: i))];
    final counts = {for (final day in days) day: 0};

    for (final raw in startedAt) {
      if (raw == null) continue;
      final local = raw.toLocal();
      final key = DateTime(local.year, local.month, local.day);
      if (counts.containsKey(key)) counts[key] = counts[key]! + 1;
    }

    return [for (final day in days) DailyActivity(day: day, count: counts[day]!)];
  }
}
