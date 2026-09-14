import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

/// Which round video message is loaded, and whether it is running.
class RoundVideoState {
  const RoundVideoState({this.url, this.playing = false, this.loading = false});

  /// Currently loaded clip, or `null` when none has been opened.
  final String? url;
  final bool playing;
  final bool loading;

  bool isActive(String candidate) => url == candidate;

  RoundVideoState copyWith({String? url, bool? playing, bool? loading}) => RoundVideoState(
        url: url ?? this.url,
        playing: playing ?? this.playing,
        loading: loading ?? this.loading,
      );
}

/// One shared player for round video messages, played in place in the thread.
///
/// A controller per bubble would hold a decoder open for every clip in the
/// history, so only the tapped one is ever initialised — starting another
/// releases the previous, exactly as a messenger behaves.
class RoundVideoController extends Notifier<RoundVideoState> {
  VideoPlayerController? _player;

  /// The live player of the active clip; `null` while nothing is loaded.
  VideoPlayerController? get player => _player;

  @override
  RoundVideoState build() {
    ref.onDispose(_release);
    return const RoundVideoState();
  }

  /// Starts [url], or pauses/resumes it when it is already the active clip.
  Future<void> toggle(String url) async {
    final current = _player;
    if (state.isActive(url) && current != null) {
      if (current.value.isPlaying) {
        await current.pause();
      } else {
        await current.play();
      }
      state = state.copyWith(playing: current.value.isPlaying);
      return;
    }

    await _release();
    state = RoundVideoState(url: url, loading: true);

    final player = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await player.initialize();
      _player = player;
      player.addListener(_onTick);
      await player.setLooping(false);
      await player.play();
      state = RoundVideoState(url: url, playing: true);
    } catch (_) {
      await player.dispose();
      // An unplayable clip must not break the thread; the bubble falls back to
      // its poster and the user can try again.
      state = const RoundVideoState();
    }
  }

  void _onTick() {
    final player = _player;
    if (player == null) return;
    final value = player.value;
    if (value.position >= value.duration && value.duration > Duration.zero) {
      player.seekTo(Duration.zero);
      player.pause();
      state = state.copyWith(playing: false);
      return;
    }
    if (value.isPlaying != state.playing) {
      state = state.copyWith(playing: value.isPlaying);
    }
  }

  /// Stops and releases the player, e.g. when leaving the room.
  Future<void> stop() async {
    await _release();
    state = const RoundVideoState();
  }

  Future<void> _release() async {
    final player = _player;
    _player = null;
    if (player == null) return;
    player.removeListener(_onTick);
    await player.dispose();
  }
}

/// Shared player for round video messages.
final roundVideoProvider =
    NotifierProvider<RoundVideoController, RoundVideoState>(RoundVideoController.new);
