import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/network/media_url.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/message_models.dart';
import '../audio_playback_controller.dart';
import '../round_video_controller.dart';
import 'video_player_screen.dart';

/// Renders one attachment inside a bubble.
///
/// Images open in a zoomable viewer, a round video message plays in place, a
/// normal video opens the in-app player and voice plays in the bubble. Only
/// documents are handed to the system — media used to be launched in a
/// browser, which dropped the session and left the file unplayable.
class AttachmentView extends StatelessWidget {
  const AttachmentView({super.key, required this.attachment, required this.outgoing});

  final MessageAttachment attachment;

  /// Our own bubble, which is indigo — the contents flip to white.
  final bool outgoing;

  static const _frameWidth = 214.0;

  @override
  Widget build(BuildContext context) {
    return switch (attachment.kind) {
      AttachmentKind.image => _Thumbnail(attachment: attachment, width: _frameWidth),
      AttachmentKind.videoMessage => _RoundVideo(attachment: attachment),
      AttachmentKind.video => _Thumbnail(attachment: attachment, width: _frameWidth, play: true),
      AttachmentKind.voice || AttachmentKind.audio => _AudioRow(
          attachment: attachment,
          outgoing: outgoing,
          width: _frameWidth,
        ),
      _ => _FileTile(attachment: attachment, outgoing: outgoing, width: _frameWidth),
    };
  }
}

/// Opens a document in the system's own viewer.
///
/// Only documents take this path: media stays in the app.
Future<void> _openDocument(BuildContext context, MessageAttachment attachment) async {
  final url = MediaUrl.resolve(attachment.fileUrl);
  final uri = url == null ? null : Uri.tryParse(url);
  if (uri == null) return;
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Faylni ochadigan dastur topilmadi')),
    );
  }
}

/// Framed image, or a video poster that opens the in-app player.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.attachment, required this.width, this.play = false});

  final MessageAttachment attachment;
  final double width;
  final bool play;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final url = MediaUrl.resolve(attachment.fileUrl);
    final size = width;
    const height = 142.0;

    final placeholder = Container(
      width: size,
      height: height,
      alignment: Alignment.center,
      color: c.bgInner,
      child: Icon(
        play ? Icons.videocam_rounded : Icons.image_outlined,
        size: 30,
        color: c.textMuted,
      ),
    );

    Widget child = url == null
        ? placeholder
        : Image.network(
            url,
            width: size,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => placeholder,
            loadingBuilder: (_, widget, progress) => progress == null ? widget : placeholder,
          );

    if (play) {
      // A video has no server-side poster, so the frame stays the placeholder
      // tint with the play affordance on top.
      child = Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(width: size, height: height, child: placeholder),
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(color: Color(0x8C020617), shape: BoxShape.circle),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: () {
        if (url == null) return;
        if (play) {
          openVideoPlayer(context, url: url, title: attachment.fileName);
        } else {
          _openImageViewer(context, url, attachment.fileName);
        }
      },
      child: ClipRRect(borderRadius: BorderRadius.circular(12), child: child),
    );
  }
}

/// Telegram-style round video message that plays in the bubble.
///
/// Only the tapped clip is initialised — see [RoundVideoController] — and the
/// ring around the circle tracks the playhead.
class _RoundVideo extends ConsumerWidget {
  const _RoundVideo({required this.attachment});

  final MessageAttachment attachment;

  static const _size = 170.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final url = MediaUrl.resolve(attachment.fileUrl);
    final state = ref.watch(roundVideoProvider);
    final controller = ref.read(roundVideoProvider.notifier);
    final active = url != null && state.isActive(url);
    final player = active ? controller.player : null;

    final poster = Container(
      width: _size,
      height: _size,
      alignment: Alignment.center,
      color: c.bgInner,
      child: state.loading && active
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(Icons.videocam_rounded, size: 30, color: c.textMuted),
    );

    return GestureDetector(
      onTap: url == null ? null : () => controller.toggle(url),
      child: SizedBox(
        width: _size,
        height: _size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipOval(
              child: SizedBox(
                width: _size,
                height: _size,
                child: player != null && player.value.isInitialized
                    // The source is a normal rectangle; cover the circle with it.
                    ? FittedBox(
                        fit: BoxFit.cover,
                        clipBehavior: Clip.hardEdge,
                        child: SizedBox(
                          width: player.value.size.width,
                          height: player.value.size.height,
                          child: VideoPlayer(player),
                        ),
                      )
                    : poster,
              ),
            ),
            if (player != null && player.value.isInitialized)
              // Repaints on the player's own ticks, so no other bubble rebuilds.
              AnimatedBuilder(
                animation: player,
                builder: (_, __) => CustomPaint(
                  size: const Size(_size, _size),
                  painter: _RingPainter(
                    progress: _progressOf(player),
                    color: c.accent,
                    track: c.border,
                  ),
                ),
              )
            else
              CustomPaint(
                size: const Size(_size, _size),
                painter: _RingPainter(progress: 0, color: c.accent, track: c.border),
              ),
            if (!(state.playing && active))
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: Color(0x8C020617),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
              ),
          ],
        ),
      ),
    );
  }

  static double _progressOf(VideoPlayerController player) {
    final total = player.value.duration.inMilliseconds;
    if (total <= 0) return 0;
    return (player.value.position.inMilliseconds / total).clamp(0.0, 1.0);
  }
}

/// Playhead ring drawn around a round video message.
class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.color, required this.track});

  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 3.0;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final base = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect, 0, 6.2831853, false, base);

    if (progress <= 0) return;
    final played = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -1.5707963, 6.2831853 * progress, false, played);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

/// Full-screen zoomable image, matching the quiz question viewer.
void _openImageViewer(BuildContext context, String url, String title) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(title, style: const TextStyle(fontSize: 15)),
        ),
        body: Center(
          child: InteractiveViewer(
            maxScale: 5,
            child: Image.network(url, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          ),
        ),
      ),
    ),
  );
}

/// Voice note / music row that plays in place.
///
/// The whole chat shares one player, so starting this clip stops any other.
class _AudioRow extends ConsumerWidget {
  const _AudioRow({required this.attachment, required this.outgoing, required this.width});

  final MessageAttachment attachment;
  final bool outgoing;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final url = MediaUrl.resolve(attachment.fileUrl);
    final playback = ref.watch(audioPlaybackProvider);
    final controller = ref.read(audioPlaybackProvider.notifier);
    final active = url != null && playback.isActive(url);

    final foreground = outgoing ? Colors.white : c.textPrimary;
    final wave = outgoing ? Colors.white : AppColors.brand;

    return SizedBox(
      width: width,
      child: Row(
        children: [
          GestureDetector(
            onTap: url == null ? null : () => controller.toggle(url),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: outgoing ? const Color(0x29FFFFFF) : AppColors.tint(AppColors.brand, 0x29),
                shape: BoxShape.circle,
              ),
              child: active && playback.loading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
                    )
                  : Icon(
                      active && playback.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 20,
                      color: foreground,
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: active
                // Only the playing clip subscribes to the playhead, so the rest
                // of the thread does not rebuild many times a second.
                ? StreamBuilder<Duration>(
                    stream: controller.positionStream,
                    builder: (_, snapshot) {
                      final total = controller.duration;
                      final position = snapshot.data ?? Duration.zero;
                      final progress = (total == null || total.inMilliseconds == 0)
                          ? 0.0
                          : (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
                      return _Waveform(
                        seed: attachment.fileName.hashCode,
                        color: wave,
                        progress: progress,
                      );
                    },
                  )
                : _Waveform(seed: attachment.fileName.hashCode, color: wave, progress: 0),
          ),
          const SizedBox(width: 8),
          _Duration(
            active: active,
            fallback: attachment.readableSize,
            color: outgoing ? const Color(0xB3FFFFFF) : c.textMuted,
          ),
        ],
      ),
    );
  }
}

/// Elapsed time while playing, file size when idle.
class _Duration extends ConsumerWidget {
  const _Duration({required this.active, required this.fallback, required this.color});

  final bool active;
  final String fallback;
  final Color color;

  static String _clock(Duration value) {
    final minutes = value.inMinutes;
    final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = TextStyle(fontSize: 11.5, color: color);
    if (!active) return Text(fallback, style: style);

    return StreamBuilder<Duration>(
      stream: ref.read(audioPlaybackProvider.notifier).positionStream,
      builder: (_, snapshot) => Text(_clock(snapshot.data ?? Duration.zero), style: style),
    );
  }
}

/// Static bars with a played/unplayed split.
class _Waveform extends StatelessWidget {
  const _Waveform({required this.seed, required this.color, required this.progress});

  final int seed;
  final Color color;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 22),
      painter: _WaveformPainter(seed: seed, color: color, progress: progress),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({required this.seed, required this.color, required this.progress});

  final int seed;
  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const barWidth = 2.5;
    const gap = 2.5;
    final count = (size.width / (barWidth + gap)).floor();
    if (count <= 0) return;
    final played = (count * progress).round();

    var value = seed.abs() % 997 + 7;
    for (var i = 0; i < count; i++) {
      value = (value * 31 + 17) % 997;
      final height = 5 + (value % 14).toDouble();
      final x = i * (barWidth + gap) + barWidth / 2;
      final paint = Paint()
        ..color = color.withValues(alpha: i < played ? 1.0 : 0.35)
        ..strokeWidth = barWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(x, (size.height - height) / 2),
        Offset(x, (size.height + height) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) =>
      oldDelegate.seed != seed || oldDelegate.color != color || oldDelegate.progress != progress;
}

/// Document / archive row; the one kind that still opens outside the app.
class _FileTile extends StatelessWidget {
  const _FileTile({required this.attachment, required this.outgoing, required this.width});

  final MessageAttachment attachment;
  final bool outgoing;
  final double width;

  Color get _tint => switch (attachment.kind) {
        AttachmentKind.pdf => AppColors.error,
        _ => AppColors.violet,
      };

  IconData get _icon => switch (attachment.kind) {
        AttachmentKind.pdf => Icons.picture_as_pdf_rounded,
        _ => Icons.insert_drive_file_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tint = outgoing ? Colors.white : _tint;
    final subtitle = [
      attachment.kind == AttachmentKind.pdf ? 'PDF' : 'Fayl',
      if (attachment.readableSize.isNotEmpty) attachment.readableSize,
    ].join(' · ');

    return GestureDetector(
      onTap: () => _openDocument(context, attachment),
      child: SizedBox(
        width: width,
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: outgoing ? const Color(0x29FFFFFF) : AppColors.tint(_tint, 0x26),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: outgoing ? const Color(0x3DFFFFFF) : AppColors.tint(_tint, 0x59),
                ),
              ),
              child: Icon(_icon, size: 21, color: tint),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: outgoing ? Colors.white : c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: outgoing ? const Color(0xB3FFFFFF) : c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
