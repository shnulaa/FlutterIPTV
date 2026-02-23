import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import '../services/service_locator.dart';

class DatabaseHelper {
  static Database? _database;
  static const String _databaseName = 'flutter_iptv.db';
  static const int _databaseVersion = 8; // Added backup_path and last_backup_time to playlists

  Future<void> initialize() async {
    ServiceLocator.log.d('DatabaseHelper: 开始初始化数据库');
    final startTime = DateTime.now();

    if (_database != null) {
      ServiceLocator.log.d('DatabaseHelper: 数据库已初始化，跳过');
      return;
    }

    // Note: FFI initialization is handled in main.dart

    final Directory appDir = await getApplicationDocumentsDirectory();
    final String path = join(appDir.path, _databaseName);
    ServiceLocator.log.d('DatabaseHelper: 数据库路径: $path');

    _database = await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    // 检查台标表是否为空，如果为空则导入数据
    await _ensureChannelLogosImported();

    final initTime = DateTime.now().difference(startTime).inMilliseconds;
    ServiceLocator.log.d('DatabaseHelper: 数据库初始化完成，耗时: ${initTime}ms');
  }

  /// 确保台标数据已导入
  Future<void> _ensureChannelLogosImported() async {
    try {
      final result = await _database!
          .rawQuery('SELECT COUNT(*) as count FROM channel_logos');
      final count = result.first['count'] as int;

      print('🔍 DatabaseHelper: 台标表当前有 $count 条数据');

      if (count == 0) {
        print('⚠️ DatabaseHelper: 台标表为空，开始导入数据');
        ServiceLocator.log.d('DatabaseHelper: 台标表为空，开始导入数据');
        await _importChannelLogos(_database!);
      } else {
        print('✅ DatabaseHelper: 台标表已有 $count 条数据，跳过导入');
        ServiceLocator.log.d('DatabaseHelper: 台标表已有 $count 条数据，跳过导入');
      }
    } catch (e) {
      print('❌ DatabaseHelper: 检查台标数据失败: $e');
      ServiceLocator.log.e('DatabaseHelper: 检查台标数据失败: $e');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // Playlists table
    await db.execute('''
      CREATE TABLE playlists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        url TEXT,
        file_path TEXT,
        epg_url TEXT,
        is_active INTEGER DEFAULT 1,
        last_updated INTEGER,
        channel_count INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');

    // Channels table
    await db.execute('''
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
        FOREIGN KEY (playlist_id) REFERENCES playlists(id) ON DELETE CASCADE
      )
    ''');

    // Favorites table
    await db.execute('''
      CREATE TABLE favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        channel_id INTEGER NOT NULL,
        position INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (channel_id) REFERENCES channels(id) ON DELETE CASCADE
      )
    ''');

    // Watch history table
    await db.execute('''
      CREATE TABLE watch_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        channel_id INTEGER NOT NULL,
        channel_name TEXT,
        channel_url TEXT,
        playlist_id INTEGER NOT NULL,
        watched_at INTEGER NOT NULL,
        duration_seconds INTEGER DEFAULT 0,
        FOREIGN KEY (channel_id) REFERENCES channels(id) ON DELETE CASCADE,
        FOREIGN KEY (playlist_id) REFERENCES playlists(id) ON DELETE CASCADE
      )
    ''');

    // EPG data table
    await db.execute('''
      CREATE TABLE epg_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        channel_epg_id TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        start_time INTEGER NOT NULL,
        end_time INTEGER NOT NULL,
        category TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    // Create indexes for better performance
    await db
        .execute('CREATE INDEX idx_channels_playlist ON channels(playlist_id)');
    await db.execute('CREATE INDEX idx_channels_group ON channels(group_name)');
    await db
        .execute('CREATE INDEX idx_favorites_channel ON favorites(channel_id)');
    await db.execute(
        'CREATE INDEX idx_history_channel ON watch_history(channel_id)');
    await db.execute(
        'CREATE INDEX idx_history_playlist ON watch_history(playlist_id)');
    await db
        .execute('CREATE INDEX idx_epg_channel ON epg_data(channel_epg_id)');
    await db
        .execute('CREATE INDEX idx_epg_time ON epg_data(start_time, end_time)');

    // Channel logos table
    await db.execute('''
      CREATE TABLE channel_logos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        channel_name TEXT NOT NULL,
        logo_url TEXT NOT NULL,
        search_keys TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_channel_logos_name ON channel_logos(channel_name)');

    // Import channel logos from SQL script
    await _importChannelLogos(db);
  }

  /// Import channel logos from SQL script
  Future<void> _importChannelLogos(Database db) async {
    try {
      print('🔍 DatabaseHelper: 开始导入台标数据');
      ServiceLocator.log.d('DatabaseHelper: 开始导入台标数据');
      final startTime = DateTime.now();

      // Load SQL script from assets
      final sqlScript =
          await rootBundle.loadString('assets/sql/channel_logos.sql');

      // Split into individual statements
      final statements = sqlScript
          .split('\n')
          .where((line) => line.trim().startsWith('INSERT'))
          .toList();

      print('🔍 DatabaseHelper: 准备执行 ${statements.length} 条 SQL 语句');
      ServiceLocator.log
          .d('DatabaseHelper: 准备执行 ${statements.length} 条 SQL 语句');

      // Execute in batches for better performance
      const batchSize = 100;
      for (var i = 0; i < statements.length; i += batchSize) {
        final batch = db.batch();
        final end = (i + batchSize < statements.length)
            ? i + batchSize
            : statements.length;

        for (var j = i; j < end; j++) {
          batch.rawInsert(statements[j]);
        }

        await batch.commit(noResult: true);
      }

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      print(
          '✅ DatabaseHelper: 台标数据导入完成，共 ${statements.length} 条记录，耗时 ${duration}ms');
      ServiceLocator.log.d(
          'DatabaseHelper: 台标数据导入完成，共 ${statements.length} 条记录，耗时 ${duration}ms');
    } catch (e) {
      print('❌ DatabaseHelper: 台标数据导入失败: $e');
      ServiceLocator.log.e('DatabaseHelper: 台标数据导入失败: $e');
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add channel_count column to playlists table
      try {
        await db.execute(
            'ALTER TABLE playlists ADD COLUMN channel_count INTEGER DEFAULT 0');
      } catch (e) {
        // Ignore if column already exists
        ServiceLocator.log.d('Migration error (ignored): $e');
      }
    }
    if (oldVersion < 3) {
      // Add sources column to channels table for multi-source support
      try {
        await db.execute('ALTER TABLE channels ADD COLUMN sources TEXT');
      } catch (e) {
        // Ignore if column already exists
        ServiceLocator.log.d('Migration error (ignored): $e');
      }
    }
    if (oldVersion < 4) {
      // Add epg_url column to playlists table
      try {
        await db.execute('ALTER TABLE playlists ADD COLUMN epg_url TEXT');
      } catch (e) {
        // Ignore if column already exists
        ServiceLocator.log.d('Migration error (ignored): $e');
      }
    }
    if (oldVersion < 5) {
      // Create channel_logos table
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS channel_logos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            channel_name TEXT NOT NULL,
            logo_url TEXT NOT NULL,
            search_keys TEXT,
            created_at INTEGER NOT NULL
          )
        ''');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_channel_logos_name ON channel_logos(channel_name)');

        // Import channel logos data
        await _importChannelLogos(db);
      } catch (e) {
        ServiceLocator.log.d('Migration error (ignored): $e');
      }
    }
    if (oldVersion < 6) {
      // Add playlist_id column to watch_history table
      try {
        await db.execute(
            'ALTER TABLE watch_history ADD COLUMN playlist_id INTEGER');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_history_playlist ON watch_history(playlist_id)');

        // Update existing records to use the first available playlist_id
        final playlists = await db.query('playlists', limit: 1);
        if (playlists.isNotEmpty) {
          final firstPlaylistId = playlists.first['id'];
          await db.update(
            'watch_history',
            {'playlist_id': firstPlaylistId},
            where: 'playlist_id IS NULL',
          );
        }
      } catch (e) {
        ServiceLocator.log.d('Migration error (ignored): $e');
      }
    }
    if (oldVersion < 7) {
      // Add fallback_logo_url column to channels table
      try {
        await db.execute(
            'ALTER TABLE channels ADD COLUMN fallback_logo_url TEXT');
        ServiceLocator.log.i('数据库迁移: 添加 fallback_logo_url 字段到 channels 表');
      } catch (e) {
        ServiceLocator.log.d('Migration error (ignored): $e');
      }
    }
    if (oldVersion < 8) {
      // Add backup_path and last_backup_time columns to playlists table
      try {
        await db.execute(
            'ALTER TABLE playlists ADD COLUMN backup_path TEXT');
        ServiceLocator.log.i('数据库迁移: 添加 backup_path 字段到 playlists 表');
      } catch (e) {
        ServiceLocator.log.d('Migration error (ignored): $e');
      }
      
      try {
        await db.execute(
            'ALTER TABLE playlists ADD COLUMN last_backup_time INTEGER');
        ServiceLocator.log.i('数据库迁移: 添加 last_backup_time 字段到 playlists 表');
      } catch (e) {
        ServiceLocator.log.d('Migration error (ignored): $e');
      }
    }
  }

  Database get db {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }
    return _database!;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  // Generic CRUD operations
  Future<int> insert(String table, Map<String, dynamic> data) async {
    return await db.insert(table, data);
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    return await db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  Future<int> update(
    String table,
    Map<String, dynamic> data, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    return await db.update(table, data, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<List<Map<String, dynamic>>> rawQuery(String sql,
      [List<Object?>? arguments]) async {
    return await db.rawQuery(sql, arguments);
  }

  Batch batch() => db.batch();

  /// Optimize database by reclaiming unused space
  /// This should be called periodically or after large deletions
  Future<void> vacuum() async {
    try {
      ServiceLocator.log.d('开始执行 VACUUM 优化数据库');
      final startTime = DateTime.now();

      await db.execute('VACUUM');

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      ServiceLocator.log.d('VACUUM 完成，耗时: ${duration}ms');
    } catch (e) {
      ServiceLocator.log.e('VACUUM 执行失败', error: e);
      rethrow;
    }
  }

  /// Get database file size in bytes
  Future<int> getDatabaseSize() async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String path = join(appDir.path, _databaseName);
      final file = File(path);

      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (e) {
      ServiceLocator.log.e('获取数据库大小失败', error: e);
      return 0;
    }
  }
}
