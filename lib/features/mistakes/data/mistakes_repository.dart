import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/mistake_models.dart';

/// The mistake bank: questions the student got wrong, on a review schedule.
///
/// The server fills the bank from the student's own answer history, so the
/// first call already returns everything they have ever missed — the client
/// never has to seed it.
class MistakesRepository {
  MistakesRepository(this._api);

  final ApiClient _api;

  static const _base = '/api/v1/student/mistakes';

  /// Counts for the bank screen.
  Future<MistakeOverview> fetchOverview() async {
    final data = await _api.get('$_base/overview/');
    return MistakeOverview.fromJson(data is Map<String, dynamic> ? data : null);
  }

  /// Questions to review now. Empty when nothing is due yet — there is no
  /// practising ahead of schedule.
  Future<List<MistakeQuestion>> fetchReview({String? subject}) async {
    final data = await _api.get(
      '$_base/review/',
      query: {if (subject != null && subject.isNotEmpty) 'subject': subject},
    );
    return asJsonList(data).map(MistakeQuestion.fromJson).toList();
  }

  /// Records one answer and returns what it did to the schedule.
  Future<MistakeAnswerResult> answer({
    required int questionId,
    required String selectedOption,
  }) async {
    final data = await _api.post(
      '$_base/$questionId/answer/',
      data: {'selected_option': selectedOption},
    );
    return MistakeAnswerResult.fromJson(data is Map<String, dynamic> ? data : null);
  }
}

/// Provides [MistakesRepository].
final mistakesRepositoryProvider = Provider<MistakesRepository>(
  (ref) => MistakesRepository(ref.watch(apiClientProvider)),
);

/// Bank counts, re-read whenever a review finishes.
final mistakeOverviewProvider = FutureProvider.autoDispose<MistakeOverview>(
  (ref) => ref.watch(mistakesRepositoryProvider).fetchOverview(),
);
