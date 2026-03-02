import '../database/database_helper.dart';
import 'service_locator.dart';

/// Service for managing channel logos
class ChannelLogoService {
  final DatabaseHelper _db;
  static const String _tableName = 'channel_logos';

  // Cache for logo mappings
  final Map<String, String> _logoCache = {};
  final Set<String> _notFoundCache = {};
  bool _isInitialized = false;

  ChannelLogoService(this._db);

  /// Convert network URL to local asset path
  /// Extracts filename from GitHub URL and converts to local asset path
  /// Also converts PNG to WebP format
  String _convertToLocalAsset(String networkUrl) {
    // Extract filename from URL (e.g., Beijing9.png)
    final filename = networkUrl.split('/').last;
    
    // Convert PNG extension to WebP
    final webpFilename = filename.replaceAll('.png', '.webp');
    
    // Return local asset path with WebP extension
    final assetPath = 'assets/icons/img/$webpFilename';
    
    // Debug log
    // ServiceLocator.log.d('[ChannelLogoService] URL转换: $filename → $webpFilename');
    
    return assetPath;
  }

  /// Initialize the service and load cache
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      ServiceLocator.log.d('ChannelLogoService: 开始初始化');
      await _loadCacheFromDatabase();
      _isInitialized = true;
      ServiceLocator.log
          .d('ChannelLogoService: 初始化完成，缓存了 ${_logoCache.length} 条记录');
    } catch (e) {
      ServiceLocator.log.e('ChannelLogoService: 初始化失败: $e');
    }
  }

  /// Load cache from database
  Future<void> _loadCacheFromDatabase() async {
    try {
      final logos = await _db.query(_tableName);
      _logoCache.clear();
      int convertedCount = 0;
      for (final logo in logos) {
        final channelName = logo['channel_name'] as String;
        final logoUrl = logo['logo_url'] as String;
        // Convert network URL to local asset path
        final localAssetPath = _convertToLocalAsset(logoUrl);
        _logoCache[_normalizeChannelName(channelName)] = localAssetPath;
        
        // Log first few conversions for debugging
        if (convertedCount < 5) {
          ServiceLocator.log.d('[ChannelLogoService] 转换示例 #${convertedCount + 1}: $channelName -> $localAssetPath');
        }
        convertedCount++;
      }
      ServiceLocator.log
          .d('ChannelLogoService: 缓存加载完成，共 ${_logoCache.length} 条记录（已转换为本地路径）');
    } catch (e) {
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
        normalized = '${wsMatch.group(1)!}卫视';
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

    if (_logoCache.containsKey(normalized)) {
      return _logoCache[normalized];
    }

    // Check negative cache
    if (_notFoundCache.contains(normalized)) {
      return null;
    }

    // Rely on memory cache for normalized matches.
    // The previous SQL query for "Exact Normalized Match" was redundant
    // because _logoCache is already populated with normalized keys at startup.
    // We proceed to fuzzy matching only if not in cache.

    // Try fuzzy match from database (Only for single lookups, not bulk)
    try {
      final cleanName = _normalizeChannelName(channelName);

      // 仅尝试模糊匹配 (LIKE)
      // 注意：这仍然可能导致全表扫描，但在滚动时不会被调用(因为使用了 findLogoUrlsBulk)
      final results = await _db.rawQuery('''
        SELECT logo_url FROM $_tableName 
        WHERE channel_name LIKE ? OR search_keys LIKE ?
        LIMIT 1
      ''', ['%$cleanName%', '%$cleanName%']);

      if (results.isNotEmpty) {
        final logoUrl = results.first['logo_url'] as String;
        final localAssetPath = _convertToLocalAsset(logoUrl);
        _logoCache[normalized] = localAssetPath;
        return localAssetPath;
      } else {
        // Add to negative cache
        _notFoundCache.add(normalized);
      }
    } catch (e) {
      ServiceLocator.log.w('ChannelLogoService: 查询失败: $e');
    }

    return null;
  }

  /// Batch find logo URLs for multiple channels
  /// Purely memory-based for maximum performance during scrolling
  Future<Map<String, String>> findLogoUrlsBulk(
      List<String> channelNames) async {
    if (!_isInitialized) {
      await initialize();
    }

    final Map<String, String> results = {};
    int foundCount = 0;

    // Check memory cache
    // Since _logoCache contains ALL logos (normalized), we don't need to query DB.
    // DB queries are too slow for bulk operations during scrolling.
    for (final name in channelNames) {
      final normalized = _normalizeChannelName(name);

      if (_logoCache.containsKey(normalized)) {
        results[name] = _logoCache[normalized]!;
        
        // Log first few results for debugging
        if (foundCount < 5) {
          ServiceLocator.log.d('[ChannelLogoService] 批量查询结果 #${foundCount + 1}: $name -> ${_logoCache[normalized]}');
        }
        foundCount++;
      } else {
        // If not in cache, assume not found for bulk operations.
        // We don't update negative cache here to allow potential future fuzzy retries
        // if the user stops scrolling (though currenlty we don't retry).
        // For performance, we treat "Not in Cache" as "No Logo".
        if (!_notFoundCache.contains(normalized)) {
          _notFoundCache.add(normalized);
        }
      }
    }

    ServiceLocator.log.d('[ChannelLogoService] 批量查询完成: ${channelNames.length} 个频道，找到 $foundCount 个台标');
    return results;
  }

  /// Get logo count from database
  Future<int> getLogoCount() async {
    try {
      final result =
          await _db.rawQuery('SELECT COUNT(*) as count FROM $_tableName');
      return result.first['count'] as int;
    } catch (e) {
      return 0;
    }
  }
}
