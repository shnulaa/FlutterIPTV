import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/log_service.dart';
import '../../../core/theme/app_theme.dart';

class SettingsProvider extends ChangeNotifier {
  // Keys for SharedPreferences
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyAutoRefresh = 'auto_refresh';
  static const String _keyRefreshInterval = 'refresh_interval';
  static const String _keyDefaultQuality = 'default_quality';
  static const String _keyHardwareDecoding = 'hardware_decoding';
  static const String _keyDecodingMode = 'decoding_mode'; // New: auto, hardware, software
  static const String _keyWindowsHwdecMode = 'windows_hwdec_mode'; // auto-safe, auto-copy, d3d11va, dxva2
  static const String _keyAllowSoftwareFallback = 'allow_software_fallback';
  static const String _keyVideoOutput = 'video_output'; // auto, libmpv, gpu
  static const String _keyChannelMergeRule = 'channel_merge_rule'; // New: name, name_group
  static const String _keyBufferSize = 'buffer_size';
  static const String _keyLastPlaylistId = 'last_playlist_id';
  static const String _keyEnableEpg = 'enable_epg';
  static const String _keyEpgUrl = 'epg_url';
  static const String _keyParentalControl = 'parental_control';
  static const String _keyParentalPin = 'parental_pin';
  static const String _keyAutoPlay = 'auto_play';
  static const String _keyRememberLastChannel = 'remember_last_channel';
  static const String _keyLastChannelId = 'last_channel_id';
  static const String _keyLocale = 'locale';
  static const String _keyVolumeNormalization = 'volume_normalization';
  static const String _keyVolumeBoost = 'volume_boost';
  static const String _keyBufferStrength = 'buffer_strength'; // fast, balanced, stable
  static const String _keyShowFps = 'show_fps';
  static const String _keyShowClock = 'show_clock';
  static const String _keyShowNetworkSpeed = 'show_network_speed';
  static const String _keyShowVideoInfo = 'show_video_info';
  static const String _keyProgressBarMode = 'progress_bar_mode'; // auto, always, never
  static const String _keyEnableMultiScreen = 'enable_multi_screen';
  static const String _keyDefaultScreenPosition = 'default_screen_position';
  static const String _keyActiveScreenIndex = 'active_screen_index';
  static const String _keyLastPlayMode = 'last_play_mode'; // 'single' or 'multi'
  static const String _keyLastMultiScreenChannels = 'last_multi_screen_channels'; // JSON string of channel IDs
  static const String _keyLastMultiScreenSourceIndexes =
      'last_multi_screen_source_indexes'; // comma-separated source indexes
  static const String _keyShowMultiScreenChannelName = 'show_multi_screen_channel_name'; // 多屏播放是否显示频道名称
  static const String _keySeekStepSeconds = 'seek_step_seconds'; // 快进/快退跨度（秒）
  static const String _keyDarkColorScheme = 'dark_color_scheme';
  static const String _keyLightColorScheme = 'light_color_scheme';
  static const String _keyFontFamily = 'font_family';
  static const String _keySimpleMenu = 'simple_menu';
  static const String _keyLogLevel = 'log_level'; // debug, release, off
  static const String _keyMobileOrientation = 'mobile_orientation'; // portrait, landscape, auto
  static const String _keyLastAppVersion = 'last_app_version'; // 用于检测版本更新
  static const String _keyShowWatchHistoryOnHome = 'show_watch_history_on_home'; // 首页是否显示观看记录
  static const String _keyShowFavoritesOnHome = 'show_favorites_on_home'; // 首页是否显示收藏夹

  // Settings values
  String _themeMode = 'dark';
  bool _autoRefresh = false;
  int _refreshInterval = 24; // hours
  String _defaultQuality = 'auto';
  bool _hardwareDecoding = true;
  String _decodingMode = 'auto'; // New: auto, hardware, software
  String _windowsHwdecMode = 'auto-safe';
  bool _allowSoftwareFallback = true;
  String _videoOutput = 'auto';
  String _channelMergeRule = 'name_group'; // New: name, name_group
  int _bufferSize = 30; // seconds
  int? _lastPlaylistId;
  bool _enableEpg = true;
  String? _epgUrl;
  bool _parentalControl = false;
  String? _parentalPin;
  bool _autoPlay = false;
  bool _rememberLastChannel = true;
  int? _lastChannelId;
  Locale? _locale;
  bool _volumeNormalization = false;
  int _volumeBoost = 0; // -20 to +20 dB
  String _bufferStrength = 'fast'; // fast, balanced, stable
  bool _showFps = true; // 默认显示FPS
  bool _showClock = true; // 默认显示时间
  bool _showNetworkSpeed = true; // 默认显示网速
  bool _showVideoInfo = true; // 默认显示分辨率码率
  String _progressBarMode = 'auto'; // 进度条显示模式：auto, always, never
  bool _enableMultiScreen = true; // 默认开启分屏
  int _defaultScreenPosition = 1; // 默认播放位置（左上角）
  int _activeScreenIndex = 0; // 当前活动窗口索引
  String _lastPlayMode = 'single'; // 上次播放模式：'single' 或 'multi'
  List<int?> _lastMultiScreenChannels = [null, null, null, null]; // 分屏频道ID列表
  List<int> _lastMultiScreenSourceIndexes = [0, 0, 0, 0]; // 分屏源索引列表
  bool _showMultiScreenChannelName = false; // 多屏播放是否显示频道名称（默认关闭）
  int _seekStepSeconds = 10; // 快进/快退跨度（秒），默认10秒
  String _darkColorScheme = 'ocean'; // 黑暗模式配色方案（默认海洋）
  String _lightColorScheme = 'sky'; // 明亮模式配色方案（默认天空）
  String _fontFamily = 'System'; // 字体设置（默认System，使用系统字体）
  bool _simpleMenu = true; // 是否使用简单菜单栏（不展开）- 默认启用
  String _logLevel = 'off'; // 日志级别：debug, release, off - 默认关闭
  String _mobileOrientation = 'portrait'; // 手机端屏幕方向：portrait, landscape, auto - 默认竖屏
  bool _showWatchHistoryOnHome = false; // 首页是否显示观看记录 - 默认不显示
  bool _showFavoritesOnHome = false; // 首页是否显示收藏夹 - 默认不显示

  // Getters
  String get themeMode => _themeMode;
  bool get autoRefresh => _autoRefresh;
  int get refreshInterval => _refreshInterval;
  String get defaultQuality => _defaultQuality;
  bool get hardwareDecoding => _hardwareDecoding;
  String get decodingMode => _decodingMode;
  String get windowsHwdecMode => _windowsHwdecMode;
  bool get allowSoftwareFallback => _allowSoftwareFallback;
  String get videoOutput => _videoOutput;
  String get channelMergeRule => _channelMergeRule;
  int get bufferSize => _bufferSize;
  int? get lastPlaylistId => _lastPlaylistId;
  bool get enableEpg => _enableEpg;
  String? get epgUrl => _epgUrl;
  bool get parentalControl => _parentalControl;
  bool get autoPlay => _autoPlay;
  bool get rememberLastChannel => _rememberLastChannel;
  int? get lastChannelId => _lastChannelId;
  Locale? get locale => _locale;
  bool get volumeNormalization => _volumeNormalization;
  int get volumeBoost => _volumeBoost;
  String get bufferStrength => _bufferStrength;
  bool get showFps => _showFps;
  bool get showClock => _showClock;
  bool get showNetworkSpeed => _showNetworkSpeed;
  bool get showVideoInfo => _showVideoInfo;
  String get progressBarMode => _progressBarMode;
  bool get enableMultiScreen => _enableMultiScreen;
  int get defaultScreenPosition => _defaultScreenPosition;
  int get activeScreenIndex => _activeScreenIndex;
  String get lastPlayMode => _lastPlayMode;
  List<int?> get lastMultiScreenChannels => _lastMultiScreenChannels;
  List<int> get lastMultiScreenSourceIndexes => _lastMultiScreenSourceIndexes;
  bool get showMultiScreenChannelName => _showMultiScreenChannelName;
  int get seekStepSeconds => _seekStepSeconds;
  String get darkColorScheme => _darkColorScheme;
  String get lightColorScheme => _lightColorScheme;
  String get fontFamily => _fontFamily;
  bool get simpleMenu => _simpleMenu;
  String get logLevel => _logLevel;
  String get mobileOrientation => _mobileOrientation;
  bool get showWatchHistoryOnHome => _showWatchHistoryOnHome;
  bool get showFavoritesOnHome => _showFavoritesOnHome;
  
  /// 获取当前应该使用的配色方案
  String get currentColorScheme {
    if (_themeMode == 'dark') return _darkColorScheme;
    if (_themeMode == 'light') return _lightColorScheme;
    // 跟随系统时需要根据系统亮度决定
    // 这里返回黑暗模式配色作为默认，实际使用时会在 UI 层判断
    return _darkColorScheme;
  }

  SettingsProvider() {
    _loadSettings();
    _checkVersionUpdate();
  }

  Future<void> _loadSettings() async {
    final prefs = ServiceLocator.prefs;

    _themeMode = prefs.getString(_keyThemeMode) ?? 'dark';
    _autoRefresh = prefs.getBool(_keyAutoRefresh) ?? false;
    _refreshInterval = prefs.getInt(_keyRefreshInterval) ?? 24;
    _defaultQuality = prefs.getString(_keyDefaultQuality) ?? 'auto';
    _hardwareDecoding = prefs.getBool(_keyHardwareDecoding) ?? true;
    _decodingMode = prefs.getString(_keyDecodingMode) ?? 'auto';
    _windowsHwdecMode = prefs.getString(_keyWindowsHwdecMode) ?? 'auto-safe';
    _allowSoftwareFallback = prefs.getBool(_keyAllowSoftwareFallback) ?? true;
    _videoOutput = prefs.getString(_keyVideoOutput) ?? 'auto';
    _channelMergeRule = prefs.getString(_keyChannelMergeRule) ?? 'name_group';
    _bufferSize = prefs.getInt(_keyBufferSize) ?? 30;
    _lastPlaylistId = prefs.getInt(_keyLastPlaylistId);
    _enableEpg = prefs.getBool(_keyEnableEpg) ?? true;
    _epgUrl = prefs.getString(_keyEpgUrl);
    _parentalControl = prefs.getBool(_keyParentalControl) ?? false;
    _parentalPin = prefs.getString(_keyParentalPin);
    _autoPlay = prefs.getBool(_keyAutoPlay) ?? false;
    _rememberLastChannel = prefs.getBool(_keyRememberLastChannel) ?? true;
    _lastChannelId = prefs.getInt(_keyLastChannelId);

    final localeCode = prefs.getString(_keyLocale);
    if (localeCode != null) {
      final parts = localeCode.split('_');
      _locale = Locale(parts[0], parts.length > 1 ? parts[1] : null);
    }
    _volumeNormalization = prefs.getBool(_keyVolumeNormalization) ?? false;
    _volumeBoost = prefs.getInt(_keyVolumeBoost) ?? 0;
    _bufferStrength = prefs.getString(_keyBufferStrength) ?? 'fast';
    _showFps = prefs.getBool(_keyShowFps) ?? true;
    _showClock = prefs.getBool(_keyShowClock) ?? true;
    _showNetworkSpeed = prefs.getBool(_keyShowNetworkSpeed) ?? true;
    _showVideoInfo = prefs.getBool(_keyShowVideoInfo) ?? true;
    _progressBarMode = prefs.getString(_keyProgressBarMode) ?? 'auto';
    _enableMultiScreen = prefs.getBool(_keyEnableMultiScreen) ?? true;
    _defaultScreenPosition = prefs.getInt(_keyDefaultScreenPosition) ?? 1;
    _activeScreenIndex = prefs.getInt(_keyActiveScreenIndex) ?? 0;
    _lastPlayMode = prefs.getString(_keyLastPlayMode) ?? 'single';
    _showMultiScreenChannelName = prefs.getBool(_keyShowMultiScreenChannelName) ?? false;
    _seekStepSeconds = prefs.getInt(_keySeekStepSeconds) ?? 10;
    ServiceLocator.log.d('SettingsProvider: loaded showMultiScreenChannelName=$_showMultiScreenChannelName');
    
    // 加载分屏频道ID列表
    final multiScreenChannelsJson = prefs.getString(_keyLastMultiScreenChannels);
    if (multiScreenChannelsJson != null) {
      try {
        final List<dynamic> decoded = List<dynamic>.from(
          multiScreenChannelsJson.split(',').map((s) => s.isEmpty ? null : int.tryParse(s))
        );
        _lastMultiScreenChannels = decoded.map((e) => e as int?).toList();
        while (_lastMultiScreenChannels.length < 4) {
          _lastMultiScreenChannels.add(null);
        }
      } catch (_) {
        _lastMultiScreenChannels = [null, null, null, null];
      }
    }

    final multiScreenSourceIndexesStr =
        prefs.getString(_keyLastMultiScreenSourceIndexes);
    if (multiScreenSourceIndexesStr != null) {
      try {
        final parsed = multiScreenSourceIndexesStr
            .split(',')
            .map((s) => int.tryParse(s) ?? 0)
            .toList();
        _lastMultiScreenSourceIndexes = parsed.take(4).toList();
        while (_lastMultiScreenSourceIndexes.length < 4) {
          _lastMultiScreenSourceIndexes.add(0);
        }
      } catch (_) {
        _lastMultiScreenSourceIndexes = [0, 0, 0, 0];
      }
    }
    
    // 加载配色方案设置
    _darkColorScheme = prefs.getString(_keyDarkColorScheme) ?? 'ocean';
    _lightColorScheme = prefs.getString(_keyLightColorScheme) ?? 'sky';
    
    // 加载字体设置
    _fontFamily = prefs.getString(_keyFontFamily) ?? 'System';
    
    // ✅ 字体迁移逻辑：将旧的侵权字体自动迁移到System
    if (AppTheme.fontMigrationMap.containsKey(_fontFamily)) {
      final oldFont = _fontFamily;
      _fontFamily = AppTheme.fontMigrationMap[_fontFamily]!;
      ServiceLocator.log.i('字体迁移: $oldFont → $_fontFamily');
      // 保存迁移后的字体，避免下次再检查
      await prefs.setString(_keyFontFamily, _fontFamily);
    }
    
    // 再次检查字体是否有效（防御性编程）
    if (!AppTheme.fontMap.containsKey(_fontFamily)) {
      ServiceLocator.log.w('字体无效: $_fontFamily，重置为System');
      _fontFamily = 'System';
      await prefs.setString(_keyFontFamily, _fontFamily);
    }
    
    // 加载简单菜单设置
    _simpleMenu = prefs.getBool(_keySimpleMenu) ?? true;
    
    // 加载日志级别设置
    _logLevel = prefs.getString(_keyLogLevel) ?? 'off';
    
    // 加载手机端屏幕方向设置
    _mobileOrientation = prefs.getString(_keyMobileOrientation) ?? 'portrait';
    
    // 加载首页显示设置
    _showWatchHistoryOnHome = prefs.getBool(_keyShowWatchHistoryOnHome) ?? false;
    _showFavoritesOnHome = prefs.getBool(_keyShowFavoritesOnHome) ?? false;
    
    // 不在构造函数中调用 notifyListeners()，避免 build 期间触发重建
  }

  /// 检测版本更新，如果版本更新则自动关闭开发者日志
  Future<void> _checkVersionUpdate() async {
    try {
      final prefs = ServiceLocator.prefs;
      final lastVersion = prefs.getString(_keyLastAppVersion);
      
      // 获取当前版本号
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      
      // 如果版本不同，说明应用更新了
      if (lastVersion != null && lastVersion != currentVersion) {
        ServiceLocator.log.d('检测到版本更新: $lastVersion → $currentVersion');
        
        // 自动关闭开发者日志
        if (_logLevel != 'off') {
          ServiceLocator.log.d('自动关闭开发者日志');
          await setLogLevel('off');
        }
      }
      
      // 保存当前版本号
      await prefs.setString(_keyLastAppVersion, currentVersion);
    } catch (e) {
      ServiceLocator.log.e('版本检测失败: $e');
    }
  }

  Future<void> _saveSettings() async {
    final prefs = ServiceLocator.prefs;

    await prefs.setString(_keyThemeMode, _themeMode);
    await prefs.setBool(_keyAutoRefresh, _autoRefresh);
    await prefs.setInt(_keyRefreshInterval, _refreshInterval);
    await prefs.setString(_keyDefaultQuality, _defaultQuality);
    await prefs.setBool(_keyHardwareDecoding, _hardwareDecoding);
    await prefs.setString(_keyDecodingMode, _decodingMode);
    await prefs.setString(_keyWindowsHwdecMode, _windowsHwdecMode);
    await prefs.setBool(_keyAllowSoftwareFallback, _allowSoftwareFallback);
    await prefs.setString(_keyVideoOutput, _videoOutput);
    await prefs.setString(_keyChannelMergeRule, _channelMergeRule);
    await prefs.setInt(_keyBufferSize, _bufferSize);
    if (_lastPlaylistId != null) {
      await prefs.setInt(_keyLastPlaylistId, _lastPlaylistId!);
    }
    await prefs.setBool(_keyEnableEpg, _enableEpg);
    if (_epgUrl != null) {
      await prefs.setString(_keyEpgUrl, _epgUrl!);
    }
    await prefs.setBool(_keyParentalControl, _parentalControl);
    if (_parentalPin != null) {
      await prefs.setString(_keyParentalPin, _parentalPin!);
    }
    await prefs.setBool(_keyAutoPlay, _autoPlay);
    await prefs.setBool(_keyRememberLastChannel, _rememberLastChannel);
    if (_lastChannelId != null) {
      await prefs.setInt(_keyLastChannelId, _lastChannelId!);
    }
    if (_locale != null) {
      await prefs.setString(_keyLocale, _locale!.languageCode);
    } else {
      await prefs.remove(_keyLocale);
    }
    await prefs.setBool(_keyVolumeNormalization, _volumeNormalization);
    await prefs.setInt(_keyVolumeBoost, _volumeBoost);
    await prefs.setString(_keyBufferStrength, _bufferStrength);
    await prefs.setBool(_keyShowFps, _showFps);
    await prefs.setBool(_keyShowClock, _showClock);
    await prefs.setBool(_keyShowNetworkSpeed, _showNetworkSpeed);
    await prefs.setBool(_keyShowVideoInfo, _showVideoInfo);
    await prefs.setString(_keyProgressBarMode, _progressBarMode);
    await prefs.setBool(_keyEnableMultiScreen, _enableMultiScreen);
    await prefs.setInt(_keyDefaultScreenPosition, _defaultScreenPosition);
    await prefs.setInt(_keyActiveScreenIndex, _activeScreenIndex);
    await prefs.setString(_keyLastPlayMode, _lastPlayMode);
    await prefs.setString(_keyLastMultiScreenChannels, _lastMultiScreenChannels.map((e) => e?.toString() ?? '').join(','));
    await prefs.setString(_keyLastMultiScreenSourceIndexes,
        _lastMultiScreenSourceIndexes.map((e) => e.toString()).join(','));
    await prefs.setBool(_keyShowMultiScreenChannelName, _showMultiScreenChannelName);
    await prefs.setInt(_keySeekStepSeconds, _seekStepSeconds);
    await prefs.setString(_keyDarkColorScheme, _darkColorScheme);
    await prefs.setString(_keyLightColorScheme, _lightColorScheme);
    await prefs.setString(_keyFontFamily, _fontFamily);
    await prefs.setBool(_keySimpleMenu, _simpleMenu);
    await prefs.setString(_keyLogLevel, _logLevel);
    await prefs.setString(_keyMobileOrientation, _mobileOrientation);
    await prefs.setBool(_keyShowWatchHistoryOnHome, _showWatchHistoryOnHome);
    await prefs.setBool(_keyShowFavoritesOnHome, _showFavoritesOnHome);
  }

  // Setters with persistence
  Future<void> setThemeMode(String mode) async {
    _themeMode = mode;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setAutoRefresh(bool value) async {
    _autoRefresh = value;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setRefreshInterval(int hours) async {
    _refreshInterval = hours;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setDefaultQuality(String quality) async {
    _defaultQuality = quality;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setHardwareDecoding(bool enabled) async {
    _hardwareDecoding = enabled;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setDecodingMode(String mode) async {
    _decodingMode = mode;
    // Also update hardwareDecoding based on mode for backward compatibility
    _hardwareDecoding = mode != 'software';
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setWindowsHwdecMode(String mode) async {
    _windowsHwdecMode = mode;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setAllowSoftwareFallback(bool enabled) async {
    _allowSoftwareFallback = enabled;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setVideoOutput(String output) async {
    _videoOutput = output;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setChannelMergeRule(String rule) async {
    _channelMergeRule = rule;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setBufferSize(int seconds) async {
    _bufferSize = seconds;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setLastPlaylistId(int? id) async {
    _lastPlaylistId = id;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setEnableEpg(bool enabled) async {
    _enableEpg = enabled;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setEpgUrl(String? url) async {
    _epgUrl = url;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setParentalControl(bool enabled) async {
    _parentalControl = enabled;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setParentalPin(String? pin) async {
    _parentalPin = pin;
    await _saveSettings();
    notifyListeners();
  }

  bool validateParentalPin(String pin) {
    return _parentalPin == pin;
  }

  Future<void> setAutoPlay(bool enabled) async {
    _autoPlay = enabled;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setRememberLastChannel(bool enabled) async {
    _rememberLastChannel = enabled;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setLastChannelId(int? id) async {
    _lastChannelId = id;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setLocale(Locale? locale) async {
    _locale = locale;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setVolumeNormalization(bool enabled) async {
    _volumeNormalization = enabled;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setVolumeBoost(int db) async {
    _volumeBoost = db.clamp(-20, 20);
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setBufferStrength(String strength) async {
    _bufferStrength = strength;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setShowFps(bool show) async {
    _showFps = show;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setShowClock(bool show) async {
    _showClock = show;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setShowNetworkSpeed(bool show) async {
    _showNetworkSpeed = show;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setShowVideoInfo(bool show) async {
    _showVideoInfo = show;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setProgressBarMode(String mode) async {
    if (mode == 'auto' || mode == 'always' || mode == 'never') {
      _progressBarMode = mode;
      await _saveSettings();
      notifyListeners();
    }
  }

  Future<void> setEnableMultiScreen(bool enabled) async {
    _enableMultiScreen = enabled;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setDefaultScreenPosition(int position) async {
    _defaultScreenPosition = position.clamp(1, 4);
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setActiveScreenIndex(int index) async {
    _activeScreenIndex = index.clamp(0, 3);
    await _saveSettings();
    notifyListeners();
  }

  /// 设置多屏播放是否显示频道名称
  Future<void> setShowMultiScreenChannelName(bool show) async {
    ServiceLocator.log.d('SettingsProvider: setShowMultiScreenChannelName($show)');
    _showMultiScreenChannelName = show;
    await _saveSettings();
    notifyListeners();
  }

  /// 设置快进/快退跨度（秒）
  Future<void> setSeekStepSeconds(int seconds) async {
    if (seconds == 5 || seconds == 10 || seconds == 30 || seconds == 60 || seconds == 120) {
      _seekStepSeconds = seconds;
      await _saveSettings();
      notifyListeners();
    }
  }

  /// 设置上次播放模式
  Future<void> setLastPlayMode(String mode) async {
    _lastPlayMode = mode;
    await _saveSettings();
    notifyListeners();
  }

  /// 设置分屏频道ID列表
  Future<void> setLastMultiScreenChannels(List<int?> channelIds) async {
    _lastMultiScreenChannels = List<int?>.from(channelIds);
    while (_lastMultiScreenChannels.length < 4) {
      _lastMultiScreenChannels.add(null);
    }
    await _saveSettings();
    notifyListeners();
  }

  /// 保存单频道播放状态
  Future<void> saveLastSingleChannel(int? channelId) async {
    _lastPlayMode = 'single';
    if (channelId != null) {
      _lastChannelId = channelId;
    }
    await _saveSettings();
    notifyListeners();
  }

  /// 保存分屏播放状态
  Future<void> saveLastMultiScreen(List<int?> channelIds, int activeIndex,
      {List<int>? sourceIndexes}) async {
    _lastPlayMode = 'multi';
    _lastMultiScreenChannels = List<int?>.from(channelIds);
    while (_lastMultiScreenChannels.length < 4) {
      _lastMultiScreenChannels.add(null);
    }
    _lastMultiScreenSourceIndexes =
        List<int>.from(sourceIndexes ?? _lastMultiScreenSourceIndexes);
    while (_lastMultiScreenSourceIndexes.length < 4) {
      _lastMultiScreenSourceIndexes.add(0);
    }
    _lastMultiScreenSourceIndexes =
        _lastMultiScreenSourceIndexes.take(4).map((e) => e < 0 ? 0 : e).toList();
    _activeScreenIndex = activeIndex.clamp(0, 3);
    await _saveSettings();
    notifyListeners();
  }

  /// 检查是否有分屏状态可恢复
  bool get hasMultiScreenState {
    return _lastPlayMode == 'multi' && _lastMultiScreenChannels.any((id) => id != null);
  }
  
  /// 设置黑暗模式配色方案
  Future<void> setDarkColorScheme(String scheme) async {
    ServiceLocator.log.d('SettingsProvider: 设置黑暗配色方案 - $scheme');
    _darkColorScheme = scheme;
    await _saveSettings();
    ServiceLocator.log.d('SettingsProvider: 配色方案已保存，通知监听者');
    notifyListeners();
  }
  
  /// 设置明亮模式配色方案
  Future<void> setLightColorScheme(String scheme) async {
    ServiceLocator.log.d('SettingsProvider: 设置明亮配色方案 - $scheme');
    _lightColorScheme = scheme;
    await _saveSettings();
    ServiceLocator.log.d('SettingsProvider: 配色方案已保存，通知监听者');
    notifyListeners();
  }

  /// 设置字体
  Future<void> setFontFamily(String fontFamily) async {
    ServiceLocator.log.d('SettingsProvider: 设置字体 - $fontFamily');
    _fontFamily = fontFamily;
    await _saveSettings();
    notifyListeners();
  }

  /// 设置简单菜单栏
  Future<void> setSimpleMenu(bool value) async {
    ServiceLocator.log.d('SettingsProvider: 设置简单菜单栏 - $value');
    _simpleMenu = value;
    await _saveSettings();
    notifyListeners();
  }

  /// 设置日志级别
  Future<void> setLogLevel(String level) async {
    debugPrint('SettingsProvider: 开始设置日志级别 - $level');
    _logLevel = level;
    await _saveSettings();
    
    // 更新日志服务
    final logLevel = switch (level) {
      'debug' => LogLevel.debug,
      'release' => LogLevel.release,
      'off' => LogLevel.off,
      _ => LogLevel.release,
    };
    
    debugPrint('SettingsProvider: 调用 ServiceLocator.log.setLogLevel($logLevel)');
    await ServiceLocator.log.setLogLevel(logLevel);
    
    // 写入测试日志
    debugPrint('SettingsProvider: 写入测试日志...');
    ServiceLocator.log.d('测试日志：日志级别已切换到 $level');
    ServiceLocator.log.i('测试日志：Info 级别');
    ServiceLocator.log.w('测试日志：Warning 级别');
    
    // 强制刷新日志缓冲区
    await ServiceLocator.log.flush();
    debugPrint('SettingsProvider: 日志缓冲区已刷新');
    
    notifyListeners();
  }

  /// 设置手机端屏幕方向
  Future<void> setMobileOrientation(String orientation) async {
    ServiceLocator.log.d('SettingsProvider: 设置手机端屏幕方向 - $orientation');
    _mobileOrientation = orientation;
    await _saveSettings();
    notifyListeners();
  }

  /// 设置首页是否显示观看记录
  Future<void> setShowWatchHistoryOnHome(bool show) async {
    ServiceLocator.log.d('SettingsProvider: 设置首页显示观看记录 - $show');
    _showWatchHistoryOnHome = show;
    await _saveSettings();
    notifyListeners();
  }

  /// 设置首页是否显示收藏夹
  Future<void> setShowFavoritesOnHome(bool show) async {
    ServiceLocator.log.d('SettingsProvider: 设置首页显示收藏夹 - $show');
    _showFavoritesOnHome = show;
    await _saveSettings();
    notifyListeners();
  }

  // Reset all settings to defaults
  Future<void> resetSettings() async {
    _themeMode = 'dark';
    _autoRefresh = false;
    _refreshInterval = 24;
    _defaultQuality = 'auto';
    _hardwareDecoding = true;
    _channelMergeRule = 'name_group';
    _decodingMode = 'auto';
    _windowsHwdecMode = 'auto-safe';
    _allowSoftwareFallback = true;
    _videoOutput = 'auto';
    _bufferSize = 30;
    _enableEpg = true;
    _epgUrl = null;
    _parentalControl = false;
    _parentalPin = null;
    _autoPlay = false;
    _rememberLastChannel = true;
    _volumeNormalization = false;
    _volumeBoost = 0;
    _bufferStrength = 'fast';
    _showFps = true;
    _showClock = true;
    _showNetworkSpeed = true;
    _showVideoInfo = true;
    _progressBarMode = 'auto';
    _seekStepSeconds = 10;
    _enableMultiScreen = true;
    _defaultScreenPosition = 1;
    _activeScreenIndex = 0;
    _lastMultiScreenSourceIndexes = [0, 0, 0, 0];
    _darkColorScheme = 'ocean';
    _lightColorScheme = 'sky';
    _fontFamily = 'System';

    await _saveSettings();
    
    // 重置日志级别为关闭（性能优化）
    await ServiceLocator.prefs.setString('log_level', 'off');
    await ServiceLocator.log.setLogLevel(LogLevel.off);
    
    notifyListeners();
  }
}
