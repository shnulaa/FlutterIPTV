import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';

/// Windows 迷你播放器模式控制
class WindowsPipChannel {
  static bool _isInMiniMode = false;
  static bool _isPinned = false;
  static Size? _originalSize;
  static Offset? _originalPosition;
  static bool _wasMaximized = false;
  static bool _wasFullScreen = false;
  
  // 迷你模式的默认尺寸
  static const double _miniWidth = 400;
  static const double _miniHeight = 225; // 16:9 比例
  static const double _margin = 20;

  // 状态变化通知器
  static final ValueNotifier<bool> pipModeNotifier = ValueNotifier<bool>(false);

  /// 是否在迷你模式
  static bool get isInPipMode => _isInMiniMode;

  /// 是否置顶
  static bool get isPinned => _isPinned;

  /// 是否支持（仅 Windows 桌面）
  static bool get isSupported => !kIsWeb && Platform.isWindows;

  /// 进入迷你模式
  static Future<bool> enterPipMode() async {
    if (!isSupported || _isInMiniMode) return false;

    try {
      // 保存原始窗口状态
      _wasFullScreen = await windowManager.isFullScreen();
      _wasMaximized = await windowManager.isMaximized();
      
      // 如果是全屏，先退出全屏
      if (_wasFullScreen) {
        await windowManager.setFullScreen(false);
        await Future.delayed(const Duration(milliseconds: 200));
      }
      
      // 如果是最大化，先取消最大化
      if (_wasMaximized) {
        await windowManager.unmaximize();
        await Future.delayed(const Duration(milliseconds: 200));
      }
      
      _originalSize = await windowManager.getSize();
      _originalPosition = await windowManager.getPosition();

      // 获取主屏幕尺寸
      final primaryDisplay = await screenRetriever.getPrimaryDisplay();
      final screenWidth = primaryDisplay.size.width;
      final screenHeight = primaryDisplay.size.height;
      
      debugPrint('WindowsPipChannel: 屏幕尺寸 - $screenWidth x $screenHeight');
      
      // 计算右下角位置，紧贴屏幕底部（覆盖任务栏）
      final x = screenWidth - _miniWidth - _margin;
      final y = screenHeight - _miniHeight - _margin;

      debugPrint('WindowsPipChannel: 目标位置 - ($x, $y)');

      // 隐藏标题栏
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      
      // 设置窗口属性
      await windowManager.setMinimumSize(const Size(320, 180));
      await windowManager.setSize(const Size(_miniWidth, _miniHeight));
      await Future.delayed(const Duration(milliseconds: 100));
      
      // 移动到右下角
      await windowManager.setPosition(Offset(x, y));
      await Future.delayed(const Duration(milliseconds: 100));
      
      // 置顶 + 跳过任务栏（这样 Win+D 不会最小化，且任务栏不显示图标）
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setSkipTaskbar(true);
      
      _isInMiniMode = true;
      _isPinned = true;
      pipModeNotifier.value = true; // 通知状态变化
      
      debugPrint('WindowsPipChannel: 进入迷你模式成功');
      return true;
    } catch (e) {
      debugPrint('WindowsPipChannel: enterPipMode error: $e');
      return false;
    }
  }

  /// 退出迷你模式
  static Future<bool> exitPipMode() async {
    if (!isSupported || !_isInMiniMode) return false;

    try {
      // 取消置顶和跳过任务栏
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setSkipTaskbar(false);
      
      // 恢复标题栏
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      
      // 恢复最小尺寸限制
      await windowManager.setMinimumSize(const Size(800, 600));
      
      // 恢复原始大小和位置
      if (_originalSize != null) {
        await windowManager.setSize(_originalSize!);
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      if (_originalPosition != null) {
        await windowManager.setPosition(_originalPosition!);
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      // 恢复最大化状态
      if (_wasMaximized) {
        await Future.delayed(const Duration(milliseconds: 100));
        await windowManager.maximize();
      }
      
      // 恢复全屏状态
      if (_wasFullScreen) {
        await Future.delayed(const Duration(milliseconds: 100));
        await windowManager.setFullScreen(true);
      }

      _isInMiniMode = false;
      _isPinned = false;
      pipModeNotifier.value = false; // 通知状态变化
      
      debugPrint('WindowsPipChannel: 退出迷你模式');
      return true;
    } catch (e) {
      debugPrint('WindowsPipChannel: exitPipMode error: $e');
      return false;
    }
  }

  /// 切换迷你模式
  static Future<bool> togglePipMode() async {
    if (_isInMiniMode) {
      return exitPipMode();
    } else {
      return enterPipMode();
    }
  }

  /// 切换置顶状态
  static Future<bool> togglePin() async {
    if (!isSupported) return false;

    try {
      _isPinned = !_isPinned;
      await windowManager.setAlwaysOnTop(_isPinned);
      debugPrint('WindowsPipChannel: 置顶状态: $_isPinned');
      return true;
    } catch (e) {
      debugPrint('WindowsPipChannel: togglePin error: $e');
      return false;
    }
  }
  
  /// 重置状态（用于应用退出时）
  static void reset() {
    _isInMiniMode = false;
    _isPinned = false;
    _originalSize = null;
    _originalPosition = null;
    _wasMaximized = false;
    _wasFullScreen = false;
  }
}
