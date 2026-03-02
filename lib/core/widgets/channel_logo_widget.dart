import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as io_client;
import 'dart:io';
import '../models/channel.dart';
import '../services/service_locator.dart';
import '../utils/throttled_state_mixin.dart';

// ========================================
// ✅ 台标加载性能配置 - 可随意调整这些参数
// ========================================
//
// 调优指南：
// 1. maxConnectionsPerHost (10): 每个主机的最大连接数
//    - 增加：加快加载速度，但可能导致服务器拒绝连接
//    - 减少：更稳定，但加载较慢
//
// 2. connectionTimeout (3s): 连接超时时间
//    - 增加：给慢速服务器更多时间，但失败时等待更久
//    - 减少：快速失败，但可能错过慢速但可用的台标
//
// 3. idleTimeout (30s): 空闲连接保持时间
//    - 增加：更好的连接复用，减少握手开销
//    - 减少：更快释放资源
//
// 4. maxConcurrentLoads (15): 最大并发加载数
//    - 增加：加载更快，但可能导致UI卡顿
//    - 减少：更流畅，但加载较慢
//
// 5. maxQueueSize (30): 最大队列大小
//    - 增加：滚动时缓存更多请求
//    - 减少：减少内存占用
//
// ========================================

/// HTTP 连接池配置
class _HttpPoolConfig {
  static const int maxConnectionsPerHost = 50; // 每个主机最多连接数
  static const Duration connectionTimeout = Duration(seconds: 5); // 连接超时
  static const Duration idleTimeout = Duration(seconds: 30); // 空闲连接保持时间
}

/// 台标加载并发控制配置
class _LogoLoadConfig {
  static const int maxConcurrentLoads = 50; // 最大并发加载数
  static const int maxQueueSize = 1000; // 最大队列大小
}

// ========================================

/// ✅ HTTP连接池：复用连接，减少TCP握手开销
class _HttpConnectionPool {
  static final _HttpConnectionPool _instance = _HttpConnectionPool._();
  factory _HttpConnectionPool() => _instance;
  _HttpConnectionPool._();

  HttpClient? _httpClient;
  io_client.IOClient? _ioClient;
  bool _initialized = false;

  void initialize() {
    if (_initialized) {
      ServiceLocator.log.d('[HttpPool] 连接池已经初始化，跳过');
      return;
    }

    _httpClient = HttpClient()
      ..connectionTimeout = _HttpPoolConfig.connectionTimeout
      ..idleTimeout = _HttpPoolConfig.idleTimeout
      ..maxConnectionsPerHost = _HttpPoolConfig.maxConnectionsPerHost
      ..autoUncompress = true
      ..userAgent = 'FlutterIPTV/1.0';

    _ioClient = io_client.IOClient(_httpClient!);
    _initialized = true;
    ServiceLocator.log.i(
        '[HttpPool] 连接池已初始化 - 每主机最大连接数: ${_HttpPoolConfig.maxConnectionsPerHost}, 连接超时: ${_HttpPoolConfig.connectionTimeout.inSeconds}s, 空闲超时: ${_HttpPoolConfig.idleTimeout.inSeconds}s');
  }

  io_client.IOClient get client {
    if (!_initialized || _ioClient == null) {
      ServiceLocator.log.w('[HttpPool] 连接池未初始化，立即初始化');
      initialize();
    }
    return _ioClient!;
  }

  void dispose() {
    if (_httpClient != null) {
      _httpClient!.close(force: true);
      _initialized = false;
      ServiceLocator.log.i('[HttpPool] 连接池已关闭');
    }
  }
}

/// Custom HTTP client with timeout and connection pooling for logo loading
class _TimeoutHttpClient extends http.BaseClient {
  final io_client.IOClient _pooledClient;
  final Duration timeout;

  _TimeoutHttpClient({
    required io_client.IOClient pooledClient,
    this.timeout = const Duration(seconds: 3),
  }) : _pooledClient = pooledClient;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _pooledClient.send(request).timeout(timeout);
  }

  @override
  void close() {
    // 不关闭连接池，让它保持复用
  }
}

/// Custom cache manager with short timeout for logo loading
class LogoCacheManager extends CacheManager {
  static const key = 'logoCache';
  static LogoCacheManager? _instance;

  factory LogoCacheManager() {
    _instance ??= LogoCacheManager._();
    return _instance!;
  }

  LogoCacheManager._()
      : super(
          Config(
            key,
            stalePeriod: const Duration(days: 7),
            maxNrOfCacheObjects: 500,
            repo: JsonCacheInfoRepository(databaseName: key),
            fileService: HttpFileService(
              httpClient: _TimeoutHttpClient(
                pooledClient: _HttpConnectionPool().client,
                timeout: _HttpPoolConfig.connectionTimeout,
              ),
            ),
          ),
        ) {
    // 初始化连接池
    _HttpConnectionPool().initialize();
    ServiceLocator.log.i('[LogoCache] 缓存管理器已初始化，使用连接池');
  }
}

/// Global logo state manager to persist logo loading states across widget rebuilds
class _LogoStateManager {
  static final _LogoStateManager _instance = _LogoStateManager._();
  factory _LogoStateManager() => _instance;
  _LogoStateManager._();

  // 记录 M3U 台标失败的频道（使用频道名称作为 key）
  final Map<String, bool> _m3uLogoFailed = {};

  // 记录数据库台标 URL（使用频道名称作为 key）
  final Map<String, String?> _fallbackLogoUrls = {};

  // 记录已经尝试加载过的频道（即使结果为 null 也不再重试）
  final Set<String> _fallbackLoaded = {};

  // 正在加载 fallback 的频道
  final Set<String> _loadingFallback = {};

  // ✅ 全局滚动状态：滚动时暂停台标加载
  bool _isScrolling = false;
  final ValueNotifier<bool> scrollingNotifier = ValueNotifier(false);

  // 并发控制：限制同时加载的台标数量
  static const int _maxConcurrentLoads = _LogoLoadConfig.maxConcurrentLoads;
  static const int _maxQueueSize = _LogoLoadConfig.maxQueueSize;
  int _currentLoadingCount = 0;
  final List<Function> _pendingLoads = [];

  bool get isScrolling => _isScrolling;

  void setScrolling(bool scrolling) {
    if (_isScrolling != scrolling) {
      _isScrolling = scrolling;
      scrollingNotifier.value = scrolling;
      // ServiceLocator.log.d(
      //     '[LogoState] 滚动状态变化: ${scrolling ? "开始滚动" : "停止滚动"}, 队列: ${_pendingLoads.length}/$_maxQueueSize, 并发: $_currentLoadingCount/$_maxConcurrentLoads');

      if (!scrolling) {
        // 滚动停止后，处理一些待加载的台标
        _processNextPendingLoad();
      }
    }
  }

  bool isM3uLogoFailed(String channelName) {
    return _m3uLogoFailed[channelName] ?? false;
  }

  void markM3uLogoFailed(String channelName) {
    _m3uLogoFailed[channelName] = true;
  }

  String? getFallbackLogoUrl(String channelName) {
    return _fallbackLogoUrls[channelName];
  }

  void setFallbackLogoUrl(String channelName, String? url) {
    _fallbackLogoUrls[channelName] = url;
    _fallbackLoaded.add(channelName); // 标记已加载
  }

  bool isFallbackLoaded(String channelName) {
    return _fallbackLoaded.contains(channelName);
  }

  bool isLoadingFallback(String channelName) {
    return _loadingFallback.contains(channelName);
  }

  void markLoadingFallback(String channelName, bool loading) {
    if (loading) {
      _loadingFallback.add(channelName);
    } else {
      _loadingFallback.remove(channelName);
    }
  }

  /// 请求加载 fallback logo，如果超过并发限制则排队
  Future<void> requestLoadFallback(Function loadFunction) async {
    // ✅ 滚动时不加载台标，直接加入队列（但限制队列大小）
    if (_isScrolling) {
      if (_pendingLoads.length >= _maxQueueSize) {
        // ServiceLocator.log.d(
        //     '[LogoState] 滚动中且队列已满(${_pendingLoads.length}/$_maxQueueSize)，丢弃请求');
        return;
      }
      // ServiceLocator.log.d(
      //     '[LogoState] 滚动中，加入队列，当前队列: ${_pendingLoads.length}/$_maxQueueSize');
      _pendingLoads.add(loadFunction);
      return;
    }

    if (_currentLoadingCount < _maxConcurrentLoads) {
      // ServiceLocator.log.d(
      //     '[LogoState] 开始加载，当前并发: $_currentLoadingCount/$_maxConcurrentLoads');
      _currentLoadingCount++;
      try {
        await loadFunction();
      } finally {
        _currentLoadingCount--;
        // ServiceLocator.log.d(
        //     '[LogoState] 加载完成，当前并发: $_currentLoadingCount/$_maxConcurrentLoads');
        _processNextPendingLoad();
      }
    } else {
      // 加入队列等待（但限制队列大小）
      if (_pendingLoads.length >= _maxQueueSize) {
        // ServiceLocator.log
        //     .d('[LogoState] 队列已满(${_pendingLoads.length}/$_maxQueueSize)，丢弃请求');
        return;
      }
      // ServiceLocator.log.d(
      //     '[LogoState] 并发已满，加入队列，当前队列: ${_pendingLoads.length}/$_maxQueueSize');
      _pendingLoads.add(loadFunction);
    }
  }

  void _processNextPendingLoad() {
    // ✅ 滚动时不处理队列
    if (_isScrolling) {
      // ServiceLocator.log.d('[LogoState] 滚动中，暂停处理队列');
      return;
    }

    // ✅ 批量处理队列，一次性启动多个加载任务（填满并发槽位）
    while (_pendingLoads.isNotEmpty &&
        _currentLoadingCount < _maxConcurrentLoads) {
      final nextLoad = _pendingLoads.removeAt(0);
      // ServiceLocator.log.d('[LogoState] 从队列取出任务，剩余: ${_pendingLoads.length}');
      _currentLoadingCount++;
      nextLoad().then((_) {
        _currentLoadingCount--;
        _processNextPendingLoad();
      }).catchError((e) {
        ServiceLocator.log.w('[LogoState] 队列任务失败: $e');
        _currentLoadingCount--;
        _processNextPendingLoad();
      });
    }
  }

  void clear() {
    _m3uLogoFailed.clear();
    _fallbackLogoUrls.clear();
    _fallbackLoaded.clear();
    _loadingFallback.clear();
    _pendingLoads.clear();
    _currentLoadingCount = 0;
  }

  /// 清理待处理的加载队列（但保留已加载的缓存）
  void clearPendingLoads() {
    _pendingLoads.clear();
    ServiceLocator.log.d('台标加载队列已清理，待处理任务数: 0');
  }
}

/// 公共访问点：清理台标加载队列
void clearLogoLoadingQueue() {
  _LogoStateManager().clearPendingLoads();
}

/// 公共访问点：完全清理台标缓存（包括已加载的）
void clearAllLogoCache() {
  _LogoStateManager().clear();
  ServiceLocator.log.d('台标缓存已完全清理');
}

/// ✅ 公共访问点：设置滚动状态（滚动时暂停台标加载）
void setLogoLoadingScrolling(bool scrolling) {
  _LogoStateManager().setScrolling(scrolling);
}

/// ✅ 公共访问点：初始化HTTP连接池
void initializeLogoConnectionPool() {
  _HttpConnectionPool().initialize();
}

/// ✅ 公共访问点：清理HTTP连接池
void disposeLogoConnectionPool() {
  _HttpConnectionPool().dispose();
}

/// Widget to display channel logo with fallback priority:
/// 1. M3U logo (if available and loads successfully)
/// 2. Database logo (fuzzy match by channel name)
/// 3. Default placeholder image
///
/// ✅ 使用 ValueNotifier 避免 setState() 导致的性能问题
class ChannelLogoWidget extends StatefulWidget {
  final Channel channel;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const ChannelLogoWidget({
    super.key,
    required this.channel,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  State<ChannelLogoWidget> createState() => _ChannelLogoWidgetState();
}

class _ChannelLogoWidgetState extends State<ChannelLogoWidget> with ThrottledStateMixin {
  final _logoState = _LogoStateManager();
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    // ServiceLocator.log.d('[ChannelLogo] initState - ${widget.channel.name}');
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _onM3uLogoError() {
    if (_isDisposed) return;

    final channelName = widget.channel.name;
    // 只在第一次失败时标记
    if (!_logoState.isM3uLogoFailed(channelName)) {
      // 标记为失败，避免下次重建时再次尝试无效链接
      _logoState.markM3uLogoFailed(channelName);
      
      // ✅ 使用throttledSetState触发rebuild，让build()方法加载fallback
      // 由于fallback是本地asset，加载很快，不会造成性能问题
      throttledSetState(() {});
      
      // ServiceLocator.log.d('[ChannelLogo] M3U台标失败，已标记并触发rebuild - $channelName');
    }
  }

  Widget _buildLogo(String? logoUrl, {bool isM3uLogo = false}) {
    if (logoUrl == null || logoUrl.isEmpty) {
      return _buildPlaceholder();
    }

    // Check if this is a local asset path
    if (logoUrl.startsWith('assets/')) {
      // Use Image.asset for local assets
      // ServiceLocator.log.d('[ChannelLogo] 加载本地asset: $logoUrl (${widget.channel.name})');
      return Image.asset(
        logoUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) {
          // If local asset fails, show placeholder
          ServiceLocator.log.w('[ChannelLogo] 本地asset加载失败: $logoUrl - $error');
          return _buildPlaceholder();
        },
      );
    }

    // Use CachedNetworkImage for network URLs (M3U logos)
    return CachedNetworkImage(
      imageUrl: logoUrl,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      cacheManager: LogoCacheManager(), // 使用自定义缓存管理器
      placeholder: (context, url) => _buildPlaceholder(),
      errorWidget: (context, url, error) {
        if (isM3uLogo) {
          _onM3uLogoError();
          
          // ✅ 不再在errorWidget中发起新的网络请求
          // 只标记失败状态，下次rebuild时会自动加载fallback（本地asset）
          ServiceLocator.log.d('[ChannelLogo] M3U台标失败，标记失败状态 - ${widget.channel.name}');
        }
        return _buildPlaceholder();
      },
      httpHeaders: const {
        'Connection': 'close',
      },
      fadeInDuration: const Duration(milliseconds: 200),
      fadeOutDuration: const Duration(milliseconds: 200),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius,
      ),
      child: Image.asset(
        'assets/images/default_logo.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          // 如果默认图片也加载失败，显示图标
          return Icon(
            Icons.tv,
            size: (widget.width ?? 48) * 0.5,
            color: Colors.grey[600],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _logoState.scrollingNotifier,
      builder: (context, isScrolling, child) {
        // 滚动时直接显示占位图，避免创建 CachedNetworkImage 导致 IO 拥堵
        if (isScrolling) {
          return _buildPlaceholderWrapper();
        }

        Widget logoWidget;
        final channelName = widget.channel.name;

        // 检查M3U台标是否之前失败过
        final m3uHasFailed = _logoState.isM3uLogoFailed(channelName);

        String? urlToLoad;
        bool isM3u = false;

        // 优先级1: M3U台标 (如果存在且未失败过)
        if (!m3uHasFailed &&
            widget.channel.logoUrl != null &&
            widget.channel.logoUrl!.isNotEmpty) {
          urlToLoad = widget.channel.logoUrl;
          isM3u = true;
        }
        // 优先级2: 预先计算好的备用台标
        else if (widget.channel.fallbackLogoUrl != null &&
            widget.channel.fallbackLogoUrl!.isNotEmpty) {
          urlToLoad = widget.channel.fallbackLogoUrl;
        }

        if (urlToLoad != null) {
          logoWidget = _buildLogo(urlToLoad, isM3uLogo: isM3u);
        } else {
          // 优先级3: 占位图
          logoWidget = _buildPlaceholder();
        }

        if (widget.borderRadius != null) {
          return ClipRRect(
            borderRadius: widget.borderRadius!,
            child: logoWidget,
          );
        }

        return logoWidget;
      },
    );
  }

  Widget _buildPlaceholderWrapper() {
    final placeholder = _buildPlaceholder();
    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius!,
        child: placeholder,
      );
    }
    return placeholder;
  }
}
