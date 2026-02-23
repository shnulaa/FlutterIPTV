import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../../core/widgets/tv_sidebar.dart';
import '../../../core/widgets/category_card.dart';
import '../../../core/widgets/channel_card.dart';
import '../../../core/widgets/channel_logo_widget.dart';
import '../../../core/platform/platform_detector.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/services/update_service.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/models/app_update.dart';
import '../../../core/utils/card_size_calculator.dart';
import '../../../core/utils/throttled_state_mixin.dart'; // ✅ 导入节流 mixin
import '../../channels/providers/channel_provider.dart';
import '../../channels/screens/channels_screen.dart';
import '../../playlist/providers/playlist_provider.dart';
import '../../playlist/widgets/add_playlist_dialog.dart';
import '../../playlist/screens/playlist_list_screen.dart';
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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver, RouteAware, ThrottledStateMixin {
  int _selectedNavIndex = 0;
  List<Channel> _watchHistoryChannels = [];
  int? _lastPlaylistId; // 跟踪上次的播放列表ID
  int _lastChannelCount = 0; // 跟踪上次的频道数量
  String _appVersion = '';
  AppUpdate? _availableUpdate; // 可用的更新
  final ScrollController _scrollController = ScrollController(); // 添加滚动控制器
  final FocusNode _continueButtonFocusNode = FocusNode(); // 继续观看按钮的焦点节点

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // 监听应用生命周期
    _loadData();
    _loadVersion();
    _checkForUpdates();
    // 监听频道变化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChannelProvider>().addListener(_onChannelProviderChanged);
      context.read<PlaylistProvider>().addListener(_onPlaylistProviderChanged);
      context
          .read<FavoritesProvider>()
          .addListener(_onFavoritesProviderChanged);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 注册路由监听
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      AppRouter.routeObserver.subscribe(this, route);
    }
    // 检查是否需要重新加载数据（应用恢复时）
    _checkAndReloadIfNeeded();
  }

  // 当从其他页面返回到此页面时触发
  @override
  void didPopNext() {
    super.didPopNext();
    ServiceLocator.log.i('返回到首页，刷新观看记录', tag: 'HomeScreen');
    _refreshWatchHistory();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // ServiceLocator.log.i('应用生命周期变化: $state', tag: 'HomeScreen');

    // 当应用从后台恢复时，检查并重新加载数据
    if (state == AppLifecycleState.resumed) {
      // ServiceLocator.log.i('应用从后台恢复，检查数据状态', tag: 'HomeScreen');
      _checkAndReloadIfNeeded();
      // 刷新观看记录
      _refreshWatchHistory();
    }
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
    _scrollController.dispose(); // 释放滚动控制器
    _continueButtonFocusNode.dispose(); // 释放焦点节点
    WidgetsBinding.instance.removeObserver(this); // 移除生命周期监听
    AppRouter.routeObserver.unsubscribe(this); // 移除路由监听
    // 移除监听器时需要小心，因为 context 可能已经不可用
    super.dispose();
  }

  void _onChannelProviderChanged() {
    if (!mounted) return;
    final channelProvider = context.read<ChannelProvider>();

    // 当加载完成时刷新推荐频道
    if (!channelProvider.isLoading && channelProvider.channels.isNotEmpty) {
      // 频道数量变化或首次加载时刷新
      if (channelProvider.channels.length != _lastChannelCount ||
          _watchHistoryChannels.isEmpty) {
        _lastChannelCount = channelProvider.channels.length;
        _refreshWatchHistory();
      }
    }
  }

  void _onPlaylistProviderChanged() {
    if (!mounted) return;
    final playlistProvider = context.read<PlaylistProvider>();
    final currentPlaylistId = playlistProvider.activePlaylist?.id;

    // 播放列表ID变化时清空观看记录并重新加载
    if (_lastPlaylistId != currentPlaylistId) {
      _lastPlaylistId = currentPlaylistId;
      _watchHistoryChannels = [];
      _lastChannelCount = 0;

      // ✅ 播放列表切换时，清空缓存并重新加载
      if (currentPlaylistId != null) {
        final channelProvider = context.read<ChannelProvider>();
        ServiceLocator.log.i('播放列表切换，清空缓存并重新加载: $currentPlaylistId', tag: 'HomeScreen');
        
        // 1. 清空 setState 队列
        clearPendingSetState();
        
        // 2. 清空 Provider 缓存和通知队列
        channelProvider.clearCache(); // 清空旧缓存
        channelProvider.clearLogoLoadingQueue(); // 清理旧的台标加载任务
        
        // 3. 加载新数据
        channelProvider.loadAllChannelsToCache(currentPlaylistId);
      }
    }

    // 当播放列表刷新完成时（isLoading 从 true 变为 false），触发频道重新加载
    // 这样可以确保刷新 M3U 后首页能正确更新
    if (!playlistProvider.isLoading && playlistProvider.hasPlaylists) {
      final channelProvider = context.read<ChannelProvider>();
      final favoritesProvider = context.read<FavoritesProvider>();
      final currentId = playlistProvider.activePlaylist?.id;
      
      // ✅ 如果频道列表为空或数量不对，重新加载首页数据
      if (!channelProvider.isLoading && currentId != null) {
        // 检查是否需要重新加载（频道为空，或者频道数量明显不对）
        if (channelProvider.channels.isEmpty) {
          ServiceLocator.log.i('播放列表刷新完成，频道为空，重新加载', tag: 'HomeScreen');
          
          // 1. 清空 setState 队列
          clearPendingSetState();
          
          // 2. 清空 Provider 缓存和通知队列
          channelProvider.clearCache(); // 清空缓存
          channelProvider.clearLogoLoadingQueue(); // 清理旧的台标加载任务
          
          // 3. 重新加载频道
          channelProvider.loadAllChannelsToCache(currentId);
        }
        
        // ✅ 播放列表刷新后，重新加载收藏夹和观看记录
        ServiceLocator.log.i('播放列表刷新完成，重新加载收藏夹和观看记录', tag: 'HomeScreen');
        favoritesProvider.loadFavorites();
        _refreshWatchHistory();
      }
    }
  }

  void _onFavoritesProviderChanged() {
    if (!mounted) return;
    // 收藏状态变化时刷新观看记录
    _refreshWatchHistory();
  }

  /// 检查并在需要时重新加载数据（处理应用恢复场景）
  void _checkAndReloadIfNeeded() {
    final playlistProvider = context.read<PlaylistProvider>();
    final channelProvider = context.read<ChannelProvider>();

    // 如果播放列表已加载但频道列表为空，说明可能是应用恢复后状态丢失
    if (playlistProvider.hasPlaylists &&
        !playlistProvider.isLoading &&
        channelProvider.channels.isEmpty &&
        !channelProvider.isLoading) {
      ServiceLocator.log.w('检测到数据状态异常：播放列表存在但频道为空，重新加载', tag: 'HomeScreen');
      final activePlaylist = playlistProvider.activePlaylist;
      if (activePlaylist?.id != null) {
        channelProvider.loadAllChannelsToCache(activePlaylist!.id!);
      }
    }
  }

  Future<void> _loadData() async {
    ServiceLocator.log.i('开始加载首页数据', tag: 'HomeScreen');
    final startTime = DateTime.now();

    final playlistProvider = context.read<PlaylistProvider>();
    final channelProvider = context.read<ChannelProvider>();
    final favoritesProvider = context.read<FavoritesProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final epgProvider = context.read<EpgProvider>();

    // 如果播放列表为空，先加载播放列表
    if (!playlistProvider.hasPlaylists) {
      ServiceLocator.log.w('播放列表为空，重新加载', tag: 'HomeScreen');
      await playlistProvider.loadPlaylists();
    }

    if (playlistProvider.hasPlaylists) {
      final activePlaylist = playlistProvider.activePlaylist;
      _lastPlaylistId = activePlaylist?.id;
      ServiceLocator.log.d(
          '活动播放列表: ${activePlaylist?.name} (ID: ${activePlaylist?.id})',
          tag: 'HomeScreen');

      if (activePlaylist != null && activePlaylist.id != null) {
        ServiceLocator.log
            .d('首页加载: 加载所有频道到缓存', tag: 'HomeScreen');
        // ✅ 加载所有频道到全局缓存
        await channelProvider.loadAllChannelsToCache(activePlaylist.id!);
      } else {
        ServiceLocator.log.d('加载所有频道', tag: 'HomeScreen');
        await channelProvider.loadAllChannels();
      }

      ServiceLocator.log.d('加载收藏列表', tag: 'HomeScreen');
      await favoritesProvider.loadFavorites();
      _refreshWatchHistory();

      final loadTime = DateTime.now().difference(startTime).inMilliseconds;
      ServiceLocator.log.i(
          '首页数据加载完成，耗时: ${loadTime}ms，频道数: ${channelProvider.channels.length}',
          tag: 'HomeScreen');

      // 加载 EPG（使用播放列表的 EPG URL，如果失败则使用设置中的兜底 URL）
      ServiceLocator.log.d(
          'HomeScreen: 检查 EPG 加载条件 - activePlaylist.epgUrl=${activePlaylist?.epgUrl}, settingsProvider.epgUrl=${settingsProvider.epgUrl}');
      print(
          'HomeScreen: 检查 EPG 加载条件 - activePlaylist.epgUrl=${activePlaylist?.epgUrl}, settingsProvider.epgUrl=${settingsProvider.epgUrl}');
      if (activePlaylist?.epgUrl != null &&
          activePlaylist!.epgUrl!.isNotEmpty) {
        ServiceLocator.log
            .d('HomeScreen: 初始加载播放列表的 EPG URL: ${activePlaylist.epgUrl}');
        // Background loading - don't block UI
        await epgProvider.loadEpg(
          activePlaylist.epgUrl!,
          fallbackUrl: settingsProvider.epgUrl,
          silent: true,
        );
      } else if (settingsProvider.epgUrl != null &&
          settingsProvider.epgUrl!.isNotEmpty) {
        ServiceLocator.log
            .d('HomeScreen: 初始加载设置中的兜底 EPG URL: ${settingsProvider.epgUrl}');
        // Background loading - don't block UI
        await epgProvider.loadEpg(settingsProvider.epgUrl!, silent: true);
      } else {
        ServiceLocator.log.d('HomeScreen: 没有可用的 EPG URL（播放列表和设置中都没有配置）');
      }

      // 自动播放功能：数据加载完成后延迟500ms自动播放
      if (settingsProvider.autoPlay && mounted) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;

          // 获取上次播放状态
          final isMultiScreenMode = settingsProvider.lastPlayMode == 'multi' &&
              settingsProvider.hasMultiScreenState;
          Channel? lastChannel;

          if (settingsProvider.rememberLastChannel &&
              settingsProvider.lastChannelId != null) {
            try {
              lastChannel = channelProvider.channels.firstWhere(
                (c) => c.id == settingsProvider.lastChannelId,
              );
            } catch (_) {
              // 频道不存在，使用第一个频道
              lastChannel = channelProvider.channels.isNotEmpty
                  ? channelProvider.channels.first
                  : null;
            }
          } else {
            lastChannel = channelProvider.channels.isNotEmpty
                ? channelProvider.channels.first
                : null;
          }

          // 自动触发继续播放
          if (lastChannel != null || isMultiScreenMode) {
            ServiceLocator.log.d(
                'HomeScreen: Auto-play triggered - isMultiScreen=$isMultiScreenMode');
            _continuePlayback(channelProvider, lastChannel, isMultiScreenMode,
                settingsProvider);
          }
        });
      }
    }
  }

  void _refreshWatchHistory() async {
    if (!mounted) return;

    final playlistProvider = context.read<PlaylistProvider>();
    final activePlaylist = playlistProvider.activePlaylist;
    
    if (activePlaylist?.id == null) {
      if (_watchHistoryChannels.isNotEmpty) {
        throttledSetState(() {
          _watchHistoryChannels = [];
        });
      }
      return;
    }

    // 异步加载观看记录
    ServiceLocator.watchHistory.getWatchHistory(activePlaylist!.id!, limit: 20).then((history) {
      if (mounted) {
        throttledSetState(() {
          _watchHistoryChannels = history;
        });
      }
    }).catchError((e) {
      ServiceLocator.log.e('加载观看记录失败: $e', tag: 'HomeScreen');
      if (mounted) {
        throttledSetState(() {
          _watchHistoryChannels = [];
        });
      }
    });
  }

  List<_NavItem> _getNavItems(BuildContext context) {
    final strings = AppStrings.of(context);
    return [
      _NavItem(icon: Icons.home_rounded, label: strings?.home ?? 'Home'),
      _NavItem(
          icon: Icons.live_tv_rounded, label: strings?.channels ?? 'Channels'),
      _NavItem(
          icon: Icons.playlist_play_rounded,
          label: strings?.playlistList ?? 'Sources'),
      _NavItem(
          icon: Icons.favorite_rounded,
          label: strings?.favorites ?? 'Favorites'),
      _NavItem(
          icon: Icons.search_rounded,
          label: strings?.searchChannels ?? 'Search'),
      _NavItem(
          icon: Icons.settings_rounded, label: strings?.settings ?? 'Settings'),
    ];
  }

  void _onNavItemTap(int index) {
    if (index == _selectedNavIndex) return;

    // 切换页面时清理台标加载队列
    clearLogoLoadingQueue();

    immediateSetState(() => _selectedNavIndex = index); // 立即更新导航
    
    // ✅ 切换到首页时不需要重新加载（使用缓存数据）
    if (index == 0) {
      _refreshWatchHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTV = PlatformDetector.isTV || size.width > 1200;

    if (isTV) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: Theme.of(context).brightness == Brightness.dark
                  ? [
                      AppTheme.getBackgroundColor(context),
                      AppTheme.getPrimaryColor(context).withOpacity(0.15),
                      AppTheme.getBackgroundColor(context),
                    ]
                  : [
                      AppTheme.getBackgroundColor(context),
                      AppTheme.getBackgroundColor(context).withOpacity(0.9),
                      AppTheme.getPrimaryColor(context).withOpacity(0.08),
                    ],
            ),
          ),
          child: TVSidebar(
            selectedIndex: 0,
            child: _buildMainContent(context),
          ),
        ),
      );
    }

    // 手机端使用底部导航栏切换页面
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.getBackgroundColor(context),
              AppTheme.getBackgroundColor(context).withOpacity(0.8),
              AppTheme.getPrimaryColor(context).withOpacity(0.05),
            ],
          ),
        ),
        // 确保内容从顶部开始
        alignment: Alignment.topCenter,
        child: _buildMobileBody(),
      ),
      bottomNavigationBar: _buildBottomNav(context),
      // 添加屏幕方向切换悬浮按钮（仅手机端）
      floatingActionButton:
          PlatformDetector.isMobile ? _buildOrientationFab() : null,
    );
  }

  /// 构建屏幕方向切换悬浮按钮
  Widget _buildOrientationFab() {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        final orientation = settings.mobileOrientation;
        IconData icon;
        String tooltip;

        // 只显示当前状态，不显示下一个状态
        switch (orientation) {
          case 'landscape':
            icon = Icons.screen_rotation_rounded;
            tooltip = '横屏模式';
            break;
          case 'portrait':
          default:
            icon = Icons.stay_current_portrait_rounded;
            tooltip = '竖屏模式';
            break;
        }

        return FloatingActionButton(
          mini: true,
          backgroundColor: AppTheme.getSurfaceColor(context).withOpacity(0.9),
          onPressed: () => _toggleOrientation(settings),
          tooltip: tooltip,
          child: Icon(icon, color: AppTheme.getPrimaryColor(context), size: 20),
        );
      },
    );
  }

  /// 切换屏幕方向（只在横屏和竖屏之间切换）
  Future<void> _toggleOrientation(SettingsProvider settings) async {
    String newOrientation;
    List<DeviceOrientation> orientations;
    String message;

    // 只在横屏和竖屏之间切换
    if (settings.mobileOrientation == 'portrait') {
      newOrientation = 'landscape';
      orientations = [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ];
      message = '已切换到横屏模式';
    } else {
      newOrientation = 'portrait';
      orientations = [
        DeviceOrientation.portraitUp,
      ];
      message = '已切换到竖屏模式';
    }

    await settings.setMobileOrientation(newOrientation);
    await SystemChrome.setPreferredOrientations(orientations);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Widget _buildMobileBody() {
    switch (_selectedNavIndex) {
      case 0:
        return _buildMainContent(context);
      case 1:
        return const _EmbeddedChannelsScreen();
      case 2:
        return const _EmbeddedPlaylistListScreen();
      case 3:
        return const _EmbeddedFavoritesScreen();
      case 4:
        return const _EmbeddedSearchScreen();
      case 5:
        return const _EmbeddedSettingsScreen();
      default:
        return _buildMainContent(context);
    }
  }

  Widget _buildBottomNav(BuildContext context) {
    final navItems = _getNavItems(context);
    return Container(
      decoration: BoxDecoration(
          color: AppTheme.getSurfaceColor(context),
          border: const Border(
              top: BorderSide(color: Color(0x1AFFFFFF), width: 1))),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(navItems.length, (index) {
              final item = navItems[index];
              final isSelected = _selectedNavIndex == index;
              return GestureDetector(
                onTap: () => _onNavItemTap(index),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                      gradient:
                          isSelected ? AppTheme.getGradient(context) : null,
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill)),
                  child: Icon(item.icon,
                      color: isSelected
                          ? Colors.white
                          : AppTheme.getTextMuted(context),
                      size: 22),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    return Consumer3<PlaylistProvider, ChannelProvider, SettingsProvider>(
      builder: (context, playlistProvider, channelProvider, settingsProvider, _) {
        if (!playlistProvider.hasPlaylists) return _buildEmptyState();

        // 播放列表正在刷新时显示加载状态
        if (playlistProvider.isLoading) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor));
        }

        // ✅ 首页使用独立的加载状态
        if (channelProvider.isLoading) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor));
        }

        // 如果播放列表已加载但首页数据为空，显示空状态并提供操作按钮
        if (playlistProvider.hasPlaylists && channelProvider.allChannels.isEmpty) {
          // 使用 addPostFrameCallback 避免在 build 期间调用 setState
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !channelProvider.isLoading) {
              ServiceLocator.log.d('HomeScreen: 频道列表为空，触发数据重新加载');
              final activePlaylist = playlistProvider.activePlaylist;
              if (activePlaylist?.id != null) {
                channelProvider.loadAllChannelsToCache(activePlaylist!.id!);
              }
            }
          });
          // 显示空状态UI，包含操作按钮
          return _buildEmptyChannelsState(playlistProvider);
        }

        final favChannels = _getFavoriteChannels(channelProvider);
        
        // ✅ 获取首页数据（显示前8个分类）
        final homeChannelsByGroup = channelProvider.getHomeChannelsByGroup(maxGroups: 8, channelsPerGroup: 12);
        final homeGroups = channelProvider.getHomeGroups(maxGroups: 8);

        return Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 固定头部
            _buildCompactHeader(channelProvider),
            // 固定分类标签（横屏时隐藏）
            if (MediaQuery.of(context).size.width <= 700 ||
                !PlatformDetector.isMobile)
              _buildCategoryChips(channelProvider),
            SizedBox(
                height: PlatformDetector.isMobile &&
                        MediaQuery.of(context).size.width > 700
                    ? 0
                    : (PlatformDetector.isMobile ? 2 : 16)), // 横屏时间距为0
            // 可滚动的频道列表
            Expanded(
              child: CustomScrollView(
                controller: _scrollController, // 添加滚动控制器
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                        horizontal: PlatformDetector.isMobile ? 12 : 24),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // 观看记录排在第一个（如果设置中启用且有记录）
                        if (settingsProvider.showWatchHistoryOnHome && _watchHistoryChannels.isNotEmpty) ...[
                          _buildChannelRow(
                              AppStrings.of(context)?.watchHistory ?? 'Watch History',
                              _watchHistoryChannels,
                              isFirstRow: true), // 观看记录是第一行
                          SizedBox(height: PlatformDetector.isMobile ? 8 : 12),
                        ],
                        // 收藏夹排在第二个（如果设置中启用且有收藏）
                        if (settingsProvider.showFavoritesOnHome && favChannels.isNotEmpty) ...[
                          _buildChannelRow(
                              AppStrings.of(context)?.myFavorites ?? 'My Favorites',
                              favChannels,
                              showMore: true,
                              onMoreTap: () => Navigator.pushNamed(context, AppRouter.favorites),
                              isFirstRow: !settingsProvider.showWatchHistoryOnHome || _watchHistoryChannels.isEmpty), // 如果观看记录不显示或为空，收藏夹是第一行
                          SizedBox(height: PlatformDetector.isMobile ? 8 : 12),
                        ],
                        // ✅ 使用首页数据显示分类和频道
                        ...homeGroups.asMap().entries.map((entry) {
                          final index = entry.key;
                          final group = entry.value;
                          // ✅ 直接从首页数据中获取该分类的频道
                          final channels = homeChannelsByGroup[group.name] ?? [];
                          
                          // ✅ 如果该分类没有频道，跳过不显示
                          if (channels.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          
                          // 判断是否是第一行：观看记录和收藏夹都不显示时，第一个分类是第一行
                          final isFirst = index == 0 && 
                              (!settingsProvider.showWatchHistoryOnHome || _watchHistoryChannels.isEmpty) && 
                              (!settingsProvider.showFavoritesOnHome || favChannels.isEmpty);
                          return Padding(
                            padding: EdgeInsets.only(
                                bottom: PlatformDetector.isMobile ? 8 : 12),
                            child: _buildChannelRow(
                              group.name,
                              channels,
                              showMore: true,
                              onMoreTap: () => Navigator.pushNamed(
                                  context, AppRouter.channels,
                                  arguments: {'groupName': group.name}),
                              isFirstRow: isFirst,
                            ),
                          );
                        }),
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
    final bool isMultiScreenMode = settingsProvider.lastPlayMode == 'multi' &&
        settingsProvider.hasMultiScreenState;

    // ServiceLocator.log.d(
    //     'HomeScreen: lastPlayMode=${settingsProvider.lastPlayMode}, hasMultiScreenState=${settingsProvider.hasMultiScreenState}, isMultiScreenMode=$isMultiScreenMode');
    // ServiceLocator.log.d(
    //     'HomeScreen: lastMultiScreenChannels=${settingsProvider.lastMultiScreenChannels}');

    if (settingsProvider.rememberLastChannel &&
        settingsProvider.lastChannelId != null) {
      try {
        lastChannel = provider.channels.firstWhere(
          (c) => c.id == settingsProvider.lastChannelId,
        );
      } catch (_) {
        // 频道不存在，使用第一个频道
        lastChannel =
            provider.channels.isNotEmpty ? provider.channels.first : null;
      }
    } else {
      lastChannel =
          provider.channels.isNotEmpty ? provider.channels.first : null;
    }

    // 构建播放列表信息
    String playlistInfo = '';
    if (activePlaylist != null) {
      final type = activePlaylist.isRemote ? 'URL' : '本地';
      playlistInfo = ' · [$type] ${activePlaylist.name}';
      if (activePlaylist.url != null && activePlaylist.url!.isNotEmpty) {
        String url =
            activePlaylist.url!.replaceFirst(RegExp(r'^https?://'), '');
        if (url.length > 30) {
          url = '${url.substring(0, 30)}...';
        }
        playlistInfo += ' · $url';
      }
    }

    // 继续播放按钮 - 名字固定为 "Continue"，不根据模式变化
    final continueLabel =
        AppStrings.of(context)?.continueWatching ?? 'Continue';
    final isMobile = PlatformDetector.isMobile;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLandscape = isMobile && screenWidth > 700; // 手机端横屏

    // 手机端获取状态栏高度，并减少一些间距让内容更靠近状态栏
    final statusBarHeight = isMobile ? MediaQuery.of(context).padding.top : 0.0;
    final topPadding = isMobile
        ? (statusBarHeight > 0 ? statusBarHeight - 10.0 : 0.0)
        : 16.0; // 状态栏高度 + 4px

    return Container(
      // 手机端添加状态栏高度的padding，其他平台使用SafeArea
      padding: EdgeInsets.fromLTRB(
          isMobile ? 12 : 24,
          topPadding, // 使用计算后的顶部间距
          isMobile ? 12 : 24,
          isMobile ? 2 : 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppTheme.getGradient(context).createShader(bounds),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('Lotus IPTV',
                          style: TextStyle(
                              fontSize: isLandscape ? 16 : (isMobile ? 18 : 28),
                              fontWeight: FontWeight.bold,
                              color: Colors.white)), // 横屏16，竖屏18
                      const SizedBox(width: 8),
                      Text('v$_appVersion',
                          style: TextStyle(
                              fontSize: isLandscape ? 10 : (isMobile ? 11 : 11),
                              fontWeight: FontWeight.normal,
                              color: Colors.white70)), // 横屏12，竖屏13，桌面14
                      if (_availableUpdate != null) ...[
                        const SizedBox(width: 8),
                        TVFocusable(
                          onSelect: () => Navigator.pushNamed(
                              context, AppRouter.settings,
                              arguments: {'autoCheckUpdate': true}),
                          focusScale: 1.0,
                          showFocusBorder: false,
                          builder: (context, isFocused, child) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                gradient: isFocused
                                    ? AppTheme.getGradient(context)
                                    : LinearGradient(
                                        colors: [
                                          Colors.orange.shade600,
                                          Colors.deepOrange.shade600
                                        ],
                                      ),
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusPill),
                                border: isFocused
                                    ? Border.all(
                                        color:
                                            AppTheme.getPrimaryColor(context),
                                        width: 2)
                                    : null,
                              ),
                              child: child,
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.system_update_rounded,
                                  size: 10, color: Colors.white),
                              const SizedBox(width: 3),
                              Text('v${_availableUpdate!.version}',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // 手机端横屏时隐藏副标题，节省空间
                if (!isMobile || MediaQuery.of(context).size.width <= 700) ...[
                  SizedBox(height: isMobile ? 2 : 4),
                  Text(
                    '${provider.totalChannelCount} ${AppStrings.of(context)?.channels ?? "频道"} · ${provider.groups.length} ${AppStrings.of(context)?.categories ?? "分类"} · ${context.watch<FavoritesProvider>().count} ${AppStrings.of(context)?.favorites ?? "收藏"}$playlistInfo',
                    style: TextStyle(
                        color: AppTheme.getTextMuted(context), fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
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
                      ? () => _continuePlayback(provider, lastChannel,
                          isMultiScreenMode, settingsProvider)
                      : null,
                  focusNode: _continueButtonFocusNode), // 添加焦点节点
              SizedBox(width: isMobile ? 6 : 10),
              _buildHeaderButton(
                  Icons.playlist_add_rounded,
                  AppStrings.of(context)?.playlists ?? 'Playlists',
                  false,
                  () => _showAddPlaylistDialog()),
              SizedBox(width: isMobile ? 6 : 10),
              _buildHeaderButton(
                  Icons.refresh_rounded,
                  AppStrings.of(context)?.refresh ?? 'Refresh',
                  false,
                  activePlaylist != null
                      ? () =>
                          _refreshCurrentPlaylist(playlistProvider, provider)
                      : null),
              SizedBox(width: isMobile ? 6 : 10),
              _buildThemeToggleButton(),
            ],
          ),
        ],
      ),
    );
  }

  /// 继续播放 - 支持单频道和分屏模式
  void _continuePlayback(ChannelProvider provider, Channel? lastChannel,
      bool isMultiScreenMode, SettingsProvider settingsProvider) {
    ServiceLocator.log
        .i('继续播放 - 模式: ${isMultiScreenMode ? "分屏" : "单频道"}', tag: 'HomeScreen');

    if (isMultiScreenMode) {
      // 恢复分屏模式
      _resumeMultiScreen(provider, settingsProvider);
    } else if (lastChannel != null) {
      // 恢复单频道播放
      ServiceLocator.log.d('恢复单频道播放: ${lastChannel.name}', tag: 'HomeScreen');
      _playChannel(lastChannel);
    }
  }

  /// 显示添加播放列表对话框
  Future<void> _showAddPlaylistDialog() async {
    final result = PlatformDetector.isMobile
        ? await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const AddPlaylistDialog(),
          )
        : await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => const AddPlaylistDialog(),
          );

    // 如果成功添加了播放列表，刷新数据
    if (result == true && mounted) {
      _loadData();
    }
  }

  /// 刷新当前播放列表
  Future<void> _refreshCurrentPlaylist(PlaylistProvider playlistProvider,
      ChannelProvider channelProvider) async {
    ServiceLocator.log.i('开始刷新当前播放列表（后台模式）', tag: 'HomeScreen');

    final activePlaylist = playlistProvider.activePlaylist;
    if (activePlaylist == null) {
      ServiceLocator.log.w('没有活动播放列表，无法刷新', tag: 'HomeScreen');
      return;
    }

    if (!mounted) return;

    // Use unified refresh method with callback (silent mode for background refresh)
    await playlistProvider.refreshPlaylistWithCallback(
      playlist: activePlaylist,
      context: context,
      silent: true,
      onComplete: (success, error) async {
        if (!mounted) return;

        if (success) {
          // Reload channels
          if (activePlaylist.id != null) {
            await channelProvider.loadChannels(activePlaylist.id!);
            
            // Clear logo cache
            clearAllLogoCache();
            
            // Refresh watch history
            _refreshWatchHistory();

            // Reload EPG
            final epgProvider = context.read<EpgProvider>();
            final settingsProvider = context.read<SettingsProvider>();

            await playlistProvider.loadPlaylists();
            final updatedPlaylist = playlistProvider.activePlaylist;

            if (updatedPlaylist?.epgUrl != null) {
              ServiceLocator.log.d(
                  'HomeScreen: 使用播放列表的 EPG URL 重新加载: ${updatedPlaylist!.epgUrl}',
                  tag: 'HomeScreen');
              // Background loading - don't block UI
              await epgProvider.loadEpg(
                updatedPlaylist.epgUrl!,
                fallbackUrl: settingsProvider.epgUrl,
                silent: true,
              );
            } else if (settingsProvider.epgUrl != null) {
              ServiceLocator.log.d(
                  'HomeScreen: 使用设置中的兜底 EPG URL 重新加载: ${settingsProvider.epgUrl}',
                  tag: 'HomeScreen');
              // Background loading - don't block UI
              await epgProvider.loadEpg(settingsProvider.epgUrl!, silent: true);
            }
          }
        }
      },
    );
  }

  /// 恢复分屏播放
  Future<void> _resumeMultiScreen(
      ChannelProvider provider, SettingsProvider settingsProvider) async {
    ServiceLocator.log.i('开始恢复分屏播放', tag: 'HomeScreen');

    final channels = provider.channels;
    final multiScreenChannelIds = settingsProvider.lastMultiScreenChannels;
    final multiScreenSourceIndexes = settingsProvider.lastMultiScreenSourceIndexes;
    final activeIndex = settingsProvider.activeScreenIndex;

    ServiceLocator.log.d('分屏频道ID: $multiScreenChannelIds', tag: 'HomeScreen');
    ServiceLocator.log.d('活动屏幕索引: $activeIndex', tag: 'HomeScreen');

    // 设置 providers 用于状态保存
    final favoritesProvider = context.read<FavoritesProvider>();
    NativePlayerChannel.setProviders(
        favoritesProvider, provider, settingsProvider);

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

    ServiceLocator.log.d('恢复屏幕频道: $restoreScreenChannels', tag: 'HomeScreen');

    // 检查是否是 Android TV，使用原生分屏
    if (PlatformDetector.isAndroid) {
      ServiceLocator.log.d('使用 Android TV 原生分屏', tag: 'HomeScreen');
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
        showChannelName: settingsProvider.showMultiScreenChannelName,
        onClosed: () {
          ServiceLocator.log.i('原生分屏播放器关闭，刷新观看记录', tag: 'HomeScreen');
          // TV端原生分屏播放器关闭后，刷新观看记录
          _refreshWatchHistory();
        },
      );
      ServiceLocator.log.i('原生分屏播放器启动成功', tag: 'HomeScreen');
    } else {
      // Windows/其他平台使用 Flutter 分屏
      ServiceLocator.log.d('使用 Flutter 分屏', tag: 'HomeScreen');
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
          final sourceIndex =
              (i < multiScreenSourceIndexes.length ? multiScreenSourceIndexes[i] : 0)
                  .clamp(0, channel.sourceCount - 1);
          final restoredChannel =
              channel.copyWith(currentSourceIndex: sourceIndex);
          // 播放频道到对应屏幕
          futures.add(multiScreenProvider.playChannelOnScreen(i, restoredChannel));
        }
      }

      // 等待所有频道开始播放
      await Future.wait(futures);

      ServiceLocator.log.d('所有分屏频道加载完成', tag: 'HomeScreen');

      // 等待一小段时间确保所有播放器都已经开始播放
      await Future.delayed(const Duration(milliseconds: 500));

      // 所有频道加载完成后，重新应用音量设置确保只有活动屏幕有声音
      await multiScreenProvider.reapplyVolumeToAllScreens();

      ServiceLocator.log.i('Flutter 分屏播放恢复成功', tag: 'HomeScreen');

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

  Widget _buildHeaderButton(
      IconData icon, String label, bool isPrimary, VoidCallback? onTap, {FocusNode? focusNode}) {
    final isMobile = PlatformDetector.isMobile;
    return TVFocusable(
      focusNode: focusNode, // 添加focusNode参数
      onSelect: onTap,
      focusScale: 1.0,
      showFocusBorder: false,
      builder: (context, isFocused, child) {
        return Container(
          padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 8 : 14, vertical: isMobile ? 6 : 8),
          decoration: BoxDecoration(
            gradient:
                isPrimary || isFocused ? AppTheme.getGradient(context) : null,
            color:
                isPrimary || isFocused ? null : AppTheme.getGlassColor(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(
                color: isFocused
                    ? AppTheme.getPrimaryColor(context)
                    : AppTheme.getGlassBorderColor(context),
                width: isFocused ? 2 : 1),
          ),
          child: child,
        );
      },
      child: Builder(
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final textColor = isPrimary
              ? Colors.white
              : (isDark ? Colors.white : AppTheme.textPrimaryLight);
          // 手机端只显示图标，节省空间
          if (isMobile) {
            return Icon(icon, color: textColor, size: 16);
          }
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: textColor, size: 16),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildThemeToggleButton() {
    final settingsProvider = context.watch<SettingsProvider>();
    final isDarkMode = settingsProvider.themeMode == 'dark';
    final isMobile = PlatformDetector.isMobile;

    return TVFocusable(
      onSelect: () {
        // 切换黑暗/明亮模式
        settingsProvider.setThemeMode(isDarkMode ? 'light' : 'dark');
      },
      focusScale: 1.0,
      showFocusBorder: false,
      builder: (context, isFocused, child) {
        return Container(
          padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 8 : 14, vertical: isMobile ? 6 : 8),
          decoration: BoxDecoration(
            color: isFocused
                ? AppTheme.getGlassColor(context)
                : AppTheme.getGlassColor(context).withOpacity(0.5),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(
                color: isFocused
                    ? AppTheme.getPrimaryColor(context)
                    : AppTheme.getGlassBorderColor(context),
                width: isFocused ? 2 : 1),
          ),
          child: child,
        );
      },
      child: Builder(
        builder: (context) {
          final themeIsDark = Theme.of(context).brightness == Brightness.dark;
          final textColor =
              themeIsDark ? Colors.white : AppTheme.textPrimaryLight;

          // 手机端只显示图标
          if (isMobile) {
            return Icon(
                isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: textColor,
                size: 16);
          }

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                  isDarkMode
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
                  color: textColor,
                  size: 16),
              const SizedBox(width: 6),
              Text(
                  isDarkMode
                      ? (AppStrings.of(context)?.themeLight ?? '明亮')
                      : (AppStrings.of(context)?.themeDark ?? '深色'),
                  style: TextStyle(
                      color: textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCategoryChips(ChannelProvider provider) {
    return _ResponsiveCategoryChips(
      groups: provider.getHomeGroups(maxGroups: 8), // ✅ 使用首页独立数据
      onGroupTap: (groupName) => Navigator.pushNamed(
          context, AppRouter.channels,
          arguments: {'groupName': groupName}),
    );
  }

  Widget _buildChannelRow(String title, List<Channel> channels,
      {bool showMore = false,
      VoidCallback? onMoreTap,
      bool isFirstRow = false}) { // 添加isFirstRow参数
    if (channels.isEmpty) return const SizedBox.shrink();
    final isMobile = PlatformDetector.isMobile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title,
                style: TextStyle(
                    color: AppTheme.getTextPrimary(context),
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            if (showMore)
              TVFocusable(
                onSelect: onMoreTap,
                focusScale: 1.0,
                showFocusBorder: false,
                builder: (context, isFocused, child) {
                  return Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 8 : 10,
                        vertical: isMobile ? 4 : 5),
                    decoration: BoxDecoration(
                      gradient:
                          isFocused ? AppTheme.getGradient(context) : null,
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    ),
                    child: child,
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(AppStrings.of(context)?.more ?? 'More',
                        style: TextStyle(
                            color: AppTheme.getTextMuted(context),
                            fontSize: isMobile ? 10 : 12)),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded,
                        color: AppTheme.getTextMuted(context),
                        size: isMobile ? 14 : 16),
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

            final availableWidth = constraints.maxWidth;
            // 首页使用专门的计算方法，显示更多更小的卡片
            final cardsPerRow =
                CardSizeCalculator.calculateHomeCardsPerRow(availableWidth);
            final cardSpacing = CardSizeCalculator.spacing;
            final totalSpacing = (cardsPerRow - 1) * cardSpacing;
            final cardWidth = (availableWidth - totalSpacing) / cardsPerRow;
            final cardHeight = cardWidth / CardSizeCalculator.aspectRatio();

            // 显示数量不能超过实际频道数量
            final displayCount = cardsPerRow.clamp(1, channels.length);

            return SizedBox(
              height: cardHeight,
              child: Row(
                children: List.generate(displayCount, (index) {
                  final channel = channels[index];

                  return Padding(
                    padding: EdgeInsets.only(
                        right: index < displayCount - 1 ? cardSpacing : 0),
                    child: SizedBox(
                      width: cardWidth,
                      child: _OptimizedChannelCard(
                        channel: channel,
                        onTap: () => _playChannel(channel),
                        onUp: isFirstRow && PlatformDetector.isTV
                            ? () {
                                // TV端第一行（观看历史）按上键时，跳转到"继续观看"按钮
                                if (_scrollController.hasClients && _scrollController.offset > 0) {
                                  // 如果不在顶部，先滚动到顶部
                                  _scrollController.animateTo(
                                    0,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOut,
                                  );
                                }
                                // 请求"继续观看"按钮的焦点
                                _continueButtonFocusNode.requestFocus();
                              }
                            : null,
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

  Future<void> _playChannel(Channel channel) async {
    ServiceLocator.log
        .i('播放频道: ${channel.name} (ID: ${channel.id})', tag: 'HomeScreen');
    // final startTime = DateTime.now();

    // 保存上次播放的频道ID
    final settingsProvider = context.read<SettingsProvider>();
    final channelProvider = context.read<ChannelProvider>();
    final favoritesProvider = context.read<FavoritesProvider>();

    // 设置 providers 用于状态保存和收藏功能
    NativePlayerChannel.setProviders(
        favoritesProvider, channelProvider, settingsProvider);

    if (settingsProvider.rememberLastChannel && channel.id != null) {
      // 保存单频道播放状态
      settingsProvider.saveLastSingleChannel(channel.id);
    }

    // 检查是否启用了分屏模式
    if (settingsProvider.enableMultiScreen) {
      // TV 端使用原生分屏播放器
      if (PlatformDetector.isTV && PlatformDetector.isAndroid) {
        // ✅ 直接使用缓存的所有频道数据
        final channels = channelProvider.allChannels;

        // 找到当前点击频道的索引
        final clickedIndex = channels.indexWhere((c) => c.url == channel.url);

        // TV端原生分屏播放器也需要记录观看历史
        if (channel.id != null && channel.playlistId != null) {
          await ServiceLocator.watchHistory.addWatchHistory(channel.id!, channel.playlistId!);
          ServiceLocator.log.d('HomeScreen: Recorded watch history for channel ${channel.name} (TV multi-screen)');
        }

        // 准备频道数据
        final urls = channels.map((c) => c.url).toList();
        final names = channels.map((c) => c.name).toList();
        final groups = channels.map((c) => c.groupName ?? '').toList();
        final sources = channels.map((c) => c.sources).toList();
        final logos = channels.map((c) => c.logoUrl ?? '').toList();

        // 启动原生分屏播放器
        await NativePlayerChannel.launchMultiScreen(
          urls: urls,
          names: names,
          groups: groups,
          sources: sources,
          logos: logos,
          initialChannelIndex: clickedIndex >= 0 ? clickedIndex : 0,
          volumeBoostDb: settingsProvider.volumeBoost,
          defaultScreenPosition: settingsProvider.defaultScreenPosition,
          showChannelName: settingsProvider.showMultiScreenChannelName,
          onClosed: () {
            ServiceLocator.log.d('HomeScreen: Native multi-screen closed, refreshing watch history');
            // TV端原生分屏播放器关闭后，刷新观看记录
            _refreshWatchHistory();
          },
        );
      } else if (PlatformDetector.isDesktop) {
        // 桌面端分屏模式：在指定位置播放频道
        final multiScreenProvider = context.read<MultiScreenProvider>();
        final defaultPosition = settingsProvider.defaultScreenPosition;
        // 设置音量增强到分屏Provider
        multiScreenProvider.setVolumeSettings(
            1.0, settingsProvider.volumeBoost);
        multiScreenProvider.playChannelAtDefaultPosition(
            channel, defaultPosition);

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
      // 普通模式：直接导航到播放器页面，不调用PlayerProvider.playChannel()
      // 避免重复记录观看历史（PlayerScreen会记录）
      Navigator.pushNamed(context, AppRouter.player, arguments: {
        'channelUrl': channel.url,
        'channelName': channel.name,
        'channelLogo': channel.logoUrl,
      });
    }
  }

  List<Channel> _getFavoriteChannels(ChannelProvider provider) {
    final favProvider = context.read<FavoritesProvider>();
    // ✅ 使用 allChannels 而不是 channels，确保能获取到所有收藏频道
    // channels 只包含分页显示的频道，可能不包含收藏的频道
    return provider.allChannels
        .where((c) => favProvider.isFavorite(c.id ?? 0))
        .take(20)
        .toList();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
                gradient: AppTheme.getGradient(context),
                borderRadius: BorderRadius.circular(24)),
            child: const Icon(Icons.playlist_add_rounded,
                size: 48, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Text(AppStrings.of(context)?.noPlaylistYet ?? 'No Playlists Yet',
              style: TextStyle(
                  color: AppTheme.getTextPrimary(context),
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
              AppStrings.of(context)?.addM3uToStart ??
                  'Add M3U playlist to start watching',
              style: TextStyle(
                  color: AppTheme.getTextSecondary(context), fontSize: 13)),
          const SizedBox(height: 24),
          TVFocusable(
            autofocus: false,
            onSelect: () => _showAddPlaylistDialog(),
            focusScale: 1.0,
            showFocusBorder: false,
            builder: (context, isFocused, child) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  gradient: AppTheme.getGradient(context),
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  border: isFocused
                      ? Border.all(
                          color: AppTheme.getPrimaryColor(context), width: 2)
                      : null,
                ),
                child: child,
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  AppStrings.of(context)?.addPlaylist ?? 'Add Playlist',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChannelsState(PlaylistProvider playlistProvider) {
    final activePlaylist = playlistProvider.activePlaylist;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
                gradient: AppTheme.getGradient(context),
                borderRadius: BorderRadius.circular(24)),
            child: const Icon(Icons.tv_off_rounded,
                size: 48, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Text('No Channels',
              style: TextStyle(
                  color: AppTheme.getTextPrimary(context),
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
              'The playlist "${activePlaylist?.name ?? 'Unknown'}" has no channels',
              style: TextStyle(
                  color: AppTheme.getTextSecondary(context), fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              TVFocusable(
                autofocus: true,
                onSelect: () => _showAddPlaylistDialog(),
                focusScale: 1.0,
                showFocusBorder: false,
                builder: (context, isFocused, child) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: AppTheme.getGradient(context),
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                      border: isFocused
                          ? Border.all(
                              color: AppTheme.getPrimaryColor(context),
                              width: 2)
                          : null,
                    ),
                    child: child,
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      AppStrings.of(context)?.addPlaylist ?? 'Add Playlist',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              if (activePlaylist != null)
                TVFocusable(
                  onSelect: () => _refreshCurrentPlaylist(
                      playlistProvider, context.read<ChannelProvider>()),
                  focusScale: 1.0,
                  showFocusBorder: false,
                  builder: (context, isFocused, child) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: isFocused
                            ? AppTheme.getGlassColor(context)
                            : AppTheme.getGlassColor(context).withOpacity(0.5),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusPill),
                        border: Border.all(
                            color: isFocused
                                ? AppTheme.getPrimaryColor(context)
                                : AppTheme.getGlassBorderColor(context),
                            width: isFocused ? 2 : 1),
                      ),
                      child: child,
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded,
                          size: 18,
                          color: AppTheme.getTextPrimary(context)),
                      const SizedBox(width: 8),
                      Text(
                        AppStrings.of(context)?.refresh ?? 'Refresh',
                        style: TextStyle(
                            color: AppTheme.getTextPrimary(context),
                            fontSize: 14,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              TVFocusable(
                onSelect: () => Navigator.pushNamed(
                    context, AppRouter.playlistList),
                focusScale: 1.0,
                showFocusBorder: false,
                builder: (context, isFocused, child) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: isFocused
                          ? AppTheme.getGlassColor(context)
                          : AppTheme.getGlassColor(context).withOpacity(0.5),
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                      border: Border.all(
                          color: isFocused
                              ? AppTheme.getPrimaryColor(context)
                              : AppTheme.getGlassBorderColor(context),
                          width: isFocused ? 2 : 1),
                    ),
                    child: child,
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.playlist_play_rounded,
                        size: 18,
                        color: AppTheme.getTextPrimary(context)),
                    const SizedBox(width: 8),
                    Text(
                      AppStrings.of(context)?.playlistList ?? 'Playlists',
                      style: TextStyle(
                          color: AppTheme.getTextPrimary(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
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
  State<_ResponsiveCategoryChips> createState() =>
      _ResponsiveCategoryChipsState();
}

class _ResponsiveCategoryChipsState extends State<_ResponsiveCategoryChips> with ThrottledStateMixin {
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
        return _buildCollapsedView(
            maxVisibleCount, isMobile, horizontalPadding);
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

  Widget _buildCollapsedView(
      int maxVisible, bool isMobile, double horizontalPadding) {
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
            ...widget.groups
                .take(visibleCount)
                .map((group) => _buildChip(group.name, isMobile)),
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
          padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 8 : 12,
              vertical: isMobile ? 3 : 8), // 手机端从5减少到3
          decoration: BoxDecoration(
            gradient: isFocused
                ? AppTheme.getGradient(context)
                : AppTheme.getSoftGradient(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(
                color: isFocused
                    ? AppTheme.getPrimaryColor(context)
                    : AppTheme.getGlassBorderColor(context)),
          ),
          child: child,
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CategoryCard.getIconForCategory(name),
              size: isMobile ? 12 : 14,
              color: AppTheme.getTextSecondary(context)),
          SizedBox(width: isMobile ? 4 : 6),
          Text(name,
              style: TextStyle(
                  color: AppTheme.getTextSecondary(context),
                  fontSize: isMobile ? 10 : 12)),
        ],
      ),
    );
  }

  Widget _buildExpandButton(int hiddenCount, bool isMobile) {
    return TVFocusable(
      onSelect: () => immediateSetState(() => _isExpanded = true), // 立即更新展开状态
      focusScale: 1.0,
      showFocusBorder: false,
      builder: (context, isFocused, child) {
        return Container(
          padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 8 : 12,
              vertical: isMobile ? 3 : 8), // 手机端从5减少到3
          decoration: BoxDecoration(
            gradient: isFocused
                ? AppTheme.getGradient(context)
                : AppTheme.getSoftGradient(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(
                color: isFocused
                    ? AppTheme.getPrimaryColor(context)
                    : AppTheme.getGlassBorderColor(context)),
          ),
          child: child,
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.more_horiz_rounded,
              size: isMobile ? 12 : 14,
              color: AppTheme.getTextSecondary(context)),
          SizedBox(width: isMobile ? 3 : 4),
          Text('+$hiddenCount',
              style: TextStyle(
                  color: AppTheme.getTextSecondary(context),
                  fontSize: isMobile ? 10 : 12)),
        ],
      ),
    );
  }

  Widget _buildCollapseButton(bool isMobile) {
    return TVFocusable(
      onSelect: () => immediateSetState(() => _isExpanded = false), // 立即更新折叠状态
      focusScale: 1.0,
      showFocusBorder: false,
      builder: (context, isFocused, child) {
        return Container(
          padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 8 : 12,
              vertical: isMobile ? 3 : 8), // 手机端从5减少到3
          decoration: BoxDecoration(
            gradient: isFocused
                ? AppTheme.getGradient(context)
                : AppTheme.getSoftGradient(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(
                color: isFocused
                    ? AppTheme.getPrimaryColor(context)
                    : AppTheme.getGlassBorderColor(context)),
          ),
          child: child,
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.unfold_less_rounded,
              size: isMobile ? 12 : 14,
              color: AppTheme.getTextSecondary(context)),
          SizedBox(width: isMobile ? 3 : 4),
          Text(AppStrings.of(context)?.collapse ?? 'Collapse',
              style: TextStyle(
                  color: AppTheme.getTextSecondary(context),
                  fontSize: isMobile ? 10 : 12)),
        ],
      ),
    );
  }
}

/// 优化的频道卡片组件 - 使用 Selector 精确控制重建
class _OptimizedChannelCard extends StatelessWidget {
  final Channel channel;
  final VoidCallback onTap;
  final VoidCallback? onUp; // 添加onUp回调

  const _OptimizedChannelCard({
    required this.channel,
    required this.onTap,
    this.onUp, // 添加onUp参数
  });

  @override
  Widget build(BuildContext context) {
    // 使用 Selector 监听收藏状态和 EPG 数据变化
    return Selector2<FavoritesProvider, EpgProvider, _ChannelCardData>(
      selector: (_, favProvider, epgProvider) {
        final currentProgram =
            epgProvider.getCurrentProgram(channel.epgId, channel.name);
        final nextProgram =
            epgProvider.getNextProgram(channel.epgId, channel.name);
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
          channel: channel, // 传递完整的 channel 对象
          groupName: channel.groupName,
          currentProgram: data.currentProgram,
          nextProgram: data.nextProgram,
          isFavorite: data.isFavorite,
          onFavoriteToggle: () =>
              context.read<FavoritesProvider>().toggleFavorite(channel),
          onTap: onTap,
          onUp: onUp, // 传递onUp回调
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
class _EmbeddedChannelsScreen extends StatefulWidget {
  const _EmbeddedChannelsScreen();

  @override
  State<_EmbeddedChannelsScreen> createState() =>
      _EmbeddedChannelsScreenState();
}

class _EmbeddedChannelsScreenState extends State<_EmbeddedChannelsScreen> {
  @override
  void initState() {
    super.initState();
    // 每次显示时清除分类筛选
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChannelProvider>().clearGroupFilter();
    });
  }

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

/// 嵌入式播放列表页面
class _EmbeddedPlaylistListScreen extends StatelessWidget {
  const _EmbeddedPlaylistListScreen();

  @override
  Widget build(BuildContext context) {
    return const PlaylistListScreen();
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
