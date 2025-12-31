import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'platform_detector.dart';
import '../services/epg_service.dart';

/// Service to launch native Android player via MethodChannel
class NativePlayerChannel {
  static const _channel = MethodChannel('com.flutteriptv/native_player');
  static bool _initialized = false;
  static Function? _onPlayerClosedCallback;

  /// Initialize the channel
  static void init() {
    if (_initialized) return;
    _initialized = true;

    // Listen for player closed event from native
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPlayerClosed') {
        debugPrint('NativePlayerChannel: Player closed from native');
        _onPlayerClosedCallback?.call();
        _onPlayerClosedCallback = null;
      } else if (call.method == 'getEpgInfo') {
        // Native player requests EPG info for a channel
        final channelName = call.arguments['channelName'] as String?;
        final epgId = call.arguments['epgId'] as String?;
        return _getEpgInfo(epgId, channelName);
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

  /// Check if native player is available (Android TV only)
  static Future<bool> isAvailable() async {
    if (!PlatformDetector.isAndroid) return false;

    try {
      final result = await _channel.invokeMethod<bool>('isNativePlayerAvailable');
      return result ?? false;
    } catch (e) {
      debugPrint('NativePlayerChannel: isAvailable error: $e');
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
    bool isDlnaMode = false,
    String bufferStrength = 'fast',
    bool showFps = true,
    Function? onClosed,
  }) async {
    try {
      init(); // Ensure initialized
      _onPlayerClosedCallback = onClosed;

      debugPrint('NativePlayerChannel: launching player with url=$url, name=$name, index=$index, channels=${urls?.length ?? 0}, isDlna=$isDlnaMode, buffer=$bufferStrength, showFps=$showFps');
      final result = await _channel.invokeMethod<bool>('launchPlayer', {
        'url': url,
        'name': name,
        'index': index,
        'urls': urls,
        'names': names,
        'groups': groups,
        'sources': sources, // 传递每个频道的所有源
        'isDlnaMode': isDlnaMode,
        'bufferStrength': bufferStrength,
        'showFps': showFps,
      });
      debugPrint('NativePlayerChannel: launch result=$result');
      return result ?? false;
    } catch (e) {
      debugPrint('NativePlayerChannel: launchPlayer error: $e');
      _onPlayerClosedCallback = null;
      return false;
    }
  }

  /// Close the native player
  static Future<void> closePlayer() async {
    try {
      await _channel.invokeMethod('closePlayer');
    } catch (e) {
      debugPrint('NativePlayerChannel: closePlayer error: $e');
    }
  }
  
  /// Pause the native player (for DLNA control)
  static Future<void> pause() async {
    try {
      await _channel.invokeMethod('pause');
    } catch (e) {
      debugPrint('NativePlayerChannel: pause error: $e');
    }
  }
  
  /// Resume/play the native player (for DLNA control)
  static Future<void> play() async {
    try {
      await _channel.invokeMethod('play');
    } catch (e) {
      debugPrint('NativePlayerChannel: play error: $e');
    }
  }
  
  /// Seek to position in milliseconds (for DLNA control)
  static Future<void> seekTo(int positionMs) async {
    try {
      await _channel.invokeMethod('seekTo', {'position': positionMs});
    } catch (e) {
      debugPrint('NativePlayerChannel: seekTo error: $e');
    }
  }
  
  /// Set volume (0-100) (for DLNA control)
  static Future<void> setVolume(int volume) async {
    try {
      await _channel.invokeMethod('setVolume', {'volume': volume});
    } catch (e) {
      debugPrint('NativePlayerChannel: setVolume error: $e');
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
      debugPrint('NativePlayerChannel: getPlaybackState error: $e');
    }
    return null;
  }
}
