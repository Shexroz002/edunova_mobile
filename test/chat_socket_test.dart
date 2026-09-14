import 'package:edunova_mobile/features/chat/data/chat_socket.dart';
import 'package:edunova_mobile/features/chat/domain/message_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Frame decoding for `/ws/chat`.
///
/// Every payload here is the shape the backend really publishes (checked
/// against `app/services/chat/real_time_event_service.py` and a live socket),
/// which is **not** the Mongo document shape — that difference is exactly what
/// these tests pin down.
void main() {
  group('message:new', () {
    test('reads the text from `content` and the id from `message_id`', () {
      final event = decodeChatFrame({
        'type': 'message:new',
        'chat_id': 1,
        'message': {
          'id': null,
          'sender_id': 2,
          'sender_name': 'User 2',
          'reply_to_message_id': null,
          'attachments': <dynamic>[],
          'mentions': <dynamic>[],
          'content': 'salom',
          'message_id': '6aa7cb62904f14acc2e98b4b',
          'created_at': '2026-09-14T10:24:34.959858+00:00',
        },
      });

      expect(event, isA<MessageNewEvent>());
      final message = (event! as MessageNewEvent).message;
      expect(message.id, '6aa7cb62904f14acc2e98b4b');
      expect(message.text, 'salom');
      expect(message.senderId, 2);
      expect(message.chatId, 1);
    });

    test('carries attachments in their stored shape', () {
      final event = decodeChatFrame({
        'type': 'message:new',
        'chat_id': 4,
        'message': {
          'sender_id': 1,
          'content': null,
          'message_id': 'abc',
          'created_at': '2026-09-14T10:00:00+00:00',
          'attachments': [
            {
              'type': 'voice',
              'file_name': 'voice-1.webm',
              'file_url': '/media/uploads/x.webm',
              'mime_type': 'audio/webm',
              'size': 78663,
            }
          ],
        },
      });

      final message = (event! as MessageNewEvent).message;
      expect(message.attachments, hasLength(1));
      expect(message.attachments.single.kind, AttachmentKind.voice);
      expect(message.attachments.single.readableSize, '77 KB');
    });

    test('a forward decodes as a new message and keeps its origin', () {
      final event = decodeChatFrame({
        'type': 'message:forward',
        'chat_id': 3,
        'message': {
          'sender_id': 7,
          'content': 'uzatilgan matn',
          'message_id': 'fwd1',
          'created_at': '2026-09-14T10:00:00+00:00',
          'forwarded_from': {'sender_name': 'Aziz', 'sender_id': 9, 'chat_id': 1},
        },
      });

      final message = (event! as MessageNewEvent).message;
      expect(message.forwardedFrom?.label, 'Aziz');
    });
  });

  test('message:ack carries the server id and echoes our client id', () {
    final event = decodeChatFrame({
      'type': 'message:ack',
      'chat_id': 1,
      'message_id': '6aa7cf0fd7c24aa28862723d',
      'created_at': '2026-09-14T10:24:34.959858+00:00',
      'client_message_id': 'local-42',
    });

    expect(event, isA<MessageAckEvent>());
    final ack = event! as MessageAckEvent;
    expect(ack.messageId, '6aa7cf0fd7c24aa28862723d');
    expect(ack.clientMessageId, 'local-42');
    expect(ack.chatId, 1);
  });

  test('message:edited reads `new_content` under `message.id`', () {
    final event = decodeChatFrame({
      'type': 'message:edited',
      'chat_id': 1,
      'message': {
        'id': 'm1',
        'sender_id': 2,
        'new_content': 'tuzatildi',
        'edited_at': '2026-09-14T10:30:00+00:00',
      },
    });

    final edited = event! as MessageEditedEvent;
    expect(edited.messageId, 'm1');
    expect(edited.newContent, 'tuzatildi');
  });

  test('message:deleted brings the chat preview along', () {
    final event = decodeChatFrame({
      'type': 'message:deleted',
      'chat_id': 1,
      'message': {'id': 'm2', 'sender_id': 2},
      'chat_preview': {
        'last_message_text': 'oldingi xabar',
        'last_message_at': '2026-09-14T09:00:00+00:00',
      },
    });

    final deleted = event! as MessageDeletedEvent;
    expect(deleted.messageId, 'm2');
    expect(deleted.previewText, 'oldingi xabar');
  });

  test('message:reaction_add says who reacted and whether it was added', () {
    final event = decodeChatFrame({
      'type': 'message:reaction_add',
      'chat_id': 1,
      'message': {'message_id': 'm3', 'emoji': '❤️', 'added': false, 'sender_id': 5},
    });

    final reaction = event! as MessageReactionEvent;
    expect(reaction.messageId, 'm3');
    expect(reaction.emoji, '❤️');
    expect(reaction.added, isFalse);
    expect(reaction.userId, 5);
  });

  test('message:read sends ONE id under the plural `message_ids`', () {
    final event = decodeChatFrame({
      'type': 'message:read',
      'chat_id': 1,
      'message_ids': '6aa0eb652b2d3b2b16730859',
      'reader_id': 2,
      'read_at': '2026-09-14T10:40:00+00:00',
    });

    final read = event! as MessageReadEvent;
    expect(read.messageId, '6aa0eb652b2d3b2b16730859');
    expect(read.readerId, 2);
  });

  test('typing:update gets its chat id from the channel name, as a string', () {
    // `_build_event` fills `chat_id` from `chat:<id>`, so it is not an int.
    final event = decodeChatFrame({
      'type': 'typing:update',
      'chat_id': '12',
      'sender_id': 3,
      'is_typing': true,
    });

    final typing = event! as TypingEvent;
    expect(typing.chatId, 12);
    expect(typing.userId, 3);
  });

  test('presence:update maps status onto a boolean', () {
    final online = decodeChatFrame({
      'type': 'presence:update',
      'user_id': 4,
      'status': 'online',
      'last_seen_at': null,
    })! as PresenceEvent;
    expect(online.online, isTrue);

    final offline = decodeChatFrame({
      'type': 'presence:update',
      'user_id': 4,
      'status': 'offline',
      'last_seen_at': '2026-09-14T10:50:08.439426+00:00',
    })! as PresenceEvent;
    expect(offline.online, isFalse);
    expect(offline.lastSeenAt, isNotNull);
  });

  test('error frames name the client frame that was refused', () {
    final event = decodeChatFrame({
      'type': 'error',
      'event': 'message:new',
      'detail': "Siz bu chat a'zosi emassiz",
    });

    final error = event! as ChatErrorEvent;
    expect(error.forEvent, 'message:new');
    expect(error.detail, "Siz bu chat a'zosi emassiz");
  });

  test('connection:ready carries this connection origin', () {
    final event = decodeChatFrame({
      'type': 'connection:ready',
      'subscribed_channels': 6,
      'origin': '4193ba9f',
    })! as ConnectionReadyEvent;

    expect(event.origin, '4193ba9f');
    expect(event.channels, 6);
  });

  test('unknown and malformed frames are ignored, not thrown', () {
    expect(decodeChatFrame({'type': 'chat:updated'}), isNull);
    expect(decodeChatFrame({'type': 'message:new'}), isNull);
    expect(decodeChatFrame({'type': 'message:edited', 'message': <String, dynamic>{}}), isNull);
    expect(decodeChatFrame(<String, dynamic>{}), isNull);
  });
}
