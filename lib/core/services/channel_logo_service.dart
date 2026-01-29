import '../database/database_helper.dart';
import 'service_locator.dart';

/// Service for managing channel logos
class ChannelLogoService {
  final DatabaseHelper _db;
  static const String _tableName = 'channel_logos';
  
  // Cache for logo mappings
  final Map<String, String> _logoCache = {};
  bool _isInitialized = false;

  ChannelLogoService(this._db);

  /// Initialize the service and load cache
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      print('🔍 ChannelLogoService: 开始初始化');
      ServiceLocator.log.d('ChannelLogoService: 开始初始化');
      await _loadCacheFromDatabase();
      _isInitialized = true;
      print('✅ ChannelLogoService: 初始化完成，缓存了 ${_logoCache.length} 条记录');
      ServiceLocator.log.d('ChannelLogoService: 初始化完成');
    } catch (e) {
      print('❌ ChannelLogoService: 初始化失败: $e');
      ServiceLocator.log.e('ChannelLogoService: 初始化失败: $e');
    }
  }

  /// Load cache from database
  Future<void> _loadCacheFromDatabase() async {
    try {
      final logos = await _db.query(_tableName);
      _logoCache.clear();
      for (final logo in logos) {
        final channelName = logo['channel_name'] as String;
        final logoUrl = logo['logo_url'] as String;
        _logoCache[_normalizeChannelName(channelName)] = logoUrl;
      }
      print('✅ ChannelLogoService: 缓存加载完成，共 ${_logoCache.length} 条记录');
      ServiceLocator.log.d('ChannelLogoService: 缓存加载完成，共 ${_logoCache.length} 条记录');
    } catch (e) {
      print('❌ ChannelLogoService: 缓存加载失败: $e');
      ServiceLocator.log.e('ChannelLogoService: 缓存加载失败: $e');
    }
  }

  /// Normalize channel name for matching
  String _normalizeChannelName(String name) {
    String normalized = name.toUpperCase();
    
    // 1. 特殊处理：CCTV-01 -> CCTV1, CCTV-1 -> CCTV1
    normalized = normalized.replaceAllMapped(
      RegExp(r'CCTV[-\s]*0*(\d+)'),
      (match) => 'CCTV${match.group(1)}',
    );
    
    // 2. 对于纯英文+数字的频道（如 CCTV1, CCTV5+），提取核心部分，去除后面的中文
    // 匹配模式：字母+数字+可选符号（如+），然后是中文或其他后缀
    final coreMatch = RegExp(r'^([A-Z0-9+]+)').firstMatch(normalized);
    if (coreMatch != null) {
      final core = coreMatch.group(1)!;
      // 如果核心部分包含字母和数字，说明是英文频道，只保留核心部分
      if (RegExp(r'[A-Z]').hasMatch(core) && RegExp(r'[0-9]').hasMatch(core)) {
        normalized = core;
        return normalized;
      }
    }
    
    // 3. 对于中文频道（如 湖南卫视高清），去除常见后缀
    // 去除英文后缀
    normalized = normalized.replaceAll(RegExp(r'(HD|4K|8K|FHD|UHD|SD)'), '');
    
    // 去除中文后缀（匹配末尾的修饰词）
    normalized = normalized.replaceAll(
      RegExp(r'(高清|超清|蓝光|高码率|低码率|标清|频道|卫视高清|卫视超清)$'),
      '',
    );
    
    // 特殊处理：保留"卫视"
    if (!normalized.endsWith('卫视') && name.toUpperCase().contains('卫视')) {
      // 如果原名包含卫视但被去掉了，加回来
      final wsMatch = RegExp(r'(.+?)卫视').firstMatch(name.toUpperCase());
      if (wsMatch != null) {
        normalized = wsMatch.group(1)! + '卫视';
      }
    }
    
    // 4. 去除空格、横线、下划线（保留 + 号）
    normalized = normalized.replaceAll(RegExp(r'[-\s_]+'), '');
    
    return normalized;
  }

  /// Find logo URL for a channel name with fuzzy matching
  Future<String?> findLogoUrl(String channelName) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Try exact match from cache first
    final normalized = _normalizeChannelName(channelName);
    print('🔍 ChannelLogoService: 查询台标 "$channelName" → 规范化为 "$normalized"');
    // 降低日志级别，避免大量输出
    // ServiceLocator.log.d('ChannelLogoService: 查询台标 "$channelName" → 规范化为 "$normalized"');
    
    if (_logoCache.containsKey(normalized)) {
      print('✅ ChannelLogoService: 缓存命中 "$normalized" → ${_logoCache[normalized]}');
      // ServiceLocator.log.d('ChannelLogoService: 缓存命中 "$normalized"');
      return _logoCache[normalized];
    }

    // Try fuzzy match from database
    try {
      final cleanName = _normalizeChannelName(channelName);
      
      // 先尝试精确匹配（规范化后）
      var results = await _db.rawQuery('''
        SELECT logo_url FROM $_tableName 
        WHERE UPPER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
          REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
            channel_name, 
            '高码率', ''), '低码率', ''), '超清', ''), '蓝光', ''), 
            '高清', ''), '标清', ''), 'HD', ''), '4K', ''), '8K', ''), 
            'FHD', ''), 'UHD', ''), '-', ''), ' ', ''), '_', '')) = ?
        LIMIT 1
      ''', [cleanName]);
      
      // 如果精确匹配失败，尝试模糊匹配
      if (results.isEmpty) {
        results = await _db.rawQuery('''
          SELECT logo_url FROM $_tableName 
          WHERE UPPER(REPLACE(REPLACE(REPLACE(channel_name, '-', ''), ' ', ''), '_', '')) LIKE ?
             OR UPPER(REPLACE(REPLACE(REPLACE(search_keys, '-', ''), ' ', ''), '_', '')) LIKE ?
          LIMIT 1
        ''', ['%$cleanName%', '%$cleanName%']);
      }
      
      if (results.isNotEmpty) {
        final logoUrl = results.first['logo_url'] as String;
        print('✅ ChannelLogoService: 数据库匹配成功 "$channelName" → "$logoUrl"');
        // ServiceLocator.log.d('ChannelLogoService: 数据库匹配成功 "$channelName" → "$logoUrl"');
        // Cache the result
        _logoCache[normalized] = logoUrl;
        return logoUrl;
      } else {
        print('⚠️ ChannelLogoService: 未找到台标 "$channelName" (规范化: "$normalized")');
        // ServiceLocator.log.w('ChannelLogoService: 未找到台标 "$channelName" (规范化: "$normalized")');
      }
    } catch (e) {
      print('❌ ChannelLogoService: 查询失败: $e');
      ServiceLocator.log.w('ChannelLogoService: 查询失败: $e');
    }

    return null;
  }

  /// Get logo count from database
  Future<int> getLogoCount() async {
    try {
      final result = await _db.rawQuery('SELECT COUNT(*) as count FROM $_tableName');
      return result.first['count'] as int;
    } catch (e) {
      return 0;
    }
  }
}
