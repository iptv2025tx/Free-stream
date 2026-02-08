import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import '../data/models/channel.dart';
import '../data/repositories/history_repository.dart';

final historyRepositoryProvider = Provider((ref) => HistoryRepository());

final playerProvider =
    NotifierProvider<PlayerNotifier, PlayerState>(PlayerNotifier.new);

class PlayerState {
  final Channel? currentChannel;
  final bool isPlaying;
  final bool isBuffering;
  final bool isFullScreen;
  final String? error;

  const PlayerState({
    this.currentChannel,
    this.isPlaying = false,
    this.isBuffering = false,
    this.isFullScreen = false,
    this.error,
  });

  PlayerState copyWith({
    Channel? currentChannel,
    bool? isPlaying,
    bool? isBuffering,
    bool? isFullScreen,
    String? error,
    bool clearError = false,
  }) {
    return PlayerState(
      currentChannel: currentChannel ?? this.currentChannel,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      isFullScreen: isFullScreen ?? this.isFullScreen,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class PlayerNotifier extends Notifier<PlayerState> {
  late final Player _player;

  Player get player => _player;

  @override
  PlayerState build() {
    final isAndroid = Platform.isAndroid;

    _player = Player(
      configuration: PlayerConfiguration(
        bufferSize: isAndroid ? 2 * 1024 * 1024 : 512 * 1024,
        logLevel: MPVLogLevel.warn,
      ),
    );

    // Platform-specific MPV options
    final mpv = _player.platform as dynamic;
    if (mpv != null) {
      try {
        mpv.setProperty('cache', 'yes');
        mpv.setProperty('cache-pause-initial', 'no');
        mpv.setProperty('network-timeout', '10');
        mpv.setProperty('force-seekable', 'yes');
        mpv.setProperty('stream-lavf-o',
            'reconnect=1,reconnect_streamed=1,reconnect_delay_max=3');

        if (isAndroid) {
          // Fire TV / Android TV: hardware decoding + tuned buffering
          mpv.setProperty('hwdec', 'mediacodec');
          mpv.setProperty('vo', 'gpu');
          mpv.setProperty('cache-secs', '5');
          mpv.setProperty('cache-pause-wait', '2');
          mpv.setProperty('demuxer-max-bytes', '4MiB');
          mpv.setProperty('demuxer-max-back-bytes', '1MiB');
          mpv.setProperty('demuxer-readahead-secs', '3');
          mpv.setProperty('vd-lavc-threads', '4');
        } else {
          // Desktop: aggressive low-latency settings
          mpv.setProperty('cache-secs', '1');
          mpv.setProperty('cache-pause-wait', '1');
          mpv.setProperty('demuxer-max-bytes', '512KiB');
          mpv.setProperty('demuxer-max-back-bytes', '0');
          mpv.setProperty('demuxer-readahead-secs', '1');
          mpv.setProperty('vd-lavc-threads', '4');
          mpv.setProperty('demuxer-lavf-o', 'fflags=+nobuffer+fastseek');
        }
      } catch (_) {
        // Platform may not support direct MPV properties
      }
    }

    _player.stream.playing.listen((playing) {
      state = state.copyWith(isPlaying: playing, clearError: true);
    });

    _player.stream.buffering.listen((buffering) {
      state = state.copyWith(isBuffering: buffering);
    });

    _player.stream.error.listen((error) {
      if (error.isNotEmpty) {
        state = state.copyWith(error: error, isPlaying: false);
      }
    });

    ref.onDispose(() {
      _player.dispose();
    });

    return const PlayerState();
  }

  Future<void> playChannel(Channel channel) async {
    // Stop current stream immediately before opening new one
    _player.stop();

    state = state.copyWith(
      currentChannel: channel,
      isBuffering: true,
      clearError: true,
    );

    try {
      // Open without waiting for previous stream cleanup
      _player.open(Media(channel.url));
      // Save to history (fire and forget)
      ref.read(historyRepositoryProvider).addToHistory(channel);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isBuffering: false);
    }
  }

  void stop() {
    _player.stop();
    state = state.copyWith(isPlaying: false, isBuffering: false);
  }

  void toggleFullScreen() {
    state = state.copyWith(isFullScreen: !state.isFullScreen);
  }

  void setVolume(double volume) {
    _player.setVolume(volume * 100);
  }

  void playNextChannel(List<Channel> channels) {
    if (channels.isEmpty || state.currentChannel == null) return;
    final currentIndex = channels.indexWhere(
      (ch) => ch.url == state.currentChannel!.url,
    );
    if (currentIndex < 0) return;
    final nextIndex = (currentIndex + 1) % channels.length;
    playChannel(channels[nextIndex]);
  }

  void playPreviousChannel(List<Channel> channels) {
    if (channels.isEmpty || state.currentChannel == null) return;
    final currentIndex = channels.indexWhere(
      (ch) => ch.url == state.currentChannel!.url,
    );
    if (currentIndex < 0) return;
    final prevIndex = (currentIndex - 1 + channels.length) % channels.length;
    playChannel(channels[prevIndex]);
  }

  void togglePlayPause() {
    _player.playOrPause();
  }
}
