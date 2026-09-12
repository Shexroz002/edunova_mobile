import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'network/api_client.dart';
import 'realtime/socket_service.dart';
import 'storage/token_storage.dart';

/// Overridden in `main.dart` with an already-initialized instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden in main()'),
);

/// Secure storage for tokens and the cached user.
final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

/// Broadcasts "the session has expired" from the network layer to the auth layer,
/// without making `core/` depend on `features/`.
class SessionEvents {
  final _expired = StreamController<void>.broadcast();

  Stream<void> get onExpired => _expired.stream;

  void expire() => _expired.add(null);

  void dispose() => _expired.close();
}

/// Session-expired event bus shared by the network and auth layers.
final sessionEventsProvider = Provider<SessionEvents>((ref) {
  final events = SessionEvents();
  ref.onDispose(events.dispose);
  return events;
});

/// The single HTTP client of the app.
final apiClientProvider = Provider<ApiClient>((ref) {
  final events = ref.watch(sessionEventsProvider);
  return ApiClient(
    tokenStorage: ref.watch(tokenStorageProvider),
    onSessionExpired: events.expire,
  );
});

/// Builds authenticated WebSocket clients (`/ws/...`).
final socketFactoryProvider = Provider<SocketFactory>((ref) {
  final api = ref.watch(apiClientProvider);
  return SocketFactory(api.accessToken, api.refreshAccessToken);
});

/// Light/dark mode, persisted between launches. Students default to dark (as on web).
class ThemeModeController extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    final saved = ref.read(sharedPreferencesProvider).getString(_key);
    return saved == 'light' ? ThemeMode.light : ThemeMode.dark;
  }

  void toggle() => setMode(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);

  void setMode(ThemeMode mode) {
    state = mode;
    ref.read(sharedPreferencesProvider).setString(_key, mode == ThemeMode.light ? 'light' : 'dark');
  }
}

/// Current [ThemeMode] (persisted).
final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
