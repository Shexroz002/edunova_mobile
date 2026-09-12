import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/auth_user.dart';

/// Result of a successful login: tokens + the short user profile.
class LoginResult {
  const LoginResult({required this.tokens, required this.user});

  final AuthTokens tokens;
  final AuthUser user;
}

/// Auth endpoints: login, register, current user, subjects.
class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  /// `POST /api/v1/auth/me/` — OAuth2 password form.
  ///
  /// The backend matches usernames case-sensitively but stores them
  /// lowercased on registration, so the username is normalized here.
  Future<LoginResult> login({required String username, required String password}) async {
    final data = await _api.post(
      '/api/v1/auth/me/',
      auth: false,
      contentType: Headers.formUrlEncodedContentType,
      data: {
        'grant_type': 'password',
        'username': username.trim().toLowerCase(),
        'password': password,
      },
    ) as Json;

    return LoginResult(
      tokens: AuthTokens.fromJson(data),
      user: AuthUser.fromJson(Map<String, dynamic>.from(data['user'] as Map)),
    );
  }

  /// `POST /api/v1/auth/register/` — always registers a student (`schoolboy`).
  Future<void> register(RegisterRequest request) async {
    await _api.post('/api/v1/auth/register/', auth: false, data: request.toJson());
  }

  /// `GET /api/v1/auth/me/` — full profile (avatar, school, subjects).
  Future<AuthUser> fetchMe() async {
    final data = await _api.get('/api/v1/auth/me/') as Json;
    return AuthUser.fromJson(data);
  }

  /// `GET /api/v1/subject/list/` — public list of subjects.
  Future<List<Subject>> fetchSubjects() async {
    final data = await _api.get('/api/v1/subject/list/', auth: false);
    return asJsonList(data).map(Subject.fromJson).toList();
  }
}

/// Auth endpoints repository.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider)),
);

/// Subjects for the registration form (cached for the app lifetime).
final subjectsProvider = FutureProvider<List<Subject>>(
  (ref) => ref.watch(authRepositoryProvider).fetchSubjects(),
);
