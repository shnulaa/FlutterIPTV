import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import '../../../core/models/playlist.dart';
import '../../../core/models/channel.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/utils/m3u_parser.dart';
import '../../favorites/providers/favorites_provider.dart';
import '../../settings/providers/settings_provider.dart';

class PlaylistProvider extends ChangeNotifier {
  List<Playlist> _playlists = [];
  Playlist? _activePlaylist;
  bool _isLoading = false;
  String? _error;
  double _importProgress = 0.0;
  
  /// Last extracted EPG URL from M3U file
  String? _lastExtractedEpgUrl;
  String? get lastExtractedEpgUrl => _lastExtractedEpgUrl;
  
  /// Apply extracted EPG URL to settings if available
  Future<bool> applyExtractedEpgUrl(SettingsProvider settingsProvider) async {
    if (_lastExtractedEpgUrl == null || _lastExtractedEpgUrl!.isEmpty) {
      return false;
    }
    
    try {
      debugPrint('DEBUG: 自动应用EPG URL: $_lastExtractedEpgUrl');
      await settingsProvider.setEpgUrl(_lastExtractedEpgUrl!);
      await settingsProvider.setEnableEpg(true);
      return true;
    } catch (e) {
      debugPrint('DEBUG: 应用EPG URL失败: $e');
      return false;
    }
  }

  // Getters
  List<Playlist> get playlists => _playlists;
  Playlist? get activePlaylist => _activePlaylist;
  bool get isLoading => _isLoading;
  String? get error => _error;
  double get importProgress => _importProgress;

  bool get hasPlaylists => _playlists.isNotEmpty;

  String _sortBy = 'name ASC';
  String get sortBy => _sortBy;

  void toggleSortOrder() {
    if (_sortBy == 'name ASC') {
      _sortBy = 'created_at DESC';
    } else {
      _sortBy = 'name ASC';
    }
    loadPlaylists();
  }

  // Load all playlists from database
  Future<void> loadPlaylists() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await ServiceLocator.database.query(
        'playlists',
        orderBy: _sortBy,
      );

      _playlists = results.map((r) => Playlist.fromMap(r)).toList();

      // Load channel counts for each playlist
      for (int i = 0; i < _playlists.length; i++) {
        final countResult = await ServiceLocator.database.rawQuery(
          'SELECT COUNT(*) as count, COUNT(DISTINCT group_name) as groups FROM channels WHERE playlist_id = ?',
          [_playlists[i].id],
        );

        if (countResult.isNotEmpty) {
          _playlists[i] = _playlists[i].copyWith(
            channelCount: countResult.first['count'] as int? ?? 0,
            groupCount: countResult.first['groups'] as int? ?? 0,
          );
        }
      }

      // Set active playlist if none selected
      if (_activePlaylist == null && _playlists.isNotEmpty) {
        _activePlaylist = _playlists.firstWhere(
          (p) => p.isActive,
          orElse: () => _playlists.first,
        );
      }

      _error = null;
    } catch (e) {
      _error = 'Failed to load playlists: $e';
      _playlists = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  // Add a new playlist from URL
  Future<Playlist?> addPlaylistFromUrl(String name, String url) async {
    _isLoading = true;
    _importProgress = 0.0;
    _error = null;
    notifyListeners();

    int? playlistId;
    try {
      // Create playlist record
      final playlistData = Playlist(
        name: name,
        url: url,
        createdAt: DateTime.now(),
      ).toMap();

      playlistId =
          await ServiceLocator.database.insert('playlists', playlistData);

      _importProgress = 0.2;
      notifyListeners();

      // Parse M3U from URL
      final channels = await M3UParser.parseFromUrl(url, playlistId);
      
      // Check for EPG URL in M3U header
      _lastExtractedEpgUrl = M3UParser.lastParseResult?.epgUrl;
      if (_lastExtractedEpgUrl != null) {
        debugPrint('DEBUG: 从M3U提取到EPG URL: $_lastExtractedEpgUrl');
      }

      _importProgress = 0.6;
      notifyListeners();

      if (channels.isEmpty) {
        throw Exception('No channels found in playlist');
      }

      // Use batch for much faster insertion
      final batch = ServiceLocator.database.db.batch();
      for (final channel in channels) {
        batch.insert('channels', channel.toMap());
      }
      await batch.commit(noResult: true);

      // Update playlist with last updated timestamp and counts
      await ServiceLocator.database.update(
        'playlists',
        {
          'last_updated': DateTime.now().millisecondsSinceEpoch,
          'channel_count':
              channels.length, // Store locally to avoid immediate recounting
        },
        where: 'id = ?',
        whereArgs: [playlistId],
      );

      _importProgress = 1.0;
      notifyListeners();

      // Reload playlists
      await loadPlaylists();

      return _playlists.firstWhere((p) => p.id == playlistId);
    } catch (e) {
      // 如果失败，删除已创建的播放列表记录
      if (playlistId != null) {
        try {
          await ServiceLocator.database.delete(
            'playlists',
            where: 'id = ?',
            whereArgs: [playlistId],
          );
        } catch (_) {}
      }
      _error = 'Failed to add playlist: $e';
      _isLoading = false;
      notifyListeners();
      rethrow; // 重新抛出异常让 UI 显示错误
    }
  }

  // Add a new playlist from M3U content directly (for QR import)
  Future<Playlist?> addPlaylistFromContent(String name, String content) async {
    _isLoading = true;
    _importProgress = 0.0;
    _error = null;
    notifyListeners();

    try {
      // Create playlist record
      final playlistData = Playlist(
        name: name,
        createdAt: DateTime.now(),
      ).toMap();

      final playlistId =
          await ServiceLocator.database.insert('playlists', playlistData);

      _importProgress = 0.2;
      notifyListeners();

      // Parse M3U content directly
      final channels = M3UParser.parse(content, playlistId);
      
      // Check for EPG URL in M3U header
      _lastExtractedEpgUrl = M3UParser.lastParseResult?.epgUrl;
      if (_lastExtractedEpgUrl != null) {
        debugPrint('DEBUG: 从M3U提取到EPG URL: $_lastExtractedEpgUrl');
      }

      _importProgress = 0.6;
      notifyListeners();

      if (channels.isEmpty) {
        throw Exception('No channels found in playlist');
      }

      // Use batch for much faster insertion
      final batch = ServiceLocator.database.db.batch();
      for (final channel in channels) {
        batch.insert('channels', channel.toMap());
      }
      await batch.commit(noResult: true);

      // Save the content as a temporary file for future refreshes
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempFile =
          await File('${tempDir.path}/playlist_${playlistId}_$timestamp.m3u')
              .writeAsString(content);

      debugPrint('DEBUG: 保存临时播放列表文件: ${tempFile.path}');

      // Update playlist with last updated timestamp, counts and file path
      await ServiceLocator.database.update(
        'playlists',
        {
          'last_updated': DateTime.now().millisecondsSinceEpoch,
          'channel_count': channels.length,
          'file_path':
              tempFile.path, // Save temp file path for future refreshes
        },
        where: 'id = ?',
        whereArgs: [playlistId],
      );

      _importProgress = 1.0;
      notifyListeners();

      // Reload playlists
      await loadPlaylists();

      return _playlists.firstWhere((p) => p.id == playlistId);
    } catch (e) {
      debugPrint('DEBUG: 添加内容播放列表时出错: $e');
      _error = 'Failed to add playlist: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // Add a new playlist from local file
  Future<Playlist?> addPlaylistFromFile(String name, String filePath) async {
    _isLoading = true;
    _importProgress = 0.0;
    _error = null;
    notifyListeners();

    try {
      // Create playlist record
      final playlistData = Playlist(
        name: name,
        filePath: filePath,
        createdAt: DateTime.now(),
      ).toMap();

      final playlistId =
          await ServiceLocator.database.insert('playlists', playlistData);

      _importProgress = 0.2;
      notifyListeners();

      // Parse M3U from file
      final channels = await M3UParser.parseFromFile(filePath, playlistId);
      
      // Check for EPG URL in M3U header
      _lastExtractedEpgUrl = M3UParser.lastParseResult?.epgUrl;
      if (_lastExtractedEpgUrl != null) {
        debugPrint('DEBUG: 从M3U提取到EPG URL: $_lastExtractedEpgUrl');
      }

      _importProgress = 0.6;
      notifyListeners();

      // Insert channels
      // Insert channels using batch for performance
      final batch = ServiceLocator.database.db.batch();
      for (final channel in channels) {
        batch.insert('channels', channel.toMap());
      }
      await batch.commit(noResult: true);

      // Update playlist channel count
      await ServiceLocator.database.update(
        'playlists',
        {
          'last_updated': DateTime.now().millisecondsSinceEpoch,
          'channel_count': channels.length,
        },
        where: 'id = ?',
        whereArgs: [playlistId],
      );

      _importProgress = 1.0;
      notifyListeners();

      // Reload playlists
      await loadPlaylists();

      return _playlists.firstWhere((p) => p.id == playlistId);
    } catch (e) {
      _error = 'Failed to add playlist: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // Refresh a playlist from its source
  Future<bool> refreshPlaylist(Playlist playlist) async {
    if (playlist.id == null) return false;

    debugPrint('DEBUG: 开始刷新播放列表: ${playlist.name} (ID: ${playlist.id})');
    debugPrint('DEBUG: playlist.url = ${playlist.url}');
    debugPrint('DEBUG: playlist.filePath = ${playlist.filePath}');
    debugPrint('DEBUG: playlist.isRemote = ${playlist.isRemote}');
    debugPrint('DEBUG: playlist.isLocal = ${playlist.isLocal}');

    _isLoading = true;
    _importProgress = 0.0;
    _error = null;
    notifyListeners();

    try {
      // 重新从数据库加载 playlist 以确保数据是最新的
      final dbResults = await ServiceLocator.database.query(
        'playlists',
        where: 'id = ?',
        whereArgs: [playlist.id],
      );
      
      if (dbResults.isEmpty) {
        throw Exception('Playlist not found in database');
      }
      
      final freshPlaylist = Playlist.fromMap(dbResults.first);
      debugPrint('DEBUG: 从数据库重新加载 - URL: ${freshPlaylist.url}, FilePath: ${freshPlaylist.filePath}');
      
      List<Channel> channels;

      debugPrint(
          'DEBUG: 播放列表源类型: ${freshPlaylist.isRemote ? "远程URL" : freshPlaylist.isLocal ? "本地文件" : "未知"}');
      debugPrint('DEBUG: 播放列表源路径: ${freshPlaylist.sourcePath}');

      if (freshPlaylist.isRemote) {
        debugPrint('DEBUG: 开始从URL解析播放列表: ${freshPlaylist.url}');
        channels = await M3UParser.parseFromUrl(freshPlaylist.url!, playlist.id!);
      } else if (freshPlaylist.isLocal) {
        debugPrint('DEBUG: 开始从本地文件解析播放列表: ${freshPlaylist.filePath}');

        // Check if file exists before trying to parse
        final file = File(freshPlaylist.filePath!);
        if (!await file.exists()) {
          debugPrint('DEBUG: 本地文件不存在: ${freshPlaylist.filePath}');
          throw Exception(
              'Local playlist file not found: ${freshPlaylist.filePath}');
        }

        channels =
            await M3UParser.parseFromFile(freshPlaylist.filePath!, playlist.id!);
      } else {
        // Check if this is a content-imported playlist without a proper file path
        debugPrint(
            'DEBUG: 播放列表源无效，URL: ${freshPlaylist.url}, 文件路径: ${freshPlaylist.filePath}');
        throw Exception(
            'Invalid playlist source - URL: ${freshPlaylist.url}, File: ${freshPlaylist.filePath}');
      }
      
      // Check for EPG URL in M3U header
      _lastExtractedEpgUrl = M3UParser.lastParseResult?.epgUrl;
      if (_lastExtractedEpgUrl != null) {
        debugPrint('DEBUG: 从M3U提取到EPG URL: $_lastExtractedEpgUrl');
      }

      debugPrint('DEBUG: 解析完成，共找到 ${channels.length} 个频道');

      _importProgress = 0.5;
      notifyListeners();

      // Delete existing channels
      debugPrint('DEBUG: 开始删除现有频道数据...');
      final deleteResult = await ServiceLocator.database.delete(
        'channels',
        where: 'playlist_id = ?',
        whereArgs: [playlist.id],
      );
      debugPrint('DEBUG: 已删除 $deleteResult 个旧频道记录');

      // Insert new channels - 改为使用批量插入以提高性能
      debugPrint('DEBUG: 开始批量插入新频道...');
      final batch = ServiceLocator.database.db.batch();
      for (final channel in channels) {
        final channelMap = channel.toMap();
        debugPrint(
            'DEBUG: 插入频道 - 名称: ${channel.name}, 台标: ${channel.logoUrl ?? "无"}');
        batch.insert('channels', channelMap);
      }
      await batch.commit(noResult: true);
      debugPrint('DEBUG: 批量插入完成，共插入 ${channels.length} 个频道');

      // Update playlist timestamp
      debugPrint('DEBUG: 更新播放列表时间戳...');
      await ServiceLocator.database.update(
        'playlists',
        {
          'last_updated': DateTime.now().millisecondsSinceEpoch,
          'channel_count': channels.length,
        },
        where: 'id = ?',
        whereArgs: [playlist.id],
      );

      _importProgress = 1.0;
      debugPrint('DEBUG: 刷新完成，进度: 100%');
      notifyListeners();

      // Reload playlists
      debugPrint('DEBUG: 重新加载播放列表数据...');
      await loadPlaylists();

      debugPrint('DEBUG: 播放列表刷新成功完成');
      return true;
    } catch (e) {
      debugPrint('DEBUG: 刷新播放列表时发生错误: $e');
      debugPrint('DEBUG: 错误堆栈: ${StackTrace.current}');
      _error = 'Failed to refresh playlist: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Delete a playlist
  Future<bool> deletePlaylist(int playlistId) async {
    try {
      // Find the playlist before deletion to check for temp files
      final playlist = _playlists.firstWhere((p) => p.id == playlistId,
          orElse: () => Playlist(name: ''));

      // Delete channels first (cascade should handle this, but being explicit)
      await ServiceLocator.database.delete(
        'channels',
        where: 'playlist_id = ?',
        whereArgs: [playlistId],
      );

      // Delete playlist
      await ServiceLocator.database.delete(
        'playlists',
        where: 'id = ?',
        whereArgs: [playlistId],
      );

      // Delete temporary file if this is a temporary playlist
      if (playlist.isTemporary && playlist.filePath != null) {
        try {
          final file = File(playlist.filePath!);
          if (await file.exists()) {
            await file.delete();
            debugPrint('DEBUG: 已删除临时播放列表文件: ${playlist.filePath}');
          }
        } catch (e) {
          debugPrint('DEBUG: 删除临时文件时出错: $e');
        }
      }

      // Update local state
      _playlists.removeWhere((p) => p.id == playlistId);

      if (_activePlaylist?.id == playlistId) {
        _activePlaylist = _playlists.isNotEmpty ? _playlists.first : null;
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete playlist: $e';
      notifyListeners();
      return false;
    }
  }

  // Set active playlist
  void setActivePlaylist(Playlist playlist,
      {Function(int)? onPlaylistChanged,
      FavoritesProvider? favoritesProvider}) async {
    debugPrint('DEBUG: 设置激活播放列表: ${playlist.name} (ID: ${playlist.id})');
    _activePlaylist = playlist;

    // Update database to mark this playlist as active
    if (playlist.id != null) {
      try {
        // Mark all playlists as inactive
        await ServiceLocator.database.update(
          'playlists',
          {'is_active': 0},
        );

        // Mark this playlist as active
        await ServiceLocator.database.update(
          'playlists',
          {'is_active': 1},
          where: 'id = ?',
          whereArgs: [playlist.id],
        );
      } catch (e) {
        debugPrint('DEBUG: 更新数据库激活状态时出错: $e');
      }
    }

    // Notify listeners immediately for UI update
    notifyListeners();

    // Trigger channel loading via callback
    if (playlist.id != null && onPlaylistChanged != null) {
      try {
        debugPrint('DEBUG: 触发播放列表频道加载回调...');
        onPlaylistChanged(playlist.id!);
      } catch (e) {
        debugPrint('DEBUG: 执行播放列表频道加载回调时出错: $e');
      }
    }

    // Update favorites provider with the new active playlist
    if (playlist.id != null && favoritesProvider != null) {
      try {
        debugPrint('DEBUG: 更新收藏夹提供者的激活播放列表ID...');
        favoritesProvider.setActivePlaylistId(playlist.id!);
        await favoritesProvider.loadFavorites();
      } catch (e) {
        debugPrint('DEBUG: 更新收藏夹时出错: $e');
      }
    }
  }

  // Update playlist
  Future<bool> updatePlaylist(Playlist playlist) async {
    if (playlist.id == null) return false;

    try {
      await ServiceLocator.database.update(
        'playlists',
        playlist.toMap(),
        where: 'id = ?',
        whereArgs: [playlist.id],
      );

      final index = _playlists.indexWhere((p) => p.id == playlist.id);
      if (index != -1) {
        _playlists[index] = playlist;
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update playlist: $e';
      notifyListeners();
      return false;
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
