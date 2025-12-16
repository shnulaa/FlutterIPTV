import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/widgets/tv_focusable.dart';
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
  final FocusNode _navFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    debugPrint('DEBUG: 开始加载主页数据...');
    
    final playlistProvider = context.read<PlaylistProvider>();
    final channelProvider = context.read<ChannelProvider>();
    final favoritesProvider = context.read<FavoritesProvider>();

    debugPrint('DEBUG: 检查是否有播放列表...');
    if (playlistProvider.hasPlaylists) {
      debugPrint('DEBUG: 找到 ${playlistProvider.playlists.length} 个播放列表');
      
      // Load channels for the active playlist instead of all channels
      final activePlaylist = playlistProvider.activePlaylist;
      if (activePlaylist != null && activePlaylist.id != null) {
        debugPrint('DEBUG: 加载激活播放列表的频道: ${activePlaylist.name} (ID: ${activePlaylist.id})');
        await channelProvider.loadChannels(activePlaylist.id!);
      } else {
        // Fallback to all channels if no active playlist
        debugPrint('DEBUG: 没有激活的播放列表，加载所有频道');
        await channelProvider.loadAllChannels();
      }
      
      debugPrint('DEBUG: 开始加载收藏...');
      await favoritesProvider.loadFavorites();
      debugPrint('DEBUG: 数据加载完成');
    } else {
      debugPrint('DEBUG: 没有找到播放列表，显示空状态');
    }
  }

  @override
  void dispose() {
    _navFocusNode.dispose();
    super.dispose();
  }

  List<_NavItem> _getNavItems(BuildContext context) {
    return [
      _NavItem(
          icon: Icons.home_rounded,
          label: AppStrings.of(context)?.home ?? 'Home'),
      _NavItem(
          icon: Icons.live_tv_rounded,
          label: AppStrings.of(context)?.channels ?? 'Channels'),
      _NavItem(
          icon: Icons.favorite_rounded,
          label: AppStrings.of(context)?.favorites ?? 'Favorites'),
      _NavItem(
          icon: Icons.search_rounded,
          label: AppStrings.of(context)?.searchChannels ?? 'Search'),
      _NavItem(
          icon: Icons.settings_rounded,
          label: AppStrings.of(context)?.settings ?? 'Settings'),
    ];
  }

  void _onNavItemTap(int index) {
    debugPrint('DEBUG: 导航项被点击，索引: $index');
    setState(() => _selectedNavIndex = index);

    // Navigation item indices:
    // 0: Home (current page, no navigation)
    // 1: Channels
    // 2: Favorites
    // 3: Search
    // 4: Settings
    
    switch (index) {
      case 0: // Home - already on home page
        debugPrint('DEBUG: 已在主页，无需导航');
        break;
      case 1: // Channels
        debugPrint('DEBUG: 导航到频道页面');
        Navigator.pushNamed(context, AppRouter.channels);
        break;
      case 2: // Favorites
        debugPrint('DEBUG: 导航到收藏页面');
        Navigator.pushNamed(context, AppRouter.favorites);
        break;
      case 3: // Search
        debugPrint('DEBUG: 导航到搜索页面');
        Navigator.pushNamed(context, AppRouter.search);
        break;
      case 4: // Settings
        debugPrint('DEBUG: 导航到设置页面');
        Navigator.pushNamed(context, AppRouter.settings);
        break;
      default:
        debugPrint('DEBUG: 未知的导航索引: $index');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTV = PlatformDetector.isTV || size.width > 1200;

    // Refresh nav items on build to get correct context
    // We need to pass them to build methods

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Row(
        children: [
          // Side Navigation (for TV and Desktop)
          if (isTV) _buildSideNav(context),

          // Main Content
          Expanded(
            child: _buildMainContent(context),
          ),
        ],
      ),
      // Bottom Navigation (for Mobile)
      bottomNavigationBar: !isTV ? _buildBottomNav(context) : null,
    );
  }

  Widget _buildSideNav(BuildContext context) {
    final navItems = _getNavItems(context);

    return Container(
      width: 80,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 24),

          // Logo
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.live_tv_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),

          const SizedBox(height: 40),

          // Navigation Items
          Expanded(
            child: TVFocusTraversalGroup(
              child: Column(
                children: List.generate(navItems.length, (index) {
                  return _buildNavItem(index, navItems[index]);
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, _NavItem item) {
    final isSelected = _selectedNavIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TVFocusable(
        autofocus: index == 0,
        onSelect: () => _onNavItemTap(index),
        focusScale: 1.1,
        showFocusBorder: false,
        builder: (context, isFocused, child) {
          return AnimatedContainer(
            duration: AppTheme.animationFast,
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isSelected || isFocused
                  ? AppTheme.primaryColor.withOpacity(isFocused ? 1.0 : 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isFocused
                  ? Border.all(color: AppTheme.focusBorderColor, width: 2)
                  : null,
            ),
            child: Icon(
              item.icon,
              color: isSelected || isFocused
                  ? (isFocused ? Colors.white : AppTheme.primaryColor)
                  : AppTheme.textMuted,
              size: 26,
            ),
          );
        },
        child: const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final navItems = _getNavItems(context);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
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
                child: AnimatedContainer(
                  duration: AppTheme.animationFast,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryColor.withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.icon,
                        color: isSelected
                            ? AppTheme.primaryColor
                            : AppTheme.textMuted,
                        size: 24,
                      ),
                      if (isSelected) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // App Bar
        SliverAppBar(
          floating: true,
          backgroundColor: AppTheme.backgroundColor.withOpacity(0.9),
          expandedHeight: 100,
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.only(left: 24, bottom: 16),
            title: Row(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) {
                    return const LinearGradient(
                      colors: [
                        Color(0xFF6366F1),
                        Color(0xFF818CF8),
                      ],
                    ).createShader(bounds);
                  },
                  child: Text(
                    AppStrings.of(context)?.lotusIptv ?? 'Lotus IPTV',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.playlist_add_rounded),
              onPressed: () => Navigator.pushNamed(
                context,
                AppRouter.playlistManager,
              ),
              tooltip:
                  AppStrings.of(context)?.managePlaylists ?? 'Manage Playlists',
            ),
            const SizedBox(width: 8),
          ],
        ),

        // Content
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: Consumer2<PlaylistProvider, ChannelProvider>(
            builder: (context, playlistProvider, channelProvider, _) {
              if (!playlistProvider.hasPlaylists) {
                return SliverFillRemaining(
                  child: _buildEmptyState(),
                );
              }

              if (channelProvider.isLoading) {
                return const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildListDelegate([
                  // Quick Stats
                  _buildQuickStats(channelProvider),

                  const SizedBox(height: 32),

                  // Categories Section
                  _buildSectionHeader(
                      AppStrings.of(context)?.categories ?? 'Categories',
                      channelProvider.groups.length),
                  const SizedBox(height: 16),
                  _buildCategoriesGrid(channelProvider),

                  const SizedBox(height: 32),

                  // Recent/Popular Channels
                  _buildSectionHeader(
                      AppStrings.of(context)?.allChannels ?? 'All Channels',
                      channelProvider.totalChannelCount),
                  const SizedBox(height: 16),
                  _buildChannelsGrid(context, channelProvider),
                ]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(
              Icons.playlist_add_rounded,
              size: 60,
              color: AppTheme.textMuted.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            AppStrings.of(context)?.noPlaylistsYet ?? 'No Playlists Yet',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.of(context)?.addFirstPlaylistHint ??
                'Add your first M3U playlist to start watching',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),
          TVFocusable(
            autofocus: true,
            onSelect: () => Navigator.pushNamed(
              context,
              AppRouter.playlistManager,
            ),
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(
                context,
                AppRouter.playlistManager,
              ),
              icon: const Icon(Icons.add_rounded),
              label:
                  Text(AppStrings.of(context)?.addPlaylist ?? 'Add Playlist'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(ChannelProvider provider) {
    final favoritesCount = context.watch<FavoritesProvider>().count;

    return Row(
      children: [
        _buildStatCard(
          AppStrings.of(context)?.totalChannels ?? 'Total Channels',
          provider.totalChannelCount.toString(),
          Icons.live_tv_rounded,
          AppTheme.primaryColor,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          AppStrings.of(context)?.categories ?? 'Categories',
          provider.groups.length.toString(),
          Icons.category_rounded,
          AppTheme.secondaryColor,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          AppStrings.of(context)?.favorites ?? 'Favorites',
          favoritesCount.toString(),
          Icons.favorite_rounded,
          AppTheme.accentColor,
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.2),
              color.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
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

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count.toString(),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoriesGrid(ChannelProvider provider) {
    final size = MediaQuery.of(context).size;
    final crossAxisCount = PlatformDetector.getGridCrossAxisCount(size.width);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 1.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: provider.groups.length,
      itemBuilder: (context, index) {
        final group = provider.groups[index];
        return CategoryCard(
          name: group.name,
          channelCount: group.channelCount,
          icon: CategoryCard.getIconForCategory(group.name),
          color: CategoryCard.getColorForIndex(index),
          onTap: () {
            Navigator.pushNamed(
              context,
              AppRouter.channels,
              arguments: {'groupName': group.name},
            );
          },
        );
      },
    );
  }

  Widget _buildChannelsGrid(BuildContext context, ChannelProvider provider) {
    final size = MediaQuery.of(context).size;
    final crossAxisCount = PlatformDetector.getGridCrossAxisCount(size.width);

    // Randomly pick 10 channels if there are enough
    List<Channel> channels;
    if (provider.channels.length <= 10) {
      channels = provider.channels;
    } else {
      channels = List<Channel>.from(provider.channels)..shuffle();
      channels = channels.take(10).toList();
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.85,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final channel = channels[index];
        return ChannelCard(
          name: channel.name,
          logoUrl: channel.logoUrl,
          groupName: channel.groupName,
          isFavorite:
              context.watch<FavoritesProvider>().isFavorite(channel.id ?? 0),
          onFavoriteToggle: () {
            context.read<FavoritesProvider>().toggleFavorite(channel);
          },
          onTap: () {
            // Ensure we set the current channel in provider before navigating
            // This is crucial for favorites to work
            context.read<PlayerProvider>().playChannel(channel);

            Navigator.pushNamed(
              context,
              AppRouter.player,
              arguments: {
                'channelUrl': channel.url,
                'channelName': channel.name,
                'channelLogo': channel.logoUrl,
              },
            );
          },
        );
      },
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem({required this.icon, required this.label});
}
