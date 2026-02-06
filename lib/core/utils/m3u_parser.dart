import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/channel.dart';
import '../services/service_locator.dart';

/// Result of M3U parsing containing channels and metadata
class M3UParseResult {
  final List<Channel> channels;
  final String? epgUrl;

  M3UParseResult({required this.channels, this.epgUrl});
}

/// Parser for M3U/M3U8 playlist files
class M3UParser {
  static const String _extM3U = '#EXTM3U';
  static const String _extInf = '#EXTINF:';
  static const String _extGrp = '#EXTGRP:';

  /// Parse result containing channels and metadata
  static M3UParseResult? _lastParseResult;

  /// Get the last parse result (for accessing EPG URL)
  static M3UParseResult? get lastParseResult => _lastParseResult;

  /// Parse M3U content from a URL
  static Future<List<Channel>> parseFromUrl(String url, int playlistId) async {
    try {
      ServiceLocator.log.d('DEBUG: 开始从URL获取播放列表内容: $url');

      // Use Dio for better handling of large files and redirects
      final dio = Dio();
      // Reduce timeout to 10 seconds as requested
      dio.options.connectTimeout = const Duration(seconds: 5);
      dio.options.receiveTimeout = const Duration(seconds: 5);

      final response = await dio.get(
        url,
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null && status < 400,
        ),
      );

      ServiceLocator.log.d('DEBUG: 成功获取播放列表内容，状态码: ${response.statusCode}');
      ServiceLocator.log
          .d('DEBUG: 内容大小: ${response.data.toString().length} 字符');

      // 使用 compute 在独立 isolate 中解析，避免阻塞主线程
      final result = await compute(
          _parseInIsolate, _ParseParams(response.data.toString(), playlistId));

      // 保存解析结果（包括 EPG URL）到主线程的静态变量
      _lastParseResult = result;

      ServiceLocator.log.d(
          'DEBUG: URL解析完成，共解析出 ${result.channels.length} 个频道，EPG URL: ${result.epgUrl ?? "(未配置)"}');

      return result.channels;
    } catch (e) {
      ServiceLocator.log.d('DEBUG: 从URL获取播放列表时出错: $e');

      final errorStr = e.toString().toLowerCase();
      // Use localization keys for common errors
      if (errorStr.contains('timeout') || errorStr.contains('timed out')) {
        throw Exception('errorTimeout');
      } else if (errorStr.contains('socket') ||
          errorStr.contains('connection') ||
          errorStr.contains('handshake') ||
          errorStr.contains('lookup')) {
        throw Exception('errorNetwork');
      } else if (errorStr.contains('404')) {
        throw Exception('Playlist not found (404)');
      } else if (errorStr.contains('403')) {
        throw Exception('Access denied (403)');
      }

      throw e;
    }
  }

  /// Parse M3U content from a local file
  static Future<List<Channel>> parseFromFile(
      String filePath, int playlistId) async {
    try {
      ServiceLocator.log.d('DEBUG: 开始从本地文件读取播放列表: $filePath');
      final file = File(filePath);

      if (!await file.exists()) {
        ServiceLocator.log.d('DEBUG: 文件不存在: $filePath');
        throw Exception('File does not exist: $filePath');
      }

      final content = await file.readAsString();
      ServiceLocator.log.d('DEBUG: 成功读取本地文件，内容大小: ${content.length} 字符');

      // 使用 compute 在独立 isolate 中解析，避免阻塞主线程
      final result =
          await compute(_parseInIsolate, _ParseParams(content, playlistId));

      // 保存解析结果（包括 EPG URL）到主线程的静态变量
      _lastParseResult = result;

      ServiceLocator.log.d(
          'DEBUG: 本地文件解析完成，共解析出 ${result.channels.length} 个频道，EPG URL: ${result.epgUrl ?? "(未配置)"}');

      return result.channels;
    } catch (e) {
      ServiceLocator.log.d('DEBUG: 读取本地播放列表文件时出错: $e');
      throw Exception('Error reading playlist file: $e');
    }
  }

  /// Isolate 中执行的解析函数（必须是顶层函数或静态函数）
  /// 返回完整的解析结果，包括频道列表和 EPG URL
  static M3UParseResult _parseInIsolate(_ParseParams params) {
    final channels = parse(params.content, params.playlistId);
    // parse 方法会设置 _lastParseResult，但那是在 isolate 中
    // 我们需要返回结果到主线程
    // 注意：_lastParseResult 在 isolate 中被设置，但我们需要返回它
    return _lastParseResult ?? M3UParseResult(channels: channels, epgUrl: null);
  }

  /// Parse M3U content string
  /// Merges channels with same tvg-name/epgId into single channel with multiple sources
  static List<Channel> parse(String content, int playlistId) {
    // 注意：此方法可能在 isolate 中运行，不能使用 ServiceLocator.log
    // 但我们可以使用 print 来调试（会输出到控制台）
    print('M3U Parser: 开始解析，播放列表ID: $playlistId');

    final List<Channel> rawChannels = [];
    final lines = LineSplitter.split(content).toList();
    String? epgUrl;

    print('M3U Parser: 内容总行数: ${lines.length}');

    if (lines.isEmpty) {
      print('M3U Parser: 内容为空，返回空频道列表');
      return rawChannels;
    }

    // Check for valid M3U header and extract EPG URL from first few lines
    bool foundHeader = false;
    for (int i = 0; i < lines.length && i < 10; i++) {
      final line = lines[i].trim();
      print(
          'M3U Parser: 检查第${i + 1}行: ${line.length > 100 ? line.substring(0, 100) + "..." : line}');

      if (line.startsWith(_extM3U)) {
        foundHeader = true;
        print('M3U Parser: 找到M3U头部标记');

        // Extract x-tvg-url from this line
        final extractedUrl = _extractEpgUrl(line);
        print('M3U Parser: EPG URL 提取结果: ${extractedUrl ?? "(未找到)"}');

        if (extractedUrl != null) {
          epgUrl = extractedUrl;
          print('M3U Parser: 成功提取EPG URL: $epgUrl');
          break;
        }
      }
    }

    if (!foundHeader) {
      print('M3U Parser: 警告 - 缺少M3U头部标记，尝试继续解析');
    } else {
      print('M3U Parser: M3U头部验证完成，EPG URL: ${epgUrl ?? "(未配置)"}');
    }

    String? currentName;
    String? currentLogo;
    String? currentGroup;
    String? currentEpgId;
    int invalidUrlCount = 0;
    int validChannelCount = 0;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      if (line.isEmpty) continue;

      if (line.startsWith(_extInf)) {
        // Parse EXTINF line
        final parsed = _parseExtInf(line);
        currentName = parsed['name'];
        currentLogo = parsed['logo'];
        currentGroup = parsed['group'];
        currentEpgId = parsed['epgId'];
      } else if (line.startsWith(_extGrp)) {
        // Parse EXTGRP line (alternative group format)
        currentGroup = line.substring(_extGrp.length).trim();
      } else if (line.startsWith('#')) {
        // Skip other directives
        continue;
      } else if (line.isNotEmpty && !line.startsWith('#')) {
        // This is a URL line
        if (currentName != null) {
          final url = line.split('\n').first.trim();
          if (_isValidUrl(url)) {
            final channel = Channel(
              playlistId: playlistId,
              name: currentName,
              url: url,
              logoUrl: currentLogo,
              groupName: currentGroup ?? 'Uncategorized',
              epgId: currentEpgId,
            );

            rawChannels.add(channel);
            validChannelCount++;
          } else {
            invalidUrlCount++;
            // ServiceLocator.log.d('DEBUG: 无效的URL在第${i + 1}行: $line');
          }
        } else {
          // ServiceLocator.log.d('DEBUG: 找到URL但没有对应的频道名称在第${i + 1}行: $line');
        }

        // Reset for next entry
        currentName = null;
        currentLogo = null;
        currentGroup = null;
        currentEpgId = null;
      }
    }

    // ServiceLocator.log.d('DEBUG: 原始解析完成 - 有效频道: $validChannelCount, 无效URL: $invalidUrlCount');
    print(
        'M3U Parser: 原始解析完成 - 有效频道: $validChannelCount, 无效URL: $invalidUrlCount');

    // Merge channels with same epgId (tvg-name) into single channel with multiple sources
    final List<Channel> mergedChannels = _mergeChannelSources(rawChannels);

    // ServiceLocator.log.d('DEBUG: 合并后频道数: ${mergedChannels.length} (原始: ${rawChannels.length})');
    print(
        'M3U Parser: 合并后频道数: ${mergedChannels.length} (原始: ${rawChannels.length})');

    // Save parse result with EPG URL
    _lastParseResult = M3UParseResult(channels: mergedChannels, epgUrl: epgUrl);
    print('M3U Parser: 保存解析结果 - EPG URL: ${epgUrl ?? "(未配置)"}');

    return mergedChannels;
  }

  /// Merge channels with same epgId into single channel with multiple sources
  /// Preserves the order of first occurrence, but prefers non-special groups
  static List<Channel> _mergeChannelSources(List<Channel> channels) {
    final Map<String, Channel> mergedMap = {};
    final List<String> orderKeys = []; // Preserve order

    // Special groups that should not be the primary group
    final specialGroups = {'🕘️更新时间', '更新时间', 'update', 'info'};

    for (final channel in channels) {
      // Use epgId as merge key
      final mergeKey = channel.epgId ?? channel.name;

      if (mergedMap.containsKey(mergeKey)) {
        // Add source to existing channel
        final existing = mergedMap[mergeKey]!;
        final newSources = [...existing.sources];

        // Add URL if not duplicate
        if (!newSources.contains(channel.url)) {
          newSources.add(channel.url);
        }

        // Check if we should replace the primary channel info
        // (prefer non-special group over special group)
        final existingIsSpecial = specialGroups.any((g) =>
            existing.groupName?.toLowerCase().contains(g.toLowerCase()) ??
            false);
        final newIsSpecial = specialGroups.any((g) =>
            channel.groupName?.toLowerCase().contains(g.toLowerCase()) ??
            false);

        if (existingIsSpecial && !newIsSpecial) {
          // Replace with the new channel's info but keep all sources
          mergedMap[mergeKey] = channel.copyWith(
            sources: newSources,
            // Keep the first URL as primary
            url: newSources.first,
          );
        } else {
          // Just add the new source
          mergedMap[mergeKey] = existing.copyWith(sources: newSources);
        }
      } else {
        // New channel
        mergedMap[mergeKey] = channel.copyWith(sources: [channel.url]);
        orderKeys.add(mergeKey);
      }
    }

    // Return in original order
    return orderKeys.map((key) => mergedMap[key]!).toList();
  }

  /// Extract EPG URL from M3U header line
  /// Supports: x-tvg-url="url" or url-tvg="url"
  static String? _extractEpgUrl(String headerLine) {
    print(
        'M3U Parser: _extractEpgUrl 输入: ${headerLine.length > 200 ? headerLine.substring(0, 200) + "..." : headerLine}');

    // Match x-tvg-url="..." or url-tvg="..."
    final patterns = [
      RegExp(r'x-tvg-url="([^"]+)"', caseSensitive: false),
      RegExp(r'url-tvg="([^"]+)"', caseSensitive: false),
      RegExp(r"x-tvg-url='([^']+)'", caseSensitive: false),
      RegExp(r"url-tvg='([^']+)'", caseSensitive: false),
    ];

    for (int i = 0; i < patterns.length; i++) {
      final pattern = patterns[i];
      final match = pattern.firstMatch(headerLine);
      print('M3U Parser: 尝试模式 $i: ${pattern.pattern} - 匹配结果: ${match != null}');

      if (match != null && match.groupCount >= 1) {
        final urls = match.group(1);
        print('M3U Parser: 提取到URL字符串: $urls');

        if (urls != null && urls.isNotEmpty) {
          // If multiple URLs separated by comma, return the first one
          final firstUrl = urls.split(',').first.trim();
          print('M3U Parser: 返回第一个URL: $firstUrl');
          return firstUrl;
        }
      }
    }

    print('M3U Parser: 所有模式都未匹配到EPG URL');
    return null;
  }

  /// Parse EXTINF line and extract metadata
  static Map<String, String?> _parseExtInf(String line) {
    String? name;
    String? logo;
    String? group;
    String? epgId;

    // Remove #EXTINF: prefix
    String content = line.substring(_extInf.length);

    // Find the channel name (after the last comma)
    final lastCommaIndex = content.lastIndexOf(',');
    if (lastCommaIndex != -1) {
      name = content.substring(lastCommaIndex + 1).trim();
      content = content.substring(0, lastCommaIndex);
    }

    // Parse attributes
    final attributes = _parseAttributes(content);

    logo = attributes['tvg-logo'] ?? attributes['logo'];
    group = attributes['group-title'] ?? attributes['tvg-group'];
    epgId = attributes['tvg-id'] ?? attributes['tvg-name'];

    // Debug logging for logo parsing
    if (logo != null && logo.isNotEmpty) {
      // ServiceLocator.log.d('DEBUG: 解析到台标URL: $logo, 频道: $name');
    }

    return {
      'name': name,
      'logo': logo,
      'group': group,
      'epgId': epgId,
    };
  }

  /// Parse key="value" attributes from a string
  static Map<String, String> _parseAttributes(String content) {
    final Map<String, String> attributes = {};

    // Regular expression to match key="value" or key=value patterns
    final RegExp attrRegex =
        RegExp(r'(\S+?)=["\u0027]?([^"\u0027]+)["\u0027]?(?:\s|$)');

    for (final match in attrRegex.allMatches(content)) {
      if (match.groupCount >= 2) {
        final key = match.group(1)?.toLowerCase();
        final value = match.group(2);
        if (key != null && value != null) {
          attributes[key] = value.trim();
        }
      }
    }

    return attributes;
  }

  /// Check if a string is a valid URL
  static bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final isValid = uri.hasScheme &&
          (uri.scheme == 'http' ||
              uri.scheme == 'https' ||
              uri.scheme == 'rtmp' ||
              uri.scheme == 'rtsp' ||
              uri.scheme == 'mms' ||
              uri.scheme == 'mmsh' ||
              uri.scheme == 'mmst');

      // if (!isValid) {
      //   ServiceLocator.log.d('DEBUG: URL验证失败 - Scheme: ${uri.scheme}, Host: ${uri.host}');
      // }

      return isValid;
    } catch (e) {
      // ServiceLocator.log.d('DEBUG: URL解析错误: $url, 错误: $e');
      return false;
    }
  }

  /// Extract unique groups from a list of channels
  static List<String> extractGroups(List<Channel> channels) {
    final Set<String> groups = {};
    for (final channel in channels) {
      if (channel.groupName != null && channel.groupName!.isNotEmpty) {
        groups.add(channel.groupName!);
      }
    }
    return groups.toList()..sort();
  }

  /// Generate M3U content from a list of channels
  static String generate(List<Channel> channels, {String? playlistName}) {
    final buffer = StringBuffer();

    buffer.writeln('#EXTM3U');
    if (playlistName != null) {
      buffer.writeln('#PLAYLIST:$playlistName');
    }
    buffer.writeln();

    for (final channel in channels) {
      // Generate entry for each source
      for (final sourceUrl in channel.sources) {
        buffer.write('#EXTINF:-1');

        if (channel.epgId != null) {
          buffer.write(' tvg-id="${channel.epgId}"');
        }
        if (channel.logoUrl != null) {
          buffer.write(' tvg-logo="${channel.logoUrl}"');
        }
        if (channel.groupName != null) {
          buffer.write(' group-title="${channel.groupName}"');
        }

        buffer.writeln(',${channel.name}');
        buffer.writeln(sourceUrl);
        buffer.writeln();
      }
    }

    return buffer.toString();
  }
}

/// 用于传递参数到 isolate 的类
class _ParseParams {
  final String content;
  final int playlistId;

  _ParseParams(this.content, this.playlistId);
}
