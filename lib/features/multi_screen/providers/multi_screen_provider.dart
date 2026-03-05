import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'dart:math' as math;

import '../../../core/models/channel.dart';
import '../../../core/services/service_locator.dart';
import '../../settings/providers/settings_provider.dart';

/// 单个屏幕的播放器状态
class ScreenPlayerState {
  Player? player;
  VideoController? videoController;
  Channel? channel;
  bool isPlaying = false;
  bool isLoading = false;
  String? error;
  bool isSoftwareDecoding = false;
  bool softwareFallbackAttempted = false;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  
  // 视频信息
  int videoWidth = 0;
  int videoHeight = 0;
  int bitrate = 0;
  double fps = 0;
  double networkSpeed = 0;
  
  ScreenPlayerState();
  
  Future<void> dispose() async {
    // 先停止播放，再释放资源
    if (player != null) {
      await player!.stop();
      await player!.dispose();
    }
    player = null;
    videoController = null;
    channel = null;
    isPlaying = false;
  }
}

class MultiScreenProvider extends ChangeNotifier {
  // 4个屏幕的播放器状态
  final List<ScreenPlayerState> _screens = List.generate(4, (_) => ScreenPlayerState());
  int _activeScreenIndex = 0;
  bool _isMultiScreenMode = false;
  String _videoOutput = 'auto';
  String _windowsHwdecMode = 'auto-safe';
  bool _allowSoftwareFallback = true;
  String _decodingMode = 'auto';
  String _bufferStrength = 'fast';
  
  // 音量设置
  double _volume = 1.0;
  int _volumeBoostDb = 0;

  List<ScreenPlayerState> get screens => _screens;
  int get activeScreenIndex => _activeScreenIndex;
  bool get isMultiScreenMode => _isMultiScreenMode;
  double get volume => _volume;
  ScreenPlayerState get activeScreen => _screens[_activeScreenIndex];

  // 获取指定屏幕的状态
  ScreenPlayerState getScreen(int index) {
    if (index >= 0 && index < 4) {
      return _screens[index];
    }
    return _screens[0];
  }
  
  // 设置音量和音量增强
  void setVolumeSettings(double volume, int volumeBoostDb) {
    _volume = volume;
    _volumeBoostDb = volumeBoostDb;
    _applyVolumeToActiveScreen();
  }

  void updatePlaybackConfig({
    required String videoOutput,
    required String windowsHwdecMode,
    required bool allowSoftwareFallback,
    required String decodingMode,
    required String bufferStrength,
  }) {
    _videoOutput = videoOutput;
    _windowsHwdecMode = windowsHwdecMode;
    _allowSoftwareFallback = allowSoftwareFallback;
    _decodingMode = decodingMode;
    _bufferStrength = bufferStrength;
  }

  Future<void> reinitializePlayers({
    required String videoOutput,
    required String windowsHwdecMode,
    required bool allowSoftwareFallback,
    required String decodingMode,
    required String bufferStrength,
  }) async {
    updatePlaybackConfig(
      videoOutput: videoOutput,
      windowsHwdecMode: windowsHwdecMode,
      allowSoftwareFallback: allowSoftwareFallback,
      decodingMode: decodingMode,
      bufferStrength: bufferStrength,
    );

    final channels = List<Channel?>.from(_screens.map((s) => s.channel));
    for (int i = 0; i < _screens.length; i++) {
      await _disposeScreenPlayer(i);
    }
    for (int i = 0; i < channels.length; i++) {
      if (channels[i] != null) {
        await playChannelOnScreen(i, channels[i]!, skipHistory: true);
      }
    }
  }
  
  // 计算有效音量（包含增强）
  double _getEffectiveVolume() {
    if (_volumeBoostDb == 0) {
      return _volume * 100;
    }
    // 将 dB 转换为线性增益
    final boostFactor = math.pow(10, _volumeBoostDb / 20);
    return (_volume * boostFactor * 100).clamp(0, 200);
  }
  
  // 应用音量到活动屏幕
  void _applyVolumeToActiveScreen() {
    final screen = _screens[_activeScreenIndex];
    if (screen.player != null) {
      screen.player!.setVolume(_getEffectiveVolume());
    }
  }

  // 设置活动屏幕
  void setActiveScreen(int index) {
    if (index >= 0 && index < 4 && _activeScreenIndex != index) {
      // 静音之前的活动屏幕
      final oldScreen = _screens[_activeScreenIndex];
      if (oldScreen.player != null) {
        oldScreen.player!.setVolume(0);
      }
      
      _activeScreenIndex = index;
      
      // 取消静音新的活动屏幕（使用有效音量，包含音量增强）
      final newScreen = _screens[_activeScreenIndex];
      if (newScreen.player != null) {
        newScreen.player!.setVolume(_getEffectiveVolume());
      }
      
      ServiceLocator.log.d('MultiScreenProvider: Active screen changed to $index');
      notifyListeners();
    }
  }

  // 启用/禁用分屏模式
  void setMultiScreenMode(bool enabled) {
    _isMultiScreenMode = enabled;
    if (!enabled) {
      // 禁用分屏模式时，停止所有非活动屏幕的播放
      for (int i = 0; i < 4; i++) {
        if (i != _activeScreenIndex) {
          stopScreen(i);
        }
      }
    }
    notifyListeners();
  }

  // 在指定屏幕播放频道
  Future<void> playChannelOnScreen(int screenIndex, Channel channel,
      {bool skipHistory = false}) async {
    if (screenIndex < 0 || screenIndex >= 4) return;
    
    // 使用 currentUrl 而不是 url，以保留当前选择的源索引
    final playUrl = channel.currentUrl;
    ServiceLocator.log.d('MultiScreenProvider: playChannelOnScreen - screenIndex=$screenIndex, channel=${channel.name}, sourceIndex=${channel.currentSourceIndex}, url=$playUrl, activeScreen=$_activeScreenIndex');
    
    final screen = _screens[screenIndex];
    
    // 如果已经在播放相同的频道和相同的源，不重复播放
    if (screen.channel?.currentUrl == playUrl && screen.isPlaying) {
      ServiceLocator.log.d('MultiScreenProvider: Already playing same channel and source, skipping');
      return;
    }
    
    // Windows端分屏模式也需要记录观看历史
    if (!skipHistory && channel.id != null) {
      await ServiceLocator.watchHistory
          .addWatchHistory(channel.id!, channel.playlistId);
      ServiceLocator.log.d('MultiScreenProvider: Recorded watch history for channel ${channel.name} (Windows multi-screen)');
    }
    
    screen.isLoading = true;
    screen.error = null;
    screen.channel = channel;
    screen.position = Duration.zero;
    screen.duration = Duration.zero;
    notifyListeners();
    
    try {
      // 如果播放器不存在，创建新的播放器
      if (screen.player == null) {
        ServiceLocator.log.d('MultiScreenProvider: Creating new player for screen $screenIndex');
        _createPlayerForScreen(screenIndex, useSoftwareDecoding: false);
        
        // 监听播放状态
        screen.player!.stream.playing.listen((playing) {
          ServiceLocator.log.d('MultiScreenProvider: Screen $screenIndex playing=$playing');
          screen.isPlaying = playing;
          // 播放开始后确保音量正确（使用当前的 _activeScreenIndex）
          if (playing) {
            _applyVolumeToScreen(screenIndex);
          }
          notifyListeners();
        });
        
        // 监听视频尺寸
        screen.player!.stream.width.listen((width) {
          screen.videoWidth = width ?? 0;
          notifyListeners();
        });
        
        screen.player!.stream.height.listen((height) {
          screen.videoHeight = height ?? 0;
          notifyListeners();
        });

        screen.player!.stream.position.listen((position) {
          screen.position = position;
          notifyListeners();
        });

        screen.player!.stream.duration.listen((duration) {
          screen.duration = duration;
          notifyListeners();
        });
        
        // 监听错误
        screen.player!.stream.error.listen((error) async {
          if (error.isNotEmpty) {
            ServiceLocator.log.d('MultiScreenProvider: Screen $screenIndex error=$error');
            if (_shouldTrySoftwareFallback(error, screen)) {
              _attemptSoftwareFallback(screenIndex);
              return;
            }
            final switched =
                await _tryNextSourceOnError(screenIndex, screen, error);
            if (switched) return;
            screen.error = error;
            screen.isLoading = false;
            notifyListeners();
          }
        });
        
        // 监听缓冲状态
        screen.player!.stream.buffering.listen((buffering) {
          screen.isLoading = buffering;
          notifyListeners();
        });
      }
      
      // 设置音量（只有活动屏幕有声音，使用有效音量包含音量增强）
      _applyVolumeToScreen(screenIndex);
      
      // 解析真实播放地址（处理302重定向）
      ServiceLocator.log.d('MultiScreenProvider: >>> 屏幕$screenIndex 开始解析302重定向');
      final redirectStartTime = DateTime.now();
      
      final realUrl = await ServiceLocator.redirectCache.resolveRealPlayUrl(playUrl);
      
      final redirectTime = DateTime.now().difference(redirectStartTime).inMilliseconds;
      ServiceLocator.log.d('MultiScreenProvider: >>> 屏幕$screenIndex 302重定向解析完成，耗时: ${redirectTime}ms');
      ServiceLocator.log.d('MultiScreenProvider: >>> 屏幕$screenIndex 使用播放地址: $realUrl');
      
      // 播放频道（使用解析后的真实URL）
      ServiceLocator.log.d('MultiScreenProvider: Opening media for screen $screenIndex: $realUrl');
      final playStartTime = DateTime.now();
      
      final userAgent = ServiceLocator.settings?.userAgent ?? SettingsProvider.defaultUserAgent;
      ServiceLocator.log.d('MultiScreenProvider: 屏幕$screenIndex User-Agent: $userAgent');
      await screen.player!.open(Media(realUrl, httpHeaders: {'User-Agent': userAgent}));
      
      final playTime = DateTime.now().difference(playStartTime).inMilliseconds;
      ServiceLocator.log.d('MultiScreenProvider: >>> 屏幕$screenIndex 播放器初始化完成，耗时: ${playTime}ms');
      
      // 播放开始后再次确保音量正确
      _applyVolumeToScreen(screenIndex);
      
      screen.isLoading = false;
      ServiceLocator.log.d('MultiScreenProvider: Screen $screenIndex started playing');
      notifyListeners();
    } catch (e) {
      ServiceLocator.log.d('MultiScreenProvider: Screen $screenIndex playback error: $e');
      final switched =
          await _tryNextSourceOnError(screenIndex, screen, e.toString());
      if (switched) return;
      screen.error = e.toString();
      screen.isLoading = false;
      notifyListeners();
    }
  }

  void _createPlayerForScreen(int screenIndex, {required bool useSoftwareDecoding}) {
    final screen = _screens[screenIndex];
    screen.player?.dispose();

    final bufferSize = switch (_bufferStrength) {
      'fast' => 32 * 1024 * 1024,
      'balanced' => 64 * 1024 * 1024,
      'stable' => 128 * 1024 * 1024,
      _ => 32 * 1024 * 1024,
    };

    String? vo;
    switch (_videoOutput) {
      case 'gpu':
        vo = 'gpu';
        break;
      case 'libmpv':
        vo = 'libmpv';
        break;
      case 'auto':
      default:
        vo = null;
        break;
    }

    final player = Player(
      configuration: PlayerConfiguration(
        bufferSize: bufferSize,
        vo: vo,
      ),
    );
    screen.player = player;

    final effectiveSoftware = useSoftwareDecoding || _decodingMode == 'software';
    String? hwdecMode;
    if (effectiveSoftware) {
      hwdecMode = 'no';
    } else {
      switch (_windowsHwdecMode) {
        case 'auto-copy':
          hwdecMode = 'auto-copy';
          break;
        case 'd3d11va':
          hwdecMode = 'd3d11va';
          break;
        case 'dxva2':
          hwdecMode = 'dxva2';
          break;
        case 'auto-safe':
        default:
          hwdecMode = 'auto-safe';
          break;
      }
    }

    screen.videoController = VideoController(
      player,
      configuration: VideoControllerConfiguration(
        hwdec: hwdecMode,
        enableHardwareAcceleration: !effectiveSoftware,
      ),
    );
    screen.isSoftwareDecoding = effectiveSoftware;
    screen.softwareFallbackAttempted = effectiveSoftware;
  }

  bool _shouldTrySoftwareFallback(String error, ScreenPlayerState screen) {
    if (_decodingMode == 'software') return false;
    if (!_allowSoftwareFallback) return false;
    if (screen.softwareFallbackAttempted || screen.isSoftwareDecoding) return false;
    final lower = error.toLowerCase();
    return lower.contains('codec') ||
        lower.contains('decoder') ||
        lower.contains('hwdec') ||
        lower.contains('hardware');
  }

  Future<void> _attemptSoftwareFallback(int screenIndex) async {
    final screen = _screens[screenIndex];
    if (screen.channel == null) return;
    screen.softwareFallbackAttempted = true;
    _createPlayerForScreen(screenIndex, useSoftwareDecoding: true);
    await playChannelOnScreen(screenIndex, screen.channel!, skipHistory: true);
  }

  Future<bool> _tryNextSourceOnError(
      int screenIndex, ScreenPlayerState screen, String error) async {
    final channel = screen.channel;
    if (channel == null || !channel.hasMultipleSources) return false;

    final nextIndex = channel.currentSourceIndex + 1;
    if (nextIndex >= channel.sourceCount) {
      ServiceLocator.log.d(
          'MultiScreenProvider: Screen $screenIndex all sources failed, lastError=$error');
      return false;
    }

    final nextChannel = channel.copyWith(currentSourceIndex: nextIndex);
    ServiceLocator.log.d(
        'MultiScreenProvider: Screen $screenIndex source ${channel.currentSourceIndex + 1}/${channel.sourceCount} failed, trying ${nextIndex + 1}/${channel.sourceCount}');
    await playChannelOnScreen(screenIndex, nextChannel, skipHistory: true);
    return true;
  }

  Future<void> _disposeScreenPlayer(int screenIndex) async {
    final screen = _screens[screenIndex];
    if (screen.player != null) {
      await screen.player!.stop();
      await screen.player!.dispose();
    }
    screen.player = null;
    screen.videoController = null;
    screen.isPlaying = false;
  }
  
  // 应用音量到指定屏幕
  void _applyVolumeToScreen(int screenIndex) {
    final screen = _screens[screenIndex];
    if (screen.player != null) {
      final targetVolume = screenIndex == _activeScreenIndex ? _getEffectiveVolume() : 0.0;
      ServiceLocator.log.d('MultiScreenProvider: _applyVolumeToScreen - screen=$screenIndex, active=$_activeScreenIndex, volume=$targetVolume');
      screen.player!.setVolume(targetVolume);
    }
  }
  
  // 重新应用音量到所有屏幕（用于恢复播放后确保音量正确）
  Future<void> reapplyVolumeToAllScreens() async {
    ServiceLocator.log.d('MultiScreenProvider: reapplyVolumeToAllScreens - activeScreen=$_activeScreenIndex');
    for (int i = 0; i < 4; i++) {
      _applyVolumeToScreen(i);
    }
    // 再次延迟应用，确保播放器完全就绪
    await Future.delayed(const Duration(milliseconds: 200));
    for (int i = 0; i < 4; i++) {
      _applyVolumeToScreen(i);
    }
  }

  // 停止指定屏幕的播放
  void stopScreen(int screenIndex) {
    if (screenIndex < 0 || screenIndex >= 4) return;
    
    final screen = _screens[screenIndex];
    screen.player?.stop();
    screen.isPlaying = false;
    screen.channel = null;
    notifyListeners();
  }

  // 清空指定屏幕
  void clearScreen(int screenIndex) {
    if (screenIndex < 0 || screenIndex >= 4) return;
    
    final screen = _screens[screenIndex];
    screen.dispose();
    _screens[screenIndex] = ScreenPlayerState();
    notifyListeners();
  }

  // 清空所有屏幕
  Future<void> clearAllScreens() async {
    ServiceLocator.log.d('MultiScreenProvider: clearAllScreens - stopping all players');
    final futures = <Future>[];
    for (int i = 0; i < 4; i++) {
      final screen = _screens[i];
      // 先停止播放
      if (screen.player != null) {
        ServiceLocator.log.d('MultiScreenProvider: Stopping player for screen $i');
        // 设置音量为0确保没有声音
        screen.player!.setVolume(0);
        futures.add(screen.player!.stop());
      }
    }
    // 等待所有播放器停止
    await Future.wait(futures);
    
    // 再释放资源
    for (int i = 0; i < 4; i++) {
      await _screens[i].dispose();
      _screens[i] = ScreenPlayerState();
    }
    _activeScreenIndex = 0;
    notifyListeners();
  }

  // 暂停所有屏幕（保留频道信息，以便恢复）
  void pauseAllScreens() {
    for (int i = 0; i < 4; i++) {
      final screen = _screens[i];
      // 停止并释放播放器，但保留频道信息
      screen.player?.dispose();
      screen.player = null;
      screen.videoController = null;
      screen.isPlaying = false;
    }
    notifyListeners();
  }

  // 恢复所有屏幕播放（重新播放记住的频道）
  Future<void> resumeAllScreens() async {
    for (int i = 0; i < 4; i++) {
      final screen = _screens[i];
      if (screen.channel != null) {
        // 重新播放该频道
        await playChannelOnScreen(i, screen.channel!);
      }
    }
  }

  // 检查是否有任何屏幕在播放
  bool get hasAnyChannel {
    return _screens.any((screen) => screen.channel != null);
  }

  // 获取活动屏幕的频道
  Channel? get activeChannel {
    return _screens[_activeScreenIndex].channel;
  }

  // 在默认位置播放频道
  void playChannelAtDefaultPosition(Channel channel, int defaultPosition) {
    final screenIndex = (defaultPosition - 1).clamp(0, 3);
    ServiceLocator.log.d('MultiScreenProvider: playChannelAtDefaultPosition - channel=${channel.name}, position=$defaultPosition, screenIndex=$screenIndex');
    setActiveScreen(screenIndex);
    playChannelOnScreen(screenIndex, channel);
  }

  // 切换到下一个频道（在活动屏幕）
  void playNextOnActiveScreen(List<Channel> channels) {
    final currentChannel = _screens[_activeScreenIndex].channel;
    if (currentChannel == null || channels.isEmpty) return;
    
    // 使用 id 或 name 进行比较，而不是 url（因为同一频道可能有多个源）
    final currentIndex = channels.indexWhere((c) => c.id == currentChannel.id || c.name == currentChannel.name);
    if (currentIndex == -1) return;
    
    final nextIndex = (currentIndex + 1) % channels.length;
    playChannelOnScreen(_activeScreenIndex, channels[nextIndex]);
  }

  // 切换到上一个频道（在活动屏幕）
  void playPreviousOnActiveScreen(List<Channel> channels) {
    final currentChannel = _screens[_activeScreenIndex].channel;
    if (currentChannel == null || channels.isEmpty) return;
    
    // 使用 id 或 name 进行比较，而不是 url（因为同一频道可能有多个源）
    final currentIndex = channels.indexWhere((c) => c.id == currentChannel.id || c.name == currentChannel.name);
    if (currentIndex == -1) return;
    
    final prevIndex = (currentIndex - 1 + channels.length) % channels.length;
    playChannelOnScreen(_activeScreenIndex, channels[prevIndex]);
  }

  bool shouldShowProgressBarForActiveScreen(String progressBarMode) {
    final screen = activeScreen;
    final durationSeconds = screen.duration.inSeconds;
    if (progressBarMode == 'never') return false;
    if (progressBarMode == 'always') return durationSeconds > 0;
    return screen.channel?.isSeekable == true &&
        durationSeconds > 0 &&
        durationSeconds <= 86400;
  }

  void seekActiveScreen(Duration position) {
    final screen = activeScreen;
    if (screen.player == null) return;
    screen.player!.seek(position);
  }

  Future<void> togglePlayPauseOnActiveScreen() async {
    final screen = activeScreen;
    final player = screen.player;
    if (player == null) return;
    if (screen.isPlaying) {
      await player.pause();
      screen.isPlaying = false;
    } else {
      await player.play();
      screen.isPlaying = true;
    }
    notifyListeners();
  }

  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0).toDouble();
    _applyVolumeToActiveScreen();
    notifyListeners();
  }

  void switchToNextSourceOnActiveScreen() {
    final screen = activeScreen;
    final channel = screen.channel;
    if (channel == null || !channel.hasMultipleSources) return;
    final newIndex = (channel.currentSourceIndex + 1) % channel.sourceCount;
    final nextChannel = channel.copyWith(currentSourceIndex: newIndex);
    playChannelOnScreen(_activeScreenIndex, nextChannel, skipHistory: true);
  }

  void switchToPreviousSourceOnActiveScreen() {
    final screen = activeScreen;
    final channel = screen.channel;
    if (channel == null || !channel.hasMultipleSources) return;
    final newIndex =
        (channel.currentSourceIndex - 1 + channel.sourceCount) %
            channel.sourceCount;
    final prevChannel = channel.copyWith(currentSourceIndex: newIndex);
    playChannelOnScreen(_activeScreenIndex, prevChannel, skipHistory: true);
  }

  @override
  void dispose() {
    for (final screen in _screens) {
      screen.dispose();
    }
    super.dispose();
  }
}
