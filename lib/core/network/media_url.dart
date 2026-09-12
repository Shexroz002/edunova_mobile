import '../config/app_config.dart';

/// Normalizes image/file links returned by the backend.
///
/// The backend builds absolute URLs from its own `BASE_URL` setting, which
/// locally is `http://127.0.0.1:8000` — unreachable from a phone. This helper:
/// * turns relative paths (`media/avatars/x.jpg`) into absolute URLs;
/// * rewrites `localhost` / `127.0.0.1` hosts to [AppConfig.apiBaseUrl];
/// * collapses duplicate slashes (`//media/...`);
/// * drops placeholder links that point at the host root.
class MediaUrl {
  MediaUrl._();

  static const _localHosts = {'localhost', '127.0.0.1', '0.0.0.0', '10.0.2.2'};

  /// Returns a loadable absolute URL, or `null` if there is nothing to show.
  static String? resolve(String? raw, {Uri? apiBase}) {
    final base = apiBase ?? AppConfig.apiBaseUri;
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;

    Uri uri;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      final parsed = Uri.tryParse(value);
      if (parsed == null) return null;
      uri = _localHosts.contains(parsed.host)
          ? parsed.replace(scheme: base.scheme, host: base.host, port: base.port)
          : parsed;
    } else {
      final path = value.replaceFirst(RegExp(r'^/+'), '');
      final baseText = base.toString().replaceAll(RegExp(r'/+$'), '');
      final parsed = Uri.tryParse('$baseText/$path');
      if (parsed == null) return null;
      uri = parsed;
    }

    final cleanPath = uri.path.replaceAll(RegExp(r'/{2,}'), '/');
    if (cleanPath.isEmpty || cleanPath == '/') return null;
    return uri.replace(path: cleanPath).toString();
  }
}
