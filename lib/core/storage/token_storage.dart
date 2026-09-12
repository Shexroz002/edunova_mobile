import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Access/refresh token pair returned by `/auth/me/` (login) and `/auth/refresh/`.
class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
      );

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
      };

  /// Expiry time read from the JWT `exp` claim, or `null` if it cannot be decoded.
  DateTime? get accessExpiresAt => _jwtExpiry(accessToken);

  /// True when the access token expires within [margin] (default 60 s).
  bool isAccessExpiringSoon({Duration margin = const Duration(seconds: 60)}) {
    final expiresAt = accessExpiresAt;
    if (expiresAt == null) return false;
    return expiresAt.difference(DateTime.now()) <= margin;
  }

  static DateTime? _jwtExpiry(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final exp = (jsonDecode(payload) as Map<String, dynamic>)['exp'];
      if (exp is! num) return null;
      return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
    } catch (_) {
      return null;
    }
  }
}

/// Persists the auth session (tokens + cached user JSON) in secure storage.
///
/// Values are cached in memory so the HTTP interceptor does not hit the
/// keychain/keystore on every request.
class TokenStorage {
  TokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static const _tokensKey = 'edunova_auth_tokens';
  static const _userKey = 'edunova_auth_user';

  final FlutterSecureStorage _storage;
  AuthTokens? _cachedTokens;
  bool _loaded = false;

  Future<AuthTokens?> readTokens() async {
    if (_loaded) return _cachedTokens;
    final raw = await _storage.read(key: _tokensKey);
    _cachedTokens = raw == null ? null : _decodeTokens(raw);
    _loaded = true;
    return _cachedTokens;
  }

  Future<void> saveTokens(AuthTokens tokens) async {
    _cachedTokens = tokens;
    _loaded = true;
    await _storage.write(key: _tokensKey, value: jsonEncode(tokens.toJson()));
  }

  Future<Map<String, dynamic>?> readUserJson() async {
    final raw = await _storage.read(key: _userKey);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveUserJson(Map<String, dynamic> user) =>
      _storage.write(key: _userKey, value: jsonEncode(user));

  Future<void> clear() async {
    _cachedTokens = null;
    _loaded = true;
    await _storage.delete(key: _tokensKey);
    await _storage.delete(key: _userKey);
  }

  AuthTokens? _decodeTokens(String raw) {
    try {
      return AuthTokens.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
