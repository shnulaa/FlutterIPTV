# Catchup 功能数据库设计文档

## 1. 数据库变更概述

### 1.1 需要修改的表

✅ **channels 表** - 需要添加 Catchup 配置字段

### 1.2 需要新增的表

✅ **catchup_configs 表** - 存储 Catchup 配置（可选，如果不想修改 channels 表）  
✅ **epg_programs 表** - 存储详细的节目单数据（扩展现有 epg_data 表）  
✅ **catchup_watch_history 表** - 存储回看观看历史  
✅ **epg_sources 表** - 管理 EPG 数据源

---

## 2. 数据库变更方案

### 方案 A：修改现有 channels 表（推荐）

**优点：**
- 结构简单，查询效率高
- 减少表关联
- 易于维护

**缺点：**
- 需要数据库迁移
- 字段较多

### 方案 B：新增 catchup_configs 表

**优点：**
- 不影响现有表结构
- 灵活性高
- 可选功能独立

**缺点：**
- 需要额外的表关联
- 查询稍复杂

**推荐：方案 A（修改 channels 表）**

---

## 3. 详细表结构设计

### 3.1 修改 channels 表


```sql
-- 原有字段保持不变
CREATE TABLE channels (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  playlist_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  url TEXT NOT NULL,
  sources TEXT,
  logo_url TEXT,
  fallback_logo_url TEXT,
  group_name TEXT,
  epg_id TEXT,
  is_active INTEGER DEFAULT 1,
  created_at INTEGER NOT NULL,
  
  -- 新增 Catchup 相关字段
  catchup_enabled INTEGER DEFAULT 0,           -- 是否启用回看 (0/1)
  catchup_type TEXT,                           -- 回看类型: append/default/shift/flussonic/xc
  catchup_source TEXT,                         -- 回看源模板
  catchup_days INTEGER DEFAULT 7,              -- 可回看天数
  catchup_is_global INTEGER DEFAULT 0,         -- 是否来自全局配置 (0/1)
  
  FOREIGN KEY (playlist_id) REFERENCES playlists(id) ON DELETE CASCADE
);

-- 添加索引
CREATE INDEX idx_channels_catchup ON channels(catchup_enabled);
```

**迁移 SQL（版本升级）：**

```sql
-- 数据库版本 2 -> 3
ALTER TABLE channels ADD COLUMN catchup_enabled INTEGER DEFAULT 0;
ALTER TABLE channels ADD COLUMN catchup_type TEXT;
ALTER TABLE channels ADD COLUMN catchup_source TEXT;
ALTER TABLE channels ADD COLUMN catchup_days INTEGER DEFAULT 7;
ALTER TABLE channels ADD COLUMN catchup_is_global INTEGER DEFAULT 0;

CREATE INDEX idx_channels_catchup ON channels(catchup_enabled);
```


### 3.2 扩展 epg_data 表为 epg_programs 表

```sql
-- 保留原有 epg_data 表，新增更详细的 epg_programs 表
CREATE TABLE epg_programs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  channel_id INTEGER NOT NULL,                 -- 关联 channels 表
  channel_epg_id TEXT NOT NULL,                -- EPG ID (tvg-id)
  title TEXT NOT NULL,                         -- 节目标题
  sub_title TEXT,                              -- 副标题
  description TEXT,                            -- 节目描述
  start_time INTEGER NOT NULL,                 -- 开始时间 (Unix timestamp)
  end_time INTEGER NOT NULL,                   -- 结束时间 (Unix timestamp)
  duration INTEGER NOT NULL,                   -- 持续时间（秒）
  category TEXT,                               -- 分类
  icon_url TEXT,                               -- 节目图标/海报
  rating TEXT,                                 -- 评级
  episode_num TEXT,                            -- 集数信息
  season_num TEXT,                             -- 季数信息
  is_catchup_available INTEGER DEFAULT 1,      -- 是否可回看
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  
  FOREIGN KEY (channel_id) REFERENCES channels(id) ON DELETE CASCADE
);

-- 索引
CREATE INDEX idx_epg_programs_channel ON epg_programs(channel_id);
CREATE INDEX idx_epg_programs_epg_id ON epg_programs(channel_epg_id);
CREATE INDEX idx_epg_programs_time ON epg_programs(start_time, end_time);
CREATE INDEX idx_epg_programs_catchup ON epg_programs(is_catchup_available);
```

### 3.3 新增 catchup_watch_history 表

```sql
CREATE TABLE catchup_watch_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  channel_id INTEGER NOT NULL,
  program_id INTEGER NOT NULL,                 -- 关联 epg_programs
  channel_name TEXT NOT NULL,
  program_title TEXT NOT NULL,
  program_start_time INTEGER NOT NULL,         -- 节目原始开始时间
  program_end_time INTEGER NOT NULL,           -- 节目原始结束时间
  watched_at INTEGER NOT NULL,                 -- 观看时间
  watch_position INTEGER DEFAULT 0,            -- 观看位置（秒）
  watch_duration INTEGER DEFAULT 0,            -- 观看时长（秒）
  completed INTEGER DEFAULT 0,                 -- 是否看完 (0/1)
  catchup_url TEXT,                            -- 生成的回看 URL
  created_at INTEGER NOT NULL,
  
  FOREIGN KEY (channel_id) REFERENCES channels(id) ON DELETE CASCADE,
  FOREIGN KEY (program_id) REFERENCES epg_programs(id) ON DELETE CASCADE
);

-- 索引
CREATE INDEX idx_catchup_history_channel ON catchup_watch_history(channel_id);
CREATE INDEX idx_catchup_history_program ON catchup_watch_history(program_id);
CREATE INDEX idx_catchup_history_watched ON catchup_watch_history(watched_at);
```


### 3.4 新增 epg_sources 表

```sql
CREATE TABLE epg_sources (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,                          -- EPG 源名称
  url TEXT NOT NULL,                           -- EPG 数据 URL
  type TEXT DEFAULT 'xmltv',                   -- 类型: xmltv/json/api
  is_active INTEGER DEFAULT 1,                 -- 是否启用
  last_updated INTEGER,                        -- 最后更新时间
  update_interval INTEGER DEFAULT 86400,       -- 更新间隔（秒，默认24小时）
  auto_update INTEGER DEFAULT 1,               -- 是否自动更新
  program_count INTEGER DEFAULT 0,             -- 节目数量
  created_at INTEGER NOT NULL
);

-- 索引
CREATE INDEX idx_epg_sources_active ON epg_sources(is_active);
```

### 3.5 新增 playlists 表字段（全局 Catchup 配置）

```sql
-- 修改 playlists 表，添加全局 Catchup 配置
ALTER TABLE playlists ADD COLUMN global_catchup_enabled INTEGER DEFAULT 0;
ALTER TABLE playlists ADD COLUMN global_catchup_type TEXT;
ALTER TABLE playlists ADD COLUMN global_catchup_source TEXT;
ALTER TABLE playlists ADD COLUMN global_catchup_days INTEGER DEFAULT 7;
```

---

## 4. 数据模型（Dart）

### 4.1 Channel 模型扩展

```dart
class Channel {
  final int? id;
  final int playlistId;
  final String name;
  final String url;
  final String? sources;
  final String? logoUrl;
  final String? fallbackLogoUrl;
  final String? groupName;
  final String? epgId;
  final bool isActive;
  final int createdAt;
  
  // Catchup 字段
  final bool catchupEnabled;
  final String? catchupType;
  final String? catchupSource;
  final int? catchupDays;
  final bool catchupIsGlobal;
  
  Channel({
    this.id,
    required this.playlistId,
    required this.name,
    required this.url,
    this.sources,
    this.logoUrl,
    this.fallbackLogoUrl,
    this.groupName,
    this.epgId,
    this.isActive = true,
    required this.createdAt,
    this.catchupEnabled = false,
    this.catchupType,
    this.catchupSource,
    this.catchupDays = 7,
    this.catchupIsGlobal = false,
  });
  
  // 从数据库映射
  factory Channel.fromMap(Map<String, dynamic> map) {
    return Channel(
      id: map['id'],
      playlistId: map['playlist_id'],
      name: map['name'],
      url: map['url'],
      sources: map['sources'],
      logoUrl: map['logo_url'],
      fallbackLogoUrl: map['fallback_logo_url'],
      groupName: map['group_name'],
      epgId: map['epg_id'],
      isActive: map['is_active'] == 1,
      createdAt: map['created_at'],
      catchupEnabled: map['catchup_enabled'] == 1,
      catchupType: map['catchup_type'],
      catchupSource: map['catchup_source'],
      catchupDays: map['catchup_days'],
      catchupIsGlobal: map['catchup_is_global'] == 1,
    );
  }
  
  // 转换为数据库映射
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'playlist_id': playlistId,
      'name': name,
      'url': url,
      'sources': sources,
      'logo_url': logoUrl,
      'fallback_logo_url': fallbackLogoUrl,
      'group_name': groupName,
      'epg_id': epgId,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
      'catchup_enabled': catchupEnabled ? 1 : 0,
      'catchup_type': catchupType,
      'catchup_source': catchupSource,
      'catchup_days': catchupDays,
      'catchup_is_global': catchupIsGlobal ? 1 : 0,
    };
  }
}
```


### 4.2 EpgProgram 模型

```dart
class EpgProgram {
  final int? id;
  final int channelId;
  final String channelEpgId;
  final String title;
  final String? subTitle;
  final String? description;
  final int startTime;
  final int endTime;
  final int duration;
  final String? category;
  final String? iconUrl;
  final String? rating;
  final String? episodeNum;
  final String? seasonNum;
  final bool isCatchupAvailable;
  final int createdAt;
  final int updatedAt;
  
  EpgProgram({
    this.id,
    required this.channelId,
    required this.channelEpgId,
    required this.title,
    this.subTitle,
    this.description,
    required this.startTime,
    required this.endTime,
    required this.duration,
    this.category,
    this.iconUrl,
    this.rating,
    this.episodeNum,
    this.seasonNum,
    this.isCatchupAvailable = true,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory EpgProgram.fromMap(Map<String, dynamic> map) {
    return EpgProgram(
      id: map['id'],
      channelId: map['channel_id'],
      channelEpgId: map['channel_epg_id'],
      title: map['title'],
      subTitle: map['sub_title'],
      description: map['description'],
      startTime: map['start_time'],
      endTime: map['end_time'],
      duration: map['duration'],
      category: map['category'],
      iconUrl: map['icon_url'],
      rating: map['rating'],
      episodeNum: map['episode_num'],
      seasonNum: map['season_num'],
      isCatchupAvailable: map['is_catchup_available'] == 1,
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'channel_id': channelId,
      'channel_epg_id': channelEpgId,
      'title': title,
      'sub_title': subTitle,
      'description': description,
      'start_time': startTime,
      'end_time': endTime,
      'duration': duration,
      'category': category,
      'icon_url': iconUrl,
      'rating': rating,
      'episode_num': episodeNum,
      'season_num': seasonNum,
      'is_catchup_available': isCatchupAvailable ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
  
  // 辅助方法
  bool get isLive {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now >= startTime && now <= endTime;
  }
  
  bool get isPast {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now > endTime;
  }
  
  bool get isFuture {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now < startTime;
  }
}
```

### 4.3 CatchupWatchHistory 模型

```dart
class CatchupWatchHistory {
  final int? id;
  final int channelId;
  final int programId;
  final String channelName;
  final String programTitle;
  final int programStartTime;
  final int programEndTime;
  final int watchedAt;
  final int watchPosition;
  final int watchDuration;
  final bool completed;
  final String? catchupUrl;
  final int createdAt;
  
  CatchupWatchHistory({
    this.id,
    required this.channelId,
    required this.programId,
    required this.channelName,
    required this.programTitle,
    required this.programStartTime,
    required this.programEndTime,
    required this.watchedAt,
    this.watchPosition = 0,
    this.watchDuration = 0,
    this.completed = false,
    this.catchupUrl,
    required this.createdAt,
  });
  
  factory CatchupWatchHistory.fromMap(Map<String, dynamic> map) {
    return CatchupWatchHistory(
      id: map['id'],
      channelId: map['channel_id'],
      programId: map['program_id'],
      channelName: map['channel_name'],
      programTitle: map['program_title'],
      programStartTime: map['program_start_time'],
      programEndTime: map['program_end_time'],
      watchedAt: map['watched_at'],
      watchPosition: map['watch_position'] ?? 0,
      watchDuration: map['watch_duration'] ?? 0,
      completed: map['completed'] == 1,
      catchupUrl: map['catchup_url'],
      createdAt: map['created_at'],
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'channel_id': channelId,
      'program_id': programId,
      'channel_name': channelName,
      'program_title': programTitle,
      'program_start_time': programStartTime,
      'program_end_time': programEndTime,
      'watched_at': watchedAt,
      'watch_position': watchPosition,
      'watch_duration': watchDuration,
      'completed': completed ? 1 : 0,
      'catchup_url': catchupUrl,
      'created_at': createdAt,
    };
  }
}
```

---

## 5. 数据库迁移策略

### 5.1 版本管理

```dart
class DatabaseHelper {
  static const int _currentVersion = 3;  // 从 2 升级到 3
  
  Future<Database> _initDatabase() async {
    return await openDatabase(
      _databasePath,
      version: _currentVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }
  
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await _upgradeToV3(db);
    }
  }
  
  Future<void> _upgradeToV3(Database db) async {
    // 添加 Catchup 字段到 channels 表
    await db.execute(
      'ALTER TABLE channels ADD COLUMN catchup_enabled INTEGER DEFAULT 0'
    );
    await db.execute(
      'ALTER TABLE channels ADD COLUMN catchup_type TEXT'
    );
    await db.execute(
      'ALTER TABLE channels ADD COLUMN catchup_source TEXT'
    );
    await db.execute(
      'ALTER TABLE channels ADD COLUMN catchup_days INTEGER DEFAULT 7'
    );
    await db.execute(
      'ALTER TABLE channels ADD COLUMN catchup_is_global INTEGER DEFAULT 0'
    );
    
    // 创建索引
    await db.execute(
      'CREATE INDEX idx_channels_catchup ON channels(catchup_enabled)'
    );
    
    // 创建新表
    await _createEpgProgramsTable(db);
    await _createCatchupWatchHistoryTable(db);
    await _createEpgSourcesTable(db);
    
    // 添加 playlists 表字段
    await db.execute(
      'ALTER TABLE playlists ADD COLUMN global_catchup_enabled INTEGER DEFAULT 0'
    );
    await db.execute(
      'ALTER TABLE playlists ADD COLUMN global_catchup_type TEXT'
    );
    await db.execute(
      'ALTER TABLE playlists ADD COLUMN global_catchup_source TEXT'
    );
    await db.execute(
      'ALTER TABLE playlists ADD COLUMN global_catchup_days INTEGER DEFAULT 7'
    );
  }
}
```

### 5.2 数据迁移注意事项

1. **备份数据**：升级前自动备份数据库
2. **渐进式迁移**：分步骤执行，每步验证
3. **回滚机制**：失败时恢复到旧版本
4. **兼容性**：保持向后兼容，旧数据仍可用

---

## 6. 查询优化

### 6.1 常用查询

```dart
// 获取支持 Catchup 的频道
Future<List<Channel>> getCatchupEnabledChannels() async {
  final db = await database;
  final maps = await db.query(
    'channels',
    where: 'catchup_enabled = ?',
    whereArgs: [1],
  );
  return maps.map((map) => Channel.fromMap(map)).toList();
}

// 获取频道的节目列表（指定日期）
Future<List<EpgProgram>> getProgramsByDate(
  int channelId,
  DateTime date,
) async {
  final db = await database;
  final startOfDay = DateTime(date.year, date.month, date.day);
  final endOfDay = startOfDay.add(Duration(days: 1));
  
  final maps = await db.query(
    'epg_programs',
    where: 'channel_id = ? AND start_time >= ? AND start_time < ?',
    whereArgs: [
      channelId,
      startOfDay.millisecondsSinceEpoch ~/ 1000,
      endOfDay.millisecondsSinceEpoch ~/ 1000,
    ],
    orderBy: 'start_time ASC',
  );
  
  return maps.map((map) => EpgProgram.fromMap(map)).toList();
}

// 获取当前正在播放的节目
Future<EpgProgram?> getCurrentProgram(int channelId) async {
  final db = await database;
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  
  final maps = await db.query(
    'epg_programs',
    where: 'channel_id = ? AND start_time <= ? AND end_time >= ?',
    whereArgs: [channelId, now, now],
    limit: 1,
  );
  
  if (maps.isEmpty) return null;
  return EpgProgram.fromMap(maps.first);
}

// 清理过期的 EPG 数据
Future<void> cleanupOldEpgData(int daysToKeep) async {
  final db = await database;
  final cutoffTime = DateTime.now()
      .subtract(Duration(days: daysToKeep))
      .millisecondsSinceEpoch ~/ 1000;
  
  await db.delete(
    'epg_programs',
    where: 'end_time < ?',
    whereArgs: [cutoffTime],
  );
}
```

---

## 7. 总结

### 数据库变更清单

✅ **修改表：**
- `channels` 表：添加 5 个 Catchup 字段
- `playlists` 表：添加 4 个全局 Catchup 字段

✅ **新增表：**
- `epg_programs` 表：详细节目单数据
- `catchup_watch_history` 表：回看观看历史
- `epg_sources` 表：EPG 数据源管理

✅ **新增索引：**
- 6 个新索引优化查询性能

✅ **数据库版本：**
- 从版本 2 升级到版本 3

### 影响评估

- **存储空间**：预计增加 20-30% （主要是 EPG 数据）
- **查询性能**：通过索引优化，影响可忽略
- **迁移时间**：小于 1 秒（对于普通数据量）
- **兼容性**：完全向后兼容
