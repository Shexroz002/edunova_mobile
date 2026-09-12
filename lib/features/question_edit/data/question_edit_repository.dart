import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../domain/question_patch.dart';

/// Editing one question: its text, its correct option and its images.
///
/// Option **text** cannot be changed — the backend exposes no endpoint for it,
/// only `update-correct-option`.
class QuestionEditRepository {
  QuestionEditRepository(this._api);

  final ApiClient _api;

  static const _base = '/api/v1/question';

  /// `PUT /question/{id}/edit` — partial, returns `202`.
  Future<void> updateQuestion(int questionId, QuestionPatch patch) async {
    if (patch.isEmpty) return;
    await _api.put('$_base/$questionId/edit', data: patch.toJson());
  }

  /// Marks [optionId] correct and every other option wrong.
  Future<void> setCorrectOption({required int questionId, required int optionId}) =>
      _api.put('$_base/update-correct-option/$questionId/$optionId');

  /// `POST /question/upload-image/{id}` — multipart field `image`.
  ///
  /// The backend keeps the client's file name verbatim and does no type check,
  /// so the extension is validated here. A question may hold **two** images;
  /// the third is rejected with "Only one image can be uploaded".
  Future<void> uploadImage(int questionId, File file) async {
    final type = _imageType(file.path);
    if (type == null) {
      throw const ApiException('Faqat JPG, PNG yoki WEBP rasm yuklash mumkin');
    }

    final form = FormData.fromMap({
      'image': await MultipartFile.fromFile(
        file.path,
        filename: file.uri.pathSegments.last,
        contentType: DioMediaType('image', type),
      ),
    });

    await _api.post('$_base/upload-image/$questionId', data: form);
  }

  /// `DELETE /question/delete-image/{questionId}/{imageId}`.
  Future<void> deleteImage({required int questionId, required int imageId}) =>
      _api.delete('$_base/delete-image/$questionId/$imageId');

  static String? _imageType(String path) {
    final name = path.toLowerCase();
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'jpeg';
    if (name.endsWith('.png')) return 'png';
    if (name.endsWith('.webp')) return 'webp';
    return null;
  }
}

/// Provides [QuestionEditRepository].
final questionEditRepositoryProvider = Provider<QuestionEditRepository>(
  (ref) => QuestionEditRepository(ref.watch(apiClientProvider)),
);

/// Maximum images the backend accepts per question.
const maxQuestionImages = 2;
