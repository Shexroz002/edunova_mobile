import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/storage/token_storage.dart';
import '../data/auth_repository.dart';
import '../domain/auth_user.dart';

/// Session status used by the router to pick login, splash or the app.
enum AuthStatus { unknown, authenticated, unauthenticated }

/// Current session state. The router redirects based on [status].
class AuthState {
  const AuthState._(this.status, this.user);

  const AuthState.unknown() : this._(AuthStatus.unknown, null);
  const AuthState.unauthenticated() : this._(AuthStatus.unauthenticated, null);
  const AuthState.authenticated(AuthUser user) : this._(AuthStatus.authenticated, user);

  final AuthStatus status;
  final AuthUser? user;

  bool get isAuthenticated => status == AuthStatus.authenticated;
}

/// Owns the login session: restore on startup, login, register, logout.
class AuthController extends Notifier<AuthState> {
  StreamSubscription<void>? _expiredSub;

  AuthRepository get _repo => ref.read(authRepositoryProvider);
  TokenStorage get _storage => ref.read(tokenStorageProvider);

  @override
  AuthState build() {
    _expiredSub = ref.read(sessionEventsProvider).onExpired.listen((_) {
      state = const AuthState.unauthenticated();
    });
    ref.onDispose(() => _expiredSub?.cancel());

    Future.microtask(_restore);
    return const AuthState.unknown();
  }

  /// Restores a saved session instantly from the cached user,
  /// then refreshes the profile from the server in the background.
  Future<void> _restore() async {
    final tokens = await _storage.readTokens();
    final cached = await _storage.readUserJson();
    if (tokens == null || cached == null) {
      state = const AuthState.unauthenticated();
      return;
    }

    final user = AuthUser.fromJson(cached);
    if (!user.isStudent) {
      await _storage.clear();
      state = const AuthState.unauthenticated();
      return;
    }

    state = AuthState.authenticated(user);
    unawaited(refreshProfile());
  }

  /// Signs in and loads the full profile.
  ///
  /// Throws [ApiException] with a user-facing message on failure.
  Future<void> login(String username, String password) async {
    final result = await _repo.login(username: username, password: password);

    if (!result.user.isStudent) {
      throw const ApiException(
        "Bu ilova faqat o'quvchilar uchun. O'qituvchilar web-versiyadan foydalanadi.",
      );
    }

    await _storage.saveTokens(result.tokens);
    var user = result.user;
    try {
      user = await _repo.fetchMe(); // login response never contains the avatar
    } on ApiException {
      // Keep the short profile; it will be refreshed later.
    }
    await _storage.saveUserJson(user.toJson());
    state = AuthState.authenticated(user);
  }

  /// Registers a new student account and signs in right away.
  Future<void> register(RegisterRequest request) async {
    await _repo.register(request);
    await login(request.username, request.password);
  }

  /// Re-fetches `/auth/me/`; silently ignores network errors.
  Future<void> refreshProfile() async {
    try {
      final user = await _repo.fetchMe();
      await _storage.saveUserJson(user.toJson());
      if (state.isAuthenticated) state = AuthState.authenticated(user);
    } on ApiException catch (e) {
      if (e.isUnauthorized) await logout();
    }
  }

  Future<void> logout() async {
    await _storage.clear();
    state = const AuthState.unauthenticated();
  }
}

/// Global auth session controller.
final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

/// Convenience: the signed-in user (null while signed out).
final currentUserProvider = Provider<AuthUser?>((ref) => ref.watch(authControllerProvider).user);
