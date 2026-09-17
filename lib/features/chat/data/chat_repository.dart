import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/chat_models.dart';
import '../domain/message_models.dart';

/// Limits mirrored from the backend so the app fails fast and in Uzbek.
class ChatLimits {
  ChatLimits._();

  /// `settings.MAX_CHAT_FILE_SIZE`.
  static const maxFileBytes = 50 * 1024 * 1024;

  /// `ALLOWED_CONTENT_TYPES` in `app/services/chat/attachment_service.py`.
  /// SVG and HTML are deliberately absent on the server.
  static const allowedMimeTypes = <String>{
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'text/plain',
    'text/csv',
    'audio/mpeg',
    'audio/ogg',
    'audio/wav',
    'audio/mp4',
    'video/mp4',
    'video/webm',
    'video/quicktime',
    'application/zip',
    'application/x-7z-compressed',
    'application/vnd.rar',
  };
}

/// HTTP side of chat: lists, history, metadata and uploads.
///
/// Sending, editing, deleting and reacting go through `/ws/chat` instead —
/// a message written over HTTP is stored but never broadcast, so the other
/// member would not see it until a reload.
class ChatRepository {
  ChatRepository(this._api);

  final ApiClient _api;

  /// Chat list with presence, unread counts and the last-message preview.
  Future<List<ChatListItem>> fetchChats({int limit = 30, int offset = 0}) async {
    final data = await _api.get('/chats', query: {'limit': limit, 'offset': offset}) as Json;
    return asJsonList(data['items']).map(ChatListItem.fromJson).toList();
  }

  /// Chat metadata plus members. `404` also means "you are not a member".
  Future<ChatDetail> fetchChatDetail(int chatId) async {
    final data = await _api.get('/chats/$chatId') as Json;
    return ChatDetail.fromJson(data);
  }

  /// Opens (or reuses) the private chat with [targetUserId].
  Future<ChatSummary> openPrivateChat(int targetUserId) async {
    final data = await _api.post(
      '/chats/private',
      data: {'target_user_id': targetUserId},
    ) as Json;
    return ChatSummary.fromJson(data);
  }

  /// Creates a group chat owned by the caller.
  Future<ChatSummary> createGroupChat({
    required String name,
    List<int> memberIds = const [],
    String? description,
  }) async {
    final data = await _api.post('/chats/group', data: {
      'name': name,
      if (description != null && description.isNotEmpty) 'description': description,
      'member_ids': memberIds,
    }) as Json;
    return ChatSummary.fromJson(data);
  }

  /// Leaves a group. Private chats cannot be left (the server returns 400).
  Future<void> leaveChat(int chatId) => _api.delete('/chats/$chatId/leave');

  /// One page of history, oldest first.
  ///
  /// [beforeId] pages backwards: pass the id of the oldest message on screen.
  Future<List<Message>> fetchHistory(
    int chatId, {
    int limit = 50,
    String? beforeId,
  }) async {
    final data = await _api.get(
      '/messages/chat/$chatId',
      query: {'limit': limit, if (beforeId != null) 'before_id': beforeId},
    );
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => Message.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Marks messages read server-side. The live receipt goes out over the
  /// socket; this keeps the unread count right after a cold start.
  Future<void> markAsRead(List<String> messageIds) async {
    if (messageIds.isEmpty) return;
    await _api.post('/messages/mark-as-read', data: {'message_ids': messageIds});
  }

  /// Bumps `views_count` for a message that scrolled into view.
  Future<void> markViewed(String messageId) => _api.post('/messages/$messageId/view');

  /// Uploads one attachment and returns it ready to hang on a message.
  ///
  /// The endpoint only echoes `{file_name, file_url, size}`, so the kind and
  /// mime type are decided here and sent along with the message.
  Future<MessageAttachment> uploadAttachment(
    File file, {
    required String mimeType,
    AttachmentKind? kind,
  }) async {
    final size = await file.length();
    if (size > ChatLimits.maxFileBytes) {
      throw const ApiException('Fayl hajmi 50 MB dan oshmasligi kerak');
    }
    if (!ChatLimits.allowedMimeTypes.contains(mimeType)) {
      throw const ApiException('Bu turdagi fayl qabul qilinmaydi');
    }

    final parts = mimeType.split('/');
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: file.uri.pathSegments.last,
        contentType: DioMediaType(parts.first, parts.length > 1 ? parts[1] : 'octet-stream'),
      ),
    });

    final data = await _api.post('/messages/files/upload', data: form) as Json;
    return MessageAttachment(
      // A recorded clip is a `voice` note and a captured clip a `video`; only
      // fall back to the mime type when the caller has no opinion.
      kind: kind ?? attachmentKindFor(mimeType),
      fileName: asString(data['file_name']) ?? file.uri.pathSegments.last,
      fileUrl: asString(data['file_url']) ?? '',
      mimeType: mimeType,
      size: asInt(data['size']) ?? size,
    );
  }
}

/// Maps a mime type onto the `type` string the chat stores.
AttachmentKind attachmentKindFor(String mimeType) {
  if (mimeType == 'application/pdf') return AttachmentKind.pdf;
  if (mimeType.startsWith('image/')) return AttachmentKind.image;
  if (mimeType.startsWith('video/')) return AttachmentKind.video;
  if (mimeType.startsWith('audio/')) return AttachmentKind.audio;
  return AttachmentKind.file;
}

/// Provides [ChatRepository].
final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(ref.watch(apiClientProvider)),
);
