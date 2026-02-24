/// 备份元数据模型
/// 
/// 包含备份文件的关键信息，用于验证和兼容性检查
/// 
/// 数据库版本兼容性策略：
/// - 备份DB版本 < 当前DB版本：允许恢复，自动触发 SQLite 的 onUpgrade 迁移
/// - 备份DB版本 = 当前DB版本：允许恢复，直接替换
/// - 备份DB版本 > 当前DB版本：拒绝恢复，提示用户更新应用
class BackupMetadata {
  final String timestamp;
  final String appVersion;
  final int databaseVersion;
  final String platform;
  final int fileSize;

  BackupMetadata({
    required this.timestamp,
    required this.appVersion,
    required this.databaseVersion,
    required this.platform,
    required this.fileSize,
  });

  /// 从 JSON 解析
  factory BackupMetadata.fromJson(Map<String, dynamic> json) {
    return BackupMetadata(
      timestamp: json['timestamp'] as String,
      appVersion: json['app_version'] as String,
      databaseVersion: json['database_version'] as int,
      platform: json['platform'] as String,
      fileSize: json['file_size'] as int,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp,
      'app_version': appVersion,
      'database_version': databaseVersion,
      'platform': platform,
      'file_size': fileSize,
    };
  }

  /// 检查数据库版本兼容性
  /// 
  /// 返回值：
  /// - 0: 版本相同，直接恢复
  /// - 负数: 备份版本较旧，需要自动迁移
  /// - 正数: 备份版本较新，不兼容
  int compareVersion(int currentDbVersion) {
    return databaseVersion - currentDbVersion;
  }

  /// 是否兼容当前版本
  bool isCompatible(int currentDbVersion) {
    return databaseVersion <= currentDbVersion;
  }

  /// 格式化的时间戳
  String get formattedTimestamp {
    try {
      final dateTime = DateTime.parse(timestamp);
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
          '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return timestamp;
    }
  }
}
