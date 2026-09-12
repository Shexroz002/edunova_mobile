import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/json_utils.dart';

/// Accent colour of a group.
///
/// The schema declares these lowercase but the server sends them uppercase
/// (`BLUE`, `VIOLET`), so parsing is case-insensitive with a fallback — the
/// web's map misses `VIOLET` entirely and renders it colourless.
enum GroupColor {
  purple(Color(0xFF7C3AED)),
  blue(Color(0xFF3B82F6)),
  violet(Color(0xFF8B5CF6)),
  green(Color(0xFF22C55E)),
  yellow(Color(0xFFFBBF24)),
  red(Color(0xFFEF4444)),
  pink(Color(0xFFEC4899)),
  teal(Color(0xFF14B8A6)),
  orange(Color(0xFFF97316)),
  cyan(Color(0xFF06B6D4));

  const GroupColor(this.color);

  final Color color;

  static GroupColor parse(String? raw) {
    final key = raw?.trim().toLowerCase();
    for (final value in GroupColor.values) {
      if (value.name == key) return value;
    }
    return GroupColor.blue;
  }
}

/// `ACTIVE` / `ARCHIVED`, also sent uppercase.
enum GroupStatus {
  active('Faol', AppColors.success),
  archived('Arxivlangan', Color(0xFF94A3B8));

  const GroupStatus(this.label, this.color);

  final String label;
  final Color color;

  static GroupStatus parse(String? raw) =>
      raw?.trim().toLowerCase() == 'archived' ? GroupStatus.archived : GroupStatus.active;
}

/// A group card from `GET /student/group/` or `.../detail-card`.
class StudentGroup {
  const StudentGroup({
    required this.id,
    required this.name,
    required this.status,
    required this.color,
    required this.studentsCount,
    required this.testsCount,
    required this.averageScore,
    this.subject,
    this.description,
    this.lastActivity,
    this.coverImage,
  });

  final int id;
  final String name;
  final GroupStatus status;
  final GroupColor color;
  final int studentsCount;
  final int testsCount;
  final double averageScore;
  final String? subject;
  final String? description;
  final DateTime? lastActivity;

  /// Always `null` from both endpoints today — see `BACKEND_ISSUES.md` #28.
  final String? coverImage;

  factory StudentGroup.fromJson(Json json) => StudentGroup(
        id: asInt(json['id']) ?? 0,
        name: asString(json['name']) ?? 'Guruh',
        status: GroupStatus.parse(asString(json['status'])),
        color: GroupColor.parse(asString(json['color'])),
        studentsCount: asInt(json['students_count']) ?? 0,
        testsCount: asInt(json['tests_count']) ?? 0,
        averageScore: asDouble(json['average_score']) ?? 0,
        subject: asString(json['subject_name']),
        description: asString(json['description']),
        lastActivity: parseUtcDate(json['last_activity']),
        coverImage: asString(json['cover_image']),
      );
}

/// One row of `GET /student/group/{gid}/sessions`.
class GroupTest {
  const GroupTest({
    required this.sessionId,
    required this.quizId,
    required this.quizName,
    required this.averageScore,
    required this.completedStudents,
    required this.totalStudents,
    this.date,
  });

  final int sessionId;
  final int quizId;
  final String quizName;
  final double averageScore;
  final int completedStudents;
  final int totalStudents;
  final DateTime? date;

  factory GroupTest.fromJson(Json json) => GroupTest(
        sessionId: asInt(json['session_id']) ?? 0,
        quizId: asInt(json['quiz_id']) ?? 0,
        quizName: asString(json['quiz_name']) ?? 'Test',
        averageScore: asDouble(json['average_score']) ?? 0,
        completedStudents: asInt(json['completed_students']) ?? 0,
        totalStudents: asInt(json['total_students']) ?? 0,
        date: parseUtcDate(json['session_date']),
      );
}

/// One row of `GET /student/group/{gid}/students-performance`.
class GroupStudent {
  const GroupStudent({
    required this.studentId,
    required this.fullName,
    required this.correct,
    required this.wrong,
    required this.testsCount,
    required this.averageScore,
    this.profileImage,
  });

  final int studentId;
  final String fullName;
  final int correct;
  final int wrong;
  final int testsCount;
  final double averageScore;
  final String? profileImage;

  factory GroupStudent.fromJson(Json json) => GroupStudent(
        studentId: asInt(json['student_id']) ?? 0,
        fullName: asString(json['full_name']) ?? '',
        correct: asInt(json['correct_answers']) ?? 0,
        wrong: asInt(json['wrong_answers']) ?? 0,
        testsCount: asInt(json['tests_count']) ?? 0,
        averageScore: asDouble(json['average_score']) ?? 0,
        profileImage: asString(json['profile_image']),
      );
}

/// `GET /student/group/{gid}/results/{sid}`.
class GroupSessionResult {
  const GroupSessionResult({
    required this.sessionId,
    required this.quizId,
    required this.quizName,
    required this.status,
    required this.participantsCount,
    required this.durationMinutes,
    required this.averageScore,
    required this.highestScore,
    required this.lowestScore,
    this.subject,
    this.date,
    this.hardestQuestionNumber,
    this.hardestQuestionAccuracy,
  });

  final int sessionId;
  final int quizId;
  final String quizName;
  final String status;
  final int participantsCount;
  final int durationMinutes;
  final double averageScore;
  final double highestScore;
  final double lowestScore;
  final String? subject;
  final DateTime? date;
  final int? hardestQuestionNumber;
  final double? hardestQuestionAccuracy;

  /// Uzbek label for the raw status string.
  String get statusLabel => switch (status.toLowerCase()) {
        'finished' || 'completed' => 'Yakunlangan',
        'running' => 'Davom etmoqda',
        'waiting' => 'Kutilmoqda',
        _ => status,
      };

  factory GroupSessionResult.fromJson(Json json) => GroupSessionResult(
        sessionId: asInt(json['session_id']) ?? 0,
        quizId: asInt(json['quiz_id']) ?? 0,
        quizName: asString(json['quiz_name']) ?? 'Test',
        status: asString(json['status']) ?? '',
        participantsCount: asInt(json['participants_count']) ?? 0,
        durationMinutes: asInt(json['duration_minutes']) ?? 0,
        averageScore: asDouble(json['average_score']) ?? 0,
        highestScore: asDouble(json['highest_score']) ?? 0,
        lowestScore: asDouble(json['lowest_score']) ?? 0,
        subject: asString(json['subject_name']),
        date: parseUtcDate(json['session_date']),
        hardestQuestionNumber: asInt(json['hardest_question_number']),
        hardestQuestionAccuracy: asDouble(json['hardest_question_accuracy']),
      );
}

/// Difficulty band of a question, from its accuracy.
enum AccuracyBand {
  easy('Oson', AppColors.success),
  medium("O'rta", AppColors.warning),
  hard('Qiyin', AppColors.error);

  const AccuracyBand(this.label, this.color);

  final String label;
  final Color color;

  /// The web's legend: ≥75% oson, 50–74% o'rta, <50% qiyin.
  static AccuracyBand of(double accuracy) {
    if (accuracy >= 75) return AccuracyBand.easy;
    if (accuracy >= 50) return AccuracyBand.medium;
    return AccuracyBand.hard;
  }
}

/// One row of `GET /student/group/{gid}/question-accuracy/{sid}`.
class QuestionAccuracy {
  const QuestionAccuracy({
    required this.questionId,
    required this.number,
    required this.label,
    required this.totalAnswers,
    required this.correctAnswers,
    required this.accuracyPercent,
  });

  final int questionId;
  final int number;
  final String label;
  final int totalAnswers;
  final int correctAnswers;
  final double accuracyPercent;

  AccuracyBand get band => AccuracyBand.of(accuracyPercent);

  factory QuestionAccuracy.fromJson(Json json) => QuestionAccuracy(
        questionId: asInt(json['question_id']) ?? 0,
        number: asInt(json['question_number']) ?? 0,
        label: asString(json['label']) ?? '',
        totalAnswers: asInt(json['total_answers']) ?? 0,
        correctAnswers: asInt(json['correct_answers']) ?? 0,
        accuracyPercent: asDouble(json['accuracy_percent']) ?? 0,
      );
}
