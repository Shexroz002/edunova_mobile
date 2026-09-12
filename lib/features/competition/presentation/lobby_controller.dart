import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/realtime/socket_service.dart';
import '../../../core/utils/json_utils.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../session/domain/session_models.dart';
import '../data/competition_repository.dart';
import '../domain/competition_models.dart';

/// Everything the waiting room renders.
class LobbyState {
  const LobbyState({
    required this.info,
    required this.participants,
    this.socketStatus = SocketStatus.idle,
    this.started = false,
    this.finishedMessage,
  });

  final SessionInfo info;
  final List<SessionParticipant> participants;
  final SocketStatus socketStatus;

  /// Set once the session starts, so the screen can move to the play route.
  final bool started;

  /// Set when the host or the deadline ends the session before it starts.
  final String? finishedMessage;

  /// Participants still in the room (the backend keeps rows of people who left).
  List<SessionParticipant> get present => participants.where((p) => p.status.isPresent).toList();

  /// How many of the present participants are marked ready.
  int get readyCount => present.where((p) => p.status == ParticipantStatus.ready).length;

  LobbyState copyWith({
    SessionInfo? info,
    List<SessionParticipant>? participants,
    SocketStatus? socketStatus,
    bool? started,
    String? finishedMessage,
  }) =>
      LobbyState(
        info: info ?? this.info,
        participants: participants ?? this.participants,
        socketStatus: socketStatus ?? this.socketStatus,
        started: started ?? this.started,
        finishedMessage: finishedMessage ?? this.finishedMessage,
      );
}

/// Waiting room: loads the session, then tracks it over the room socket.
///
/// Connecting to `/ws/quiz/sessions/{id}` is what marks the student "ready"
/// server-side, so there is deliberately no ready button.
class LobbyController extends AutoDisposeFamilyAsyncNotifier<LobbyState, int> {
  SocketService? _socket;
  StreamSubscription<Json>? _messages;
  StreamSubscription<SocketStatus>? _status;

  @override
  Future<LobbyState> build(int arg) async {
    ref.onDispose(() {
      _messages?.cancel();
      _status?.cancel();
      _socket?.close();
    });

    final repo = ref.read(competitionRepositoryProvider);
    final info = await repo.fetchInfo(arg);
    final participants = await repo.fetchParticipants(arg);

    _connect();

    return LobbyState(
      info: info,
      participants: participants,
      // A session that is already running should send the student straight in.
      started: info.status.toLowerCase() == 'running',
    );
  }

  /// True when the signed-in student hosts this session.
  bool get isHost => state.value?.info.hostId == ref.read(authControllerProvider).user?.id;

  /// The host may start only with at least one other participant present.
  ///
  /// The backend itself accepts a solo start (the host counts as a participant),
  /// which would produce a "competition" of one. See `docs/OPEN_QUESTIONS.md` Q2.
  bool get canStart => isHost && (state.value?.present.length ?? 0) >= 2;

  void _connect() {
    final socket = ref.read(socketFactoryProvider).create(
      '/ws/quiz/sessions/$arg',
      heartbeat: const {'event': 'ping'},
    );
    _socket = socket;
    _messages = socket.messages.listen(_onEvent);
    _status = socket.statusChanges.listen((s) {
      final current = state.value;
      if (current != null) state = AsyncData(current.copyWith(socketStatus: s));
    });
    socket.connect();
  }

  void _onEvent(Json frame) {
    final current = state.value;
    if (current == null) return;

    final data = frame['data'] is Map
        ? Map<String, dynamic>.from(frame['data'] as Map)
        : const <String, dynamic>{};

    switch (RoomEvent.parse(asString(frame['event']))) {
      case RoomEvent.participantJoined:
        state = AsyncData(current.copyWith(
          participants: _upsert(current.participants, SessionParticipant.fromJoinedEvent(data)),
        ));
      case RoomEvent.participantReady:
        state = AsyncData(current.copyWith(
          participants: _setStatus(current.participants, data, ParticipantStatus.ready),
        ));
      case RoomEvent.participantReconnected:
        state = AsyncData(current.copyWith(
          participants: _setStatus(current.participants, data, ParticipantStatus.ready),
        ));
      case RoomEvent.participantDisconnected:
        state = AsyncData(current.copyWith(
          participants: _setStatus(current.participants, data, ParticipantStatus.disconnected),
        ));
      case RoomEvent.sessionStarted:
        state = AsyncData(current.copyWith(started: true));
      case RoomEvent.sessionFinished:
        state = AsyncData(current.copyWith(
          finishedMessage: 'Sessiya yakunlandi.',
        ));
      case RoomEvent.unknown:
        // `chat_message` is out of scope, and `ping` answers arrive with a
        // spurious `error` frame that must be ignored.
        break;
    }
  }

  /// Replaces a participant by id, or appends when they are new.
  List<SessionParticipant> _upsert(List<SessionParticipant> list, SessionParticipant incoming) {
    final index = list.indexWhere((p) => p.userId == incoming.userId);
    if (index < 0) return [...list, incoming];
    return [...list]..[index] = incoming;
  }

  /// Applies a status change addressed by `user_id`.
  List<SessionParticipant> _setStatus(
    List<SessionParticipant> list,
    Json data,
    ParticipantStatus status,
  ) {
    final userId = asInt(data['user_id']);
    if (userId == null) return list;
    final index = list.indexWhere((p) => p.userId == userId);
    if (index < 0) return list;
    return [...list]..[index] = list[index].copyWith(status: status);
  }

  /// Re-reads the session and its participants (pull to refresh).
  Future<void> refresh() async {
    final repo = ref.read(competitionRepositoryProvider);
    final info = await repo.fetchInfo(arg);
    final participants = await repo.fetchParticipants(arg);
    final current = state.value;
    state = AsyncData(
      (current ?? LobbyState(info: info, participants: participants)).copyWith(
        info: info,
        participants: participants,
        started: info.status.toLowerCase() == 'running',
      ),
    );
  }

  /// Reconnects the room socket when the app returns to the foreground.
  Future<void> resumeSocket() async => _socket?.reconnectNow();

  /// Host only: starts the session for everyone.
  Future<void> start() async {
    await ref.read(competitionRepositoryProvider).start(arg);
    // `session_started` also arrives over the socket; setting it here keeps the
    // host moving even if the frame is lost.
    final current = state.value;
    if (current != null) state = AsyncData(current.copyWith(started: true));
  }

  /// Leaves the room. The row stays server-side, marked `disconnected`.
  Future<void> leave() async {
    final participantId = state.value?.info.currentParticipantId;
    if (participantId == null) return;
    await ref
        .read(competitionRepositoryProvider)
        .leave(sessionId: arg, participantId: participantId);
  }

  /// Invites a contact by user id.
  Future<void> invite(int userId) async {
    final info = state.value?.info;
    if (info == null) return;
    await ref.read(competitionRepositoryProvider).invite(
          sessionId: arg,
          joinCode: info.joinCode,
          recipientId: userId,
        );
  }
}

/// Waiting room state for one session.
final lobbyControllerProvider =
    AsyncNotifierProvider.autoDispose.family<LobbyController, LobbyState, int>(
  LobbyController.new,
);
