import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../data/models/channel.dart';
import '../../../providers/player_provider.dart';
import '../../../providers/search_provider.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final VideoController videoController;

  const PlayerScreen({super.key, required this.videoController});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  bool _showChannelName = true;
  Timer? _osdTimer;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _startOsdTimer();
  }

  @override
  void dispose() {
    _osdTimer?.cancel();
    _focusNode.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // Keep landscape on Fire TV (don't unlock to portrait)
    super.dispose();
  }

  void _startOsdTimer() {
    _osdTimer?.cancel();
    setState(() => _showChannelName = true);
    _osdTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showChannelName = false);
    });
  }

  void _showOsd() {
    _startOsdTimer();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
    final channels = ref.read(filteredChannelsProvider);
    final notifier = ref.read(playerProvider.notifier);

    // Channel Up: CH+ or Arrow Right
    if (key == LogicalKeyboardKey.channelUp ||
        key == LogicalKeyboardKey.arrowRight) {
      notifier.playNextChannel(channels);
      _showOsd();
      return KeyEventResult.handled;
    }

    // Channel Down: CH- or Arrow Left
    if (key == LogicalKeyboardKey.channelDown ||
        key == LogicalKeyboardKey.arrowLeft) {
      notifier.playPreviousChannel(channels);
      _showOsd();
      return KeyEventResult.handled;
    }

    // Play/Pause: Enter, Select, or media keys
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.mediaPlayPause ||
        key == LogicalKeyboardKey.mediaPlay ||
        key == LogicalKeyboardKey.mediaPause) {
      notifier.togglePlayPause();
      return KeyEventResult.handled;
    }

    // Back: exit fullscreen
    if (key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack ||
        key == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }

    // Media rewind/fast-forward: switch channels on Fire TV remote
    if (key == LogicalKeyboardKey.mediaRewind) {
      notifier.playPreviousChannel(channels);
      _showOsd();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaFastForward) {
      notifier.playNextChannel(channels);
      _showOsd();
      return KeyEventResult.handled;
    }

    // Arrow Up/Down: show OSD
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      _showOsd();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final channel = playerState.currentChannel;

    return PopScope(
      canPop: true,
      child: Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Stack(
          children: [
            // Video
            Center(
              child: Video(
                controller: widget.videoController,
                controls: NoVideoControls,
              ),
            ),
            // Channel name OSD (fades out after 2 seconds)
            if (channel != null)
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 24,
                child: AnimatedOpacity(
                  opacity: _showChannelName ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 500),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.live_tv, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          channel.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            shadows: [
                              Shadow(blurRadius: 4, color: Colors.black),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // Back button (hidden, shown on OSD)
            if (_showChannelName)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 16,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  opacity: _showChannelName ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 500),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildOsdHint(Icons.arrow_left, 'CH-'),
                      const SizedBox(width: 24),
                      _buildOsdHint(Icons.play_arrow, 'OK'),
                      const SizedBox(width: 24),
                      _buildOsdHint(Icons.arrow_right, 'CH+'),
                    ],
                  ),
                ),
              ),
            // Error overlay
            if (playerState.error != null)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.redAccent, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'Erro ao reproduzir',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        playerState.error!,
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () {
                          if (channel != null) {
                            ref
                                .read(playerProvider.notifier)
                                .playChannel(channel);
                          }
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildOsdHint(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

Widget NoVideoControls(VideoState state) {
  return const SizedBox.shrink();
}
