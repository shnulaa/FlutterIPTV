# Lotus IPTV

<p align="center">
  <img src="assets/icons/app_icon.png" width="120" alt="Lotus IPTV Logo">
</p>

<p align="center">
  <strong>A Modern IPTV Player for Windows, Android, and Android TV</strong>
</p>

<p align="center">
  <a href="https://github.com/shnulaa/FlutterIPTV/releases">
    <img src="https://img.shields.io/github/v/release/shnulaa/FlutterIPTV?include_prereleases" alt="Latest Release">
  </a>
  <a href="https://github.com/shnulaa/FlutterIPTV/actions/workflows/build-release.yml">
    <img src="https://github.com/shnulaa/FlutterIPTV/actions/workflows/build-release.yml/badge.svg" alt="Build Status">
  </a>
  <a href="https://github.com/shnulaa/FlutterIPTV/releases">
    <img src="https://img.shields.io/github/downloads/shnulaa/FlutterIPTV/total" alt="Downloads">
  </a>
</p>

<p align="center">
  <strong>English</strong> | <a href="README_ZH.md">中文</a>
</p>

Lotus IPTV is a modern, high-performance IPTV player built with Flutter. Features a beautiful Lotus-themed UI with pink/purple gradient accents, optimized for seamless viewing across desktop, mobile, and TV platforms.

## ✨ Features

### 🎨 Lotus Theme UI
- Pure black background with lotus pink/purple gradient accents
- Glassmorphism style cards for desktop/mobile
- TV-optimized interface with smooth performance
- Auto-collapsing sidebar navigation

### 📺 Multi-Platform Support
- **Windows**: Desktop-optimized UI with keyboard shortcuts and mini mode
- **Android Mobile**: Touch-friendly interface with gesture controls
- **Android TV**: Full D-Pad navigation with remote control support

### ⚡ High-Performance Playback
- **Desktop/Mobile**: Powered by `media_kit` with hardware acceleration
- **Android TV**: Native ExoPlayer (Media3) for 4K video playback
- Real-time FPS display (configurable in settings)
- Video stats display (resolution, codec info)
- Supports HLS (m3u8), MP4, MKV, RTMP/RTSP and more

### 📂 Smart Playlist Management
- Import M3U/M3U8 playlists from local files or URLs
- QR code import for easy mobile-to-TV transfer
- Auto-grouping by `group-title`
- Preserves original M3U category order
- Channel availability testing with batch operations

### ❤️ User Features
- Favorites management with long-press support
- Channel search by name or group
- In-player category panel (press LEFT key)
- Double-press BACK to exit player (prevents accidental exit)
- Watch history tracking
- Default channel logo for missing thumbnails
- **Multi-source support**: Auto-merge channels with same name, switch sources with LEFT/RIGHT keys

### 📡 EPG (Electronic Program Guide)
- Support for XMLTV format EPG data
- Auto-load EPG from M3U `x-tvg-url` attribute
- Manual EPG URL configuration in settings
- Display current and upcoming programs in player
- Program remaining time indicator

### 📺 DLNA Screen Casting
- Built-in DLNA renderer (DMR) service
- Cast videos from other devices to Lotus IPTV
- Support for common video formats
- Playback control from casting device (play/pause/seek/volume)
- Auto-start DLNA service option

## 📸 Screenshots

<p align="center">
  <img src="assets/screenshots/home_screen.png" width="30%" alt="Home Screen">
  <img src="assets/screenshots/channels_screen.png" width="30%" alt="Channels Screen">
  <img src="assets/screenshots/player_screen.png" width="30%" alt="Player Screen">
  <img src="assets/screenshots/fav_screen.png" width="30%" alt="Favorites Screen">
  <img src="assets/screenshots/setting_screen.png" width="30%" alt="Setting Screen">
  
</p>

## 🚀 Download

Download the latest version from [Releases Page](https://github.com/shnulaa/FlutterIPTV/releases/latest).

### Available Platforms
- **Windows**: x64 Installer (.exe)
- **Android Mobile**: APK for arm64-v8a, armeabi-v7a, x86_64
- **Android TV**: APK for arm64-v8a, armeabi-v7a, x86_64

## 🎮 Controls

| Action | Keyboard | TV Remote |
|--------|----------|-----------|
| Play/Pause | Space/Enter | OK |
| Channel Up | ↑ | D-Pad Up |
| Channel Down | ↓ | D-Pad Down |
| Open Category Panel | ← | D-Pad Left |
| Favorite | F | Long Press OK |
| Mute | M | - |
| Exit Player | Double Esc | Double Back |

## 🛠️ Development

### Prerequisites
- Flutter SDK (>=3.5.0)
- Android Studio (for Android/TV builds)
- Visual Studio (for Windows builds)

### Build
```bash
git clone https://github.com/shnulaa/FlutterIPTV.git
cd FlutterIPTV
flutter pub get

# Run
flutter run -d windows
flutter run -d <android_device>

# Build Release
flutter build windows
flutter build apk --release
```

## 🤝 Contributing

Pull requests are welcome!

## ⚠️ Disclaimer

This application is a player only and does not provide any content. Users must provide their own M3U playlists. Developers are not responsible for the content played through this application.

## 📄 License

This project is licensed under the MIT License.
