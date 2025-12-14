import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';

import '../models/channel.dart';

/// Parser for M3U/M3U8 playlist files
class M3UParser {
  static const String _extM3U = '#EXTM3U';
  static const String _extInf = '#EXTINF:';
  static const String _extGrp = '#EXTGRP:';

  /// Parse M3U content from a URL
  static Future<List<Channel>> parseFromUrl(String url, int playlistId) async {
    try {
      // Use Dio for better handling of large files and redirects
      final dio = Dio();
      final response = await dio.get(
        url,
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null && status < 400,
        ),
      );

      return parse(response.data.toString(), playlistId);
    } catch (e) {
      throw Exception('Error fetching playlist from URL: $e');
    }
  }

  /// Parse M3U content from a local file
  static Future<List<Channel>> parseFromFile(
      String filePath, int playlistId) async {
    try {
      final file = File(filePath);
      final content = await file.readAsString();
      return parse(content, playlistId);
    } catch (e) {
      throw Exception('Error reading playlist file: $e');
    }
  }

  /// Parse M3U content string
  static List<Channel> parse(String content, int playlistId) {
    final List<Channel> channels = [];
    final lines = LineSplitter.split(content).toList();

    if (lines.isEmpty) return channels;

    // Check for valid M3U header
    if (!lines.first.trim().startsWith(_extM3U)) {
      // Try parsing anyway, some files don't have the header
    }

    String? currentName;
    String? currentLogo;
    String? currentGroup;
    String? currentEpgId;

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
        if (currentName != null && _isValidUrl(line)) {
          channels.add(Channel(
            playlistId: playlistId,
            name: currentName,
            url: line.split('\$').first.trim(),
            logoUrl: currentLogo,
            groupName: currentGroup ?? 'Uncategorized',
            epgId: currentEpgId,
          ));
        }

        // Reset for next entry
        currentName = null;
        currentLogo = null;
        currentGroup = null;
        currentEpgId = null;
      }
    }

    return channels;
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
      return uri.hasScheme &&
          (uri.scheme == 'http' ||
              uri.scheme == 'https' ||
              uri.scheme == 'rtmp' ||
              uri.scheme == 'rtsp' ||
              uri.scheme == 'mms');
    } catch (_) {
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
