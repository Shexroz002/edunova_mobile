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

  /// Folds rows the backend returns for one subject under several spellings.
  ///
  /// `analytics/subjects` groups by the stored subject name, so "fizika" and
  /// "Fizika" come back as two rows for the same subject. Counts are added and
  /// the percentage is recomputed from them, which weights each spelling by the
  /// answers it carried — averaging the two percentages would let a five-answer
  /// row count as much as a sixty-answer one.
  static List<SubjectStats> merged(List<SubjectStats> rows) {
    final byName = <String, SubjectStats>{};
    for (final row in rows) {
      final key = row.subject.trim().toLowerCase();
      final seen = byName[key];
      if (seen == null) {
        byName[key] = row;
        continue;
      }
      final correct = seen.correct + row.correct;
      final total = seen.total + row.total;
      byName[key] = SubjectStats(
        subject: _betterSpelling(seen.subject, row.subject),
        correct: correct,
        wrong: seen.wrong + row.wrong,
        total: total,
        percent: total == 0 ? 0 : correct / total * 100,
        firstAttempt: _earlier(seen.firstAttempt, row.firstAttempt),
        lastAttempt: _later(seen.lastAttempt, row.lastAttempt),
      );
    }
    return byName.values.toList();
  }

  /// Prefers the capitalised spelling, which is how a subject is written.
  static String _betterSpelling(String a, String b) {
    final aCapital = a.isNotEmpty && a[0] == a[0].toUpperCase();
    final bCapital = b.isNotEmpty && b[0] == b[0].toUpperCase();
    if (aCapital == bCapital) return a;
    return aCapital ? a : b;
  }

  static DateTime? _earlier(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a ?? b;
    return a.isBefore(b) ? a : b;
  }

  static DateTime? _later(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a ?? b;
    return a.isAfter(b) ? a : b;
  }

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

/// Sessions of one day, split by whether they were finished.
class DailyActivity {
  const DailyActivity({required this.day, required this.total, required this.done});

  /// Local midnight of the day.
  final DateTime day;

  /// Sessions started on this day.
  final int total;

  /// How many of them the student answered through to the end.
  final int done;

  /// Started and walked away from.
  int get abandoned => total - done;

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
  /// to compute it from history instead.
  ///
  /// The count is split because a bar of sessions *started* overstates the
  /// week: a large share of them are abandoned after a handful of questions,
  /// so an untouched test would stand as tall as one answered to the end.
  static List<DailyActivity> lastWeek(
    Iterable<({DateTime? startedAt, bool finished})> sessions, {
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final midnight = DateTime(today.year, today.month, today.day);
    final days = [for (var i = 6; i >= 0; i--) midnight.subtract(Duration(days: i))];
    final total = {for (final day in days) day: 0};
    final done = {for (final day in days) day: 0};

    for (final session in sessions) {
      final raw = session.startedAt;
      if (raw == null) continue;
      final local = raw.toLocal();
      final key = DateTime(local.year, local.month, local.day);
      if (!total.containsKey(key)) continue;
      total[key] = total[key]! + 1;
      if (session.finished) done[key] = done[key]! + 1;
    }

    return [
      for (final day in days) DailyActivity(day: day, total: total[day]!, done: done[day]!),
    ];
  }
}
