import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/channel.dart';
import 'channel_test_service.dart';

/// 后台测试状态
enum BackgroundTestStatus {
  idle,
  running,
  completed,
  cancelled,
}

/// 后台测试进度回调
typedef BackgroundTestCallback = void Function(BackgroundTestProgress progress);

/// 后台测试进度
class BackgroundTestProgress {
  final int total;
  final int completed;
  final int available;
  final int unavailable;
  final String? currentChannelName;
  final BackgroundTestStatus status;
  final List<ChannelTestResult> results;

  BackgroundTestProgress({
    required this.total,
    required this.completed,
    required this.available,
    required this.unavailable,
    this.currentChannelName,
    required this.status,
    required this.results,
  });

  double get progress => total > 0 ? completed / total : 0;
  bool get isComplete => status == BackgroundTestStatus.completed;
  bool get isRunning => status == BackgroundTestStatus.running;
}

/// 后台频道测试服务（单例）
class BackgroundTestService {
  static final BackgroundTestService _instance = BackgroundTestService._internal();
  factory BackgroundTestService() => _instance;
  BackgroundTestService._internal();

  final ChannelTestService _testService = ChannelTestService();
  StreamSubscription<ChannelTestProgress>? _subscription;
  
  BackgroundTestStatus _status = BackgroundTestStatus.idle;
  int _total = 0;
  int _completed = 0;
  int _available = 0;
  int _unavailable = 0;
  String? _currentChannelName;
  List<ChannelTestResult> _results = [];
  
  final List<BackgroundTestCallback> _listeners = [];

  // Getters
  BackgroundTestStatus get status => _status;
  bool get isRunning => _status == BackgroundTestStatus.running;
  bool get hasResults => _results.isNotEmpty;
  
  BackgroundTestProgress get currentProgress => BackgroundTestProgress(
    total: _total,
    completed: _completed,
    available: _available,
    unavailable: _unavailable,
    currentChannelName: _currentChannelName,
    status: _status,
    results: List.unmodifiable(_results),
  );

  /// 添加监听器
  void addListener(BackgroundTestCallback callback) {
    _listeners.add(callback);
  }

  /// 移除监听器
  void removeListener(BackgroundTestCallback callback) {
    _listeners.remove(callback);
  }

  /// 通知所有监听器
  void _notifyListeners() {
    final progress = currentProgress;
    for (final listener in _listeners) {
      listener(progress);
    }
  }

  /// 开始后台测试
  void startTest(List<Channel> channels) {
    if (_status == BackgroundTestStatus.running) {
      debugPrint('后台测试已在运行中');
      return;
    }

    _status = BackgroundTestStatus.running;
    _total = channels.length;
    _completed = 0;
    _available = 0;
    _unavailable = 0;
    _currentChannelName = null;
    _results = [];
    _notifyListeners();

    _subscription = _testService.testChannels(channels).listen(
      (progress) {
        _completed = progress.completed;
        _available = progress.available;
        _unavailable = progress.unavailable;
        _currentChannelName = progress.currentChannel.name;
        _results = progress.results;
        
        if (progress.isComplete) {
          _status = BackgroundTestStatus.completed;
        }
        
        _notifyListeners();
      },
      onError: (e) {
        debugPrint('后台测试出错: $e');
        _status = BackgroundTestStatus.completed;
        _notifyListeners();
      },
      onDone: () {
        _status = BackgroundTestStatus.completed;
        _notifyListeners();
      },
    );

    debugPrint('后台测试已启动，共 ${channels.length} 个频道');
  }

  /// 停止后台测试
  void stopTest() {
    _subscription?.cancel();
    _subscription = null;
    _status = BackgroundTestStatus.cancelled;
    _notifyListeners();
    debugPrint('后台测试已停止');
  }

  /// 清除结果
  void clearResults() {
    _status = BackgroundTestStatus.idle;
    _total = 0;
    _completed = 0;
    _available = 0;
    _unavailable = 0;
    _currentChannelName = null;
    _results = [];
    _notifyListeners();
  }

  /// 获取失效频道ID列表
  List<int> getUnavailableChannelIds() {
    return _results
        .where((r) => !r.isAvailable)
        .map((r) => r.channel.id)
        .whereType<int>()
        .toList();
  }
}
