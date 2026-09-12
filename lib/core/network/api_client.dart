import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';
import 'auth_interceptor.dart';

/// Thin wrapper around [Dio] used by all repositories.
///
/// Every method returns the decoded JSON body (`Map`, `List` or `null`)
/// and throws [ApiException] with a ready-to-show Uzbek message on failure.
class ApiClient {
  ApiClient({
    required TokenStorage tokenStorage,
    required void Function() onSessionExpired,
    String? baseUrl,
  }) : dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ?? AppConfig.apiBaseUrl,
            connectTimeout: AppConfig.connectTimeout,
            receiveTimeout: AppConfig.receiveTimeout,
            headers: {'accept': 'application/json'},
          ),
        ) {
    _auth = AuthInterceptor(
      dio: dio,
      tokenStorage: tokenStorage,
      onSessionExpired: onSessionExpired,
    );
    dio.interceptors.add(_auth);
    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(
          requestHeader: false, // do not print Bearer tokens
          responseHeader: false,
          requestBody: false,
          responseBody: false,
        ),
      );
    }
  }

  final Dio dio;
  late final AuthInterceptor _auth;

  /// A valid access token for WebSocket URLs (refreshed if about to expire).
  Future<String?> accessToken() => _auth.freshAccessToken();

  /// Forces a token refresh; returns the new access token or `null`.
  Future<String?> refreshAccessToken() => _auth.forceRefresh();

  /// `GET` request; returns the decoded JSON body.
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) =>
      _send(() => dio.get<dynamic>(path, queryParameters: _clean(query), options: _options(auth)));

  /// `POST` request; `data` may be a JSON map/list, form map or [FormData].
  Future<dynamic> post(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    bool auth = true,
    String? contentType,
  }) =>
      _send(() => dio.post<dynamic>(
            path,
            data: data,
            queryParameters: _clean(query),
            options: _options(auth, contentType: contentType),
          ));

  /// `PUT` request; returns the decoded JSON body.
  Future<dynamic> put(String path, {Object? data, bool auth = true}) =>
      _send(() => dio.put<dynamic>(path, data: data, options: _options(auth)));

  /// `PATCH` request; returns the decoded JSON body.
  Future<dynamic> patch(String path, {Object? data, bool auth = true}) =>
      _send(() => dio.patch<dynamic>(path, data: data, options: _options(auth)));

  /// `DELETE` request; returns the decoded JSON body (often `null`).
  Future<dynamic> delete(String path, {bool auth = true}) =>
      _send(() => dio.delete<dynamic>(path, options: _options(auth)));

  Future<dynamic> _send(Future<Response<dynamic>> Function() request) async {
    try {
      final response = await request();
      return response.data;
    } catch (error) {
      throw ApiException.from(error);
    }
  }

  Options _options(bool auth, {String? contentType}) => Options(
        contentType: contentType,
        extra: {AuthFlags.skipAuth: !auth},
      );

  /// Drops `null` and empty-string query values (the backend rejects `search=`).
  Map<String, dynamic>? _clean(Map<String, dynamic>? query) {
    if (query == null) return null;
    return {
      for (final entry in query.entries)
        if (entry.value != null && entry.value.toString().isNotEmpty) entry.key: entry.value,
    };
  }
}
