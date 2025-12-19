import 'package:flutter/foundation.dart';
import '../../../core/models/channel.dart';
import '../../../core/models/channel_group.dart';
import '../../../core/services/service_locator.dart';

class ChannelProvider extends ChangeNotifier {
  List<Channel> _channels = [];
  List<ChannelGroup> _groups = [];
  String? _selectedGroup;
  bool _isLoading = false;
  String? _error;

  // Getters
  List<Channel> get channels => _channels;
  List<ChannelGroup> get groups => _groups;
  String? get selectedGroup => _selectedGroup;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Channel> get filteredChannels {
    if (_selectedGroup == null) return _channels;
    // 如果选中失效频道分组，返回所有失效频道
    if (_selectedGroup == unavailableGroupName) {
      return _channels.where((c) => isUnavailableChannel(c.groupName)).toList();
    }
    return _channels.where((c) => c.groupName == _selectedGroup).toList();
  }

  int get totalChannelCount => _channels.length;

  // Load channels for a specific playlist
  Future<void> loadChannels(int playlistId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await ServiceLocator.database.query(
        'channels',
        where: 'playlist_id = ? AND is_active = 1',
        whereArgs: [playlistId],
        orderBy: 'id ASC',
      );

      debugPrint('DEBUG: 从数据库加载 ${results.length} 个频道，播放列表ID: $playlistId');

      _channels = results.map((r) {
        final channel = Channel.fromMap(r);
        debugPrint(
            'DEBUG: 加载频道 - 名称: ${channel.name}, 台标: ${channel.logoUrl ?? "无"}');
        return channel;
      }).toList();

      _updateGroups();
      _error = null;
    } catch (e) {
      debugPrint('DEBUG: 加载频道时出错: $e');
      _error = 'Failed to load channels: $e';
      _channels = [];
      _groups = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  // Load all channels from all active playlists
  Future<void> loadAllChannels() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await ServiceLocator.database.rawQuery('''
        SELECT c.* FROM channels c
        INNER JOIN playlists p ON c.playlist_id = p.id
        WHERE c.is_active = 1 AND p.is_active = 1
        ORDER BY c.id ASC
      ''');

      debugPrint('DEBUG: 从数据库加载所有 ${results.length} 个频道');

      _channels = results.map((r) {
        final channel = Channel.fromMap(r);
        debugPrint(
            'DEBUG: 加载频道 - 名称: ${channel.name}, 台标: ${channel.logoUrl ?? "无"}');
        return channel;
      }).toList();

      _updateGroups();
      _error = null;
    } catch (e) {
      debugPrint('DEBUG: 加载所有频道时出错: $e');
      _error = 'Failed to load channels: $e';
      _channels = [];
      _groups = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  void _updateGroups() {
    final Map<String, int> groupCounts = {};
    int unavailableCount = 0;

    for (final channel in _channels) {
      final group = channel.groupName ?? 'Uncategorized';
      // 将所有失效频道合并到一个分组
      if (isUnavailableChannel(group)) {
        unavailableCount++;
      } else {
        groupCounts[group] = (groupCounts[group] ?? 0) + 1;
      }
    }

    _groups = groupCounts.entries
        .map((e) => ChannelGroup(name: e.key, channelCount: e.value))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    
    // 如果有失效频道，添加到列表末尾
    if (unavailableCount > 0) {
      _groups.add(ChannelGroup(name: unavailableGroupName, channelCount: unavailableCount));
    }
  }

  // Select a group filter
  void selectGroup(String? groupName) {
    _selectedGroup = groupName;
    notifyListeners();
  }

  // Clear group filter
  void clearGroupFilter() {
    _selectedGroup = null;
    notifyListeners();
  }

  // Search channels by name
  List<Channel> searchChannels(String query) {
    if (query.isEmpty) return filteredChannels;

    final lowerQuery = query.toLowerCase();
    return _channels.where((c) {
      return c.name.toLowerCase().contains(lowerQuery) ||
          (c.groupName?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  // Get channels by group
  List<Channel> getChannelsByGroup(String groupName) {
    return _channels.where((c) => c.groupName == groupName).toList();
  }

  // Get a channel by ID
  Channel? getChannelById(int id) {
    try {
      return _channels.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  // Update favorite status for a channel
  void updateFavoriteStatus(int channelId, bool isFavorite) {
    final index = _channels.indexWhere((c) => c.id == channelId);
    if (index != -1) {
      _channels[index] = _channels[index].copyWith(isFavorite: isFavorite);
      notifyListeners();
    }
  }

  // Set currently playing channel
  void setCurrentlyPlaying(int? channelId) {
    for (int i = 0; i < _channels.length; i++) {
      final isPlaying = _channels[i].id == channelId;
      if (_channels[i].isCurrentlyPlaying != isPlaying) {
        _channels[i] = _channels[i].copyWith(isCurrentlyPlaying: isPlaying);
      }
    }
    notifyListeners();
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
      notifyListeners();
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

      _channels.removeWhere((c) => c.playlistId == playlistId);
      _updateGroups();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to delete channels: $e';
      notifyListeners();
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
        final channel = _channels.firstWhere((c) => c.id == id, orElse: () => _channels.first);
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
      for (int i = 0; i < _channels.length; i++) {
        if (channelIds.contains(_channels[i].id)) {
          final originalGroup = _channels[i].groupName ?? 'Uncategorized';
          if (!isUnavailableChannel(originalGroup)) {
            _channels[i] = _channels[i].copyWith(
              groupName: '$unavailableGroupPrefix|$originalGroup',
            );
          }
        }
      }

      _updateGroups();
      notifyListeners();

      debugPrint('DEBUG: 已将 ${channelIds.length} 个频道标记为失效');
    } catch (e) {
      debugPrint('DEBUG: 标记失效频道时出错: $e');
      _error = 'Failed to mark channels as unavailable: $e';
      notifyListeners();
    }
  }

  // 恢复失效频道到原分组
  Future<bool> restoreChannel(int channelId) async {
    try {
      final channel = _channels.firstWhere((c) => c.id == channelId);
      final originalGroup = extractOriginalGroup(channel.groupName);
      
      if (originalGroup == null) {
        debugPrint('DEBUG: 频道不是失效频道，无需恢复');
        return false;
      }

      await ServiceLocator.database.update(
        'channels',
        {'group_name': originalGroup},
        where: 'id = ?',
        whereArgs: [channelId],
      );

      final index = _channels.indexWhere((c) => c.id == channelId);
      if (index != -1) {
        _channels[index] = _channels[index].copyWith(groupName: originalGroup);
      }

      _updateGroups();
      notifyListeners();
      
      debugPrint('DEBUG: 已恢复频道到分组: $originalGroup');
      return true;
    } catch (e) {
      _error = 'Failed to restore channel: $e';
      notifyListeners();
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

      _channels.removeWhere((c) => isUnavailableChannel(c.groupName));
      _updateGroups();
      notifyListeners();

      debugPrint('DEBUG: 已删除 $count 个失效频道');
      return count;
    } catch (e) {
      _error = 'Failed to delete unavailable channels: $e';
      notifyListeners();
      return 0;
    }
  }

  // 获取失效频道数量
  int get unavailableChannelCount {
    return _channels.where((c) => isUnavailableChannel(c.groupName)).length;
  }

  // Clear all data
  void clear() {
    _channels = [];
    _groups = [];
    _selectedGroup = null;
    _error = null;
    notifyListeners();
  }
}
