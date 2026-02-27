import 'package:flutter/services.dart';
import 'platform_detector.dart';
import '../services/epg_service.dart';
import '../../features/favorites/providers/favorites_provider.dart';
import '../../features/channels/providers/channel_provider.dart';
import '../../features/settings/providers/settings_provider.dart';
import '../services/service_locator.dart';

/// Service to launch native Android player via MethodChannel
class NativePlayerChannel {
  static const _channel = MethodChannel('com.flutteriptv/native_player');
  static bool _initialized = false;
  static Function? _onPlayerClosedCallback;
  static Function? _onMultiScreenClosedCallback;
  static FavoritesProvider? _favoritesProvider;
  static ChannelProvider? _channelProvider;
  static SettingsProvider? _settingsProvider;

  /// Set providers for favorite functionality
  static void setProviders(
      FavoritesProvider favoritesProvider, ChannelProvider channelProvider,
      [SettingsProvider? settingsProvider]) {
    _favoritesProvider = favoritesProvider;
    _channelProvider = channelProvider;
    _settingsProvider = settingsProvider;
  }

  /// Initialize the channel
  static void init() {
    if (_initialized) return;
    _initialized = true;

    // Listen for player closed event from native
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPlayerClosed') {
        ServiceLocator.log.d('NativePlayerChannel: Player closed from native');
        // 保存单频道播放状态
        _saveSingleChannelState(call.arguments);
        _onPlayerClosedCallback?.call();
        _onPlayerClosedCallback = null;
      } else if (call.method == 'onMultiScreenClosed') {
        ServiceLocator.log.d('NativePlayerChannel: Multi-screen closed from native');
        // 保存分屏状态
        _saveMultiScreenState(call.arguments);
        _onMultiScreenClosedCallback?.call();
        _onMultiScreenClosedCallback = null;
      } else if (call.method == 'getEpgInfo') {
        // Native player requests EPG info for a channel
        final channelName = call.arguments['channelName'] as String?;
        final epgId = call.arguments['epgId'] as String?;
        return _getEpgInfo(epgId, channelName);
      } else if (call.method == 'toggleFavorite') {
        // Native player requests to toggle favorite
        final channelIndex = call.arguments['channelIndex'] as int?;
        return _toggleFavorite(channelIndex);
      } else if (call.method == 'isFavorite') {
        // Native player requests to check if channel is favorite
        final channelIndex = call.arguments['channelIndex'] as int?;
        return _isFavorite(channelIndex);
      } else if (call.method == 'addWatchHistory') {
        // Native player requests to add watch history
        final channelIndex = call.arguments['channelIndex'] as int?;
        return _addWatchHistory(channelIndex);
      }
    });
  }

  static Map<String, dynamic>? _getEpgInfo(String? epgId, String? channelName) {
    final epgService = EpgService();
    final currentProgram = epgService.getCurrentProgram(epgId, channelName);
    final nextProgram = epgService.getNextProgram(epgId, channelName);

    if (currentProgram == null && nextProgram == null) return null;

    return {
      'currentTitle': currentProgram?.title,
      'currentRemaining': currentProgram?.remainingMinutes,
      'nextTitle': nextProgram?.title,
    };
  }

  static Future<bool?> _toggleFavorite(int? channelIndex) async {
    if (channelIndex == null ||
        _favoritesProvider == null ||
        _channelProvider == null) {
      ServiceLocator.log.d(
          'NativePlayerChannel: toggleFavorite - invalid params: index=$channelIndex, favProv=${_favoritesProvider != null}, chanProv=${_channelProvider != null}');
      return null;
    }

    final channels = _channelProvider!.channels;
    if (channelIndex < 0 || channelIndex >= channels.length) {
      ServiceLocator.log.d(
          'NativePlayerChannel: toggleFavorite - invalid index: $channelIndex, channels=${channels.length}');
      return null;
    }

    final channel = channels[channelIndex];
    ServiceLocator.log.d(
        'NativePlayerChannel: toggleFavorite - channel: ${channel.name}, id: ${channel.id}');

    if (channel.id == null) {
      ServiceLocator.log.d('NativePlayerChannel: toggleFavorite - channel has no id');
      return null;
    }

    // Check current favorite status before toggle
    final wasFavorite = _favoritesProvider!.isFavorite(channel.id!);
    ServiceLocator.log.d(
        'NativePlayerChannel: toggleFavorite - wasFavorite: $wasFavorite');

    // Toggle favorite
    final success = await _favoritesProvider!.toggleFavorite(channel);
    ServiceLocator.log.d('NativePlayerChannel: toggleFavorite - success: $success');

    if (!success) {
      return null;
    }

    // Return the new favorite status (opposite of what it was)
    final isFavoriteNow = !wasFavorite;
    ServiceLocator.log.d(
        'NativePlayerChannel: toggleFavorite - isFavoriteNow: $isFavoriteNow');
    return isFavoriteNow;
  }

  static bool _isFavorite(int? channelIndex) {
    if (channelIndex == null ||
        _favoritesProvider == null ||
        _channelProvider == null) {
      ServiceLocator.log.d(
          'NativePlayerChannel: isFavorite - invalid params: index=$channelIndex, favProv=${_favoritesProvider != null}, chanProv=${_channelProvider != null}');
      return false;
    }

    final channels = _channelProvider!.channels;
    if (channelIndex < 0 || channelIndex >= channels.length) {
      ServiceLocator.log.d(
          'NativePlayerChannel: isFavorite - invalid index: $channelIndex, channels=${channels.length}');
      return false;
    }

    final channel = channels[channelIndex];
    if (channel.id == null) {
      ServiceLocator.log.d('NativePlayerChannel: isFavorite - channel has no id');
      return false;
    }

    final isFav = _favoritesProvider!.isFavorite(channel.id!);
    ServiceLocator.log.d(
        'NativePlayerChannel: isFavorite - channel: ${channel.name}, isFavorite: $isFav');
    return isFav;
  }

  /// Add watch history for a channel (called from native player)
  static Future<bool> _addWatchHistory(int? channelIndex) async {
    if (channelIndex == null || _channelProvider == null) {
      ServiceLocator.log.d(
          'NativePlayerChannel: addWatchHistory - invalid params: index=$channelIndex, chanProv=${_channelProvider != null}');
      return false;
    }

    final channels = _channelProvider!.channels;
    if (channelIndex < 0 || channelIndex >= channels.length) {
      ServiceLocator.log.d(
          'NativePlayerChannel: addWatchHistory - invalid index: $channelIndex, channels=${channels.length}');
      return false;
    }

    final channel = channels[channelIndex];
    if (channel.id == null || channel.playlistId == null) {
      ServiceLocator.log.d(
          'NativePlayerChannel: addWatchHistory - channel has no id or playlistId: ${channel.name}');
      return false;
    }

    try {
      await ServiceLocator.watchHistory.addWatchHistory(channel.id!, channel.playlistId!);
      ServiceLocator.log.d(
          'NativePlayerChannel: addWatchHistory - success for channel: ${channel.name}');
      return true;
    } catch (e) {
      ServiceLocator.log.e(
          'NativePlayerChannel: addWatchHistory - error: $e');
      return false;
    }
  }

  /// 保存分屏状态
  static void _saveMultiScreenState(dynamic arguments) {
    if (_settingsProvider == null || _channelProvider == null) {
      ServiceLocator.log.d(
          'NativePlayerChannel: _saveMultiScreenState - providers not set');
      return;
    }

    if (arguments == null) {
      ServiceLocator.log.d('NativePlayerChannel: _saveMultiScreenState - no arguments');
      return;
    }

    try {
      final Map<dynamic, dynamic> args = arguments as Map<dynamic, dynamic>;
      final List<dynamic>? screenStates =
          args['screenStates'] as List<dynamic>?;
      final int activeIndex = args['activeIndex'] as int? ?? 0;

      if (screenStates == null) {
        ServiceLocator.log.d(
            'NativePlayerChannel: _saveMultiScreenState - no screenStates');
        return;
      }

      // 将频道索引转换为频道ID
      final channels = _channelProvider!.channels;
      final List<int?> channelIds = [];

      for (final state in screenStates) {
        if (state == null) {
          channelIds.add(null);
        } else {
          final channelIndex = state as int;
          if (channelIndex >= 0 && channelIndex < channels.length) {
            channelIds.add(channels[channelIndex].id);
          } else {
            channelIds.add(null);
          }
        }
      }

      ServiceLocator.log.d(
          'NativePlayerChannel: _saveMultiScreenState - channelIds: $channelIds, activeIndex: $activeIndex');

      // 保存分屏状态
      _settingsProvider!.saveLastMultiScreen(channelIds, activeIndex);
    } catch (e) {
      ServiceLocator.log.d('NativePlayerChannel: _saveMultiScreenState error: $e');
    }
  }

  /// 保存单频道播放状态
  static void _saveSingleChannelState(dynamic arguments) {
    if (_settingsProvider == null || _channelProvider == null) {
      ServiceLocator.log.d(
          'NativePlayerChannel: _saveSingleChannelState - providers not set');
      return;
    }

    try {
      int? channelIndex;
      bool skipSave = false;

      if (arguments != null && arguments is Map) {
        channelIndex = arguments['channelIndex'] as int?;
        skipSave = arguments['skipSave'] as bool? ?? false;
      }

      // 如果是从分屏退出到单频道播放的，不覆盖分屏状态
      if (skipSave) {
        ServiceLocator.log.d(
            'NativePlayerChannel: _saveSingleChannelState - skipSave=true, keeping multi-screen state');
        return;
      }

      if (channelIndex == null || channelIndex < 0) {
        ServiceLocator.log.d(
            'NativePlayerChannel: _saveSingleChannelState - no valid channelIndex');
        return;
      }

      final channels = _channelProvider!.channels;
      if (channelIndex >= channels.length) {
        ServiceLocator.log.d(
            'NativePlayerChannel: _saveSingleChannelState - channelIndex out of range');
        return;
      }

      final channelId = channels[channelIndex].id;
      ServiceLocator.log.d(
          'NativePlayerChannel: _saveSingleChannelState - channelIndex: $channelIndex, channelId: $channelId');

      if (channelId != null) {
        // 保存单频道播放状态
        _settingsProvider!.saveLastSingleChannel(channelId);
      }
    } catch (e) {
      ServiceLocator.log.d('NativePlayerChannel: _saveSingleChannelState error: $e');
    }
  }

  /// Check if native player is available (Android TV only)
  static Future<bool> isAvailable() async {
    if (!PlatformDetector.isAndroid) return false;

    try {
      final result =
          await _channel.invokeMethod<bool>('isNativePlayerAvailable');
      return result ?? false;
    } catch (e) {
      ServiceLocator.log.d('NativePlayerChannel: isAvailable error: $e');
      return false;
    }
  }

  /// Launch native player with given URL, channel name, and optional channel list for switching
  /// Returns true if launched successfully
  static Future<bool> launchPlayer({
    required String url,
    String name = '',
    int index = 0,
    List<String>? urls,
    List<String>? names,
    List<String>? groups,
    List<List<String>>? sources, // 每个频道的所有源
    List<String>? logos, // 每个频道的台标URL
    List<String>? epgIds, // 每个频道的EPG ID
    List<bool>? isSeekable, // 每个频道是否可拖动（点播/回放）
    bool isDlnaMode = false,
    String bufferStrength = 'fast',
    bool showFps = true,
    bool showClock = true,
    bool showNetworkSpeed = true,
    bool showVideoInfo = true,
    String progressBarMode = 'auto', // 进度条显示模式：auto, always, never
    int seekStepSeconds = 10, // 快进/快退跨度（秒）
    bool showChannelName = false, // 多屏播放是否显示频道名称
    Function? onClosed,
  }) async {
    try {
      init(); // Ensure initialized
      _onPlayerClosedCallback = onClosed;

      ServiceLocator.log.d(
          'NativePlayerChannel: launching player with url=$url, name=$name, index=$index, channels=${urls?.length ?? 0}, isDlna=$isDlnaMode, buffer=$bufferStrength, progressBarMode=$progressBarMode, seekStepSeconds=$seekStepSeconds, showChannelName=$showChannelName');
      final result = await _channel.invokeMethod<bool>('launchPlayer', {
        'url': url,
        'name': name,
        'index': index,
        'urls': urls,
        'names': names,
        'groups': groups,
        'sources': sources, // 传递每个频道的所有源
        'logos': logos, // 传递每个频道的台标URL
        'epgIds': epgIds, // 传递每个频道的EPG ID
        'isSeekable': isSeekable, // 传递每个频道是否可拖动
        'isDlnaMode': isDlnaMode,
        'bufferStrength': bufferStrength,
        'showFps': showFps,
        'showClock': showClock,
        'showNetworkSpeed': showNetworkSpeed,
        'showVideoInfo': showVideoInfo,
        'progressBarMode': progressBarMode, // 传递进度条显示模式
        'seekStepSeconds': seekStepSeconds, // 传递快进/快退跨度
        'showChannelName': showChannelName, // 传递多屏频道名称显示设置
      });
      ServiceLocator.log.d('NativePlayerChannel: launch result=$result');
      return result ?? false;
    } catch (e) {
      ServiceLocator.log.d('NativePlayerChannel: launchPlayer error: $e');
      _onPlayerClosedCallback = null;
      return false;
    }
  }

  /// Close the native player
  static Future<void> closePlayer() async {
    try {
      await _channel.invokeMethod('closePlayer');
    } catch (e) {
      ServiceLocator.log.d('NativePlayerChannel: closePlayer error: $e');
    }
  }

  /// Pause the native player (for DLNA control)
  static Future<void> pause() async {
    try {
      await _channel.invokeMethod('pause');
    } catch (e) {
      ServiceLocator.log.d('NativePlayerChannel: pause error: $e');
    }
  }

  /// Resume/play the native player (for DLNA control)
  static Future<void> play() async {
    try {
      await _channel.invokeMethod('play');
    } catch (e) {
      ServiceLocator.log.d('NativePlayerChannel: play error: $e');
    }
  }

  /// Seek to position in milliseconds (for DLNA control)
  static Future<void> seekTo(int positionMs) async {
    try {
      await _channel.invokeMethod('seekTo', {'position': positionMs});
    } catch (e) {
      ServiceLocator.log.d('NativePlayerChannel: seekTo error: $e');
    }
  }

  /// Set volume (0-100) (for DLNA control)
  static Future<void> setVolume(int volume) async {
    try {
      await _channel.invokeMethod('setVolume', {'volume': volume});
    } catch (e) {
      ServiceLocator.log.d('NativePlayerChannel: setVolume error: $e');
    }
  }

  /// Get current playback state from native player
  static Future<Map<String, dynamic>?> getPlaybackState() async {
    try {
      final result = await _channel.invokeMethod<Map>('getPlaybackState');
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
    } catch (e) {
      ServiceLocator.log.d('NativePlayerChannel: getPlaybackState error: $e');
    }
    return null;
  }

  /// Launch native multi-screen player (TV only)
  /// Returns true if launched successfully
  static Future<bool> launchMultiScreen({
    required List<String> urls,
    required List<String> names,
    required List<String> groups,
    List<List<String>>? sources,
    List<String>? logos,
    int initialChannelIndex = 0,
    int volumeBoostDb = 0,
    int defaultScreenPosition = 1, // 1-4 对应四个屏幕位置
    int restoreActiveIndex = -1, // 恢复时的活动屏幕索引
    List<int?>? restoreScreenChannels, // 恢复时每个屏幕的频道索引
    bool showChannelName = false, // 是否显示频道名称
    Function? onClosed,
  }) async {
    try {
      init(); // Ensure initialized
      _onMultiScreenClosedCallback = onClosed;

      ServiceLocator.log.d(
          'NativePlayerChannel: launching multi-screen with ${urls.length} channels, initial=$initialChannelIndex, volumeBoost=$volumeBoostDb, defaultScreen=$defaultScreenPosition, restoreActive=$restoreActiveIndex, restoreChannels=$restoreScreenChannels, showChannelName=$showChannelName');
      final result = await _channel.invokeMethod<bool>('launchMultiScreen', {
        'urls': urls,
        'names': names,
        'groups': groups,
        'sources': sources,
        'logos': logos,
        'initialChannelIndex': initialChannelIndex,
        'volumeBoostDb': volumeBoostDb,
        'defaultScreenPosition': defaultScreenPosition,
        'restoreActiveIndex': restoreActiveIndex,
        'restoreScreenChannels': restoreScreenChannels,
        'showChannelName': showChannelName,
      });
      ServiceLocator.log.d('NativePlayerChannel: multi-screen launch result=$result');
      return result ?? false;
    } catch (e) {
      ServiceLocator.log.d('NativePlayerChannel: launchMultiScreen error: $e');
      _onMultiScreenClosedCallback = null;
      return false;
    }
  }

  /// Close the native multi-screen player
  static Future<void> closeMultiScreen() async {
    try {
      await _channel.invokeMethod('closeMultiScreen');
    } catch (e) {
      ServiceLocator.log.d('NativePlayerChannel: closeMultiScreen error: $e');
    }
  }
}
