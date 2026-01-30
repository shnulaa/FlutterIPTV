import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import '../../../core/models/playlist.dart';
import '../../../core/models/channel.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/utils/m3u_parser.dart';
import '../../../core/utils/txt_parser.dart';
import '../../favorites/providers/favorites_provider.dart';

class PlaylistProvider extends ChangeNotifier {
  List<Playlist> _playlists = [];
  Playlist? _activePlaylist;
  bool _isLoading = false;
  String? _error;
  double _importProgress = 0.0;

  /// Last extracted EPG URL from M3U file (for UI display only)
  String? _lastExtractedEpgUrl;
  String? get lastExtractedEpgUrl => _lastExtractedEpgUrl;

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
    ServiceLocator.log.i('开始加载播放列表', tag: 'PlaylistProvider');
    final startTime = DateTime.now();
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await ServiceLocator.database.query(
        'playlists',
        orderBy: _sortBy,
      );

      _playlists = results.map((r) => Playlist.fromMap(r)).toList();
      ServiceLocator.log.d('从数据库加载了 ${_playlists.length} 个播放列表', tag: 'PlaylistProvider');

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
        ServiceLocator.log.d('设置活动播放列表: ${_activePlaylist?.name}', tag: 'PlaylistProvider');
      }

      final loadTime = DateTime.now().difference(startTime).inMilliseconds;
      ServiceLocator.log.i('播放列表加载完成，耗时: ${loadTime}ms', tag: 'PlaylistProvider');
      _error = null;
    } catch (e) {
      ServiceLocator.log.e('加载播放列表失败', tag: 'PlaylistProvider', error: e);
      _error = 'Failed to load playlists: $e';
      _playlists = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Detect playlist format from URL or content
  /// Returns 'txt' for TXT format, 'm3u' for M3U format
  String _detectPlaylistFormat(String source, {String? content}) {
    // Check by extension first
    final lowerSource = source.toLowerCase();
    if (lowerSource.endsWith('.txt')) {
      return 'txt';
    }
    if (lowerSource.endsWith('.m3u') || lowerSource.endsWith('.m3u8')) {
      return 'm3u';
    }

    // Check by content if available
    if (content != null) {
      final trimmed = content.trim();
      // TXT format typically starts with category or has ,#genre# pattern
      if (trimmed.contains(',#genre#')) {
        return 'txt';
      }
      // M3U format starts with #EXTM3U
      if (trimmed.startsWith('#EXTM3U') || trimmed.startsWith('#EXTINF')) {
        return 'm3u';
      }
    }

    // Default to M3U
    return 'm3u';
  }

  // Add a new playlist from URL
  Future<Playlist?> addPlaylistFromUrl(String name, String url) async {
    ServiceLocator.log.i('从URL添加播放列表: $name', tag: 'PlaylistProvider');
    ServiceLocator.log.d('URL: $url', tag: 'PlaylistProvider');
    final startTime = DateTime.now();
    
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

      playlistId = await ServiceLocator.database.insert('playlists', playlistData);

      _importProgress = 0.2;
      notifyListeners();

      // Detect format and parse accordingly
      final format = _detectPlaylistFormat(url);
      ServiceLocator.log.i('检测到播放列表格式: $format', tag: 'PlaylistProvider');

      final List<Channel> channels;
      if (format == 'txt') {
        channels = await TXTParser.parseFromUrl(url, playlistId);
      } else {
        channels = await M3UParser.parseFromUrl(url, playlistId);
      }

      // Check for EPG URL in M3U header (only for M3U format)
      if (format == 'm3u') {
        _lastExtractedEpgUrl = M3UParser.lastParseResult?.epgUrl;
        if (_lastExtractedEpgUrl != null) {
          ServiceLocator.log.d('从M3U提取到EPG URL: $_lastExtractedEpgUrl', tag: 'PlaylistProvider');
          // Save EPG URL to playlist
          await ServiceLocator.database.update(
            'playlists',
            {'epg_url': _lastExtractedEpgUrl},
            where: 'id = ?',
            whereArgs: [playlistId],
          );
        }
      }

      _importProgress = 0.6;
      notifyListeners();

      if (channels.isEmpty) {
        ServiceLocator.log.w('播放列表中没有找到频道', tag: 'PlaylistProvider');
        throw Exception('No channels found in playlist');
      }
      
      ServiceLocator.log.i('解析到 ${channels.length} 个频道', tag: 'PlaylistProvider');

      // Use batch for much faster insertion, split into chunks to avoid memory issues
      const chunkSize = 500; // Insert 500 channels at a time
      for (int i = 0; i < channels.length; i += chunkSize) {
        final end = (i + chunkSize < channels.length) ? i + chunkSize : channels.length;
        final chunk = channels.sublist(i, end);
        
        final batch = ServiceLocator.database.db.batch();
        for (final channel in chunk) {
          batch.insert('channels', channel.toMap());
        }
        await batch.commit(noResult: true);
        
        // Update progress
        _importProgress = 0.6 + (0.4 * (end / channels.length));
        notifyListeners();
        
        ServiceLocator.log.d('已插入 $end/${channels.length} 个频道', tag: 'PlaylistProvider');
      }

      // Update playlist with last updated timestamp and counts
      await ServiceLocator.database.update(
        'playlists',
        {
          'last_updated': DateTime.now().millisecondsSinceEpoch,
          'channel_count': channels.length, // Store locally to avoid immediate recounting
        },
        where: 'id = ?',
        whereArgs: [playlistId],
      );

      _importProgress = 1.0;
      notifyListeners();

      // Reload playlists
      await loadPlaylists();

      final totalTime = DateTime.now().difference(startTime).inMilliseconds;
      ServiceLocator.log.i('播放列表添加成功，总耗时: ${totalTime}ms', tag: 'PlaylistProvider');
      
      // 刷新日志缓冲区
      await ServiceLocator.log.flush();

      return _playlists.firstWhere((p) => p.id == playlistId);
    } catch (e) {
      ServiceLocator.log.e('添加播放列表失败', tag: 'PlaylistProvider', error: e);
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

      final playlistId = await ServiceLocator.database.insert('playlists', playlistData);

      _importProgress = 0.2;
      notifyListeners();

      // Detect format and parse accordingly
      final format = _detectPlaylistFormat('', content: content);
      ServiceLocator.log.d('DEBUG: 检测到播放列表格式: $format');

      final List<Channel> channels;
      if (format == 'txt') {
        channels = TXTParser.parse(content, playlistId);
      } else {
        channels = M3UParser.parse(content, playlistId);
      }

      // Check for EPG URL in M3U header (only for M3U format)
      if (format == 'm3u') {
        _lastExtractedEpgUrl = M3UParser.lastParseResult?.epgUrl;
        if (_lastExtractedEpgUrl != null) {
          ServiceLocator.log.d('DEBUG: 从M3U提取到EPG URL: $_lastExtractedEpgUrl');
          // Save EPG URL to playlist
          await ServiceLocator.database.update(
            'playlists',
            {'epg_url': _lastExtractedEpgUrl},
            where: 'id = ?',
            whereArgs: [playlistId],
          );
        }
      }

      _importProgress = 0.6;
      notifyListeners();

      if (channels.isEmpty) {
        throw Exception('No channels found in playlist');
      }

      // Use batch for much faster insertion, split into chunks to avoid memory issues
      const chunkSize = 500; // Insert 500 channels at a time
      for (int i = 0; i < channels.length; i += chunkSize) {
        final end = (i + chunkSize < channels.length) ? i + chunkSize : channels.length;
        final chunk = channels.sublist(i, end);
        
        final batch = ServiceLocator.database.db.batch();
        for (final channel in chunk) {
          batch.insert('channels', channel.toMap());
        }
        await batch.commit(noResult: true);
        
        // Update progress
        _importProgress = 0.6 + (0.4 * (end / channels.length));
        notifyListeners();
      }

      // Save the content as a temporary file for future refreshes
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempFile = await File('${tempDir.path}/playlist_${playlistId}_$timestamp.m3u').writeAsString(content);

      ServiceLocator.log.d('DEBUG: 保存临时播放列表文件: ${tempFile.path}');

      // Update playlist with last updated timestamp, counts and file path
      await ServiceLocator.database.update(
        'playlists',
        {
          'last_updated': DateTime.now().millisecondsSinceEpoch,
          'channel_count': channels.length,
          'file_path': tempFile.path, // Save temp file path for future refreshes
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
      ServiceLocator.log.d('DEBUG: 添加内容播放列表时出错: $e');
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

      final playlistId = await ServiceLocator.database.insert('playlists', playlistData);

      _importProgress = 0.2;
      notifyListeners();

      // Detect format and parse accordingly
      final format = _detectPlaylistFormat(filePath);
      ServiceLocator.log.d('DEBUG: 检测到播放列表格式: $format');

      final List<Channel> channels;
      if (format == 'txt') {
        channels = await TXTParser.parseFromFile(filePath, playlistId);
      } else {
        channels = await M3UParser.parseFromFile(filePath, playlistId);
      }

      // Check for EPG URL in M3U header (only for M3U format)
      if (format == 'm3u') {
        _lastExtractedEpgUrl = M3UParser.lastParseResult?.epgUrl;
        if (_lastExtractedEpgUrl != null) {
          ServiceLocator.log.d('DEBUG: 从M3U提取到EPG URL: $_lastExtractedEpgUrl');
        }
      }

      _importProgress = 0.6;
      notifyListeners();

      // Insert channels using batch for performance, split into chunks
      const chunkSize = 500; // Insert 500 channels at a time
      for (int i = 0; i < channels.length; i += chunkSize) {
        final end = (i + chunkSize < channels.length) ? i + chunkSize : channels.length;
        final chunk = channels.sublist(i, end);
        
        final batch = ServiceLocator.database.db.batch();
        for (final channel in chunk) {
          batch.insert('channels', channel.toMap());
        }
        await batch.commit(noResult: true);
        
        // Update progress
        _importProgress = 0.6 + (0.4 * (end / channels.length));
        notifyListeners();
      }

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

    ServiceLocator.log.d('DEBUG: 开始刷新播放列表: ${playlist.name} (ID: ${playlist.id})');
    ServiceLocator.log.d('DEBUG: playlist.url = ${playlist.url}');
    ServiceLocator.log.d('DEBUG: playlist.filePath = ${playlist.filePath}');
    ServiceLocator.log.d('DEBUG: playlist.isRemote = ${playlist.isRemote}');
    ServiceLocator.log.d('DEBUG: playlist.isLocal = ${playlist.isLocal}');

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
      ServiceLocator.log.d('DEBUG: 从数据库重新加载 - URL: ${freshPlaylist.url}, FilePath: ${freshPlaylist.filePath}');

      List<Channel> channels;

      ServiceLocator.log.d('DEBUG: 播放列表源类型: ${freshPlaylist.isRemote ? "远程URL" : freshPlaylist.isLocal ? "本地文件" : "未知"}');
      ServiceLocator.log.d('DEBUG: 播放列表源路径: ${freshPlaylist.sourcePath}');

      if (freshPlaylist.isRemote) {
        ServiceLocator.log.d('DEBUG: 开始从URL解析播放列表: ${freshPlaylist.url}');
        
        // Detect format and parse accordingly
        final format = _detectPlaylistFormat(freshPlaylist.url!);
        ServiceLocator.log.d('DEBUG: 检测到播放列表格式: $format');
        
        if (format == 'txt') {
          channels = await TXTParser.parseFromUrl(freshPlaylist.url!, playlist.id!);
        } else {
          channels = await M3UParser.parseFromUrl(freshPlaylist.url!, playlist.id!);
        }
        
        // Check for EPG URL in M3U header (only for M3U format)
        if (format == 'm3u') {
          _lastExtractedEpgUrl = M3UParser.lastParseResult?.epgUrl;
          if (_lastExtractedEpgUrl != null) {
            ServiceLocator.log.d('DEBUG: 从M3U提取到EPG URL: $_lastExtractedEpgUrl');
          }
        }
      } else if (freshPlaylist.isLocal) {
        ServiceLocator.log.d('DEBUG: 开始从本地文件解析播放列表: ${freshPlaylist.filePath}');

        // Check if file exists before trying to parse
        final file = File(freshPlaylist.filePath!);
        if (!await file.exists()) {
          ServiceLocator.log.d('DEBUG: 本地文件不存在: ${freshPlaylist.filePath}');
          throw Exception('Local playlist file not found: ${freshPlaylist.filePath}');
        }

        // Detect format and parse accordingly
        final format = _detectPlaylistFormat(freshPlaylist.filePath!);
        ServiceLocator.log.d('DEBUG: 检测到播放列表格式: $format');
        
        if (format == 'txt') {
          channels = await TXTParser.parseFromFile(freshPlaylist.filePath!, playlist.id!);
        } else {
          channels = await M3UParser.parseFromFile(freshPlaylist.filePath!, playlist.id!);
        }
        
        // Check for EPG URL in M3U header (only for M3U format)
        if (format == 'm3u') {
          _lastExtractedEpgUrl = M3UParser.lastParseResult?.epgUrl;
          if (_lastExtractedEpgUrl != null) {
            ServiceLocator.log.d('DEBUG: 从M3U提取到EPG URL: $_lastExtractedEpgUrl');
          }
        }
      } else {
        // Check if this is a content-imported playlist without a proper file path
        ServiceLocator.log.d('DEBUG: 播放列表源无效，URL: ${freshPlaylist.url}, 文件路径: ${freshPlaylist.filePath}');
        throw Exception('Invalid playlist source - URL: ${freshPlaylist.url}, File: ${freshPlaylist.filePath}');
      }

      ServiceLocator.log.d('DEBUG: 解析完成，共找到 ${channels.length} 个频道');

      _importProgress = 0.5;
      notifyListeners();

      // 使用事务确保数据一致性：先删除旧数据，再插入新数据
      // 如果插入失败，事务会回滚，旧数据不会丢失
      await ServiceLocator.database.db.transaction((txn) async {
        // Delete existing channels
        ServiceLocator.log.d('DEBUG: 开始删除现有频道数据...');
        final deleteResult = await txn.delete(
          'channels',
          where: 'playlist_id = ?',
          whereArgs: [playlist.id],
        );
        ServiceLocator.log.d('DEBUG: 已删除 $deleteResult 个旧频道记录');

        // Insert new channels - 使用批量插入以提高性能，分块处理避免内存问题
        const chunkSize = 500;
        for (int i = 0; i < channels.length; i += chunkSize) {
          final end = (i + chunkSize < channels.length) ? i + chunkSize : channels.length;
          final chunk = channels.sublist(i, end);
          
          final batch = txn.batch();
          for (final channel in chunk) {
            final channelMap = channel.toMap();
            batch.insert('channels', channelMap);
          }
          await batch.commit(noResult: true);
          ServiceLocator.log.d('DEBUG: 已插入 $end/${channels.length} 个新频道记录');
        }
      });

      // Update playlist timestamp and EPG URL
      ServiceLocator.log.d('DEBUG: 更新播放列表时间戳和EPG URL...');
      final updateData = <String, dynamic>{
        'last_updated': DateTime.now().millisecondsSinceEpoch,
        'channel_count': channels.length,
      };
      
      // 如果提取到了 EPG URL，也更新到数据库
      if (_lastExtractedEpgUrl != null) {
        updateData['epg_url'] = _lastExtractedEpgUrl;
        ServiceLocator.log.d('DEBUG: 保存EPG URL到数据库: $_lastExtractedEpgUrl');
      }
      
      await ServiceLocator.database.update(
        'playlists',
        updateData,
        where: 'id = ?',
        whereArgs: [playlist.id],
      );

      _importProgress = 1.0;
      ServiceLocator.log.d('DEBUG: 刷新完成，进度: 100%');
      notifyListeners();

      // 清除重定向缓存（因为播放列表已更新，URL可能已变化）
      ServiceLocator.redirectCache.clearAllCache();
      ServiceLocator.log.d('已清除重定向缓存（刷新播放列表）');

      // Reload playlists
      ServiceLocator.log.d('DEBUG: 重新加载播放列表数据...');
      await loadPlaylists();

      ServiceLocator.log.d('DEBUG: 播放列表刷新成功完成');
      return true;
    } catch (e) {
      ServiceLocator.log.d('DEBUG: 刷新播放列表时发生错误: $e');
      ServiceLocator.log.d('DEBUG: 错误堆栈: ${StackTrace.current}');
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
      final playlist = _playlists.firstWhere((p) => p.id == playlistId, orElse: () => Playlist(name: ''));
      final wasActive = _activePlaylist?.id == playlistId;

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
            ServiceLocator.log.d('DEBUG: 已删除临时播放列表文件: ${playlist.filePath}');
          }
        } catch (e) {
          ServiceLocator.log.d('DEBUG: 删除临时文件时出错: $e');
        }
      }

      // 清除重定向缓存（因为播放列表的URL可能已失效）
      ServiceLocator.redirectCache.clearAllCache();
      ServiceLocator.log.d('已清除重定向缓存（删除播放列表）');

      // Update local state
      _playlists.removeWhere((p) => p.id == playlistId);

      // If the deleted playlist was active, switch to the first available playlist
      if (wasActive) {
        if (_playlists.isNotEmpty) {
          _activePlaylist = _playlists.first;
          // Save the new active playlist to database
          await ServiceLocator.prefs.setInt('active_playlist_id', _activePlaylist!.id!);
          ServiceLocator.log.d('DEBUG: 删除后切换到播放列表: ${_activePlaylist!.name} (ID: ${_activePlaylist!.id})');
        } else {
          _activePlaylist = null;
          await ServiceLocator.prefs.remove('active_playlist_id');
          ServiceLocator.log.d('DEBUG: 没有剩余播放列表');
        }
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
  void setActivePlaylist(Playlist playlist, {Function(int)? onPlaylistChanged, FavoritesProvider? favoritesProvider}) async {
    ServiceLocator.log.d('DEBUG: 设置激活播放列表: ${playlist.name} (ID: ${playlist.id})');
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
        ServiceLocator.log.d('DEBUG: 更新数据库激活状态时出错: $e');
      }
    }

    // Notify listeners immediately for UI update
    notifyListeners();

    // Trigger channel loading via callback
    if (playlist.id != null && onPlaylistChanged != null) {
      try {
        ServiceLocator.log.d('DEBUG: 触发播放列表频道加载回调...');
        onPlaylistChanged(playlist.id!);
      } catch (e) {
        ServiceLocator.log.d('DEBUG: 执行播放列表频道加载回调时出错: $e');
      }
    }

    // Update favorites provider with the new active playlist
    if (playlist.id != null && favoritesProvider != null) {
      try {
        ServiceLocator.log.d('DEBUG: 更新收藏夹提供者的激活播放列表ID...');
        favoritesProvider.setActivePlaylistId(playlist.id!);
        await favoritesProvider.loadFavorites();
      } catch (e) {
        ServiceLocator.log.d('DEBUG: 更新收藏夹时出错: $e');
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
