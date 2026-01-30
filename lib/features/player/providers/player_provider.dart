import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'dart:async';
import 'dart:math' as math;

import '../../../core/models/channel.dart';
import '../../../core/platform/platform_detector.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/channel_test_service.dart';

enum PlayerState {
  idle,
  loading,
  playing,
  paused,
  error,
  buffering,
}

/// Unified player provider that uses:
/// - Native Android Activity (via MethodChannel) on Android TV for best 4K performance
/// - media_kit on Windows and other platforms
/// - ExoPlayer (video_player) as fallback on Android
class PlayerProvider extends ChangeNotifier {
  // media_kit player (for Windows/Desktop and fallback)
  Player? _mediaKitPlayer;
  VideoController? _videoController;

  // video_player (ExoPlayer) for Android fallback
  VideoPlayerController? _exoPlayer;
  int _exoPlayerKey = 0; // 用于强制 VideoPlayer widget 重建

  // Common state
  Channel? _currentChannel;
  PlayerState _state = PlayerState.idle;
  String? _error;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 1.0;
  bool _isMuted = false;
  double _playbackSpeed = 1.0;
  bool _isFullscreen = false;
  bool _controlsVisible = true;
  int _volumeBoostDb = 0;

  int _retryCount = 0;
  static const int _maxRetries = 2;  // 改为重试2次
  Timer? _retryTimer;
  bool _isAutoSwitching = false; // 标记是否正在自动切换源
  bool _isAutoDetecting = false; // 标记是否正在自动检测源

  // On Android TV, we use native player via Activity, so don't init any Flutter player
  // On Android phone/tablet, use video_player (ExoPlayer)
  // On other platforms, use media_kit
  bool get _useNativePlayer => Platform.isAndroid && PlatformDetector.isTV;
  bool get _useExoPlayer => Platform.isAndroid && !PlatformDetector.isTV;

  // Getters
  Player? get player => _mediaKitPlayer;
  VideoController? get videoController => _videoController;
  VideoPlayerController? get exoPlayer => _exoPlayer;
  int get exoPlayerKey => _exoPlayerKey; // 用于 VideoPlayer widget 的 key
  bool get useExoPlayer => _useExoPlayer;

  Channel? get currentChannel => _currentChannel;
  PlayerState get state => _state;
  String? get error => _error;
  Duration get position => _position;
  Duration get duration => _duration;
  double get volume => _volume;
  bool get isMuted => _isMuted;
  double get playbackSpeed => _playbackSpeed;
  bool get isFullscreen => _isFullscreen;
  bool get controlsVisible => _controlsVisible;

  bool get isPlaying => _state == PlayerState.playing;
  bool get isLoading => _state == PlayerState.loading || _state == PlayerState.buffering;
  bool get hasError => _state == PlayerState.error && _error != null;

  /// Check if current content is seekable (VOD or replay)
  bool get isSeekable {
    // 1. 检查频道类型（如果明确是直播，不可拖动）
    if (_currentChannel?.isLive == true) return false;
    
    // 2. 检查频道类型（如果是点播或回放，可拖动）
    if (_currentChannel?.isSeekable == true) {
      // 但还需要检查 duration 是否有效
      if (_duration.inSeconds > 0 && _duration.inSeconds <= 86400) {
        return true;
      }
    }
    
    // 3. 检查 duration（点播内容有明确时长）
    // 直播流通常 duration 为 0 或超大值
    if (_duration.inSeconds > 0 && _duration.inSeconds <= 86400) {
      // 有效时长（0秒到24小时），但要排除直播流
      if (_currentChannel?.isLive != true) {
        return true;
      }
    }
    
    // 4. 默认不可拖动（安全起见）
    return false;
  }
  
  /// Check if should show progress bar based on settings and content
  bool shouldShowProgressBar(String progressBarMode) {
    if (progressBarMode == 'never') return false;
    if (progressBarMode == 'always') return _duration.inSeconds > 0;
    // auto mode: only show for seekable content
    return isSeekable && _duration.inSeconds > 0;
  }
  
  /// Check if current content is live stream
  bool get isLiveStream => !isSeekable;

  // 清除错误状态（用于显示错误后防止重复显示）
  void clearError() {
    _error = null;
    _errorDisplayed = true; // 标记错误已被显示，防止重复触发
    // 重置状态为 idle，避免 hasError 一直为 true
    if (_state == PlayerState.error) {
      _state = PlayerState.idle;
    }
    notifyListeners();
  }

  // 错误防抖：记录上次错误时间，避免短时间内重复触发
  DateTime? _lastErrorTime;
  String? _lastErrorMessage;
  bool _errorDisplayed = false; // 标记错误是否已被显示

  void _setError(String error) {
    ServiceLocator.log.d('PlayerProvider: _setError 被调用 - 当前重试次数: $_retryCount/$_maxRetries, 错误: $error');
    
    // 忽略 seek 相关的错误（直播流不支持 seek）
    if (error.contains('seekable') || 
        error.contains('Cannot seek') || 
        error.contains('seek in this stream')) {
      ServiceLocator.log.d('PlayerProvider: 忽略 seek 错误（直播流不支持拖动）');
      return;
    }
    
    // 忽略音频解码警告（如果能播放声音，这只是警告）
    if (error.contains('Error decoding audio') || 
        error.contains('audio decoder') ||
        error.contains('Audio decoding')) {
      ServiceLocator.log.d('PlayerProvider: 忽略音频解码警告（可能只是部分帧解码失败）');
      return;
    }
    
    // 尝试自动重试（重试阶段不受防抖限制）
    if (_retryCount < _maxRetries && _currentChannel != null) {
      _retryCount++;
      ServiceLocator.log.d('PlayerProvider: 播放错误，尝试重试 ($_retryCount/$_maxRetries): $error');
      _retryTimer?.cancel();
      _retryTimer = Timer(const Duration(milliseconds: 500), () {
        if (_currentChannel != null) {
          _retryPlayback();
        }
      });
      return;
    }
    
    // 超过重试次数，检查是否有下一个源
    if (_currentChannel != null && _currentChannel!.hasMultipleSources) {
      final currentSourceIndex = _currentChannel!.currentSourceIndex;
      final totalSources = _currentChannel!.sourceCount;
      
      ServiceLocator.log.d('PlayerProvider: 当前源索引: $currentSourceIndex, 总源数: $totalSources');
      
      // 计算下一个源索引（不使用模运算，避免循环）
      int nextIndex = currentSourceIndex + 1;
      
      // 检查下一个源是否存在
      if (nextIndex < totalSources) {
        // 下一个源存在，先检测再尝试
        ServiceLocator.log.d('PlayerProvider: 当前源 (${currentSourceIndex + 1}/$totalSources) 重试失败，检测源 ${nextIndex + 1}');
        
        // 标记开始自动检测
        _isAutoDetecting = true;
        // 异步检测下一个源
        _checkAndSwitchToNextSource(nextIndex, error);
        return;
      } else {
        ServiceLocator.log.d('PlayerProvider: 已到达最后一个源 (${currentSourceIndex + 1}/$totalSources)，停止尝试');
      }
    }
    
    // 没有更多源或所有源都失败，显示错误（此时才应用防抖）
    final now = DateTime.now();
    // 如果错误已经被显示过，不再设置
    if (_errorDisplayed) {
      return;
    }
    // 相同错误在30秒内不重复设置
    if (_lastErrorMessage == error && _lastErrorTime != null && now.difference(_lastErrorTime!).inSeconds < 30) {
      return;
    }
    _lastErrorMessage = error;
    _lastErrorTime = now;
    
    ServiceLocator.log.d('PlayerProvider: 播放失败，显示错误');
    _state = PlayerState.error;
    _error = error;
    notifyListeners();
  }
  
  
  /// 检测并切换到下一个源（用于自动切换）
  Future<void> _checkAndSwitchToNextSource(int nextIndex, String originalError) async {
    if (_currentChannel == null || !_isAutoDetecting) return; // 如果检测被取消，停止
    
    // 更新UI显示正在检测的源
    _currentChannel!.currentSourceIndex = nextIndex;
    _state = PlayerState.loading;
    notifyListeners();
    
    ServiceLocator.log.d('PlayerProvider: 检测源 ${nextIndex + 1}/${_currentChannel!.sourceCount}');
    
    final testService = ChannelTestService();
    final tempChannel = Channel(
      id: _currentChannel!.id,
      name: _currentChannel!.name,
      url: _currentChannel!.sources[nextIndex],
      groupName: _currentChannel!.groupName,
      logoUrl: _currentChannel!.logoUrl,
      sources: [_currentChannel!.sources[nextIndex]],
      playlistId: _currentChannel!.playlistId,
    );
    
    final result = await testService.testChannel(tempChannel);
    
    if (!_isAutoDetecting) return; // 检测完成后再次检查是否被取消
    
    if (!result.isAvailable) {
      ServiceLocator.log.d('PlayerProvider: 源 ${nextIndex + 1} 不可用: ${result.error}，继续尝试下一个源');
      
      // 检查是否还有更多源
      final totalSources = _currentChannel!.sourceCount;
      final nextNextIndex = nextIndex + 1;
      
      if (nextNextIndex < totalSources) {
        // 继续检测下一个源
        _checkAndSwitchToNextSource(nextNextIndex, originalError);
      } else {
        // 已到达最后一个源，显示错误
        ServiceLocator.log.d('PlayerProvider: 已到达最后一个源，所有源都不可用');
        _isAutoDetecting = false;
        _state = PlayerState.error;
        _error = '所有 $totalSources 个源均不可用';
        notifyListeners();
      }
      return;
    }
    
    ServiceLocator.log.d('PlayerProvider: 源 ${nextIndex + 1} 可用 (${result.responseTime}ms)，切换');
    _isAutoDetecting = false;
    _retryCount = 0; // 重置重试计数
    _isAutoSwitching = true; // 标记为自动切换
    _lastErrorMessage = null; // 重置错误消息，允许新源的错误被处理
    _playCurrentSource();
    _isAutoSwitching = false; // 重置标记
  }

  /// 重试播放当前频道
  Future<void> _retryPlayback() async {
    if (_currentChannel == null) return;
    
    ServiceLocator.log.d('PlayerProvider: 正在重试播放 ${_currentChannel!.name}, 当前源索引: ${_currentChannel!.currentSourceIndex}, 重试计数: $_retryCount');
    _state = PlayerState.loading;
    _error = null;
    notifyListeners();
    
    // 使用 currentUrl 而不是 url，以使用当前选择的源
    final url = _currentChannel!.currentUrl;
    ServiceLocator.log.d('PlayerProvider: 重试URL: $url');
    
    try {
      if (_useExoPlayer) {
        await _initExoPlayer(url);
      } else {
        await _mediaKitPlayer?.open(Media(url));
        _state = PlayerState.playing;
      }
      // 注意：不在这里重置 _retryCount，因为播放器可能还会异步报错
      // 重试计数会在播放真正稳定后（playing 状态持续一段时间）或切换频道时重置
      ServiceLocator.log.d('PlayerProvider: 重试命令已发送');
    } catch (e) {
      ServiceLocator.log.d('PlayerProvider: 重试失败: $e');
      // 重试失败，继续尝试或显示错误
      _setError('Failed to play channel: $e');
    }
    notifyListeners();
  }

  String _hwdecMode = 'unknown';
  String _videoCodec = '';
  double _fps = 0;
  
  // FPS 显示
  double _currentFps = 0;
  
  // 视频信息
  int _videoWidth = 0;
  int _videoHeight = 0;
  double _downloadSpeed = 0; // bytes per second

  double get currentFps => _currentFps;
  int get videoWidth => _videoWidth;
  int get videoHeight => _videoHeight;
  double get downloadSpeed => _downloadSpeed;

  String get videoInfo {
    if (_useExoPlayer) {
      if (_exoPlayer == null || !_exoPlayer!.value.isInitialized) return '';
      final size = _exoPlayer!.value.size;
      return '${size.width.toInt()}x${size.height.toInt()} | ExoPlayer';
    } else {
      if (_mediaKitPlayer == null) return '';
      final w = _mediaKitPlayer!.state.width;
      final h = _mediaKitPlayer!.state.height;
      if (w == 0 || h == 0) return '';
      final parts = <String>['${w}x$h'];
      if (_videoCodec.isNotEmpty) parts.add(_videoCodec);
      if (_fps > 0) parts.add('${_fps.toStringAsFixed(1)} fps');
      parts.add('hwdec: $_hwdecMode');
      return parts.join(' | ');
    }
  }

  double get progress {
    if (_duration.inMilliseconds == 0) return 0;
    return _position.inMilliseconds / _duration.inMilliseconds;
  }

  PlayerProvider() {
    _initPlayer();
  }

  void _initPlayer({bool useSoftwareDecoding = false}) {
    // On Android TV, we use native player - don't initialize any Flutter player
    if (_useNativePlayer) {
      return;
    }

    if (!_useExoPlayer) {
      _initMediaKitPlayer(useSoftwareDecoding: useSoftwareDecoding);
    }
  }

  void _initMediaKitPlayer({bool useSoftwareDecoding = false, String bufferStrength = 'fast'}) {
    _mediaKitPlayer?.dispose();
    _debugInfoTimer?.cancel();

    // 根据缓冲强度设置缓冲区大小
    final bufferSize = switch (bufferStrength) {
      'fast' => 32 * 1024 * 1024,      // 32MB - 快速启动
      'balanced' => 64 * 1024 * 1024,  // 64MB - 平衡
      'stable' => 128 * 1024 * 1024,   // 128MB - 稳定
      _ => 32 * 1024 * 1024,
    };

    _mediaKitPlayer = Player(
      configuration: PlayerConfiguration(
        bufferSize: bufferSize,
        // 设置网络超时（秒）
        // timeout: 3 秒连接超时
      ),
    );

    VideoControllerConfiguration config = VideoControllerConfiguration(
      hwdec: Platform.isAndroid ? (useSoftwareDecoding ? 'no' : 'mediacodec') : null,
      enableHardwareAcceleration: !useSoftwareDecoding,
    );

    _videoController = VideoController(_mediaKitPlayer!, configuration: config);
    _setupMediaKitListeners();
    _updateDebugInfo();
  }

  void _setupMediaKitListeners() {
    _mediaKitPlayer!.stream.playing.listen((playing) {
      if (playing) {
        _state = PlayerState.playing;
        // 只有在播放稳定后才重置重试计数
        // 使用延迟确保播放真正开始，而不是短暂的状态变化
        Future.delayed(const Duration(seconds: 3), () {
          if (_state == PlayerState.playing && _currentChannel != null) {
            ServiceLocator.log.d('PlayerProvider: 播放稳定，重置重试计数');
            _retryCount = 0;
          }
        });
      } else if (_state == PlayerState.playing) {
        _state = PlayerState.paused;
      }
      notifyListeners();
    });

    _mediaKitPlayer!.stream.buffering.listen((buffering) {
      if (buffering && _state != PlayerState.idle && _state != PlayerState.error) {
        _state = PlayerState.buffering;
      } else if (!buffering && _state == PlayerState.buffering) {
        _state = _mediaKitPlayer!.state.playing ? PlayerState.playing : PlayerState.paused;
      }
      notifyListeners();
    });

    _mediaKitPlayer!.stream.position.listen((pos) {
      _position = pos;
      notifyListeners();
    });
    _mediaKitPlayer!.stream.duration.listen((dur) {
      _duration = dur;
      notifyListeners();
    });
    _mediaKitPlayer!.stream.tracks.listen((tracks) {
      for (final track in tracks.video) {
        if (track.codec != null) _videoCodec = track.codec!;
        if (track.fps != null) _fps = track.fps!;
      }
      notifyListeners();
    });
    _mediaKitPlayer!.stream.volume.listen((vol) {
      _volume = vol / 100;
      notifyListeners();
    });
    _mediaKitPlayer!.stream.error.listen((err) {
      if (err.isNotEmpty) {
        if (_shouldTrySoftwareFallback(err)) {
          _attemptSoftwareFallback();
        } else {
          _setError(err);
        }
      }
    });
    _mediaKitPlayer!.stream.width.listen((_) => notifyListeners());
    _mediaKitPlayer!.stream.height.listen((_) => notifyListeners());
  }

  Timer? _debugInfoTimer;
  
  void _updateDebugInfo() {
    _debugInfoTimer?.cancel();
    
    _debugInfoTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_mediaKitPlayer == null) return;
      _hwdecMode = 'mediacodec';
      
      // 更新视频尺寸
      _videoWidth = _mediaKitPlayer!.state.width ?? 0;
      _videoHeight = _mediaKitPlayer!.state.height ?? 0;
      
      // Windows 端直接使用 track 中的 fps 信息
      // media_kit (mpv) 的渲染帧率基本等于视频源帧率
      if (_state == PlayerState.playing && _fps > 0) {
        _currentFps = _fps;
      } else {
        _currentFps = 0;
      }
      
      // 估算下载速度 - 基于视频分辨率和帧率
      // media_kit 没有直接的下载速度 API，使用视频参数估算
      if (_state == PlayerState.playing && _videoWidth > 0 && _videoHeight > 0) {
        final pixels = _videoWidth * _videoHeight;
        final fps = _fps > 0 ? _fps : 25.0;
        // 估算公式：像素数 * 帧率 * 压缩系数 (H.264/H.265 典型压缩比)
        // 1080p@30fps 约 3-8 Mbps, 4K@30fps 约 15-25 Mbps
        double compressionFactor;
        if (pixels >= 3840 * 2160) {
          compressionFactor = 0.04; // 4K
        } else if (pixels >= 1920 * 1080) {
          compressionFactor = 0.06; // 1080p
        } else if (pixels >= 1280 * 720) {
          compressionFactor = 0.08; // 720p
        } else {
          compressionFactor = 0.10; // SD
        }
        final estimatedBitrate = pixels * fps * compressionFactor; // bits per second
        _downloadSpeed = estimatedBitrate / 8.0; // bytes per second
      } else {
        _downloadSpeed = 0;
      }
      
      notifyListeners();
    });
  }

  bool _shouldTrySoftwareFallback(String error) {
    final lowerError = error.toLowerCase();
    return (lowerError.contains('codec') || lowerError.contains('decoder') || lowerError.contains('hwdec') || lowerError.contains('mediacodec')) && _retryCount < _maxRetries;
  }

  void _attemptSoftwareFallback() {
    _retryCount++;
    final channelToPlay = _currentChannel;
    _initMediaKitPlayer(useSoftwareDecoding: true);
    if (channelToPlay != null) playChannel(channelToPlay);
  }

  // ============ ExoPlayer Methods ============

  /// 解析真实播放地址（使用全局缓存服务）
  Future<String> resolveRealPlayUrl(String url) async {
    return await ServiceLocator.redirectCache.resolveRealPlayUrl(url);
  }

  Future<void> _initExoPlayer(String url) async {
    // 确保旧播放器完全释放
    await _disposeExoPlayer();
    
    // 等待一小段时间确保资源完全释放
    await Future.delayed(const Duration(milliseconds: 100));

    // 增加 key 强制 VideoPlayer widget 重建
    _exoPlayerKey++;

    // 先通知 UI exoPlayer 已被释放
    notifyListeners();

    // 解析真实播放地址（处理302重定向）
    late final String realUrl;
    try {
      realUrl = await resolveRealPlayUrl(url);
      ServiceLocator.log.d('使用播放地址: $realUrl');
    } catch (e) {
      _setError('解析播放地址失败: $e');
      return;
    }

    _exoPlayer = VideoPlayerController.networkUrl(
      Uri.parse(realUrl),
      httpHeaders: const {
        'Connection': 'keep-alive',
        'User-Agent': 'miguvideo_android',
        'Accept': '*/*',
      },
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: false, 
        allowBackgroundPlayback: false,
      ),
    );

    _exoPlayer!.addListener(_onExoPlayerUpdate);

    try {
      await _exoPlayer!.initialize();
      // 初始化完成后立即通知 UI
      notifyListeners();

      await _exoPlayer!.setVolume(_isMuted ? 0 : _volume);
      await _exoPlayer!.play();
      _state = PlayerState.playing;
    } catch (e) {
      _setError('Failed to initialize player: $e');
      return;
    }
    notifyListeners();
  }

  void _onExoPlayerUpdate() {
    if (_exoPlayer == null) return;
    final value = _exoPlayer!.value;
    _position = value.position;
    _duration = value.duration;

    if (value.hasError) {
      _setError(value.errorDescription ?? 'Unknown error');
      return;
    } else if (value.isPlaying) {
      _state = PlayerState.playing;
    } else if (value.isBuffering) {
      _state = PlayerState.buffering;
    } else if (value.isInitialized && !value.isPlaying) {
      _state = PlayerState.paused;
    }

    notifyListeners();
  }

  Future<void> _disposeExoPlayer() async {
    if (_exoPlayer != null) {
      _exoPlayer!.removeListener(_onExoPlayerUpdate);
      await _exoPlayer!.dispose();
      _exoPlayer = null;
      notifyListeners(); // 通知 UI player 已被释放
    }
  }

  // ============ Public API ============

  Future<void> playChannel(Channel channel) async {
    ServiceLocator.log.i('========== 开始播放频道 ==========', tag: 'PlayerProvider');
    ServiceLocator.log.i('频道: ${channel.name} (ID: ${channel.id})', tag: 'PlayerProvider');
    ServiceLocator.log.d('URL: ${channel.url}', tag: 'PlayerProvider');
    ServiceLocator.log.d('源数量: ${channel.sourceCount}', tag: 'PlayerProvider');
    final playStartTime = DateTime.now();
    
    _currentChannel = channel;
    _state = PlayerState.loading;
    _error = null;
    _lastErrorMessage = null; // 重置错误防抖
    _errorDisplayed = false; // 重置错误显示标记
    _retryCount = 0; // 重置重试计数
    _retryTimer?.cancel(); // 取消任何正在进行的重试
    _isAutoDetecting = false; // 取消任何正在进行的自动检测
    loadVolumeSettings(); // Apply volume boost settings
    notifyListeners();

    // 如果有多个源，先检测找到第一个可用的源
    if (channel.hasMultipleSources) {
      ServiceLocator.log.i('频道有 ${channel.sourceCount} 个源，开始检测可用源', tag: 'PlayerProvider');
      final detectStartTime = DateTime.now();
      
      final availableSourceIndex = await _findFirstAvailableSource(channel);
      
      final detectTime = DateTime.now().difference(detectStartTime).inMilliseconds;
      
      if (availableSourceIndex != null) {
        channel.currentSourceIndex = availableSourceIndex;
        ServiceLocator.log.i('找到可用源 ${availableSourceIndex + 1}/${channel.sourceCount}，检测耗时: ${detectTime}ms', tag: 'PlayerProvider');
      } else {
        ServiceLocator.log.e('所有 ${channel.sourceCount} 个源都不可用，检测耗时: ${detectTime}ms', tag: 'PlayerProvider');
        _setError('所有 ${channel.sourceCount} 个源均不可用');
        return;
      }
    }

    // 使用 currentUrl 而不是 url，以保留当前选择的源索引
    final playUrl = channel.currentUrl;
    ServiceLocator.log.d('准备播放URL: $playUrl', tag: 'PlayerProvider');

    try {
      final playerInitStartTime = DateTime.now();
      
      if (_useExoPlayer) {
        ServiceLocator.log.d('使用 ExoPlayer', tag: 'PlayerProvider');
        await _initExoPlayer(playUrl);
      } else {
        ServiceLocator.log.d('使用 MediaKit', tag: 'PlayerProvider');
        await _mediaKitPlayer?.open(Media(playUrl));
        _state = PlayerState.playing;
      }
      
      final playerInitTime = DateTime.now().difference(playerInitStartTime).inMilliseconds;
      final totalTime = DateTime.now().difference(playStartTime).inMilliseconds;
      ServiceLocator.log.i('播放器初始化完成，耗时: ${playerInitTime}ms', tag: 'PlayerProvider');
      ServiceLocator.log.i('========== 频道播放总耗时: ${totalTime}ms ==========', tag: 'PlayerProvider');
    } catch (e) {
      ServiceLocator.log.e('播放频道失败', tag: 'PlayerProvider', error: e);
      _setError('Failed to play channel: $e');
      return;
    }
    notifyListeners();
  }

  /// 查找第一个可用的源
  Future<int?> _findFirstAvailableSource(Channel channel) async {
    ServiceLocator.log.d('开始检测 ${channel.sourceCount} 个源', tag: 'PlayerProvider');
    final testService = ChannelTestService();
    
    for (int i = 0; i < channel.sourceCount; i++) {
      // 更新UI显示当前检测的源
      channel.currentSourceIndex = i;
      notifyListeners();
      
      // 创建临时频道对象用于测试
      final tempChannel = Channel(
        id: channel.id,
        name: channel.name,
        url: channel.sources[i],
        groupName: channel.groupName,
        logoUrl: channel.logoUrl,
        sources: [channel.sources[i]], // 只测试当前源
        playlistId: channel.playlistId,
      );
      
      ServiceLocator.log.d('检测源 ${i + 1}/${channel.sourceCount}', tag: 'PlayerProvider');
      final testStartTime = DateTime.now();
      
      final result = await testService.testChannel(tempChannel);
      final testTime = DateTime.now().difference(testStartTime).inMilliseconds;
      
      if (result.isAvailable) {
        ServiceLocator.log.i('✓ 源 ${i + 1} 可用，响应时间: ${result.responseTime}ms，检测耗时: ${testTime}ms', tag: 'PlayerProvider');
        return i;
      } else {
        ServiceLocator.log.w('✗ 源 ${i + 1} 不可用: ${result.error}，检测耗时: ${testTime}ms', tag: 'PlayerProvider');
      }
    }
    
    ServiceLocator.log.e('所有 ${channel.sourceCount} 个源都不可用', tag: 'PlayerProvider');
    return null; // 所有源都不可用
  }

  Future<void> playUrl(String url, {String? name}) async {
    _state = PlayerState.loading;
    _error = null;
    _lastErrorMessage = null; // 重置错误防抖
    _errorDisplayed = false; // 重置错误显示标记
    loadVolumeSettings(); // Apply volume boost settings
    notifyListeners();

    try {
      if (_useExoPlayer) {
        await _initExoPlayer(url);
      } else {
        await _mediaKitPlayer?.open(Media(url));
        _state = PlayerState.playing;
      }
    } catch (e) {
      _setError('Failed to play: $e');
      return;
    }
    notifyListeners();
  }

  void togglePlayPause() {
    if (_useExoPlayer) {
      if (_exoPlayer == null) return;
      _exoPlayer!.value.isPlaying ? _exoPlayer!.pause() : _exoPlayer!.play();
    } else {
      _mediaKitPlayer?.playOrPause();
    }
  }

  void pause() {
    _useExoPlayer ? _exoPlayer?.pause() : _mediaKitPlayer?.pause();
  }

  void play() {
    _useExoPlayer ? _exoPlayer?.play() : _mediaKitPlayer?.play();
  }

  Future<void> stop({bool silent = false}) async {
    // 清除错误状态和定时器
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryCount = 0;
    _error = null;
    _errorDisplayed = false;
    _lastErrorMessage = null;
    _lastErrorTime = null;
    _isAutoSwitching = false;
    _isAutoDetecting = false;
    
    if (_useExoPlayer) {
      await _disposeExoPlayer();
    } else {
      _mediaKitPlayer?.stop();
    }
    _state = PlayerState.idle;
    _currentChannel = null;
    
    if (!silent) {
      notifyListeners();
    }
  }

  void seek(Duration position) {
    _useExoPlayer ? _exoPlayer?.seekTo(position) : _mediaKitPlayer?.seek(position);
  }

  void seekForward(int seconds) {
    seek(_position + Duration(seconds: seconds));
  }

  void seekBackward(int seconds) {
    final newPos = _position - Duration(seconds: seconds);
    seek(newPos.isNegative ? Duration.zero : newPos);
  }

  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    _applyVolume();
    if (_volume > 0) _isMuted = false;
    notifyListeners();
  }

  double _volumeBeforeMute = 1.0; // 保存静音前的音量

  void toggleMute() {
    if (!_isMuted) {
      // 静音前保存当前音量
      _volumeBeforeMute = _volume > 0 ? _volume : 1.0;
    }
    _isMuted = !_isMuted;
    if (!_isMuted && _volume == 0) {
      // 取消静音时如果音量为0，恢复到之前的音量
      _volume = _volumeBeforeMute;
    }
    _applyVolume();
    notifyListeners();
  }

  /// Apply volume boost from settings (in dB)
  void setVolumeBoost(int db) {
    _volumeBoostDb = db.clamp(-20, 20);
    _applyVolume();
    notifyListeners();
  }

  /// Load volume settings from preferences
  void loadVolumeSettings() {
    final prefs = ServiceLocator.prefs;
    // 音量增强独立于音量标准化，始终加载
    _volumeBoostDb = prefs.getInt('volume_boost') ?? 0;
    _applyVolume();
  }

  /// Calculate and apply the effective volume with boost
  void _applyVolume() {
    if (_isMuted) {
      _useExoPlayer ? _exoPlayer?.setVolume(0) : _mediaKitPlayer?.setVolume(0);
      return;
    }

    // Convert dB to linear multiplier: multiplier = 10^(dB/20)
    final multiplier = math.pow(10, _volumeBoostDb / 20.0);
    final effectiveVolume = (_volume * multiplier).clamp(0.0, 2.0); // Allow up to 2x volume

    if (_useExoPlayer) {
      _exoPlayer?.setVolume(effectiveVolume);
    } else {
      // media_kit uses 0-100 scale, but can go higher for boost
      _mediaKitPlayer?.setVolume(effectiveVolume * 100);
    }
  }

  void setPlaybackSpeed(double speed) {
    _playbackSpeed = speed;
    _useExoPlayer ? _exoPlayer?.setPlaybackSpeed(speed) : _mediaKitPlayer?.setRate(speed);
    notifyListeners();
  }

  void toggleFullscreen() {
    _isFullscreen = !_isFullscreen;
    notifyListeners();
  }

  void setFullscreen(bool fullscreen) {
    _isFullscreen = fullscreen;
    notifyListeners();
  }

  void setControlsVisible(bool visible) {
    _controlsVisible = visible;
    notifyListeners();
  }

  void toggleControls() {
    _controlsVisible = !_controlsVisible;
    notifyListeners();
  }

  void playNext(List<Channel> channels) {
    if (_currentChannel == null || channels.isEmpty) return;
    final idx = channels.indexWhere((c) => c.id == _currentChannel!.id);
    if (idx == -1 || idx >= channels.length - 1) return;
    playChannel(channels[idx + 1]);
  }

  void playPrevious(List<Channel> channels) {
    if (_currentChannel == null || channels.isEmpty) return;
    final idx = channels.indexWhere((c) => c.id == _currentChannel!.id);
    if (idx <= 0) return;
    playChannel(channels[idx - 1]);
  }

  /// Switch to next source for current channel (if has multiple sources)
  void switchToNextSource() {
    if (_currentChannel == null || !_currentChannel!.hasMultipleSources) return;
    
    // 取消正在进行的自动检测
    _isAutoDetecting = false;
    _retryTimer?.cancel();
    
    final newIndex = (_currentChannel!.currentSourceIndex + 1) % _currentChannel!.sourceCount;
    _currentChannel!.currentSourceIndex = newIndex;
    
    ServiceLocator.log.d('PlayerProvider: 手动切换到源 ${newIndex + 1}/${_currentChannel!.sourceCount}');
    
    // 只有在非自动切换时才重置（手动切换时重置）
    if (!_isAutoSwitching) {
      _retryCount = 0;
      ServiceLocator.log.d('PlayerProvider: 手动切换源，重置重试状态');
    }
    
    // Play the new source
    _playCurrentSource();
  }

  /// Switch to previous source for current channel (if has multiple sources)
  void switchToPreviousSource() {
    if (_currentChannel == null || !_currentChannel!.hasMultipleSources) return;
    
    // 取消正在进行的自动检测
    _isAutoDetecting = false;
    _retryTimer?.cancel();
    
    final newIndex = (_currentChannel!.currentSourceIndex - 1 + _currentChannel!.sourceCount) % _currentChannel!.sourceCount;
    _currentChannel!.currentSourceIndex = newIndex;
    
    ServiceLocator.log.d('PlayerProvider: 手动切换到源 ${newIndex + 1}/${_currentChannel!.sourceCount}');
    
    // 只有在非自动切换时才重置（手动切换时重置）
    if (!_isAutoSwitching) {
      _retryCount = 0;
      ServiceLocator.log.d('PlayerProvider: 手动切换源，重置重试状态');
    }
    
    // Play the new source
    _playCurrentSource();
  }

  /// Play the current source of the current channel
  Future<void> _playCurrentSource() async {
    if (_currentChannel == null) return;
    
    // 记录日志
    ServiceLocator.log.d('开始播放频道源', tag: 'PlayerProvider');
    ServiceLocator.log.d('频道: ${_currentChannel!.name}, 源索引: ${_currentChannel!.currentSourceIndex}/${_currentChannel!.sourceCount}', tag: 'PlayerProvider');
    
    // 检测当前源是否可用
    final testService = ChannelTestService();
    final tempChannel = Channel(
      id: _currentChannel!.id,
      name: _currentChannel!.name,
      url: _currentChannel!.currentUrl,
      groupName: _currentChannel!.groupName,
      logoUrl: _currentChannel!.logoUrl,
      sources: [_currentChannel!.currentUrl],
      playlistId: _currentChannel!.playlistId,
    );
    
    ServiceLocator.log.i('检测源可用性: ${_currentChannel!.currentUrl}', tag: 'PlayerProvider');
    
    final result = await testService.testChannel(tempChannel);
    
    if (!result.isAvailable) {
      ServiceLocator.log.w('源不可用: ${result.error}', tag: 'PlayerProvider');
      _setError('源不可用: ${result.error}');
      return;
    }
    
    ServiceLocator.log.i('源可用，响应时间: ${result.responseTime}ms', tag: 'PlayerProvider');
    
    final url = _currentChannel!.currentUrl;
    _state = PlayerState.loading;
    _error = null;
    _lastErrorMessage = null;
    _errorDisplayed = false;
    notifyListeners();

    try {
      if (_useExoPlayer) {
        await _initExoPlayer(url);
      } else {
        await _mediaKitPlayer?.open(Media(url));
        _state = PlayerState.playing;
      }
      ServiceLocator.log.i('播放成功', tag: 'PlayerProvider');
    } catch (e) {
      ServiceLocator.log.e('播放失败', tag: 'PlayerProvider', error: e);
      _setError('Failed to play source: $e');
      return;
    }
    notifyListeners();
  }

  /// Get current source index (1-based for display)
  int get currentSourceIndex => (_currentChannel?.currentSourceIndex ?? 0) + 1;

  /// Get total source count
  int get sourceCount => _currentChannel?.sourceCount ?? 1;

  /// Set current channel without starting playback (for native player coordination)
  void setCurrentChannelOnly(Channel channel) {
    _currentChannel = channel;
    notifyListeners();
  }

  @override
  void dispose() {
    _debugInfoTimer?.cancel();
    _retryTimer?.cancel();
    _mediaKitPlayer?.dispose();
    _disposeExoPlayer();
    super.dispose();
  }
}
