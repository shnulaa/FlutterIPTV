/// Channel type enum
enum ChannelType {
  live,      // 直播
  vod,       // 点播
  replay,    // 回放
  unknown,   // 未知
}

/// Represents an IPTV channel with multiple sources
class Channel {
  final int? id;
  final int playlistId;
  final String name;
  final String url; // Primary URL (first source)
  final List<String> sources; // All source URLs
  final String? logoUrl;
  final String? groupName;
  final String? epgId;
  final bool isActive;
  final DateTime createdAt;

  // Runtime properties (not stored in database)
  bool isFavorite;
  bool isCurrentlyPlaying;
  int currentSourceIndex; // Current playing source index

  String? fallbackLogoUrl;

  Channel({
    this.id,
    required this.playlistId,
    required this.name,
    required this.url,
    List<String>? sources,
    this.logoUrl,
    this.groupName,
    this.epgId,
    this.isActive = true,
    DateTime? createdAt,
    this.isFavorite = false,
    this.isCurrentlyPlaying = false,
    this.currentSourceIndex = 0,
    this.fallbackLogoUrl,
  }) : sources = sources ?? [url],
       createdAt = createdAt ?? DateTime.now();

  /// Get current source URL
  String get currentUrl => sources.isNotEmpty 
      ? sources[currentSourceIndex.clamp(0, sources.length - 1)] 
      : url;

  /// Check if channel has multiple sources
  bool get hasMultipleSources => sources.length > 1;

  /// Get source count
  int get sourceCount => sources.length;

  /// Determine channel type based on group name and URL
  ChannelType get type {
    final group = groupName?.toLowerCase() ?? '';
    final urlLower = currentUrl.toLowerCase();
    
    // 回放关键词（优先级最高，因为回放也可能是 .mp4 文件）
    if (group.contains('回放') || group.contains('replay') ||
        group.contains('时移') || group.contains('catchup') ||
        group.contains('回看')) {
      return ChannelType.replay;
    }
    
    // 点播关键词
    if (group.contains('电影') || group.contains('movie') ||
        group.contains('电视剧') || group.contains('series') || group.contains('剧集') ||
        group.contains('音乐') || group.contains('music') || group.contains('mv') ||
        group.contains('舞曲') || group.contains('dance') ||
        group.contains('点播') || group.contains('vod') ||
        group.contains('综艺') || group.contains('variety') ||
        group.contains('动漫') || group.contains('anime') ||
        group.contains('纪录片') || group.contains('documentary')) {
      return ChannelType.vod;
    }
    
    // URL 扩展名判断（点播文件）
    if (urlLower.endsWith('.mp4') || urlLower.endsWith('.mkv') ||
        urlLower.endsWith('.avi') || urlLower.endsWith('.mov') ||
        urlLower.endsWith('.flv') || urlLower.endsWith('.wmv') ||
        urlLower.endsWith('.m4v') || urlLower.endsWith('.3gp')) {
      return ChannelType.vod;
    }
    
    // 直播关键词
    if (group.contains('直播') || group.contains('live') ||
        group.contains('央视') || group.contains('cctv') ||
        group.contains('卫视') || group.contains('频道') || 
        group.contains('channel') || group.contains('tv')) {
      return ChannelType.live;
    }
    
    // URL 特征判断（直播流）
    if (urlLower.contains('/live/') || urlLower.contains('live.') ||
        urlLower.endsWith('.m3u8') || urlLower.contains('.m3u8?')) {
      return ChannelType.live;
    }
    
    return ChannelType.unknown;
  }
  
  /// Check if channel is seekable (can use progress bar)
  bool get isSeekable => type == ChannelType.vod || type == ChannelType.replay;
  
  /// Check if channel is live stream
  bool get isLive => type == ChannelType.live;

  factory Channel.fromMap(Map<String, dynamic> map) {
    final logoUrl = map['logo_url'] as String?;
    var fallbackLogoUrl = map['fallback_logo_url'] as String?;
    final url = map['url'] as String;
    
    // Convert PNG to WebP for fallback logo URLs
    if (fallbackLogoUrl != null && fallbackLogoUrl.endsWith('.png')) {
      fallbackLogoUrl = fallbackLogoUrl.replaceAll('.png', '.webp');
    }
    
    // Parse sources from JSON string or use single URL
    List<String> sources = [url];
    if (map['sources'] != null) {
      try {
        final sourcesStr = map['sources'] as String;
        if (sourcesStr.isNotEmpty) {
          sources = sourcesStr.split('|||');
        }
      } catch (e) {
        // Fallback to single URL
      }
    }

    return Channel(
      id: map['id'] as int?,
      playlistId: map['playlist_id'] as int,
      name: map['name'] as String,
      url: url,
      sources: sources,
      logoUrl: logoUrl,
      fallbackLogoUrl: fallbackLogoUrl,
      groupName: map['group_name'] as String?,
      epgId: map['epg_id'] as String?,
      isActive: (map['is_active'] as int?) == 1,
      createdAt: map['created_at'] != null ? DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int) : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'playlist_id': playlistId,
      'name': name,
      'url': url,
      'sources': sources.join('|||'), // Store as delimiter-separated string
      'logo_url': logoUrl,
      'fallback_logo_url': fallbackLogoUrl,
      'group_name': groupName,
      'epg_id': epgId,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  Channel copyWith({
    int? id,
    int? playlistId,
    String? name,
    String? url,
    List<String>? sources,
    String? logoUrl,
    String? groupName,
    String? epgId,
    bool? isActive,
    DateTime? createdAt,
    bool? isFavorite,
    bool? isCurrentlyPlaying,
    int? currentSourceIndex,
    String? fallbackLogoUrl,
  }) {
    return Channel(
      id: id ?? this.id,
      playlistId: playlistId ?? this.playlistId,
      name: name ?? this.name,
      url: url ?? this.url,
      sources: sources ?? List.from(this.sources),
      logoUrl: logoUrl ?? this.logoUrl,
      groupName: groupName ?? this.groupName,
      epgId: epgId ?? this.epgId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      isFavorite: isFavorite ?? this.isFavorite,
      isCurrentlyPlaying: isCurrentlyPlaying ?? this.isCurrentlyPlaying,
      currentSourceIndex: currentSourceIndex ?? this.currentSourceIndex,
      fallbackLogoUrl: fallbackLogoUrl ?? this.fallbackLogoUrl,
    );
  }

  /// Add a source URL to this channel
  Channel addSource(String sourceUrl) {
    if (!sources.contains(sourceUrl)) {
      return copyWith(sources: [...sources, sourceUrl]);
    }
    return this;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Channel && other.id == id && other.url == url;
  }

  @override
  int get hashCode => id.hashCode ^ url.hashCode;

  @override
  String toString() => 'Channel(id: $id, name: $name, group: $groupName)';
}
