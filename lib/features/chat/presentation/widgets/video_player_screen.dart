import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_colors.dart';

/// Plays a chat video inside the app.
///
/// Opened from a video bubble instead of handing the URL to a browser — the
/// file lives behind the API and a browser would either prompt a download or
/// lose the session.
Future<void> openVideoPlayer(BuildContext context, {required String url, String? title}) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => VideoPlayerScreen(url: url, title: title),
    ),
  );
}

/// Full-screen player with play/pause and a scrub bar.
class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({super.key, required this.url, this.title});

  final String url;
  final String? title;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
      await controller.play();
    } catch (_) {
      await controller.dispose();
      if (mounted) setState(() => _error = 'Videoni ochib bo\'lmadi');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final controller = _controller;
    if (controller == null) return;
    setState(() {
      controller.value.isPlaying ? controller.pause() : controller.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.title ?? 'Video',
          style: const TextStyle(fontSize: 15),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: switch ((controller, _error)) {
          (_, final String message) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 36),
                const SizedBox(height: 10),
                Text(message, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          (null, _) => const CircularProgressIndicator(color: Colors.white),
          (final VideoPlayerController ready, _) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AspectRatio(
                  aspectRatio: ready.value.aspectRatio == 0 ? 16 / 9 : ready.value.aspectRatio,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      VideoPlayer(ready),
                      GestureDetector(
                        onTap: _togglePlay,
                        child: AnimatedOpacity(
                          opacity: ready.value.isPlaying ? 0 : 1,
                          duration: const Duration(milliseconds: 150),
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              color: Color(0x8C020617),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: VideoProgressIndicator(
                    ready,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: AppColors.brand,
                      bufferedColor: Colors.white24,
                      backgroundColor: Colors.white12,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _togglePlay,
                  iconSize: 34,
                  color: Colors.white,
                  icon: Icon(
                    ready.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                ),
              ],
            ),
        },
      ),
    );
  }
}
