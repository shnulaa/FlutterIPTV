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
    <img src="https://github.com/shnulaa/FlutterIPTV/actions/workflows/build-release.yml/badge.svg?branch=main" alt="Build Status">
  </a>
  <a href="https://github.com/shnulaa/FlutterIPTV/releases">
    <img src="https://img.shields.io/github/downloads/shnulaa/FlutterIPTV/total" alt="Downloads">
  </a>
</p>

<p align="center">
  <strong>中文</strong> | <a href="README_ZH.md">中文</a>
</p>

Lotus IPTV is a modern, high-performance IPTV player built with Flutter. Features a beautiful Lotus-themed UI with pink/purple gradient accents(Split-screen support), optimized for seamless viewing across desktop, mobile, and TV platforms.

> **💡 Feedback Welcome**  
> We welcome everyone to submit [Issues](https://github.com/shnulaa/FlutterIPTV/issues)! Without your bug reports and improvement suggestions, the software has no hope of progress! Every piece of feedback you provide is the driving force behind the project's advancement.

## 📸 Screenshots

<table>
  <tr>
    <td align="center"><img src="assets/screenshots/s1.jpg" width="100%" alt="Home Screen"><br><sub>🏠 Home Dark Theme</sub></td>
    <td align="center"><img src="assets/screenshots/s10.jpg" width="100%" alt="Home Screen2"><br><sub>🏠 Home Light Theme</sub></td>
    <td align="center"><img src="assets/screenshots/s2.jpg" width="100%" alt="Channels"><br><sub>📡 Channels</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="assets/screenshots/s5.jpg" width="100%" alt="Player"><br><sub>▶️ Player</sub></td>
    <td align="center"><img src="assets/screenshots/s3.jpg" width="100%" alt="Favorites"><br><sub>❤️ Favorites</sub></td>
    <td align="center"><img src="assets/screenshots/s4.jpg" width="100%" alt="Settings"><br><sub>⚙️ Settings</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="assets/screenshots/s6.jpg" width="100%" alt="Playlist Manager"><br><sub>📂 Playlist Manager</sub></td>
    <td align="center"><img src="assets/screenshots/mini.jpg" width="100%" alt="Split Mini Screen"><br><sub>📺 Split Mini Screen</sub></td>
    <td align="center"><img src="assets/screenshots/s8.jpg" width="100%" alt="Multi-Screen"><br><sub>📺 Split Screen</sub></td>    
  </tr>
</table>
## ⚠️ Disclaimer

1. This application is provided solely as a general-purpose media player and does not provide, host, store, or distribute any audio or video content.
2. This application does not include any built-in M3U / M3U8 playlists or media sources. All media content and playlists are added by users themselves.
3. Users are solely responsible for ensuring that the media content and playlists they use are obtained from legal and authorized sources.
4. The developer does not assume any responsibility for the legality, copyright, or licensing of any content played through this application.

## 🚀 Getting Started

### 📋 Adding IPTV Playlists

To start watching channels, you need to add M3U/M3U8/TXT playlist sources:

**How to add:**
1. Open Lotus IPTV
2. Click "Add Playlist" or "+" button
3. Select "From URL"
4. Paste the URL
5. Click "Add" and wait for channels to load

#### 📁 Other Playlist Sources
- **Local Files**: Import `.m3u` or `.m3u8` files from your device
- **Custom URLs**: Add your own IPTV service URLs
- **QR Code**: Scan QR codes containing playlist URLs

> **Note**: The public playlist above contains channels from various countries and may have varying availability. For the best experience, use playlists from your IPTV service provider.

## 🚀 Download

Download the latest version from [Releases Page](https://github.com/shnulaa/FlutterIPTV/releases/latest).

### Available Platforms
- **Windows**: x64 Installer (.exe)
- **Android Mobile**: APK for arm64-v8a, armeabi-v7a, x86_64
- **Android TV**: APK for arm64-v8a, armeabi-v7a, x86_64

## 🎮 Controls

### Desktop/Mobile

| Action | Keyboard | Mouse/Touch |
|--------|----------|-------------|
| Play/Pause | Space/Enter | Click |
| Channel Up | ↑ | Swipe Up |
| Channel Down | ↓ | Swipe Down |
| Open Category Panel | ← | - |
| Switch Source | ←/→ | - |
| Favorite | F | Long Press |
| Mute | M | - |
| Exit Player | Double Esc | - |
| Enter Multi-Screen | - | Click Button |

### Android TV

| Action | Remote Button | Description |
|--------|---------------|-------------|
| Play/Pause | OK (short press) | Toggle playback |
| Channel Up/Down | Channel Up/Down (short press) | Switch channels |
| Switch Source | Channel Up/Down (long press) | Switch between sources |
| Seek Backward | D-Pad Left (short press) | Seek backward (5/10/30/60/120s configurable) |
| Seek Forward | D-Pad Right (short press) | Seek forward (5/10/30/60/120s configurable) |
| Continuous Rewind | D-Pad Left (long press) | Continuous rewind (speed multiplier increases) |
| Continuous Fast Forward | D-Pad Right (long press) | Continuous fast forward (speed multiplier increases) |
| Open Category Panel | D-Pad Left (double click) | Show category list |
| Favorite | OK (double click) | Add/remove favorite |
| Enter Multi-Screen | OK (long press) | Enter 2x2 split screen mode |
| Exit Player | Back (double press) | Return to channel list |

### TV Multi-Screen Mode

| Action | Remote Button | Description |
|--------|---------------|-------------|
| Move Focus | D-Pad | Move between 4 screens (also switches audio) |
| Select Channel | OK (short press) | Open channel selector for focused screen |
| Clear Screen | OK (long press) | Clear channel from focused screen |
| Exit Multi-Screen | Back | Return to single player (if channel playing) or exit |


## ✨ Features

### 🎨 Multi-Color Theme System
- **12 Preset Color Schemes**: 6 dark themes + 6 light themes
- **Dynamic Theme Switching**: Change colors across entire UI instantly
- **Color Schemes**: Lotus Pink, Ocean Blue, Forest Green, Sunset Orange, Royal Purple, Cherry Red
- Glassmorphism style cards for desktop/mobile
- TV-optimized interface with smooth performance
- Auto-collapsing sidebar navigation
- Theme colors applied globally: selection boxes, buttons, icons, gradients

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
- Import M3U/M3U8/TXT playlists from local files or URLs
- QR code import for easy mobile-to-TV transfer
- Auto-grouping by `group-title`
- Preserves original M3U category order
- Channel availability testing with batch operations

#### Supported Playlist Formats
- **M3U/M3U8**: Standard IPTV playlist format with EPG and logo support
- **TXT**: Simplified text format using `,#genre#` as category marker
  ```
  Category Name,#genre#
  Channel Name,Channel URL
  Channel Name,Channel URL
  ```

### ❤️ User Features
- Favorites management with long-press support
- Channel search by name or group
- In-player category panel (press LEFT key)
- Double-press BACK to exit player (prevents accidental exit)
- Watch history tracking
- **Auto Channel Logo Matching**: 1088+ pre-embedded channel logos with smart fuzzy matching
  - Automatic logo display for TXT playlists (no logo info)
  - Three-level priority: M3U logo → Database logo → Default image
- **Auto-play on Startup**: Optional continue playback after app launch (disabled by default)
- **Multi-source support**: Auto-merge channels with same name, switch sources with LEFT/RIGHT keys
- **Multi-screen mode** (Desktop & TV): 2x2 split screen for simultaneous viewing of 4 channels, with independent EPG display and mini mode support (Desktop)

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



## 📄 License

This project is licensed under the MIT License.
