# Lotus IPTV

<p align="center">
  <img src="assets/icons/app_icon.png" width="120" alt="Lotus IPTV Logo">
</p>

<p align="center">
  <strong>现代化 IPTV 播放器 - 支持 Windows、Android 和 Android TV</strong>
</p>

<p align="center">
  <a href="https://github.com/shnulaa/FlutterIPTV/releases">
    <img src="https://img.shields.io/github/v/release/shnulaa/FlutterIPTV?include_prereleases" alt="最新版本">
  </a>
  <a href="https://github.com/shnulaa/FlutterIPTV/actions/workflows/build-release.yml">
    <img src="https://github.com/shnulaa/FlutterIPTV/actions/workflows/build-release.yml/badge.svg" alt="构建状态">
  </a>
  <a href="https://github.com/shnulaa/FlutterIPTV/releases">
    <img src="https://img.shields.io/github/downloads/shnulaa/FlutterIPTV/total" alt="下载量">
  </a>
</p>

<p align="center">
  <a href="README_EN.md">English</a> | <strong>中文</strong>
</p>

Lotus IPTV 是一款基于 Flutter 开发的现代化高性能 IPTV 播放器（支持分屏播放）。采用精美的莲花主题 UI，粉紫渐变色调，针对桌面、移动端和电视平台进行了深度优化。

## 📸 软件截图

<table>
  <tr>
    <td align="center"><img src="assets/screenshots/home_screen.jpg" width="100%" alt="主页"><br><sub>🏠 主页(暗黑模式)</sub></td>
    <td align="center"><img src="assets/screenshots/s11.jpg" width="100%" alt="主页明亮模式"><br><sub>🏠 主页(明亮模式)</sub></td>
    <td align="center"><img src="assets/screenshots/channels_screen.jpg" width="100%" alt="频道列表"><br><sub>📡 频道列表</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="assets/screenshots/player_screen.png" width="100%" alt="播放界面"><br><sub>▶️ 播放界面</sub></td>
    <td align="center"><img src="assets/screenshots/fav_screen.jpg" width="100%" alt="收藏夹"><br><sub>❤️ 收藏夹</sub></td>
    <td align="center"><img src="assets/screenshots/setting_screen.jpg" width="100%" alt="设置"><br><sub>⚙️ 设置</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="assets/screenshots/s12.jpg" width="100%" alt="播放列表管理"><br><sub>📂 播放列表管理</sub></td>
    <td align="center"><img src="assets/screenshots/mini.jpg" width="100%" alt="Mini播放页面"><br><sub>📺 Mini播放页面</sub></td>
    <td align="center"><img src="assets/screenshots/s7.jpg" width="100%" alt="分屏播放"><br><sub>📺 分屏播放</sub></td>
  </tr>
  </tr>
</table>

## ✨ 功能特性

### 🎨 多色主题系统
- **12 种预设配色方案**: 深色主题 6 种 + 浅色主题 6 种
- **动态主题切换**: 一键切换整个 UI 配色
- **配色方案**: 莲花粉、海洋蓝、森林绿、日落橙、皇家紫、樱桃红
- 玻璃拟态风格卡片（桌面/移动端）
- TV 端专属优化界面，流畅性能
- 自动折叠侧边栏导航
- 主题色全局应用：选择框、按钮、图标、渐变背景

### 📺 多平台支持
- **Windows**: 桌面优化 UI，支持键盘快捷键和迷你模式
- **Android 手机**: 触摸友好界面，支持手势控制
- **Android TV**: 完整 D-Pad 导航，遥控器全面支持

### ⚡ 高性能播放
- **桌面/移动端**: 基于 `media_kit` 硬件加速
- **Android TV**: 原生 ExoPlayer (Media3) 支持 4K 视频播放
- 实时 FPS 帧率显示（可在设置中配置）
- 视频参数显示（分辨率、编解码器信息）
- 支持 HLS (m3u8)、MP4、MKV、RTMP/RTSP 等多种格式

### 📂 智能播放列表管理
- 支持从本地文件或 URL 导入 M3U/M3U8/TXT 播放列表
- 二维码导入，方便手机到电视的快速传输
- 根据 `group-title` 自动分组
- 保持 M3U 文件原始分类顺序
- 频道可用性检测，支持批量操作

#### 支持的播放列表格式
- **M3U/M3U8**: 标准 IPTV 播放列表格式，支持 EPG 和台标
- **TXT**: 简化的文本格式，使用 `,#genre#` 作为分类标记
  ```
  分类名称,#genre#
  频道名称,频道URL
  频道名称,频道URL
  ```

### ❤️ 用户功能
- 收藏管理，支持长按操作
- 频道搜索（按名称或分组）
- 播放器内分类面板（按左键打开）
- 双击返回键退出播放器（防止误触）
- 观看历史记录
- **频道台标自动匹配**: 预埋 1088+ 条频道台标，智能模糊匹配
  - TXT 格式播放列表自动显示台标（无台标信息）
  - 三级优先级加载：M3U 台标 → 数据库台标 → 默认图片
  - 智能匹配："CCTV1-综合" 匹配 "CCTV1"，"湖南卫视高清" 匹配 "湖南卫视"
  - GitHub 代理加速台标图片加载
- **启动自动播放**: 可选择应用启动后自动继续播放（默认关闭）
- **多源切换**: 同名频道自动合并，左右键切换源
- **分屏模式** (桌面端 & TV端): 2x2 分屏同时观看 4 个频道，独立 EPG 显示，桌面端支持迷你模式

### 📡 EPG 电子节目单
- 支持 XMLTV 格式 EPG 数据
- 自动从 M3U 的 `x-tvg-url` 属性加载 EPG
- 设置中可手动配置 EPG 地址
- 播放器中显示当前和即将播出的节目
- 节目剩余时间提示

### 📺 DLNA 投屏
- 内置 DLNA 渲染器 (DMR) 服务
- 支持从其他设备投屏到 Lotus IPTV
- 支持常见视频格式
- 投屏设备可控制播放（播放/暂停/快进/音量）
- 可设置自动启动 DLNA 服务


## 🚀 下载安装

从 [Releases 页面](https://github.com/shnulaa/FlutterIPTV/releases/latest) 下载最新版本。

### 支持平台
- **Windows**: x64 安装包 (.exe)
- **Android 手机**: APK (arm64-v8a, armeabi-v7a, x86_64)
- **Android TV**: APK (arm64-v8a, armeabi-v7a, x86_64)

## 🎮 操作控制

### 桌面端/移动端

| 动作 | 键盘 | 鼠标/触摸 |
|------|------|-----------|
| 播放/暂停 | 空格/回车 | 点击 |
| 上一频道 | ↑ | 上滑 |
| 下一频道 | ↓ | 下滑 |
| 打开分类面板 | ← | - |
| 切换源 | ←/→ | - |
| 收藏 | F | 长按 |
| 静音 | M | - |
| 退出播放器 | 双击 Esc | - |
| 进入分屏 | - | 点击按钮 |

### Android TV 电视端

| 动作 | 遥控器按键 | 说明 |
|------|-----------|------|
| 播放/暂停 | 确认键（短按） | 切换播放状态 |
| 上/下一频道 | 方向键 上/下 | 切换频道 |
| 打开分类面板 | 方向键 左（长按） | 显示分类列表 |
| 切换源 | 方向键 左/右 | 切换播放源 |
| 收藏 | 确认键（双击） | 添加/取消收藏 |
| 进入分屏 | 确认键（长按） | 进入 2x2 分屏模式 |
| 退出播放器 | 返回键（双击） | 返回频道列表 |

### TV 分屏模式

| 动作 | 遥控器按键 | 说明 |
|------|-----------|------|
| 移动焦点 | 方向键 | 在4个屏幕间移动（同时切换音频） |
| 选择频道 | 确认键（短按） | 打开频道选择器 |
| 清除屏幕 | 确认键（长按） | 清除当前屏幕的频道 |
| 退出分屏 | 返回键 | 返回单屏播放（如有频道）或退出 |

## 🛠️ 开发构建

### 环境要求
- Flutter SDK (>=3.5.0)
- Android Studio（用于 Android/TV 构建）
- Visual Studio（用于 Windows 构建）

### 构建步骤
```bash
git clone https://github.com/shnulaa/FlutterIPTV.git
cd FlutterIPTV
flutter pub get

# 运行
flutter run -d windows
flutter run -d <android_device>

# 构建发布版
flutter build windows
flutter build apk --release
```

## 🤝 参与贡献

欢迎提交 Pull Request！

## ⚠️ 免责声明

本应用程序仅作为播放器，不提供任何内容。用户需自行提供 M3U 播放列表。开发者不对通过本应用播放的内容承担任何责任。

## 📄 许可证

本项目采用 MIT 许可证。
