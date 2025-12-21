import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class AppStrings {
  final Locale locale;
  final Map<String, String> _localizedValues;

  AppStrings(this.locale, this._localizedValues);

  static AppStrings? of(BuildContext context) {
    return Localizations.of<AppStrings>(context, AppStrings);
  }

  static const LocalizationsDelegate<AppStrings> delegate =
      _AppStringsDelegate();

  String get playlistManager => _localizedValues['playlistManager']!;
  String get addNewPlaylist => _localizedValues['addNewPlaylist']!;
  String get playlistName => _localizedValues['playlistName']!;
  String get playlistUrl => _localizedValues['playlistUrl']!;
  String get addFromUrl => _localizedValues['addFromUrl']!;
  String get fromFile => _localizedValues['fromFile']!;
  String get importing => _localizedValues['importing']!;
  String get noPlaylists => _localizedValues['noPlaylists']!;
  String get addFirstPlaylist => _localizedValues['addFirstPlaylist']!;
  String get deletePlaylist => _localizedValues['deletePlaylist']!;
  String get deleteConfirmation => _localizedValues['deleteConfirmation']!;
  String get cancel => _localizedValues['cancel']!;
  String get delete => _localizedValues['delete']!;
  String get settings => _localizedValues['settings']!;
  String get language => _localizedValues['language']!;
  String get unknown => _localizedValues['unknown']!;
  String get save => _localizedValues['save']!;
  String get error => _localizedValues['error']!;
  String get success => _localizedValues['success']!;
  String get active => _localizedValues['active']!;
  String get refresh => _localizedValues['refresh']!;
  String get updated => _localizedValues['updated']!;
  String get version => _localizedValues['version']!;
  String get categories => _localizedValues['categories']!;
  String get allChannels => _localizedValues['allChannels']!;
  String get channels => _localizedValues['channels']!;
  String get noChannelsFound => _localizedValues['noChannelsFound']!;
  String get removeFavorites => _localizedValues['removeFavorites']!;
  String get addFavorites => _localizedValues['addFavorites']!;
  String get channelInfo => _localizedValues['channelInfo']!;
  String get playback => _localizedValues['playback']!;
  String get autoPlay => _localizedValues['autoPlay']!;
  String get autoPlaySubtitle => _localizedValues['autoPlaySubtitle']!;
  String get hardwareDecoding => _localizedValues['hardwareDecoding']!;
  String get hardwareDecodingSubtitle => _localizedValues['hardwareDecodingSubtitle']!;
  String get bufferSize => _localizedValues['bufferSize']!;
  String get seconds => _localizedValues['seconds']!;
  String get playlists => _localizedValues['playlists']!;
  String get autoRefresh => _localizedValues['autoRefresh']!;
  String get autoRefreshSubtitle => _localizedValues['autoRefreshSubtitle']!;
  String get refreshInterval => _localizedValues['refreshInterval']!;
  String get hours => _localizedValues['hours']!;
  String get days => _localizedValues['days']!;
  String get day => _localizedValues['day']!;
  String get rememberLastChannel => _localizedValues['rememberLastChannel']!;
  String get rememberLastChannelSubtitle => _localizedValues['rememberLastChannelSubtitle']!;
  String get epg => _localizedValues['epg']!;
  String get enableEpg => _localizedValues['enableEpg']!;
  String get enableEpgSubtitle => _localizedValues['enableEpgSubtitle']!;
  String get epgUrl => _localizedValues['epgUrl']!;
  String get notConfigured => _localizedValues['notConfigured']!;
  String get parentalControl => _localizedValues['parentalControl']!;
  String get enableParentalControl => _localizedValues['enableParentalControl']!;
  String get enableParentalControlSubtitle => _localizedValues['enableParentalControlSubtitle']!;
  String get changePin => _localizedValues['changePin']!;
  String get changePinSubtitle => _localizedValues['changePinSubtitle']!;
  String get about => _localizedValues['about']!;
  String get platform => _localizedValues['platform']!;
  String get resetAllSettings => _localizedValues['resetAllSettings']!;
  String get resetSettingsSubtitle => _localizedValues['resetSettingsSubtitle']!;
  String get enterEpgUrl => _localizedValues['enterEpgUrl']!;
  String get setPin => _localizedValues['setPin']!;
  String get enterPin => _localizedValues['enterPin']!;
  String get resetSettings => _localizedValues['resetSettings']!;
  String get resetConfirm => _localizedValues['resetConfirm']!;
  String get reset => _localizedValues['reset']!;
  String get pleaseEnterPlaylistName => _localizedValues['pleaseEnterPlaylistName']!;
  String get pleaseEnterPlaylistUrl => _localizedValues['pleaseEnterPlaylistUrl']!;
  String get playlistAdded => _localizedValues['playlistAdded']!;
  String get playlistRefreshed => _localizedValues['playlistRefreshed']!;
  String get playlistRefreshFailed => _localizedValues['playlistRefreshFailed']!;
  String get playlistDeleted => _localizedValues['playlistDeleted']!;
  String get playlistImported => _localizedValues['playlistImported']!;
  String get errorPickingFile => _localizedValues['errorPickingFile']!;
  String get minutesAgo => _localizedValues['minutesAgo']!;
  String get hoursAgo => _localizedValues['hoursAgo']!;
  String get daysAgo => _localizedValues['daysAgo']!;
  String get live => _localizedValues['live']!;
  String get buffering => _localizedValues['buffering']!;
  String get paused => _localizedValues['paused']!;
  String get loading => _localizedValues['loading']!;
  String get playbackError => _localizedValues['playbackError']!;
  String get retry => _localizedValues['retry']!;
  String get goBack => _localizedValues['goBack']!;
  String get playbackSettings => _localizedValues['playbackSettings']!;
  String get playbackSpeed => _localizedValues['playbackSpeed']!;
  String get shortcutsHint => _localizedValues['shortcutsHint']!;
  String get lotusIptv => _localizedValues['lotusIptv']!;
  String get professionalIptvPlayer => _localizedValues['professionalIptvPlayer']!;
  String get searchChannels => _localizedValues['searchChannels']!;
  String get searchHint => _localizedValues['searchHint']!;
  String get typeToSearch => _localizedValues['typeToSearch']!;
  String get popularCategories => _localizedValues['popularCategories']!;
  String get sports => _localizedValues['sports']!;
  String get movies => _localizedValues['movies']!;
  String get news => _localizedValues['news']!;
  String get music => _localizedValues['music']!;
  String get kids => _localizedValues['kids']!;
  String get noResultsFound => _localizedValues['noResultsFound']!;
  String get noChannelsMatch => _localizedValues['noChannelsMatch']!;
  String get resultsFor => _localizedValues['resultsFor']!;
  String get favorites => _localizedValues['favorites']!;
  String get clearAll => _localizedValues['clearAll']!;
  String get noFavoritesYet => _localizedValues['noFavoritesYet']!;
  String get favoritesHint => _localizedValues['favoritesHint']!;
  String get browseChannels => _localizedValues['browseChannels']!;
  String get removedFromFavorites => _localizedValues['removedFromFavorites']!;
  String get undo => _localizedValues['undo']!;
  String get clearAllFavorites => _localizedValues['clearAllFavorites']!;
  String get clearFavoritesConfirm => _localizedValues['clearFavoritesConfirm']!;
  String get allFavoritesCleared => _localizedValues['allFavoritesCleared']!;
  String get home => _localizedValues['home']!;
  String get managePlaylists => _localizedValues['managePlaylists']!;
  String get noPlaylistsYet => _localizedValues['noPlaylistsYet']!;
  String get addFirstPlaylistHint => _localizedValues['addFirstPlaylistHint']!;
  String get addPlaylist => _localizedValues['addPlaylist']!;
  String get totalChannels => _localizedValues['totalChannels']!;
  
  // New translations
  String get volumeNormalization => _localizedValues['volumeNormalization']!;
  String get volumeNormalizationSubtitle => _localizedValues['volumeNormalizationSubtitle']!;
  String get volumeBoost => _localizedValues['volumeBoost']!;
  String get noBoost => _localizedValues['noBoost']!;
  String get checkUpdate => _localizedValues['checkUpdate']!;
  String get checkUpdateSubtitle => _localizedValues['checkUpdateSubtitle']!;
  String get decodingMode => _localizedValues['decodingMode']!;
  String get decodingModeAuto => _localizedValues['decodingModeAuto']!;
  String get decodingModeHardware => _localizedValues['decodingModeHardware']!;
  String get decodingModeSoftware => _localizedValues['decodingModeSoftware']!;
  String get decodingModeAutoDesc => _localizedValues['decodingModeAutoDesc']!;
  String get decodingModeHardwareDesc => _localizedValues['decodingModeHardwareDesc']!;
  String get decodingModeSoftwareDesc => _localizedValues['decodingModeSoftwareDesc']!;
  String get volumeBoostLow => _localizedValues['volumeBoostLow']!;
  String get volumeBoostSlightLow => _localizedValues['volumeBoostSlightLow']!;
  String get volumeBoostNormal => _localizedValues['volumeBoostNormal']!;
  String get volumeBoostSlightHigh => _localizedValues['volumeBoostSlightHigh']!;
  String get volumeBoostHigh => _localizedValues['volumeBoostHigh']!;
  String get chinese => _localizedValues['chinese']!;
  String get english => _localizedValues['english']!;
  String get scanToImport => _localizedValues['scanToImport']!;
  String get importingPlaylist => _localizedValues['importingPlaylist']!;
  String get importSuccess => _localizedValues['importSuccess']!;
  String get importFailed => _localizedValues['importFailed']!;
  String get serverStartFailed => _localizedValues['serverStartFailed']!;
  String get processing => _localizedValues['processing']!;
  String get testChannel => _localizedValues['testChannel']!;
  String get unavailable => _localizedValues['unavailable']!;
  String get localFile => _localizedValues['localFile']!;
  
  // Home screen
  String get recommendedChannels => _localizedValues['recommendedChannels']!;
  String get myFavorites => _localizedValues['myFavorites']!;
  String get continueWatching => _localizedValues['continueWatching']!;
  String get channelStats => _localizedValues['channelStats']!;
  String get noPlaylistYet => _localizedValues['noPlaylistYet']!;
  String get addM3uToStart => _localizedValues['addM3uToStart']!;
  String get search => _localizedValues['search']!;
  
  // Player hints
  String get playerHintTV => _localizedValues['playerHintTV']!;
  String get playerHintDesktop => _localizedValues['playerHintDesktop']!;
  
  // More UI strings
  String get more => _localizedValues['more']!;
  String get close => _localizedValues['close']!;
  String get startingServer => _localizedValues['startingServer']!;
  String get selectM3uFile => _localizedValues['selectM3uFile']!;
  String get noFileSelected => _localizedValues['noFileSelected']!;
  String get epgAutoApplied => _localizedValues['epgAutoApplied']!;
  String get addFirstPlaylistTV => _localizedValues['addFirstPlaylistTV']!;
  String get qrStep1 => _localizedValues['qrStep1']!;
  String get qrStep2 => _localizedValues['qrStep2']!;
  String get qrStep3 => _localizedValues['qrStep3']!;

  // Map access for dynamic keys if needed
  String operator [](String key) => _localizedValues[key] ?? key;
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'zh'].contains(locale.languageCode);

  @override
  Future<AppStrings> load(Locale locale) {
    return SynchronousFuture<AppStrings>(
        AppStrings(locale, _getValues(locale)));
  }

  @override
  bool shouldReload(_AppStringsDelegate old) => false;

  Map<String, String> _getValues(Locale locale) {
    if (locale.languageCode == 'zh') {
      return _zhValues;
    } else {
      return _enValues;
    }
  }
  
  static const Map<String, String> _zhValues = {
    'playlistManager': '播放列表管理',
    'addNewPlaylist': '添加新播放列表',
    'playlistName': '播放列表名称',
    'playlistUrl': 'M3U/M3U8 链接',
    'addFromUrl': '从链接添加',
    'fromFile': '从文件导入',
    'importing': '导入中...',
    'noPlaylists': '暂无播放列表',
    'addFirstPlaylist': '请在上方添加您的第一个 M3U 播放列表',
    'deletePlaylist': '删除播放列表',
    'deleteConfirmation': '确定要删除 "{name}" 吗？这将同时删除该列表下的所有频道。',
    'cancel': '取消',
    'delete': '删除',
    'settings': '设置',
    'language': '语言',
    'unknown': '未知',
    'save': '保存',
    'error': '错误',
    'success': '成功',
    'active': '当前使用',
    'refresh': '刷新',
    'updated': '更新于',
    'version': '版本',
    'categories': '分类',
    'allChannels': '所有频道',
    'channels': '频道',
    'noChannelsFound': '未找到频道',
    'removeFavorites': '取消收藏',
    'addFavorites': '添加到收藏',
    'channelInfo': '频道信息',
    'playback': '播放',
    'autoPlay': '自动播放',
    'autoPlaySubtitle': '选择频道时自动开始播放',
    'hardwareDecoding': '硬件解码',
    'hardwareDecodingSubtitle': '使用硬件加速进行视频播放',
    'bufferSize': '缓冲大小',
    'seconds': '秒',
    'playlists': '播放列表',
    'autoRefresh': '自动刷新',
    'autoRefreshSubtitle': '定期自动更新播放列表',
    'refreshInterval': '刷新间隔',
    'hours': '小时',
    'days': '天',
    'day': '天',
    'rememberLastChannel': '记忆最后播放',
    'rememberLastChannelSubtitle': '恢复播放上次观看的频道',
    'epg': '电子节目单 (EPG)',
    'enableEpg': '启用 EPG',
    'enableEpgSubtitle': '显示频道节目信息',
    'epgUrl': 'EPG 链接',
    'notConfigured': '未配置',
    'parentalControl': '家长控制',
    'enableParentalControl': '启用家长控制',
    'enableParentalControlSubtitle': '观看特定内容需要 PIN 码',
    'changePin': '修改 PIN 码',
    'changePinSubtitle': '更新家长控制 PIN 码',
    'about': '关于',
    'platform': '平台',
    'resetAllSettings': '重置所有设置',
    'resetSettingsSubtitle': '恢复所有设置到默认值',
    'enterEpgUrl': '输入 EPG XMLTV 链接',
    'setPin': '设置 PIN 码',
    'enterPin': '输入 4 位 PIN 码',
    'resetSettings': '重置设置',
    'resetConfirm': '确定要将所有设置重置为默认值吗？',
    'reset': '重置',
    'pleaseEnterPlaylistName': '请输入播放列表名称',
    'pleaseEnterPlaylistUrl': '请输入播放列表链接',
    'playlistAdded': '已添加 "{name}"',
    'playlistRefreshed': '播放列表刷新成功',
    'playlistRefreshFailed': '播放列表刷新失败',
    'playlistDeleted': '播放列表已删除',
    'playlistImported': '播放列表导入成功',
    'errorPickingFile': '选择文件时出错: {error}',
    'minutesAgo': '分钟前',
    'hoursAgo': '小时前',
    'daysAgo': '天前',
    'live': '直播',
    'buffering': '缓冲中...',
    'paused': '暂停',
    'loading': '加载中...',
    'playbackError': '播放错误',
    'retry': '重试',
    'goBack': '返回',
    'playbackSettings': '播放设置',
    'playbackSpeed': '播放速度',
    'shortcutsHint': '左/右: 快进退 • 上/下: 换台 • 回车: 播放/暂停 • M: 静音',
    'lotusIptv': 'Lotus IPTV',
    'professionalIptvPlayer': '专业 IPTV 播放器',
    'searchChannels': '搜索频道',
    'searchHint': '搜索频道...',
    'typeToSearch': '输入频道名称或分类进行搜索',
    'popularCategories': '热门分类',
    'sports': '体育',
    'movies': '电影',
    'news': '新闻',
    'music': '音乐',
    'kids': '少儿',
    'noResultsFound': '未找到结果',
    'noChannelsMatch': '没有找到匹配 "{query}" 的频道',
    'resultsFor': '搜索 "{query}" 的结果: {count} 个',
    'favorites': '收藏',
    'clearAll': '清空',
    'noFavoritesYet': '暂无收藏',
    'favoritesHint': '长按频道可添加到收藏',
    'browseChannels': '浏览频道',
    'removedFromFavorites': '已从收藏中移除 "{name}"',
    'undo': '撤销',
    'clearAllFavorites': '清空所有收藏',
    'clearFavoritesConfirm': '确定要清空所有收藏的频道吗？',
    'allFavoritesCleared': '所有收藏已清空',
    'home': '首页',
    'managePlaylists': '管理播放列表',
    'noPlaylistsYet': '暂无播放列表',
    'addFirstPlaylistHint': '添加您的第一个 M3U 播放列表以开始观看',
    'addPlaylist': '添加播放列表',
    'totalChannels': '频道总数',
    // New translations
    'volumeNormalization': '音量平衡',
    'volumeNormalizationSubtitle': '自动调节不同频道的音量差异',
    'volumeBoost': '音量增益',
    'noBoost': '无增益',
    'checkUpdate': '检查更新',
    'checkUpdateSubtitle': '检查是否有新版本可用',
    'decodingMode': '解码模式',
    'decodingModeAuto': '自动',
    'decodingModeHardware': '硬解',
    'decodingModeSoftware': '软解',
    'decodingModeAutoDesc': '自动选择最佳方式，推荐',
    'decodingModeHardwareDesc': '强制硬解，部分设备可能报错',
    'decodingModeSoftwareDesc': '使用CPU解码，兼容性好但耗电',
    'volumeBoostLow': '大幅降低音量',
    'volumeBoostSlightLow': '略微降低音量',
    'volumeBoostNormal': '保持原始音量',
    'volumeBoostSlightHigh': '略微提高音量',
    'volumeBoostHigh': '大幅提高音量',
    'chinese': '中文',
    'english': 'English',
    'scanToImport': '扫码导入播放列表',
    'importingPlaylist': '正在导入',
    'importSuccess': '导入成功',
    'importFailed': '导入失败',
    'serverStartFailed': '无法启动本地服务器，请检查网络连接',
    'processing': '正在处理，请稍候...',
    'testChannel': '测试频道',
    'unavailable': '失效',
    'localFile': '本地文件',
    // Home screen
    'recommendedChannels': '推荐频道',
    'myFavorites': '我的收藏',
    'continueWatching': '继续观看',
    'channelStats': '{channels} 频道 · {categories} 分类 · {favorites} 收藏',
    'noPlaylistYet': '还没有播放列表',
    'addM3uToStart': '添加 M3U 播放列表开始观看',
    'search': '搜索',
    // Player hints
    'playerHintTV': '↑↓ 切换频道 · ← 分类列表 · OK 播放/暂停',
    'playerHintDesktop': '左/右: 快进退 · 上/下: 换台 · 回车: 播放/暂停 · M: 静音',
    // More UI strings
    'more': '更多',
    'close': '关闭',
    'startingServer': '正在启动服务...',
    'selectM3uFile': '请在文件管理器中选择M3U/M3U8文件',
    'noFileSelected': '未选择文件。请确保您的设备已连接USB存储设备或已配置网络存储。',
    'epgAutoApplied': '已自动应用EPG源',
    'addFirstPlaylistTV': '添加您的第一个M3U播放列表\n您可以通过USB设备导入或使用手机扫码导入',
    'qrStep1': '使用手机扫描左侧二维码',
    'qrStep2': '在网页中输入链接或上传文件',
    'qrStep3': '点击导入，电视自动接收',
  };
  
  static const Map<String, String> _enValues = {
    'playlistManager': 'Playlist Manager',
    'addNewPlaylist': 'Add New Playlist',
    'playlistName': 'Playlist Name',
    'playlistUrl': 'M3U/M3U8 URL',
    'addFromUrl': 'Add from URL',
    'fromFile': 'From File',
    'importing': 'Importing...',
    'noPlaylists': 'No Playlists',
    'addFirstPlaylist': 'Add your first M3U playlist above',
    'deletePlaylist': 'Delete Playlist',
    'deleteConfirmation': 'Are you sure you want to delete "{name}"? This will also remove all channels from this playlist.',
    'cancel': 'Cancel',
    'delete': 'Delete',
    'settings': 'Settings',
    'language': 'Language',
    'unknown': 'Unknown',
    'save': 'Save',
    'error': 'Error',
    'success': 'Success',
    'active': 'ACTIVE',
    'refresh': 'Refresh',
    'updated': 'Updated',
    'version': 'Version',
    'categories': 'Categories',
    'allChannels': 'All Channels',
    'channels': 'channels',
    'noChannelsFound': 'No channels found',
    'removeFavorites': 'Remove from Favorites',
    'addFavorites': 'Add to Favorites',
    'channelInfo': 'Channel Info',
    'playback': 'Playback',
    'autoPlay': 'Auto-play',
    'autoPlaySubtitle': 'Automatically start playback when selecting a channel',
    'hardwareDecoding': 'Hardware Decoding',
    'hardwareDecodingSubtitle': 'Use hardware acceleration for video playback',
    'bufferSize': 'Buffer Size',
    'seconds': 'seconds',
    'playlists': 'Playlists',
    'autoRefresh': 'Auto-refresh',
    'autoRefreshSubtitle': 'Automatically update playlists periodically',
    'refreshInterval': 'Refresh Interval',
    'hours': 'hours',
    'days': 'days',
    'day': 'day',
    'rememberLastChannel': 'Remember Last Channel',
    'rememberLastChannelSubtitle': 'Resume playback from last watched channel',
    'epg': 'EPG (Electronic Program Guide)',
    'enableEpg': 'Enable EPG',
    'enableEpgSubtitle': 'Show program information for channels',
    'epgUrl': 'EPG URL',
    'notConfigured': 'Not configured',
    'parentalControl': 'Parental Control',
    'enableParentalControl': 'Enable Parental Control',
    'enableParentalControlSubtitle': 'Require PIN to access certain content',
    'changePin': 'Change PIN',
    'changePinSubtitle': 'Update your parental control PIN',
    'about': 'About',
    'platform': 'Platform',
    'resetAllSettings': 'Reset All Settings',
    'resetSettingsSubtitle': 'Restore all settings to default values',
    'enterEpgUrl': 'Enter EPG XMLTV URL',
    'setPin': 'Set PIN',
    'enterPin': 'Enter 4-digit PIN',
    'resetSettings': 'Reset Settings',
    'resetConfirm': 'Are you sure you want to reset all settings to their default values?',
    'reset': 'Reset',
    'pleaseEnterPlaylistName': 'Please enter a playlist name',
    'pleaseEnterPlaylistUrl': 'Please enter a playlist URL',
    'playlistAdded': 'Added "{name}"',
    'playlistRefreshed': 'Playlist refreshed successfully',
    'playlistRefreshFailed': 'Failed to refresh playlist',
    'playlistDeleted': 'Playlist deleted',
    'playlistImported': 'Playlist imported successfully',
    'errorPickingFile': 'Error picking file: {error}',
    'minutesAgo': 'm ago',
    'hoursAgo': 'h ago',
    'daysAgo': 'd ago',
    'live': 'LIVE',
    'buffering': 'Buffering...',
    'paused': 'Paused',
    'loading': 'Loading...',
    'playbackError': 'Playback Error',
    'retry': 'Retry',
    'goBack': 'Go Back',
    'playbackSettings': 'Playback Settings',
    'playbackSpeed': 'Playback Speed',
    'shortcutsHint': 'Left/Right: Seek • Up/Down: Change Channel • Enter: Play/Pause • M: Mute',
    'lotusIptv': 'Lotus IPTV',
    'professionalIptvPlayer': 'Professional IPTV Player',
    'searchChannels': 'Search Channels',
    'searchHint': 'Search channels...',
    'typeToSearch': 'Type to search by channel name or category',
    'popularCategories': 'Popular Categories',
    'sports': 'Sports',
    'movies': 'Movies',
    'news': 'News',
    'music': 'Music',
    'kids': 'Kids',
    'noResultsFound': 'No Results Found',
    'noChannelsMatch': 'No channels match "{query}"',
    'resultsFor': '{count} result(s) for "{query}"',
    'favorites': 'Favorites',
    'clearAll': 'Clear All',
    'noFavoritesYet': 'No Favorites Yet',
    'favoritesHint': 'Long press on a channel to add it to favorites',
    'browseChannels': 'Browse Channels',
    'removedFromFavorites': 'Removed "{name}" from favorites',
    'undo': 'Undo',
    'clearAllFavorites': 'Clear All Favorites',
    'clearFavoritesConfirm': 'Are you sure you want to remove all channels from your favorites?',
    'allFavoritesCleared': 'All favorites cleared',
    'home': 'Home',
    'managePlaylists': 'Manage Playlists',
    'noPlaylistsYet': 'No Playlists Yet',
    'addFirstPlaylistHint': 'Add your first M3U playlist to start watching',
    'addPlaylist': 'Add Playlist',
    'totalChannels': 'Total Channels',
    // New translations
    'volumeNormalization': 'Volume Normalization',
    'volumeNormalizationSubtitle': 'Auto-adjust volume differences between channels',
    'volumeBoost': 'Volume Boost',
    'noBoost': 'No boost',
    'checkUpdate': 'Check for Updates',
    'checkUpdateSubtitle': 'Check if a new version is available',
    'decodingMode': 'Decoding Mode',
    'decodingModeAuto': 'Auto',
    'decodingModeHardware': 'Hardware',
    'decodingModeSoftware': 'Software',
    'decodingModeAutoDesc': 'Automatically choose best option. Recommended.',
    'decodingModeHardwareDesc': 'Force MediaCodec. May cause errors on some devices.',
    'decodingModeSoftwareDesc': 'Use CPU decoding. More compatible but uses more power.',
    'volumeBoostLow': 'Significantly lower volume',
    'volumeBoostSlightLow': 'Slightly lower volume',
    'volumeBoostNormal': 'Keep original volume',
    'volumeBoostSlightHigh': 'Slightly higher volume',
    'volumeBoostHigh': 'Significantly higher volume',
    'chinese': '中文',
    'english': 'English',
    'scanToImport': 'Scan to Import Playlist',
    'importingPlaylist': 'Importing',
    'importSuccess': 'Import successful',
    'importFailed': 'Import failed',
    'serverStartFailed': 'Failed to start local server. Please check network connection.',
    'processing': 'Processing, please wait...',
    'testChannel': 'Test Channel',
    'unavailable': 'Unavailable',
    'localFile': 'Local File',
    // Home screen
    'recommendedChannels': 'Recommended',
    'myFavorites': 'My Favorites',
    'continueWatching': 'Continue Watching',
    'channelStats': '{channels} channels · {categories} categories · {favorites} favorites',
    'noPlaylistYet': 'No Playlists Yet',
    'addM3uToStart': 'Add M3U playlist to start watching',
    'search': 'Search',
    // Player hints
    'playerHintTV': '↑↓ Switch Channel · ← Categories · OK Play/Pause',
    'playerHintDesktop': 'Left/Right: Seek · Up/Down: Switch · Enter: Play/Pause · M: Mute',
    // More UI strings
    'more': 'More',
    'close': 'Close',
    'startingServer': 'Starting server...',
    'selectM3uFile': 'Please select an M3U/M3U8 file',
    'noFileSelected': 'No file selected. Please ensure your device has USB storage or network storage configured.',
    'epgAutoApplied': 'EPG source auto-applied',
    'addFirstPlaylistTV': 'Add your first M3U playlist\nYou can import via USB or scan QR code',
    'qrStep1': 'Scan the QR code with your phone',
    'qrStep2': 'Enter URL or upload file on the webpage',
    'qrStep3': 'Click import, TV receives automatically',
  };
}
