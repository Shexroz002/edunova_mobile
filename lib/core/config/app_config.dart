/// Global application configuration.
///
/// The backend address comes from `--dart-define-from-file=config/<env>.json`
/// (key `API_BASE_URL`).
///
/// Without it the default is `http://127.0.0.1:8000`, which is what a **real
/// phone or tablet** needs together with `adb reverse tcp:8000 tcp:8000`.
/// A build that forgets the flag then still reaches the backend instead of
/// failing with "Server javob bermadi". The Android **emulator** is the
/// exception — it reaches the host at `10.0.2.2`, so it needs
/// `--dart-define-from-file=config/dev.json`.
class AppConfig {
  AppConfig._();

  static const String _definedApiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Base REST address without a trailing slash, e.g. `http://127.0.0.1:8000`.
  static final String apiBaseUrl = _normalize(
    _definedApiBaseUrl.isNotEmpty ? _definedApiBaseUrl : _localDefault(),
  );

  /// WebSocket base address derived from [apiBaseUrl] (`http` → `ws`, `https` → `wss`).
  static String get wsBaseUrl {
    if (apiBaseUrl.startsWith('https://')) {
      return apiBaseUrl.replaceFirst('https://', 'wss://');
    }
    return apiBaseUrl.replaceFirst('http://', 'ws://');
  }

  /// Parsed [apiBaseUrl], used to rewrite media links.
  static final Uri apiBaseUri = Uri.parse(apiBaseUrl);

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);

  static String _localDefault() => 'http://127.0.0.1:8000';

  static String _normalize(String url) => url.replaceAll(RegExp(r'/+$'), '');
}
