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
        orderBy: 'group_name, name',
      );
      
      _channels = results.map((r) => Channel.fromMap(r)).toList();
      _updateGroups();
      _error = null;
    } catch (e) {
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
        ORDER BY c.group_name, c.name
      ''');
      
      _channels = results.map((r) => Channel.fromMap(r)).toList();
      _updateGroups();
      _error = null;
    } catch (e) {
      _error = 'Failed to load channels: $e';
      _channels = [];
      _groups = [];
    }
    
    _isLoading = false;
    notifyListeners();
  }
  
  void _updateGroups() {
    final Map<String, int> groupCounts = {};
    
    for (final channel in _channels) {
      final group = channel.groupName ?? 'Uncategorized';
      groupCounts[group] = (groupCounts[group] ?? 0) + 1;
    }
    
    _groups = groupCounts.entries
        .map((e) => ChannelGroup(name: e.key, channelCount: e.value))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
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
  
  // Clear all data
  void clear() {
    _channels = [];
    _groups = [];
    _selectedGroup = null;
    _error = null;
    notifyListeners();
  }
}
