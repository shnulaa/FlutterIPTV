import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart';
import '../../../core/models/backup_file.dart';
import '../../../core/models/backup_metadata.dart';
import '../../../core/services/backup_service.dart';
import '../../../core/services/restore_service.dart';
import '../../../core/services/webdav_service.dart';
import '../../../core/services/service_locator.dart';

/// 备份和恢复 Provider
class BackupProvider extends ChangeNotifier {
  final BackupService _backupService = BackupService();
  final RestoreService _restoreService = RestoreService();
  final WebDAVService _webdavService = WebDAVService();

  bool _isLoading = false;
  double _progress = 0.0;
  String _progressMessage = '';
  String? _error;

  List<BackupFile> _localBackups = [];
  List<BackupFile> _webdavBackups = [];

  // Getters
  bool get isLoading => _isLoading;
  double get progress => _progress;
  String get progressMessage => _progressMessage;
  String? get error => _error;
  List<BackupFile> get localBackups => _localBackups;
  List<BackupFile> get webdavBackups => _webdavBackups;
  bool get isWebDAVConfigured => _webdavService.isConfigured;

  /// 创建本地备份
  Future<bool> createLocalBackup({String? message}) async {
    _progress = 0.0;
    _progressMessage = message ?? '正在创建本地备份...';
    _error = null;
    notifyListeners();

    try {
      await _backupService.createBackup(
        onProgress: (progress, message) {
          _progress = progress;
          _progressMessage = message;
          notifyListeners();
        },
      );

      await loadLocalBackups(notify: false);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 加载本地备份列表
  Future<void> loadLocalBackups({bool notify = true, String? message}) async {
    try {
      _localBackups = await _backupService.getLocalBackups();
      if (notify) {
        notifyListeners();
      }
    } catch (e) {
      ServiceLocator.log.e('加载本地备份列表失败', tag: 'BackupProvider', error: e);
      if (notify) {
        notifyListeners();
      }
    }
  }

  /// 设置备份目录
  Future<bool> setBackupDirectory(String directoryPath) async {
    try {
      await _backupService.setBackupDirectory(directoryPath);
      await loadLocalBackups(); // 重新加载备份列表
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 获取当前备份目录路径
  Future<String> getBackupDirectoryPath() async {
    try {
      return await _backupService.getBackupDirectoryPath();
    } catch (e) {
      ServiceLocator.log.e('获取备份目录失败', tag: 'BackupProvider', error: e);
      return '';
    }
  }

  /// 删除本地备份
  Future<bool> deleteLocalBackup(String filePath) async {
    try {
      await _backupService.deleteLocalBackup(filePath);
      await loadLocalBackups();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 配置 WebDAV
  void configureWebDAV({
    required String serverUrl,
    required String username,
    required String password,
    String remotePath = '/',
    bool notify = true, // 添加参数控制是否触发通知
  }) {
    _webdavService.configure(
      serverUrl: serverUrl,
      username: username,
      password: password,
      remotePath: remotePath,
    );

    // 保存配置到 SharedPreferences
    ServiceLocator.prefs.setString('webdav_url', serverUrl);
    ServiceLocator.prefs.setString('webdav_username', username);
    ServiceLocator.prefs.setString('webdav_password', password);
    ServiceLocator.prefs.setString('webdav_path', remotePath);

    if (notify) {
      notifyListeners();
    }
  }

  /// 加载 WebDAV 配置
  void loadWebDAVConfig() {
    final url = ServiceLocator.prefs.getString('webdav_url');
    final username = ServiceLocator.prefs.getString('webdav_username');
    final password = ServiceLocator.prefs.getString('webdav_password');
    final remotePath = ServiceLocator.prefs.getString('webdav_path') ?? '/';

    if (url != null && username != null && password != null) {
      _webdavService.configure(
        serverUrl: url,
        username: username,
        password: password,
        remotePath: remotePath,
      );
      notifyListeners();
    }
  }

  /// 测试 WebDAV 连接
  Future<bool> testWebDAVConnection({bool notify = true, String? message}) async {
    try {
      final result = await _webdavService.testConnection();
      return result;
    } catch (e) {
      _error = e.toString();
      if (notify) {
        notifyListeners();
      }
      return false;
    }
  }

  /// 备份到 WebDAV
  Future<bool> backupToWebDAV() async {
    _progress = 0.0;
    _error = null;
    notifyListeners();

    try {
      // 先创建本地备份
      _progressMessage = '创建本地备份...';
      notifyListeners();

      final localBackupPath = await _backupService.createBackup(
        onProgress: (progress, message) {
          _progress = progress * 0.7; // 本地备份占 70%
          _progressMessage = message;
          notifyListeners();
        },
      );

      // 上传到 WebDAV
      _progressMessage = '上传到 WebDAV...';
      _progress = 0.7;
      notifyListeners();

      await _webdavService.uploadBackup(
        localFilePath: localBackupPath,
        onProgress: (progress) {
          _progress = 0.7 + (progress * 0.3); // 上传占 30%
          notifyListeners();
        },
      );

      _progress = 1.0;
      _progressMessage = '完成';
      await loadWebDAVBackups(notify: false);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 加载 WebDAV 备份列表
  Future<void> loadWebDAVBackups({bool notify = true, String? message}) async {
    try {
      _webdavBackups = await _webdavService.listBackups();
      if (notify) {
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      if (notify) {
        notifyListeners();
      }
    }
  }

  /// 从 WebDAV 恢复
  Future<bool> restoreFromWebDAV(String remotePath, {VoidCallback? onRestoreComplete}) async {
    _progress = 0.0;
    _progressMessage = '正在下载备份...';
    _error = null;
    notifyListeners();

    try {
      ServiceLocator.log.i('开始从 WebDAV 恢复: $remotePath', tag: 'BackupProvider');
      
      // 下载到临时目录
      final tempDir = await getTemporaryDirectory();
      final fileName = remotePath.split('/').last;
      final localPath = path.join(tempDir.path, fileName);

      ServiceLocator.log.d('下载到临时文件: $localPath', tag: 'BackupProvider');

      await _webdavService.downloadBackup(
        remotePath: remotePath,
        localPath: localPath,
        onProgress: (progress) {
          _progress = progress * 0.3; // 下载占 30%
          notifyListeners();
        },
      );

      ServiceLocator.log.i('下载完成，开始恢复', tag: 'BackupProvider');

      // 恢复
      _progressMessage = '正在恢复备份...';
      _progress = 0.3;
      notifyListeners();

      await _restoreService.restore(
        backupFilePath: localPath,
        onProgress: (progress, message) {
          _progress = 0.3 + (progress * 0.7); // 恢复占 70%
          _progressMessage = message;
          notifyListeners();
        },
      );

      ServiceLocator.log.i('恢复完成', tag: 'BackupProvider');

      // 清理临时文件
      final file = File(localPath);
      if (await file.exists()) {
        await file.delete();
        ServiceLocator.log.d('临时文件已删除', tag: 'BackupProvider');
      }

      _progress = 1.0;
      _progressMessage = '恢复完成';
      notifyListeners();

      // 恢复完成后执行回调
      if (onRestoreComplete != null) {
        ServiceLocator.log.d('执行恢复完成回调', tag: 'BackupProvider');
        onRestoreComplete();
      }
      
      ServiceLocator.log.i('restoreFromWebDAV 返回 true', tag: 'BackupProvider');
      return true;
    } catch (e, stackTrace) {
      ServiceLocator.log.e('WebDAV 恢复失败', tag: 'BackupProvider', error: e, stackTrace: stackTrace);
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 从本地备份恢复
  Future<bool> restoreFromLocal(String backupFilePath, {VoidCallback? onRestoreComplete, String? message}) async {
    ServiceLocator.log.i('BackupProvider.restoreFromLocal 开始', tag: 'BackupProvider');
    _progress = 0.0;
    _progressMessage = message ?? '正在恢复备份...';
    _error = null;
    notifyListeners();

    try {
      ServiceLocator.log.i('调用 RestoreService.restore', tag: 'BackupProvider');
      await _restoreService.restore(
        backupFilePath: backupFilePath,
        onProgress: (progress, message) {
          _progress = progress;
          _progressMessage = message;
          notifyListeners();
        },
      );

      ServiceLocator.log.i('RestoreService.restore 已返回', tag: 'BackupProvider');
      
      _progress = 1.0;
      _progressMessage = '恢复完成';
      notifyListeners();
      
      // 恢复完成后执行回调
      if (onRestoreComplete != null) {
        ServiceLocator.log.i('执行恢复完成回调', tag: 'BackupProvider');
        onRestoreComplete();
      }
      
      ServiceLocator.log.i('BackupProvider.restoreFromLocal 返回 true', tag: 'BackupProvider');
      
      return true;
    } catch (e, stackTrace) {
      ServiceLocator.log.e('恢复失败', tag: 'BackupProvider', error: e, stackTrace: stackTrace);
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 从文件选择器选择备份文件并恢复
  Future<bool> restoreFromSelectedFile() async {
    try {
      // 使用 file_picker 让用户选择备份文件
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        dialogTitle: '选择备份文件',
      );

      if (result == null || result.files.isEmpty) {
        return false; // 用户取消选择
      }

      final filePath = result.files.first.path;
      if (filePath == null) {
        _error = '无法获取文件路径';
        notifyListeners();
        return false;
      }

      return await restoreFromLocal(filePath);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 验证备份文件
  Future<BackupMetadata?> validateBackup(String backupFilePath) async {
    try {
      return await _restoreService.validateBackup(backupFilePath);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// 删除 WebDAV 备份
  Future<bool> deleteWebDAVBackup(String remotePath) async {
    try {
      await _webdavService.deleteBackup(remotePath);
      await loadWebDAVBackups();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
