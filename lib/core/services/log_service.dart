import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'service_locator.dart';

/// 日志级别
enum LogLevel {
  debug,    // 调试模式：记录所有日志
  release,  // 发布模式：只记录警告和错误
  off,      // 关闭日志
}

/// 日志服务 - 统一管理应用日志
class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  Logger? _logger;
  LogLevel _currentLevel = LogLevel.release;
  String? _logFilePath;
  bool _initialized = false;
  
  // 批量写入缓冲区
  final List<String> _logBuffer = [];
  static const int _bufferSize = 10; // 缓冲区大小（减小到10条，更快写入）
  DateTime? _lastFlushTime; // 上次刷新时间
  static const Duration _autoFlushInterval = Duration(seconds: 2); // 自动刷新间隔（减小到2秒）

  /// 初始化日志服务
  Future<void> init({SharedPreferences? prefs}) async {
    if (_initialized) return;

    try {
      // 从设置中读取日志级别
      final preferences = prefs ?? ServiceLocator.prefs;
      
      String levelString = preferences.getString('log_level') ?? 'off';
      debugPrint('LogService: 从 SharedPreferences 读取日志级别: $levelString');
      
      _currentLevel = _parseLogLevel(levelString);
      debugPrint('LogService: 解析后的日志级别: ${_currentLevel.name}');

      if (_currentLevel == LogLevel.off) {
        debugPrint('LogService: 日志已关闭');
        _initialized = true;
        return;
      }

      // 获取日志文件路径
      _logFilePath = await _getLogFilePath();
      
      if (_logFilePath != null) {
        // 创建日志文件引用
        _file = File(_logFilePath!);
        
        // 创建日志目录
        final logDir = Directory(path.dirname(_logFilePath!));
        if (!await logDir.exists()) {
          await logDir.create(recursive: true);
        }

        // 清理旧日志（保留最近7天）
        await _cleanOldLogs(logDir);

        // 创建 Logger 实例（使用批量输出）
        // 注意：Logger 的 level 参数设置为 all，让我们的 Filter 来控制
        _logger = Logger(
          filter: _LogFilter(_currentLevel),
          printer: _LogPrinter(),
          output: _BatchFileOutput(this),
          level: Level.all, // 允许所有级别，由 Filter 控制
        );

        debugPrint('LogService: 初始化成功，日志文件: $_logFilePath');
        debugPrint('LogService: 日志级别: ${_currentLevel.name}');
        
        // 写入启动日志
        _logger?.i('========================================');
        _logger?.i('应用启动 - ${DateTime.now()}');
        _logger?.i('日志级别: ${_currentLevel.name}');
        _logger?.i('========================================');
        
        // 立即刷新启动日志
        await flush();
      }

      _initialized = true;
    } catch (e) {
      debugPrint('LogService: 初始化失败 - $e');
    }
  }

  /// 获取日志文件路径
  Future<String?> _getLogFilePath() async {
    try {
      Directory? logDir;

      if (Platform.isWindows) {
        // Windows: 使用应用安装目录下的 logs 文件夹
        final exePath = Platform.resolvedExecutable;
        final exeDir = path.dirname(exePath);
        logDir = Directory(path.join(exeDir, 'logs'));
      } else if (Platform.isAndroid) {
        // Android: 使用应用的外部存储目录
        final appDir = await getExternalStorageDirectory();
        if (appDir != null) {
          logDir = Directory(path.join(appDir.path, 'logs'));
        }
      } else {
        // 其他平台：使用应用文档目录
        final appDir = await getApplicationDocumentsDirectory();
        logDir = Directory(path.join(appDir.path, 'logs'));
      }

      if (logDir == null) return null;

      // 创建日志目录
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }

      // 日志文件名：lotus_iptv_YYYYMMDD.log
      final dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
      return path.join(logDir.path, 'lotus_iptv_$dateStr.log');
    } catch (e) {
      debugPrint('LogService: 获取日志路径失败 - $e');
      return null;
    }
  }

  /// 清理旧日志（保留最近7天）
  Future<void> _cleanOldLogs(Directory logDir) async {
    try {
      final now = DateTime.now();
      final files = await logDir.list().toList();

      for (final file in files) {
        if (file is File && file.path.endsWith('.log')) {
          final stat = await file.stat();
          final age = now.difference(stat.modified).inDays;
          
          if (age > 7) {
            await file.delete();
            debugPrint('LogService: 删除旧日志 - ${path.basename(file.path)}');
          }
        }
      }
    } catch (e) {
      debugPrint('LogService: 清理旧日志失败 - $e');
    }
  }

  /// 解析日志级别
  LogLevel _parseLogLevel(String level) {
    switch (level.toLowerCase()) {
      case 'debug':
        return LogLevel.debug;
      case 'release':
        return LogLevel.release;
      case 'off':
        return LogLevel.off;
      default:
        return LogLevel.release;
    }
  }

  /// 设置日志级别
  Future<void> setLogLevel(LogLevel level) async {
    debugPrint('LogService: 开始设置日志级别为 ${level.name}');
    
    // 先刷新当前缓冲区
    await flush();
    
    _currentLevel = level;
    
    // 保存到设置
    try {
      final prefs = ServiceLocator.prefs;
      await prefs.setString('log_level', level.name);
      debugPrint('LogService: 日志级别已保存到 SharedPreferences');
    } catch (e) {
      debugPrint('LogService: 保存日志级别失败 - $e');
    }

    // 重新初始化
    _initialized = false;
    _logger = null;
    _file = null;
    debugPrint('LogService: 开始重新初始化...');
    await init();
    debugPrint('LogService: 重新初始化完成，_logger = $_logger, _file = $_file');
  }

  /// 获取当前日志级别
  LogLevel get currentLevel => _currentLevel;

  /// 获取日志文件路径
  String? get logFilePath => _logFilePath;

  /// Debug 日志
  void d(String message, {String? tag, dynamic error, StackTrace? stackTrace}) {
    if (_currentLevel == LogLevel.off) return; // 只有 off 时才不记录
    if (_currentLevel != LogLevel.debug) return; // 只有 debug 级别才记录 debug 日志
    
    if (_logger == null) {
      debugPrint('LogService: Logger 未初始化，无法写入日志');
      return;
    }
    
    final msg = tag != null ? '[$tag] $message' : message;
    _logger?.d(msg, error: error, stackTrace: stackTrace);
    // 在调试模式下，只在非批量导入时输出到控制台
    // if (kDebugMode) debugPrint('DEBUG: $msg');
  }

  /// Info 日志
  void i(String message, {String? tag, dynamic error, StackTrace? stackTrace}) {
    if (_currentLevel == LogLevel.off) return;
    
    if (_logger == null) {
      debugPrint('LogService: Logger 未初始化 (Info)');
      return;
    }
    
    final msg = tag != null ? '[$tag] $message' : message;
    _logger?.i(msg, error: error, stackTrace: stackTrace);
    if (kDebugMode) debugPrint('INFO: $msg');
  }

  /// Warning 日志
  void w(String message, {String? tag, dynamic error, StackTrace? stackTrace}) {
    if (_currentLevel == LogLevel.off) return;
    final msg = tag != null ? '[$tag] $message' : message;
    _logger?.w(msg, error: error, stackTrace: stackTrace);
    if (kDebugMode) debugPrint('WARN: $msg');
  }

  /// Error 日志
  void e(String message, {String? tag, dynamic error, StackTrace? stackTrace}) {
    if (_currentLevel == LogLevel.off) return;
    final msg = tag != null ? '[$tag] $message' : message;
    _logger?.e(msg, error: error, stackTrace: stackTrace);
    if (kDebugMode) debugPrint('ERROR: $msg');
  }
  
  /// 刷新日志缓冲区（强制写入所有缓存的日志）
  Future<void> flush() async {
    if (_logBuffer.isEmpty) return;
    
    try {
      if (_file != null) {
        await _file!.writeAsString(
          _logBuffer.join('\n') + '\n',
          mode: FileMode.append,
          flush: true,
        );
        _logBuffer.clear();
        _lastFlushTime = DateTime.now();
      }
    } catch (e) {
      debugPrint('LogService: 刷新日志缓冲区失败 - $e');
    }
  }
  
  /// 检查是否需要自动刷新
  void _checkAutoFlush() {
    if (_lastFlushTime == null) {
      _lastFlushTime = DateTime.now();
      return;
    }
    
    final now = DateTime.now();
    if (now.difference(_lastFlushTime!) >= _autoFlushInterval) {
      flush();
    }
  }
  
  File? _file;

  /// 获取日志目录
  Future<Directory?> getLogDirectory() async {
    if (_logFilePath == null) return null;
    return Directory(path.dirname(_logFilePath!));
  }

  /// 获取所有日志文件
  Future<List<File>> getLogFiles() async {
    final logDir = await getLogDirectory();
    if (logDir == null || !await logDir.exists()) return [];

    final files = await logDir.list().toList();
    return files
        .whereType<File>()
        .where((f) => f.path.endsWith('.log'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path)); // 按日期倒序
  }

  /// 导出日志文件（用于分享给开发者）
  Future<String?> exportLogs() async {
    try {
      final logFiles = await getLogFiles();
      if (logFiles.isEmpty) return null;

      // 合并所有日志文件
      final buffer = StringBuffer();
      buffer.writeln('========================================');
      buffer.writeln('Lotus IPTV 日志导出');
      buffer.writeln('导出时间: ${DateTime.now()}');
      buffer.writeln('========================================\n');

      for (final file in logFiles) {
        buffer.writeln('\n========== ${path.basename(file.path)} ==========\n');
        final content = await file.readAsString();
        buffer.writeln(content);
      }

      // 保存到临时文件
      final tempDir = await getTemporaryDirectory();
      final exportFile = File(path.join(
        tempDir.path,
        'lotus_iptv_logs_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.txt',
      ));
      await exportFile.writeAsString(buffer.toString());

      return exportFile.path;
    } catch (e) {
      debugPrint('LogService: 导出日志失败 - $e');
      return null;
    }
  }

  /// 清空所有日志
  Future<void> clearLogs() async {
    try {
      final logDir = await getLogDirectory();
      if (logDir == null || !await logDir.exists()) return;

      final files = await logDir.list().toList();
      for (final file in files) {
        if (file is File && file.path.endsWith('.log')) {
          await file.delete();
        }
      }

      debugPrint('LogService: 已清空所有日志');
      
      // 重新初始化以创建新日志文件
      _initialized = false;
      await init();
    } catch (e) {
      debugPrint('LogService: 清空日志失败 - $e');
    }
  }
}

/// 自定义日志过滤器
class _LogFilter extends LogFilter {
  final LogLevel logLevel;

  _LogFilter(this.logLevel);

  @override
  bool shouldLog(LogEvent event) {
    if (logLevel == LogLevel.off) return false;
    if (logLevel == LogLevel.debug) return true; // Debug 模式记录所有
    // Release 模式记录 info, warning 和 error
    return event.level.index >= Level.info.index;
  }
}

/// 自定义日志打印器
class _LogPrinter extends LogPrinter {
  static final _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');

  @override
  List<String> log(LogEvent event) {
    final time = _dateFormat.format(event.time);
    final level = event.level.name.toUpperCase().padRight(7);
    final message = event.message;
    
    final buffer = StringBuffer();
    buffer.write('$time [$level] $message');

    if (event.error != null) {
      buffer.write('\nError: ${event.error}');
    }

    if (event.stackTrace != null) {
      buffer.write('\nStackTrace:\n${event.stackTrace}');
    }

    return [buffer.toString()];
  }
}

/// 批量文件输出（性能优化版）
class _BatchFileOutput extends LogOutput {
  final LogService logService;

  _BatchFileOutput(this.logService);

  @override
  void output(OutputEvent event) {
    if (logService._file == null) return;

    try {
      for (final line in event.lines) {
        logService._logBuffer.add(line);
      }
      
      // 检查是否需要自动刷新（基于时间）
      logService._checkAutoFlush();
      
      // 当缓冲区达到一定大小时，批量写入
      if (logService._logBuffer.length >= LogService._bufferSize) {
        logService._file!.writeAsStringSync(
          logService._logBuffer.join('\n') + '\n',
          mode: FileMode.append,
          flush: false, // 不立即刷新，提高性能
        );
        logService._logBuffer.clear();
        logService._lastFlushTime = DateTime.now();
      }
    } catch (e) {
      debugPrint('LogService: 写入日志失败 - $e');
    }
  }
}
