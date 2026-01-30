import 'dart:io';
import 'service_locator.dart';

/// 重定向URL缓存条目
class _RedirectCacheEntry {
  final String realUrl;
  final DateTime timestamp;
  
  _RedirectCacheEntry(this.realUrl, this.timestamp);
}

/// 全局重定向缓存服务
/// 用于缓存HTTP 302重定向的真实播放地址
class RedirectCacheService {
  static final RedirectCacheService _instance = RedirectCacheService._internal();
  factory RedirectCacheService() => _instance;
  RedirectCacheService._internal();

  final Map<String, _RedirectCacheEntry> _cache = {};
  static const _cacheExpiryDuration = Duration(hours: 24); // 24小时过期

  /// 解析真实播放地址（处理302重定向，带缓存）
  Future<String> resolveRealPlayUrl(String url) async {
    // 检查缓存
    final cached = _cache[url];
    if (cached != null) {
      final now = DateTime.now();
      if (now.difference(cached.timestamp) < _cacheExpiryDuration) {
        ServiceLocator.log.d('使用缓存的重定向: $url -> ${cached.realUrl}');
        return cached.realUrl;
      } else {
        // 缓存过期，移除
        _cache.remove(url);
        ServiceLocator.log.d('缓存过期，重新解析: $url');
      }
    }

    // 解析重定向
    try {
      final client = HttpClient();
      client.autoUncompress = true;
      
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set(HttpHeaders.userAgentHeader, 'miguvideo_android');
      
      // 不自动跟随重定向，手动获取 Location
      request.followRedirects = false;
      
      final response = await request.close();
      
      if (response.isRedirect) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        if (location != null) {
          ServiceLocator.log.d('解析重定向: $url -> $location');
          await response.drain();
          client.close();
          
          // 缓存结果
          _cache[url] = _RedirectCacheEntry(location, DateTime.now());
          
          return location;
        }
      }
      
      await response.drain();
      client.close();
      
      // 如果没有重定向，返回原始 URL（不缓存）
      ServiceLocator.log.d('无重定向，使用原始 URL: $url');
      return url;
    } catch (e) {
      ServiceLocator.log.e('解析播放地址失败: $e');
      // 失败时返回原始 URL
      return url;
    }
  }

  /// 清除指定URL的缓存
  void clearCache(String url) {
    _cache.remove(url);
    ServiceLocator.log.d('清除缓存: $url');
  }

  /// 清除所有缓存
  void clearAllCache() {
    _cache.clear();
    ServiceLocator.log.d('清除所有重定向缓存');
  }

  /// 清除过期缓存
  void clearExpiredCache() {
    final now = DateTime.now();
    _cache.removeWhere((url, entry) {
      final expired = now.difference(entry.timestamp) >= _cacheExpiryDuration;
      if (expired) {
        ServiceLocator.log.d('清除过期缓存: $url');
      }
      return expired;
    });
  }

  /// 获取缓存统计信息
  Map<String, dynamic> getCacheStats() {
    return {
      'total': _cache.length,
      'entries': _cache.entries.map((e) {
        final age = DateTime.now().difference(e.value.timestamp);
        return {
          'url': e.key,
          'realUrl': e.value.realUrl,
          'age': '${age.inMinutes}分钟',
        };
      }).toList(),
    };
  }
}
