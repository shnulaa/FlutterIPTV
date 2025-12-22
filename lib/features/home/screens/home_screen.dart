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
import '../../settings/providers/settings_provider.dart';
import '../../epg/providers/epg_provider.dart';
import '../../../core/models/channel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedNavIndex = 0;
  List<Channel> _recommendedChannels = [];
  int? _lastPlaylistId; // 跟踪上次的播放列表ID

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
    final playlistProvider = context.read<PlaylistProvider>();
    final currentPlaylistId = playlistProvider.activePlaylist?.id;
    
    // 如果播放列表变化了，清空推荐频道并重新加载
    if (_lastPlaylistId != currentPlaylistId) {
      _lastPlaylistId = currentPlaylistId;
      _recommendedChannels = [];
      if (channelProvider.channels.isNotEmpty) {
        _refreshRecommendedChannels();
      }
    } else if (_recommendedChannels.isEmpty && channelProvider.channels.isNotEmpty) {
      _refreshRecommendedChannels();
    }
  }

  Future<void> _loadData() async {
    final playlistProvider = context.read<PlaylistProvider>();
    final channelProvider = context.read<ChannelProvider>();
    final favoritesProvider = context.read<FavoritesProvider>();

    if (playlistProvider.hasPlaylists) {
      final activePlaylist = playlistProvider.activePlaylist;
      _lastPlaylistId = activePlaylist?.id;
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
    // 随机打乱频道顺序，显示数量由 _buildChannelRow 根据宽度自动计算
    final shuffled = List<Channel>.from(channelProvider.channels)..shuffle();
    // 最多取20个作为候选，实际显示数量由宽度决定
    _recommendedChannels = shuffled.take(20).toList();
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
        
        return Column(
          children: [
            // 固定头部
            _buildCompactHeader(channelProvider),
            // 固定分类标签
            _buildCategoryChips(channelProvider),
            const SizedBox(height: 16),
            // 可滚动的频道列表
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildChannelRow(AppStrings.of(context)?.recommendedChannels ?? 'Recommended', _recommendedChannels, showRefresh: true, onRefresh: _refreshRecommendedChannels),
                        const SizedBox(height: 12),
                        ...channelProvider.groups.take(5).map((group) {
                          // 取足够多的频道，实际显示数量由宽度决定
                          final channels = channelProvider.channels.where((c) => c.groupName == group.name).take(20).toList();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
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
                          const SizedBox(height: 12),
                        ],
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCompactHeader(ChannelProvider provider) {
    // 获取上次播放的频道 - 使用 watch 来监听变化
    final settingsProvider = context.watch<SettingsProvider>();
    final playlistProvider = context.watch<PlaylistProvider>();
    final activePlaylist = playlistProvider.activePlaylist;
    Channel? lastChannel;
    
    debugPrint('DEBUG: rememberLastChannel=${settingsProvider.rememberLastChannel}, lastChannelId=${settingsProvider.lastChannelId}');
    
    if (settingsProvider.rememberLastChannel && settingsProvider.lastChannelId != null) {
      try {
        lastChannel = provider.channels.firstWhere(
          (c) => c.id == settingsProvider.lastChannelId,
        );
        debugPrint('DEBUG: 找到上次播放的频道: ${lastChannel.name} (ID: ${lastChannel.id})');
      } catch (_) {
        // 频道不存在，使用第一个频道
        debugPrint('DEBUG: 未找到上次播放的频道ID ${settingsProvider.lastChannelId}，使用第一个频道');
        lastChannel = provider.channels.isNotEmpty ? provider.channels.first : null;
      }
    } else {
      debugPrint('DEBUG: 未启用记忆功能或无上次频道，使用第一个频道');
      lastChannel = provider.channels.isNotEmpty ? provider.channels.first : null;
    }

    // 构建播放列表信息
    String playlistInfo = '';
    if (activePlaylist != null) {
      final type = activePlaylist.isRemote ? 'URL' : '本地';
      playlistInfo = ' · [$type] ${activePlaylist.name}';
      if (activePlaylist.url != null && activePlaylist.url!.isNotEmpty) {
        String url = activePlaylist.url!.replaceFirst(RegExp(r'^https?://'), '');
        if (url.length > 30) {
          url = '${url.substring(0, 30)}...';
        }
        playlistInfo += ' · $url';
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
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
                const SizedBox(height: 4),
                Text(
                  '${provider.totalChannelCount} ${AppStrings.of(context)?.channels ?? "频道"} · ${provider.groups.length} ${AppStrings.of(context)?.categories ?? "分类"} · ${context.watch<FavoritesProvider>().count} ${AppStrings.of(context)?.favorites ?? "收藏"}$playlistInfo',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Row(
            children: [
              _buildHeaderButton(Icons.play_arrow_rounded, AppStrings.of(context)?.continueWatching ?? 'Continue', true, lastChannel != null ? () => _playChannel(lastChannel!) : null),
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
    return _ResponsiveCategoryChips(
      groups: provider.groups,
      onGroupTap: (groupName) => Navigator.pushNamed(context, AppRouter.channels, arguments: {'groupName': groupName}),
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
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            // 每个卡片宽度 160 + 间距 12
            const cardWidth = 160.0;
            const cardSpacing = 12.0;
            final availableWidth = constraints.maxWidth;
            
            // 计算能显示多少个卡片
            final maxCards = ((availableWidth + cardSpacing) / (cardWidth + cardSpacing)).floor();
            // 显示数量不能超过实际频道数量，最少显示1个
            final displayCount = maxCards.clamp(1, channels.length);
            
            // 获取 EPG Provider
            final epgProvider = context.watch<EpgProvider>();
            
            return SizedBox(
              height: 140,
              child: Row(
                children: List.generate(displayCount, (index) {
                  final channel = channels[index];
                  // 获取 EPG 信息
                  final currentProgram = epgProvider.getCurrentProgram(channel.epgId, channel.name);
                  final nextProgram = epgProvider.getNextProgram(channel.epgId, channel.name);
                  
                  return Padding(
                    padding: EdgeInsets.only(right: index < displayCount - 1 ? cardSpacing : 0),
                    child: SizedBox(
                      width: cardWidth,
                      child: ChannelCard(
                        name: channel.name,
                        logoUrl: channel.logoUrl,
                        groupName: channel.groupName,
                        currentProgram: currentProgram?.title,
                        nextProgram: nextProgram?.title,
                        isFavorite: context.watch<FavoritesProvider>().isFavorite(channel.id ?? 0),
                        onFavoriteToggle: () => context.read<FavoritesProvider>().toggleFavorite(channel),
                        onTap: () => _playChannel(channel),
                      ),
                    ),
                  );
                }),
              ),
            );
          },
        ),
      ],
    );
  }

  void _playChannel(Channel channel) {
    // 保存上次播放的频道ID
    final settingsProvider = context.read<SettingsProvider>();
    if (settingsProvider.rememberLastChannel && channel.id != null) {
      settingsProvider.setLastChannelId(channel.id);
    }
    
    context.read<PlayerProvider>().playChannel(channel);
    Navigator.pushNamed(context, AppRouter.player, arguments: {
      'channelUrl': channel.url,
      'channelName': channel.name,
      'channelLogo': channel.logoUrl,
    });
  }

  List<Channel> _getFavoriteChannels(ChannelProvider provider) {
    final favProvider = context.read<FavoritesProvider>();
    // 最多取20个作为候选，实际显示数量由宽度决定
    return provider.channels.where((c) => favProvider.isFavorite(c.id ?? 0)).take(20).toList();
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

/// 响应式分类标签组件 - 根据宽度自适应，超出时折叠
class _ResponsiveCategoryChips extends StatefulWidget {
  final List<dynamic> groups;
  final Function(String) onGroupTap;

  const _ResponsiveCategoryChips({
    required this.groups,
    required this.onGroupTap,
  });

  @override
  State<_ResponsiveCategoryChips> createState() => _ResponsiveCategoryChipsState();
}

class _ResponsiveCategoryChipsState extends State<_ResponsiveCategoryChips> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - 48; // 减去左右 padding
        
        // 计算每个 chip 的大致宽度（图标 + 文字 + padding）
        // 估算每个 chip 平均宽度约 100px
        final estimatedChipWidth = 110.0;
        final maxVisibleCount = (availableWidth / estimatedChipWidth).floor();
        
        // 如果所有分类都能显示，直接用 Wrap
        if (widget.groups.length <= maxVisibleCount || _isExpanded) {
          return _buildExpandedView();
        }
        
        // 否则显示部分 + 展开按钮
        return _buildCollapsedView(maxVisibleCount);
      },
    );
  }

  Widget _buildExpandedView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.start,
          children: [
            ...widget.groups.map((group) => _buildChip(group.name)),
            if (widget.groups.length > 6) _buildCollapseButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsedView(int maxVisible) {
    // 至少显示 4 个，留一个位置给展开按钮
    final visibleCount = (maxVisible - 1).clamp(3, widget.groups.length);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.start,
          children: [
            ...widget.groups.take(visibleCount).map((group) => _buildChip(group.name)),
            _buildExpandButton(widget.groups.length - visibleCount),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String name) {
    return TVFocusable(
      onSelect: () => widget.onGroupTap(name),
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
          Icon(CategoryCard.getIconForCategory(name), size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Text(name, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildExpandButton(int hiddenCount) {
    return TVFocusable(
      onSelect: () => setState(() => _isExpanded = true),
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
          const Icon(Icons.more_horiz_rounded, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 4),
          Text('+$hiddenCount', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildCollapseButton() {
    return TVFocusable(
      onSelect: () => setState(() => _isExpanded = false),
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
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.unfold_less_rounded, size: 14, color: AppTheme.textSecondary),
          SizedBox(width: 4),
          Text('收起', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}
