import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'dart:io';
import 'dart:async';
import 'dart:math' as math;

import '../../../core/models/channel.dart';
import '../../../core/platform/platform_detector.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/channel_test_service.dart';
import '../../../core/services/log_service.dart';
import '../../settings/providers/settings_provider.dart';

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
/// - media_kit on all other platforms (Windows, Android phone/tablet, etc.)
class PlayerProvider extends ChangeNotifier {
  // media_kit player (for all platforms except Android TV)
  Player? _mediaKitPlayer;
  VideoController? _videoController;

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
  bool _isSoftwareDecoding = false;
  bool _noVideoFallbackAttempted = false;
  bool _allowSoftwareFallback = true;
  String _windowsHwdecMode = 'auto-safe';
  bool _isDisposed = false;
  String _videoOutput = 'auto';
  String _vo = 'unknown';
  String _configuredVo = 'auto';

  // On Android TV, we use native player via Activity, so don't init any Flutter player
  // On Android phone/tablet and other platforms, use media_kit
  bool get _useNativePlayer => Platform.isAndroid && PlatformDetector.isTV;

  // Getters
  Player? get player => _mediaKitPlayer;
  VideoController? get videoController => _videoController;

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

  /// Create Media object with custom User-Agent header
  Media _createMedia(String url) {
    final userAgent = ServiceLocator.settings?.userAgent ?? SettingsProvider.defaultUserAgent;
    ServiceLocator.log.d('PlayerProvider: 创建Media对象 User-Agent: $userAgent');
    return Media(url, httpHeaders: {'User-Agent': userAgent});
  }

  /// Check if current content is seekable (VOD or replay)
  bool get isSeekable {
    // 1. 检查直播类型（如果明确是直播，不可拖动）
    if (_currentChannel?.isLive == true) return false;
    
    // 2. 检查直播类型（如果是点播或回放，可拖动）
    if (_currentChannel?.isSeekable == true) {
      // 但还需要检查 duration 是否有效
      if (_duration.inSeconds > 0 && _duration.inSeconds <= 86400) {
        return true;
      }
    }
    
    // 3. 检查 duration（点播内容有明确时长）
    // 直播流通常 duration 为 0 或超大值
    if (_duration.inSeconds > 0 && _duration.inSeconds <= 86400) {
      // 有效时长（1秒到24小时），但要排除直播流
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
    
    // 忽略音频解码警告（如果还能播放声音，这只是警告）
    if (error.contains('Error decoding audio') || 
        error.contains('audio decoder') ||
        error.contains('Audio decoding')) {
      ServiceLocator.log.d('PlayerProvider: Ignore audio decode warning (likely partial frame decode failure)');
      return;
    }
    
    // 尝试自动重试（重试阶段不受防护限制）
    if (_retryCount < _maxRetries && _currentChannel != null) {
      _retryCount++;
      ServiceLocator.log.d('PlayerProvider: 播放错误，尝试重试($_retryCount/$_maxRetries): $error');
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
      
      // 计算下一个源索引（不使用取模运算，避免循环）
      int nextIndex = currentSourceIndex + 1;
      
      // 检查下一个源是否存在
      if (nextIndex < totalSources) {
        // 下一个源存在，先检测再尝试
        ServiceLocator.log.d('PlayerProvider: 当前源(${currentSourceIndex + 1}/$totalSources) 重试失败，检测源 ${nextIndex + 1}');
        
        // 标记开始自动检测
        _isAutoDetecting = true;
        // 异步检测下一个源
        _checkAndSwitchToNextSource(nextIndex, error);
        return;
      } else {
        ServiceLocator.log.d('PlayerProvider: 已到最后一个源 (${currentSourceIndex + 1}/$totalSources), 停止尝试');
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
    
    ServiceLocator.log.d('PlayerProvider: Playback failed, show error');
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
        // 已到最后一个源，显示错误
        ServiceLocator.log.d('PlayerProvider: 已到最后一个源，所有源都不可用');
        _isAutoDetecting = false;
        _state = PlayerState.error;
        _error = '所有 $totalSources 个源都不可用';
        notifyListeners();
      }
      return;
    }
    
    ServiceLocator.log.d('PlayerProvider: Source ${nextIndex + 1} is available (${result.responseTime}ms), switching');
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
    final startTime = DateTime.now();
    
    _state = PlayerState.loading;
    _error = null;
    notifyListeners();
    
    // 使用 currentUrl 而不是 url，以使用当前选择的源
    final url = _currentChannel!.currentUrl;
    ServiceLocator.log.d('PlayerProvider: 重试URL: $url');
    
    try {
      if (!_useNativePlayer) {
        ServiceLocator.log.i('>>> Retry: start resolving redirect', tag: 'PlayerProvider');
        // 解析真实播放地址（处理 302 重定向）
        final redirectStartTime = DateTime.now();
        
        final realUrl = await ServiceLocator.redirectCache.resolveRealPlayUrl(url);
        
        final redirectTime = DateTime.now().difference(redirectStartTime).inMilliseconds;
        ServiceLocator.log.i('>>> 重试: 302重定向解析完成，耗时: ${redirectTime}ms', tag: 'PlayerProvider');
        ServiceLocator.log.d('>>> 重试: 使用播放地址: $realUrl', tag: 'PlayerProvider');
        
        final playStartTime = DateTime.now();
        await _mediaKitPlayer?.open(_createMedia(realUrl));
        
        final playTime = DateTime.now().difference(playStartTime).inMilliseconds;
        final totalTime = DateTime.now().difference(startTime).inMilliseconds;
        ServiceLocator.log.i('>>> 重试: 播放器初始化完成，耗时: ${playTime}ms', tag: 'PlayerProvider');
        ServiceLocator.log.i('>>> 重试: 总耗时: ${totalTime}ms', tag: 'PlayerProvider');
        
        _state = PlayerState.playing;
      }
      // 注意：不在这里重置 _retryCount，因为播放器可能还会异步报错
      // 重试计数会在播放真正稳定后（playing 状态持续一段时间）或切换频道时重置
      ServiceLocator.log.d('PlayerProvider: Retry command sent');
    } catch (e) {
      final totalTime = DateTime.now().difference(startTime).inMilliseconds;
      ServiceLocator.log.d('PlayerProvider: 重试失败 (${totalTime}ms): $e');
      // 重试失败，继续尝试或显示错误
      _setError('Failed to play channel: $e');
    }
    notifyListeners();
  }

  String _hwdecMode = 'unknown';
  String _videoCodec = '';
  double _fps = 0;
  
  // 保存初始化时的 hwdec 配置
  String _configuredHwdec = 'unknown';
  
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
    if (_mediaKitPlayer == null) return '';
    final w = _mediaKitPlayer!.state.width;
    final h = _mediaKitPlayer!.state.height;
    if (w == 0 || h == 0) return '';
    final parts = <String>['${w}x$h'];
    if (_videoCodec.isNotEmpty) parts.add(_videoCodec);
    if (_fps > 0) parts.add('${_fps.toStringAsFixed(1)} fps');
    final hwdecInfo = _formatHwdecInfo();
    if (hwdecInfo.isNotEmpty) {
      parts.add('hwdec: $hwdecInfo');
    }
    final voInfo = _formatVoInfo();
    if (voInfo.isNotEmpty) {
      parts.add('vo: $voInfo');
    }
    return parts.join(' | ');
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

    // 其他平台（包括 Android 手机）都使用 media_kit
    _initMediaKitPlayer(useSoftwareDecoding: useSoftwareDecoding);
  }
  
  /// 预热播放器 - 在应用启动时调用,提前初始化播放器资源
  /// 这样首次进入播放页面时就不会卡顿
  Future<void> warmup() async {
    if (_useNativePlayer) {
      return; // 原生播放器不需要预热
    }
    
    if (_mediaKitPlayer == null) {
      ServiceLocator.log.d('PlayerProvider: 预热播放器 - 初始化 media_kit', tag: 'PlayerProvider');
      _initMediaKitPlayer();
    }
    
    // 使用空 Media 预热会触发错误回调，可能导致首次播放黑屏/蓝屏
    // 目前只做实例初始化，不做无效流程预加载
  }

  void _initMediaKitPlayer({bool useSoftwareDecoding = false, String bufferStrength = 'fast'}) {
    _mediaKitPlayer?.dispose();
    _debugInfoTimer?.cancel();
    // Load decoding settings (overridden by explicit useSoftwareDecoding)
    final prefs = ServiceLocator.prefs;
    final decodingMode = prefs.getString('decoding_mode') ?? 'auto';
    _windowsHwdecMode = prefs.getString('windows_hwdec_mode') ?? 'auto-safe';
    _allowSoftwareFallback = prefs.getBool('allow_software_fallback') ?? true;
    _videoOutput = prefs.getString('video_output') ?? 'auto';
    final effectiveSoftware = useSoftwareDecoding || decodingMode == 'software';
    _isSoftwareDecoding = effectiveSoftware;

    ServiceLocator.log.i('========== 初始化播放器 ==========', tag: 'PlayerProvider');
    ServiceLocator.log.i('平台: ${Platform.operatingSystem}', tag: 'PlayerProvider');
    ServiceLocator.log.i('软解码模式: $useSoftwareDecoding', tag: 'PlayerProvider');
    ServiceLocator.log.i('缓冲强度: $bufferStrength', tag: 'PlayerProvider');

    // 根据缓冲强度设置缓冲区大小
    final bufferSize = switch (bufferStrength) {
      'fast' => 32 * 1024 * 1024,      // 32MB - 快速启动
      'balanced' => 64 * 1024 * 1024,  // 64MB - 平衡模式
      'stable' => 128 * 1024 * 1024,   // 128MB - 稳定优先
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
    _configuredVo = _videoOutput;

    _mediaKitPlayer = Player(
      configuration: PlayerConfiguration(
        bufferSize: bufferSize,
        vo: vo,
        // 设置网络超时（可选）
        // timeout: 3 秒连接最长超时
        // 根据日志级别启用 mpv 日志
        logLevel: ServiceLocator.log.currentLevel == LogLevel.debug
            ? MPVLogLevel.debug
            : (ServiceLocator.log.currentLevel == LogLevel.off
                ? MPVLogLevel.error
                : MPVLogLevel.info),
      ),
    );

    // 确畾确欢视ｇ爜妯″紡
    String? hwdecMode;
    if (Platform.isAndroid) {
      hwdecMode = effectiveSoftware ? 'no' : 'mediacodec';
    } else if (Platform.isWindows) {
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
    }

    _configuredHwdec = hwdecMode ?? 'default';
    ServiceLocator.log.i('硬件解码模式: ${hwdecMode ?? "默认"}', tag: 'PlayerProvider');
    ServiceLocator.log.i('确欢加犻€? ${!effectiveSoftware}', tag: 'PlayerProvider');

    VideoControllerConfiguration config = VideoControllerConfiguration(
      hwdec: hwdecMode,
      enableHardwareAcceleration: !effectiveSoftware,
    );

    // 默认显示为配置值，后续可被实际运行时覆盖
    _hwdecMode = effectiveSoftware ? 'no' : _configuredHwdec;
    _vo = vo ?? 'auto';

    _videoController = VideoController(_mediaKitPlayer!, configuration: config);
    _setupMediaKitListeners();
    _updateDebugInfo();
    
    ServiceLocator.log.i('播放器初始化完成', tag: 'PlayerProvider');
  }

  void _setupMediaKitListeners() {
    ServiceLocator.log.d('设置播放器监听器', tag: 'PlayerProvider');
    
    // 只有在日志关闭时才完成 mpv 日志
      if (ServiceLocator.log.currentLevel != LogLevel.off) {
        _mediaKitPlayer!.stream.log.listen((log) {
          final message = log.text.toLowerCase();
          ServiceLocator.log.d('MPV log: ${log.text}', tag: 'PlayerProvider');
          
          // // 检测并记录解码信息
        if (message.contains('using hardware decoding') || 
            message.contains('hwdec') ||
            message.contains('d3d11va') ||
            message.contains('nvdec') ||
            message.contains('dxva2') ||
            message.contains('qsv')) {
            ServiceLocator.log.i('使用硬件解码: ${log.text}', tag: 'PlayerProvider');
            _updateHwdecFromLog(message);
          }
        
        // // 检测到 GPU 解码
        if (message.contains('gpu') || 
            message.contains('nvidia') || 
            message.contains('intel') || 
            message.contains('amd') ||
            message.contains('adapter') ||
            message.contains('device')) {
          ServiceLocator.log.i('使用 GPU 解码: ${log.text}', tag: 'PlayerProvider');
        }
        
        // // 检测到软件解码
          if (message.contains('vo/gpu') || 
              message.contains('opengl') || 
              message.contains('d3d11') ||
              message.contains('vulkan') ||
              message.contains('video output') ||
              message.contains('vo:')) {
            ServiceLocator.log.i('使用软件解码 ${log.text}', tag: 'PlayerProvider');
            _updateVoFromLog(message);
          }
        
        // // 检测到解码选项
        if (message.contains('decoder') || message.contains('codec')) {
          ServiceLocator.log.d('检测解码方式 ${log.text}', tag: 'PlayerProvider');
        }
        
        // 记录错误和警告
        if (log.level == MPVLogLevel.error) {
          ServiceLocator.log.e('MPV错误: ${log.text}', tag: 'PlayerProvider');
        } else if (log.level == MPVLogLevel.warn) {
          ServiceLocator.log.w('MPV警告: ${log.text}', tag: 'PlayerProvider');
        }
        });
      }
    
    _mediaKitPlayer!.stream.playing.listen((playing) {
      ServiceLocator.log.d('播放状态变化: playing=$playing', tag: 'PlayerProvider');
      if (playing) {
        _state = PlayerState.playing;
        // 只有在播放稳定后才重置重试计数
        // 使用延迟确保播放真正开始，而不是短暂的状态变化
        Future.delayed(const Duration(seconds: 3), () {
          if (_state == PlayerState.playing && _currentChannel != null) {
            ServiceLocator.log.d('PlayerProvider: Playback stable, reset retry count');
            _retryCount = 0;
          }
        });
      } else if (_state == PlayerState.playing) {
        _state = PlayerState.paused;
      }
      notifyListeners();
    });

    _mediaKitPlayer!.stream.buffering.listen((buffering) {
      ServiceLocator.log.d('缓冲状态: buffering=$buffering', tag: 'PlayerProvider');
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
      ServiceLocator.log.d('轨ㄩ亾淇℃伅更存柊: 视嗛轨?${tracks.video.length}, 音抽轨?${tracks.audio.length}', tag: 'PlayerProvider');
      
      for (final track in tracks.video) {
        if (track.codec != null) {
          _videoCodec = track.codec!;
          ServiceLocator.log.i('视嗛缂栫爜: ${track.codec}', tag: 'PlayerProvider');
        }
        if (track.fps != null) {
          _fps = track.fps!;
          ServiceLocator.log.i('视嗛甯х巼: ${track.fps} fps', tag: 'PlayerProvider');
        }
        if (track.w != null && track.h != null) {
          ServiceLocator.log.i('视嗛分嗚鲸率? ${track.w}x${track.h}', tag: 'PlayerProvider');
        }
      }
      
      for (final track in tracks.audio) {
        if (track.codec != null) {
          ServiceLocator.log.i('音抽缂栫爜: ${track.codec}', tag: 'PlayerProvider');
        }
      }
      
      notifyListeners();
    });
    
    _mediaKitPlayer!.stream.volume.listen((vol) {
      _volume = vol / 100;
      notifyListeners();
    });
    
    _mediaKitPlayer!.stream.error.listen((err) {
      if (err.isNotEmpty) {
        ServiceLocator.log.e('播放器错误: $err', tag: 'PlayerProvider');
        
        // 分析错误类型
        if (err.toLowerCase().contains('decode') || err.toLowerCase().contains('decoder')) {
          ServiceLocator.log.e('>>> 解码错误: $err', tag: 'PlayerProvider');
        } else if (err.toLowerCase().contains('render') || err.toLowerCase().contains('display')) {
          ServiceLocator.log.e('>>> 网络错误: $err', tag: 'PlayerProvider');
        } else if (err.toLowerCase().contains('hwdec') || err.toLowerCase().contains('hardware')) {
          ServiceLocator.log.e('>>> 确欢加犻€熼敊璇? $err', tag: 'PlayerProvider');
        } else if (err.toLowerCase().contains('codec')) {
          ServiceLocator.log.e('>>> 解码器错误: $err', tag: 'PlayerProvider');
        }
        
        if (_shouldTrySoftwareFallback(err)) {
          ServiceLocator.log.w('宽濊瘯轨В素佸洖退', tag: 'PlayerProvider');
          _attemptSoftwareFallback();
        } else {
          _setError(err);
        }
      }
    });
    
    _mediaKitPlayer!.stream.width.listen((width) {
      if (width != null && width > 0) {
        ServiceLocator.log.d('视嗛瀹藉害: $width', tag: 'PlayerProvider');
      }
      notifyListeners();
    });
    
    _mediaKitPlayer!.stream.height.listen((height) {
      if (height != null && height > 0) {
        ServiceLocator.log.d('视嗛高樺害: $height', tag: 'PlayerProvider');
      }
      notifyListeners();
    });
  }

  Timer? _debugInfoTimer;
  
  void _updateDebugInfo() {
    _debugInfoTimer?.cancel();
    
    _debugInfoTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_mediaKitPlayer == null) return;
      
      // 如果线程未开启或尚未解析到实际值，使用配置值兜底
      if (ServiceLocator.log.currentLevel == LogLevel.off &&
          (_hwdecMode == 'unknown' || _hwdecMode.isEmpty)) {
        _hwdecMode = _configuredHwdec;
      }
      
      // 更存柊视嗛宽哄
      final newWidth = _mediaKitPlayer!.state.width ?? 0;
      final newHeight = _mediaKitPlayer!.state.height ?? 0;
      
      // 检测视频尺寸变化（可能表示解码成功）
      if (newWidth != _videoWidth || newHeight != _videoHeight) {
        if (newWidth > 0 && newHeight > 0) {
          ServiceLocator.log.i('鉁?视嗛视ｇ爜鎴愬姛: ${newWidth}x${newHeight}', tag: 'PlayerProvider');
        } else if (_videoWidth > 0 && newWidth == 0) {
          ServiceLocator.log.w('鉁?视嗛视ｇ爜个㈠け', tag: 'PlayerProvider');
        }
      }
      
      _videoWidth = newWidth;
      _videoHeight = newHeight;
      
      // Windows 端直接使用 track 中的 fps 信息
      // media_kit (mpv) 的勬覆查撳抚率囧熀帧瓑浜庤棰戞簮甯х巼
      if (_state == PlayerState.playing && _fps > 0) {
        _currentFps = _fps;
      } else {
        _currentFps = 0;
      }
      
      // 预扮畻个嬭浇閫熷害 - 鍩轰簬视嗛分嗚鲸率囧拰甯х巼
      // media_kit 没有直接的下载速度 API，使用视频参数估算
      if (_state == PlayerState.playing && _videoWidth > 0 && _videoHeight > 0) {
        final pixels = _videoWidth * _videoHeight;
        final fps = _fps > 0 ? _fps : 25.0;
        // 预扮畻全紡锛氬儚绱犳暟 * 甯х巼 * 压嬬缉绯绘暟 (H.264/H.265 全稿瀷压嬬缉姣?
        // 1080p@30fps 绾?3-8 Mbps, 4K@30fps 绾?15-25 Mbps
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

  void _updateHwdecFromLog(String lowerMessage) {
    String? detected;

    // e.g. "Using hardware decoding (d3d11va-copy)"
    final hwdecMatch =
        RegExp(r'using hardware decoding\s*\(([^)]+)\)').firstMatch(lowerMessage);
    if (hwdecMatch != null) {
      detected = hwdecMatch.group(1);
    }

    // e.g. "hwdec=auto", "hwdec: d3d11va"
    final hwdecKeyMatch =
        RegExp(r'hwdec(?:-current)?\s*[:=]\s*([\w\-]+)')
            .firstMatch(lowerMessage);
    if (detected == null && hwdecKeyMatch != null) {
      detected = hwdecKeyMatch.group(1);
    }

    if (detected == null && lowerMessage.contains('software decoding')) {
      detected = 'no';
    }

    if (detected != null && detected.isNotEmpty && detected != _hwdecMode) {
      _hwdecMode = detected;
      notifyListeners();
    }
  }

  void _updateVoFromLog(String lowerMessage) {
    String? detected;

    // e.g. "VO: [gpu] 1920x1080"
    final voMatch = RegExp(r'vo:\s*\[?([a-z0-9_\-]+)\]?').firstMatch(lowerMessage);
    if (voMatch != null) {
      detected = voMatch.group(1);
    }

    // e.g. "Using video output driver: gpu"
    final driverMatch =
        RegExp(r'video output driver:\s*([a-z0-9_\-]+)').firstMatch(lowerMessage);
    if (detected == null && driverMatch != null) {
      detected = driverMatch.group(1);
    }

    if (detected != null && detected.isNotEmpty && detected != _vo) {
      _vo = detected;
      notifyListeners();
    }
  }

  String _formatHwdecInfo() {
    final configured = _configuredHwdec.trim();
    final actual = _hwdecMode.trim();
    if (configured.isEmpty || configured == 'unknown') {
      return actual == 'unknown' ? '' : actual;
    }
    if (actual.isEmpty || actual == 'unknown' || actual == configured) {
      return configured;
    }
    return '$configured -> $actual';
  }

  String _formatVoInfo() {
    final configured = _configuredVo.trim();
    final actual = _vo.trim();
    if (configured.isEmpty || configured == 'unknown') {
      return actual == 'unknown' ? '' : actual;
    }
    if (actual.isEmpty || actual == 'unknown' || actual == configured) {
      return configured;
    }
    return '$configured -> $actual';
  }

  bool _shouldTrySoftwareFallback(String error) {
    final lowerError = error.toLowerCase();
    if (!_allowSoftwareFallback) return false;
    return (lowerError.contains('codec') ||
            lowerError.contains('decoder') ||
            lowerError.contains('hwdec') ||
            lowerError.contains('mediacodec')) &&
        _retryCount < _maxRetries;
  }

  void _attemptSoftwareFallback() {
    if (!_allowSoftwareFallback) return;
    _retryCount++;
    final channelToPlay = _currentChannel;
    _initMediaKitPlayer(useSoftwareDecoding: true);
    if (channelToPlay != null) playChannel(channelToPlay);
  }

  // ============ Public API ============

  Future<void> playChannel(Channel channel, {bool preserveCurrentSource = false}) async {
    ServiceLocator.log.i('========== 开始嬫挱设鹃道==========', tag: 'PlayerProvider');
    ServiceLocator.log.i('棰戦亾: ${channel.name} (ID: ${channel.id})', tag: 'PlayerProvider');
    ServiceLocator.log.d('URL: ${channel.url}', tag: 'PlayerProvider');
    ServiceLocator.log.d('源数量 ${channel.sourceCount}', tag: 'PlayerProvider');
    final playStartTime = DateTime.now();
    
    _currentChannel = channel;
    _state = PlayerState.loading;
    _error = null;
    _lastErrorMessage = null; // 重置错误防抖
    _errorDisplayed = false; // 重置错误显示标记
    _retryCount = 0; // 重置重试计数
    _retryTimer?.cancel(); // 取消任何正在进行的重试
    _isAutoDetecting = false; // 取消任何正在进行的自动检测
    _noVideoFallbackAttempted = false;
    loadVolumeSettings(); // Apply volume boost settings
    notifyListeners();

    // 如果有多个源，先检测找到第一个可用的源
    if (channel.hasMultipleSources && !preserveCurrentSource) {
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
    } else if (channel.hasMultipleSources) {
      channel.currentSourceIndex =
          channel.currentSourceIndex.clamp(0, channel.sourceCount - 1);
      ServiceLocator.log.d('PlayerProvider: preserveCurrentSource=true, using source ${channel.currentSourceIndex + 1}/${channel.sourceCount}');
    }

    final playUrl = channel.currentUrl;
    ServiceLocator.log.d('准备播放URL: $playUrl', tag: 'PlayerProvider');

    try {
      final playerInitStartTime = DateTime.now();
      
      // Android TV 使用原生播放器，通过 MethodChannel 处理
      // 其他平台（包括 Android 手机）都使用 media_kit
      if (!_useNativePlayer) {
        // 解析真实播放地址（处理 302 重定向）
        ServiceLocator.log.i('>>> Start resolving redirect', tag: 'PlayerProvider');
        final redirectStartTime = DateTime.now();
        
        final realUrl = await ServiceLocator.redirectCache.resolveRealPlayUrl(playUrl);
        
        final redirectTime = DateTime.now().difference(redirectStartTime).inMilliseconds;
        ServiceLocator.log.i('>>> 302重定向解析完成，耗时: ${redirectTime}ms', tag: 'PlayerProvider');
        ServiceLocator.log.d('>>> 使用播放地址: $realUrl', tag: 'PlayerProvider');
        
        // 开始播放
        ServiceLocator.log.i('>>> Start initializing player', tag: 'PlayerProvider');
        final playStartTime = DateTime.now();
        
        await _mediaKitPlayer?.open(_createMedia(realUrl));
        
        final playTime = DateTime.now().difference(playStartTime).inMilliseconds;
        ServiceLocator.log.i('>>> 播放器初始化完成，耗时: ${playTime}ms', tag: 'PlayerProvider');
        
        _state = PlayerState.playing;
        notifyListeners();
        _scheduleNoVideoFallbackIfNeeded();
      }
      
      // 记录观看历史
      final channelId = channel.id;
      final playlistId = channel.playlistId;
      if (channelId != null && playlistId != null) {
        await ServiceLocator.watchHistory.addWatchHistory(channelId, playlistId);
      }
      
      final playerInitTime = DateTime.now().difference(playerInitStartTime).inMilliseconds;
      final totalTime = DateTime.now().difference(playStartTime).inMilliseconds;
      ServiceLocator.log.i('>>> 播放流程总耗时: ${totalTime}ms (播放器初始化: ${playerInitTime}ms)', tag: 'PlayerProvider');
      ServiceLocator.log.i('========== 频道播放总耗时: ${totalTime}ms ==========', tag: 'PlayerProvider');
    } catch (e) {
      ServiceLocator.log.e('播放频道失败', tag: 'PlayerProvider', error: e);
      _setError('Failed to play channel: $e');
      return;
    }
  }

  Future<void> reinitializePlayer({required String bufferStrength}) async {
    if (_useNativePlayer) return;
    final channelToPlay = _currentChannel;
    _state = PlayerState.loading;
    notifyListeners();
    _initMediaKitPlayer(bufferStrength: bufferStrength);
    if (channelToPlay != null) {
      await playChannel(channelToPlay);
    }
  }

  /// 查找第一个可用的源
  Future<int?> _findFirstAvailableSource(Channel channel) async {
    ServiceLocator.log.d('开始检测第${channel.sourceCount} 个源', tag: 'PlayerProvider');
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
        ServiceLocator.log.i('源${i + 1} 可用，响应时间: ${result.responseTime}ms，检测耗时: ${testTime}ms', tag: 'PlayerProvider');
        return i;
      } else {
        ServiceLocator.log.w('✗ 源 ${i + 1} 不可用: ${result.error}，检测耗时: ${testTime}ms', tag: 'PlayerProvider');
      }
    }
    
    ServiceLocator.log.e('所有${channel.sourceCount} 个源都不可用', tag: 'PlayerProvider');
    return null; // 所有源都不可用
  }

  Future<void> playUrl(String url, {String? name}) async {
    // Android TV 使用原生播放器，不支持此方法
    if (_useNativePlayer) {
      ServiceLocator.log.w('playUrl: Android TV 使用原生播放器，不支持此方法', tag: 'PlayerProvider');
      return;
    }
    
    final startTime = DateTime.now();
    _state = PlayerState.loading;
    _error = null;
    _lastErrorMessage = null; // 重置错误防抖
    _errorDisplayed = false; // 重置错误显示标记
    _noVideoFallbackAttempted = false;
    loadVolumeSettings(); // Apply volume boost settings
    notifyListeners();

    try {
      // 解析真实播放地址（处理 302 重定向）
      ServiceLocator.log.i('>>> Start resolving redirect', tag: 'PlayerProvider');
      final redirectStartTime = DateTime.now();
      
      final realUrl = await ServiceLocator.redirectCache.resolveRealPlayUrl(url);
      
      final redirectTime = DateTime.now().difference(redirectStartTime).inMilliseconds;
      ServiceLocator.log.i('>>> 302重定向解析完成，耗时: ${redirectTime}ms', tag: 'PlayerProvider');
        ServiceLocator.log.d('>>> 使用播放地址: $realUrl', tag: 'PlayerProvider');
      
      // 开始播放
      ServiceLocator.log.i('>>> Start initializing player', tag: 'PlayerProvider');
      final playStartTime = DateTime.now();
      
      await _mediaKitPlayer?.open(_createMedia(realUrl));
      
      final playTime = DateTime.now().difference(playStartTime).inMilliseconds;
      final totalTime = DateTime.now().difference(startTime).inMilliseconds;
        ServiceLocator.log.i('>>> 播放器初始化完成，耗时: ${playTime}ms', tag: 'PlayerProvider');
        ServiceLocator.log.i('>>> 播放流程总耗时: ${totalTime}ms', tag: 'PlayerProvider');
      
      _state = PlayerState.playing;
      _scheduleNoVideoFallbackIfNeeded();
    } catch (e) {
      final totalTime = DateTime.now().difference(startTime).inMilliseconds;
      ServiceLocator.log.e('>>> 播放失败 (${totalTime}ms): $e', tag: 'PlayerProvider');
      _setError('Failed to play: $e');
      return;
    }
    notifyListeners();
  }

  void togglePlayPause() {
    if (_useNativePlayer) return; // TV 端由原生播放器处理
    _mediaKitPlayer?.playOrPause();
  }

  void pause() {
    if (_useNativePlayer) return; // TV 端由原生播放器处理
    _mediaKitPlayer?.pause();
  }

  void play() {
    if (_useNativePlayer) return; // TV 端由原生播放器处理
    _mediaKitPlayer?.play();
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
    
    if (!_useNativePlayer) {
      _mediaKitPlayer?.stop();
    }
    _state = PlayerState.idle;
    _currentChannel = null;
    
    if (!silent) {
      notifyListeners();
    }
  }

  void seek(Duration position) {
    if (_useNativePlayer) return; // TV 端由原生播放器处理
    _mediaKitPlayer?.seek(position);
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

  double _volumeBeforeMute = 1.0; // 淇濆瓨闈欓煶鍓嶇殑音抽噺

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
    // 音量增强独立于音量标准化，最终加载
    _volumeBoostDb = prefs.getInt('volume_boost') ?? 0;
    _applyVolume();
  }

  /// Calculate and apply the effective volume with boost
  void _applyVolume() {
    if (_useNativePlayer) return; // TV 端由原生播放器处理
    
    if (_isMuted) {
      _mediaKitPlayer?.setVolume(0);
      return;
    }

    // Convert dB to linear multiplier: multiplier = 10^(dB/20)
    final multiplier = math.pow(10, _volumeBoostDb / 20.0);
    final effectiveVolume = (_volume * multiplier).clamp(0.0, 2.0); // Allow up to 2x volume

    // media_kit uses 0-100 scale, but can go higher for boost
    _mediaKitPlayer?.setVolume(effectiveVolume * 100);
  }

  void setPlaybackSpeed(double speed) {
    if (_useNativePlayer) return; // TV 端由原生播放器处理
    _playbackSpeed = speed;
    _mediaKitPlayer?.setRate(speed);
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
    
    // 取消任何正在进行的自动检测
    _isAutoDetecting = false;
    _retryTimer?.cancel();
    
    final newIndex = (_currentChannel!.currentSourceIndex + 1) % _currentChannel!.sourceCount;
    _currentChannel!.currentSourceIndex = newIndex;
    
    ServiceLocator.log.d('PlayerProvider: 手动切换到源 ${newIndex + 1}/${_currentChannel!.sourceCount}');
    
    // 只有在非自动切换时才重置（手动切换时重置）
    if (!_isAutoSwitching) {
      _retryCount = 0;
      ServiceLocator.log.d('PlayerProvider: Manual source switch, reset retry state');
    }
    
    // Play the new source
    _playCurrentSource();
  }

  /// Switch to previous source for current channel (if has multiple sources)
  void switchToPreviousSource() {
    if (_currentChannel == null || !_currentChannel!.hasMultipleSources) return;
    
    // 取消任何正在进行的自动检测
    _isAutoDetecting = false;
    _retryTimer?.cancel();
    
    final newIndex = (_currentChannel!.currentSourceIndex - 1 + _currentChannel!.sourceCount) % _currentChannel!.sourceCount;
    _currentChannel!.currentSourceIndex = newIndex;
    
    ServiceLocator.log.d('PlayerProvider: 手动切换到源 ${newIndex + 1}/${_currentChannel!.sourceCount}');
    
    // 只有在非自动切换时才重置（手动切换时重置）
    if (!_isAutoSwitching) {
      _retryCount = 0;
      ServiceLocator.log.d('PlayerProvider: Manual source switch, reset retry state');
    }
    
    // Play the new source
    _playCurrentSource();
  }

  /// Play the current source of the current channel
  Future<void> _playCurrentSource() async {
    if (_currentChannel == null) return;
    
    // 记录初始配置
    ServiceLocator.log.d('开始嬫挱设鹃道源', tag: 'PlayerProvider');
    ServiceLocator.log.d('频道: ${_currentChannel!.name}, 源索引 ${_currentChannel!.currentSourceIndex}/${_currentChannel!.sourceCount}', tag: 'PlayerProvider');
    
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
    final startTime = DateTime.now();
    
    _state = PlayerState.loading;
    _error = null;
    _lastErrorMessage = null;
    _errorDisplayed = false;
    _noVideoFallbackAttempted = false;
    notifyListeners();

    try {
      if (!_useNativePlayer) {
        // 解析真实播放地址（处理 302 重定向）
        ServiceLocator.log.i('>>> Source switch: start resolving redirect', tag: 'PlayerProvider');
        final redirectStartTime = DateTime.now();
        
        final realUrl = await ServiceLocator.redirectCache.resolveRealPlayUrl(url);
        
        final redirectTime = DateTime.now().difference(redirectStartTime).inMilliseconds;
        ServiceLocator.log.i('>>> 切换源: 302重定向解析完成，耗时: ${redirectTime}ms', tag: 'PlayerProvider');
        ServiceLocator.log.d('>>> 切换源: 使用播放地址: $realUrl', tag: 'PlayerProvider');
        
        final playStartTime = DateTime.now();
        await _mediaKitPlayer?.open(_createMedia(realUrl));
        
        final playTime = DateTime.now().difference(playStartTime).inMilliseconds;
        final totalTime = DateTime.now().difference(startTime).inMilliseconds;
        ServiceLocator.log.i('>>> 切换源: 播放器初始化完成，耗时: ${playTime}ms', tag: 'PlayerProvider');
        ServiceLocator.log.i('>>> 切换源: 总昏€楁时: ${totalTime}ms', tag: 'PlayerProvider');
        
        _state = PlayerState.playing;
        _scheduleNoVideoFallbackIfNeeded();
      }
      ServiceLocator.log.i('播放成功', tag: 'PlayerProvider');
    } catch (e) {
      final totalTime = DateTime.now().difference(startTime).inMilliseconds;
      ServiceLocator.log.e('播放失败 (${totalTime}ms)', tag: 'PlayerProvider', error: e);
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
    _isDisposed = true;
    _debugInfoTimer?.cancel();
    _retryTimer?.cancel();
    _mediaKitPlayer?.dispose();
    super.dispose();
  }

  void _scheduleNoVideoFallbackIfNeeded() {
    if (_useNativePlayer) return;
    if (!Platform.isWindows) return;
    if (_isSoftwareDecoding) return;
    if (!_allowSoftwareFallback) return;
    if (_noVideoFallbackAttempted) return;

    _noVideoFallbackAttempted = true;
    Future.delayed(const Duration(seconds: 3), () {
      if (_isDisposed) return;
      // 若已播放但仍无画面（宽度为0），尝试解码回调
      if (_state == PlayerState.playing && _videoWidth == 0 && _videoHeight == 0) {
        ServiceLocator.log.w('PlayerProvider: 音抽帧変絾时犵敾闈紝宽濊瘯轨В鍥為€€', tag: 'PlayerProvider');
        _attemptSoftwareFallback();
      }
    });
  }
}

