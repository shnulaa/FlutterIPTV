import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../../core/widgets/tv_sidebar.dart';
import '../../../core/widgets/channel_card.dart';
import '../../../core/platform/platform_detector.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/services/channel_test_service.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/background_test_service.dart';
import '../../../core/models/channel.dart';
import '../providers/channel_provider.dart';
import '../widgets/channel_test_dialog.dart';
import '../../favorites/providers/favorites_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../epg/providers/epg_provider.dart';

class ChannelsScreen extends StatefulWidget {
  final String? groupName;

  const ChannelsScreen({
    super.key,
    this.groupName,
  });

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  String? _selectedGroup;
  final ScrollController _scrollController = ScrollController();
  final ScrollController _groupScrollController = ScrollController();
  
  // 用于TV端分类焦点管理
  final List<FocusNode> _groupFocusNodes = [];
  final List<FocusNode> _channelFocusNodes = [];
  int _currentGroupIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedGroup = widget.groupName;

    if (_selectedGroup != null) {
      context.read<ChannelProvider>().selectGroup(_selectedGroup!);
    }
  }

  @override
  void dispose() {
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
        backgroundColor: AppTheme.backgroundColor,
        body: TVSidebar(
          selectedIndex: 1, // 频道页
          child: content,
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: content,
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
            width: 240,
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
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
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: AppTheme.cardColor,
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
                            color: AppTheme.cardColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: AppTheme.textPrimary,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        AppStrings.of(context)?.categories ?? 'Categories',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
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
                    focusNode: _groupFocusNodes.isNotEmpty ? _groupFocusNodes[0] : null,
                    groupIndex: 0,
                    onTap: () {
                      setState(() {
                        _selectedGroup = null;
                        _currentGroupIndex = 0;
                      });
                      provider.clearGroupFilter();
                    },
                  ),
                ),

                const Divider(color: AppTheme.cardColor, height: 1),

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
                        focusNode: focusIndex < _groupFocusNodes.length ? _groupFocusNodes[focusIndex] : null,
                        groupIndex: focusIndex,
                        onTap: () {
                          setState(() {
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
        onFocus: PlatformDetector.isTV ? () {
          // TV端焦点移动自动选中分类
          _currentGroupIndex = groupIndex;
          onTap();
        } : null,
        onRight: PlatformDetector.isTV ? () {
          // 按右键跳转到频道网格的第一个频道
          if (_channelFocusNodes.isNotEmpty) {
            _channelFocusNodes[0].requestFocus();
          }
        } : null,
        onLeft: PlatformDetector.isTV ? () {
          // 按左键跳转到侧边菜单的当前选中项（频道页是index 1）
          final menuNodes = TVSidebar.menuFocusNodes;
          if (menuNodes != null && menuNodes.length > 1) {
            menuNodes[1].requestFocus(); // 频道页是第2个菜单项
          }
        } : null,
        focusScale: 1.02,
        showFocusBorder: false,
        builder: (context, isFocused, child) {
          return AnimatedContainer(
            duration: AppTheme.animationFast,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryColor.withOpacity(0.2)
                  : isFocused
                      ? AppTheme.cardColor
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isFocused
                    ? AppTheme.focusBorderColor
                    : isSelected
                        ? AppTheme.primaryColor.withOpacity(0.5)
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
                    color:
                        isSelected ? AppTheme.primaryColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),

                // Name
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Count badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryColor.withOpacity(0.2)
                        : AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.textMuted,
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
    return Consumer<ChannelProvider>(
      builder: (context, provider, _) {
        final channels = provider.filteredChannels;
        final size = MediaQuery.of(context).size;
        final crossAxisCount =
            PlatformDetector.getGridCrossAxisCount(size.width);

        return CustomScrollView(
          controller: _scrollController,
          slivers: [
            // App Bar
            SliverAppBar(
              floating: true,
              backgroundColor: AppTheme.backgroundColor.withOpacity(0.95),
              title: Text(
                _selectedGroup ??
                    (AppStrings.of(context)?.allChannels ?? 'All Channels'),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
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
                  color: AppTheme.textSecondary,
                  tooltip: '测试频道',
                  onPressed: channels.isEmpty
                      ? null
                      : () => _showChannelTestDialog(context, channels),
                ),
                // Delete all unavailable channels button (only show when in unavailable group)
                if (_selectedGroup == ChannelProvider.unavailableGroupName && channels.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_rounded),
                    color: AppTheme.errorColor,
                    tooltip: '删除所有失效频道',
                    onPressed: () => _confirmDeleteAllUnavailable(context, provider),
                  ),
                // Channel count
                Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${channels.length} ${AppStrings.of(context)?.channels ?? 'channels'}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
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
                        color: AppTheme.textMuted.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppStrings.of(context)?.noChannelsFound ??
                            'No channels found',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 180,
                    childAspectRatio: 1.17,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final channel = channels[index];
                      final isFavorite = context
                          .watch<FavoritesProvider>()
                          .isFavorite(channel.id ?? 0);
                      final isUnavailable = ChannelProvider.isUnavailableChannel(channel.groupName);
                      
                      // 获取 EPG 当前节目和下一个节目
                      final epgProvider = context.watch<EpgProvider>();
                      final currentProgram = epgProvider.getCurrentProgram(channel.epgId, channel.name);
                      final nextProgram = epgProvider.getNextProgram(channel.epgId, channel.name);
                      
                      // TV端：确保焦点节点数量正确
                      if (PlatformDetector.isTV) {
                        while (_channelFocusNodes.length <= index) {
                          _channelFocusNodes.add(FocusNode());
                        }
                      }
                      
                      // TV端：判断是否是第一列（需要处理左键导航）
                      final isFirstColumn = index % crossAxisCount == 0;
                      
                      // TV端：判断是否是最后一行（需要处理下键切换分类）
                      final totalRows = (channels.length / crossAxisCount).ceil();
                      final currentRow = index ~/ crossAxisCount;
                      final isLastRow = currentRow == totalRows - 1;

                      return ChannelCard(
                        name: channel.name,
                        logoUrl: channel.logoUrl,
                        groupName: isUnavailable 
                            ? ChannelProvider.extractOriginalGroup(channel.groupName)
                            : channel.groupName,
                        currentProgram: currentProgram?.title,
                        nextProgram: nextProgram?.title,
                        isFavorite: isFavorite,
                        isUnavailable: isUnavailable,
                        autofocus: index == 0,
                        focusNode: PlatformDetector.isTV && index < _channelFocusNodes.length 
                            ? _channelFocusNodes[index] 
                            : null,
                        onLeft: (PlatformDetector.isTV && isFirstColumn) ? () {
                          // 第一列按左键，跳转到当前选中的分类
                          if (_currentGroupIndex < _groupFocusNodes.length) {
                            _groupFocusNodes[_currentGroupIndex].requestFocus();
                          }
                        } : null,
                        onDown: (PlatformDetector.isTV && isLastRow) ? () {
                          // 最后一行按下键，不做任何事（阻止跳转）
                        } : null,
                        onFavoriteToggle: () {
                          context
                              .read<FavoritesProvider>()
                              .toggleFavorite(channel);
                        },
                        onTest: () => _testSingleChannel(context, channel),
                        onTap: () {
                          // 保存上次播放的频道ID
                          final settingsProvider = context.read<SettingsProvider>();
                          if (settingsProvider.rememberLastChannel && channel.id != null) {
                            settingsProvider.setLastChannelId(channel.id);
                          }
                          
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
                        onLongPress: () =>
                            _showChannelOptions(context, channel),
                      );
                    },
                    childCount: channels.length,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteAllUnavailable(BuildContext context, ChannelProvider provider) async {
    final count = provider.unavailableChannelCount;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '删除所有失效频道',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          '确定要删除全部 $count 个失效频道吗？此操作不可撤销。',
          style: const TextStyle(color: AppTheme.textSecondary),
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
      setState(() {
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
      if (result.isAvailable && ChannelProvider.isUnavailableChannel(channelObj.groupName)) {
        final provider = context.read<ChannelProvider>();
        final originalGroup = ChannelProvider.extractOriginalGroup(channelObj.groupName);
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
            backgroundColor: result.isAvailable ? Colors.green : AppTheme.errorColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _showChannelTestDialog(BuildContext context, List<dynamic> channels) async {
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
          backgroundColor: AppTheme.primaryColor,
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
      final unavailableCount = result.results.where((r) => !r.isAvailable).length;
      
      // 显示提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已将 $unavailableCount 个失效频道移至"${ChannelProvider.unavailableGroupName}"分类'),
          backgroundColor: Colors.orange,
          action: SnackBarAction(
            label: '查看',
            textColor: Colors.white,
            onPressed: () {
              // 跳转到失效分类
              setState(() {
                _selectedGroup = ChannelProvider.unavailableGroupName;
              });
              context.read<ChannelProvider>().selectGroup(ChannelProvider.unavailableGroupName);
            },
          ),
        ),
      );

      // 自动跳转到失效分类
      setState(() {
        _selectedGroup = ChannelProvider.unavailableGroupName;
      });
      context.read<ChannelProvider>().selectGroup(ChannelProvider.unavailableGroupName);
    }
  }

  void _showBackgroundTestProgress(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const BackgroundTestProgressDialog(),
    );
  }

  // ignore: unused_element
  Future<void> _deleteUnavailableChannels(List<ChannelTestResult> results) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '确认删除',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          '确定要删除 ${results.length} 个不可用的频道吗？此操作不可撤销。',
          style: const TextStyle(color: AppTheme.textSecondary),
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
      backgroundColor: AppTheme.surfaceColor,
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
                style: const TextStyle(
                  color: AppTheme.textPrimary,
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
                      : AppTheme.textSecondary,
                ),
                title: Text(
                  isFavorite
                      ? (AppStrings.of(context)?.removeFavorites ??
                          'Remove from Favorites')
                      : (AppStrings.of(context)?.addFavorites ??
                          'Add to Favorites'),
                  style: const TextStyle(color: AppTheme.textPrimary),
                ),
                onTap: () async {
                  await favoritesProvider.toggleFavorite(channel);
                  Navigator.pop(context);
                },
              ),

              ListTile(
                leading: const Icon(
                  Icons.info_outline_rounded,
                  color: AppTheme.textSecondary,
                ),
                title: Text(
                  AppStrings.of(context)?.channelInfo ?? 'Channel Info',
                  style: const TextStyle(color: AppTheme.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  // Show channel info dialog
                },
              ),

              ListTile(
                leading: const Icon(
                  Icons.speed_rounded,
                  color: AppTheme.textSecondary,
                ),
                title: const Text(
                  '测试频道',
                  style: TextStyle(color: AppTheme.textPrimary),
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
                    style: const TextStyle(color: AppTheme.textPrimary),
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

/// 后台测试进度指示器
class _BackgroundTestIndicator extends StatefulWidget {
  final VoidCallback onTap;

  const _BackgroundTestIndicator({required this.onTap});

  @override
  State<_BackgroundTestIndicator> createState() => _BackgroundTestIndicatorState();
}

class _BackgroundTestIndicatorState extends State<_BackgroundTestIndicator> {
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
      setState(() {
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
              ? AppTheme.primaryColor.withOpacity(0.2)
              : Colors.orange.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_progress.isRunning) ...[
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primaryColor,
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
