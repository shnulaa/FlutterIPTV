import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import '../platform/platform_detector.dart';
import 'update_service.dart';
import '../managers/update_manager.dart';

/// Service Locator for dependency injection
class ServiceLocator {
  static late SharedPreferences _prefs;
  static late DatabaseHelper _database;
  static late Directory _appDir;
  static late UpdateService _updateService;
  static late UpdateManager _updateManager;

  static SharedPreferences get prefs => _prefs;
  static DatabaseHelper get database => _database;
  static Directory get appDir => _appDir;
  static UpdateService get updateService => _updateService;
  static UpdateManager get updateManager => _updateManager;

  static Future<void> initPrefs() async {
    // Initialize SharedPreferences - Fast and critical for theme
    _prefs = await SharedPreferences.getInstance();

    // Detect platform
    PlatformDetector.init();
  }

  static Future<void> initDatabase() async {
    debugPrint('DEBUG: 开始初始化数据库...');
    
    // Initialize app directory
    _appDir = await getApplicationDocumentsDirectory();
    debugPrint('DEBUG: 应用程序目录: ${_appDir.path}');

    // Initialize database
    _database = DatabaseHelper();
    await _database.initialize();
    debugPrint('DEBUG: 数据库初始化完成');
  }

  static Future<void> init() async {
    debugPrint('DEBUG: 开始完整服务初始化...');
    
    await initPrefs();
    debugPrint('DEBUG: SharedPreferences 初始化完成');
    
    await initDatabase();
    debugPrint('DEBUG: 数据库初始化完成');

    // Initialize update service
    _updateService = UpdateService();
    _updateManager = UpdateManager();
    debugPrint('DEBUG: 更新服务初始化完成');
    
    debugPrint('DEBUG: 所有服务初始化完成');
  }

  static Future<void> dispose() async {
    await _database.close();
  }
}
