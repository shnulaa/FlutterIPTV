import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Detects the current platform and provides platform-specific helpers
class PlatformDetector {
  static late PlatformType _currentPlatform;
  static bool _isTV = false;
  static const _channel = MethodChannel('com.flutteriptv/platform');

  static PlatformType get currentPlatform => _currentPlatform;
  static bool get isTV => _isTV;
  static bool get isMobile => _currentPlatform == PlatformType.android && !_isTV;
  static bool get isDesktop => _currentPlatform == PlatformType.windows || _currentPlatform == PlatformType.macos || _currentPlatform == PlatformType.linux;
  static bool get isAndroid => _currentPlatform == PlatformType.android;
  static bool get isWindows => _currentPlatform == PlatformType.windows;

  /// Whether D-Pad navigation should be enabled
  static bool get useDPadNavigation => _isTV || isDesktop;

  /// Whether touch input is the primary input method
  static bool get useTouchInput => isMobile;

  static Future<void> init() async {
    if (kIsWeb) {
      _currentPlatform = PlatformType.web;
    } else if (Platform.isAndroid) {
      _currentPlatform = PlatformType.android;
      await _detectAndroidTV();
    } else if (Platform.isWindows) {
      _currentPlatform = PlatformType.windows;
    } else if (Platform.isIOS) {
      _currentPlatform = PlatformType.ios;
    } else if (Platform.isMacOS) {
      _currentPlatform = PlatformType.macos;
    } else if (Platform.isLinux) {
      _currentPlatform = PlatformType.linux;
    } else {
      _currentPlatform = PlatformType.unknown;
    }
  }

  static Future<void> _detectAndroidTV() async {
    // First check compile-time flag
    const envIsTV = bool.fromEnvironment('IS_TV', defaultValue: false);
    if (envIsTV) {
      _isTV = true;
      debugPrint('PlatformDetector: TV mode enabled via IS_TV flag');
      return;
    }

    // Then try to detect via platform channel
    try {
      final result = await _channel.invokeMethod<bool>('isTV');
      _isTV = result ?? false;
      debugPrint('PlatformDetector: TV detection via channel: $_isTV');
    } catch (e) {
      debugPrint('PlatformDetector: Failed to detect TV via channel: $e');
      _isTV = false;
    }
  }

  /// Force TV mode (useful for testing)
  static void setTVMode(bool isTV) {
    _isTV = isTV;
    debugPrint('PlatformDetector: TV mode manually set to: $isTV');
  }

  /// Get appropriate grid count based on platform
  static int getGridCrossAxisCount(double screenWidth) {
    if (_isTV || isDesktop) {
      if (screenWidth > 1600) return 6;
      if (screenWidth > 1200) return 5;
      if (screenWidth > 900) return 4;
      return 3;
    } else {
      if (screenWidth > 600) return 3;
      return 2;
    }
  }

  /// Get appropriate thumbnail size based on platform
  static double getThumbnailHeight() {
    if (_isTV) return 180;
    if (isDesktop) return 160;
    return 120;
  }

  /// Get focus border width for TV/Desktop
  static double getFocusBorderWidth() {
    if (_isTV) return 4;
    if (isDesktop) return 3;
    return 2;
  }

  /// Set screen keep on (Android only)
  static Future<bool> setKeepScreenOn(bool enable) async {
    if (!isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('setKeepScreenOn', {'enable': enable});
      debugPrint('PlatformDetector: setKeepScreenOn($enable) result: $result');
      return result ?? false;
    } catch (e) {
      debugPrint('PlatformDetector: setKeepScreenOn error: $e');
      return false;
    }
  }
}

enum PlatformType {
  android,
  ios,
  windows,
  macos,
  linux,
  web,
  unknown,
}
