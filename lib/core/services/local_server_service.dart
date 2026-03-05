import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'service_locator.dart';

/// A simple local HTTP server for receiving playlist data and search queries from mobile devices
class LocalServerService {
  // 单例模式
  static final LocalServerService _instance = LocalServerService._internal();
  factory LocalServerService() => _instance;
  LocalServerService._internal();
  
  HttpServer? _server;
  String? _localIp;
  final int _port = 38888;

  // Callbacks
  Function(String url, String name)? onUrlReceived;
  Function(String content, String name)? onContentReceived;
  Function(String query)? onSearchReceived;
  Function(String serverUrl, String username, String password)? onWebDAVConfigReceived;
  Function(String userAgent)? onUserAgentReceived;

  // Log content for viewing
  String? _logContent;

  bool get isRunning => _server != null;
  String get serverUrl => 'http://$_localIp:$_port';
  String get importUrl => 'http://$_localIp:$_port/import';
  String get searchUrl => 'http://$_localIp:$_port/search';
  String? get localIp => _localIp;
  int get port => _port;

  String? _lastError;
  String? get lastError => _lastError;
  
  String? _cachedImportHtml;
  String? _cachedSearchHtml;
  String? _cachedWebDAVConfigHtml;
  String? _cachedUserAgentHtml;

  /// Set log content for viewing via /logs route
  void setLogContent(String content) {
    _logContent = content;
  }

  /// Start the local HTTP server
  Future<bool> start() async {
    // 如果服务器已经在运行，直接返回成功
    if (_server != null) {
      ServiceLocator.log.d('服务器已在运行', tag: 'LocalServer');
      return true;
    }
    
    try {
      _lastError = null;
      
      // Load HTML templates if not cached
      if (_cachedImportHtml == null) {
        try {
          _cachedImportHtml = await rootBundle.loadString('assets/html/import_playlist.html');
          ServiceLocator.log.d('导入HTML模板加载成功', tag: 'LocalServer');
        } catch (e) {
          ServiceLocator.log.d('导入HTML模板加载失败: $e', tag: 'LocalServer');
          _lastError = '无法加载页面模板';
          return false;
        }
      }
      
      if (_cachedSearchHtml == null) {
        try {
          _cachedSearchHtml = await rootBundle.loadString('assets/html/search_channels.html');
          ServiceLocator.log.d('搜索HTML模板加载成功', tag: 'LocalServer');
        } catch (e) {
          ServiceLocator.log.d('搜索HTML模板加载失败: $e', tag: 'LocalServer');
        }
      }
      
      if (_cachedWebDAVConfigHtml == null) {
        try {
          _cachedWebDAVConfigHtml = await rootBundle.loadString('assets/html/webdav_config.html');
          ServiceLocator.log.d('WebDAV配置HTML模板加载成功', tag: 'LocalServer');
        } catch (e) {
          ServiceLocator.log.d('WebDAV配置HTML模板加载失败: $e', tag: 'LocalServer');
        }
      }
      
      if (_cachedUserAgentHtml == null) {
        try {
          _cachedUserAgentHtml = await rootBundle.loadString('assets/html/user_agent_input.html');
          ServiceLocator.log.d('User-Agent输入HTML模板加载成功', tag: 'LocalServer');
        } catch (e) {
          ServiceLocator.log.d('User-Agent输入HTML模板加载失败: $e', tag: 'LocalServer');
        }
      }
      
      // Get local IP address
      _localIp = await _getLocalIpAddress();
      if (_localIp == null) {
        _lastError = '无法获取本地IP地址。请检查网络连接是否正常。';
        ServiceLocator.log.d('$_lastError', tag: 'LocalServer');
        return false;
      }

      ServiceLocator.log.d('本地IP地址: $_localIp', tag: 'LocalServer');
      ServiceLocator.log.d('尝试在端口 $_port 启动服务器...', tag: 'LocalServer');

      // Start HTTP server - bind to all interfaces
      _server = await HttpServer.bind(InternetAddress.anyIPv4, _port, shared: true);

      ServiceLocator.log.d('服务器已启动，监听地址: ${_server!.address.address}:${_server!.port}', tag: 'LocalServer');
      ServiceLocator.log.d('访问地址: http://$_localIp:$_port', tag: 'LocalServer');

      _server!.listen(_handleRequest, onError: (e) {
        ServiceLocator.log.d('请求处理错误: $e', tag: 'LocalServer');
      });

      return true;
    } on SocketException catch (e) {
      if (e.osError?.errorCode == 10048 || e.message.contains('address already in use')) {
        _lastError = '端口 $_port 已被占用。请关闭占用该端口的程序后重试。';
      } else if (e.osError?.errorCode == 10013) {
        _lastError = '权限不足。请以管理员身份运行应用。';
      } else {
        _lastError = '网络错误: ${e.message}';
      }
      ServiceLocator.log.d('启动失败 (SocketException): $e', tag: 'LocalServer');
      ServiceLocator.log.d('错误代码: ${e.osError?.errorCode}', tag: 'LocalServer');
      return false;
    } catch (e) {
      _lastError = '启动失败: $e';
      ServiceLocator.log.d('启动失败: $e', tag: 'LocalServer');
      return false;
    }
  }

  /// Stop the server
  Future<void> stop() async {
    await _server?.close();
    _server = null;
  }

  /// Handle incoming HTTP requests
  void _handleRequest(HttpRequest request) async {
    // Enable CORS
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type');

    // Handle preflight
    if (request.method == 'OPTIONS') {
      request.response.statusCode = 200;
      await request.response.close();
      return;
    }

    try {
      ServiceLocator.log.d('收到请求 - 路径: ${request.uri.path}, 方法: ${request.method}');
      
      if (request.uri.path == '/' && request.method == 'GET') {
        // Serve the import page by default
        ServiceLocator.log.d('提供导入页面 (/)');
        await _serveImportPage(request);
      } else if (request.uri.path == '/import' && request.method == 'GET') {
        // Serve the import page
        ServiceLocator.log.d('提供导入页面 (/import)');
        await _serveImportPage(request);
      } else if (request.uri.path == '/search' && request.method == 'GET') {
        // Serve the search page
        ServiceLocator.log.d('提供搜索页面 (/search)');
        await _serveSearchPage(request);
      } else if (request.uri.path == '/submit' && request.method == 'POST') {
        // Handle playlist submission
        ServiceLocator.log.d('处理播放列表提交');
        await _handleSubmission(request);
      } else if (request.uri.path == '/api/search' && request.method == 'POST') {
        // Handle search submission
        ServiceLocator.log.d('处理搜索提交');
        await _handleSearchSubmission(request);
      } else if (request.uri.path == '/logs' && request.method == 'GET') {
        // Serve the logs page
        ServiceLocator.log.d('提供日志查看页面');
        await _serveLogsPage(request);
      } else if (request.uri.path == '/webdav-config' && request.method == 'GET') {
        // Serve the WebDAV config page
        ServiceLocator.log.d('提供 WebDAV 配置页面');
        await _serveWebDAVConfigPage(request);
      } else if (request.uri.path == '/api/webdav-config' && request.method == 'POST') {
        // Handle WebDAV config submission
        ServiceLocator.log.d('处理 WebDAV 配置提交');
        await _handleWebDAVConfigSubmission(request);
      } else if (request.uri.path == '/user-agent' && request.method == 'GET') {
        // Serve the User-Agent input page
        ServiceLocator.log.d('提供 User-Agent 输入页面');
        await _serveUserAgentPage(request);
      } else if (request.uri.path == '/api/user-agent' && request.method == 'POST') {
        // Handle User-Agent submission
        ServiceLocator.log.d('处理 User-Agent 提交');
        await _handleUserAgentSubmission(request);
      } else {
        ServiceLocator.log.d('404 - 未找到路径: ${request.uri.path}');
        request.response.statusCode = 404;
        request.response.write('Not Found');
        await request.response.close();
      }
    } catch (e) {
      ServiceLocator.log.d('请求处理错误: $e');
      request.response.statusCode = 500;
      request.response.write('Error: $e');
      await request.response.close();
    }
  }

  /// Serve the import web page
  Future<void> _serveImportPage(HttpRequest request) async {
    request.response.headers.contentType = ContentType.html;
    request.response.write(_cachedImportHtml ?? _getImportPageHtml());
    await request.response.close();
  }

  /// Serve the search web page
  Future<void> _serveSearchPage(HttpRequest request) async {
    ServiceLocator.log.d('_serveSearchPage 被调用');
    ServiceLocator.log.d('_cachedSearchHtml 是否为空: ${_cachedSearchHtml == null}');
    request.response.headers.contentType = ContentType.html;
    final html = _cachedSearchHtml ?? _getSearchPageHtml();
    ServiceLocator.log.d('发送搜索页面，长度: ${html.length}');
    request.response.write(html);
    await request.response.close();
  }

  /// Serve the logs viewing page
  Future<void> _serveLogsPage(HttpRequest request) async {
    request.response.headers.contentType = ContentType.html;
    final html = _getLogsPageHtml();
    request.response.write(html);
    await request.response.close();
  }

  /// Serve the WebDAV config page
  Future<void> _serveWebDAVConfigPage(HttpRequest request) async {
    request.response.headers.contentType = ContentType.html;
    request.response.write(_cachedWebDAVConfigHtml ?? _getWebDAVConfigPageHtml());
    await request.response.close();
  }

  /// Serve the User-Agent input page
  Future<void> _serveUserAgentPage(HttpRequest request) async {
    request.response.headers.contentType = ContentType.html;
    request.response.write(_cachedUserAgentHtml ?? _getUserAgentPageHtml());
    await request.response.close();
  }

  /// Handle playlist submission from mobile
  Future<void> _handleSubmission(HttpRequest request) async {
    try {
      ServiceLocator.log.d('收到来自 ${request.requestedUri} 的提交请求');

      final content = await utf8.decoder.bind(request).join();
      ServiceLocator.log.d('请求内容长度: ${content.length}');

      final data = json.decode(content) as Map<String, dynamic>;

      final type = data['type'] as String?;
      final name = data['name'] as String? ?? 'Imported Playlist';

      ServiceLocator.log.d('请求类型: $type, 名称: $name');

      if (type == 'url') {
        final url = data['url'] as String?;
        ServiceLocator.log.d('URL内容: ${url?.substring(0, math.min(100, url.length))}...');

        if (url != null && url.isNotEmpty) {
          ServiceLocator.log.d('调用URL接收回调...');
          onUrlReceived?.call(url, name);

          request.response.headers.contentType = ContentType.json;
          request.response.write(json.encode({'success': true, 'message': 'URL received'}));
        } else {
          ServiceLocator.log.d('URL为空或无效');
          request.response.statusCode = 400;
          request.response.write(json.encode({'success': false, 'message': 'URL is required'}));
        }
      } else if (type == 'content') {
        final fileContent = data['content'] as String?;
        ServiceLocator.log.d('文件内容长度: ${fileContent?.length}');

        if (fileContent != null && fileContent.isNotEmpty) {
          ServiceLocator.log.d('调用内容接收回调...');
          onContentReceived?.call(fileContent, name);

          request.response.headers.contentType = ContentType.json;
          request.response.write(json.encode({'success': true, 'message': 'Content received'}));
        } else {
          ServiceLocator.log.d('文件内容为空');
          request.response.statusCode = 400;
          request.response.write(json.encode({'success': false, 'message': 'Content is required'}));
        }
      } else {
        ServiceLocator.log.d('无效的请求类型: $type');
        request.response.statusCode = 400;
        request.response.write(json.encode({'success': false, 'message': 'Invalid type'}));
      }
    } catch (e) {
      ServiceLocator.log.d('处理提交请求时出错: $e');
      ServiceLocator.log.d('错误堆栈: ${StackTrace.current}');
      request.response.statusCode = 400;
      request.response.write(json.encode({'success': false, 'message': 'Invalid request: $e'}));
    }

    await request.response.close();
    ServiceLocator.log.d('请求处理完成');
  }

  /// Handle search submission from mobile
  Future<void> _handleSearchSubmission(HttpRequest request) async {
    try {
      ServiceLocator.log.d('收到来自 ${request.requestedUri} 的搜索请求');

      final content = await utf8.decoder.bind(request).join();
      ServiceLocator.log.d('请求内容长度: ${content.length}');

      final data = json.decode(content) as Map<String, dynamic>;
      final query = data['query'] as String?;

      ServiceLocator.log.d('搜索内容: $query');

      if (query != null && query.isNotEmpty) {
        ServiceLocator.log.d('调用搜索接收回调...');
        onSearchReceived?.call(query);

        request.response.headers.contentType = ContentType.json;
        request.response.write(json.encode({'success': true, 'message': 'Search query received'}));
      } else {
        ServiceLocator.log.d('搜索内容为空');
        request.response.statusCode = 400;
        request.response.write(json.encode({'success': false, 'message': 'Query is required'}));
      }
    } catch (e) {
      ServiceLocator.log.d('处理搜索请求时出错: $e');
      ServiceLocator.log.d('错误堆栈: ${StackTrace.current}');
      request.response.statusCode = 400;
      request.response.write(json.encode({'success': false, 'message': 'Invalid request: $e'}));
    }

    await request.response.close();
    ServiceLocator.log.d('搜索请求处理完成');
  }

  /// Handle WebDAV config submission from mobile
  Future<void> _handleWebDAVConfigSubmission(HttpRequest request) async {
    try {
      ServiceLocator.log.d('收到来自 ${request.requestedUri} 的 WebDAV 配置请求');

      final content = await utf8.decoder.bind(request).join();
      ServiceLocator.log.d('请求内容长度: ${content.length}');

      final data = json.decode(content) as Map<String, dynamic>;
      final serverUrl = data['serverUrl'] as String?;
      final username = data['username'] as String?;
      final password = data['password'] as String?;

      ServiceLocator.log.d('服务器地址: $serverUrl');
      ServiceLocator.log.d('用户名: $username');

      if (serverUrl != null && serverUrl.isNotEmpty && username != null && username.isNotEmpty) {
        ServiceLocator.log.d('调用 WebDAV 配置接收回调...');
        onWebDAVConfigReceived?.call(serverUrl, username, password ?? '');

        request.response.headers.contentType = ContentType.json;
        request.response.write(json.encode({'success': true, 'message': 'WebDAV config received'}));
      } else {
        ServiceLocator.log.d('服务器地址或用户名为空');
        request.response.statusCode = 400;
        request.response.write(json.encode({'success': false, 'message': 'Server URL and username are required'}));
      }
    } catch (e) {
      ServiceLocator.log.d('处理 WebDAV 配置请求时出错: $e');
      ServiceLocator.log.d('错误堆栈: ${StackTrace.current}');
      request.response.statusCode = 400;
      request.response.write(json.encode({'success': false, 'message': 'Invalid request: $e'}));
    }

    await request.response.close();
    ServiceLocator.log.d('WebDAV 配置请求处理完成');
  }

  /// Handle User-Agent submission from mobile
  Future<void> _handleUserAgentSubmission(HttpRequest request) async {
    try {
      ServiceLocator.log.d('收到来自 ${request.requestedUri} 的 User-Agent 请求');

      final content = await utf8.decoder.bind(request).join();
      ServiceLocator.log.d('请求内容长度: ${content.length}');

      final data = json.decode(content) as Map<String, dynamic>;
      final userAgent = data['userAgent'] as String?;

      ServiceLocator.log.d('User-Agent: $userAgent');

      if (userAgent != null && userAgent.isNotEmpty) {
        ServiceLocator.log.d('调用 User-Agent 接收回调...');
        onUserAgentReceived?.call(userAgent);

        request.response.headers.contentType = ContentType.json;
        request.response.write(json.encode({'success': true, 'message': 'User-Agent received'}));
      } else {
        ServiceLocator.log.d('User-Agent 为空');
        request.response.statusCode = 400;
        request.response.write(json.encode({'success': false, 'message': 'User-Agent is required'}));
      }
    } catch (e) {
      ServiceLocator.log.d('处理 User-Agent 请求时出错: $e');
      ServiceLocator.log.d('错误堆栈: ${StackTrace.current}');
      request.response.statusCode = 400;
      request.response.write(json.encode({'success': false, 'message': 'Invalid request: $e'}));
    }

    await request.response.close();
    ServiceLocator.log.d('User-Agent 请求处理完成');
  }

  /// Get the local IP address
  /// Tries to find the most likely usable LAN IP using a scoring mechanism
  Future<String?> _getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      NetworkInterface? bestInterface;
      int bestScore = -1000;

      for (var interface in interfaces) {
        int score = 0;
        final name = interface.name.toLowerCase();

        // Penalize virtual interfaces
        if (name.contains('vethernet') ||
            name.contains('virtual') ||
            name.contains('wsl') ||
            name.contains('docker') ||
            name.contains('bridge') ||
            name.contains('vmware') ||
            name.contains('box') ||
            name.contains('pseudo') ||
            name.contains('host-only') ||
            name.contains('tap') ||
            name.contains('tun')) {
          score -= 100;
        }

        // Bonus for known physical interface names
        if (name.contains('wi-fi') || name.contains('wlan')) {
          score += 50;
        }
        if (name.contains('ethernet') || name.contains('以太网') || name.contains('本地连接')) {
          score += 40;
        }

        // Find the first IPv4 address
        String? ip;
        for (var addr in interface.addresses) {
          if (!addr.isLoopback) {
            ip = addr.address;
            break;
          }
        }

        if (ip == null) {
          continue;
        }

        // Bonus for standard LAN ranges
        if (ip.startsWith('192.168.')) {
          score += 20;
        } else if (ip.startsWith('10.')) {
          score += 10;
        } else if (ip.startsWith('172.')) {
          // Check Class B private range 172.16.0.0 - 172.31.255.255
          try {
            final secondPart = int.parse(ip.split('.')[1]);
            if (secondPart >= 16 && secondPart <= 31) score += 15;
          } catch (_) {}
        }

        ServiceLocator.log.d('${interface.name}, IP: $ip, Score: $score', tag: 'Interface');

        if (score > bestScore) {
          bestScore = score;
          bestInterface = interface;
        }
      }

      if (bestInterface != null) {
        for (var addr in bestInterface.addresses) {
          if (!addr.isLoopback) {
            return addr.address;
          }
        }
      }

      return null;
    } catch (e) {
      ServiceLocator.log.d('$e', tag: 'Error getting local IP');
      return null;
    }
  }

  /// Generate the HTML page for mobile input (fallback)
  String _getImportPageHtml() {
    return r'''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Lotus IPTV - Import Playlist</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
            min-height: 100vh;
            padding: 20px;
            color: #fff;
            text-align: center;
        }
        h1 { margin-top: 50px; }
        p { color: #888; }
    </style>
</head>
<body>
    <h1>🎬 Lotus IPTV</h1>
    <p>Import Playlist</p>
    <p>Please reload the page</p>
</body>
</html>
''';
  }

  /// Generate the search HTML page (fallback)
  String _getSearchPageHtml() {
    return r'''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Lotus IPTV - Search Channels</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
            min-height: 100vh;
            padding: 20px;
            color: #fff;
            text-align: center;
        }
        h1 { margin-top: 50px; }
        p { color: #888; }
    </style>
</head>
<body>
    <h1>🔍 Lotus IPTV</h1>
    <p>Search Channels</p>
    <p>Please reload the page</p>
</body>
</html>
''';
  }

  /// Generate the logs viewing HTML page
  String _getLogsPageHtml() {
    final logContent = _logContent ?? '没有可用的日志内容';
    final escapedContent = const HtmlEscape().convert(logContent);
    
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Lotus IPTV - 日志查看</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
            min-height: 100vh;
            padding: 20px;
            color: #fff;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        .header {
            text-align: center;
            margin-bottom: 30px;
        }
        .header h1 {
            font-size: 28px;
            margin-bottom: 10px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }
        .header p {
            color: #888;
            font-size: 14px;
        }
        .actions {
            display: flex;
            gap: 10px;
            justify-content: center;
            margin-bottom: 20px;
            flex-wrap: wrap;
        }
        .btn {
            padding: 12px 24px;
            border: none;
            border-radius: 8px;
            font-size: 14px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s ease;
            display: inline-flex;
            align-items: center;
            gap: 8px;
        }
        .btn-primary {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .btn-primary:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);
        }
        .btn-secondary {
            background: rgba(255, 255, 255, 0.1);
            color: white;
            border: 1px solid rgba(255, 255, 255, 0.2);
        }
        .btn-secondary:hover {
            background: rgba(255, 255, 255, 0.15);
        }
        .log-container {
            background: rgba(0, 0, 0, 0.3);
            border-radius: 12px;
            padding: 20px;
            border: 1px solid rgba(255, 255, 255, 0.1);
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
        }
        .log-content {
            background: #1a1a2e;
            border-radius: 8px;
            padding: 16px;
            font-family: 'Courier New', Courier, monospace;
            font-size: 13px;
            line-height: 1.6;
            color: #e0e0e0;
            white-space: pre-wrap;
            word-wrap: break-word;
            max-height: 600px;
            overflow-y: auto;
            border: 1px solid rgba(255, 255, 255, 0.05);
        }
        .log-content::-webkit-scrollbar {
            width: 8px;
        }
        .log-content::-webkit-scrollbar-track {
            background: rgba(255, 255, 255, 0.05);
            border-radius: 4px;
        }
        .log-content::-webkit-scrollbar-thumb {
            background: rgba(255, 255, 255, 0.2);
            border-radius: 4px;
        }
        .log-content::-webkit-scrollbar-thumb:hover {
            background: rgba(255, 255, 255, 0.3);
        }
        .toast {
            position: fixed;
            top: 20px;
            right: 20px;
            background: #4caf50;
            color: white;
            padding: 16px 24px;
            border-radius: 8px;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
            display: none;
            animation: slideIn 0.3s ease;
        }
        @keyframes slideIn {
            from {
                transform: translateX(400px);
                opacity: 0;
            }
            to {
                transform: translateX(0);
                opacity: 1;
            }
        }
        .toast.show {
            display: block;
        }
        @media (max-width: 768px) {
            .header h1 {
                font-size: 24px;
            }
            .actions {
                flex-direction: column;
            }
            .btn {
                width: 100%;
                justify-content: center;
            }
            .log-content {
                font-size: 12px;
                max-height: 400px;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📋 Lotus IPTV 日志查看</h1>
            <p>查看和分享应用日志</p>
        </div>
        
        <div class="actions">
            <button class="btn btn-primary" onclick="copyLogs()">
                📋 复制日志
            </button>
            <button class="btn btn-secondary" onclick="downloadLogs()">
                💾 下载日志
            </button>
        </div>
        
        <div class="log-container">
            <div class="log-content" id="logContent">$escapedContent</div>
        </div>
    </div>
    
    <div class="toast" id="toast">已复制到剪贴板！</div>
    
    <script>
        function showToast(message) {
            const toast = document.getElementById('toast');
            toast.textContent = message;
            toast.classList.add('show');
            setTimeout(() => {
                toast.classList.remove('show');
            }, 3000);
        }
        
        function copyLogs() {
            const logContent = document.getElementById('logContent').textContent;
            
            // 尝试使用现代 Clipboard API
            if (navigator.clipboard && navigator.clipboard.writeText) {
                navigator.clipboard.writeText(logContent).then(() => {
                    showToast('✓ 已复制到剪贴板！');
                }).catch(err => {
                    console.error('Clipboard API 失败:', err);
                    // 如果失败，尝试备用方案
                    fallbackCopy(logContent);
                });
            } else {
                // 浏览器不支持 Clipboard API，使用备用方案
                fallbackCopy(logContent);
            }
        }
        
        function fallbackCopy(text) {
            // 创建临时 textarea 元素
            const textarea = document.createElement('textarea');
            textarea.value = text;
            textarea.style.position = 'fixed';
            textarea.style.top = '0';
            textarea.style.left = '0';
            textarea.style.width = '2em';
            textarea.style.height = '2em';
            textarea.style.padding = '0';
            textarea.style.border = 'none';
            textarea.style.outline = 'none';
            textarea.style.boxShadow = 'none';
            textarea.style.background = 'transparent';
            document.body.appendChild(textarea);
            
            // 选择文本
            textarea.focus();
            textarea.select();
            
            try {
                // 执行复制命令
                const successful = document.execCommand('copy');
                if (successful) {
                    showToast('✓ 已复制到剪贴板！');
                } else {
                    showToast('✗ 复制失败，请手动复制');
                }
            } catch (err) {
                console.error('execCommand 失败:', err);
                showToast('✗ 复制失败，请手动复制');
            }
            
            // 移除临时元素
            document.body.removeChild(textarea);
        }
        
        function downloadLogs() {
            const logContent = document.getElementById('logContent').textContent;
            const blob = new Blob([logContent], { type: 'text/plain' });
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = 'lotus_iptv_logs_' + new Date().toISOString().replace(/[:.]/g, '-') + '.txt';
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            URL.revokeObjectURL(url);
            showToast('✓ 日志已下载！');
        }
    </script>
</body>
</html>
''';
  }

  /// Generate the WebDAV config HTML page (fallback)
  String _getWebDAVConfigPageHtml() {
    return r'''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Lotus IPTV - WebDAV Configuration</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
            min-height: 100vh;
            padding: 20px;
            color: #fff;
            text-align: center;
        }
        h1 { margin-top: 50px; }
        p { color: #888; }
    </style>
</head>
<body>
    <h1>🔧 Lotus IPTV</h1>
    <p>WebDAV Configuration</p>
    <p>Please reload the page</p>
</body>
</html>
''';
  }

  /// Generate the User-Agent input HTML page (fallback)
  String _getUserAgentPageHtml() {
    return r'''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Lotus IPTV - User-Agent Input</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
            min-height: 100vh;
            padding: 20px;
            color: #fff;
            text-align: center;
        }
        h1 { margin-top: 50px; }
        p { color: #888; }
    </style>
</head>
<body>
    <h1>🌐 Lotus IPTV</h1>
    <p>User-Agent Input</p>
    <p>Please reload the page</p>
</body>
</html>
''';
  }
}

