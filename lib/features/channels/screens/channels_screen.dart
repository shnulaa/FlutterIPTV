import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../../core/widgets/tv_sidebar.dart';
import '../../../core/widgets/channel_card.dart';
import '../../../core/widgets/category_card.dart';
import '../../../core/widgets/auto_scroll_text.dart';
import '../../../core/platform/platform_detector.dart';
import '../../../core/platform/native_player_channel.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/services/channel_test_service.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/background_test_service.dart';
import '../../../core/services/epg_service.dart';
import '../../../core/models/channel.dart';
import '../../../core/utils/card_size_calculator.dart';
import '../../../core/utils/throttled_state_mixin.dart'; // ✅ 导入节流 mixin

import '../providers/channel_provider.dart';
import '../widgets/channel_test_dialog.dart';
import '../../favorites/providers/favorites_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../epg/providers/epg_provider.dart';
import '../../multi_screen/providers/multi_screen_provider.dart';
import '../../playlist/providers/playlist_provider.dart';

class ChannelsScreen extends StatefulWidget {
  final String? groupName;
  final bool embedded; // 是否嵌入到首页底部导航

  const ChannelsScreen({
    super.key,
    this.groupName,
    this.embedded = false,
  });

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> with ThrottledStateMixin {
  String? _selectedGroup;
  final ScrollController _scrollController = ScrollController();
  final ScrollController _groupScrollController = ScrollController();

  // ✅ 本地缓存频道列表，避免每次 Provider 更新都重建
  List<Channel> _cachedChannels = [];
  bool _isLoadingMore = false;

  // 用于TV端分类焦点管理
  final List<FocusNode> _groupFocusNodes = [];
  final List<FocusNode> _channelFocusNodes = [];
  int _currentGroupIndex = 0;
  int _lastChannelIndex = 0; // 记住上次聚焦的频道索引

  // 延迟选中分类的定时器
  Timer? _groupSelectTimer;

  // ✅ 滚动状态管理：用于暂停台标加载
  Timer? _scrollEndTimer;

  @override
  void initState() {
    super.initState();
    _selectedGroup = widget.groupName;

    // ✅ 添加滚动监听，滚动时暂停台标加载
    _scrollController.addListener(_onScroll);

    // 嵌入模式下清除分类筛选，显示全部频道
    if (widget.embedded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<ChannelProvider>().clearGroupFilter();
      });
    } else if (_selectedGroup != null) {
      context.read<ChannelProvider>().selectGroup(_selectedGroup!);

      // 如果是从首页"更多"按钮跳转过来的，延迟跳转焦点到第一个频道
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (PlatformDetector.isTV) {
          // 延迟一点时间确保UI完全构建完成
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              // 找到对应分类的索引
              final provider = context.read<ChannelProvider>();
              final groupIndex =
                  provider.groups.indexWhere((g) => g.name == _selectedGroup);
              if (groupIndex >= 0) {
                // +1 因为第一个是"全部频道"
                _currentGroupIndex = groupIndex + 1;
              }

              // 跳转焦点到第一个频道并记住索引
              if (_channelFocusNodes.isNotEmpty) {
                _lastChannelIndex = 0; // 记住是第一个频道
                _channelFocusNodes[0].requestFocus();
              }
            }
          });
        }
      });
    }
  }

  @override
  void dispose() {
    // 确保退出页面时恢复台标加载
    try {
      if (mounted) {
        context.read<ChannelProvider>().resumeLogoLoading();
      }
    } catch (e) {
      // Ignore provider error on dispose
    }

    _groupSelectTimer?.cancel();
    _scrollEndTimer?.cancel();
    _scrollController.dispose();
    _groupScrollController.dispose();
    for (final node in _groupFocusNodes) {
      node.dispose();
    }
    for (final node in _channelFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  // ✅ 控制台标加载状态
  void setLogoLoadingScrolling(bool isScrolling) {
    if (!mounted) return;
    try {
      final provider = context.read<ChannelProvider>();
      if (isScrolling) {
        provider.pauseLogoLoading();
      } else {
        provider.resumeLogoLoading();
      }
    } catch (_) {}
  }

  /// ✅ 滚动监听：滚动时暂停台标加载 + 滚动到底部时加载更多
  void _onScroll() {
    // 标记为正在滚动
    setLogoLoadingScrolling(true);

    // 取消之前的定时器
    _scrollEndTimer?.cancel();

    // 滚动停止500ms后恢复台标加载
    _scrollEndTimer = Timer(const Duration(milliseconds: 500), () {
      setLogoLoadingScrolling(false);
    });

    // ✅ 检查是否滚动到底部，触发加载更多
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final delta = maxScroll - currentScroll;

    // 距离底部还有1000像素时开始加载下一页
    if (delta < 1000 && mounted && !_isLoadingMore) {
      final provider = context.read<ChannelProvider>();

      if (provider.hasMore) {
        ServiceLocator.log.i(
            '[ChannelsScreen] 触发加载更多: delta=${delta.toStringAsFixed(0)}px, loaded=${provider.loadedChannelCount}/${provider.totalChannelCount}');

        immediateSetState(() => _isLoadingMore = true); // 立即更新加载状态

        // 判断是加载所有频道还是特定播放列表
        Future<void> loadFuture;
        if (provider.selectedGroup == null) {
          ServiceLocator.log.d('[ChannelsScreen] 加载所有频道（分页）');
          loadFuture = provider.loadAllChannels(loadMore: true);
        } else {
          final playlistProvider = context.read<PlaylistProvider>();
          final activePlaylist = playlistProvider.activePlaylist;
          final playlistId = activePlaylist?.id;
          if (playlistId != null) {
            ServiceLocator.log.d('[ChannelsScreen] 加载播放列表 $playlistId 的频道（分页）');
            loadFuture = provider.loadChannels(playlistId, loadMore: true);
          } else {
            ServiceLocator.log.w('[ChannelsScreen] 无法加载更多：playlistId 为 null');
            immediateSetState(() => _isLoadingMore = false); // 立即更新加载状态
            return;
          }
        }

        // 加载完成后更新本地缓存和状态
        loadFuture.then((_) {
          ServiceLocator.log.i('[ChannelsScreen] 加载更多完成，开始更新缓存');
          if (mounted) {
            throttledSetState(() {
              _cachedChannels = provider.filteredChannels;
              ServiceLocator.log
                  .i('[ChannelsScreen] 缓存更新完成: ${_cachedChannels.length} 个频道');
            });

            // ✅ 等待UI渲染完成后再解锁“加载更多”，防止快速连续触发
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                immediateSetState(() {
                  _isLoadingMore = false;
                });
                ServiceLocator.log.d('[ChannelsScreen] "加载更多"已解锁');

                // NEW LOGIC: Check again if we're at the bottom and need to load more
                final currentMaxScroll =
                    _scrollController.position.maxScrollExtent;
                final currentScrollPosition = _scrollController.position.pixels;

                const threshold = 0.9; // Moved threshold declaration here

                bool shouldLoadNextPage = false;
                if (currentMaxScroll == 0.0) {
                  // No scrollable content yet, or very little (e.g., first load)
                  shouldLoadNextPage =
                      true; // Always try to load if nothing loaded yet
                } else {
                  shouldLoadNextPage =
                      (currentScrollPosition / currentMaxScroll) > threshold;
                }

                if (shouldLoadNextPage && provider.hasMore) {
                  ServiceLocator.log.d(
                      '[ChannelsScreen] "加载更多"解锁后再次触发加载 (position/max: ${currentScrollPosition.toStringAsFixed(0)}/${currentMaxScroll.toStringAsFixed(0)}, threshold: ${threshold * 100}%)');
                  _onScroll(); // Recursive call, but now with a guaranteed frame break.
                } else {
                  ServiceLocator.log.d(
                      '[ChannelsScreen] "加载更多"解锁，但不再触发下一页加载 (position/max: ${currentScrollPosition.toStringAsFixed(0)}/${currentMaxScroll.toStringAsFixed(0)}, hasMore: ${provider.hasMore}, threshold: ${threshold * 100}%)');
                }
              }
            });
          }
        }).catchError((e) {
          ServiceLocator.log.e('[ChannelsScreen] 加载更多失败', error: e);
          if (mounted) {
            immediateSetState(() => _isLoadingMore = false); // 立即更新加载状态
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTV = PlatformDetector.isTV || size.width > 1200;

    final content = Row(
      children: [
        // Groups Sidebar (for TV and Desktop)
        if (isTV) _buildGroupsSidebar(),
        // Channels Grid
        Expanded(child: _buildChannelsContent()),
      ],
    );

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
            selectedIndex: 1, // 频道页
            onRight: () {
              // 主菜单按右键，跳转到当前分类
              if (_groupFocusNodes.isNotEmpty &&
                  _currentGroupIndex < _groupFocusNodes.length) {
                _groupFocusNodes[_currentGroupIndex].requestFocus();
              }
            },
            child: content,
          ),
        ),
      );
    }

    // 嵌入模式不使用Scaffold，直接返回内容
    if (widget.embedded) {
      final isMobile = PlatformDetector.isMobile;
      final isLandscape = isMobile && MediaQuery.of(context).size.width > 700;
      final statusBarHeight =
          isMobile ? MediaQuery.of(context).padding.top : 0.0;
      final topPadding =
          isMobile ? (statusBarHeight > 0 ? statusBarHeight - 15 : 0.0) : 0.0;

      return Stack(
        children: [
          content,
          // 手机端嵌入模式：竖屏时显示浮动按钮，横屏时不显示（因为有固定分类栏）
          if (!isLandscape)
            Positioned(
              left: 8,
              top: topPadding + 8,
              child: Material(
                color: AppTheme.getSurfaceColor(context),
                borderRadius: BorderRadius.circular(8),
                elevation: 2,
                child: InkWell(
                  onTap: () => _showMobileGroupsBottomSheet(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.menu_rounded,
                            color: AppTheme.getTextPrimary(context), size: 18),
                        const SizedBox(width: 6),
                        Text(
                          _selectedGroup ??
                              (AppStrings.of(context)?.allChannels ?? 'All'),
                          style: TextStyle(
                            color: AppTheme.getTextPrimary(context),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_drop_down,
                            color: AppTheme.getTextMuted(context), size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }

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
        child: content,
      ),
      // 手机端添加分类抽屉
      drawer: _buildMobileGroupsDrawer(),
    );
  }

  /// 手机端嵌入模式的分类底部弹窗
  void _showMobileGroupsBottomSheet(BuildContext context) {
    final provider = context.read<ChannelProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.getSurfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              child: Text(
                AppStrings.of(context)?.categories ?? 'Categories',
                style: TextStyle(
                  color: AppTheme.getTextPrimary(context),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  _buildMobileGroupItem(
                    name: AppStrings.of(context)?.allChannels ?? 'All Channels',
                    count: provider.totalChannelCount,
                    isSelected: _selectedGroup == null,
                    onTap: () {
                      immediateSetState(() => _selectedGroup = null); // 立即更新分类选择
                      provider.clearGroupFilter();
                      Navigator.pop(ctx);
                    },
                  ),
                  ...provider.groups.map((group) => _buildMobileGroupItem(
                        name: group.name,
                        count: group.channelCount,
                        isSelected: _selectedGroup == group.name,
                        onTap: () {
                          immediateSetState(() => _selectedGroup = group.name); // 立即更新分类选择
                          provider.selectGroup(group.name);
                          Navigator.pop(ctx);
                        },
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupsSidebar() {
    return Consumer<ChannelProvider>(
      builder: (context, provider, _) {
        // 确保焦点节点数量正确 (1个"全部频道" + 分类数量)
        final totalGroups = provider.groups.length + 1;
        while (_groupFocusNodes.length < totalGroups) {
          _groupFocusNodes.add(FocusNode());
        }
        while (_groupFocusNodes.length > totalGroups) {
          _groupFocusNodes.removeLast().dispose();
        }

        return FocusTraversalGroup(
          child: Container(
            width: 180,
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: Theme.of(context).brightness == Brightness.dark
                          ? [
                              const Color(0xFF0A0A0A),
                              AppTheme.getPrimaryColor(context)
                                  .withOpacity(0.1),
                            ]
                          : [
                              const Color(0xFFE0E0E0),
                              AppTheme.getPrimaryColor(context)
                                  .withOpacity(0.12),
                            ],
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: AppTheme.getCardColor(context),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      TVFocusable(
                        onSelect: () => Navigator.of(context).pop(),
                        focusScale: 1.1,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.getCardColor(context),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: AppTheme.getTextPrimary(context),
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        AppStrings.of(context)?.categories ?? 'Categories',
                        style: TextStyle(
                          color: AppTheme.getTextPrimary(context),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // All Channels Option
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: _buildGroupItem(
                    name: AppStrings.of(context)?.allChannels ?? 'All Channels',
                    count: provider.totalChannelCount,
                    isSelected: _selectedGroup == null,
                    focusNode: _groupFocusNodes.isNotEmpty
                        ? _groupFocusNodes[0]
                        : null,
                    groupIndex: 0,
                    onTap: () {
                      immediateSetState(() {
                        _selectedGroup = null;
                        _currentGroupIndex = 0;
                      });
                      provider.clearGroupFilter();
                    },
                  ),
                ),

                Divider(color: AppTheme.getCardColor(context), height: 1),

                // Groups List
                Expanded(
                  child: ListView.builder(
                    controller: _groupScrollController,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: provider.groups.length,
                    itemBuilder: (context, index) {
                      final group = provider.groups[index];
                      final focusIndex = index + 1; // +1 因为第一个是"全部频道"
                      return _buildGroupItem(
                        name: group.name,
                        count: group.channelCount,
                        isSelected: _selectedGroup == group.name,
                        focusNode: focusIndex < _groupFocusNodes.length
                            ? _groupFocusNodes[focusIndex]
                            : null,
                        groupIndex: focusIndex,
                        onTap: () {
                          immediateSetState(() {
                            _selectedGroup = group.name;
                            _currentGroupIndex = focusIndex;
                          });
                          provider.selectGroup(group.name);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 手机端分类抽屉
  Widget _buildMobileGroupsDrawer() {
    return Consumer<ChannelProvider>(
      builder: (context, provider, _) {
        return Drawer(
          backgroundColor: AppTheme.getSurfaceColor(context),
          width: 220,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: const BoxDecoration(
                    gradient: AppTheme.lotusGradient,
                  ),
                  child: Text(
                    AppStrings.of(context)?.categories ?? 'Categories',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // All Channels Option
                _buildMobileGroupItem(
                  name: AppStrings.of(context)?.allChannels ?? 'All Channels',
                  count: provider.totalChannelCount,
                  isSelected: _selectedGroup == null,
                  onTap: () {
                    immediateSetState(() => _selectedGroup = null); // 立即更新分类选择
                    provider.clearGroupFilter();
                    Navigator.pop(context);
                  },
                ),

                const Divider(height: 1),

                // Groups List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: provider.groups.length,
                    itemBuilder: (context, index) {
                      final group = provider.groups[index];
                      return _buildMobileGroupItem(
                        name: group.name,
                        count: group.channelCount,
                        isSelected: _selectedGroup == group.name,
                        onTap: () {
                          immediateSetState(() => _selectedGroup = group.name); // 立即更新分类选择
                          provider.selectGroup(group.name);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 手机端分类列表项
  Widget _buildMobileGroupItem({
    required String name,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      leading: Icon(
        CategoryCard.getIconForCategory(name),
        color: isSelected
            ? AppTheme.getPrimaryColor(context)
            : AppTheme.getTextSecondary(context),
        size: 20,
      ),
      title: Text(
        name,
        style: TextStyle(
          color: isSelected
              ? AppTheme.getPrimaryColor(context)
              : AppTheme.getTextPrimary(context),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          fontSize: 13,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.getPrimaryColor(context).withOpacity(0.2)
              : AppTheme.getCardColor(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          count.toString(),
          style: TextStyle(
            color: isSelected
                ? AppTheme.getPrimaryColor(context)
                : AppTheme.getTextMuted(context),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      selected: isSelected,
      selectedTileColor: AppTheme.getPrimaryColor(context).withOpacity(0.1),
      onTap: onTap,
    );
  }

  Widget _buildGroupItem({
    required String name,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
    FocusNode? focusNode,
    int groupIndex = 0,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: TVFocusable(
        focusNode: focusNode,
        onSelect: onTap,
        onFocus: PlatformDetector.isTV
            ? () {
                // TV端焦点移动延迟选中分类，避免快速滚动时频繁刷新
                _currentGroupIndex = groupIndex;
                _groupSelectTimer?.cancel();
                _groupSelectTimer =
                    Timer(const Duration(milliseconds: 300), () {
                  if (mounted) {
                    // 切换分类时重置频道索引并滚动到顶部
                    _lastChannelIndex = 0;
                    _scrollController.jumpTo(0);
                    onTap();
                  }
                });
              }
            : null,
        onRight: PlatformDetector.isTV
            ? () {
                // 按右键跳转到上次聚焦的频道（或第一个）
                if (_channelFocusNodes.isNotEmpty) {
                  final targetIndex =
                      _lastChannelIndex.clamp(0, _channelFocusNodes.length - 1);
                  _channelFocusNodes[targetIndex].requestFocus();
                }
              }
            : null,
        onLeft: PlatformDetector.isTV
            ? () {
                // 按左键跳转到侧边菜单的当前选中项（频道页是index 1）
                final menuNodes = TVSidebar.menuFocusNodes;
                if (menuNodes != null && menuNodes.length > 1) {
                  menuNodes[1].requestFocus(); // 频道页是第2个菜单项
                }
              }
            : null,
        focusScale: 1.02,
        showFocusBorder: false,
        builder: (context, isFocused, child) {
          return AnimatedContainer(
            duration: AppTheme.animationFast,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: isSelected || isFocused
                  ? AppTheme.getSoftGradient(context)
                  : null,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isFocused
                    ? AppTheme.getPrimaryColor(context)
                    : isSelected
                        ? AppTheme.getPrimaryColor(context).withOpacity(0.5)
                        : Colors.transparent,
                width: isFocused ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                // Selection indicator
                AnimatedContainer(
                  duration: AppTheme.animationFast,
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.getPrimaryColor(context)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),

                // Name
                Expanded(
                  child: AutoScrollText(
                    text: name,
                    forceScroll: true,
                    style: TextStyle(
                      color: isSelected
                          ? AppTheme.getPrimaryColor(context)
                          : AppTheme.getTextPrimary(context),
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),

                // Count badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.getPrimaryColor(context).withOpacity(0.2)
                        : AppTheme.getCardColor(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      color: isSelected
                          ? AppTheme.getPrimaryColor(context)
                          : AppTheme.getTextMuted(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        child: const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildChannelsContent() {
    ServiceLocator.log.d('[ChannelsScreen] _buildChannelsContent 被调用');

    // ✅ 使用 Consumer 只监听分组变化，频道列表使用本地缓存
    return Consumer<ChannelProvider>(
      builder: (context, provider, _) {
        ServiceLocator.log.d(
            '[ChannelsScreen] Consumer builder 被调用 - filteredChannels=${provider.filteredChannels.length}, cached=${_cachedChannels.length}');

        // 首次加载或切换分类时更新缓存
        if (_cachedChannels.isEmpty ||
            provider.filteredChannels.length != _cachedChannels.length) {
          ServiceLocator.log.d(
              '[ChannelsScreen] 需要更新缓存: empty=${_cachedChannels.isEmpty}, lengthChanged=${provider.filteredChannels.length != _cachedChannels.length}');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              throttledSetState(() {
                _cachedChannels = provider.filteredChannels;
                ServiceLocator.log
                    .d('[ChannelsScreen] 缓存已更新: ${_cachedChannels.length} 个频道');
              });

              // ✅ 检查是否填满屏幕，如果未填满且还有更多数据，自动触发加载下一页
              Future.delayed(const Duration(milliseconds: 200), () {
                if (mounted && _scrollController.hasClients) {
                  final maxScroll = _scrollController.position.maxScrollExtent;
                  // 如果最大滚动距离很小（说明内容没有填满屏幕），且还有更多数据，则触发加载
                  if (maxScroll < 100 && provider.hasMore && !_isLoadingMore) {
                    ServiceLocator.log.i(
                        '[ChannelsScreen] 内容不足以滚动(maxScroll=$maxScroll)，自动触发加载更多');
                    _onScroll();
                  }
                }
              });
            }
          });
        }

        final channels = _cachedChannels.isNotEmpty
            ? _cachedChannels
            : provider.filteredChannels;
        ServiceLocator.log.d('[ChannelsScreen] 使用频道列表: ${channels.length} 个');
        final isMobile = PlatformDetector.isMobile;
        final isLandscape = isMobile && MediaQuery.of(context).size.width > 700;

        // 参考首页的设置，手机端获取状态栏高度并减少间距
        final statusBarHeight =
            isMobile ? MediaQuery.of(context).padding.top : 0.0;
        final topPadding = isMobile
            ? (statusBarHeight > 0 ? statusBarHeight - 15.0 : 0.0)
            : 0.0;

        return CustomScrollView(
          controller: _scrollController,
          // ✅ 性能优化：限制缓存范围，减少内存占用
          cacheExtent: 500,
          slivers: [
            // 手机竖屏：添加顶部间距
            if (isMobile && !isLandscape)
              SliverToBoxAdapter(
                child: SizedBox(height: topPadding),
              ),

            // 手机横屏：使用 SliverPersistentHeader 实现固定分类栏（不遮挡状态栏）
            if (isLandscape && widget.embedded)
              SliverPersistentHeader(
                pinned: true,
                delegate: _LandscapeCategoryBarDelegate(
                  provider: provider,
                  selectedGroup: _selectedGroup,
                  channels: channels,
                  statusBarHeight: statusBarHeight,
                  onGroupSelected: (groupName) {
                    immediateSetState(() => _selectedGroup = groupName); // 立即更新分类选择
                    if (groupName == null) {
                      provider.clearGroupFilter();
                    } else {
                      provider.selectGroup(groupName);
                    }
                  },
                  onTestChannels: () =>
                      _showChannelTestDialog(context, channels),
                  onShowBackgroundTest: () =>
                      _showBackgroundTestProgress(context),
                  onDeleteUnavailable: _selectedGroup ==
                              ChannelProvider.unavailableGroupName &&
                          channels.isNotEmpty
                      ? () => _confirmDeleteAllUnavailable(context, provider)
                      : null,
                ),
              ),

            // 竖屏或非嵌入模式：使用普通 AppBar
            if (!isLandscape || !widget.embedded)
              SliverAppBar(
                pinned: false,
                floating: true,
                primary: false, // 禁用自动SafeArea
                backgroundColor: Colors.transparent,
                toolbarHeight: 56.0,
                expandedHeight: 0,
                collapsedHeight: 56.0,
                titleSpacing: 0,
                leadingWidth: 56,
                flexibleSpace: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: Theme.of(context).brightness == Brightness.dark
                          ? [
                              const Color(0xFF0A0A0A).withOpacity(0.95),
                              AppTheme.getPrimaryColor(context)
                                  .withOpacity(0.15),
                            ]
                          : [
                              const Color(0xFFE0E0E0).withOpacity(0.95),
                              AppTheme.getPrimaryColor(context)
                                  .withOpacity(0.12),
                            ],
                    ),
                  ),
                ),
                leading: isMobile && !widget.embedded
                    ? IconButton(
                        icon: Icon(Icons.menu_rounded,
                            color: AppTheme.getTextPrimary(context), size: 24),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      )
                    : null,
                title: widget.embedded
                    ? null
                    : Text(
                        _selectedGroup ??
                            (AppStrings.of(context)?.allChannels ??
                                'All Channels'),
                        style: TextStyle(
                          color: AppTheme.getTextPrimary(context),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                actions: [
                  // Background test progress indicator
                  _BackgroundTestIndicator(
                    onTap: () => _showBackgroundTestProgress(context),
                  ),
                  // Test channels button
                  IconButton(
                    icon: const Icon(Icons.speed_rounded),
                    iconSize: 24,
                    color: AppTheme.getTextSecondary(context),
                    tooltip: '测试频道',
                    onPressed: channels.isEmpty
                        ? null
                        : () => _showChannelTestDialog(context, channels),
                  ),
                  // Delete all unavailable channels button
                  if (_selectedGroup == ChannelProvider.unavailableGroupName &&
                      channels.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.delete_sweep_rounded),
                      iconSize: 24,
                      color: AppTheme.errorColor,
                      tooltip: '删除所有失效频道',
                      onPressed: () =>
                          _confirmDeleteAllUnavailable(context, provider),
                    ),
                  // Channel count
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      margin: EdgeInsets.only(right: isLandscape ? 8 : 16),
                      decoration: BoxDecoration(
                        color:
                            AppTheme.getSurfaceColor(context).withOpacity(0.8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isLandscape
                            ? '${channels.length}'
                            : '${channels.length} ${AppStrings.of(context)?.channels ?? 'channels'}',
                        style: TextStyle(
                          color: AppTheme.getTextSecondary(context),
                          fontSize: isLandscape ? 11 : 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

            // Channels Grid
            if (channels.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.live_tv_outlined,
                        size: 64,
                        color: AppTheme.getTextMuted(context).withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppStrings.of(context)?.noChannelsFound ??
                            'No channels found',
                        style: TextStyle(
                          color: AppTheme.getTextSecondary(context),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.only(
                  left: isMobile ? (isLandscape ? 4 : 8) : 20,
                  right: isMobile ? (isLandscape ? 4 : 8) : 20,
                  top: isMobile ? (isLandscape ? 4 : 8) : 20, // 横屏时顶部间距4px
                  bottom: isMobile ? (isLandscape ? 4 : 8) : 20,
                ),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final availableWidth = constraints.crossAxisExtent;
                    final crossAxisCount =
                        CardSizeCalculator.calculateCardsPerRow(availableWidth);

                    // ServiceLocator.log.d(
                    //     '[ChannelsScreen] SliverLayoutBuilder - 宽度=$availableWidth, 每行=$crossAxisCount 张卡片');

                    return SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: CardSizeCalculator.aspectRatio(),
                        crossAxisSpacing: CardSizeCalculator.spacing,
                        mainAxisSpacing: CardSizeCalculator.spacing,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          // ✅ 只在前10个和最后10个卡片打印日志，避免日志过多
                          // if (index < 10 || index >= channels.length - 10) {
                          //   ServiceLocator.log.d(
                          //       '[ChannelsScreen] 构建卡片 #$index/${channels.length}');
                          // }

                          final channel = channels[index];

                          // ✅ 使用 select 替代 watch，只监听特定频道的数据变化
                          // 这样可以避免其他频道的更新导致所有卡片重建
                          final isFavorite =
                              context.select<FavoritesProvider, bool>(
                            (provider) => provider.isFavorite(channel.id ?? 0),
                          );

                          final isUnavailable =
                              ChannelProvider.isUnavailableChannel(
                                  channel.groupName);

                          // ✅ 使用 select 获取 EPG 数据，只在该频道的 EPG 变化时重建
                          final currentProgram =
                              context.select<EpgProvider, EpgProgram?>(
                            (provider) => provider.getCurrentProgram(
                                channel.epgId, channel.name),
                          );

                          final nextProgram =
                              context.select<EpgProvider, EpgProgram?>(
                            (provider) => provider.getNextProgram(
                                channel.epgId, channel.name),
                          );

                          // TV端：确保焦点节点数量正确
                          if (PlatformDetector.isTV) {
                            while (_channelFocusNodes.length <= index) {
                              _channelFocusNodes.add(FocusNode());
                            }
                          }

                          // TV端：判断是否是第一列（需要处理左键导航）
                          final isFirstColumn = index % crossAxisCount == 0;

                          // TV端：判断是否是最后一行（需要处理下键切换分类）
                          final totalRows =
                              (channels.length / crossAxisCount).ceil();
                          final currentRow = index ~/ crossAxisCount;
                          final isLastRow = currentRow == totalRows - 1;

                          return ChannelCard(
                            name: channel.name,
                            logoUrl: channel.logoUrl,
                            channel: channel, // 传递完整的 channel 对象
                            groupName: isUnavailable
                                ? ChannelProvider.extractOriginalGroup(
                                    channel.groupName)
                                : channel.groupName,
                            currentProgram: currentProgram?.title,
                            nextProgram: nextProgram?.title,
                            isFavorite: isFavorite,
                            isUnavailable: isUnavailable,
                            autofocus: index == 0,
                            focusNode: PlatformDetector.isTV &&
                                    index < _channelFocusNodes.length
                                ? _channelFocusNodes[index]
                                : null,
                            onFocused: PlatformDetector.isTV
                                ? () {
                                    // 记住当前聚焦的频道索引
                                    _lastChannelIndex = index;
                                  }
                                : null,
                            onLeft: (PlatformDetector.isTV && isFirstColumn)
                                ? () {
                                    // 第一列按左键，跳转到当前选中的分类
                                    ServiceLocator.log.d(
                                        'ChannelsScreen: onLeft pressed, _currentGroupIndex=$_currentGroupIndex, _selectedGroup=$_selectedGroup');
                                    if (_currentGroupIndex <
                                        _groupFocusNodes.length) {
                                      _groupFocusNodes[_currentGroupIndex]
                                          .requestFocus();
                                    }
                                  }
                                : null,
                            onDown: (PlatformDetector.isTV && isLastRow)
                                ? () {
                                    // 最后一行按下键，不做任何事（阻止跳转）
                                  }
                                : null,
                            onFavoriteToggle: () {
                              context
                                  .read<FavoritesProvider>()
                                  .toggleFavorite(channel);
                            },
                            onTest: () => _testSingleChannel(context, channel),
                            onTap: () async {
                              final settingsProvider =
                                  context.read<SettingsProvider>();

                              // 保存上次播放的频道ID
                              if (settingsProvider.rememberLastChannel &&
                                  channel.id != null) {
                                settingsProvider.setLastChannelId(channel.id);
                              }

                              ServiceLocator.log.d(
                                  'ChannelsScreen: onTap - enableMultiScreen=${settingsProvider.enableMultiScreen}, isDesktop=${PlatformDetector.isDesktop}, isTV=${PlatformDetector.isTV}');

                              // 检查是否启用了分屏模式
                              if (settingsProvider.enableMultiScreen) {
                                // TV 端使用原生分屏播放器
                                if (PlatformDetector.isTV &&
                                    PlatformDetector.isAndroid) {
                                  ServiceLocator.log.d(
                                      'ChannelsScreen: TV Multi-screen mode, launching native multi-screen player');
                                  final channelProvider =
                                      context.read<ChannelProvider>();
                                  final favoritesProvider =
                                      context.read<FavoritesProvider>();
                                  // ✅ 使用全部频道而不是分页显示的频道
                                  final channels = channelProvider.allChannels;

                                  // 设置 providers 用于收藏功能
                                  NativePlayerChannel.setProviders(
                                      favoritesProvider,
                                      channelProvider,
                                      settingsProvider);

                                  // 找到当前点击频道的索引
                                  final clickedIndex = channels
                                      .indexWhere((c) => c.url == channel.url);

                                  // TV端原生分屏播放器也需要记录观看历史
                                  if (channel.id != null &&
                                      channel.playlistId != null) {
                                    await ServiceLocator.watchHistory
                                        .addWatchHistory(
                                            channel.id!, channel.playlistId!);
                                    ServiceLocator.log.d(
                                        'ChannelsScreen: Recorded watch history for channel ${channel.name} (TV multi-screen)');
                                  }

                                  // 准备频道数据
                                  final urls =
                                      channels.map((c) => c.url).toList();
                                  final names =
                                      channels.map((c) => c.name).toList();
                                  final groups = channels
                                      .map((c) => c.groupName ?? '')
                                      .toList();
                                  final sources =
                                      channels.map((c) => c.sources).toList();
                                  final logos = channels
                                      .map((c) => c.logoUrl ?? '')
                                      .toList();

                                  // 启动原生分屏播放器，传递初始频道索引和音量增强
                                  await NativePlayerChannel.launchMultiScreen(
                                    urls: urls,
                                    names: names,
                                    groups: groups,
                                    sources: sources,
                                    logos: logos,
                                    initialChannelIndex:
                                        clickedIndex >= 0 ? clickedIndex : 0,
                                    volumeBoostDb: settingsProvider.volumeBoost,
                                    defaultScreenPosition:
                                        settingsProvider.defaultScreenPosition,
                                    showChannelName: settingsProvider
                                        .showMultiScreenChannelName,
                                    onClosed: () {
                                      ServiceLocator.log.d(
                                          'ChannelsScreen: Native multi-screen closed');
                                    },
                                  );
                                } else if (PlatformDetector.isDesktop) {
                                  ServiceLocator.log.d(
                                      'ChannelsScreen: Desktop Multi-screen mode, playing channel: ${channel.name}');
                                  // 桌面端分屏模式：在指定位置播放频道
                                  final multiScreenProvider =
                                      context.read<MultiScreenProvider>();
                                  final defaultPosition =
                                      settingsProvider.defaultScreenPosition;
                                  // 设置音量增强到分屏Provider
                                  multiScreenProvider.setVolumeSettings(
                                      1.0, settingsProvider.volumeBoost);
                                  multiScreenProvider
                                      .playChannelAtDefaultPosition(
                                          channel, defaultPosition);

                                  // 分屏模式下导航到播放器页面，但不传递频道参数（由MultiScreenProvider处理播放）
                                  Navigator.pushNamed(
                                    context,
                                    AppRouter.player,
                                    arguments: {
                                      'channelUrl': '', // 空URL表示分屏模式
                                      'channelName': '',
                                      'channelLogo': null,
                                    },
                                  );
                                } else {
                                  // 其他平台普通播放
                                  Navigator.pushNamed(
                                    context,
                                    AppRouter.player,
                                    arguments: {
                                      'channelUrl': channel.url,
                                      'channelName': channel.name,
                                      'channelLogo': channel.logoUrl,
                                    },
                                  );
                                }
                              } else {
                                // 普通模式：导航到播放器页面并传递频道参数
                                Navigator.pushNamed(
                                  context,
                                  AppRouter.player,
                                  arguments: {
                                    'channelUrl': channel.url,
                                    'channelName': channel.name,
                                    'channelLogo': channel.logoUrl,
                                  },
                                );
                              }
                            },
                            onLongPress: () =>
                                _showChannelOptions(context, channel),
                          );
                        },
                        childCount: channels.length,
                        // ✅ 性能优化：不保持已滚动出视口的卡片状态
                        addAutomaticKeepAlives: false,
                        // ✅ 性能优化：添加重绘边界，避免不必要的重绘
                        addRepaintBoundaries: true,
                      ),
                    );
                  },
                ),
              ),

            // ✅ 加载更多指示器
            if (_isLoadingMore)
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '加载更多频道... (${channels.length}/${provider.filteredChannels.length})',
                        style: TextStyle(
                          color: AppTheme.getTextSecondary(context),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ✅ 已加载全部提示
            if (!provider.hasMore && channels.isNotEmpty)
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  alignment: Alignment.center,
                  child: Text(
                    '已加载全部 ${channels.length} 个频道',
                    style: TextStyle(
                      color: AppTheme.getTextSecondary(context),
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteAllUnavailable(
      BuildContext context, ChannelProvider provider) async {
    final count = provider.unavailableChannelCount;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.getSurfaceColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '删除所有失效频道',
          style: TextStyle(color: AppTheme.getTextPrimary(context)),
        ),
        content: Text(
          '确定要删除全部 $count 个失效频道吗？此操作不可撤销。',
          style: TextStyle(color: AppTheme.getTextSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('删除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final deletedCount = await provider.deleteAllUnavailableChannels();

      // 切换到全部频道
      immediateSetState(() {
        _selectedGroup = null;
      });
      provider.clearGroupFilter();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已删除 $deletedCount 个失效频道'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _testSingleChannel(BuildContext context, dynamic channel) async {
    final testService = ChannelTestService();
    final channelObj = channel as Channel;

    // 显示测试中提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Text('正在测试: ${channelObj.name}'),
          ],
        ),
        duration: const Duration(seconds: 10),
      ),
    );

    final result = await testService.testChannel(channelObj);

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // 如果测试通过且是失效频道，自动恢复到原分类
      if (result.isAvailable &&
          ChannelProvider.isUnavailableChannel(channelObj.groupName)) {
        final provider = context.read<ChannelProvider>();
        final originalGroup =
            ChannelProvider.extractOriginalGroup(channelObj.groupName);
        await provider.restoreChannel(channelObj.id!);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('${channelObj.name} 可用，已恢复到 "$originalGroup" 分类'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  result.isAvailable ? Icons.check_circle : Icons.error,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    result.isAvailable
                        ? '${channelObj.name} 可用 (${result.responseTime}ms)'
                        : '${channelObj.name} 不可用: ${result.error}',
                  ),
                ),
              ],
            ),
            backgroundColor:
                result.isAvailable ? Colors.green : AppTheme.errorColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _showChannelTestDialog(
      BuildContext context, List<dynamic> channels) async {
    final result = await showDialog<ChannelTestDialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ChannelTestDialog(
        channels: channels.cast<Channel>(),
      ),
    );

    if (result == null || !mounted) return;

    // 如果转入后台执行
    if (result.runInBackground) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text('测试已转入后台，剩余 ${result.remainingCount} 个频道'),
            ],
          ),
          backgroundColor: AppTheme.getPrimaryColor(context),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: '查看进度',
            textColor: Colors.white,
            onPressed: () => _showBackgroundTestProgress(context),
          ),
        ),
      );
      return;
    }

    // 如果用户选择移动到失效分类
    if (result.movedToUnavailable) {
      final unavailableCount =
          result.results.where((r) => !r.isAvailable).length;

      // 显示提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '已将 $unavailableCount 个失效频道移至"${ChannelProvider.unavailableGroupName}"分类'),
          backgroundColor: Colors.orange,
          action: SnackBarAction(
            label: '查看',
            textColor: Colors.white,
            onPressed: () {
              // 跳转到失效分类
              immediateSetState(() {
                _selectedGroup = ChannelProvider.unavailableGroupName;
              });
              context
                  .read<ChannelProvider>()
                  .selectGroup(ChannelProvider.unavailableGroupName);
            },
          ),
        ),
      );

      // 自动跳转到失效分类
      immediateSetState(() {
        _selectedGroup = ChannelProvider.unavailableGroupName;
      });
      context
          .read<ChannelProvider>()
          .selectGroup(ChannelProvider.unavailableGroupName);
    }
  }

  void _showBackgroundTestProgress(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const BackgroundTestProgressDialog(),
    );
  }

  // ignore: unused_element
  Future<void> _deleteUnavailableChannels(
      List<ChannelTestResult> results) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.getSurfaceColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '确认删除',
          style: TextStyle(color: AppTheme.getTextPrimary(context)),
        ),
        content: Text(
          '确定要删除 ${results.length} 个不可用的频道吗？此操作不可撤销。',
          style: TextStyle(color: AppTheme.getTextSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('删除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        // 删除不可用频道
        for (final result in results) {
          if (result.channel.id != null) {
            await ServiceLocator.database.delete(
              'channels',
              where: 'id = ?',
              whereArgs: [result.channel.id],
            );
          }
        }

        // 刷新频道列表
        if (mounted) {
          context.read<ChannelProvider>().loadAllChannels();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已删除 ${results.length} 个不可用频道'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('删除失败: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  void _showChannelOptions(BuildContext context, dynamic channel) {
    final favoritesProvider = context.read<FavoritesProvider>();
    final isFavorite = favoritesProvider.isFavorite(channel.id ?? 0);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.getSurfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Channel name
              Text(
                channel.name,
                style: TextStyle(
                  color: AppTheme.getTextPrimary(context),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Options
              ListTile(
                leading: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite
                      ? AppTheme.accentColor
                      : AppTheme.getTextSecondary(context),
                ),
                title: Text(
                  isFavorite
                      ? (AppStrings.of(context)?.removeFavorites ??
                          'Remove from Favorites')
                      : (AppStrings.of(context)?.addFavorites ??
                          'Add to Favorites'),
                  style: TextStyle(color: AppTheme.getTextPrimary(context)),
                ),
                onTap: () async {
                  await favoritesProvider.toggleFavorite(channel);
                  Navigator.pop(context);
                },
              ),

              ListTile(
                leading: Icon(
                  Icons.info_outline_rounded,
                  color: AppTheme.getTextSecondary(context),
                ),
                title: Text(
                  AppStrings.of(context)?.channelInfo ?? 'Channel Info',
                  style: TextStyle(color: AppTheme.getTextPrimary(context)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  // Show channel info dialog
                },
              ),

              ListTile(
                leading: Icon(
                  Icons.speed_rounded,
                  color: AppTheme.getTextSecondary(context),
                ),
                title: Text(
                  '测试频道',
                  style: TextStyle(color: AppTheme.getTextPrimary(context)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _testSingleChannel(context, channel);
                },
              ),

              // 如果是失效频道，显示恢复选项
              if (ChannelProvider.isUnavailableChannel(channel.groupName))
                ListTile(
                  leading: const Icon(
                    Icons.restore_rounded,
                    color: Colors.orange,
                  ),
                  title: Text(
                    '恢复到原分类 (${ChannelProvider.extractOriginalGroup(channel.groupName)})',
                    style: TextStyle(color: AppTheme.getTextPrimary(context)),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final provider = context.read<ChannelProvider>();
                    final success = await provider.restoreChannel(channel.id!);
                    if (mounted && success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('已恢复 ${channel.name} 到原分类'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                ),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

/// 横屏分类栏 Delegate（固定在状态栏下方）
class _LandscapeCategoryBarDelegate extends SliverPersistentHeaderDelegate {
  final ChannelProvider provider;
  final String? selectedGroup;
  final List<dynamic> channels;
  final Function(String?) onGroupSelected;
  final VoidCallback onTestChannels;
  final VoidCallback onShowBackgroundTest;
  final VoidCallback? onDeleteUnavailable;
  final double statusBarHeight;

  _LandscapeCategoryBarDelegate({
    required this.provider,
    required this.selectedGroup,
    required this.channels,
    required this.onGroupSelected,
    required this.onTestChannels,
    required this.onShowBackgroundTest,
    this.onDeleteUnavailable,
    required this.statusBarHeight,
  });

  @override
  double get minExtent => 40.0 + statusBarHeight;

  @override
  double get maxExtent => 40.0 + statusBarHeight;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      height: 40 + statusBarHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: Theme.of(context).brightness == Brightness.dark
              ? [
                  const Color(0xFF0A0A0A).withOpacity(0.95),
                  AppTheme.getPrimaryColor(context).withOpacity(0.15),
                ]
              : [
                  const Color(0xFFE0E0E0).withOpacity(0.95),
                  AppTheme.getPrimaryColor(context).withOpacity(0.12),
                ],
        ),
      ),
      child: Column(
        children: [
          // 顶部状态栏占位
          SizedBox(height: statusBarHeight - 10),
          // 分类栏内容
          Container(
            height: 40,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.getCardColor(context).withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                // 左侧：横向滚动的分类列表
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    itemCount: provider.groups.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        final isSelected = selectedGroup == null;
                        return _buildCategoryChip(
                          context: context,
                          name: AppStrings.of(context)?.allChannels ?? 'All',
                          count: provider.totalChannelCount,
                          isSelected: isSelected,
                          onTap: () => onGroupSelected(null),
                        );
                      } else {
                        final group = provider.groups[index - 1];
                        final isSelected = selectedGroup == group.name;
                        return _buildCategoryChip(
                          context: context,
                          name: group.name,
                          count: group.channelCount,
                          isSelected: isSelected,
                          onTap: () => onGroupSelected(group.name),
                        );
                      }
                    },
                  ),
                ),
                // 右侧：操作按钮
                _buildActions(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 分隔线
        Container(
          width: 1,
          height: 24,
          color: AppTheme.getCardColor(context).withOpacity(0.5),
          margin: const EdgeInsets.symmetric(horizontal: 4),
        ),
        // 后台测试进度
        _BackgroundTestIndicator(onTap: onShowBackgroundTest),
        // 测试按钮
        IconButton(
          icon: const Icon(Icons.speed_rounded),
          iconSize: 18,
          padding: const EdgeInsets.all(6),
          color: channels.isEmpty
              ? AppTheme.getTextMuted(context).withOpacity(0.3)
              : AppTheme.getTextSecondary(context),
          onPressed: channels.isEmpty ? null : onTestChannels,
        ),
        // 删除失效频道按钮
        if (onDeleteUnavailable != null)
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            iconSize: 18,
            padding: const EdgeInsets.all(6),
            color: AppTheme.errorColor,
            onPressed: onDeleteUnavailable,
          ),
        // 频道数量
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: AppTheme.getSurfaceColor(context).withOpacity(0.8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${channels.length}',
            style: TextStyle(
              color: AppTheme.getTextSecondary(context),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip({
    required BuildContext context,
    required String name,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: isSelected ? AppTheme.getGradient(context) : null,
              color: isSelected
                  ? null
                  : AppTheme.getCardColor(context).withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? AppTheme.getPrimaryColor(context)
                    : AppTheme.getGlassBorderColor(context),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CategoryCard.getIconForCategory(name),
                  size: 12,
                  color: isSelected
                      ? Colors.white
                      : AppTheme.getTextSecondary(context),
                ),
                const SizedBox(width: 4),
                Text(
                  name,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : AppTheme.getTextPrimary(context),
                    fontSize: 11,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                const SizedBox(width: 3),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.2)
                        : AppTheme.getCardColor(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : AppTheme.getTextMuted(context),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _LandscapeCategoryBarDelegate oldDelegate) {
    return oldDelegate.selectedGroup != selectedGroup ||
        oldDelegate.provider.groups.length != provider.groups.length ||
        oldDelegate.channels.length != channels.length;
  }
}

/// 后台测试进度指示器
class _BackgroundTestIndicator extends StatefulWidget {
  final VoidCallback onTap;

  const _BackgroundTestIndicator({required this.onTap});

  @override
  State<_BackgroundTestIndicator> createState() =>
      _BackgroundTestIndicatorState();
}

class _BackgroundTestIndicatorState extends State<_BackgroundTestIndicator> with ThrottledStateMixin {
  final BackgroundTestService _service = BackgroundTestService();
  late BackgroundTestProgress _progress;

  @override
  void initState() {
    super.initState();
    _progress = _service.currentProgress;
    _service.addListener(_onProgressUpdate);
  }

  @override
  void dispose() {
    _service.removeListener(_onProgressUpdate);
    super.dispose();
  }

  void _onProgressUpdate(BackgroundTestProgress progress) {
    if (mounted) {
      throttledSetState(() {
        _progress = progress;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 只在运行中或有结果时显示
    if (!_progress.isRunning && !_progress.isComplete) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _progress.isRunning
              ? AppTheme.getPrimaryColor(context).withOpacity(0.2)
              : Colors.orange.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_progress.isRunning) ...[
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.getPrimaryColor(context),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_progress.completed}/${_progress.total}',
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ] else ...[
              const Icon(
                Icons.check_circle_outline,
                size: 16,
                color: Colors.orange,
              ),
              const SizedBox(width: 6),
              Text(
                '测试完成 (${_progress.unavailable}失效)',
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
