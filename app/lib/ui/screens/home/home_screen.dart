import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/channel.dart';
import '../../../providers/player_provider.dart';
import '../../../providers/playlist_provider.dart';
import '../../../providers/search_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../widgets/category_sidebar.dart';
import '../../widgets/channel_card.dart';
import '../../widgets/mini_player.dart';
import '../player/player_screen.dart';
import '../favorites/favorites_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final VideoController _videoController;
  final _searchController = TextEditingController();
  final FocusNode _rootFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final player = ref.read(playerProvider.notifier).player;
    _videoController = VideoController(player);

    // Fire TV: keep landscape only (no orientation unlock)
    // Orientation is locked to sensorLandscape in AndroidManifest
  }

  @override
  void dispose() {
    _searchController.dispose();
    _rootFocusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
    final channels = ref.read(filteredChannelsProvider);
    final notifier = ref.read(playerProvider.notifier);
    final hasChannel = ref.read(playerProvider).currentChannel != null;

    // Channel Up/Down: switch channels if playing
    if (hasChannel && key == LogicalKeyboardKey.channelUp) {
      notifier.playNextChannel(channels);
      return KeyEventResult.handled;
    }
    if (hasChannel && key == LogicalKeyboardKey.channelDown) {
      notifier.playPreviousChannel(channels);
      return KeyEventResult.handled;
    }

    // Media keys
    if (hasChannel &&
        (key == LogicalKeyboardKey.mediaPlayPause ||
            key == LogicalKeyboardKey.mediaPlay ||
            key == LogicalKeyboardKey.mediaPause)) {
      notifier.togglePlayPause();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  bool get _isDesktop =>
      MediaQuery.of(context).size.width >= AppConstants.desktopBreakpoint;

  void _openFullScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(videoController: _videoController),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final hasActiveChannel = playerState.currentChannel != null;

    if (_isDesktop) {
      return _buildDesktopLayout(hasActiveChannel);
    }
    return _buildMobileLayout(hasActiveChannel);
  }

  Widget _buildDesktopLayout(bool hasActiveChannel) {
    // 27px ~= 2.5% overscan safe zone at 1080p (Fire TV standard)
    const overscan = EdgeInsets.all(27.0);

    return Focus(
      focusNode: _rootFocusNode,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        body: Padding(
          padding: Platform.isAndroid ? overscan : EdgeInsets.zero,
          child: Row(
          children: [
            // Sidebar
            SizedBox(
              width: 240,
              child: FocusTraversalGroup(
                child: Column(
                  children: [
                    _buildSidebarHeader(),
                    const Expanded(child: CategorySidebar()),
                  ],
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            // Channel list (main focus area)
            Expanded(
              flex: 3,
              child: FocusTraversalGroup(
                child: Column(
                  children: [
                    _buildTopBar(),
                    Expanded(child: _buildChannelContent()),
                  ],
                ),
              ),
            ),
            // Player panel
            if (hasActiveChannel) ...[
              const VerticalDivider(width: 1),
              SizedBox(
                width: 420,
                child: FocusTraversalGroup(
                  child: _buildPlayerPanel(),
                ),
              ),
            ],
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(bool hasActiveChannel) {
    return Focus(
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => FavoritesScreen(videoController: _videoController)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Categorias',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const Expanded(child: CategorySidebar()),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildChannelContent()),
          if (hasActiveChannel)
            MiniPlayer(
              videoController: _videoController,
              onExpand: _openFullScreen,
            ),
        ],
      ),
    ),
    );
  }

  Widget _buildSidebarHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.live_tv, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            AppConstants.appName,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(child: _buildSearchBar()),
          const SizedBox(width: 8),
          _buildViewToggle(),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar playlist',
            onPressed: () => ref.read(playlistProvider.notifier).refresh(),
          ),
          if (_isDesktop) ...[
            IconButton(
              icon: const Icon(Icons.favorite),
              tooltip: 'Favoritos',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => FavoritesScreen(videoController: _videoController)),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Configurações',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Buscar canais...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    ref.read(searchQueryProvider.notifier).state = '';
                  },
                )
              : null,
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
        onChanged: (value) =>
            ref.read(searchQueryProvider.notifier).state = value,
      ),
    );
  }

  Widget _buildViewToggle() {
    final isGrid = ref.watch(gridViewProvider);
    return IconButton(
      icon: Icon(isGrid ? Icons.view_list : Icons.grid_view),
      tooltip: isGrid ? 'Modo lista' : 'Modo grade',
      onPressed: () {
        ref.read(gridViewProvider.notifier).state = !isGrid;
        ref.read(settingsRepositoryProvider).setGridView(!isGrid);
      },
    );
  }

  Widget _buildChannelContent() {
    final channels = ref.watch(filteredChannelsProvider);
    final isGrid = ref.watch(gridViewProvider);
    final playlistState = ref.watch(playlistProvider);

    return playlistState.when(
      loading: () => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Carregando playlist...'),
          ],
        ),
      ),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text('Erro ao carregar: $e'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => ref.read(playlistProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
      data: (_) {
        if (channels.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search_off, size: 48),
                SizedBox(height: 16),
                Text('Nenhum canal encontrado'),
              ],
            ),
          );
        }

        if (isGrid) {
          return _buildGrid(channels);
        }
        return _buildList(channels);
      },
    );
  }

  Widget _buildGrid(List<Channel> channels) {
    final crossAxisCount = _isDesktop ? 4 : 3;
    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 0.85,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: channels.length,
        itemBuilder: (_, i) => ChannelCard(channel: channels[i]),
      ),
    );
  }

  Widget _buildList(List<Channel> channels) {
    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: channels.length,
        itemBuilder: (_, i) => ChannelListTile(channel: channels[i]),
      ),
    );
  }

  Widget _buildPlayerPanel() {
    final playerState = ref.watch(playerProvider);
    final channel = playerState.currentChannel;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Video (tap to fullscreen, no controls to avoid focus trap)
        GestureDetector(
          onTap: _openFullScreen,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: ExcludeFocus(
              child: Video(
                controller: _videoController,
                controls: (state) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
        // Channel info + actions
        if (channel != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  channel.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  channel.group,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton.tonalIcon(
                      autofocus: true,
                      onPressed: _openFullScreen,
                      icon: const Icon(Icons.fullscreen),
                      label: const Text('Tela cheia'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.stop),
                      onPressed: () =>
                          ref.read(playerProvider.notifier).stop(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        // Status
        if (playerState.isBuffering)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Carregando...'),
              ],
            ),
          ),
        if (playerState.error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.error, color: colorScheme.error, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    playerState.error!,
                    style: TextStyle(color: colorScheme.error, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
