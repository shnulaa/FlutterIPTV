import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../database/database_helper.dart';
import '../platform/platform_detector.dart';
import 'update_service.dart';
import 'log_service.dart';
import 'channel_logo_service.dart';
import 'redirect_cache_service.dart';
import '../managers/update_manager.dart';

/// Service Locator for dependency injection
class ServiceLocator {
  static late SharedPreferences _prefs;
  static late DatabaseHelper _database;
  static late Directory _appDir;
  static late UpdateService _updateService;
  static late UpdateManager _updateManager;
  static late LogService _logService;
  static late ChannelLogoService _channelLogoService;
  static late RedirectCacheService _redirectCache;

  static SharedPreferences get prefs => _prefs;
  static DatabaseHelper get database => _database;
  static Directory get appDir => _appDir;
  static UpdateService get updateService => _updateService;
  static UpdateManager get updateManager => _updateManager;
  static LogService get log => _logService;
  static ChannelLogoService get channelLogo => _channelLogoService;
  static RedirectCacheService get redirectCache => _redirectCache;
  
  /// Check if log service is initialized
  static bool get isLogInitialized {
    try {
      return _logService != null;
    } catch (e) {
      return false;
    }
  }

  static Future<void> initPrefs() async {
    // Initialize SharedPreferences - Fast and critical for theme
    _prefs = await SharedPreferences.getInstance();
    
    // Initialize log service early (after prefs) - pass prefs to avoid circular dependency
    _logService = LogService();
    await _logService.init(prefs: _prefs);

    // Detect platform (after log service is initialized)
    await PlatformDetector.init();
  }

  static Future<void> initDatabase() async {
    // Initialize app directory
    _appDir = await getApplicationDocumentsDirectory();

    // Initialize database
    _database = DatabaseHelper();
    await _database.initialize();

    // Initialize channel logo service (after database)
    _channelLogoService = ChannelLogoService(_database);
    // Initialize in background to avoid blocking app startup
    _channelLogoService.initialize().catchError((e) {
      log.e('Failed to initialize channel logo service: $e');
    });
  }

  static Future<void> init() async {
    await initPrefs();
    await initDatabase();

    // Initialize update service
    _updateService = UpdateService();
    _updateManager = UpdateManager();
    
    // Initialize redirect cache service
    _redirectCache = RedirectCacheService();
  }

  static Future<void> dispose() async {
    // 刷新日志缓冲区
    try {
      await _logService.flush();
    } catch (e) {
      // 使用 print 而不是 debugPrint，因为这是在 static 方法中
      print('ServiceLocator: 刷新日志失败 - $e');
    }
    
    await _database.close();
  }
}
