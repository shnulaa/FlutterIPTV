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

  // Catch-up TV related fields
  final bool supportsCatchUp; // Whether this channel supports catch-up TV
  final String? catchUpSource; // Catch-up URL template (may contain time variables)
  final String? catchUpType; // Catch-up type: "default", "vod", "shift"
  final int catchUpDays; // Number of days of catch-up available (default 7)

  // Runtime properties (not stored in database)
  bool isFavorite;
  bool isCurrentlyPlaying;
  int currentSourceIndex; // Current playing source index

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
    this.supportsCatchUp = false,
    this.catchUpSource,
    this.catchUpType,
    this.catchUpDays = 7,
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

  /// Check if this channel supports catch-up TV
  bool get hasCatchUp => supportsCatchUp && catchUpSource != null && catchUpSource!.isNotEmpty;

  factory Channel.fromMap(Map<String, dynamic> map) {
    final logoUrl = map['logo_url'] as String?;
    final url = map['url'] as String;
    
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
      groupName: map['group_name'] as String?,
      epgId: map['epg_id'] as String?,
      isActive: (map['is_active'] as int?) == 1,
      createdAt: map['created_at'] != null ? DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int) : DateTime.now(),
      supportsCatchUp: (map['supports_catchup'] as int?) == 1,
      catchUpSource: map['catchup_source'] as String?,
      catchUpType: map['catchup_type'] as String?,
      catchUpDays: map['catchup_days'] as int? ?? 7,
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
      'group_name': groupName,
      'epg_id': epgId,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'supports_catchup': supportsCatchUp ? 1 : 0,
      'catchup_source': catchUpSource,
      'catchup_type': catchUpType,
      'catchup_days': catchUpDays,
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
    bool? supportsCatchUp,
    String? catchUpSource,
    String? catchUpType,
    int? catchUpDays,
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
      supportsCatchUp: supportsCatchUp ?? this.supportsCatchUp,
      catchUpSource: catchUpSource ?? this.catchUpSource,
      catchUpType: catchUpType ?? this.catchUpType,
      catchUpDays: catchUpDays ?? this.catchUpDays,
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
