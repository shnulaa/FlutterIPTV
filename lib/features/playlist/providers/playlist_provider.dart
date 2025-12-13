import 'package:flutter/foundation.dart';
import '../../../core/models/playlist.dart';
import '../../../core/models/channel.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/utils/m3u_parser.dart';

class PlaylistProvider extends ChangeNotifier {
  List<Playlist> _playlists = [];
  Playlist? _activePlaylist;
  bool _isLoading = false;
  String? _error;
  double _importProgress = 0.0;
  
  // Getters
  List<Playlist> get playlists => _playlists;
  Playlist? get activePlaylist => _activePlaylist;
  bool get isLoading => _isLoading;
  String? get error => _error;
  double get importProgress => _importProgress;
  
  bool get hasPlaylists => _playlists.isNotEmpty;
  
  // Load all playlists from database
  Future<void> loadPlaylists() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final results = await ServiceLocator.database.query(
        'playlists',
        orderBy: 'created_at DESC',
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
    
    try {
      // Create playlist record
      final playlistData = Playlist(
        name: name,
        url: url,
        createdAt: DateTime.now(),
      ).toMap();
      
      final playlistId = await ServiceLocator.database.insert('playlists', playlistData);
      
      _importProgress = 0.2;
      notifyListeners();
      
      // Parse M3U from URL
      final channels = await M3UParser.parseFromUrl(url, playlistId);
      
      _importProgress = 0.6;
      notifyListeners();
      
      // Insert channels
      for (int i = 0; i < channels.length; i++) {
        await ServiceLocator.database.insert('channels', channels[i].toMap());
        
        // Update progress
        if (i % 50 == 0) {
          _importProgress = 0.6 + (0.4 * i / channels.length);
          notifyListeners();
        }
      }
      
      // Update playlist with last updated timestamp
      await ServiceLocator.database.update(
        'playlists',
        {'last_updated': DateTime.now().millisecondsSinceEpoch},
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
      
      // Parse M3U from file
      final channels = await M3UParser.parseFromFile(filePath, playlistId);
      
      _importProgress = 0.6;
      notifyListeners();
      
      // Insert channels
      for (int i = 0; i < channels.length; i++) {
        await ServiceLocator.database.insert('channels', channels[i].toMap());
        
        if (i % 50 == 0) {
          _importProgress = 0.6 + (0.4 * i / channels.length);
          notifyListeners();
        }
      }
      
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
    
    _isLoading = true;
    _importProgress = 0.0;
    _error = null;
    notifyListeners();
    
    try {
      List<Channel> channels;
      
      if (playlist.isRemote) {
        channels = await M3UParser.parseFromUrl(playlist.url!, playlist.id!);
      } else if (playlist.isLocal) {
        channels = await M3UParser.parseFromFile(playlist.filePath!, playlist.id!);
      } else {
        throw Exception('Invalid playlist source');
      }
      
      _importProgress = 0.5;
      notifyListeners();
      
      // Delete existing channels
      await ServiceLocator.database.delete(
        'channels',
        where: 'playlist_id = ?',
        whereArgs: [playlist.id],
      );
      
      // Insert new channels
      for (int i = 0; i < channels.length; i++) {
        await ServiceLocator.database.insert('channels', channels[i].toMap());
        
        if (i % 50 == 0) {
          _importProgress = 0.5 + (0.5 * i / channels.length);
          notifyListeners();
        }
      }
      
      // Update playlist timestamp
      await ServiceLocator.database.update(
        'playlists',
        {'last_updated': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [playlist.id],
      );
      
      _importProgress = 1.0;
      notifyListeners();
      
      // Reload playlists
      await loadPlaylists();
      
      return true;
    } catch (e) {
      _error = 'Failed to refresh playlist: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  // Delete a playlist
  Future<bool> deletePlaylist(int playlistId) async {
    try {
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
  void setActivePlaylist(Playlist playlist) {
    _activePlaylist = playlist;
    notifyListeners();
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
