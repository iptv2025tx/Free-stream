import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/channel.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/player_provider.dart';
import 'channel_logo.dart';

class ChannelCard extends ConsumerStatefulWidget {
  final Channel channel;

  const ChannelCard({super.key, required this.channel});

  @override
  ConsumerState<ChannelCard> createState() => _ChannelCardState();
}

class _ChannelCardState extends ConsumerState<ChannelCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final isPlaying = playerState.currentChannel?.url == widget.channel.url;
    final isFav = ref.watch(favoritesProvider).valueOrNull?.any(
              (c) => c.url == widget.channel.url,
            ) ??
        false;
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedScale(
      scale: _isFocused ? 1.08 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: _isFocused
              ? Border.all(color: colorScheme.primary, width: 3)
              : null,
          boxShadow: _isFocused
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Card(
          margin: EdgeInsets.zero,
          color: isPlaying
              ? colorScheme.primaryContainer
              : _isFocused
                  ? colorScheme.surfaceContainerHigh
                  : colorScheme.surfaceContainerLow,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () =>
                ref.read(playerProvider.notifier).playChannel(widget.channel),
            onFocusChange: (focused) {
              setState(() => _isFocused = focused);
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    children: [
                      ChannelLogo(logoUrl: widget.channel.logoUrl, size: 56),
                      if (isPlaying)
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.play_arrow,
                              size: 14,
                              color: colorScheme.onPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.channel.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isPlaying || _isFocused
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isPlaying
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => ref
                        .read(favoritesProvider.notifier)
                        .toggle(widget.channel),
                    child: Icon(
                      isFav ? Icons.favorite : Icons.favorite_border,
                      size: 18,
                      color: isFav
                          ? colorScheme.error
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ChannelListTile extends ConsumerStatefulWidget {
  final Channel channel;

  const ChannelListTile({super.key, required this.channel});

  @override
  ConsumerState<ChannelListTile> createState() => _ChannelListTileState();
}

class _ChannelListTileState extends ConsumerState<ChannelListTile> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final isPlaying = playerState.currentChannel?.url == widget.channel.url;
    final isFav = ref.watch(favoritesProvider).valueOrNull?.any(
              (c) => c.url == widget.channel.url,
            ) ??
        false;
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        border: _isFocused
            ? Border.all(color: colorScheme.primary, width: 2)
            : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: ChannelLogo(logoUrl: widget.channel.logoUrl, size: 40),
        title: Text(
          widget.channel.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: isPlaying || _isFocused
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          widget.channel.group,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: IconButton(
          icon: Icon(
            isFav ? Icons.favorite : Icons.favorite_border,
            color: isFav ? colorScheme.error : null,
          ),
          onPressed: () =>
              ref.read(favoritesProvider.notifier).toggle(widget.channel),
        ),
        selected: isPlaying,
        selectedTileColor: colorScheme.primaryContainer,
        focusColor: colorScheme.surfaceContainerHigh,
        onTap: () =>
            ref.read(playerProvider.notifier).playChannel(widget.channel),
        onFocusChange: (focused) {
          setState(() => _isFocused = focused);
        },
      ),
    );
  }
}
