/// Represents an IPTV playlist (M3U/M3U8/TXT source)
class Playlist {
  final int? id;
  final String name;
  final String? url;
  final String? filePath;
  final String? epgUrl; // EPG URL extracted from M3U header
  final bool isActive;
  final DateTime? lastUpdated;
  final DateTime createdAt;
  final String? backupPath; // 备份文件路径
  final DateTime? lastBackupTime; // 最后备份时间

  // Runtime properties
  int channelCount;
  int groupCount;

  Playlist({
    this.id,
    required this.name,
    this.url,
    this.filePath,
    this.epgUrl,
    this.isActive = true,
    this.lastUpdated,
    DateTime? createdAt,
    this.channelCount = 0,
    this.groupCount = 0,
    this.backupPath,
    this.lastBackupTime,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Playlist.fromMap(Map<String, dynamic> map) {
    return Playlist(
      id: map['id'] as int?,
      name: map['name'] as String,
      url: map['url'] as String?,
      filePath: map['file_path'] as String?,
      epgUrl: map['epg_url'] as String?,
      isActive: (map['is_active'] as int?) == 1,
      lastUpdated: map['last_updated'] != null ? DateTime.fromMillisecondsSinceEpoch(map['last_updated'] as int) : null,
      createdAt: map['created_at'] != null ? DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int) : DateTime.now(),
      backupPath: map['backup_path'] as String?,
      lastBackupTime: map['last_backup_time'] != null ? DateTime.fromMillisecondsSinceEpoch(map['last_backup_time'] as int) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'url': url,
      'file_path': filePath,
      'epg_url': epgUrl,
      'is_active': isActive ? 1 : 0,
      'last_updated': lastUpdated?.millisecondsSinceEpoch,
      'created_at': createdAt.millisecondsSinceEpoch,
      'backup_path': backupPath,
      'last_backup_time': lastBackupTime?.millisecondsSinceEpoch,
    };
  }

  Playlist copyWith({
    int? id,
    String? name,
    String? url,
    String? filePath,
    String? epgUrl,
    bool? isActive,
    DateTime? lastUpdated,
    DateTime? createdAt,
    int? channelCount,
    int? groupCount,
    String? backupPath,
    DateTime? lastBackupTime,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      filePath: filePath ?? this.filePath,
      epgUrl: epgUrl ?? this.epgUrl,
      isActive: isActive ?? this.isActive,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      createdAt: createdAt ?? this.createdAt,
      channelCount: channelCount ?? this.channelCount,
      groupCount: groupCount ?? this.groupCount,
      backupPath: backupPath ?? this.backupPath,
      lastBackupTime: lastBackupTime ?? this.lastBackupTime,
    );
  }

  /// Check if this is a remote playlist (URL-based)
  bool get isRemote => url != null && url!.isNotEmpty;

  /// Check if this is a local playlist (file-based)
  bool get isLocal => filePath != null && filePath!.isNotEmpty;

  /// Check if this is a temporary playlist (imported via QR)
  bool get isTemporary => filePath != null && filePath!.contains('temp') && filePath!.contains('playlist_');
  
  /// Check if playlist has a backup file
  bool get hasBackup => backupPath != null && backupPath!.isNotEmpty;

  /// Get the source path (URL or file path)
  String get sourcePath => url ?? filePath ?? '';

  /// Get the playlist format (M3U or TXT)
  String get format {
    final source = sourcePath.toLowerCase();
    if (source.endsWith('.txt')) {
      return 'TXT';
    } else if (source.endsWith('.m3u') || source.endsWith('.m3u8')) {
      return 'M3U';
    }
    // 默认返回 M3U
    return 'M3U';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Playlist && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Playlist(id: $id, name: $name, channels: $channelCount)';
}
