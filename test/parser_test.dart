import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('M3U Parsing Test', () {
    const m3uContent = '''
#EXTM3U
#EXTINF:-1 group-title="💓4K(Test),#genre#" ,苏州4k
https://live-auth.51kandianshi.com/szgd/csztv4k_hd.m3u8
#EXTINF:-1 tvg-name="CCTV1" tvg-logo="https://live.fanmingming.com/tv/CCTV1.png" group-title="🐼中央电视",CCTV1
http://183.207.248.71/PLTV/3/224/3221228213/1.m3u8\$南京移动
''';

    final channels = parse(m3uContent, 1);

    expect(channels.length, 2);

    // First channel - No logo
    expect(channels[0].name, '苏州4k');
    expect(channels[0].logoUrl, null);

    // Second channel - Has logo
    expect(channels[1].name, 'CCTV1');
    expect(channels[1].logoUrl, 'https://live.fanmingming.com/tv/CCTV1.png');
    // Also check if URL is cleaned (it won't be with current logic, but we can verify)
    print('URL 2: ${channels[1].url}');
  });
}

// Minimal Channel class mock for testing logic
class Channel {
  final int playlistId;
  final String name;
  final String url;
  final String? logoUrl;
  final String? groupName;
  final String? epgId;

  Channel({
    required this.playlistId,
    required this.name,
    required this.url,
    this.logoUrl,
    this.groupName,
    this.epgId,
  });
}

// The parsing logic copied from M3UParser
List<Channel> parse(String content, int playlistId) {
  final List<Channel> channels = [];
  final lines = LineSplitter.split(content).toList();
  const _extInf = '#EXTINF:';

  String? currentName;
  String? currentLogo;
  String? currentGroup;
  String? currentEpgId;

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;

    if (line.startsWith(_extInf)) {
      String content = line.substring(_extInf.length);
      final lastCommaIndex = content.lastIndexOf(',');
      if (lastCommaIndex != -1) {
        currentName = content.substring(lastCommaIndex + 1).trim();
        content = content.substring(0, lastCommaIndex);
      }

      final attributes = _parseAttributes(content);
      currentLogo = attributes['tvg-logo'] ?? attributes['logo'];
      currentGroup = attributes['group-title'] ?? attributes['tvg-group'];
      currentEpgId = attributes['tvg-id'] ?? attributes['tvg-name'];
    } else if (line.isNotEmpty && !line.startsWith('#')) {
      if (currentName != null) {
        channels.add(Channel(
          playlistId: playlistId,
          name: currentName,
          url: line,
          logoUrl: currentLogo,
          groupName: currentGroup ?? 'Uncategorized',
          epgId: currentEpgId,
        ));
      }
      currentName = null;
      currentLogo = null;
      currentGroup = null;
      currentEpgId = null;
    }
  }
  return channels;
}

Map<String, String> _parseAttributes(String content) {
  final Map<String, String> attributes = {};
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
