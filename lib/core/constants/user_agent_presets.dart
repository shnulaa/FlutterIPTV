/// User-Agent presets for different browsers and media players
class UserAgentPresets {
  static const String wget = 'Wget/1.21.3';
  static const String chromeWindows = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
  static const String chromeMac = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
  static const String firefox = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0';
  static const String safari = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15';
  static const String edge = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0';
  static const String vlc = 'VLC/3.0.20 LibVLC/3.0.20';
  static const String ffmpeg = 'Lavf/60.3.100';
  static const String androidChrome = 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';
  static const String iosSafari = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';

  /// Get all presets as a map
  static Map<String, String> get all => {
        'wget': wget,
        'chrome_windows': chromeWindows,
        'chrome_mac': chromeMac,
        'firefox': firefox,
        'safari': safari,
        'edge': edge,
        'vlc': vlc,
        'ffmpeg': ffmpeg,
        'android_chrome': androidChrome,
        'ios_safari': iosSafari,
      };

  /// Get preset by key
  static String? getPreset(String key) {
    return all[key];
  }

  /// Get key by value
  static String? getKeyByValue(String value) {
    for (final entry in all.entries) {
      if (entry.value == value) {
        return entry.key;
      }
    }
    return null;
  }
}
