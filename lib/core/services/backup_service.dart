import 'dart:io';
import 'dart:convert';
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:package_info_plus/package_info_plus.dart';
import '../models/backup_metadata.dart';
import '../models/backup_file.dart';
import 'service_locator.dart';

/// 备份服务
/// 
/// 负责创建和管理本地备份文件
class BackupService {
  /// 创建备份
  /// 
  /// 返回创建的备份文件路径
  Future<String> createBackup({
    required Function(double progress, String message) onProgress,
  }) async {
    ServiceLocator.log.i('开始创建备份', tag: 'BackupService');
    final startTime = DateTime.now();

    try {
      // 1. 准备备份目录 (10%)
      onProgress(0.1, '准备备份目录...');
      final backupDir = await _getBackupDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupFileName = 'backup_$timestamp.zip';
      final backupFilePath = path.join(backupDir.path, backupFileName);
      final tempDir = await _getTempDirectory();

      // 2. 收集数据库文件 (20%)
      onProgress(0.2, '收集数据库文件...');
      final dbFile = await _getDatabaseFile();
      final dbBackupDir = Directory(path.join(tempDir.path, 'database'));
      await dbBackupDir.create(recursive: true);
      await dbFile.copy(path.join(dbBackupDir.path, 'flutter_iptv.db'));

      // 3. 收集 SharedPreferences (40%)
      onProgress(0.4, '收集应用配置...');
      final prefsBackupDir = Directory(path.join(tempDir.path, 'preferences'));
      await prefsBackupDir.create(recursive: true);
      await _exportSharedPreferences(path.join(prefsBackupDir.path, 'settings.json'));

      // 4. 收集播放列表文件 (60%)
      onProgress(0.6, '收集播放列表文件...');
      final playlistsBackupDir = Directory(path.join(tempDir.path, 'playlists'));
      await playlistsBackupDir.create(recursive: true);
      await _copyPlaylistFiles(playlistsBackupDir);

      // 5. 创建元数据 (70%)
      onProgress(0.7, '创建备份元数据...');
      final metadata = await _createMetadata();
      final metadataFile = File(path.join(tempDir.path, 'metadata.json'));
      await metadataFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(metadata.toJson()),
      );
      ServiceLocator.log.d('元数据文件已创建: ${metadataFile.path}', tag: 'BackupService');
      ServiceLocator.log.d('元数据文件存在: ${await metadataFile.exists()}', tag: 'BackupService');

      // 6. 压缩为 ZIP 文件 (80%)
      onProgress(0.8, '压缩备份文件...');
      await _createZipArchive(tempDir, backupFilePath);

      // 7. 清理临时文件 (95%)
      onProgress(0.95, '清理临时文件...');
      await tempDir.delete(recursive: true);

      // 8. 完成 (100%)
      onProgress(1.0, '备份完成');

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      ServiceLocator.log.i('备份创建成功，耗时: ${duration}ms，文件: $backupFilePath', tag: 'BackupService');

      return backupFilePath;
    } catch (e, stackTrace) {
      ServiceLocator.log.e('创建备份失败', tag: 'BackupService', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// 获取本地备份列表
  Future<List<BackupFile>> getLocalBackups() async {
    try {
      final backupDir = await _getBackupDirectory();
      if (!await backupDir.exists()) {
        return [];
      }

      final files = await backupDir
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.zip'))
          .cast<File>()
          .toList();

      final backupFiles = <BackupFile>[];
      for (final file in files) {
        try {
          // 验证文件名格式：backup_数字.zip
          final fileName = path.basename(file.path);
          if (!_isValidBackupFileName(fileName)) {
            ServiceLocator.log.d('跳过非标准格式的备份文件: $fileName', tag: 'BackupService');
            continue;
          }
          
          final backupFile = await BackupFile.fromFile(file);
          backupFiles.add(backupFile);
        } catch (e) {
          ServiceLocator.log.w('读取备份文件失败: ${file.path}', tag: 'BackupService', error: e);
        }
      }

      // 按创建时间倒序排列
      backupFiles.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return backupFiles;
    } catch (e, stackTrace) {
      ServiceLocator.log.e('获取本地备份列表失败', tag: 'BackupService', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// 验证备份文件名格式
  /// 
  /// 有效格式：backup_1771852442578.zip
  /// - 必须以 "backup_" 开头
  /// - 后面跟 13 位数字（时间戳）
  /// - 以 ".zip" 结尾
  bool _isValidBackupFileName(String fileName) {
    final pattern = RegExp(r'^backup_\d{13}\.zip$');
    return pattern.hasMatch(fileName);
  }

  /// 删除本地备份
  Future<void> deleteLocalBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        ServiceLocator.log.i('删除备份文件: $filePath', tag: 'BackupService');
      }
    } catch (e, stackTrace) {
      ServiceLocator.log.e('删除备份文件失败', tag: 'BackupService', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // ========== 私有辅助方法 ==========

  /// 获取备份目录
  Future<Directory> _getBackupDirectory() async {
    // 先尝试从 SharedPreferences 获取用户自定义的备份目录
    final customPath = ServiceLocator.prefs.getString('backup_directory');
    
    if (customPath != null && customPath.isNotEmpty) {
      final customDir = Directory(customPath);
      if (await customDir.exists()) {
        return customDir;
      }
    }
    
    // 如果没有自定义目录或目录不存在，使用默认目录
    final appDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(path.join(appDir.path, 'backups'));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  /// 设置自定义备份目录
  Future<void> setBackupDirectory(String directoryPath) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    await ServiceLocator.prefs.setString('backup_directory', directoryPath);
    ServiceLocator.log.i('备份目录已设置为: $directoryPath', tag: 'BackupService');
  }

  /// 获取当前备份目录路径
  Future<String> getBackupDirectoryPath() async {
    final dir = await _getBackupDirectory();
    return dir.path;
  }

  /// 获取临时目录
  Future<Directory> _getTempDirectory() async {
    final tempDir = await getTemporaryDirectory();
    final backupTempDir = Directory(path.join(tempDir.path, 'backup_temp_${DateTime.now().millisecondsSinceEpoch}'));
    await backupTempDir.create(recursive: true);
    return backupTempDir;
  }

  /// 获取数据库文件
  Future<File> _getDatabaseFile() async {
    final appDir = await getApplicationDocumentsDirectory();
    return File(path.join(appDir.path, 'flutter_iptv.db'));
  }

  /// 导出 SharedPreferences 为 JSON
  Future<void> _exportSharedPreferences(String outputPath) async {
    final prefs = ServiceLocator.prefs;
    final keys = prefs.getKeys();
    final data = <String, dynamic>{};

    for (final key in keys) {
      final value = prefs.get(key);
      data[key] = value;
    }

    final file = File(outputPath);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
    );
  }

  /// 复制播放列表文件
  Future<void> _copyPlaylistFiles(Directory targetDir) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final playlistsDir = Directory(path.join(appDir.path, 'playlists'));

      if (!await playlistsDir.exists()) {
        ServiceLocator.log.d('播放列表目录不存在，跳过', tag: 'BackupService');
        return;
      }

      final files = await playlistsDir
          .list()
          .where((entity) => entity is File)
          .cast<File>()
          .toList();

      for (final file in files) {
        final fileName = path.basename(file.path);
        final targetPath = path.join(targetDir.path, fileName);
        await file.copy(targetPath);
      }

      ServiceLocator.log.d('复制了 ${files.length} 个播放列表文件', tag: 'BackupService');
    } catch (e) {
      ServiceLocator.log.w('复制播放列表文件失败', tag: 'BackupService', error: e);
    }
  }

  /// 创建备份元数据
  Future<BackupMetadata> _createMetadata() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final dbFile = await _getDatabaseFile();
    final dbSize = await dbFile.length();

    return BackupMetadata(
      timestamp: DateTime.now().toIso8601String(),
      appVersion: packageInfo.version,
      databaseVersion: 8, // 从 database_helper.dart 获取
      platform: Platform.operatingSystem,
      fileSize: dbSize,
    );
  }

  /// 创建 ZIP 压缩包
  Future<void> _createZipArchive(Directory sourceDir, String outputPath) async {
    ServiceLocator.log.d('开始创建 ZIP: ${sourceDir.path} -> $outputPath', tag: 'BackupService');
    
    final encoder = ZipFileEncoder();
    encoder.create(outputPath);
    
    // 先列出源目录中的所有文件
    final allFiles = <File>[];
    await for (final entity in sourceDir.list(recursive: true)) {
      if (entity is File) {
        allFiles.add(entity);
        ServiceLocator.log.d('发现文件: ${entity.path}', tag: 'BackupService');
      }
    }
    
    ServiceLocator.log.d('共发现 ${allFiles.length} 个文件', tag: 'BackupService');
    
    // 添加所有文件到 ZIP
    for (final file in allFiles) {
      final relativePath = path.relative(file.path, from: sourceDir.path);
      ServiceLocator.log.d('添加文件到 ZIP: $relativePath', tag: 'BackupService');
      await encoder.addFile(file, relativePath);
    }
    
    encoder.close();
    ServiceLocator.log.i('ZIP 压缩完成: $outputPath，包含 ${allFiles.length} 个文件', tag: 'BackupService');
  }
}
