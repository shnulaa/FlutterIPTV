# Changelog

All notable changes to FlutterIPTV will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.8] - 2024-12-14

### Fixed
- Fixed database migration error (`no such column: channel_count`) for existing users
- Updated database schema version to 2

## [1.0.7] - 2024-12-14

### Fixed
- Fixed "Database not initialized" error on Windows by initializing FFI engine early in `main.dart`
- Implemented "From File" playlist import functionality with performance optimization

## [1.0.6] - 2024-12-14

### Fixed
- Upgraded Gradle Wrapper to 8.0 to fix Android build failure

## [1.0.5] - 2024-12-14

### Fixed
- Fixed GitHub Actions ZIP creation failure by adding `-Force` parameter

## [1.0.4] - 2024-12-14

### Fixed
- Fixed GitHub Actions build failure by aligning Flutter version (3.16.9) with local environment
- Resolved `win32` compatibility issues

## [1.0.3] - 2024-12-14

### Fixed
- Fixed critical startup crash (LateInitializationError)
- Fixed "app not responding" during M3U import using batch database insert
- Fixed video playback continuing after exiting player screen (audio playing in background)
- Fixed Windows CI build failure due to package name casing
- Optimized cold start time significantly by moving heavy initialization to Splash Screen
- Switched to Dio for more robust playlist downloading

## [1.0.2] - 2024-12-13

### Fixed
- Fixed Android build configuration (SDK version and Gradle settings)
- Fixed Windows CI build by auto-generating platform files
- Updated compileSdk to 34 to support latest dependencies

## [1.0.1] - 2024-12-13

### Fixed
- Fixed multiple import path errors in providers and screens
- Fixed `TVFocusable` widget const constructor issues
- Removed unused `google_fonts` dependency
- Fixed `shortcuts` map type issue in `main.dart`

## [1.0.0] - 2024-12-13

### Added
- Initial release of FlutterIPTV
- **Multi-Platform Support**
  - Windows (PC) with keyboard/mouse navigation
  - Android Mobile with touch-optimized interface
  - Android TV with full D-Pad/Remote navigation
- **Video Player**
  - High-quality playback using media_kit (libmpv)
  - Support for HLS, DASH, RTMP/RTSP streams
  - Hardware-accelerated decoding
  - Playback speed control (0.5x - 2.0x)
  - Volume control with mute toggle
- **Playlist Management**
  - Import M3U/M3U8 playlists from URL
  - Import local playlist files
  - Automatic playlist refresh
  - Multiple playlist support
- **Channel Features**
  - Automatic grouping by categories
  - Channel search by name or group
  - Favorites with drag-and-drop reordering
  - Watch history tracking
- **Settings**
  - Playback buffer configuration
  - Auto-play preferences
  - Last channel memory
  - Parental control with PIN
- **UI/UX**
  - Beautiful dark theme optimized for TV
  - Smooth animations and transitions
  - Focus-based navigation for TV remotes
  - Responsive design for all screen sizes

### Technical
- Flutter 3.x compatible
- Provider state management
- SQLite local database
- MediaKit video player integration
- Platform channel for Android TV detection

---

## [Unreleased]

### Planned Features
- EPG (Electronic Program Guide) support
- Channel logos caching
- Multiple audio track selection
- Subtitle support
- Picture-in-Picture mode (Android)
- Chromecast support
- Recording functionality
