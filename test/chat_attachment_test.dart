import 'package:edunova_mobile/features/chat/data/chat_repository.dart';
import 'package:edunova_mobile/features/chat/domain/message_models.dart';
import 'package:edunova_mobile/features/chat/presentation/widgets/chat_composer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Attachment typing rules.
///
/// The upload endpoint validates `content-type` against its own allow-list, so
/// a wrong mapping here is rejected by the server rather than silently stored.
void main() {
  group('mimeTypeForPath', () {
    test('maps a recorded voice note onto an accepted type', () {
      // `record` writes AAC into an m4a container.
      expect(mimeTypeForPath('/tmp/voice-1789.m4a'), 'audio/mp4');
      expect(mimeTypeForPath('/tmp/clip.aac'), 'audio/mp4');
    });

    test('maps the video containers the camera and gallery produce', () {
      expect(mimeTypeForPath('/tmp/VID_001.mp4'), 'video/mp4');
      expect(mimeTypeForPath('/tmp/clip.mov'), 'video/quicktime');
      expect(mimeTypeForPath('/tmp/clip.webm'), 'video/webm');
    });

    test('is case insensitive, as gallery files often are upper case', () {
      expect(mimeTypeForPath('/tmp/IMG_0001.JPG'), 'image/jpeg');
      expect(mimeTypeForPath('/tmp/VID_0001.MP4'), 'video/mp4');
    });

    test('returns null for a type the server would refuse', () {
      expect(mimeTypeForPath('/tmp/drawing.svg'), isNull);
      expect(mimeTypeForPath('/tmp/page.html'), isNull);
      expect(mimeTypeForPath('/tmp/app.apk'), isNull);
    });

    test('every mapped type is one the upload endpoint accepts', () {
      const extensions = [
        'jpg', 'jpeg', 'png', 'gif', 'webp', 'pdf', 'doc', 'docx', 'xls', 'xlsx',
        'ppt', 'pptx', 'txt', 'csv', 'mp3', 'ogg', 'wav', 'm4a', 'aac', 'mp4',
        'webm', 'mov', 'zip', '7z', 'rar',
      ];
      for (final extension in extensions) {
        final mime = mimeTypeForPath('file.$extension');
        expect(mime, isNotNull, reason: '.$extension has no mapping');
        expect(
          ChatLimits.allowedMimeTypes,
          contains(mime),
          reason: '.$extension maps to $mime, which the server rejects',
        );
      }
    });
  });

  group('attachmentKindFor', () {
    test('derives a kind from the mime type', () {
      expect(attachmentKindFor('image/png'), AttachmentKind.image);
      expect(attachmentKindFor('video/mp4'), AttachmentKind.video);
      expect(attachmentKindFor('audio/mp4'), AttachmentKind.audio);
      expect(attachmentKindFor('application/pdf'), AttachmentKind.pdf);
      expect(attachmentKindFor('application/zip'), AttachmentKind.file);
    });
  });

  group('MessageAttachment', () {
    test('serialises video_message back to its snake_case type', () {
      const attachment = MessageAttachment(
        kind: AttachmentKind.videoMessage,
        fileName: 'round.mp4',
        fileUrl: '/media/uploads/round.mp4',
      );
      expect(attachment.toJson()['type'], 'video_message');
    });

    test('a recorded note round-trips as `voice`, not `audio`', () {
      const attachment = MessageAttachment(
        kind: AttachmentKind.voice,
        fileName: 'voice-1.m4a',
        fileUrl: '/media/uploads/voice-1.m4a',
        mimeType: 'audio/mp4',
      );
      final json = attachment.toJson();
      expect(json['type'], 'voice');
      expect(MessageAttachment.fromJson(json).kind, AttachmentKind.voice);
    });

    test('voice and audio both render as audio, video kinds as visual', () {
      expect(AttachmentKind.voice.isAudio, isTrue);
      expect(AttachmentKind.audio.isAudio, isTrue);
      expect(AttachmentKind.video.isVisual, isTrue);
      expect(AttachmentKind.videoMessage.isVisual, isTrue);
      expect(AttachmentKind.pdf.isVisual, isFalse);
    });
  });
}
