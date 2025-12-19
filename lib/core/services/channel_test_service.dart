import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/channel.dart';

/// 频道测试结果
class ChannelTestResult {
  final Channel channel;
  final bool isAvailable;
  final int? responseTime; // 响应时间（毫秒）
  final String? error;

  ChannelTestResult({
    required this.channel,
    required this.isAvailable,
    this.responseTime,
    this.error,
  });
}

/// 频道测试服务
class ChannelTestService {
  static const int _timeout = 15; // 超时时间（秒）
  static const int _maxConcurrent = 5; // 最大并发数

  /// 测试单个频道
  Future<ChannelTestResult> testChannel(Channel channel) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final uri = Uri.parse(channel.url);
      
      // 根据协议类型选择测试方法
      if (uri.scheme == 'rtmp' || uri.scheme == 'rtsp') {
        // RTMP/RTSP 流无法通过 HTTP 测试，尝试 socket 连接
        return await _testSocketConnection(channel, uri, stopwatch);
      }
      
      // HTTP/HTTPS 流测试 - 使用 GET 请求并只读取少量数据
      return await _testHttpStream(channel, uri, stopwatch);
    } on TimeoutException {
      stopwatch.stop();
      return ChannelTestResult(
        channel: channel,
        isAvailable: false,
        responseTime: stopwatch.elapsedMilliseconds,
        error: '连接超时',
      );
    } on SocketException catch (e) {
      stopwatch.stop();
      return ChannelTestResult(
        channel: channel,
        isAvailable: false,
        responseTime: stopwatch.elapsedMilliseconds,
        error: '网络错误: ${e.message}',
      );
    } catch (e) {
      stopwatch.stop();
      return ChannelTestResult(
        channel: channel,
        isAvailable: false,
        responseTime: stopwatch.elapsedMilliseconds,
        error: e.toString(),
      );
    }
  }

  /// 测试 HTTP/HTTPS 流
  Future<ChannelTestResult> _testHttpStream(
    Channel channel,
    Uri uri,
    Stopwatch stopwatch,
  ) async {
    HttpClient? client;
    HttpClientRequest? request;
    HttpClientResponse? response;
    
    try {
      client = HttpClient();
      client.connectionTimeout = Duration(seconds: _timeout);
      
      // 使用 GET 请求
      request = await client.getUrl(uri).timeout(
        Duration(seconds: _timeout),
      );
      
      // 设置常见的流媒体请求头
      request.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
      request.headers.set('Accept', '*/*');
      request.headers.set('Connection', 'keep-alive');
      
      response = await request.close().timeout(
        Duration(seconds: _timeout),
      );
      
      stopwatch.stop();
      
      // 检查响应状态
      // 流媒体服务器可能返回 200, 206 (部分内容), 或 302/301 (重定向)
      final statusCode = response.statusCode;
      final isAvailable = statusCode >= 200 && statusCode < 400;
      
      // 检查 Content-Type 是否像流媒体
      final contentType = response.headers.contentType?.toString() ?? '';
      final isStreamContent = contentType.contains('video') ||
          contentType.contains('audio') ||
          contentType.contains('mpegurl') ||
          contentType.contains('octet-stream') ||
          contentType.contains('x-mpegURL') ||
          contentType.isEmpty; // 有些服务器不返回 Content-Type
      
      debugPrint('测试频道 ${channel.name}: HTTP $statusCode, Content-Type: $contentType');
      
      return ChannelTestResult(
        channel: channel,
        isAvailable: isAvailable,
        responseTime: stopwatch.elapsedMilliseconds,
        error: isAvailable ? null : 'HTTP $statusCode',
      );
    } finally {
      // 确保关闭连接，不读取响应体
      try {
        response?.detachSocket().then((socket) => socket.destroy());
      } catch (_) {}
      client?.close(force: true);
    }
  }

  /// 测试 Socket 连接 (用于 RTMP/RTSP)
  Future<ChannelTestResult> _testSocketConnection(
    Channel channel,
    Uri uri,
    Stopwatch stopwatch,
  ) async {
    Socket? socket;
    
    try {
      final host = uri.host;
      final port = uri.port != 0 ? uri.port : (uri.scheme == 'rtmp' ? 1935 : 554);
      
      socket = await Socket.connect(
        host,
        port,
        timeout: Duration(seconds: _timeout),
      );
      
      stopwatch.stop();
      
      return ChannelTestResult(
        channel: channel,
        isAvailable: true,
        responseTime: stopwatch.elapsedMilliseconds,
      );
    } finally {
      socket?.destroy();
    }
  }

  /// 批量测试频道
  Stream<ChannelTestProgress> testChannels(List<Channel> channels) async* {
    if (channels.isEmpty) return;

    final total = channels.length;
    var completed = 0;
    var available = 0;
    var unavailable = 0;
    final results = <ChannelTestResult>[];

    // 分批处理
    for (var i = 0; i < channels.length; i += _maxConcurrent) {
      final batch = channels.skip(i).take(_maxConcurrent).toList();
      
      final futures = batch.map((channel) => testChannel(channel));
      final batchResults = await Future.wait(futures);
      
      for (final result in batchResults) {
        completed++;
        results.add(result);
        
        if (result.isAvailable) {
          available++;
        } else {
          unavailable++;
        }
        
        yield ChannelTestProgress(
          total: total,
          completed: completed,
          available: available,
          unavailable: unavailable,
          currentChannel: result.channel,
          currentResult: result,
          results: List.unmodifiable(results),
        );
      }
    }
  }
}

/// 频道测试进度
class ChannelTestProgress {
  final int total;
  final int completed;
  final int available;
  final int unavailable;
  final Channel currentChannel;
  final ChannelTestResult currentResult;
  final List<ChannelTestResult> results;

  ChannelTestProgress({
    required this.total,
    required this.completed,
    required this.available,
    required this.unavailable,
    required this.currentChannel,
    required this.currentResult,
    required this.results,
  });

  double get progress => total > 0 ? completed / total : 0;
  bool get isComplete => completed >= total;
}
