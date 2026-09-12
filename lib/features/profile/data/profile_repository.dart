import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../domain/profile_edit.dart';

/// Profile editing: the detail patch and the avatar upload.
class ProfileRepository {
  ProfileRepository(this._api);

  final ApiClient _api;

  /// `PUT /api/v1/users/{id}/`.
  ///
  /// The response echoes the patch schema with `null` for every field that was
  /// not sent, so it says nothing about the stored user; the caller reloads
  /// `/auth/me/` instead.
  Future<void> updateProfile(int userId, ProfilePatch patch) async {
    if (patch.isEmpty) return;
    await _api.put('/api/v1/users/$userId/', data: patch.toJson());
  }

  /// `PUT /api/v1/users/{id}/avatar/` — multipart, field name `avatar`.
  ///
  /// The backend accepts jpg, png and webp only, and decides by the
  /// `Content-Type` of the part, so it is set explicitly from the extension.
  /// Returns the new image path.
  Future<String?> uploadAvatar(int userId, File file) async {
    final type = _imageType(file.path);
    if (type == null) {
      throw const ApiException('Faqat JPG, PNG yoki WEBP rasm yuklash mumkin');
    }

    final form = FormData.fromMap({
      'avatar': await MultipartFile.fromFile(
        file.path,
        filename: file.uri.pathSegments.last,
        contentType: DioMediaType('image', type),
      ),
    });

    final data = await _api.put('/api/v1/users/$userId/avatar/', data: form);
    return data is Map ? data['profile_image']?.toString() : null;
  }

  /// The image subtype the backend allows, or `null` for anything else.
  static String? _imageType(String path) {
    final name = path.toLowerCase();
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'jpeg';
    if (name.endsWith('.png')) return 'png';
    if (name.endsWith('.webp')) return 'webp';
    return null;
  }
}

/// Provides [ProfileRepository].
final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(apiClientProvider)),
);
