import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../../core/widgets/tv_sidebar.dart';
import '../../../core/widgets/category_card.dart';
import '../../../core/widgets/channel_card.dart';
import '../../../core/platform/platform_detector.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/services/update_service.dart';
import '../../../core/models/app_update.dart';
import '../../channels/providers/channel_provider.dart';
import '../../channels/screens/channels_screen.dart';
import '../../playlist/providers/playlist_provider.dart';
import '../../favorites/providers/favorites_provider.dart';
import '../../favorites/screens/favorites_screen.dart';
import '../../player/providers/player_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../settings/screens/settings_screen.dart';
import '../../search/screens/search_screen.dart';
import '../../epg/providers/epg_provider.dart';
import '../../multi_screen/providers/multi_screen_provider.dart';
import '../../../core/platform/native_player_channel.dart';
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
  int _lastChannelCount = 0; // 跟踪上次的频道数量
  String _appVersion = '';
  AppUpdate? _availableUpdate; // 可用的更新

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadVersion();
    _checkForUpdates();
    // 监听频道变化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChannelProvider>().addListener(_onChannelProviderChanged);
      context.read<PlaylistProvider>().addListener(_onPlaylistProviderChanged);
      context.read<FavoritesProvider>().addListener(_onFavoritesProviderChanged);
    });
  }

  Future<void> _checkForUpdates() async {
    try {
      final updateService = UpdateService();
      // 启动时强制检查一次更新（忽略24小时限制）
      final update = await updateService.checkForUpdates(forceCheck: true);
      if (mounted && update != null) {
        setState(() {
          _availableUpdate = update;
        });
      }
    } catch (e) {
      // 静默失败，不影响用户体验
    }
  }

  Future<void> _loadVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = packageInfo.version;
        });
      }
    } catch (e) {
      // ignore
    }
  }

  @override
  void dispose() {
    // 移除监听器时需要小心，因为 context 可能已经不可用
    super.dispose();
  }

  void _onChannelProviderChanged() {
    if (!mounted) return;
    final channelProvider = context.read<ChannelProvider>();
    
    // 当加载完成时刷新推荐频道
    if (!channelProvider.isLoading && channelProvider.channels.isNotEmpty) {
      // 频道数量变化或首次加载时刷新
      if (channelProvider.channels.length != _lastChannelCount || _recommendedChannels.isEmpty) {
        _lastChannelCount = channelProvider.channels.length;
        _refreshRecommendedChannels();
      }
    }
  }

  void _onPlaylistProviderChanged() {
    if (!mounted) return;
    final playlistProvider = context.read<PlaylistProvider>();
    final currentPlaylistId = playlistProvider.activePlaylist?.id;
    
    // 播放列表ID变化时清空推荐频道
    if (_lastPlaylistId != currentPlaylistId) {
      _lastPlaylistId = currentPlaylistId;
      _recommendedChannels = [];
    }
    
    // 当播放列表刷新完成时（isLoading 从 true 变为 false），触发频道重新加载
    // 这样可以确保刷新 M3U 后首页能正确更新
    if (!playlistProvider.isLoading && playlistProvider.hasPlaylists) {
      final channelProvider = context.read<ChannelProvider>();
      // 如果频道 provider 不在加载中，且推荐频道为空，则重新加载
      if (!channelProvider.isLoading && _recommendedChannels.isEmpty) {
        _refreshRecommendedChannels();
      }
    }
  }

  void _onFavoritesProviderChanged() {
    if (!mounted) return;
    // 收藏状态变化时刷新推荐频道
    _refreshRecommendedChannels();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
    if (!mounted) return;

    final channelProvider = context.read<ChannelProvider>();
    final favoritesProvider = context.read<FavoritesProvider>();
    
    if (channelProvider.channels.isEmpty) return;

    // 分离收藏和非收藏频道
    final favoriteChannels = <Channel>[];
    final nonFavoriteChannels = <Channel>[];
    
    for (final channel in channelProvider.channels) {
      if (favoritesProvider.isFavorite(channel.id ?? 0)) {
        favoriteChannels.add(channel);
      } else {
        nonFavoriteChannels.add(channel);
      }
    }
    
    // 打乱非收藏频道顺序
    nonFavoriteChannels.shuffle();
    
    // 优先显示收藏频道，不够再补充非收藏频道
    _recommendedChannels = [
      ...favoriteChannels,
      ...nonFavoriteChannels,
    ].take(20).toList();

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
    if (index == _selectedNavIndex) return;
    setState(() => _selectedNavIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTV = PlatformDetector.isTV || size.width > 1200;

    if (isTV) {
      return Scaffold(
        backgroundColor: AppTheme.getBackgroundColor(context),
        body: TVSidebar(
          selectedIndex: 0,
          child: _buildMainContent(context),
        ),
      );
    }

    // 手机端使用底部导航栏切换页面
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      body: _buildMobileBody(),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildMobileBody() {
    switch (_selectedNavIndex) {
      case 0:
        return _buildMainContent(context);
      case 1:
        return const _EmbeddedChannelsScreen();
      case 2:
        return const _EmbeddedFavoritesScreen();
      case 3:
        return const _EmbeddedSearchScreen();
      case 4:
        return const _EmbeddedSettingsScreen();
      default:
        return _buildMainContent(context);
    }
  }

  Widget _buildBottomNav(BuildContext context) {
    final navItems = _getNavItems(context);
    return Container(
      decoration: BoxDecoration(color: AppTheme.getSurfaceColor(context), border: const Border(top: BorderSide(color: Color(0x1AFFFFFF), width: 1))),
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
                  child: Icon(item.icon, color: isSelected ? Colors.white : AppTheme.getTextMuted(context), size: 24),
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
        // 播放列表正在刷新或频道正在加载时显示加载状态
        if (playlistProvider.isLoading || channelProvider.isLoading) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
        }

        final favChannels = _getFavoriteChannels(channelProvider);

        return Column(
          children: [
            // 固定头部
            _buildCompactHeader(channelProvider),
            // 固定分类标签
            _buildCategoryChips(channelProvider),
            SizedBox(height: PlatformDetector.isMobile ? 10 : 16),
            // 可滚动的频道列表
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: PlatformDetector.isMobile ? 12 : 24),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildChannelRow(AppStrings.of(context)?.recommendedChannels ?? 'Recommended', _recommendedChannels, showRefresh: true, onRefresh: _refreshRecommendedChannels),
                        SizedBox(height: PlatformDetector.isMobile ? 8 : 12),
                        ...channelProvider.groups.take(5).map((group) {
                          // 取足够多的频道，实际显示数量由宽度决定
                          final channels = channelProvider.channels.where((c) => c.groupName == group.name).take(20).toList();
                          return Padding(
                            padding: EdgeInsets.only(bottom: PlatformDetector.isMobile ? 8 : 12),
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
                          SizedBox(height: PlatformDetector.isMobile ? 8 : 12),
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
    final bool isMultiScreenMode = settingsProvider.lastPlayMode == 'multi' && settingsProvider.hasMultiScreenState;
    
    debugPrint('HomeScreen: lastPlayMode=${settingsProvider.lastPlayMode}, hasMultiScreenState=${settingsProvider.hasMultiScreenState}, isMultiScreenMode=$isMultiScreenMode');
    debugPrint('HomeScreen: lastMultiScreenChannels=${settingsProvider.lastMultiScreenChannels}');

    if (settingsProvider.rememberLastChannel && settingsProvider.lastChannelId != null) {
      try {
        lastChannel = provider.channels.firstWhere(
          (c) => c.id == settingsProvider.lastChannelId,
        );
      } catch (_) {
        // 频道不存在，使用第一个频道
        lastChannel = provider.channels.isNotEmpty ? provider.channels.first : null;
      }
    } else {
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

    // 继续播放按钮 - 名字固定为 "Continue"，不根据模式变化
    final continueLabel = AppStrings.of(context)?.continueWatching ?? 'Continue';
    final isMobile = PlatformDetector.isMobile;

    return Container(
      padding: EdgeInsets.fromLTRB(isMobile ? 12 : 24, isMobile ? 10 : 16, isMobile ? 12 : 24, isMobile ? 8 : 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => AppTheme.lotusGradient.createShader(bounds),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('Lotus IPTV', style: TextStyle(fontSize: isMobile ? 20 : 28, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(width: 8),
                      Text('v$_appVersion', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Colors.white70)),
                      if (_availableUpdate != null) ...[
                        const SizedBox(width: 8),
                        TVFocusable(
                          onSelect: () => Navigator.pushNamed(context, AppRouter.settings),
                          focusScale: 1.0,
                          showFocusBorder: false,
                          builder: (context, isFocused, child) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                gradient: isFocused ? AppTheme.lotusGradient : LinearGradient(
                                  colors: [Colors.orange.shade600, Colors.deepOrange.shade600],
                                ),
                                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                                border: isFocused ? Border.all(color: AppTheme.focusBorderColor, width: 2) : null,
                              ),
                              child: child,
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.system_update_rounded, size: 10, color: Colors.white),
                              const SizedBox(width: 3),
                              Text('v${_availableUpdate!.version}', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${provider.totalChannelCount} ${AppStrings.of(context)?.channels ?? "频道"} · ${provider.groups.length} ${AppStrings.of(context)?.categories ?? "分类"} · ${context.watch<FavoritesProvider>().count} ${AppStrings.of(context)?.favorites ?? "收藏"}$playlistInfo',
                  style: TextStyle(color: AppTheme.getTextMuted(context), fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Row(
            children: [
              _buildHeaderButton(
                Icons.play_arrow_rounded, 
                continueLabel, 
                true, 
                (lastChannel != null || isMultiScreenMode) 
                    ? () => _continuePlayback(provider, lastChannel, isMultiScreenMode, settingsProvider) 
                    : null
              ),
              const SizedBox(width: 10),
              _buildHeaderButton(Icons.playlist_add_rounded, AppStrings.of(context)?.playlists ?? 'Playlists', false, () => Navigator.pushNamed(context, AppRouter.playlistManager)),
            ],
          ),
        ],
      ),
    );
  }

  /// 继续播放 - 支持单频道和分屏模式
  void _continuePlayback(ChannelProvider provider, Channel? lastChannel, bool isMultiScreenMode, SettingsProvider settingsProvider) {
    if (isMultiScreenMode) {
      // 恢复分屏模式
      _resumeMultiScreen(provider, settingsProvider);
    } else if (lastChannel != null) {
      // 恢复单频道播放
      _playChannel(lastChannel);
    }
  }

  /// 恢复分屏播放
  Future<void> _resumeMultiScreen(ChannelProvider provider, SettingsProvider settingsProvider) async {
    final channels = provider.channels;
    final multiScreenChannelIds = settingsProvider.lastMultiScreenChannels;
    final activeIndex = settingsProvider.activeScreenIndex;
    
    // 设置 providers 用于状态保存
    final favoritesProvider = context.read<FavoritesProvider>();
    NativePlayerChannel.setProviders(favoritesProvider, provider, settingsProvider);
    
    // 将频道ID转换为频道索引
    final List<int?> restoreScreenChannels = [];
    int initialChannelIndex = 0;
    bool foundFirst = false;
    
    for (int i = 0; i < multiScreenChannelIds.length; i++) {
      final channelId = multiScreenChannelIds[i];
      if (channelId != null) {
        final index = channels.indexWhere((c) => c.id == channelId);
        if (index >= 0) {
          restoreScreenChannels.add(index);
          if (!foundFirst) {
            initialChannelIndex = index;
            foundFirst = true;
          }
        } else {
          restoreScreenChannels.add(null);
        }
      } else {
        restoreScreenChannels.add(null);
      }
    }
    
    debugPrint('HomeScreen: _resumeMultiScreen - channelIds=$multiScreenChannelIds, restoreChannels=$restoreScreenChannels, activeIndex=$activeIndex');
    
    // 检查是否是 Android TV，使用原生分屏
    if (PlatformDetector.isAndroid) {
      final urls = channels.map((c) => c.url).toList();
      final names = channels.map((c) => c.name).toList();
      final groups = channels.map((c) => c.groupName ?? '').toList();
      final sources = channels.map((c) => c.sources).toList();
      final logos = channels.map((c) => c.logoUrl ?? '').toList();
      
      await NativePlayerChannel.launchMultiScreen(
        urls: urls,
        names: names,
        groups: groups,
        sources: sources,
        logos: logos,
        initialChannelIndex: initialChannelIndex,
        volumeBoostDb: settingsProvider.volumeBoost,
        defaultScreenPosition: settingsProvider.defaultScreenPosition,
        restoreActiveIndex: activeIndex,
        restoreScreenChannels: restoreScreenChannels,
        onClosed: () {
          debugPrint('HomeScreen: Multi-screen closed');
        },
      );
    } else {
      // Windows/其他平台使用 Flutter 分屏
      if (!mounted) return;
      
      // 预先设置 MultiScreenProvider 的频道状态
      final multiScreenProvider = context.read<MultiScreenProvider>();
      
      // 设置音量增强（必须在播放之前设置）
      multiScreenProvider.setVolumeSettings(1.0, settingsProvider.volumeBoost);
      
      // 设置活动屏幕（必须在播放之前设置）
      multiScreenProvider.setActiveScreen(activeIndex);
      
      // 恢复每个屏幕的频道（等待所有播放完成）
      final futures = <Future>[];
      for (int i = 0; i < multiScreenChannelIds.length && i < 4; i++) {
        final channelId = multiScreenChannelIds[i];
        if (channelId != null) {
          final channel = channels.firstWhere(
            (c) => c.id == channelId,
            orElse: () => channels.first,
          );
          // 播放频道到对应屏幕
          futures.add(multiScreenProvider.playChannelOnScreen(i, channel));
        }
      }
      
      // 等待所有频道开始播放
      await Future.wait(futures);
      
      // 等待一小段时间确保所有播放器都已经开始播放
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 所有频道加载完成后，重新应用音量设置确保只有活动屏幕有声音
      await multiScreenProvider.reapplyVolumeToAllScreens();
      
      // 找到初始频道（用于路由参数）
      Channel? initialChannel;
      if (initialChannelIndex >= 0 && initialChannelIndex < channels.length) {
        initialChannel = channels[initialChannelIndex];
      } else if (channels.isNotEmpty) {
        initialChannel = channels.first;
      }
      
      if (initialChannel != null && mounted) {
        Navigator.pushNamed(
          context,
          AppRouter.player,
          arguments: {
            'channelUrl': initialChannel.url,
            'channelName': initialChannel.name,
            'isMultiScreen': true,
          },
        );
      }
    }
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
            color: isPrimary || isFocused ? null : AppTheme.getGlassColor(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(color: isFocused ? AppTheme.focusBorderColor : AppTheme.getGlassBorderColor(context), width: isFocused ? 2 : 1),
          ),
          child: child,
        );
      },
      child: Builder(
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final textColor = isPrimary ? Colors.white : (isDark ? Colors.white : AppTheme.textPrimaryLight);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: textColor, size: 16),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          );
        },
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
    final isMobile = PlatformDetector.isMobile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: TextStyle(color: AppTheme.getTextPrimary(context), fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.w600)),
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
                      color: isFocused ? AppTheme.primaryColor : AppTheme.getGlassColor(context),
                      shape: BoxShape.circle,
                    ),
                    child: child,
                  );
                },
                child: Icon(Icons.refresh_rounded, color: AppTheme.getTextPrimary(context), size: isMobile ? 12 : 14),
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
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 10, vertical: isMobile ? 4 : 5),
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
                    Text(AppStrings.of(context)?.more ?? 'More', style: TextStyle(color: AppTheme.getTextMuted(context), fontSize: isMobile ? 10 : 12)),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded, color: AppTheme.getTextMuted(context), size: isMobile ? 14 : 16),
                  ],
                ),
              ),
          ],
        ),
        SizedBox(height: isMobile ? 6 : 8),
        LayoutBuilder(
          builder: (context, constraints) {
            // 如果没有频道，不显示任何内容
            if (channels.isEmpty) {
              return const SizedBox.shrink();
            }

            // 手机端使用更小的卡片
            final isMobile = PlatformDetector.isMobile;
            final cardWidth = isMobile ? 95.0 : 160.0;
            final cardSpacing = isMobile ? 6.0 : 12.0;
            final cardHeight = isMobile ? 100.0 : 140.0;
            final availableWidth = constraints.maxWidth;

            // 计算能显示多少个卡片，多加1个让布局更美观
            final maxCards = ((availableWidth + cardSpacing) / (cardWidth + cardSpacing)).floor() + 1;
            // 显示数量不能超过实际频道数量，最少显示1个
            final displayCount = maxCards.clamp(1, channels.length);

            return SizedBox(
              height: cardHeight,
              child: Row(
                children: List.generate(displayCount, (index) {
                  final channel = channels[index];

                  return Padding(
                    padding: EdgeInsets.only(right: index < displayCount - 1 ? cardSpacing : 0),
                    child: SizedBox(
                      width: cardWidth,
                      child: _OptimizedChannelCard(
                        channel: channel,
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
    final channelProvider = context.read<ChannelProvider>();
    final favoritesProvider = context.read<FavoritesProvider>();
    
    // 设置 providers 用于状态保存和收藏功能
    NativePlayerChannel.setProviders(favoritesProvider, channelProvider, settingsProvider);
    
    if (settingsProvider.rememberLastChannel && channel.id != null) {
      // 保存单频道播放状态
      settingsProvider.saveLastSingleChannel(channel.id);
    }

    // 检查是否启用了分屏模式
    if (settingsProvider.enableMultiScreen) {
      // TV 端使用原生分屏播放器
      if (PlatformDetector.isTV && PlatformDetector.isAndroid) {
        final channels = channelProvider.channels;
        
        // 找到当前点击频道的索引
        final clickedIndex = channels.indexWhere((c) => c.url == channel.url);
        
        // 准备频道数据
        final urls = channels.map((c) => c.url).toList();
        final names = channels.map((c) => c.name).toList();
        final groups = channels.map((c) => c.groupName ?? '').toList();
        final sources = channels.map((c) => c.sources).toList();
        final logos = channels.map((c) => c.logoUrl ?? '').toList();
        
        // 启动原生分屏播放器
        NativePlayerChannel.launchMultiScreen(
          urls: urls,
          names: names,
          groups: groups,
          sources: sources,
          logos: logos,
          initialChannelIndex: clickedIndex >= 0 ? clickedIndex : 0,
          volumeBoostDb: settingsProvider.volumeBoost,
          defaultScreenPosition: settingsProvider.defaultScreenPosition,
          onClosed: () {
            debugPrint('HomeScreen: Native multi-screen closed');
          },
        );
      } else if (PlatformDetector.isDesktop) {
        // 桌面端分屏模式：在指定位置播放频道
        final multiScreenProvider = context.read<MultiScreenProvider>();
        final defaultPosition = settingsProvider.defaultScreenPosition;
        // 设置音量增强到分屏Provider
        multiScreenProvider.setVolumeSettings(1.0, settingsProvider.volumeBoost);
        multiScreenProvider.playChannelAtDefaultPosition(channel, defaultPosition);
        
        // 分屏模式下导航到播放器页面，但不传递频道参数（由MultiScreenProvider处理播放）
        Navigator.pushNamed(context, AppRouter.player, arguments: {
          'channelUrl': '', // 空URL表示分屏模式
          'channelName': '',
          'channelLogo': null,
        });
      } else {
        // 其他平台普通播放
        context.read<PlayerProvider>().playChannel(channel);
        Navigator.pushNamed(context, AppRouter.player, arguments: {
          'channelUrl': channel.url,
          'channelName': channel.name,
          'channelLogo': channel.logoUrl,
        });
      }
    } else {
      // 普通模式
      context.read<PlayerProvider>().playChannel(channel);
      Navigator.pushNamed(context, AppRouter.player, arguments: {
        'channelUrl': channel.url,
        'channelName': channel.name,
        'channelLogo': channel.logoUrl,
      });
    }
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
          Text(AppStrings.of(context)?.noPlaylistYet ?? 'No Playlists Yet', style: TextStyle(color: AppTheme.getTextPrimary(context), fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(AppStrings.of(context)?.addM3uToStart ?? 'Add M3U playlist to start watching', style: TextStyle(color: AppTheme.getTextSecondary(context), fontSize: 13)),
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
    final isMobile = PlatformDetector.isMobile;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = isMobile ? 12.0 : 24.0;
        final availableWidth = constraints.maxWidth - horizontalPadding * 2;

        // 计算每个 chip 的大致宽度（图标 + 文字 + padding）
        // 手机端使用更小的估算宽度
        final estimatedChipWidth = isMobile ? 75.0 : 110.0;
        final maxVisibleCount = (availableWidth / estimatedChipWidth).floor();

        // 如果所有分类都能显示，直接用 Wrap
        if (widget.groups.length <= maxVisibleCount || _isExpanded) {
          return _buildExpandedView(isMobile, horizontalPadding);
        }

        // 否则显示部分 + 展开按钮
        return _buildCollapsedView(maxVisibleCount, isMobile, horizontalPadding);
      },
    );
  }

  Widget _buildExpandedView(bool isMobile, double horizontalPadding) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: isMobile ? 6 : 8,
          runSpacing: isMobile ? 6 : 8,
          alignment: WrapAlignment.start,
          children: [
            ...widget.groups.map((group) => _buildChip(group.name, isMobile)),
            if (widget.groups.length > 6) _buildCollapseButton(isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsedView(int maxVisible, bool isMobile, double horizontalPadding) {
    // 至少显示 4 个，留一个位置给展开按钮
    final visibleCount = (maxVisible - 1).clamp(3, widget.groups.length);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: isMobile ? 6 : 8,
          runSpacing: isMobile ? 6 : 8,
          alignment: WrapAlignment.start,
          children: [
            ...widget.groups.take(visibleCount).map((group) => _buildChip(group.name, isMobile)),
            _buildExpandButton(widget.groups.length - visibleCount, isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String name, bool isMobile) {
    return TVFocusable(
      onSelect: () => widget.onGroupTap(name),
      focusScale: 1.0,
      showFocusBorder: false,
      builder: (context, isFocused, child) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12, vertical: isMobile ? 5 : 8),
          decoration: BoxDecoration(
            gradient: isFocused ? AppTheme.lotusGradient : null,
            color: isFocused ? null : AppTheme.getGlassColor(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(color: isFocused ? AppTheme.focusBorderColor : AppTheme.getGlassBorderColor(context)),
          ),
          child: child,
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CategoryCard.getIconForCategory(name), size: isMobile ? 12 : 14, color: AppTheme.getTextSecondary(context)),
          SizedBox(width: isMobile ? 4 : 6),
          Text(name, style: TextStyle(color: AppTheme.getTextSecondary(context), fontSize: isMobile ? 10 : 12)),
        ],
      ),
    );
  }

  Widget _buildExpandButton(int hiddenCount, bool isMobile) {
    return TVFocusable(
      onSelect: () => setState(() => _isExpanded = true),
      focusScale: 1.0,
      showFocusBorder: false,
      builder: (context, isFocused, child) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12, vertical: isMobile ? 5 : 8),
          decoration: BoxDecoration(
            gradient: isFocused ? AppTheme.lotusGradient : null,
            color: isFocused ? null : AppTheme.getGlassColor(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(color: isFocused ? AppTheme.focusBorderColor : AppTheme.getGlassBorderColor(context)),
          ),
          child: child,
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.more_horiz_rounded, size: isMobile ? 12 : 14, color: AppTheme.getTextSecondary(context)),
          SizedBox(width: isMobile ? 3 : 4),
          Text('+$hiddenCount', style: TextStyle(color: AppTheme.getTextSecondary(context), fontSize: isMobile ? 10 : 12)),
        ],
      ),
    );
  }

  Widget _buildCollapseButton(bool isMobile) {
    return TVFocusable(
      onSelect: () => setState(() => _isExpanded = false),
      focusScale: 1.0,
      showFocusBorder: false,
      builder: (context, isFocused, child) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12, vertical: isMobile ? 5 : 8),
          decoration: BoxDecoration(
            gradient: isFocused ? AppTheme.lotusGradient : null,
            color: isFocused ? null : AppTheme.getGlassColor(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(color: isFocused ? AppTheme.focusBorderColor : AppTheme.getGlassBorderColor(context)),
          ),
          child: child,
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.unfold_less_rounded, size: isMobile ? 12 : 14, color: AppTheme.getTextSecondary(context)),
          SizedBox(width: isMobile ? 3 : 4),
          Text(AppStrings.of(context)?.collapse ?? 'Collapse', style: TextStyle(color: AppTheme.getTextSecondary(context), fontSize: isMobile ? 10 : 12)),
        ],
      ),
    );
  }
}

/// 优化的频道卡片组件 - 使用 Selector 精确控制重建
class _OptimizedChannelCard extends StatelessWidget {
  final Channel channel;
  final VoidCallback onTap;

  const _OptimizedChannelCard({
    required this.channel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 使用 Selector 监听收藏状态和 EPG 数据变化
    return Selector2<FavoritesProvider, EpgProvider, _ChannelCardData>(
      selector: (_, favProvider, epgProvider) {
        final currentProgram = epgProvider.getCurrentProgram(channel.epgId, channel.name);
        final nextProgram = epgProvider.getNextProgram(channel.epgId, channel.name);
        return _ChannelCardData(
          isFavorite: favProvider.isFavorite(channel.id ?? 0),
          currentProgram: currentProgram?.title,
          nextProgram: nextProgram?.title,
        );
      },
      builder: (context, data, _) {
        return ChannelCard(
          name: channel.name,
          logoUrl: channel.logoUrl,
          groupName: channel.groupName,
          currentProgram: data.currentProgram,
          nextProgram: data.nextProgram,
          isFavorite: data.isFavorite,
          onFavoriteToggle: () => context.read<FavoritesProvider>().toggleFavorite(channel),
          onTap: onTap,
        );
      },
    );
  }
}

/// 频道卡片数据，用于 Selector 比较
class _ChannelCardData {
  final bool isFavorite;
  final String? currentProgram;
  final String? nextProgram;

  _ChannelCardData({
    required this.isFavorite,
    this.currentProgram,
    this.nextProgram,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _ChannelCardData &&
        other.isFavorite == isFavorite &&
        other.currentProgram == currentProgram &&
        other.nextProgram == nextProgram;
  }

  @override
  int get hashCode => Object.hash(isFavorite, currentProgram, nextProgram);
}

/// 嵌入式频道页面（手机端底部导航用）
class _EmbeddedChannelsScreen extends StatelessWidget {
  const _EmbeddedChannelsScreen();

  @override
  Widget build(BuildContext context) {
    return const ChannelsScreen(embedded: true);
  }
}

/// 嵌入式收藏页面
class _EmbeddedFavoritesScreen extends StatelessWidget {
  const _EmbeddedFavoritesScreen();

  @override
  Widget build(BuildContext context) {
    return const FavoritesScreen(embedded: true);
  }
}

/// 嵌入式搜索页面
class _EmbeddedSearchScreen extends StatelessWidget {
  const _EmbeddedSearchScreen();

  @override
  Widget build(BuildContext context) {
    return const SearchScreen(embedded: true);
  }
}

/// 嵌入式设置页面
class _EmbeddedSettingsScreen extends StatelessWidget {
  const _EmbeddedSettingsScreen();

  @override
  Widget build(BuildContext context) {
    return const SettingsScreen(embedded: true);
  }
}
