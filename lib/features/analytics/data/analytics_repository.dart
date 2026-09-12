import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/utils/json_utils.dart';
import '../../session/data/session_repository.dart';
import '../domain/analytics_models.dart';

/// Student analytics endpoints.
///
/// These replace the gamification the web invents on the client (XP, streak,
/// level, rank) — see `CLAUDE.md` default decision 1.
class AnalyticsRepository {
  AnalyticsRepository(this._api);

  final ApiClient _api;

  static const _base = '/api/v1/student/quizzes/analytics';

  /// Session count, correct answers and the average score.
  Future<OverallStats> fetchOverall() async {
    final data = await _api.get('$_base/overall/cards');
    return OverallStats.fromJson(data is Map<String, dynamic> ? data : null);
  }

  /// Per-subject accuracy, newest attempt last.
  Future<List<SubjectStats>> fetchSubjects() async {
    final data = await _api.get('$_base/subjects');
    return asJsonList(data).map(SubjectStats.fromJson).toList();
  }

  /// Rule-based study advice. The endpoint is typed `any`, so parse tolerantly.
  Future<Recommendation> fetchRecommendation() async {
    final data = await _api.get('$_base/recommendation');
    return Recommendation.fromJson(data is Map<String, dynamic> ? data : null);
  }
}

/// Provides [AnalyticsRepository].
final analyticsRepositoryProvider = Provider<AnalyticsRepository>(
  (ref) => AnalyticsRepository(ref.watch(apiClientProvider)),
);

/// Overall stat cards shown on the home and profile screens.
final overallStatsProvider = FutureProvider.autoDispose<OverallStats>(
  (ref) => ref.watch(analyticsRepositoryProvider).fetchOverall(),
);

/// Per-subject results shown in "Mening fanlarim".
final subjectStatsProvider = FutureProvider.autoDispose<List<SubjectStats>>(
  (ref) => ref.watch(analyticsRepositoryProvider).fetchSubjects(),
);

/// Study advice shown on the statistics screen.
final recommendationProvider = FutureProvider.autoDispose<Recommendation>(
  (ref) => ref.watch(analyticsRepositoryProvider).fetchRecommendation(),
);

/// Sessions started per day over the last week, from the session history.
final weeklyActivityProvider = FutureProvider.autoDispose<List<DailyActivity>>((ref) async {
  final history = await ref.watch(sessionRepositoryProvider).fetchAllHistory(maxItems: 200);
  return DailyActivity.lastWeek(history.map((item) => item.createdAt));
});
