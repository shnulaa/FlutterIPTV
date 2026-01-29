import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/channel.dart';
import './service_locator.dart';

/// 频道测试结果
class ChannelTestResult {
  final Channel channel;
  final bool isAvailable;
  final int? responseTime; // 响应时间（毫秒）
  final String? error;
  final int availableSources; // 可用源数量
  final int totalSources; // 总源数量
  final List<SourceTestResult> sourceResults; // 每个源的测试结果

  ChannelTestResult({
    required this.channel,
    required this.isAvailable,
    this.responseTime,
    this.error,
    this.availableSources = 1,
    this.totalSources = 1,
    this.sourceResults = const [],
  });
}

/// 单个源的测试结果
class SourceTestResult {
  final String url;
  final bool isAvailable;
  final int? responseTime;
  final String? error;

  SourceTestResult({
    required this.url,
    required this.isAvailable,
    this.responseTime,
    this.error,
  });
}

/// 频道测试服务
class ChannelTestService {
  static const int _timeout = 3; // 超时时间（秒）
  static const int _maxConcurrent = 5; // 最大并发数

  /// 测试单个频道（测试所有源）
  Future<ChannelTestResult> testChannel(Channel channel) async {
    final sources = channel.sources;
    
    // 如果只有一个源，使用简单测试
    if (sources.length <= 1) {
      return _testSingleUrl(channel, channel.url);
    }
    
    // 测试所有源
    final sourceResults = <SourceTestResult>[];
    int availableCount = 0;
    int? bestResponseTime;
    
    for (final sourceUrl in sources) {
      final result = await _testUrl(sourceUrl);
      sourceResults.add(result);
      
      if (result.isAvailable) {
        availableCount++;
        if (bestResponseTime == null || (result.responseTime ?? 0) < bestResponseTime) {
          bestResponseTime = result.responseTime;
        }
      }
    }
    
    // 频道可用 = 至少有一个源可用
    final isAvailable = availableCount > 0;
    
    return ChannelTestResult(
      channel: channel,
      isAvailable: isAvailable,
      responseTime: bestResponseTime,
      error: isAvailable ? null : '所有 ${sources.length} 个源均不可用',
      availableSources: availableCount,
      totalSources: sources.length,
      sourceResults: sourceResults,
    );
  }

  /// 测试单个 URL
  Future<SourceTestResult> _testUrl(String url) async {
    final stopwatch = Stopwatch()..start();

    try {
      final uri = Uri.parse(url);

      // 根据协议类型选择测试方法
      if (uri.scheme == 'rtmp' || uri.scheme == 'rtsp') {
        return await _testSocketUrl(url, uri, stopwatch);
      }

      return await _testHttpUrl(url, uri, stopwatch);
    } on TimeoutException {
      stopwatch.stop();
      return SourceTestResult(
        url: url,
        isAvailable: false,
        responseTime: stopwatch.elapsedMilliseconds,
        error: '连接超时',
      );
    } on SocketException catch (e) {
      stopwatch.stop();
      return SourceTestResult(
        url: url,
        isAvailable: false,
        responseTime: stopwatch.elapsedMilliseconds,
        error: '网络错误: ${e.message}',
      );
    } catch (e) {
      stopwatch.stop();
      return SourceTestResult(
        url: url,
        isAvailable: false,
        responseTime: stopwatch.elapsedMilliseconds,
        error: e.toString(),
      );
    }
  }

  /// 测试单个频道（单源，兼容旧逻辑）
  Future<ChannelTestResult> _testSingleUrl(Channel channel, String url) async {
    final stopwatch = Stopwatch()..start();

    try {
      final uri = Uri.parse(url);

      // 根据协议类型选择测试方法
      if (uri.scheme == 'rtmp' || uri.scheme == 'rtsp') {
        return await _testSocketConnection(channel, uri, stopwatch);
      }

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
      client.connectionTimeout = const Duration(seconds: _timeout);

      // 使用 GET 请求
      request = await client.getUrl(uri).timeout(
            const Duration(seconds: _timeout),
          );

      // 设置常见的流媒体请求头
      request.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
      request.headers.set('Accept', '*/*');
      request.headers.set('Connection', 'keep-alive');

      response = await request.close().timeout(
            const Duration(seconds: _timeout),
          );

      stopwatch.stop();

      // 检查响应状态
      final statusCode = response.statusCode;
      final isAvailable = statusCode >= 200 && statusCode < 400;

      final contentType = response.headers.contentType?.toString() ?? '';
      ServiceLocator.log.d('测试频道 ${channel.name}: HTTP $statusCode, Content-Type: $contentType');

      return ChannelTestResult(
        channel: channel,
        isAvailable: isAvailable,
        responseTime: stopwatch.elapsedMilliseconds,
        error: isAvailable ? null : 'HTTP $statusCode',
      );
    } finally {
      try {
        response?.detachSocket().then((socket) => socket.destroy());
      } catch (_) {}
      client?.close(force: true);
    }
  }

  /// 测试 HTTP/HTTPS URL（返回 SourceTestResult）
  Future<SourceTestResult> _testHttpUrl(
    String url,
    Uri uri,
    Stopwatch stopwatch,
  ) async {
    HttpClient? client;
    HttpClientRequest? request;
    HttpClientResponse? response;

    try {
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: _timeout);

      request = await client.getUrl(uri).timeout(
            const Duration(seconds: _timeout),
          );

      request.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
      request.headers.set('Accept', '*/*');
      request.headers.set('Connection', 'keep-alive');

      response = await request.close().timeout(
            const Duration(seconds: _timeout),
          );

      stopwatch.stop();

      final statusCode = response.statusCode;
      final isAvailable = statusCode >= 200 && statusCode < 400;

      return SourceTestResult(
        url: url,
        isAvailable: isAvailable,
        responseTime: stopwatch.elapsedMilliseconds,
        error: isAvailable ? null : 'HTTP $statusCode',
      );
    } finally {
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
        timeout: const Duration(seconds: _timeout),
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

  /// 测试 Socket URL（返回 SourceTestResult）
  Future<SourceTestResult> _testSocketUrl(
    String url,
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
        timeout: const Duration(seconds: _timeout),
      );

      stopwatch.stop();

      return SourceTestResult(
        url: url,
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
