import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import '../models/channel.dart';
import '../services/service_locator.dart';

/// Custom HTTP client with timeout for logo loading
class _TimeoutHttpClient extends http.BaseClient {
  final http.Client _inner = http.Client();
  final Duration timeout;

  _TimeoutHttpClient({this.timeout = const Duration(seconds: 2)});  // 2秒超时

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request).timeout(timeout);
  }

  @override
  void close() {
    _inner.close();
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
              httpClient: _TimeoutHttpClient(timeout: const Duration(seconds: 2)),  // 2秒超时
            ),
          ),
        );
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
  
  // 正在加载 fallback 的频道
  final Set<String> _loadingFallback = {};
  
  // 并发控制：限制同时加载的台标数量
  static const int _maxConcurrentLoads = 10; // 最多同时加载 10 个台标
  int _currentLoadingCount = 0;
  final List<Function> _pendingLoads = [];

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
    if (_currentLoadingCount < _maxConcurrentLoads) {
      _currentLoadingCount++;
      try {
        await loadFunction();
      } finally {
        _currentLoadingCount--;
        _processNextPendingLoad();
      }
    } else {
      // 加入队列等待
      _pendingLoads.add(loadFunction);
    }
  }

  void _processNextPendingLoad() {
    if (_pendingLoads.isNotEmpty && _currentLoadingCount < _maxConcurrentLoads) {
      final nextLoad = _pendingLoads.removeAt(0);
      _currentLoadingCount++;
      nextLoad().then((_) {
        _currentLoadingCount--;
        _processNextPendingLoad();
      }).catchError((_) {
        _currentLoadingCount--;
        _processNextPendingLoad();
      });
    }
  }

  void clear() {
    _m3uLogoFailed.clear();
    _fallbackLogoUrls.clear();
    _loadingFallback.clear();
    _pendingLoads.clear();
    _currentLoadingCount = 0;
  }
}

/// Widget to display channel logo with fallback priority:
/// 1. M3U logo (if available and loads successfully)
/// 2. Database logo (fuzzy match by channel name)
/// 3. Default placeholder image
class ChannelLogoWidget extends StatefulWidget {
  final Channel channel;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final bool lazyLoad; // 是否延迟加载台标（用于大列表优化）

  const ChannelLogoWidget({
    super.key,
    required this.channel,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.lazyLoad = true, // 默认启用延迟加载
  });

  @override
  State<ChannelLogoWidget> createState() => _ChannelLogoWidgetState();
}

class _ChannelLogoWidgetState extends State<ChannelLogoWidget> {
  final _logoState = _LogoStateManager();

  @override
  void initState() {
    super.initState();
    print('🔍 ChannelLogoWidget.initState - ${widget.channel.name}, logoUrl: ${widget.channel.logoUrl}, lazyLoad: ${widget.lazyLoad}');
    ServiceLocator.log.d('ChannelLogoWidget.initState - ${widget.channel.name}, logoUrl: ${widget.channel.logoUrl}, lazyLoad: ${widget.lazyLoad}');
    
    // 如果不是延迟加载模式，或者频道没有 M3U 台标，立即加载数据库台标
    if (!widget.lazyLoad || widget.channel.logoUrl == null || widget.channel.logoUrl!.isEmpty) {
      print('🔍 ChannelLogoWidget: 立即加载数据库台标 - ${widget.channel.name}');
      ServiceLocator.log.d('ChannelLogoWidget: 立即加载数据库台标 - ${widget.channel.name}');
      _loadFallbackLogo();
    }
  }

  Future<void> _loadFallbackLogo() async {
    final channelName = widget.channel.name;
    
    // 如果已经加载过或正在加载，直接返回
    if (_logoState.getFallbackLogoUrl(channelName) != null || 
        _logoState.isLoadingFallback(channelName)) {
      return;
    }
    
    // 使用并发控制加载
    await _logoState.requestLoadFallback(() async {
      _logoState.markLoadingFallback(channelName, true);
      print('🔍 ChannelLogoWidget: 开始加载数据库台标 - $channelName');
      ServiceLocator.log.d('ChannelLogoWidget: 开始加载数据库台标 - $channelName');
      
      try {
        final logoUrl = await ServiceLocator.channelLogo.findLogoUrl(channelName);
        print('🔍 ChannelLogoWidget: 数据库台标查询结果 - $channelName: $logoUrl');
        ServiceLocator.log.d('ChannelLogoWidget: 数据库台标查询结果 - $channelName: $logoUrl');
        
        _logoState.setFallbackLogoUrl(channelName, logoUrl);
        _logoState.markLoadingFallback(channelName, false);
        
        if (mounted) {
          setState(() {});
          print('🔍 ChannelLogoWidget: 已设置数据库台标 - $channelName');
          ServiceLocator.log.d('ChannelLogoWidget: 已设置数据库台标 - $channelName');
        }
      } catch (e) {
        print('❌ ChannelLogoWidget: 加载数据库台标失败 - $channelName: $e');
        ServiceLocator.log.w('Failed to load fallback logo for $channelName: $e');
        _logoState.setFallbackLogoUrl(channelName, null);
        _logoState.markLoadingFallback(channelName, false);
        if (mounted) {
          setState(() {});
        }
      }
    });
  }
  
  void _ensureFallbackLoaded() {
    final channelName = widget.channel.name;
    // 延迟加载：只在真正需要时才加载
    if (widget.lazyLoad && 
        _logoState.isM3uLogoFailed(channelName) &&
        _logoState.getFallbackLogoUrl(channelName) == null &&
        !_logoState.isLoadingFallback(channelName)) {
      _loadFallbackLogo();
    }
  }

  void _onM3uLogoError() {
    final channelName = widget.channel.name;
    // 只在第一次失败时触发
    if (!_logoState.isM3uLogoFailed(channelName)) {
      // ServiceLocator.log.d('ChannelLogoWidget: M3U 台标失败，尝试数据库台标 - $channelName');
      _logoState.markM3uLogoFailed(channelName);
      // 立即加载数据库台标
      if (_logoState.getFallbackLogoUrl(channelName) == null &&
          !_logoState.isLoadingFallback(channelName)) {
        _loadFallbackLogo();
      } else if (mounted) {
        setState(() {});
      }
    }
  }

  Widget _buildLogo(String? logoUrl, {bool isM3uLogo = false}) {
    if (logoUrl == null || logoUrl.isEmpty) {
      return _buildPlaceholder();
    }

    print('🔍 ChannelLogoWidget: 尝试加载台标 - ${widget.channel.name}: $logoUrl');
    ServiceLocator.log.d('ChannelLogoWidget: 尝试加载台标 - ${widget.channel.name}: $logoUrl');

    return CachedNetworkImage(
      imageUrl: logoUrl,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      cacheManager: LogoCacheManager(), // 使用自定义缓存管理器
      placeholder: (context, url) => _buildPlaceholder(),
      errorWidget: (context, url, error) {
        print('❌ ChannelLogoWidget: 台标加载失败 - ${widget.channel.name}: $error');
        ServiceLocator.log.w('ChannelLogoWidget: 台标加载失败 - ${widget.channel.name}: $error');
        
        // 只有 M3U logo 失败时才触发 fallback
        if (isM3uLogo) {
          _onM3uLogoError();
        }
        return _buildPlaceholder();
      },
      httpHeaders: const {
        'Connection': 'close',
      },
      fadeInDuration: const Duration(milliseconds: 200),
      fadeOutDuration: const Duration(milliseconds: 200),
      // 注意：使用自定义 CacheManager 时不能使用 maxWidthDiskCache 和 maxHeightDiskCache
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
    final channelName = widget.channel.name;
    final m3uLogoFailed = _logoState.isM3uLogoFailed(channelName);
    final fallbackLogoUrl = _logoState.getFallbackLogoUrl(channelName);
    
    Widget logoWidget;

    // Priority 1: Try M3U logo if available and not failed
    if (!m3uLogoFailed && 
        widget.channel.logoUrl != null && 
        widget.channel.logoUrl!.isNotEmpty) {
      logoWidget = _buildLogo(widget.channel.logoUrl, isM3uLogo: true);
    }
    // Priority 2: Try database fallback logo
    else if (fallbackLogoUrl != null && fallbackLogoUrl.isNotEmpty) {
      logoWidget = _buildLogo(fallbackLogoUrl, isM3uLogo: false);
    }
    // Priority 3: Default placeholder (or loading fallback)
    else {
      // 在延迟加载模式下，当 M3U logo 失败时才触发 fallback 加载
      _ensureFallbackLoaded();
      logoWidget = _buildPlaceholder();
    }

    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius!,
        child: logoWidget,
      );
    }

    return logoWidget;
  }
}
