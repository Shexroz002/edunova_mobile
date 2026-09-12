import 'package:dio/dio.dart';

import '../storage/token_storage.dart';

/// Request option flags understood by [AuthInterceptor].
class AuthFlags {
  AuthFlags._();

  /// Set `extra: {AuthFlags.skipAuth: true}` for public endpoints (login, register...).
  static const skipAuth = 'skipAuth';
  static const _retried = 'authRetried';
}

/// Attaches the Bearer token and keeps it fresh.
///
/// * Refreshes proactively when the access token expires within 60 s.
/// * On `401` refreshes once and retries the original request.
/// * Concurrent refreshes are merged into a single call (single-flight),
///   so parallel requests never rotate the refresh token twice.
/// * If the refresh token is rejected, the session is cleared and
///   [onSessionExpired] is called so the app can return to the login screen.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.dio,
    required this.tokenStorage,
    required this.onSessionExpired,
  }) : _refreshDio = Dio(
          BaseOptions(
            baseUrl: dio.options.baseUrl,
            connectTimeout: dio.options.connectTimeout,
            receiveTimeout: dio.options.receiveTimeout,
            headers: {'accept': 'application/json'},
          ),
        );

  final Dio dio;
  final TokenStorage tokenStorage;
  final void Function() onSessionExpired;
  final Dio _refreshDio;

  Future<AuthTokens?>? _refreshing;

  /// Returns a usable access token, refreshing it first if it is about to expire.
  ///
  /// Used by WebSocket connections, which pass the token in the query string.
  Future<String?> freshAccessToken() async {
    var tokens = await tokenStorage.readTokens();
    if (tokens != null && tokens.isAccessExpiringSoon()) {
      tokens = await _refresh(tokens) ?? await tokenStorage.readTokens();
    }
    return tokens?.accessToken;
  }

  /// Forces a refresh (e.g. after a WebSocket handshake was rejected).
  Future<String?> forceRefresh() async {
    final tokens = await tokenStorage.readTokens();
    if (tokens == null) return null;
    return (await _refresh(tokens))?.accessToken;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra[AuthFlags.skipAuth] == true) {
      handler.next(options);
      return;
    }

    final token = await freshAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final isUnauthorized = err.response?.statusCode == 401;
    final canRetry = options.extra[AuthFlags.skipAuth] != true &&
        options.extra[AuthFlags._retried] != true &&
        options.data is! FormData; // multipart bodies cannot be re-sent

    if (!isUnauthorized || !canRetry) {
      handler.next(err);
      return;
    }

    final current = await tokenStorage.readTokens();
    if (current == null) {
      handler.next(err);
      return;
    }

    final refreshed = await _refresh(current);
    if (refreshed == null) {
      handler.next(err);
      return;
    }

    options.extra[AuthFlags._retried] = true;
    try {
      final response = await dio.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  /// Runs at most one refresh at a time; other callers await the same future.
  Future<AuthTokens?> _refresh(AuthTokens current) {
    final inFlight = _refreshing;
    if (inFlight != null) return inFlight;
    final future = _doRefresh(current);
    _refreshing = future;
    return future.whenComplete(() => _refreshing = null);
  }

  Future<AuthTokens?> _doRefresh(AuthTokens current) async {
    try {
      final response = await _refreshDio.post<Map<String, dynamic>>(
        '/api/v1/auth/refresh/',
        data: {'refresh_token': current.refreshToken},
      );
      final tokens = AuthTokens.fromJson(response.data!);
      await tokenStorage.saveTokens(tokens);
      return tokens;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 404) {
        await tokenStorage.clear();
        onSessionExpired();
      }
      // Network errors keep the session: the user may simply be offline.
      return null;
    } catch (_) {
      return null;
    }
  }
}
