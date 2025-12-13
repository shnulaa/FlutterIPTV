import 'package:flutter/foundation.dart';
import '../../../core/services/service_locator.dart';

class SettingsProvider extends ChangeNotifier {
  // Keys for SharedPreferences
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyAutoRefresh = 'auto_refresh';
  static const String _keyRefreshInterval = 'refresh_interval';
  static const String _keyDefaultQuality = 'default_quality';
  static const String _keyHardwareDecoding = 'hardware_decoding';
  static const String _keyBufferSize = 'buffer_size';
  static const String _keyLastPlaylistId = 'last_playlist_id';
  static const String _keyEnableEpg = 'enable_epg';
  static const String _keyEpgUrl = 'epg_url';
  static const String _keyParentalControl = 'parental_control';
  static const String _keyParentalPin = 'parental_pin';
  static const String _keyAutoPlay = 'auto_play';
  static const String _keyRememberLastChannel = 'remember_last_channel';
  static const String _keyLastChannelId = 'last_channel_id';
  
  // Settings values
  String _themeMode = 'dark';
  bool _autoRefresh = true;
  int _refreshInterval = 24; // hours
  String _defaultQuality = 'auto';
  bool _hardwareDecoding = true;
  int _bufferSize = 30; // seconds
  int? _lastPlaylistId;
  bool _enableEpg = true;
  String? _epgUrl;
  bool _parentalControl = false;
  String? _parentalPin;
  bool _autoPlay = true;
  bool _rememberLastChannel = true;
  int? _lastChannelId;
  
  // Getters
  String get themeMode => _themeMode;
  bool get autoRefresh => _autoRefresh;
  int get refreshInterval => _refreshInterval;
  String get defaultQuality => _defaultQuality;
  bool get hardwareDecoding => _hardwareDecoding;
  int get bufferSize => _bufferSize;
  int? get lastPlaylistId => _lastPlaylistId;
  bool get enableEpg => _enableEpg;
  String? get epgUrl => _epgUrl;
  bool get parentalControl => _parentalControl;
  bool get autoPlay => _autoPlay;
  bool get rememberLastChannel => _rememberLastChannel;
  int? get lastChannelId => _lastChannelId;
  
  SettingsProvider() {
    _loadSettings();
  }
  
  void _loadSettings() {
    final prefs = ServiceLocator.prefs;
    
    _themeMode = prefs.getString(_keyThemeMode) ?? 'dark';
    _autoRefresh = prefs.getBool(_keyAutoRefresh) ?? true;
    _refreshInterval = prefs.getInt(_keyRefreshInterval) ?? 24;
    _defaultQuality = prefs.getString(_keyDefaultQuality) ?? 'auto';
    _hardwareDecoding = prefs.getBool(_keyHardwareDecoding) ?? true;
    _bufferSize = prefs.getInt(_keyBufferSize) ?? 30;
    _lastPlaylistId = prefs.getInt(_keyLastPlaylistId);
    _enableEpg = prefs.getBool(_keyEnableEpg) ?? true;
    _epgUrl = prefs.getString(_keyEpgUrl);
    _parentalControl = prefs.getBool(_keyParentalControl) ?? false;
    _parentalPin = prefs.getString(_keyParentalPin);
    _autoPlay = prefs.getBool(_keyAutoPlay) ?? true;
    _rememberLastChannel = prefs.getBool(_keyRememberLastChannel) ?? true;
    _lastChannelId = prefs.getInt(_keyLastChannelId);
    
    notifyListeners();
  }
  
  Future<void> _saveSettings() async {
    final prefs = ServiceLocator.prefs;
    
    await prefs.setString(_keyThemeMode, _themeMode);
    await prefs.setBool(_keyAutoRefresh, _autoRefresh);
    await prefs.setInt(_keyRefreshInterval, _refreshInterval);
    await prefs.setString(_keyDefaultQuality, _defaultQuality);
    await prefs.setBool(_keyHardwareDecoding, _hardwareDecoding);
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
  
  // Reset all settings to defaults
  Future<void> resetSettings() async {
    _themeMode = 'dark';
    _autoRefresh = true;
    _refreshInterval = 24;
    _defaultQuality = 'auto';
    _hardwareDecoding = true;
    _bufferSize = 30;
    _enableEpg = true;
    _epgUrl = null;
    _parentalControl = false;
    _parentalPin = null;
    _autoPlay = true;
    _rememberLastChannel = true;
    
    await _saveSettings();
    notifyListeners();
  }
}
