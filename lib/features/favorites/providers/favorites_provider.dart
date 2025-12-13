import 'package:flutter/foundation.dart';
import '../../../core/models/channel.dart';
import '../../../core/services/service_locator.dart';

class FavoritesProvider extends ChangeNotifier {
  List<Channel> _favorites = [];
  bool _isLoading = false;
  String? _error;
  
  // Getters
  List<Channel> get favorites => _favorites;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  int get count => _favorites.length;
  
  // Load favorites from database
  Future<void> loadFavorites() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final results = await ServiceLocator.database.rawQuery('''
        SELECT c.* FROM channels c
        INNER JOIN favorites f ON c.id = f.channel_id
        WHERE c.is_active = 1
        ORDER BY f.position ASC, f.created_at DESC
      ''');
      
      _favorites = results.map((r) {
        final channel = Channel.fromMap(r);
        return channel.copyWith(isFavorite: true);
      }).toList();
      
      _error = null;
    } catch (e) {
      _error = 'Failed to load favorites: $e';
      _favorites = [];
    }
    
    _isLoading = false;
    notifyListeners();
  }
  
  // Check if a channel is favorited
  bool isFavorite(int channelId) {
    return _favorites.any((c) => c.id == channelId);
  }
  
  // Add a channel to favorites
  Future<bool> addFavorite(Channel channel) async {
    if (channel.id == null) return false;
    
    try {
      // Get the next position
      final positionResult = await ServiceLocator.database.rawQuery(
        'SELECT MAX(position) as max_pos FROM favorites',
      );
      final nextPosition = (positionResult.first['max_pos'] as int? ?? 0) + 1;
      
      // Insert favorite
      await ServiceLocator.database.insert('favorites', {
        'channel_id': channel.id,
        'position': nextPosition,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
      
      // Update local list
      _favorites.add(channel.copyWith(isFavorite: true));
      notifyListeners();
      
      return true;
    } catch (e) {
      _error = 'Failed to add favorite: $e';
      notifyListeners();
      return false;
    }
  }
  
  // Remove a channel from favorites
  Future<bool> removeFavorite(int channelId) async {
    try {
      await ServiceLocator.database.delete(
        'favorites',
        where: 'channel_id = ?',
        whereArgs: [channelId],
      );
      
      _favorites.removeWhere((c) => c.id == channelId);
      notifyListeners();
      
      return true;
    } catch (e) {
      _error = 'Failed to remove favorite: $e';
      notifyListeners();
      return false;
    }
  }
  
  // Toggle favorite status
  Future<bool> toggleFavorite(Channel channel) async {
    if (channel.id == null) return false;
    
    if (isFavorite(channel.id!)) {
      return removeFavorite(channel.id!);
    } else {
      return addFavorite(channel);
    }
  }
  
  // Reorder favorites
  Future<void> reorderFavorites(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    
    final channel = _favorites.removeAt(oldIndex);
    _favorites.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, channel);
    
    // Update positions in database
    try {
      for (int i = 0; i < _favorites.length; i++) {
        await ServiceLocator.database.update(
          'favorites',
          {'position': i},
          where: 'channel_id = ?',
          whereArgs: [_favorites[i].id],
        );
      }
    } catch (e) {
      _error = 'Failed to reorder favorites: $e';
    }
    
    notifyListeners();
  }
  
  // Clear all favorites
  Future<void> clearFavorites() async {
    try {
      await ServiceLocator.database.delete('favorites');
      _favorites.clear();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to clear favorites: $e';
      notifyListeners();
    }
  }
}
