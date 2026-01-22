import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/channel.dart';

/// Result of M3U parsing containing channels and metadata
class M3UParseResult {
  final List<Channel> channels;
  final String? epgUrl;
  final Set<String> unsupportedSchemes;

  M3UParseResult({
    required this.channels,
    this.epgUrl,
    this.unsupportedSchemes = const {},
  });
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

  /// Parse M3U content from a URL (backwards compatible, returns channels only)
  static Future<List<Channel>> parseFromUrl(String url, int playlistId) async {
    final result = await parseFromUrlWithResult(url, playlistId);
    return result.channels;
  }

  /// Parse M3U content from a URL (returns full result with unsupported schemes)
  static Future<M3UParseResult> parseFromUrlWithResult(String url, int playlistId) async {
    try {
      debugPrint('DEBUG: 开始从URL获取播放列表内容: $url');

      // Use Dio for better handling of large files and redirects
      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 30);
      dio.options.receiveTimeout = const Duration(seconds: 30);

      final response = await dio.get(
        url,
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null && status < 400,
        ),
      );

      debugPrint('DEBUG: 成功获取播放列表内容，状态码: ${response.statusCode}');
      debugPrint('DEBUG: 内容大小: ${response.data.toString().length} 字符');

      final result = parse(response.data.toString(), playlistId);
      debugPrint('DEBUG: URL解析完成，共解析出 ${result.channels.length} 个频道');

      return result;
    } catch (e) {
      debugPrint('DEBUG: 从URL获取播放列表时出错: $e');
      // 简化错误信息
      String errorMsg = 'Failed to load playlist';
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('404')) {
        errorMsg = 'Playlist not found (404)';
      } else if (errorStr.contains('403')) {
        errorMsg = 'Access denied (403)';
      } else if (errorStr.contains('timeout') || errorStr.contains('timed out')) {
        errorMsg = 'Connection timeout';
      } else if (errorStr.contains('socket') || errorStr.contains('connection')) {
        errorMsg = 'Network connection failed';
      } else if (errorStr.contains('certificate') || errorStr.contains('ssl')) {
        errorMsg = 'SSL certificate error';
      }
      throw Exception(errorMsg);
    }
  }

  /// Parse M3U content from a local file (returns full result with unsupported schemes)
  static Future<M3UParseResult> parseFromFileWithResult(String filePath, int playlistId) async {
    try {
      debugPrint('DEBUG: 开始从本地文件读取播放列表: $filePath');
      final file = File(filePath);

      if (!await file.exists()) {
        debugPrint('DEBUG: 文件不存在: $filePath');
        throw Exception('File does not exist: $filePath');
      }

      final content = await file.readAsString();
      debugPrint('DEBUG: 成功读取本地文件，内容大小: ${content.length} 字符');

      final result = parse(content, playlistId);
      debugPrint('DEBUG: 本地文件解析完成，共解析出 ${result.channels.length} 个频道');

      return result;
    } catch (e) {
      debugPrint('DEBUG: 读取本地播放列表文件时出错: $e');
      throw Exception('Error reading playlist file: $e');
    }
  }

  /// Parse M3U content from a local file (backwards compatible, returns channels only)
  static Future<List<Channel>> parseFromFile(String filePath, int playlistId) async {
    final result = await parseFromFileWithResult(filePath, playlistId);
    return result.channels;
  }



  /// Parse M3U content string
  /// Merges channels with same tvg-name/epgId into single channel with multiple sources
  static M3UParseResult parse(String content, int playlistId) {
    debugPrint('DEBUG: 开始解析M3U内容，播放列表ID: $playlistId');

    final List<Channel> rawChannels = [];
    final Set<String> unsupportedSchemes = {};
    final lines = LineSplitter.split(content).toList();
    String? epgUrl;

    debugPrint('DEBUG: 内容总行数: ${lines.length}');

    if (lines.isEmpty) {
      debugPrint('DEBUG: 内容为空，返回空频道列表');
      return M3UParseResult(channels: rawChannels, epgUrl: epgUrl, unsupportedSchemes: unsupportedSchemes);
    }

    // Check for valid M3U header and extract EPG URL from first few lines
    bool foundHeader = false;
    for (int i = 0; i < lines.length && i < 10; i++) {
      final line = lines[i].trim();
      if (line.startsWith(_extM3U)) {
        foundHeader = true;
        // Extract x-tvg-url from this line
        final extractedUrl = _extractEpgUrl(line);
        if (extractedUrl != null) {
          epgUrl = extractedUrl;
          debugPrint('DEBUG: 从M3U头部提取到EPG URL: $epgUrl');
          break;
        }
      }
    }

    if (!foundHeader) {
      debugPrint('DEBUG: 警告 - 缺少M3U头部标记，尝试继续解析');
    }

    String? currentName;
    String? currentLogo;
    String? currentGroup;
    String? currentEpgId;
    bool currentSupportsCatchUp = false;
    String? currentCatchUpSource;
    String? currentCatchUpType;
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
        // Parse catch-up TV attributes
        currentSupportsCatchUp = parsed['supportsCatchUp'] == 'true';
        currentCatchUpSource = parsed['catchUpSource'];
        currentCatchUpType = parsed['catchUpType'];
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
              supportsCatchUp: currentSupportsCatchUp,
              catchUpSource: currentCatchUpSource,
              catchUpType: currentCatchUpType,
            );

            rawChannels.add(channel);
            validChannelCount++;
          } else {
            invalidUrlCount++;
            try {
              final uri = Uri.parse(url);
              if (uri.hasScheme) {
                unsupportedSchemes.add(uri.scheme);
              }
            } catch (e) {}
            debugPrint('DEBUG: 无效的URL在第${i + 1}行: $line');
          }
        } else {
          debugPrint('DEBUG: 找到URL但没有对应的频道名称在第${i + 1}行: $line');
        }

        // Reset for next entry
        currentName = null;
        currentLogo = null;
        currentGroup = null;
        currentEpgId = null;
        currentSupportsCatchUp = false;
        currentCatchUpSource = null;
        currentCatchUpType = null;
      }
    }

    debugPrint('DEBUG: 原始解析完成 - 有效频道: $validChannelCount, 无效URL: $invalidUrlCount');
    if (unsupportedSchemes.isNotEmpty) {
      debugPrint('DEBUG: 不支持的协议: ${unsupportedSchemes.join(", ")}');
    }

    // Merge channels with same epgId (tvg-name) into single channel with multiple sources
    final List<Channel> mergedChannels = _mergeChannelSources(rawChannels);
    
    debugPrint('DEBUG: 合并后频道数: ${mergedChannels.length} (原始: ${rawChannels.length})');

    // Save parse result with EPG URL
    _lastParseResult = M3UParseResult(
      channels: mergedChannels,
      epgUrl: epgUrl,
      unsupportedSchemes: unsupportedSchemes,
    );

    return _lastParseResult!;
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
        final existingIsSpecial = specialGroups.any(
          (g) => existing.groupName?.toLowerCase().contains(g.toLowerCase()) ?? false
        );
        final newIsSpecial = specialGroups.any(
          (g) => channel.groupName?.toLowerCase().contains(g.toLowerCase()) ?? false
        );
        
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
    // Match x-tvg-url="..." or url-tvg="..."
    final patterns = [
      RegExp(r'x-tvg-url="([^"]+)"', caseSensitive: false),
      RegExp(r'url-tvg="([^"]+)"', caseSensitive: false),
      RegExp(r"x-tvg-url='([^']+)'", caseSensitive: false),
      RegExp(r"url-tvg='([^']+)'", caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(headerLine);
      if (match != null && match.groupCount >= 1) {
        final urls = match.group(1);
        if (urls != null && urls.isNotEmpty) {
          // If multiple URLs separated by comma, return the first one
          return urls.split(',').first.trim();
        }
      }
    }
    return null;
  }

  /// Parse EXTINF line and extract metadata
  static Map<String, String?> _parseExtInf(String line) {
    String? name;
    String? logo;
    String? group;
    String? epgId;
    bool supportsCatchUp = false;
    String? catchUpSource;
    String? catchUpType;

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

    // Parse catch-up TV attributes
    final catchup = attributes['catchup'];
    if (catchup != null && catchup.isNotEmpty && catchup != 'none') {
      supportsCatchUp = true;
    }
    catchUpSource = attributes['catchup-source'];
    catchUpType = attributes['catchup-type'];

    // Debug logging for logo parsing
    if (logo != null && logo.isNotEmpty) {
      debugPrint('DEBUG: 解析到台标URL: $logo, 频道: $name');
    }

    // Debug logging for catch-up parsing
    if (supportsCatchUp && catchUpSource != null) {
      debugPrint('DEBUG: 解析到回放配置: $name, catchup-source: $catchUpSource');
    }

    return {
      'name': name,
      'logo': logo,
      'group': group,
      'epgId': epgId,
      'supportsCatchUp': supportsCatchUp.toString(),
      'catchUpSource': catchUpSource,
      'catchUpType': catchUpType,
    };
  }

  /// Parse key="value" attributes from a string
  static Map<String, String> _parseAttributes(String content) {
    final Map<String, String> attributes = {};

    // Regular expression to match key="value" or key=value patterns
    final RegExp attrRegex = RegExp(r'(\S+?)=["\u0027]?([^"\u0027]+)["\u0027]?(?:\s|$)');

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
          (uri.scheme == 'http' || uri.scheme == 'https' || 
           uri.scheme == 'rtmp' || uri.scheme == 'rtsp' || 
           uri.scheme == 'mms' || uri.scheme == 'mmsh' || uri.scheme == 'mmst' ||
           uri.scheme == 'rtp' || uri.scheme == 'udp' || uri.scheme == 'igmp');

      if (!isValid) {
        debugPrint('DEBUG: URL验证失败 - Scheme: ${uri.scheme}, Host: ${uri.host}');
      }

      return isValid;
    } catch (e) {
      debugPrint('DEBUG: URL解析错误: $url, 错误: $e');
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
