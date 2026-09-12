import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/realtime/socket_service.dart';
import '../../../core/utils/json_utils.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/notifications_repository.dart';
import '../domain/app_notification.dart';

/// Live notification stream for the signed-in student.
///
/// Wraps `/ws/notifications/{userId}`, whose frames are `{type, data}`:
/// * any [NotificationKind] value carries a whole notification object;
/// * `notification_count_update` carries `{count}` for the bell badge.
///
/// The socket is opened once per session and shared by the badge and the
/// notification list, so the list can prepend arrivals while the badge counts.
class NotificationStream {
  NotificationStream(this._socket);

  final SocketService _socket;

  final _arrivals = StreamController<AppNotification>.broadcast();
  final _counts = StreamController<int>.broadcast();
  StreamSubscription<Json>? _subscription;

  /// Notifications pushed while the app is open.
  Stream<AppNotification> get arrivals => _arrivals.stream;

  /// Unread counts pushed by `notification_count_update`.
  Stream<int> get unreadCounts => _counts.stream;

  /// Connects and starts dispatching frames.
  void start() {
    _subscription ??= _socket.messages.listen(_onFrame);
    _socket.connect();
  }

  /// Reconnects after the app returns to the foreground.
  Future<void> resume() => _socket.reconnectNow();

  void _onFrame(Json frame) {
    final type = asString(frame['type']);
    final data = frame['data'] is Map
        ? Map<String, dynamic>.from(frame['data'] as Map)
        : const <String, dynamic>{};

    if (type == 'notification_count_update') {
      final count = asInt(data['count']);
      if (count != null) _counts.add(count);
      return;
    }
    if (data.isEmpty) return;
    // Anything else is a notification object; its own `type` field is authoritative.
    _arrivals.add(AppNotification.fromJson(data));
  }

  /// Closes the socket and both streams.
  Future<void> dispose() async {
    await _subscription?.cancel();
    await _socket.close();
    await _arrivals.close();
    await _counts.close();
  }
}

/// Live notification socket, or `null` while signed out.
final notificationStreamProvider = Provider<NotificationStream?>((ref) {
  final userId = ref.watch(authControllerProvider).user?.id;
  if (userId == null) return null;

  final socket = ref.watch(socketFactoryProvider).create('/ws/notifications/$userId');
  final stream = NotificationStream(socket)..start();
  ref.onDispose(stream.dispose);
  return stream;
});

/// Unread notification count driving the app-bar bell badge.
///
/// Seeded from the REST list so the badge is right before any frame arrives,
/// then kept up to date by `notification_count_update`.
class UnreadCountController extends Notifier<int> {
  StreamSubscription<int>? _socketSub;
  StreamSubscription<AppNotification>? _arrivalSub;

  @override
  int build() {
    final stream = ref.watch(notificationStreamProvider);
    if (stream != null) {
      _socketSub = stream.unreadCounts.listen((count) => state = count);
      // A push can arrive before the server sends a new count.
      _arrivalSub = stream.arrivals.listen((_) => state = state + 1);
      ref.onDispose(() {
        _socketSub?.cancel();
        _arrivalSub?.cancel();
      });
      Future.microtask(refresh);
    }
    return 0;
  }

  /// Recounts from the server (after opening the list, or marking as read).
  Future<void> refresh() async {
    try {
      final page = await ref.read(notificationsRepositoryProvider).fetchPage(page: 1, size: 100);
      state = page.items.where((n) => !n.isRead).length;
    } catch (_) {
      // A failed badge refresh must never surface as an error to the user.
    }
  }

  /// Applies a local change without waiting for the server.
  void setCount(int value) => state = value < 0 ? 0 : value;
}

/// Unread notification count (bell badge).
final unreadCountProvider = NotifierProvider<UnreadCountController, int>(UnreadCountController.new);
