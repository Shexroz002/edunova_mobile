import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/quiz.dart';

/// The student's own quizzes (created from PDF or AI).
class TestsRepository {
  TestsRepository(this._api);

  final ApiClient _api;

  /// `GET /student/quizzes/list` — one page, optionally filtered by [search].
  Future<PageResult<QuizSummary>> fetchQuizzes(
      {String? search, int page = 1, int size = 20}) async {
    final data = await _api.get(
      '/api/v1/student/quizzes/list',
      query: {'search': search, 'page': page, 'size': size},
    ) as Json;
    return PageResult.fromJson(data, QuizSummary.fromJson);
  }

  /// `GET /student/quizzes/{id}/` — quiz with its question list (no options).
  Future<QuizDetail> fetchQuiz(int quizId) async {
    final data = await _api.get('/api/v1/student/quizzes/$quizId/') as Json;
    return QuizDetail.fromJson(data);
  }

  /// `GET /question/detail/{id}` — one question with options and the correct answer.
  Future<QuestionContent> fetchQuestion(int questionId) async {
    final data = await _api.get('/api/v1/question/detail/$questionId') as Json;
    return QuestionContent.fromJson(data);
  }
}

/// Provides [TestsRepository].
final testsRepositoryProvider = Provider<TestsRepository>(
  (ref) => TestsRepository(ref.watch(apiClientProvider)),
);
