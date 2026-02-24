import 'dart:io';
import 'backup_metadata.dart';

/// 备份文件模型
class BackupFile {
  final String name;
  final String path;
  final int size;
  final DateTime createdAt;
  final BackupMetadata? metadata;
  final bool isLocal;

  BackupFile({
    required this.name,
    required this.path,
    required this.size,
    required this.createdAt,
    this.metadata,
    this.isLocal = true,
  });

  /// 从本地文件创建
  static Future<BackupFile> fromFile(File file) async {
    final stat = await file.stat();
    final name = file.path.split(Platform.pathSeparator).last;
    
    return BackupFile(
      name: name,
      path: file.path,
      size: stat.size,
      createdAt: stat.modified,
      isLocal: true,
    );
  }

  /// 从 WebDAV 文件信息创建
  static BackupFile fromWebDAV({
    required String name,
    required String path,
    required int size,
    required DateTime modifiedTime,
  }) {
    return BackupFile(
      name: name,
      path: path,
      size: size,
      createdAt: modifiedTime,
      isLocal: false,
    );
  }

  /// 格式化文件大小
  String get formattedSize {
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(2)} KB';
    } else if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  /// 格式化创建时间
  String get formattedDate {
    return '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')} '
        '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
  }
}
