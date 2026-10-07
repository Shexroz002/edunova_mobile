import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/solution_models.dart';

/// Step-by-step solutions: for bank questions and for the student's own problems.
///
/// Solving happens in the background on the server. Every call here is quick:
/// a fresh problem comes back `pending`, and the screen asks again until it
/// is `done` or `failed`.
class SolutionRepository {
  SolutionRepository(this._api);

  final ApiClient _api;

  static const _base = '/api/v1/student';

  /// The solution of a finished test's question; [chosen] is the student's option.
  Future<ExplanationResult> explanation(int questionId, {String? chosen}) async {
    final data = await _api.get(
      '$_base/questions/$questionId/explanation/',
      query: {if (chosen != null && chosen.isNotEmpty) 'chosen': chosen},
    );
    return ExplanationResult.fromJson(data is Json ? data : null);
  }

  /// How many problems are left today.
  Future<SolveQuota> quota() async {
    final data = await _api.get('$_base/solve/quota/');
    return SolveQuota.fromJson(data is Json ? data : null);
  }

  /// Recent problems, newest first; without their solutions.
  Future<List<SolveRequestItem>> history() async {
    final data = await _api.get('$_base/solve/history/');
    return asJsonList(data).map(SolveRequestItem.fromJson).toList();
  }

  /// Reads a photo. Nothing is solved until the student confirms the text.
  Future<RecognizeResult> recognize(File image) async {
    final type = _imageType(image.path);
    if (type == null) throw const ApiException('Faqat JPG, PNG yoki WEBP rasm yuborish mumkin');
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        image.path,
        filename: image.uri.pathSegments.last,
        contentType: DioMediaType('image', type),
      ),
    });
    final data = await _api.post('$_base/solve/recognize/', data: form);
    return RecognizeResult.fromJson(data is Json ? data : null);
  }

  /// Queues a problem: the confirmed text of a photo ([requestId]) or typed text.
  Future<SolveRequestItem> submit({int? requestId, required String text, required String subject}) async {
    final data = await _api.post(
      '$_base/solve/',
      data: {if (requestId != null) 'request_id': requestId, 'text': text, 'subject': subject},
    );
    return SolveRequestItem.fromJson(data is Json ? data : null);
  }

  /// The problem's status and, once done, its solution.
  Future<SolveRequestItem> request(int id) async {
    final data = await _api.get('$_base/solve/$id/');
    return SolveRequestItem.fromJson(data is Json ? data : null);
  }

  /// Sends a problem that failed for lack of the model again; it does not count twice.
  Future<SolveRequestItem> retry(int id) async {
    final data = await _api.post('$_base/solve/$id/retry/');
    return SolveRequestItem.fromJson(data is Json ? data : null);
  }

  /// "Was it clear?" — [verdict] is `helpful`, `unclear` or `wrong`.
  Future<void> feedback({int? explanationId, int? solveRequestId, required String verdict}) async {
    await _api.post(
      '$_base/solve/feedback/',
      data: {
        if (explanationId != null) 'explanation_id': explanationId,
        if (solveRequestId != null) 'solve_request_id': solveRequestId,
        'verdict': verdict,
      },
    );
  }

  static String? _imageType(String path) {
    final name = path.toLowerCase();
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'jpeg';
    if (name.endsWith('.png')) return 'png';
    if (name.endsWith('.webp')) return 'webp';
    return null;
  }
}

/// Provides [SolutionRepository].
final solutionRepositoryProvider = Provider<SolutionRepository>(
  (ref) => SolutionRepository(ref.watch(apiClientProvider)),
);

/// Problems left today, re-read after every new problem.
final solveQuotaProvider = FutureProvider.autoDispose<SolveQuota>(
  (ref) => ref.watch(solutionRepositoryProvider).quota(),
);

/// Recent problems for the solve screen.
final solveHistoryProvider = FutureProvider.autoDispose<List<SolveRequestItem>>(
  (ref) => ref.watch(solutionRepositoryProvider).history(),
);
