import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/quiz_job.dart';

/// Starting and following a quiz-generation job.
class QuizCreateRepository {
  QuizCreateRepository(this._api);

  final ApiClient _api;

  static const _base = '/api/v1/quiz-generator';

  /// Uploads a PDF and queues the job. Multipart field name is `file`.
  ///
  /// The backend rejects anything that is not named `*.pdf` **and** sent as
  /// `application/pdf` (or `application/octet-stream`), and silently fails on a
  /// file over 5 MB, so both are checked here first.
  Future<QuizJob> startPdfJob(File file) async {
    if (!file.path.toLowerCase().endsWith('.pdf')) {
      throw const ApiException('Faqat PDF fayl yuklash mumkin');
    }
    if (await file.length() > CreateLimits.maxPdfBytes) {
      throw const ApiException("Fayl hajmi 5 MB dan oshmasligi kerak");
    }

    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: file.uri.pathSegments.last,
        contentType: DioMediaType('application', 'pdf'),
      ),
    });

    final data = await _api.post('$_base/pdf-jobs', data: form) as Json;
    return QuizJob.fromJson(data);
  }

  /// Queues an AI job. Every parameter goes in the **query string**; the
  /// endpoint takes no body, and `subject` is the numeric subject id.
  Future<QuizJob> startAiJob({
    required int subjectId,
    required String description,
    required int questionCount,
  }) async {
    final data = await _api.post(
      '$_base/quiz/generate',
      query: {
        'subject': subjectId,
        'description': description.trim(),
        'question_count': questionCount,
      },
    ) as Json;
    return QuizJob.fromJson(data);
  }

  /// Current job state. `404 "Job topilmadi"` for a missing or foreign job.
  Future<QuizJob> fetchJob(String jobId) async {
    final data = await _api.get('$_base/jobs/$jobId') as Json;
    return QuizJob.fromJson(data, fallbackId: jobId);
  }
}

/// Provides [QuizCreateRepository].
final quizCreateRepositoryProvider = Provider<QuizCreateRepository>(
  (ref) => QuizCreateRepository(ref.watch(apiClientProvider)),
);
