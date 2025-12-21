import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../../core/widgets/tv_sidebar.dart';
import '../../../core/widgets/category_card.dart';
import '../../../core/widgets/channel_card.dart';
import '../../../core/platform/platform_detector.dart';
import '../../../core/i18n/app_strings.dart';
import '../../channels/providers/channel_provider.dart';
import '../../playlist/providers/playlist_provider.dart';
import '../../favorites/providers/favorites_provider.dart';
import '../../player/providers/player_provider.dart';
import '../../../core/models/channel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedNavIndex = 0;
  List<Channel> _recommendedChannels = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 当从其他页面返回时，检查是否需要刷新推荐频道
    final channelProvider = context.read<ChannelProvider>();
    if (_recommendedChannels.isEmpty && channelProvider.channels.isNotEmpty) {
      _refreshRecommendedChannels();
    }
  }

  Future<void> _loadData() async {
    final playlistProvider = context.read<PlaylistProvider>();
    final channelProvider = context.read<ChannelProvider>();
    final favoritesProvider = context.read<FavoritesProvider>();

    if (playlistProvider.hasPlaylists) {
      final activePlaylist = playlistProvider.activePlaylist;
      if (activePlaylist != null && activePlaylist.id != null) {
        await channelProvider.loadChannels(activePlaylist.id!);
      } else {
        await channelProvider.loadAllChannels();
      }
      await favoritesProvider.loadFavorites();
      _refreshRecommendedChannels();
    }
  }

  void _refreshRecommendedChannels() {
    final channelProvider = context.read<ChannelProvider>();
    if (channelProvider.channels.length <= 7) {
      _recommendedChannels = channelProvider.channels;
    } else {
      final shuffled = List<Channel>.from(channelProvider.channels)..shuffle();
      _recommendedChannels = shuffled.take(7).toList();
    }
    setState(() {});
  }

  List<_NavItem> _getNavItems(BuildContext context) {
    final strings = AppStrings.of(context);
    return [
      _NavItem(icon: Icons.home_rounded, label: strings?.home ?? 'Home'),
      _NavItem(icon: Icons.live_tv_rounded, label: strings?.channels ?? 'Channels'),
      _NavItem(icon: Icons.favorite_rounded, label: strings?.favorites ?? 'Favorites'),
      _NavItem(icon: Icons.search_rounded, label: strings?.searchChannels ?? 'Search'),
      _NavItem(icon: Icons.settings_rounded, label: strings?.settings ?? 'Settings'),
    ];
  }

  void _onNavItemTap(int index) {
    if (index == 0) {
      setState(() => _selectedNavIndex = 0);
      return;
    }
    switch (index) {
      case 1: Navigator.pushNamed(context, AppRouter.channels); break;
      case 2: Navigator.pushNamed(context, AppRouter.favorites); break;
      case 3: Navigator.pushNamed(context, AppRouter.search); break;
      case 4: Navigator.pushNamed(context, AppRouter.settings); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTV = PlatformDetector.isTV || size.width > 1200;

    if (isTV) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: TVSidebar(
          selectedIndex: 0,
          child: _buildMainContent(context),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: _buildMainContent(context),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final navItems = _getNavItems(context);
    return Container(
      decoration: const BoxDecoration(color: AppTheme.surfaceColor, border: Border(top: BorderSide(color: Color(0x1AFFFFFF), width: 1))),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(navItems.length, (index) {
              final item = navItems[index];
              final isSelected = _selectedNavIndex == index;
              return GestureDetector(
                onTap: () => _onNavItemTap(index),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(gradient: isSelected ? AppTheme.lotusGradient : null, borderRadius: BorderRadius.circular(AppTheme.radiusPill)),
                  child: Icon(item.icon, color: isSelected ? Colors.white : AppTheme.textMuted, size: 24),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    return Consumer2<PlaylistProvider, ChannelProvider>(
      builder: (context, playlistProvider, channelProvider, _) {
        if (!playlistProvider.hasPlaylists) return _buildEmptyState();
        if (channelProvider.isLoading) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
        }
        
        // 频道加载完成后，如果推荐频道为空则初始化
        if (_recommendedChannels.isEmpty && channelProvider.channels.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _refreshRecommendedChannels();
          });
        }
        
        final favChannels = _getFavoriteChannels(channelProvider);
        
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildCompactHeader(channelProvider)),
            SliverToBoxAdapter(child: _buildCategoryChips(channelProvider)),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildChannelRow(AppStrings.of(context)?.recommendedChannels ?? 'Recommended', _recommendedChannels, showRefresh: true, onRefresh: _refreshRecommendedChannels),
                  const SizedBox(height: 28),
                  ...channelProvider.groups.take(5).map((group) {
                    final channels = channelProvider.channels.where((c) => c.groupName == group.name).take(7).toList();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 28),
                      child: _buildChannelRow(
                        group.name,
                        channels,
                        showMore: true,
                        onMoreTap: () => Navigator.pushNamed(context, AppRouter.channels, arguments: {'groupName': group.name}),
                      ),
                    );
                  }),
                  if (favChannels.isNotEmpty) ...[
                    _buildChannelRow(AppStrings.of(context)?.myFavorites ?? 'My Favorites', favChannels, showMore: true, onMoreTap: () => Navigator.pushNamed(context, AppRouter.favorites)),
                    const SizedBox(height: 24),
                  ],
                ]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCompactHeader(ChannelProvider provider) {
    final recentChannel = provider.channels.isNotEmpty ? provider.channels.first : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => AppTheme.lotusGradient.createShader(bounds),
                  child: const Text('Lotus IPTV', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const SizedBox(height: 6),
                Text(
                  '${provider.totalChannelCount} ${AppStrings.of(context)?.channels ?? "channels"} · ${provider.groups.length} ${AppStrings.of(context)?.categories ?? "categories"} · ${context.watch<FavoritesProvider>().count} ${AppStrings.of(context)?.favorites ?? "favorites"}',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _buildHeaderButton(Icons.play_arrow_rounded, AppStrings.of(context)?.continueWatching ?? 'Continue', true, recentChannel != null ? () => _playChannel(recentChannel) : null),
              const SizedBox(width: 10),
              _buildHeaderButton(Icons.playlist_add_rounded, AppStrings.of(context)?.playlists ?? 'Playlists', false, () => Navigator.pushNamed(context, AppRouter.playlistManager)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton(IconData icon, String label, bool isPrimary, VoidCallback? onTap) {
    return TVFocusable(
      onSelect: onTap,
      focusScale: 1.0,
      showFocusBorder: false,
      builder: (context, isFocused, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: isPrimary || isFocused ? AppTheme.lotusGradient : null,
            color: isPrimary || isFocused ? null : AppTheme.glassColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(color: isFocused ? AppTheme.focusBorderColor : AppTheme.glassBorderColor, width: isFocused ? 2 : 1),
          ),
          child: child,
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildCategoryChips(ChannelProvider provider) {
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: provider.groups.length,
        itemBuilder: (context, index) {
          final group = provider.groups[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TVFocusable(
              onSelect: () => Navigator.pushNamed(context, AppRouter.channels, arguments: {'groupName': group.name}),
              focusScale: 1.0,
              showFocusBorder: false,
              builder: (context, isFocused, child) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: isFocused ? AppTheme.lotusGradient : null,
                    color: isFocused ? null : AppTheme.glassColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    border: Border.all(color: isFocused ? AppTheme.focusBorderColor : AppTheme.glassBorderColor),
                  ),
                  child: child,
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CategoryCard.getIconForCategory(group.name), size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Text(group.name, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChannelRow(String title, List<Channel> channels, {bool showMore = false, bool showRefresh = false, VoidCallback? onMoreTap, VoidCallback? onRefresh}) {
    if (channels.isEmpty && !showRefresh) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            if (showRefresh) ...[
              const SizedBox(width: 10),
              TVFocusable(
                onSelect: onRefresh,
                focusScale: 1.0,
                showFocusBorder: false,
                builder: (context, isFocused, child) {
                  return Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: isFocused ? AppTheme.primaryColor : AppTheme.glassColor,
                      shape: BoxShape.circle,
                    ),
                    child: child,
                  );
                },
                child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 14),
              ),
            ],
            const Spacer(),
            if (showMore)
              TVFocusable(
                onSelect: onMoreTap,
                focusScale: 1.0,
                showFocusBorder: false,
                builder: (context, isFocused, child) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: isFocused ? AppTheme.lotusGradient : null,
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    ),
                    child: child,
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(AppStrings.of(context)?.more ?? 'More', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    const SizedBox(width: 2),
                    const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted, size: 16),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 145,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: channels.length > 7 ? 7 : channels.length,
            itemBuilder: (context, index) {
              final channel = channels[index];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SizedBox(
                  width: 160,
                  child: ChannelCard(
                    name: channel.name,
                    logoUrl: channel.logoUrl,
                    groupName: channel.groupName,
                    isFavorite: context.watch<FavoritesProvider>().isFavorite(channel.id ?? 0),
                    onFavoriteToggle: () => context.read<FavoritesProvider>().toggleFavorite(channel),
                    onTap: () => _playChannel(channel),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _playChannel(Channel channel) {
    context.read<PlayerProvider>().playChannel(channel);
    Navigator.pushNamed(context, AppRouter.player, arguments: {
      'channelUrl': channel.url,
      'channelName': channel.name,
      'channelLogo': channel.logoUrl,
    });
  }

  List<Channel> _getFavoriteChannels(ChannelProvider provider) {
    final favProvider = context.read<FavoritesProvider>();
    return provider.channels.where((c) => favProvider.isFavorite(c.id ?? 0)).take(7).toList();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(gradient: AppTheme.lotusSoftGradient, borderRadius: BorderRadius.circular(24)),
            child: const Icon(Icons.playlist_add_rounded, size: 48, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Text(AppStrings.of(context)?.noPlaylistYet ?? 'No Playlists Yet', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(AppStrings.of(context)?.addM3uToStart ?? 'Add M3U playlist to start watching', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 24),
          TVFocusable(
            autofocus: true,
            onSelect: () => Navigator.pushNamed(context, AppRouter.playlistManager),
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRouter.playlistManager),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(AppStrings.of(context)?.addPlaylist ?? 'Add Playlist'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
