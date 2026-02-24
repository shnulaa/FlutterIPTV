import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/backup_metadata.dart';
import 'service_locator.dart';

/// 恢复服务
/// 
/// 负责从备份文件恢复数据
/// 
/// 数据库版本兼容性处理：
/// - 备份版本 < 当前版本：恢复后自动触发 SQLite onUpgrade 迁移
/// - 备份版本 = 当前版本：直接恢复
/// - 备份版本 > 当前版本：拒绝恢复，提示更新应用
class RestoreService {
  /// 验证备份文件并读取元数据
  Future<BackupMetadata> validateBackup(String backupFilePath) async {
    ServiceLocator.log.i('验证备份文件: $backupFilePath', tag: 'RestoreService');

    Directory? tempDir;
    try {
      final backupFile = File(backupFilePath);
      if (!await backupFile.exists()) {
        throw Exception('备份文件不存在');
      }

      ServiceLocator.log.d('备份文件大小: ${await backupFile.length()} bytes', tag: 'RestoreService');

      // 解压到临时目录读取元数据
      tempDir = await _getTempDirectory();
      ServiceLocator.log.d('临时目录: ${tempDir.path}', tag: 'RestoreService');
      
      await _extractZipArchive(backupFilePath, tempDir.path);
      ServiceLocator.log.d('ZIP 解压完成', tag: 'RestoreService');

      // 读取元数据
      final metadataFile = File(path.join(tempDir.path, 'metadata.json'));
      ServiceLocator.log.d('查找元数据文件: ${metadataFile.path}', tag: 'RestoreService');
      
      if (!await metadataFile.exists()) {
        // 列出临时目录中的文件以便调试
        final files = await tempDir.list(recursive: true).toList();
        ServiceLocator.log.w('临时目录中的文件: ${files.map((f) => path.relative(f.path, from: tempDir!.path)).join(", ")}', tag: 'RestoreService');
        throw Exception('备份文件格式无效：缺少元数据文件');
      }

      final metadataContent = await metadataFile.readAsString();
      ServiceLocator.log.d('元数据内容: $metadataContent', tag: 'RestoreService');
      
      final metadataJson = jsonDecode(metadataContent);
      final metadata = BackupMetadata.fromJson(metadataJson);

      ServiceLocator.log.i('备份文件验证成功', tag: 'RestoreService');
      return metadata;
    } catch (e, stackTrace) {
      ServiceLocator.log.e('验证备份文件失败', tag: 'RestoreService', error: e, stackTrace: stackTrace);
      rethrow;
    } finally {
      // 确保清理临时文件（使用 finally 确保一定执行）
      if (tempDir != null) {
        try {
          // 等待一小段时间，确保文件句柄被释放
          await Future.delayed(const Duration(milliseconds: 100));
          
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
            ServiceLocator.log.d('临时目录已清理', tag: 'RestoreService');
          }
        } catch (cleanupError) {
          ServiceLocator.log.w('清理临时文件失败（可忽略）', tag: 'RestoreService', error: cleanupError);
        }
      }
    }
  }

  /// 检查版本兼容性
  Future<VersionCompatibility> checkCompatibility(BackupMetadata metadata) async {
    const currentDbVersion = 8; // 从 database_helper.dart 获取
    final comparison = metadata.compareVersion(currentDbVersion);

    if (comparison > 0) {
      return VersionCompatibility.incompatible;
    } else if (comparison < 0) {
      return VersionCompatibility.needsMigration;
    } else {
      return VersionCompatibility.compatible;
    }
  }

  /// 从备份恢复
  Future<void> restore({
    required String backupFilePath,
    required Function(double progress, String message) onProgress,
  }) async {
    ServiceLocator.log.i('开始恢复备份: $backupFilePath', tag: 'RestoreService');
    final startTime = DateTime.now();

    Directory? tempDir;
    Directory? rollbackDir;

    try {
      // 1. 验证备份文件 (10%)
      onProgress(0.1, '验证备份文件...');
      final metadata = await validateBackup(backupFilePath);

      // 2. 检查版本兼容性 (15%)
      onProgress(0.15, '检查版本兼容性...');
      final compatibility = await checkCompatibility(metadata);
      if (compatibility == VersionCompatibility.incompatible) {
        throw Exception('备份文件来自更新版本的应用（数据库版本 ${metadata.databaseVersion}），请先更新应用到最新版本');
      }

      // 3. 创建当前数据的回滚备份 (25%)
      onProgress(0.25, '创建回滚备份...');
      rollbackDir = await _createRollbackBackup();

      // 4. 关闭数据库连接 (30%)
      onProgress(0.3, '关闭数据库连接...');
      ServiceLocator.log.i('准备关闭数据库', tag: 'RestoreService');
      await ServiceLocator.database.close();
      ServiceLocator.log.i('数据库已关闭', tag: 'RestoreService');

      // 5. 解压备份文件 (40%)
      onProgress(0.4, '解压备份文件...');
      tempDir = await _getTempDirectory();
      await _extractZipArchive(backupFilePath, tempDir.path);

      // 6. 恢复数据库文件 (55%)
      onProgress(0.55, '恢复数据库...');
      await _restoreDatabaseFile(tempDir);

      // 7. 恢复 SharedPreferences (70%)
      onProgress(0.7, '恢复应用配置...');
      await _restoreSharedPreferences(tempDir);

      // 8. 恢复播放列表文件 (85%)
      onProgress(0.85, '恢复播放列表...');
      await _restorePlaylistFiles(tempDir);

      // 9. 清理临时文件 (95%)
      onProgress(0.95, '清理临时文件...');
      await tempDir.delete(recursive: true);
      await rollbackDir.delete(recursive: true);

      // 10. 重新初始化数据库 (98%)
      onProgress(0.98, '重新初始化数据库...');
      ServiceLocator.log.i('开始重新初始化数据库', tag: 'RestoreService');
      
      try {
        // 添加超时保护，防止卡住
        await ServiceLocator.database.initialize().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            ServiceLocator.log.w('数据库初始化超时，但继续执行', tag: 'RestoreService');
            throw TimeoutException('数据库初始化超时');
          },
        );
        ServiceLocator.log.i('数据库已重新初始化', tag: 'RestoreService');
      } catch (e) {
        ServiceLocator.log.e('数据库初始化失败，但恢复过程继续', tag: 'RestoreService', error: e);
        // 不抛出异常，让恢复过程继续
      }

      // 11. 完成 (100%)
      onProgress(1.0, '恢复完成');
      ServiceLocator.log.i('进度已设置为 100%', tag: 'RestoreService');

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      ServiceLocator.log.i('恢复完成，耗时: ${duration}ms，需要刷新应用数据', tag: 'RestoreService');

      if (compatibility == VersionCompatibility.needsMigration) {
        ServiceLocator.log.i('备份版本较旧，数据库已自动升级', tag: 'RestoreService');
      }
      
      ServiceLocator.log.i('restore 方法即将返回', tag: 'RestoreService');
    } catch (e, stackTrace) {
      ServiceLocator.log.e('恢复失败，开始回滚', tag: 'RestoreService', error: e, stackTrace: stackTrace);

      // 回滚到原始状态
      if (rollbackDir != null) {
        try {
          await _rollback(rollbackDir);
          
          // 回滚后也需要重新初始化数据库
          try {
            await ServiceLocator.database.initialize();
            ServiceLocator.log.i('回滚成功，数据库已重新初始化', tag: 'RestoreService');
          } catch (dbError) {
            ServiceLocator.log.e('重新初始化数据库失败', tag: 'RestoreService', error: dbError);
          }
        } catch (rollbackError) {
          ServiceLocator.log.e('回滚失败', tag: 'RestoreService', error: rollbackError);
        }
      }

      // 清理临时文件
      if (tempDir != null && await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }

      rethrow;
    }
  }

  // ========== 私有辅助方法 ==========

  Future<Directory> _getTempDirectory() async {
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final restoreTempDir = Directory(path.join(tempDir.path, 'restore_temp_$timestamp'));
    await restoreTempDir.create(recursive: true);
    return restoreTempDir;
  }

  Future<void> _extractZipArchive(String zipPath, String outputPath) async {
    ServiceLocator.log.d('开始解压 ZIP: $zipPath 到 $outputPath', tag: 'RestoreService');
    
    final bytes = File(zipPath).readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);
    
    ServiceLocator.log.d('ZIP 文件包含 ${archive.files.length} 个文件', tag: 'RestoreService');
    
    // 列出 ZIP 中的所有文件
    for (final file in archive.files) {
      ServiceLocator.log.d('ZIP 中的文件: ${file.name} (${file.size} bytes)', tag: 'RestoreService');
    }
    
    // 手动解压每个文件，确保正确处理
    for (final file in archive.files) {
      final filename = file.name;
      if (file.isFile) {
        final data = file.content as List<int>;
        final outputFile = File(path.join(outputPath, filename));
        
        // 确保目录存在
        await outputFile.parent.create(recursive: true);
        
        // 写入文件
        await outputFile.writeAsBytes(data);
        ServiceLocator.log.d('已解压文件: $filename', tag: 'RestoreService');
      }
    }
    
    ServiceLocator.log.d('ZIP 解压完成', tag: 'RestoreService');
  }

  Future<Directory> _createRollbackBackup() async {
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final rollbackDir = Directory(path.join(tempDir.path, 'rollback_$timestamp'));
    await rollbackDir.create(recursive: true);

    // 备份数据库
    final appDir = await getApplicationDocumentsDirectory();
    final dbFile = File(path.join(appDir.path, 'flutter_iptv.db'));
    if (await dbFile.exists()) {
      final rollbackDbFile = File(path.join(rollbackDir.path, 'flutter_iptv.db'));
      // 如果回滚文件已存在，先删除
      if (await rollbackDbFile.exists()) {
        await rollbackDbFile.delete();
      }
      await dbFile.copy(rollbackDbFile.path);
    }

    // 备份播放列表目录
    final playlistsDir = Directory(path.join(appDir.path, 'playlists'));
    if (await playlistsDir.exists()) {
      final rollbackPlaylistsDir = Directory(path.join(rollbackDir.path, 'playlists'));
      await rollbackPlaylistsDir.create();
      await for (final entity in playlistsDir.list()) {
        if (entity is File) {
          final fileName = path.basename(entity.path);
          await entity.copy(path.join(rollbackPlaylistsDir.path, fileName));
        }
      }
    }

    return rollbackDir;
  }

  Future<void> _restoreDatabaseFile(Directory tempDir) async {
    final dbBackupFile = File(path.join(tempDir.path, 'database', 'flutter_iptv.db'));
    if (!await dbBackupFile.exists()) {
      throw Exception('备份文件中缺少数据库文件');
    }

    final appDir = await getApplicationDocumentsDirectory();
    final dbFile = File(path.join(appDir.path, 'flutter_iptv.db'));
    
    ServiceLocator.log.d('准备恢复数据库文件', tag: 'RestoreService');
    
    // 方案：直接用新文件的内容覆盖旧文件，而不是删除后复制
    // 这样可以避免 Windows 文件占用的问题
    try {
      // 读取备份文件的内容
      final backupBytes = await dbBackupFile.readAsBytes();
      
      // 直接写入目标文件（覆盖模式）
      await dbFile.writeAsBytes(backupBytes, mode: FileMode.write, flush: true);
      ServiceLocator.log.d('数据库文件已覆盖恢复', tag: 'RestoreService');
      
      // 同时处理 WAL 和 SHM 文件（如果存在）
      await _cleanupWalFiles(appDir);
      
    } catch (e) {
      ServiceLocator.log.e('恢复数据库文件失败', tag: 'RestoreService', error: e);
      throw Exception('无法恢复数据库文件: $e');
    }
  }
  
  /// 清理 SQLite WAL 文件
  Future<void> _cleanupWalFiles(Directory appDir) async {
    try {
      // 删除 WAL 文件
      final walFile = File(path.join(appDir.path, 'flutter_iptv.db-wal'));
      if (await walFile.exists()) {
        await walFile.delete();
        ServiceLocator.log.d('已删除 WAL 文件', tag: 'RestoreService');
      }
      
      // 删除 SHM 文件
      final shmFile = File(path.join(appDir.path, 'flutter_iptv.db-shm'));
      if (await shmFile.exists()) {
        await shmFile.delete();
        ServiceLocator.log.d('已删除 SHM 文件', tag: 'RestoreService');
      }
    } catch (e) {
      ServiceLocator.log.w('清理 WAL 文件失败（可忽略）', tag: 'RestoreService', error: e);
    }
  }

  Future<void> _restoreSharedPreferences(Directory tempDir) async {
    final prefsFile = File(path.join(tempDir.path, 'preferences', 'settings.json'));
    if (!await prefsFile.exists()) {
      ServiceLocator.log.w('备份文件中缺少配置文件，跳过', tag: 'RestoreService');
      return;
    }

    final prefsJson = jsonDecode(await prefsFile.readAsString()) as Map<String, dynamic>;
    final prefs = ServiceLocator.prefs;

    // 清除现有配置
    for (final key in prefs.getKeys()) {
      await prefs.remove(key);
    }

    // 恢复配置
    for (final entry in prefsJson.entries) {
      final value = entry.value;
      if (value is bool) {
        await prefs.setBool(entry.key, value);
      } else if (value is int) {
        await prefs.setInt(entry.key, value);
      } else if (value is double) {
        await prefs.setDouble(entry.key, value);
      } else if (value is String) {
        await prefs.setString(entry.key, value);
      } else if (value is List<String>) {
        await prefs.setStringList(entry.key, value);
      }
    }
  }

  Future<void> _restorePlaylistFiles(Directory tempDir) async {
    final playlistsBackupDir = Directory(path.join(tempDir.path, 'playlists'));
    if (!await playlistsBackupDir.exists()) {
      ServiceLocator.log.w('备份文件中缺少播放列表目录，跳过', tag: 'RestoreService');
      return;
    }

    final appDir = await getApplicationDocumentsDirectory();
    final playlistsDir = Directory(path.join(appDir.path, 'playlists'));

    // 清空现有播放列表
    if (await playlistsDir.exists()) {
      await playlistsDir.delete(recursive: true);
    }
    await playlistsDir.create(recursive: true);

    // 恢复播放列表文件
    await for (final entity in playlistsBackupDir.list()) {
      if (entity is File) {
        final fileName = path.basename(entity.path);
        await entity.copy(path.join(playlistsDir.path, fileName));
      }
    }
  }

  Future<void> _rollback(Directory rollbackDir) async {
    ServiceLocator.log.i('开始回滚到原始状态', tag: 'RestoreService');

    // 恢复数据库
    final rollbackDbFile = File(path.join(rollbackDir.path, 'flutter_iptv.db'));
    if (await rollbackDbFile.exists()) {
      final appDir = await getApplicationDocumentsDirectory();
      final dbFile = File(path.join(appDir.path, 'flutter_iptv.db'));
      
      // 如果目标文件已存在，先删除
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
      
      await rollbackDbFile.copy(dbFile.path);
    }

    // 恢复播放列表
    final rollbackPlaylistsDir = Directory(path.join(rollbackDir.path, 'playlists'));
    if (await rollbackPlaylistsDir.exists()) {
      final appDir = await getApplicationDocumentsDirectory();
      final playlistsDir = Directory(path.join(appDir.path, 'playlists'));

      if (await playlistsDir.exists()) {
        await playlistsDir.delete(recursive: true);
      }
      await playlistsDir.create(recursive: true);

      await for (final entity in rollbackPlaylistsDir.list()) {
        if (entity is File) {
          final fileName = path.basename(entity.path);
          await entity.copy(path.join(playlistsDir.path, fileName));
        }
      }
    }
  }
}

/// 版本兼容性枚举
enum VersionCompatibility {
  compatible,      // 版本相同，直接恢复
  needsMigration,  // 备份版本较旧，需要自动迁移
  incompatible,    // 备份版本较新，不兼容
}
