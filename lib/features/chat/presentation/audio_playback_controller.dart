import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

/// Which clip is loaded and whether it is running.
///
/// Deliberately free of the playhead: the position ticks many times a second
/// and would rebuild every bubble in the thread. Widgets read
/// [AudioPlaybackController.positionStream] instead, and only while they are
/// the active clip.
class AudioPlaybackState {
  const AudioPlaybackState({this.url, this.playing = false, this.loading = false});

  /// Currently loaded clip, or `null` when nothing has been played yet.
  final String? url;
  final bool playing;
  final bool loading;

  bool isActive(String candidate) => url == candidate;

  AudioPlaybackState copyWith({String? url, bool? playing, bool? loading}) => AudioPlaybackState(
        url: url ?? this.url,
        playing: playing ?? this.playing,
        loading: loading ?? this.loading,
      );
}

/// One shared audio player for the whole chat.
///
/// Voice notes and music behave like every other messenger: starting one stops
/// the previous, and a single player keeps memory flat no matter how long the
/// thread is.
class AudioPlaybackController extends Notifier<AudioPlaybackState> {
  late final AudioPlayer _player;
  StreamSubscription<PlayerState>? _stateSub;

  @override
  AudioPlaybackState build() {
    _player = AudioPlayer();
    _stateSub = _player.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        // Rewind so the next tap starts from the beginning.
        _player.seek(Duration.zero);
        _player.pause();
        state = state.copyWith(playing: false, loading: false);
        return;
      }
      state = state.copyWith(
        playing: playerState.playing,
        loading: playerState.processingState == ProcessingState.loading ||
            playerState.processingState == ProcessingState.buffering,
      );
    });

    ref.onDispose(() {
      _stateSub?.cancel();
      _player.dispose();
    });
    return const AudioPlaybackState();
  }

  /// Playhead of the active clip.
  Stream<Duration> get positionStream => _player.positionStream;

  /// Length of the active clip once it is loaded.
  Duration? get duration => _player.duration;

  /// Starts [url], or pauses/resumes it when it is already the active clip.
  Future<void> toggle(String url) async {
    if (state.isActive(url)) {
      if (_player.playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
      return;
    }

    state = AudioPlaybackState(url: url, loading: true);
    try {
      await _player.setUrl(url);
      await _player.play();
    } catch (_) {
      // A missing or unplayable file must not take the thread down; the bubble
      // simply falls back to its idle state.
      state = const AudioPlaybackState();
    }
  }

  /// Moves the playhead of the active clip.
  Future<void> seek(Duration position) => _player.seek(position);

  /// Stops playback, e.g. when leaving the room.
  Future<void> stop() async {
    await _player.pause();
    state = state.copyWith(playing: false);
  }
}

/// Shared chat audio player.
final audioPlaybackProvider =
    NotifierProvider<AudioPlaybackController, AudioPlaybackState>(AudioPlaybackController.new);
