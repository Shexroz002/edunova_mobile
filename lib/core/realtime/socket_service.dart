import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/app_config.dart';

/// Connection state of a [SocketService].
enum SocketStatus { idle, connecting, connected, reconnecting, closed }

/// A reconnecting JSON WebSocket client.
///
/// * Connects to `AppConfig.wsBaseUrl + path?token=<access token>`.
/// * Emits every decoded JSON object on [messages] (non-JSON frames are ignored).
/// * Reconnects with exponential backoff (1 s → 30 s) until [close] is called.
/// * Optionally sends a [heartbeat] message at [heartbeatInterval].
///
/// The token is fetched through [tokenProvider] on every (re)connect, so an
/// expired token is refreshed automatically. Full URLs are never logged
/// because they contain the token.
class SocketService {
  SocketService({
    required this.path,
    required this.tokenProvider,
    this.tokenRefresher,
    this.heartbeat,
    this.heartbeatInterval = const Duration(seconds: 25),
  });

  /// Socket path starting with `/`, e.g. `/ws/quiz/sessions/12`.
  final String path;

  /// Returns a valid access token (or `null` when signed out).
  final Future<String?> Function() tokenProvider;

  /// Forces a token refresh, used once after a rejected handshake.
  ///
  /// The backend closes the socket *before* accepting it, so a stale token
  /// surfaces as an HTTP `401`/`403` on the upgrade rather than a `1008` close
  /// frame, and the status is not reliably exposed by the channel exception.
  /// Retrying with the same token would then back off forever, so the first
  /// handshake failure refreshes the token and retries immediately.
  final Future<String?> Function()? tokenRefresher;

  /// Message sent periodically to keep the connection alive, e.g. `{'event': 'ping'}`.
  final Map<String, dynamic>? heartbeat;
  final Duration heartbeatInterval;

  final _messages = StreamController<Map<String, dynamic>>.broadcast();
  final _status = StreamController<SocketStatus>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _attempt = 0;
  bool _closed = false;
  bool _handshakeRefreshed = false;
  SocketStatus _current = SocketStatus.idle;

  /// Decoded incoming JSON objects.
  Stream<Map<String, dynamic>> get messages => _messages.stream;

  /// Connection status changes.
  Stream<SocketStatus> get statusChanges => _status.stream;

  /// Current connection status.
  SocketStatus get status => _current;

  /// Opens the connection (no-op if already connected or closed for good).
  Future<void> connect() async {
    if (_closed || _current == SocketStatus.connected || _current == SocketStatus.connecting) {
      return;
    }
    _setStatus(_attempt == 0 ? SocketStatus.connecting : SocketStatus.reconnecting);

    final token = await tokenProvider();
    if (_closed) return;
    if (token == null) {
      _setStatus(SocketStatus.closed);
      return;
    }

    final uri = Uri.parse('${AppConfig.wsBaseUrl}$path').replace(queryParameters: {'token': token});
    try {
      final channel = WebSocketChannel.connect(uri);
      await channel.ready;
      if (_closed) {
        await channel.sink.close();
        return;
      }
      _channel = channel;
      _attempt = 0;
      _setStatus(SocketStatus.connected);
      _handshakeRefreshed = false;
      _subscription = channel.stream.listen(
        _onData,
        onError: (_) => _scheduleReconnect(),
        onDone: _scheduleReconnect,
        cancelOnError: true,
      );
      _startHeartbeat();
    } catch (_) {
      // Never log the error: its message embeds the URL, which carries the token.
      await _onHandshakeFailed();
    }
  }

  /// Refreshes the token once after a rejected handshake, then retries at once;
  /// any further failure falls back to the normal backoff.
  Future<void> _onHandshakeFailed() async {
    final refresher = tokenRefresher;
    if (_closed || refresher == null || _handshakeRefreshed) {
      _scheduleReconnect();
      return;
    }

    _handshakeRefreshed = true;
    final token = await refresher();
    if (_closed) return;
    if (token == null) {
      // The refresh token is gone too: the session is over, so stop trying.
      _setStatus(SocketStatus.closed);
      return;
    }
    _current = SocketStatus.idle;
    await connect();
  }

  /// Sends a JSON message if connected; returns `false` otherwise.
  bool send(Map<String, dynamic> message) {
    final channel = _channel;
    if (channel == null || _current != SocketStatus.connected) return false;
    channel.sink.add(jsonEncode(message));
    return true;
  }

  /// Drops the current connection and connects again immediately
  /// (call it when the app returns to the foreground).
  Future<void> reconnectNow() async {
    if (_closed) return;
    await _teardown();
    _attempt = 0;
    _setStatus(SocketStatus.idle);
    await connect();
  }

  /// Closes the socket for good and releases all resources.
  Future<void> close() async {
    _closed = true;
    await _teardown();
    _setStatus(SocketStatus.closed);
    await _messages.close();
    await _status.close();
  }

  void _onData(dynamic data) {
    if (data is! String) return;
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) _messages.add(decoded);
    } catch (_) {
      // Ignore non-JSON frames.
    }
  }

  void _startHeartbeat() {
    final message = heartbeat;
    _heartbeatTimer?.cancel();
    if (message == null) return;
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) => send(message));
  }

  void _scheduleReconnect() {
    if (_closed) return;
    _teardown();
    _attempt++;
    final seconds = math.min(30, math.pow(2, _attempt - 1).toInt());
    _setStatus(SocketStatus.reconnecting);
    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      _current = SocketStatus.idle;
      connect();
    });
  }

  Future<void> _teardown() async {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    await _subscription?.cancel();
    _subscription = null;
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      try {
        await channel.sink.close();
      } catch (_) {
        // Already closed.
      }
    }
  }

  void _setStatus(SocketStatus status) {
    _current = status;
    if (!_status.isClosed) _status.add(status);
  }
}

/// Creates [SocketService]s that authenticate with the current session.
class SocketFactory {
  /// [tokenProvider] usually is `ApiClient.accessToken` and [tokenRefresher]
  /// `ApiClient.refreshAccessToken`.
  const SocketFactory(this._tokenProvider, this._tokenRefresher);

  final Future<String?> Function() _tokenProvider;
  final Future<String?> Function() _tokenRefresher;

  /// A new, not yet connected socket for [path] (e.g. `/ws/notifications/7`).
  SocketService create(String path, {Map<String, dynamic>? heartbeat}) => SocketService(
        path: path,
        tokenProvider: _tokenProvider,
        tokenRefresher: _tokenRefresher,
        heartbeat: heartbeat,
      );
}
