import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/channel.dart';

/// Parser for TXT playlist files (genre format)
/// Format: 
/// Category,#genre#
/// Channel Name,URL
/// Channel Name,URL
class TXTParser {
  /// Parse TXT content from a URL
  static Future<List<Channel>> parseFromUrl(String url, int playlistId) async {
    try {
      debugPrint('DEBUG: 开始从URL获取TXT播放列表内容: $url');

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

      debugPrint('DEBUG: 成功获取TXT播放列表内容，状态码: ${response.statusCode}');
      debugPrint('DEBUG: 内容大小: ${response.data.toString().length} 字符');

      final channels = parse(response.data.toString(), playlistId);
      debugPrint('DEBUG: TXT URL解析完成，共解析出 ${channels.length} 个频道');

      return channels;
    } catch (e) {
      debugPrint('DEBUG: 从URL获取TXT播放列表时出错: $e');
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

  /// Parse TXT content from a local file
  static Future<List<Channel>> parseFromFile(String filePath, int playlistId) async {
    try {
      debugPrint('DEBUG: 开始从本地文件读取TXT播放列表: $filePath');
      final file = File(filePath);

      if (!await file.exists()) {
        debugPrint('DEBUG: 文件不存在: $filePath');
        throw Exception('File does not exist: $filePath');
      }

      final content = await file.readAsString();
      debugPrint('DEBUG: 成功读取TXT本地文件，内容大小: ${content.length} 字符');

      final channels = parse(content, playlistId);
      debugPrint('DEBUG: TXT本地文件解析完成，共解析出 ${channels.length} 个频道');

      return channels;
    } catch (e) {
      debugPrint('DEBUG: 读取TXT本地播放列表文件时出错: $e');
      throw Exception('Error reading playlist file: $e');
    }
  }

  /// Parse TXT content string
  /// Format: Category,#genre#
  ///         Channel Name,URL
  /// Merges channels with same name into single channel with multiple sources
  static List<Channel> parse(String content, int playlistId) {
    debugPrint('DEBUG: 开始解析TXT内容，播放列表ID: $playlistId');

    final List<Channel> rawChannels = [];
    final lines = LineSplitter.split(content).toList();

    debugPrint('DEBUG: TXT内容总行数: ${lines.length}');

    if (lines.isEmpty) {
      debugPrint('DEBUG: TXT内容为空，返回空频道列表');
      return rawChannels;
    }

    String currentGroup = 'Uncategorized';
    int validChannelCount = 0;
    int invalidLineCount = 0;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      if (line.isEmpty) continue;

      // Check if this is a category line (ends with ,#genre#)
      if (line.endsWith(',#genre#')) {
        currentGroup = line.substring(0, line.length - 8).trim();
        if (currentGroup.isEmpty) {
          currentGroup = 'Uncategorized';
        }
        debugPrint('DEBUG: 找到分类: $currentGroup');
        continue;
      }

      // Parse channel line: Channel Name,URL
      final parts = line.split(',');
      if (parts.length >= 2) {
        final name = parts[0].trim();
        final url = parts.sublist(1).join(',').trim(); // Handle URLs with commas

        if (name.isNotEmpty && _isValidUrl(url)) {
          final channel = Channel(
            playlistId: playlistId,
            name: name,
            url: url,
            groupName: currentGroup,
          );

          rawChannels.add(channel);
          validChannelCount++;
        } else {
          invalidLineCount++;
          if (name.isEmpty) {
            debugPrint('DEBUG: 第${i + 1}行频道名称为空: $line');
          } else {
            debugPrint('DEBUG: 第${i + 1}行URL无效: $url');
          }
        }
      } else {
        invalidLineCount++;
        debugPrint('DEBUG: 第${i + 1}行格式不正确: $line');
      }
    }

    debugPrint('DEBUG: TXT原始解析完成 - 有效频道: $validChannelCount, 无效行: $invalidLineCount');

    // Merge channels with same name into single channel with multiple sources
    final List<Channel> mergedChannels = _mergeChannelSources(rawChannels);
    
    debugPrint('DEBUG: TXT合并后频道数: ${mergedChannels.length} (原始: ${rawChannels.length})');

    return mergedChannels;
  }

  /// Merge channels with same name into single channel with multiple sources
  /// Preserves the order of first occurrence, but prefers non-special groups
  static List<Channel> _mergeChannelSources(List<Channel> channels) {
    final Map<String, Channel> mergedMap = {};
    final List<String> orderKeys = []; // Preserve order

    // Special groups that should not be the primary group
    final specialGroups = {'🕘️更新时间', '更新时间', 'update', 'info'};

    for (final channel in channels) {
      // Use channel name as merge key (TXT format doesn't have epgId)
      final mergeKey = channel.name;
      
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

  /// Check if a string is a valid URL
  static bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final isValid = uri.hasScheme && 
          (uri.scheme == 'http' || uri.scheme == 'https' || 
           uri.scheme == 'rtmp' || uri.scheme == 'rtsp' || 
           uri.scheme == 'mms' || uri.scheme == 'mmsh' || uri.scheme == 'mmst' ||
           uri.scheme == 'rtp' || uri.scheme == 'udp' || uri.scheme == 'igmp');

      return isValid;
    } catch (e) {
      return false;
    }
  }

  /// Generate TXT content from a list of channels
  static String generate(List<Channel> channels) {
    final buffer = StringBuffer();
    
    // Group channels by category
    final Map<String, List<Channel>> groupedChannels = {};
    for (final channel in channels) {
      final group = channel.groupName ?? 'Uncategorized';
      groupedChannels.putIfAbsent(group, () => []).add(channel);
    }

    // Write each group
    for (final entry in groupedChannels.entries) {
      buffer.writeln('${entry.key},#genre#');
      for (final channel in entry.value) {
        buffer.writeln('${channel.name},${channel.url}');
      }
    }

    return buffer.toString();
  }
}
