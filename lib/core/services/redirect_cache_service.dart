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
    final startTime = DateTime.now();
    
    // 清理URL：去掉 $ 及其后面的内容（通常是源标签/备注）
    final cleanUrl = url.split('\$').first.trim();
    
    // 检查协议：只有 HTTP/HTTPS 才进行302检测
    if (!_isHttpProtocol(cleanUrl)) {
      ServiceLocator.log.d('✓ 非HTTP协议，跳过302检查: $cleanUrl');
      return cleanUrl;
    }
    
    // 检查是否是 udpxy URL（udpxy 不支持 HEAD 方法）
    if (_isUdpxyUrl(cleanUrl)) {
      ServiceLocator.log.d('✓ 检测到udpxy URL，跳过302检查: $cleanUrl');
      return cleanUrl;
    }
    
    // 检查是否是直接的流媒体URL，如果是则跳过302检查
    if (_isDirectStreamUrl(cleanUrl)) {
      ServiceLocator.log.d('✓ 检测到直接流媒体URL，跳过302检查: $cleanUrl');
      return cleanUrl;
    }
    
    // 检查缓存（使用清理后的URL作为key）
    final cached = _cache[cleanUrl];
    if (cached != null) {
      final now = DateTime.now();
      if (now.difference(cached.timestamp) < _cacheExpiryDuration) {
        final elapsed = DateTime.now().difference(startTime).inMilliseconds;
        ServiceLocator.log.d('✓ 使用缓存的重定向 (${elapsed}ms): $cleanUrl -> ${cached.realUrl}');
        return cached.realUrl;
      } else {
        // 缓存过期，移除
        _cache.remove(cleanUrl);
        ServiceLocator.log.d('缓存过期，重新解析: $cleanUrl');
      }
    }

    // 递归解析重定向（最多3层）
    final realUrl = await _resolveRedirectRecursive(cleanUrl, 0, startTime);
    
    // 缓存最终结果
    if (realUrl != cleanUrl) {
      _cache[cleanUrl] = _RedirectCacheEntry(realUrl, DateTime.now());
    }
    
    return realUrl;
  }
  
  /// 检查URL是否是HTTP或HTTPS协议
  /// 只有HTTP/HTTPS协议才需要进行302重定向检测
  bool _isHttpProtocol(String url) {
    try {
      final uri = Uri.parse(url);
      final scheme = uri.scheme.toLowerCase();
      return scheme == 'http' || scheme == 'https';
    } catch (e) {
      // 如果URL解析失败，保守起见返回false（不检测302）
      return false;
    }
  }
  
  /// 检查URL是否是 udpxy 代理地址
  /// udpxy 是将 UDP 组播流转换为 HTTP 流的代理服务器
  /// 特征：
  /// - path 格式: /rtp/IPv4:Port 或 /udp/IPv4:Port
  /// - 不支持 HEAD 方法
  /// - 不支持 Range 请求
  /// - 不返回 Content-Length
  /// 
  /// 示例：
  /// - http://192.168.1.1:4022/rtp/225.1.2.142:10870
  /// - http://lysj.aylzline.top:8899/rtp/225.1.2.142:10870
  bool _isUdpxyUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path;
      
      // udpxy 的 path 格式：/rtp/IPv4:Port 或 /udp/IPv4:Port
      // IPv4 格式：xxx.xxx.xxx.xxx (每段 0-255)
      // Port 格式：1-65535
      final udpxyRegex = RegExp(
        r'^/(rtp|udp)/\d{1,3}(\.\d{1,3}){3}:\d+$',
        caseSensitive: false,
      );
      
      return udpxyRegex.hasMatch(path);
    } catch (e) {
      return false;
    }
  }
  
  /// 递归解析重定向
  Future<String> _resolveRedirectRecursive(String url, int depth, DateTime startTime) async {
    const maxDepth = 3; // 最多3层重定向
    
    if (depth >= maxDepth) {
      ServiceLocator.log.w('⚠ 达到最大重定向深度($maxDepth)，停止解析: $url');
      return url;
    }
    
    // 如果当前URL已经是直接流媒体地址，不再继续重定向
    if (depth > 0 && _isDirectStreamUrl(url)) {
      ServiceLocator.log.d('✓ 第${depth}层重定向后检测到直接流媒体URL: $url');
      return url;
    }

    try {
      final connectStartTime = DateTime.now();
      final client = HttpClient();
      client.autoUncompress = true;
      client.connectionTimeout = const Duration(seconds: 2);
      
      final request = await client.getUrl(Uri.parse(url));
      final userAgent = ServiceLocator.settings?.userAgent ?? 'Wget/1.21.3';
      request.headers.set(HttpHeaders.userAgentHeader, userAgent);
      request.followRedirects = false;
      
      ServiceLocator.log.d('HTTP请求 User-Agent: $userAgent', tag: 'RedirectCache');
      
      final response = await request.close().timeout(const Duration(seconds: 2));
      final connectTime = DateTime.now().difference(connectStartTime).inMilliseconds;
      
      final responseCode = response.statusCode;
      ServiceLocator.log.d('第${depth + 1}层 HTTP响应码: $responseCode');
      
      if (responseCode == 403) {
        ServiceLocator.log.w('收到403 Forbidden，可能User-Agent被拒绝');
      }
      
      if (response.isRedirect) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        await response.drain();
        client.close();
        
        if (location != null) {
          final elapsed = DateTime.now().difference(startTime).inMilliseconds;
          ServiceLocator.log.d('✓ 第${depth + 1}层重定向 (${connectTime}ms, 累计:${elapsed}ms)');
          ServiceLocator.log.d('  ${depth + 1}层URL: $url');
          ServiceLocator.log.d('  -> 重定向到: $location');
          
          // 递归解析下一层重定向
          return await _resolveRedirectRecursive(location, depth + 1, startTime);
        }
      }
      
      await response.drain();
      client.close();
      
      final totalTime = DateTime.now().difference(startTime).inMilliseconds;
      if (depth == 0) {
        ServiceLocator.log.d('✓ 无重定向 (${totalTime}ms)，响应码: $responseCode，使用原始URL: $url');
      } else {
        ServiceLocator.log.d('✓ 第${depth + 1}层无重定向 (累计:${totalTime}ms)，最终URL: $url');
      }
      return url;
    } catch (e) {
      final totalTime = DateTime.now().difference(startTime).inMilliseconds;
      ServiceLocator.log.e('✗ 第${depth + 1}层解析失败 (${totalTime}ms): $e');
      return url;
    }
  }
  
  /// 检查URL是否是直接的流媒体地址
  /// 这些格式通常不需要302重定向，可以直接播放
  bool _isDirectStreamUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path.toLowerCase();
      
      // 常见的流媒体文件扩展名
      final streamExtensions = [
        '.m3u8',   // HLS
        '.m3u',    // M3U playlist
        '.ts',     // MPEG-TS
        '.flv',    // Flash Video
        '.mp4',    // MP4
        '.mkv',    // Matroska
        '.avi',    // AVI
        '.mov',    // QuickTime
        '.wmv',    // Windows Media
        '.mpd',    // MPEG-DASH
        '.f4m',    // Flash Manifest
        '.ism',    // Smooth Streaming
        '.webm',   // WebM
      ];
      
      // 检查路径是否以这些扩展名结尾
      return streamExtensions.any((ext) => path.endsWith(ext));
    } catch (e) {
      return false;
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
