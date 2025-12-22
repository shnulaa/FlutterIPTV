import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/channel.dart';

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

      final channels = parse(response.data.toString(), playlistId);
      debugPrint('DEBUG: URL解析完成，共解析出 ${channels.length} 个频道');

      return channels;
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

  /// Parse M3U content from a local file
  static Future<List<Channel>> parseFromFile(
      String filePath, int playlistId) async {
    try {
      debugPrint('DEBUG: 开始从本地文件读取播放列表: $filePath');
      final file = File(filePath);

      if (!await file.exists()) {
        debugPrint('DEBUG: 文件不存在: $filePath');
        throw Exception('File does not exist: $filePath');
      }

      final content = await file.readAsString();
      debugPrint('DEBUG: 成功读取本地文件，内容大小: ${content.length} 字符');

      final channels = parse(content, playlistId);
      debugPrint('DEBUG: 本地文件解析完成，共解析出 ${channels.length} 个频道');

      return channels;
    } catch (e) {
      debugPrint('DEBUG: 读取本地播放列表文件时出错: $e');
      throw Exception('Error reading playlist file: $e');
    }
  }

  /// Parse M3U content string
  static List<Channel> parse(String content, int playlistId) {
    debugPrint('DEBUG: 开始解析M3U内容，播放列表ID: $playlistId');

    final List<Channel> channels = [];
    final lines = LineSplitter.split(content).toList();
    String? epgUrl;

    debugPrint('DEBUG: 内容总行数: ${lines.length}');

    if (lines.isEmpty) {
      debugPrint('DEBUG: 内容为空，返回空频道列表');
      return channels;
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
      // Try parsing anyway, some files don't have the header
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
          if (_isValidUrl(line)) {
            final channel = Channel(
              playlistId: playlistId,
              name: currentName,
              url: line.split('\$').first.trim(),
              logoUrl: currentLogo,
              groupName: currentGroup ?? 'Uncategorized',
              epgId: currentEpgId,
            );

            // Debug logging for channel creation
            debugPrint(
                'DEBUG: 创建频道 - 名称: ${channel.name}, 台标: ${channel.logoUrl ?? "无"}');

            channels.add(channel);
            validChannelCount++;
          } else {
            invalidUrlCount++;
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
      }
    }

    debugPrint(
        'DEBUG: 解析完成 - 有效频道: $validChannelCount, 无效URL: $invalidUrlCount');
    
    // Save parse result with EPG URL
    _lastParseResult = M3UParseResult(channels: channels, epgUrl: epgUrl);
    
    return channels;
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
      debugPrint('DEBUG: 解析到台标URL: $logo, 频道: $name');
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
      buffer.writeln(channel.url);
      buffer.writeln();
    }

    return buffer.toString();
  }
}
