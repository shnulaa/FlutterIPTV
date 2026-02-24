import 'dart:io';
import 'package:restart_app/restart_app.dart';
import '../services/service_locator.dart';

/// 应用重启助手
/// 
/// 提供跨平台的应用重启功能
class AppRestartHelper {
  /// 重启应用
  /// 
  /// - Windows: 启动新进程后退出当前进程
  /// - Android/iOS: 使用 restart_app 包
  /// - 其他平台: 降级使用 exit(0)
  static Future<void> restartApp() async {
    ServiceLocator.log.i('开始重启应用', tag: 'AppRestartHelper');
    
    if (Platform.isWindows) {
      await _restartOnWindows();
    } else if (Platform.isAndroid || Platform.isIOS) {
      await _restartOnMobile();
    } else {
      ServiceLocator.log.w('不支持的平台，使用 exit(0)', tag: 'AppRestartHelper');
      exit(0);
    }
  }
  
  /// Windows 平台重启
  static Future<void> _restartOnWindows() async {
    try {
      ServiceLocator.log.i('Windows 平台重启', tag: 'AppRestartHelper');
      
      // 获取当前可执行文件路径
      final executablePath = Platform.resolvedExecutable;
      ServiceLocator.log.d('可执行文件路径: $executablePath', tag: 'AppRestartHelper');
      
      // 启动新进程
      // 使用 detached 模式，让新进程独立运行
      await Process.start(
        executablePath,
        [],
        mode: ProcessStartMode.detached,
      );
      
      ServiceLocator.log.i('新进程已启动，准备退出当前进程', tag: 'AppRestartHelper');
      
      // 延迟一下，确保新进程启动
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 退出当前进程
      exit(0);
    } catch (e, stackTrace) {
      ServiceLocator.log.e('Windows 重启失败，降级使用 exit(0)', tag: 'AppRestartHelper', error: e, stackTrace: stackTrace);
      exit(0);
    }
  }
  
  /// 移动平台重启
  static Future<void> _restartOnMobile() async {
    try {
      ServiceLocator.log.i('移动平台重启，使用 restart_app', tag: 'AppRestartHelper');
      await Restart.restartApp();
    } catch (e, stackTrace) {
      ServiceLocator.log.e('restart_app 失败，降级使用 exit(0)', tag: 'AppRestartHelper', error: e, stackTrace: stackTrace);
      exit(0);
    }
  }
  
  /// 检查是否支持自动重启
  static bool get supportsAutoRestart {
    return Platform.isWindows || Platform.isAndroid || Platform.isIOS;
  }
  
  /// 获取重启提示文本
  static String getRestartMessage() {
    if (Platform.isWindows) {
      return '应用将自动重启以应用更改...';
    } else if (Platform.isAndroid || Platform.isIOS) {
      return '应用将自动重启以应用更改...';
    } else {
      return '应用将关闭，请手动重新打开应用以应用更改。';
    }
  }
  
  /// 获取重启按钮文本
  static String getRestartButtonText() {
    if (supportsAutoRestart) {
      return '立即重启';
    } else {
      return '关闭应用';
    }
  }
}
