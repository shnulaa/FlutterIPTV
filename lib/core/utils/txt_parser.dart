import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/channel.dart';
import '../services/service_locator.dart';

/// Parser for TXT playlist files (genre format)
/// Format:
/// Category,#genre#
/// Channel Name,URL
/// Channel Name,URL
class TXTParser {
  /// Parse TXT content from a URL
  static Future<List<Channel>> parseFromUrl(String url, int playlistId) async {
    try {
      ServiceLocator.log.d('DEBUG: 开始从URL获取TXT播放列表内容: $url');

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

      ServiceLocator.log.d('DEBUG: 成功获取TXT播放列表内容，状态码: ${response.statusCode}');
      ServiceLocator.log
          .d('DEBUG: 内容大小: ${response.data.toString().length} 字符');

      // 使用 compute 在独立 isolate 中解析，避免阻塞主线程
      final channels = await compute(
          _parseInIsolate, _ParseParams(response.data.toString(), playlistId));
      ServiceLocator.log.d('DEBUG: TXT URL解析完成，共解析出 ${channels.length} 个频道');

      return channels;
    } catch (e) {
      ServiceLocator.log.d('DEBUG: 从URL获取TXT播放列表时出错: $e');

      final errorStr = e.toString().toLowerCase();

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

  /// Parse TXT content from a local file
  static Future<List<Channel>> parseFromFile(
      String filePath, int playlistId) async {
    try {
      ServiceLocator.log.d('DEBUG: 开始从本地文件读取TXT播放列表: $filePath');
      final file = File(filePath);

      if (!await file.exists()) {
        ServiceLocator.log.d('DEBUG: 文件不存在: $filePath');
        throw Exception('File does not exist: $filePath');
      }

      final content = await file.readAsString();
      ServiceLocator.log.d('DEBUG: 成功读取TXT本地文件，内容大小: ${content.length} 字符');

      // 使用 compute 在独立 isolate 中解析，避免阻塞主线程
      final channels =
          await compute(_parseInIsolate, _ParseParams(content, playlistId));
      ServiceLocator.log.d('DEBUG: TXT本地文件解析完成，共解析出 ${channels.length} 个频道');

      return channels;
    } catch (e) {
      ServiceLocator.log.d('DEBUG: 读取TXT本地播放列表文件时出错: $e');
      throw Exception('Error reading playlist file: $e');
    }
  }

  /// Parse TXT content string
  /// Format: Category,#genre#
  ///         Channel Name,URL
  /// Merges channels with same name into single channel with multiple sources
  static List<Channel> parse(String content, int playlistId) {
    // 注意：此方法可能在 isolate 中运行，不能使用 ServiceLocator.log
    // ServiceLocator.log.d('DEBUG: 开始解析TXT内容，播放列表ID: $playlistId');

    final List<Channel> rawChannels = [];
    final lines = LineSplitter.split(content).toList();

    // ServiceLocator.log.d('DEBUG: TXT内容总行数: ${lines.length}');

    if (lines.isEmpty) {
      // ServiceLocator.log.d('DEBUG: TXT内容为空，返回空频道列表');
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
        // ServiceLocator.log.d('DEBUG: 找到分类: $currentGroup');
        continue;
      }

      // Parse channel line: Channel Name,URL
      final parts = line.split(',');
      if (parts.length >= 2) {
        final name = parts[0].trim();
        final url =
            parts.sublist(1).join(',').trim(); // Handle URLs with commas

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
          // if (name.isEmpty) {
          //   ServiceLocator.log.d('DEBUG: 第${i + 1}行频道名称为空: $line');
          // } else {
          //   ServiceLocator.log.d('DEBUG: 第${i + 1}行URL无效: $url');
          // }
        }
      } else {
        invalidLineCount++;
        // ServiceLocator.log.d('DEBUG: 第${i + 1}行格式不正确: $line');
      }
    }

    // ServiceLocator.log.d('DEBUG: TXT原始解析完成 - 有效频道: $validChannelCount, 无效行: $invalidLineCount');

    // Merge channels with same name into single channel with multiple sources
    final List<Channel> mergedChannels = _mergeChannelSources(rawChannels);

    // ServiceLocator.log.d('DEBUG: TXT合并后频道数: ${mergedChannels.length} (原始: ${rawChannels.length})');

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

/// 用于传递参数到 isolate 的类
class _ParseParams {
  final String content;
  final int playlistId;

  _ParseParams(this.content, this.playlistId);
}

/// Isolate 中执行的解析函数（必须是顶层函数或静态函数）
List<Channel> _parseInIsolate(_ParseParams params) {
  return TXTParser.parse(params.content, params.playlistId);
}
