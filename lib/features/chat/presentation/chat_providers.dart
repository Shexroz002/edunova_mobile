import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/realtime/socket_service.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/chat_socket.dart';

/// The one `/ws/chat` connection, shared by the list and every open room.
///
/// The backend subscribes a connection to all of the user's chats at once, so
/// a second socket would only duplicate traffic. `null` while signed out.
final chatSocketProvider = Provider<ChatSocket?>((ref) {
  final userId = ref.watch(authControllerProvider).user?.id;
  if (userId == null) return null;

  final socket = ref.watch(socketFactoryProvider).create(
    '/ws/chat',
    // Presence expires after 60 s server-side; the default 25 s beat keeps
    // us online without a margin this tight mattering.
    heartbeat: const {'type': ChatEventType.heartbeat},
  );
  final chatSocket = ChatSocket(socket)..start();
  ref.onDispose(chatSocket.dispose);
  return chatSocket;
});

/// Live connection status, for the "qayta ulanmoqda" banner.
final chatSocketStatusProvider = StreamProvider<SocketStatus>((ref) {
  final socket = ref.watch(chatSocketProvider);
  if (socket == null) return const Stream.empty();
  return socket.statusChanges;
});

/// Whether a user is online, and when they were last seen.
class PresenceState {
  const PresenceState({required this.online, this.lastSeenAt});

  final bool online;
  final DateTime? lastSeenAt;
}

/// Live presence of everyone the socket reports on.
///
/// Fed by `presence:update`, which the server publishes on the
/// `presence:{friend_id}` channels this connection subscribed to. The chat
/// list's own `is_online` comes from its REST snapshot; this map is what the
/// room header and the member list follow.
class PresenceController extends Notifier<Map<int, PresenceState>> {
  StreamSubscription<ChatEvent>? _subscription;

  @override
  Map<int, PresenceState> build() {
    final socket = ref.watch(chatSocketProvider);
    if (socket != null) {
      _subscription = socket.events.listen((event) {
        if (event is! PresenceEvent) return;
        state = {
          ...state,
          event.userId: PresenceState(online: event.online, lastSeenAt: event.lastSeenAt),
        };
      });
      ref.onDispose(() => _subscription?.cancel());
    }
    return const {};
  }

  /// Seeds from a REST snapshot (chat detail members) without waiting for a frame.
  void seed(int userId, {required bool online, DateTime? lastSeenAt}) {
    if (state[userId]?.online == online) return;
    state = {...state, userId: PresenceState(online: online, lastSeenAt: lastSeenAt)};
  }
}

/// Live presence map keyed by user id.
final presenceProvider =
    NotifierProvider<PresenceController, Map<int, PresenceState>>(PresenceController.new);

/// Errors the server pushed back (`error` frames), surfaced as snack bars.
final chatErrorProvider = StreamProvider<ChatErrorEvent>((ref) {
  final socket = ref.watch(chatSocketProvider);
  if (socket == null) return const Stream.empty();
  return socket.events.where((e) => e is ChatErrorEvent).cast<ChatErrorEvent>();
});
