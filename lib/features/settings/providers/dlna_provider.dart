import 'package:flutter/foundation.dart';
import '../../../core/services/dlna_service.dart';

/// DLNA 服务状态管理
class DlnaProvider extends ChangeNotifier {
  final DlnaService _dlnaService = DlnaService();

  bool _isEnabled = false;
  bool _isRunning = false;
  bool _isActiveSession = false; // 是否有活跃的 DLNA 投屏会话
  String? _pendingUrl;
  String? _pendingTitle;

  bool get isEnabled => _isEnabled;
  bool get isRunning => _isRunning;
  bool get isActiveSession => _isActiveSession; // 是否正在 DLNA 投屏
  String get deviceName => _dlnaService.deviceName;
  String? get pendingUrl => _pendingUrl;
  String? get pendingTitle => _pendingTitle;

  // 播放回调（由外部设置）
  Function(String url, String? title)? onPlayRequested;
  Function()? onPauseRequested;
  Function()? onStopRequested;
  Function(Duration position)? onSeekRequested;
  Function(int volume)? onVolumeRequested;

  DlnaProvider() {
    _setupCallbacks();
  }

  void _setupCallbacks() {
    _dlnaService.onPlayUrl = (url, title) {
      debugPrint('DLNA Provider: 收到播放请求 - $url');
      _pendingUrl = url;
      _pendingTitle = title;
      _isActiveSession = true; // 开始 DLNA 会话
      notifyListeners();
      
      // 调用外部回调
      onPlayRequested?.call(url, title);
    };

    _dlnaService.onPause = () {
      debugPrint('DLNA Provider: 收到暂停请求');
      onPauseRequested?.call();
    };

    _dlnaService.onStop = () {
      debugPrint('DLNA Provider: 收到停止请求');
      _pendingUrl = null;
      _pendingTitle = null;
      _isActiveSession = false; // 结束 DLNA 会话
      notifyListeners();
      onStopRequested?.call();
    };

    _dlnaService.onSetVolume = (volume) {
      debugPrint('DLNA Provider: 设置音量 - $volume');
      onVolumeRequested?.call(volume);
    };

    _dlnaService.onSeek = (position) {
      debugPrint('DLNA Provider: 跳转到 - $position');
      onSeekRequested?.call(position);
    };
  }

  /// 启用/禁用 DLNA 服务
  Future<bool> setEnabled(bool enabled) async {
    if (enabled == _isEnabled) return true;

    if (enabled) {
      final success = await _dlnaService.start();
      if (success) {
        _isEnabled = true;
        _isRunning = true;
        notifyListeners();
        return true;
      }
      return false;
    } else {
      await _dlnaService.stop();
      _isEnabled = false;
      _isRunning = false;
      _pendingUrl = null;
      _pendingTitle = null;
      notifyListeners();
      return true;
    }
  }

  /// 更新播放状态（供 PlayerProvider 调用）
  void updatePlayState({
    String? state,
    Duration? position,
    Duration? duration,
  }) {
    _dlnaService.updatePlayState(
      state: state,
      position: position,
      duration: duration,
    );
  }
  
  /// 通知 DLNA 服务播放已停止（主动退出时调用）
  void notifyPlaybackStopped() {
    _dlnaService.updatePlayState(state: 'STOPPED');
    _pendingUrl = null;
    _pendingTitle = null;
  }
  
  /// 同步播放器状态到 DLNA（定期调用）
  void syncPlayerState({
    required bool isPlaying,
    required bool isPaused,
    required Duration position,
    required Duration duration,
  }) {
    String state;
    if (isPlaying) {
      state = 'PLAYING';
    } else if (isPaused) {
      state = 'PAUSED_PLAYBACK';
    } else {
      state = 'STOPPED';
    }
    
    _dlnaService.updatePlayState(
      state: state,
      position: position,
      duration: duration,
    );
  }

  /// 清除待播放内容
  void clearPending() {
    _pendingUrl = null;
    _pendingTitle = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _dlnaService.stop();
    super.dispose();
  }
}
