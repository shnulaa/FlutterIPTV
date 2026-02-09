import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/models/channel.dart';
import '../../../core/models/channel_group.dart';
import '../../../core/services/service_locator.dart';

class ChannelProvider extends ChangeNotifier {
  // ✅ 全局缓存：一次性加载所有频道
  List<Channel> _allChannels = [];
  List<ChannelGroup> _allGroups = [];
  
  // ✅ UI分页显示：避免一次性渲染太多台标
  List<Channel> _displayedChannels = []; // UI显示的频道（分页累积）
  static const int _displayPageSize = 50; // 每次显示50个
  int _displayedCount = 0; // 已显示的数量
  
  // 当前筛选条件
  String? _selectedGroup;
  bool _isLoading = false;
  String? _error;

  // ✅ 分页相关（仅用于UI显示）
  bool _hasMoreToDisplay = true;
  bool _isLoadingMore = false;
  int? _currentPlaylistId;

  // ✅ 台标加载控制
  bool _isLogoLoadingPaused = false;
  int _loadingGeneration = 0;

  // ✅ 节流通知：防止频繁调用 notifyListeners() 阻塞主线程
  Timer? _notifyTimer;
  bool _hasPendingNotify = false;
  static const _notifyThrottleDuration = Duration(milliseconds: 100); // 100ms节流

  // Getters
  List<Channel> get allChannels => _allChannels; // 全局缓存（所有频道）
  List<Channel> get channels => _displayedChannels; // UI显示的频道（分页）
  List<ChannelGroup> get groups => _allGroups;
  String? get selectedGroup => _selectedGroup;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMoreToDisplay;
  String? get error => _error;
  int get totalChannelCount => _allChannels.length;
  int get loadedChannelCount => _displayedChannels.length;

  // ✅ 节流通知：防止频繁调用 notifyListeners()
  void _throttledNotify() {
    _hasPendingNotify = true;
    
    // 如果已经有定时器在运行，不创建新的
    if (_notifyTimer?.isActive ?? false) {
      return;
    }

    // 创建新的定时器
    _notifyTimer = Timer(_notifyThrottleDuration, () {
      if (_hasPendingNotify) {
        _hasPendingNotify = false;
        notifyListeners();
      }
    });
  }

  // ✅ 立即通知（用于重要状态变化）
  void _immediateNotify() {
    _notifyTimer?.cancel();
    _hasPendingNotify = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _notifyTimer?.cancel();
    super.dispose();
  }
  List<Channel> get filteredChannels {
    if (_selectedGroup == null) return _allChannels;
    if (_selectedGroup == unavailableGroupName) {
      return _allChannels.where((c) => isUnavailableChannel(c.groupName)).toList();
    }
    return _allChannels.where((c) => c.groupName == _selectedGroup).toList();
  }

  // ✅ UI显示的筛选频道（分页显示）
  List<Channel> get displayedFilteredChannels {
    if (_selectedGroup == null) return _displayedChannels;
    if (_selectedGroup == unavailableGroupName) {
      return _displayedChannels.where((c) => isUnavailableChannel(c.groupName)).toList();
    }
    return _displayedChannels.where((c) => c.groupName == _selectedGroup).toList();
  }

  // ✅ 首页数据：获取指定数量的分类
  List<ChannelGroup> getHomeGroups({int maxGroups = 8}) {
    return _allGroups.take(maxGroups).toList();
  }

  // ✅ 首页数据：每个分类指定数量的频道
  Map<String, List<Channel>> getHomeChannelsByGroup({int maxGroups = 8, int channelsPerGroup = 12}) {
    final result = <String, List<Channel>>{};
    final groups = _allGroups.take(maxGroups);
    
    for (final group in groups) {
      final channels = _allChannels
          .where((c) => c.groupName == group.name)
          .take(channelsPerGroup)
          .toList();
      if (channels.isNotEmpty) {
        result[group.name] = channels;
      }
    }
    
    return result;
  }

  // ✅ 重置UI显示状态
  void _resetDisplay() {
    _displayedChannels.clear();
    _displayedCount = 0;
    _hasMoreToDisplay = true;
  }

  // ✅ 清空全局缓存（切换/刷新/删除 playlist 时调用）
  void clearCache() {
    // 1. 取消所有待通知主线程的队列
    _notifyTimer?.cancel();
    _hasPendingNotify = false;
    
    // 2. 取消所有正在进行的台标加载任务（通过增加 generation ID）
    _loadingGeneration++;
    
    // 3. 清空所有缓存数据
    _allChannels.clear();
    _allGroups.clear();
    _displayedChannels.clear();
    _displayedCount = 0;
    _hasMoreToDisplay = true;
    _currentPlaylistId = null;
    
    ServiceLocator.log.i('缓存已清空，台标加载已取消 (generation: $_loadingGeneration)', tag: 'ChannelProvider');
  }

  // ✅ 加载所有频道到全局缓存（一次性加载，但UI分页显示）
  Future<void> loadAllChannelsToCache(int playlistId, {bool loadMore = false}) async {
    if (loadMore) {
      // UI加载更多：从缓存中取下一批显示
      return _loadMoreToDisplay();
    }

    // 首次加载：清空缓存并重置状态
    ServiceLocator.log.i('加载所有频道到全局缓存: $playlistId', tag: 'ChannelProvider');
    clearCache();
    _currentPlaylistId = playlistId;
    _isLoading = true;
    _error = null;
    _immediateNotify(); // 立即通知加载开始

    final startTime = DateTime.now();

    try {
      // ✅ 一次性加载所有频道到缓存
      final results = await ServiceLocator.database.query(
        'channels',
        where: 'playlist_id = ? AND is_active = 1',
        whereArgs: [playlistId],
        orderBy: 'id ASC',
      );

      _allChannels = results.map((r) => Channel.fromMap(r)).toList();
      
      ServiceLocator.log.i(
          '缓存加载完成: ${_allChannels.length} 个频道',
          tag: 'ChannelProvider');

      // 从缓存中统计分类
      _updateGroups();

      // ✅ 初始显示第一批频道
      _loadMoreToDisplay(isInitial: true);

      // 后台填充备用台标，不阻塞UI（分批处理）
      _populateFallbackLogosInBatches(_allChannels, _loadingGeneration);

      final loadTime = DateTime.now().difference(startTime).inMilliseconds;
      ServiceLocator.log.i(
          '频道加载完成，耗时: ${loadTime}ms，显示: ${_displayedChannels.length}/${_allChannels.length}',
          tag: 'ChannelProvider');
      _error = null;
    } catch (e) {
      ServiceLocator.log.e('加载频道失败', tag: 'ChannelProvider', error: e);
      _error = 'Failed to load channels: $e';
      _allChannels = [];
      _allGroups = [];
    }

    _isLoading = false;
    _immediateNotify(); // 立即通知加载完成
  }

  // ✅ 从缓存中加载更多到UI显示
  Future<void> _loadMoreToDisplay({bool isInitial = false}) async {
    if (!isInitial) {
      if (_isLoadingMore || !_hasMoreToDisplay) return;
      _isLoadingMore = true;
      _immediateNotify(); // 立即通知开始加载更多
    }

    // 从缓存中取下一批
    final startIndex = _displayedCount;
    final endIndex = (_displayedCount + _displayPageSize).clamp(0, _allChannels.length);
    
    if (startIndex >= _allChannels.length) {
      _hasMoreToDisplay = false;
      if (!isInitial) {
        _isLoadingMore = false;
        _immediateNotify();
      }
      return;
    }

    final nextBatch = _allChannels.sublist(startIndex, endIndex);
    _displayedChannels.addAll(nextBatch);
    _displayedCount = endIndex;
    _hasMoreToDisplay = _displayedCount < _allChannels.length;

    ServiceLocator.log.d(
        'UI显示更新: ${_displayedChannels.length}/${_allChannels.length}',
        tag: 'ChannelProvider');

    if (!isInitial) {
      _isLoadingMore = false;
      _immediateNotify(); // 立即通知加载更多完成
    }
  }

  // Load channels for a specific playlist (兼容旧代码)
  Future<void> loadChannels(int playlistId, {bool loadMore = false}) async {
    return loadAllChannelsToCache(playlistId, loadMore: loadMore);
  }

  // Load all channels from all active playlists (一次性加载到缓存，UI分页显示)
  Future<void> loadAllChannels({bool loadMore = false}) async {
    if (loadMore) {
      // UI加载更多：从缓存中取下一批显示
      return _loadMoreToDisplay();
    }

    clearCache();
    _isLoading = true;
    _error = null;
    _immediateNotify(); // 立即通知加载开始

    final startTime = DateTime.now();

    try {
      // ✅ 一次性加载所有频道到缓存
      final results = await ServiceLocator.database.rawQuery('''
        SELECT c.* FROM channels c
        INNER JOIN playlists p ON c.playlist_id = p.id
        WHERE c.is_active = 1 AND p.is_active = 1
        ORDER BY c.id ASC
      ''');

      _allChannels = results.map((r) => Channel.fromMap(r)).toList();
      
      ServiceLocator.log.i(
          '缓存加载完成: ${_allChannels.length} 个频道',
          tag: 'ChannelProvider');

      // 从缓存中统计分类
      _updateGroups();

      // ✅ 初始显示第一批频道
      _loadMoreToDisplay(isInitial: true);

      // 后台填充备用台标，不阻塞UI（分批处理）
      _populateFallbackLogosInBatches(_allChannels, _loadingGeneration);

      final loadTime = DateTime.now().difference(startTime).inMilliseconds;
      ServiceLocator.log.i(
          '所有频道加载完成，耗时: ${loadTime}ms，显示: ${_displayedChannels.length}/${_allChannels.length}',
          tag: 'ChannelProvider');
      _error = null;
    } catch (e) {
      _error = 'Failed to load channels: $e';
      _allChannels = [];
      _allGroups = [];
    }

    _isLoading = false;
    _immediateNotify(); // 立即通知加载完成
  }

  void _updateGroups() {
    final Map<String, int> groupCounts = {};
    final List<String> groupOrder = []; // 保持原始顺序
    int unavailableCount = 0;

    for (final channel in _allChannels) {
      final group = channel.groupName ?? 'Uncategorized';
      // 将所有失效频道合并到一个分组
      if (isUnavailableChannel(group)) {
        unavailableCount++;
      } else {
        if (!groupCounts.containsKey(group)) {
          groupOrder.add(group); // 记录首次出现的顺序
        }
        groupCounts[group] = (groupCounts[group] ?? 0) + 1;
      }
    }

    // 按原始顺序创建分组列表
    _allGroups = groupOrder
        .map((name) =>
            ChannelGroup(name: name, channelCount: groupCounts[name] ?? 0))
        .toList();

    // 如果有失效频道，添加到列表末尾
    if (unavailableCount > 0) {
      _allGroups.add(ChannelGroup(
          name: unavailableGroupName, channelCount: unavailableCount));
    }
  }

  // Select a group filter
  void selectGroup(String? groupName) {
    _selectedGroup = groupName;

    // 切换分类时，清理台标加载队列，避免堆积
    try {
      clearLogoLoadingQueue();
      ServiceLocator.log.d('切换分类到: $groupName，已清理台标加载队列');
    } catch (e) {
      ServiceLocator.log.w('清理台标队列失败: $e');
    }

    _immediateNotify(); // 立即通知分类切换
  }

  // Clear group filter
  void clearGroupFilter() {
    _selectedGroup = null;
    _immediateNotify(); // 立即通知清除筛选
  }

  // Search channels by name
  List<Channel> searchChannels(String query) {
    if (query.isEmpty) return filteredChannels;

    final lowerQuery = query.toLowerCase();
    return _allChannels.where((c) {
      return c.name.toLowerCase().contains(lowerQuery) ||
          (c.groupName?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  // Get channels by group
  List<Channel> getChannelsByGroup(String groupName) {
    return _allChannels.where((c) => c.groupName == groupName).toList();
  }

  // Get a channel by ID
  Channel? getChannelById(int id) {
    try {
      return _allChannels.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  // Update favorite status for a channel
  void updateFavoriteStatus(int channelId, bool isFavorite) {
    final index = _allChannels.indexWhere((c) => c.id == channelId);
    if (index != -1) {
      _allChannels[index] = _allChannels[index].copyWith(isFavorite: isFavorite);
      _throttledNotify(); // 使用节流通知（非关键更新）
    }
  }

  // Set currently playing channel
  void setCurrentlyPlaying(int? channelId) {
    for (int i = 0; i < _allChannels.length; i++) {
      final isPlaying = _allChannels[i].id == channelId;
      if (_allChannels[i].isCurrentlyPlaying != isPlaying) {
        _allChannels[i] = _allChannels[i].copyWith(isCurrentlyPlaying: isPlaying);
      }
    }
    _throttledNotify(); // 使用节流通知（非关键更新）
  }

  // Add channels from parsing
  Future<void> addChannels(List<Channel> channels) async {
    try {
      for (final channel in channels) {
        await ServiceLocator.database.insert('channels', channel.toMap());
      }

      // Reload channels
      if (channels.isNotEmpty) {
        await loadChannels(channels.first.playlistId);
      }
    } catch (e) {
      _error = 'Failed to add channels: $e';
      _immediateNotify(); // 立即通知错误
    }
  }

  // Delete channels for a playlist
  Future<void> deleteChannelsForPlaylist(int playlistId) async {
    try {
      await ServiceLocator.database.delete(
        'channels',
        where: 'playlist_id = ?',
        whereArgs: [playlistId],
      );

      _allChannels.removeWhere((c) => c.playlistId == playlistId);
      _updateGroups();
      _immediateNotify(); // 立即通知删除完成
    } catch (e) {
      _error = 'Failed to delete channels: $e';
      _immediateNotify(); // 立即通知错误
    }
  }

  // 失效频道分类名称前缀
  static const String unavailableGroupPrefix = '⚠️ 失效频道';
  static const String unavailableGroupName = '⚠️ 失效频道';

  // 从失效分组名中提取原始分组名
  static String? extractOriginalGroup(String? groupName) {
    if (groupName == null || !groupName.startsWith(unavailableGroupPrefix)) {
      return null;
    }
    // 格式: "⚠️ 失效频道|原始分组名"
    final parts = groupName.split('|');
    if (parts.length > 1) {
      return parts[1];
    }
    return 'Uncategorized';
  }

  // 检查是否是失效频道
  static bool isUnavailableChannel(String? groupName) {
    return groupName != null && groupName.startsWith(unavailableGroupPrefix);
  }

  // 将频道标记为失效（移动到失效分类，保留原始分组信息）
  Future<void> markChannelsAsUnavailable(List<int> channelIds) async {
    if (channelIds.isEmpty) return;

    try {
      // 批量更新频道分组，保存原始分组名
      for (final id in channelIds) {
        final channel = _allChannels.firstWhere((c) => c.id == id,
            orElse: () => _allChannels.first);
        final originalGroup = channel.groupName ?? 'Uncategorized';
        // 如果已经是失效频道，不重复标记
        if (isUnavailableChannel(originalGroup)) continue;

        final newGroupName = '$unavailableGroupPrefix|$originalGroup';

        await ServiceLocator.database.update(
          'channels',
          {'group_name': newGroupName},
          where: 'id = ?',
          whereArgs: [id],
        );
      }

      // 更新内存中的频道数据
      for (int i = 0; i < _allChannels.length; i++) {
        if (channelIds.contains(_allChannels[i].id)) {
          final originalGroup = _allChannels[i].groupName ?? 'Uncategorized';
          if (!isUnavailableChannel(originalGroup)) {
            _allChannels[i] = _allChannels[i].copyWith(
              groupName: '$unavailableGroupPrefix|$originalGroup',
            );
          }
        }
      }

      _updateGroups();
      _immediateNotify(); // 立即通知标记完成

      ServiceLocator.log.d('DEBUG: 已将 ${channelIds.length} 个频道标记为失效');
    } catch (e) {
      ServiceLocator.log.d('DEBUG: 标记失效频道时出错: $e');
      _error = 'Failed to mark channels as unavailable: $e';
      _immediateNotify(); // 立即通知错误
    }
  }

  // 恢复失效频道到原分组
  Future<bool> restoreChannel(int channelId) async {
    try {
      final channel = _allChannels.firstWhere((c) => c.id == channelId);
      final originalGroup = extractOriginalGroup(channel.groupName);

      if (originalGroup == null) {
        ServiceLocator.log.d('DEBUG: 频道不是失效频道，无需恢复');
        return false;
      }

      await ServiceLocator.database.update(
        'channels',
        {'group_name': originalGroup},
        where: 'id = ?',
        whereArgs: [channelId],
      );

      final index = _allChannels.indexWhere((c) => c.id == channelId);
      if (index != -1) {
        _allChannels[index] = _allChannels[index].copyWith(groupName: originalGroup);
      }

      _updateGroups();
      _immediateNotify(); // 立即通知恢复完成

      ServiceLocator.log.d('DEBUG: 已恢复频道到分组: $originalGroup');
      return true;
    } catch (e) {
      _error = 'Failed to restore channel: $e';
      _immediateNotify(); // 立即通知错误
      return false;
    }
  }

  // 删除所有失效频道
  Future<int> deleteAllUnavailableChannels() async {
    try {
      final count = await ServiceLocator.database.delete(
        'channels',
        where: 'group_name LIKE ?',
        whereArgs: ['$unavailableGroupPrefix%'],
      );

      _allChannels.removeWhere((c) => isUnavailableChannel(c.groupName));
      _updateGroups();
      _immediateNotify(); // 立即通知删除完成

      ServiceLocator.log.d('DEBUG: 已删除 $count 个失效频道');
      return count;
    } catch (e) {
      _error = 'Failed to delete unavailable channels: $e';
      _immediateNotify(); // 立即通知错误
      return 0;
    }
  }

  // 获取失效频道数量
  int get unavailableChannelCount {
    return _allChannels.where((c) => isUnavailableChannel(c.groupName)).length;
  }

  // ✅ 暂停台标加载（例如在快速滚动时）
  void pauseLogoLoading() {
    _isLogoLoadingPaused = true;
  }

  // ✅ 恢复台标加载
  void resumeLogoLoading() {
    _isLogoLoadingPaused = false;
  }

  // ✅ 清理台标加载队列（取消当前所有后台加载任务）
  void clearLogoLoadingQueue() {
    // 1. 取消待通知主线程的队列
    _notifyTimer?.cancel();
    _hasPendingNotify = false;
    
    // 2. 增加 generation ID，取消所有正在进行的台标加载
    _loadingGeneration++;
    
    ServiceLocator.log.d('台标加载队列已清理 (generation: $_loadingGeneration)', tag: 'ChannelProvider');
  }

  // ✅ 后台填充备用台标 (分批处理，避免阻塞主线程)
  Future<void> _populateFallbackLogosInBatches(
      List<Channel> channelsToProcess, int generationId) async {
    final stopwatch = Stopwatch()..start();
    int processedCount = 0;
    const batchSize = 20; // 每批20个
    const delayBetweenBatches = 50; // 每批之间延迟50ms，让出更多时间给UI

    // 创建一个副本进行迭代，避免在迭代时修改列表
    final List<Channel> processingList = List.from(channelsToProcess);

    for (int i = 0; i < processingList.length; i += batchSize) {
      // 检查任务是否已取消
      if (generationId != _loadingGeneration) return;

      // 如果暂停加载，等待直到恢复
      while (_isLogoLoadingPaused) {
        if (generationId != _loadingGeneration) return;
        await Future.delayed(const Duration(milliseconds: 100));
      }

      final end = (i + batchSize < processingList.length)
          ? i + batchSize
          : processingList.length;
      final batch = processingList.sublist(i, end);

      // 筛选需要查询台标的频道
      final channelsToQuery =
          batch.where((c) => c.logoUrl == null || c.logoUrl!.isEmpty).toList();

      if (channelsToQuery.isNotEmpty) {
        try {
          final names = channelsToQuery.map((c) => c.name).toList();
          // 批量查询，显著减少 Platform Channel 消息数量
          final logos =
              await ServiceLocator.channelLogo.findLogoUrlsBulk(names);

          // 更新结果
          for (final channel in channelsToQuery) {
            if (logos.containsKey(channel.name)) {
              channel.fallbackLogoUrl = logos[channel.name];
              processedCount++;
            }
          }
        } catch (e) {
          ServiceLocator.log.w('批量获取台标失败: $e');
        }
      }

      // 每处理完一个批次，延迟更长时间让出主线程
      if (i + batchSize < processingList.length) {
        await Future.delayed(Duration(milliseconds: delayBetweenBatches));
      }
    }

    stopwatch.stop();
    if (processedCount > 0 && generationId == _loadingGeneration) {
      ServiceLocator.log.i(
          '备用台标处理完成，为 $processedCount 个频道找到台标，耗时: ${stopwatch.elapsedMilliseconds}ms',
          tag: 'ChannelProvider');
    }
  }

  // ✅ 后台填充备用台标 (旧方法，保持兼容)
  Future<void> _populateFallbackLogos(
      List<Channel> channelsToProcess, int generationId) async {
    return _populateFallbackLogosInBatches(channelsToProcess, generationId);
  }

  // Clear all data
  void clear() {
    _allChannels = [];
    _allGroups = [];
    _selectedGroup = null;
    _error = null;
    _immediateNotify(); // 立即通知清空完成
  }
}
