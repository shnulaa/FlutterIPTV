import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:video_player/video_player.dart';
import 'dart:io' show Platform;
import 'dart:async';
import 'dart:math' as math;

import '../../../core/models/channel.dart';
import '../../../core/platform/platform_detector.dart';
import '../../../core/services/service_locator.dart';

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
  static const int _maxRetries = 3;
  Timer? _retryTimer;

  // On Android TV, we use native player via Activity, so don't init any Flutter player
  // On Android phone/tablet, use ExoPlayer
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
    
    // 尝试自动重试
    if (_retryCount < _maxRetries && _currentChannel != null) {
      _retryCount++;
      debugPrint('PlayerProvider: 播放错误，尝试重试 ($_retryCount/$_maxRetries): $error');
      _retryTimer?.cancel();
      _retryTimer = Timer(const Duration(seconds: 2), () {
        if (_currentChannel != null) {
          _retryPlayback();
        }
      });
      return;
    }
    
    // 超过重试次数，显示错误
    _state = PlayerState.error;
    _error = error;
    notifyListeners();
  }
  
  /// 重试播放当前频道
  Future<void> _retryPlayback() async {
    if (_currentChannel == null) return;
    
    debugPrint('PlayerProvider: 正在重试播放 ${_currentChannel!.name}');
    _state = PlayerState.loading;
    _error = null;
    notifyListeners();
    
    try {
      if (_useExoPlayer) {
        await _initExoPlayer(_currentChannel!.url);
      } else {
        await _mediaKitPlayer?.open(Media(_currentChannel!.url));
        _state = PlayerState.playing;
      }
    } catch (e) {
      debugPrint('PlayerProvider: 重试失败: $e');
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

  double get currentFps => _currentFps;

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
      configuration: PlayerConfiguration(bufferSize: bufferSize),
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
        _retryCount = 0;
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
      
      // Windows 端直接使用 track 中的 fps 信息
      // media_kit (mpv) 的渲染帧率基本等于视频源帧率
      if (_state == PlayerState.playing && _fps > 0) {
        _currentFps = _fps;
      } else {
        _currentFps = 0;
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

  Future<void> _initExoPlayer(String url) async {
    await _disposeExoPlayer();

    // 增加 key 强制 VideoPlayer widget 重建
    _exoPlayerKey++;

    // 先通知 UI exoPlayer 已被释放
    notifyListeners();

    _exoPlayer = VideoPlayerController.networkUrl(
      Uri.parse(url),
      httpHeaders: const {'Connection': 'keep-alive'},
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false, allowBackgroundPlayback: false),
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
    _currentChannel = channel;
    _state = PlayerState.loading;
    _error = null;
    _lastErrorMessage = null; // 重置错误防抖
    _errorDisplayed = false; // 重置错误显示标记
    loadVolumeSettings(); // Apply volume boost settings
    notifyListeners();

    try {
      if (_useExoPlayer) {
        await _initExoPlayer(channel.url);
      } else {
        await _mediaKitPlayer?.open(Media(channel.url));
        _state = PlayerState.playing;
      }
    } catch (e) {
      _setError('Failed to play channel: $e');
      return;
    }
    notifyListeners();
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

  Future<void> stop() async {
    if (_useExoPlayer) {
      await _disposeExoPlayer();
    } else {
      _mediaKitPlayer?.stop();
    }
    _state = PlayerState.idle;
    _currentChannel = null;
    notifyListeners();
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

  void toggleMute() {
    _isMuted = !_isMuted;
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
