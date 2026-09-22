import 'dart:async';

import 'package:edunova_mobile/core/network/api_client.dart';
import 'package:edunova_mobile/core/realtime/socket_service.dart';
import 'package:edunova_mobile/core/storage/token_storage.dart';
import 'package:edunova_mobile/features/auth/domain/auth_user.dart';
import 'package:edunova_mobile/features/auth/presentation/auth_controller.dart';
import 'package:edunova_mobile/features/chat/data/chat_repository.dart';
import 'package:edunova_mobile/features/chat/data/chat_socket.dart';
import 'package:edunova_mobile/features/chat/domain/chat_models.dart';
import 'package:edunova_mobile/features/chat/domain/message_models.dart';
import 'package:edunova_mobile/features/chat/presentation/chat_providers.dart';
import 'package:edunova_mobile/features/chat/presentation/chat_list_controller.dart';
import 'package:edunova_mobile/features/chat/presentation/chat_room_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _me = 1;
const _peer = 2;
const _chatId = 7;

/// A socket that never opens a connection: frames go in through [emit].
class _FakeSocket extends SocketService {
  _FakeSocket() : super(path: '/ws/chat', tokenProvider: _noToken);

  static Future<String?> _noToken() async => null;

  final _incoming = StreamController<Map<String, dynamic>>.broadcast();
  final sent = <Map<String, dynamic>>[];

  @override
  Stream<Map<String, dynamic>> get messages => _incoming.stream;

  @override
  Future<void> connect() async {}

  @override
  bool send(Map<String, dynamic> message) {
    sent.add(message);
    return true;
  }

  void emit(Map<String, dynamic> frame) => _incoming.add(frame);
}

class _FakeChatRepository extends ChatRepository {
  _FakeChatRepository()
      : super(ApiClient(tokenStorage: TokenStorage(), onSessionExpired: () {}));

  @override
  Future<List<ChatListItem>> fetchChats({int limit = 30, int offset = 0}) async => const [];

  @override
  Future<ChatDetail> fetchChatDetail(int chatId) async => ChatDetail.fromJson({
        'id': chatId,
        'name': 'Doston',
        'type': 'private',
        'owner_id': _me,
        'members_count': 2,
        'members': [
          {'user_id': _me, 'username': 'me', 'role': 'member', 'is_online': true},
          {'user_id': _peer, 'username': 'doston', 'role': 'member', 'is_online': true},
        ],
      });

  @override
  Future<List<Message>> fetchHistory(
    int chatId, {
    int limit = 30,
    String? beforeId,
  }) async =>
      const [];

  @override
  Future<void> markAsRead(List<String> messageIds) async {}
}

class _FakeAuth extends AuthController {
  @override
  AuthState build() => const AuthState.authenticated(
        AuthUser(id: _me, username: 'me', firstName: 'Me', lastName: 'User'),
      );
}

Map<String, dynamic> _typingFrame() => {
      'type': 'typing:update',
      // The server injects the chat id from the `chat:{id}` channel name, so it
      // arrives as a string.
      'chat_id': '$_chatId',
      'sender_id': _peer,
      'is_typing': true,
    };

Map<String, dynamic> _messageFrame(String id) => {
      'type': 'message:new',
      'chat_id': _chatId,
      'message': {
        'sender_id': _peer,
        'sender_name': 'Doston',
        'content': 'salom',
        'message_id': id,
        'created_at': '2026-09-17T10:00:00+00:00',
        'attachments': <dynamic>[],
        'mentions': <dynamic>[],
      },
    };

void main() {
  late _FakeSocket socket;
  late ProviderContainer container;

  Future<void> boot(WidgetTester tester) async {
    socket = _FakeSocket();
    container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_FakeAuth.new),
        chatRepositoryProvider.overrideWithValue(_FakeChatRepository()),
        chatSocketProvider.overrideWithValue(ChatSocket(socket)..start()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(chatRoomProvider(_chatId).future);
    await tester.pump();
  }

  Set<int> typingUsers() => container.read(chatRoomProvider(_chatId)).value!.typingUserIds;
  Set<int> typingChats() => container.read(chatListProvider).value!.typingChatIds;

  group('the room indicator', () {
    testWidgets('appears when the peer types', (tester) async {
      await boot(tester);

      socket.emit(_typingFrame());
      await tester.pump();

      expect(typingUsers(), {_peer});

      // Let the linger expire so no timer outlives the test.
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('goes away after 4 s of silence', (tester) async {
      await boot(tester);

      socket.emit(_typingFrame());
      await tester.pump();
      expect(typingUsers(), {_peer});

      // Still typing three seconds in: the frames keep it up.
      await tester.pump(const Duration(seconds: 3));
      expect(typingUsers(), {_peer});

      await tester.pump(const Duration(seconds: 2));
      expect(typingUsers(), isEmpty);
    });

    testWidgets('a further frame extends it rather than restarting the clock', (tester) async {
      await boot(tester);

      socket.emit(_typingFrame());
      await tester.pump(const Duration(seconds: 3));
      socket.emit(_typingFrame());
      await tester.pump(const Duration(seconds: 3));

      // Six seconds after the first frame, three after the last: still typing.
      expect(typingUsers(), {_peer});

      await tester.pump(const Duration(seconds: 2));
      expect(typingUsers(), isEmpty);
    });

    testWidgets('the delivered message takes it down for good', (tester) async {
      // The regression: the message handler wrote a state snapshot taken
      // before the indicator was cleared, putting it back with its linger
      // timer already cancelled — so it stayed up forever.
      await boot(tester);

      socket.emit(_typingFrame());
      await tester.pump();
      socket.emit(_messageFrame('6aa7cb62904f14acc2e98b4b'));
      await tester.pump();

      expect(typingUsers(), isEmpty);

      await tester.pump(const Duration(seconds: 10));
      expect(typingUsers(), isEmpty);
    });
  });

  group('the list row', () {
    testWidgets('stops saying "yozmoqda" after 4 s', (tester) async {
      await boot(tester);
      await container.read(chatListProvider.future);

      socket.emit(_typingFrame());
      await tester.pump();
      expect(typingChats(), {_chatId});

      await tester.pump(const Duration(seconds: 5));
      expect(typingChats(), isEmpty);
    });

    testWidgets('and after a message arrives', (tester) async {
      await boot(tester);
      await container.read(chatListProvider.future);

      socket.emit(_typingFrame());
      await tester.pump();
      socket.emit(_messageFrame('6aa7cb62904f14acc2e98b4c'));
      await tester.pump(const Duration(seconds: 10));

      expect(typingChats(), isEmpty);
    });
  });
}
