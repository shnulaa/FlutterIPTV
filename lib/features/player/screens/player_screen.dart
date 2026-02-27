import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:async';

import '../../../core/i18n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../../core/platform/platform_detector.dart';
import '../../../core/platform/native_player_channel.dart';
import '../../../core/platform/windows_pip_channel.dart';
import '../../../core/platform/windows_fullscreen_native.dart';
import '../../../core/models/channel.dart';
import '../providers/player_provider.dart';
import '../../favorites/providers/favorites_provider.dart';
import '../../channels/providers/channel_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../settings/providers/dlna_provider.dart';
import '../../epg/providers/epg_provider.dart';
import '../../multi_screen/providers/multi_screen_provider.dart';
import '../../multi_screen/widgets/multi_screen_player.dart';
import '../../../core/services/service_locator.dart';

class PlayerScreen extends StatefulWidget {
  final String channelUrl;
  final String channelName;
  final String? channelLogo;
  final bool isMultiScreen; // 是否强制进入分屏模式

  const PlayerScreen({
    super.key,
    required this.channelUrl,
    required this.channelName,
    this.channelLogo,
    this.isMultiScreen = false,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with WidgetsBindingObserver {
  Timer? _hideControlsTimer;
  Timer? _dlnaSyncTimer; // DLNA 状态同步定时器（Android TV 原生播放器用）
  Timer? _wakelockTimer; // 定时刷新wakelock（手机端用）
  bool _showControls = true;
  final FocusNode _playerFocusNode = FocusNode();
  bool _usingNativePlayer = false;
  bool _showCategoryPanel = false;
  String? _selectedCategory;
  final ScrollController _categoryScrollController = ScrollController();
  final ScrollController _channelScrollController = ScrollController();

  // 保存 provider 引用，用于 dispose 时释放资源
  PlayerProvider? _playerProvider;
  MultiScreenProvider? _multiScreenProvider;
  SettingsProvider? _settingsProvider;

  // 本地分屏模式状态（不影响设置）
  bool _localMultiScreenMode = false;

  // 保存分屏模式状态，用于 dispose 时判断
  bool _wasMultiScreenMode = false;

  // 标记是否已经保存了分屏状态（避免重复保存）
  bool _multiScreenStateSaved = false;

  // 手势控制相关变量
  double _gestureStartY = 0;
  double _initialVolume = 0;
  double _initialBrightness = 0;
  bool _showGestureIndicator = false;
  double _gestureValue = 0;

  // 本地 loading 状态，用于强制刷新
  bool _isLoading = true;

  // 错误已显示标记，防止重复显示
  bool _errorShown = false;
  Timer? _errorHideTimer; // 错误提示自动隐藏定时器

  // Windows 全屏状态
  bool _isFullScreen = false;
  DateTime? _lastFullScreenToggle; // 记录上次切换时间
  bool _mouseOver = false;

  // 检查是否处于分屏模式（使用本地状态）
  bool _isMultiScreenMode() {
    return _localMultiScreenMode && PlatformDetector.isDesktop;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 保持屏幕常亮
    _enableWakelock();
    // 延迟到 didChangeDependencies 之后再检查播放器
    // 因为需要先初始化 _localMultiScreenMode
  }

  Future<void> _enableWakelock() async {
    // 手机端使用原生方法确保屏幕常亮
    if (PlatformDetector.isMobile) {
      try {
        await PlatformDetector.setKeepScreenOn(true);
      } catch (e) {
        ServiceLocator.log.d('PlayerScreen: Failed to set keep screen on: $e');
      }
    } else {
      // 其他平台使用wakelock_plus
      try {
      // 添加短暂的延迟，确保 Flutter 引擎完全初始化
        await Future.delayed(const Duration(milliseconds: 100));
        await WakelockPlus.enable();
        final enabled = await WakelockPlus.enabled;
        ServiceLocator.log.d('PlayerScreen: WakelockPlus enabled: $enabled');
      } catch (e) {
        ServiceLocator.log.d('PlayerScreen: Failed to enable wakelock: $e');
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 保存 provider 引用并添加监听
    if (_playerProvider == null) {
      _playerProvider = context.read<PlayerProvider>();
      _playerProvider!.addListener(_onProviderUpdate);
      _isLoading = _playerProvider!.isLoading;

      // 保存 settings 和 multi-screen provider 引用（用于 dispose 时保存状态）
      _settingsProvider = context.read<SettingsProvider>();
      _multiScreenProvider = context.read<MultiScreenProvider>();

      // 检查是否是 DLNA 投屏模式
      bool isDlnaMode = false;
      try {
        final dlnaProvider = context.read<DlnaProvider>();
        isDlnaMode = dlnaProvider.isActiveSession;
      } catch (_) {}

      // 初始化本地分屏模式状态（根据设置或传入参数）
      // 如果传入的 isMultiScreen=true，强制进入分屏模式
      // DLNA 投屏模式下不进入分屏
      _localMultiScreenMode = !isDlnaMode &&
          (widget.isMultiScreen || _settingsProvider!.enableMultiScreen) &&
          PlatformDetector.isDesktop;

      // 如果是分屏模式且分屏没有正在播放的频道，设置音量增强到分屏provider
      // 如果分屏已经有频道在播放（从主页继续播放进入），不要覆盖音量设置
      if (_localMultiScreenMode && !_multiScreenProvider!.hasAnyChannel) {
        _multiScreenProvider!.setVolumeSettings(
            _playerProvider!.volume, _settingsProvider!.volumeBoost);
      }

      // 现在可以安全地检查和启动播放器了
      _checkAndLaunchPlayer();
    }
    // 保存分屏模式状态
    _wasMultiScreenMode = _isMultiScreenMode();
  }

  void _onProviderUpdate() {
    if (!mounted) return;
    final provider = _playerProvider;
    if (provider == null) return;

    final newLoading = provider.isLoading;
    if (_isLoading != newLoading) {
      setState(() {
        _isLoading = newLoading;
      });
    }

    // 检查错误状态
    if (provider.hasError && !_errorShown) {
      _checkAndShowError();
    }

    // 只有 DLNA 投屏会话时才同步播放状态
    try {
      final dlnaProvider = context.read<DlnaProvider>();
      if (dlnaProvider.isActiveSession) {
        dlnaProvider.syncPlayerState(
          isPlaying: provider.isPlaying,
          isPaused: provider.state == PlayerState.paused,
          position: provider.position,
          duration: provider.duration,
        );
      }
    } catch (e) {
      // DLNA provider 可能不可用，忽略错误
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    ServiceLocator.log.d('PlayerScreen: AppLifecycleState changed to $state');
  }

  Future<void> _checkAndLaunchPlayer() async {
    // 分屏模式下不启动PlayerProvider播放，由MultiScreenProvider处理
    if (_isMultiScreenMode()) {
      // 分屏模式：隐藏系统UI，但不启动PlayerProvider
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      return;
    }

    // Check if we should use native player on Android TV
    if (PlatformDetector.isTV && PlatformDetector.isAndroid) {
      final nativeAvailable = await NativePlayerChannel.isAvailable();
      ServiceLocator.log
          .d('PlayerScreen: Native player available: $nativeAvailable');
      if (nativeAvailable && mounted) {
        _usingNativePlayer = true;

        // 检查是否是 DLNA 投屏模式
        bool isDlnaMode = false;
        try {
          final dlnaProvider = context.read<DlnaProvider>();
          isDlnaMode = dlnaProvider.isActiveSession;
          ServiceLocator.log
              .d('PlayerScreen: DLNA isActiveSession=$isDlnaMode');
        } catch (e) {
          ServiceLocator.log.d('PlayerScreen: Failed to get DlnaProvider: $e');
        }

        // 获取频道列表
        final channelProvider = context.read<ChannelProvider>();
        // 使用全部频道而不是分页显示的频道
        final channels = channelProvider.allChannels;

        // 设置 providers 用于收藏功能和状态保存
        final favoritesProvider = context.read<FavoritesProvider>();
        final settingsProvider = context.read<SettingsProvider>();
        NativePlayerChannel.setProviders(
            favoritesProvider, channelProvider, settingsProvider);

        // DLNA 模式下不使用频道列表，直接播放传入的 URL
        List<String> urls;
        List<String> names;
        List<String> groups;
        List<List<String>> sources;
        List<String> logos;
        List<String> epgIds;
        List<bool> isSeekableList;
        int currentIndex = 0;

        if (isDlnaMode) {
          // DLNA 模式：只播放传入的URL，不提供频道切换功能
          urls = [widget.channelUrl];
          names = [widget.channelName];
          groups = ['DLNA'];
          sources = [
            [widget.channelUrl]
          ];
          logos = [''];
          epgIds = [''];
          isSeekableList = [true]; // DLNA 投屏默认可拖动
          currentIndex = 0;
        } else {
          // 正常模式：使用频道列表
          // Find current channel index
          for (int i = 0; i < channels.length; i++) {
            if (channels[i].url == widget.channelUrl) {
              currentIndex = i;
              break;
            }
          }
          urls = channels.map((c) => c.url).toList();
          names = channels.map((c) => c.name).toList();
          groups = channels.map((c) => c.groupName ?? '').toList();
          sources = channels.map((c) => c.sources).toList();
          logos = channels.map((c) => c.logoUrl ?? '').toList();
          epgIds = channels.map((c) => c.epgId ?? '').toList();
          isSeekableList = channels.map((c) => c.isSeekable).toList();
        }

        ServiceLocator.log.d(
            'PlayerScreen: Launching native player for ${widget.channelName} (isDlna=$isDlnaMode, index $currentIndex of ${urls.length})');

        // TV端原生播放器也需要记录频道遍历
        if (!isDlnaMode && currentIndex >= 0 && currentIndex < channels.length) {
          final channel = channels[currentIndex];
          if (channel.id != null && channel.playlistId != null) {
            await ServiceLocator.watchHistory.addWatchHistory(channel.id!, channel.playlistId!);
            ServiceLocator.log.d('PlayerScreen: Recorded watch history for channel ${channel.name}');
          }
        }

        // 获取缓冲强度设置和显示设置
        final bufferStrength = settingsProvider.bufferStrength;
        final showFps = settingsProvider.showFps;
        final showClock = settingsProvider.showClock;
        final showNetworkSpeed = settingsProvider.showNetworkSpeed;
        final showVideoInfo = settingsProvider.showVideoInfo;

        // Launch native player with channel list and callback for when it closes
        final launched = await NativePlayerChannel.launchPlayer(
          url: widget.channelUrl,
          name: widget.channelName,
          index: currentIndex,
          urls: urls,
          names: names,
          groups: groups,
          sources: sources,
          logos: logos,
          epgIds: epgIds,
          isSeekable: isSeekableList,
          isDlnaMode: isDlnaMode,
          bufferStrength: bufferStrength,
          showFps: showFps,
          showClock: showClock,
          showNetworkSpeed: showNetworkSpeed,
          showVideoInfo: showVideoInfo,
          progressBarMode: settingsProvider.progressBarMode, // 传递进度条显示模式
          seekStepSeconds: settingsProvider.seekStepSeconds, // 传递快进/快退跨度
          showChannelName:
              settingsProvider.showMultiScreenChannelName, // 传递多屏频道名称显示设置
          onClosed: () {
            ServiceLocator.log.d('PlayerScreen: Native player closed callback');
            // 停止 DLNA 同步定时器
            _dlnaSyncTimer?.cancel();
            _dlnaSyncTimer = null;

            // 通知 DLNA 播放已经停止（如果是 DLNA 投屏的话）
            try {
              final dlnaProvider = context.read<DlnaProvider>();
              if (dlnaProvider.isActiveSession) {
                dlnaProvider.notifyPlaybackStopped();
              }
            } catch (e) {
              // 忽略错误
            }

            if (mounted) {
              // 杩斿洖棣栭〉
              Navigator.of(context).maybePop();
            }
          },
        );

        if (launched && mounted) {
          // Don't pop - wait for native player to close via callback
          // The native player is now a Fragment overlay, not a separate Activity

          // 如果是 DLNA 投屏，启动状态同步定时器
          _startDlnaSyncForNativePlayer();
          return;
        } else if (!launched && mounted) {
          // Native player failed to launch, fall back to Flutter player
          _usingNativePlayer = false;
          _initFlutterPlayer();
        }
        return;
      }
    }

    // Fallback to Flutter player
    if (mounted) {
      _usingNativePlayer = false;
      _initFlutterPlayer();
    }
  }

  void _initFlutterPlayer() {
    _startPlayback();
    _startHideControlsTimer();

    // Hide system UI for immersive experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // 手机端定期刷新 wakelock，防止某些设备上 wakelock 失效
    if (PlatformDetector.isMobile) {
      _wakelockTimer?.cancel();
      _wakelockTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
        if (mounted) {
          await _enableWakelock();
        }
      });
    }

    // 不再使用持续监听，改为一次错误检查
  }

  /// 为 Android TV 原生播放器启用 DLNA 状态同步
  void _startDlnaSyncForNativePlayer() {
    try {
      final dlnaProvider = context.read<DlnaProvider>();
      // 注意：不检查 isActiveSession，因为在 TV 端接收 DLNA 投屏时，
      // 这个方法可能在 isActiveSession 设置之前就被调用了
      // 只要 DLNA 服务在运行，就启动同步定时器
      if (!dlnaProvider.isRunning) {
        ServiceLocator.log
            .d('PlayerScreen: DLNA service not running, skip sync timer');
        return;
      }

      ServiceLocator.log
          .d('PlayerScreen: Starting DLNA sync timer for native player');

      // 每秒同步一次播放状态
      _dlnaSyncTimer?.cancel();
      _dlnaSyncTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
        if (!mounted) {
          _dlnaSyncTimer?.cancel();
          return;
        }

        try {
          final state = await NativePlayerChannel.getPlaybackState();
          ServiceLocator.log.d('PlayerScreen: DLNA sync - state=$state');
          if (state != null) {
            final isPlaying = state['isPlaying'] as bool? ?? false;
            final position =
                Duration(milliseconds: (state['position'] as int?) ?? 0);
            final duration =
                Duration(milliseconds: (state['duration'] as int?) ?? 0);
            final stateStr = state['state'] as String? ?? 'unknown';

            dlnaProvider.syncPlayerState(
              isPlaying: isPlaying,
              isPaused: stateStr == 'paused',
              position: position,
              duration: duration,
            );
          }
        } catch (e) {
          ServiceLocator.log.d('PlayerScreen: DLNA sync error - $e');
        }
      });
    } catch (e) {
      ServiceLocator.log.d('PlayerScreen: Failed to start DLNA sync - $e');
    }
  }

  void _checkAndShowError() {
    if (!mounted || _errorShown) return;

    final provider = context.read<PlayerProvider>();
    if (provider.hasError && provider.error != null) {
      final errorMessage = provider.error!;
      _errorShown = true;
      provider.clearError();

      // 先取消之前的定时器
      _errorHideTimer?.cancel();

      // 清除之前的 SnackBar
      try {
        ScaffoldMessenger.of(context).clearSnackBars();
      } catch (e) {
        ServiceLocator.log.d('PlayerScreen: Error clearing SnackBars: $e');
        return;
      }

      final scaffoldMessenger = ScaffoldMessenger.of(context);

      final snackBar = SnackBar(
        content: Text(
            '${AppStrings.of(context)?.playbackError ?? "Error"}: $errorMessage'),
        backgroundColor: AppTheme.errorColor,
        duration: const Duration(days: 365), // 设置很长的时间，手动控制易隐藏
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: AppStrings.of(context)?.retry ?? 'Retry',
          textColor: Colors.white,
          onPressed: () {
            _errorHideTimer?.cancel();
            _errorShown = false;
            scaffoldMessenger.hideCurrentSnackBar();
            _startPlayback();
          },
        ),
      );

      scaffoldMessenger.showSnackBar(snackBar);

      // 3绉掑后手前姩闅愯棌
      _errorHideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          try {
            scaffoldMessenger.hideCurrentSnackBar();
          } catch (e) {
            ServiceLocator.log.d('PlayerScreen: Error hiding SnackBar: $e');
          }
          _errorShown = false;
        }
      });
    }
  }

  void _startPlayback() {
    _errorShown = false; // 重置错误显示标记
    _errorHideTimer?.cancel(); // 取消错误提示隐藏定时器
    // 隐藏错误提示
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }

    final playerProvider = context.read<PlayerProvider>();
    final channelProvider = context.read<ChannelProvider>();
    final settingsProvider = context.read<SettingsProvider>();

    try {
      // ✅ 使用全部频道列表而不是分页显示的频道，确保能找到当前频道
      final channel = channelProvider.allChannels.firstWhere(
        (c) => c.url == widget.channelUrl,
      );

      // 保存上次播放的频道 ID
      if (settingsProvider.rememberLastChannel && channel.id != null) {
        settingsProvider.setLastChannelId(channel.id);
      }

      playerProvider.playChannel(channel);
    } catch (_) {
      // Fallback if channel object not found
      playerProvider.playUrl(widget.channelUrl, name: widget.channelName);
    }
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _showControls = false);
      }
    });
  }

  void _showControlsTemporarily() {
    setState(() => _showControls = true);
    _startHideControlsTimer();
  }

  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond >= 1024 * 1024) {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    } else if (bytesPerSecond >= 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(0)} KB/s';
    } else {
      return '${bytesPerSecond.toStringAsFixed(0)} B/s';
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    ServiceLocator.log.d(
        'PlayerScreen: dispose() called, _usingNativePlayer=$_usingNativePlayer, _wasMultiScreenMode=$_wasMultiScreenMode');

    // 首先移除 provider 监听器，防止后续更新触发错误显示
    if (_playerProvider != null) {
      _playerProvider!.removeListener(_onProviderUpdate);
    }

    // 然后清除所有错误提示和定时器
    _errorHideTimer?.cancel();
    _errorShown = false;

    // 立即清除所有 SnackBar（包括错误提示）
    try {
      ScaffoldMessenger.of(context).clearSnackBars();
    } catch (e) {
      ServiceLocator.log
          .d('PlayerScreen: Error clearing SnackBars in dispose: $e');
    }

    WidgetsBinding.instance.removeObserver(this);
    _hideControlsTimer?.cancel();
    _dlnaSyncTimer?.cancel();
    _wakelockTimer?.cancel();
    _longPressTimer?.cancel();
    _playerFocusNode.dispose();
    _categoryScrollController.dispose();
    _channelScrollController.dispose();

    // 如果是 Windows mini 模式，退出 mini 模式
    if (WindowsPipChannel.isInPipMode) {
      WindowsPipChannel.exitPipMode();
    }

    // 如果是全屏模式，退出全屏 - 使用原生 API
    if (_isFullScreen && PlatformDetector.isWindows) {
      final success = WindowsFullscreenNative.exitFullScreen();
      if (!success) {
        ServiceLocator.log
            .d('Native exitFullScreen failed in dispose, using window_manager');
        unawaited(windowManager.setFullScreen(false));
      }
    }

    // 保存分屏状态（Windows 平台）
    if (_wasMultiScreenMode && PlatformDetector.isDesktop) {
      _saveMultiScreenState();
    }

    // 离开播放页面时，单屏和多屏都必须停止并释放资源
    if (!_usingNativePlayer && _playerProvider != null) {
      ServiceLocator.log
          .d('PlayerScreen: calling _playerProvider.stop() in silent mode');
      unawaited(_playerProvider!.stop(silent: true));
    }
    if (PlatformDetector.isDesktop && _multiScreenProvider != null) {
      ServiceLocator.log
          .d('PlayerScreen: calling _multiScreenProvider.clearAllScreens() in dispose');
      unawaited(_multiScreenProvider!.clearAllScreens());
    }

    // 重置亮度到系统默认
    try {
      ScreenBrightness.instance.resetApplicationScreenBrightness();
    } catch (_) {}

    // 全抽棴屏箷甯镐寒
    if (PlatformDetector.isMobile) {
      PlatformDetector.setKeepScreenOn(false);
    } else {
      try {
        WakelockPlus.disable();
      } catch (e) {
        ServiceLocator.log.d('PlayerScreen: Failed to disable wakelock: $e');
      }
    }

    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    super.dispose();
  }

  /// 保存分屏状态（Windows 平台）
  void _saveMultiScreenState() {
    // 避免重复保存
    if (_multiScreenStateSaved) {
      ServiceLocator.log
          .d('PlayerScreen: Multi-screen state already saved, skipping');
      return;
    }

    try {
      if (_multiScreenProvider == null || _settingsProvider == null) {
        ServiceLocator.log.d(
            'PlayerScreen: Cannot save multi-screen state - providers not available');
        return;
      }

      // 获取每个屏幕的频道ID
      final List<int?> channelIds = [];
      final List<int> sourceIndexes = [];
      for (int i = 0; i < 4; i++) {
        final screen = _multiScreenProvider!.getScreen(i);
        channelIds.add(screen.channel?.id);
        sourceIndexes.add(screen.channel?.currentSourceIndex ?? 0);
      }

      final activeIndex = _multiScreenProvider!.activeScreenIndex;

      ServiceLocator.log.d(
          'PlayerScreen: Saving multi-screen state - channelIds: $channelIds, sourceIndexes: $sourceIndexes, activeIndex: $activeIndex');

      // 保存分屏状态
      _settingsProvider!.saveLastMultiScreen(
        channelIds,
        activeIndex,
        sourceIndexes: sourceIndexes,
      );
      _multiScreenStateSaved = true;
    } catch (e) {
      ServiceLocator.log.d('PlayerScreen: Error saving multi-screen state: $e');
    }
  }

  /// 显示源切换指示器 (已移除，因为顶部已有显示)
  void _showSourceSwitchIndicator(PlayerProvider provider) {
    // 不再显示 SnackBar，顶部已有源指示器
  }

  void _saveLastChannelId(Channel? channel) {
    if (channel == null || channel.id == null) return;
    if (_settingsProvider != null && _settingsProvider!.rememberLastChannel) {
      // 保存单频道播放状态
      _settingsProvider!.saveLastSingleChannel(channel.id);
    }
  }

  // ============ 手机端手动控制============

  // 简化手动控制
  Offset? _panStartPosition;
  String?
      _currentGestureType; // 'volume', 'brightness', 'channel', 'horizontal'

  void _onPanStart(DragStartDetails details) {
    _panStartPosition = details.globalPosition;
    _currentGestureType = null;

    final playerProvider = _playerProvider ?? context.read<PlayerProvider>();
    _initialVolume = playerProvider.volume;
    _gestureStartY = details.globalPosition.dy;

    // 异步获取当前亮度
    _loadCurrentBrightness();
  }

  Future<void> _loadCurrentBrightness() async {
    try {
      _initialBrightness = await ScreenBrightness.instance.current;
    } catch (_) {
      _initialBrightness = 0.5;
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_panStartPosition == null) return;

    final dx = details.globalPosition.dx - _panStartPosition!.dx;
    final dy = details.globalPosition.dy - _panStartPosition!.dy;

    // 首次移动超过阈值时确定手势类型
    if (_currentGestureType == null) {
      const threshold = 10.0; // 降低阈值，更灵敏
      if (dx.abs() > threshold || dy.abs() > threshold) {
        final screenWidth = MediaQuery.of(context).size.width;
        final x = _panStartPosition!.dx;

        if (dy.abs() > dx.abs()) {
          // 垂直滑动
          if (x < screenWidth * 0.35) {
            _currentGestureType = 'volume';
            _gestureValue = _initialVolume;
          } else if (x > screenWidth * 0.65) {
            _currentGestureType = 'brightness';
            _gestureValue = _initialBrightness;
          } else {
            _currentGestureType = 'channel';
          }
        } else {
          // 姘村钩婊戝姩
          _currentGestureType = 'horizontal';
        }
      }
      return;
    }

    // 处理垂直滑动
    final screenHeight = MediaQuery.of(context).size.height;
    final deltaY = _gestureStartY - details.globalPosition.dy;

    if (_currentGestureType == 'volume') {
      final volumeChange =
          (deltaY / (screenHeight * 0.5)) * 1.0; // 滑动半屏改变100%音量
      final newVolume = (_initialVolume + volumeChange).clamp(0.0, 1.0);
      (_playerProvider ?? context.read<PlayerProvider>()).setVolume(newVolume);
      setState(() {
        _showGestureIndicator = true;
        _gestureValue = newVolume;
      });
    } else if (_currentGestureType == 'brightness') {
      final brightnessChange = (deltaY / (screenHeight * 0.5)) * 1.0;
      final newBrightness =
          (_initialBrightness + brightnessChange).clamp(0.0, 1.0);
      try {
        ScreenBrightness.instance.setApplicationScreenBrightness(newBrightness);
      } catch (_) {}
      setState(() {
        _showGestureIndicator = true;
        _gestureValue = newBrightness;
      });
    } else if (_currentGestureType == 'channel') {
      // 个棿鍖哄煙显示婊戝姩鎸囩ず
      setState(() {
        _showGestureIndicator = true;
        _gestureValue = dy.clamp(-100.0, 100.0) / 100.0; // 用于显示方向
      });
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_panStartPosition == null) {
      _resetGestureState();
      return;
    }

    final dx = details.globalPosition.dx - _panStartPosition!.dx;
    final dy = details.globalPosition.dy - _panStartPosition!.dy;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // 处理频道切换
    if (_currentGestureType == 'channel') {
      final threshold = screenHeight * 0.08; // 婊戝姩瓒呰繃屏箷8%启冲彲切囨崲
      if (dy.abs() > threshold) {
        _errorShown = false; // 切囨崲棰戦亾时堕噸缃敊璇爣璁?
        _errorHideTimer?.cancel(); // 取消错误提示隐藏定时器
        // 隐藏错误提示
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        final playerProvider =
            _playerProvider ?? context.read<PlayerProvider>();
        final channelProvider = context.read<ChannelProvider>();
        if (dy > 0) {
          // 下滑 -> 上一个频道
          playerProvider.playPrevious(channelProvider.allChannels);
          _saveLastChannelId(playerProvider.currentChannel);
        } else {
          // 上滑 -> 下一个频道
          playerProvider.playNext(channelProvider.allChannels);
          _saveLastChannelId(playerProvider.currentChannel);
        }
        // 强制刷新 UI
        setState(() {});
      }
    }

    // 处理水平滑动 - 显示/隐藏分类菜单
    if (_currentGestureType == 'horizontal') {
      final threshold = screenWidth * 0.15; // 婊戝姩瓒呰繃屏箷15%
      if (dx < -threshold && !_showCategoryPanel) {
        // 宸︽粦显示切嗙被鑿滃崟
        setState(() {
          _showCategoryPanel = true;
          _showControls = false;
        });
      } else if (dx > threshold && _showCategoryPanel) {
        // 只虫粦全抽棴切嗙被鑿滃崟
        setState(() {
          _showCategoryPanel = false;
          _selectedCategory = null;
        });
      }
    }

    _resetGestureState();
  }

  void _resetGestureState() {
    setState(() {
      _showGestureIndicator = false;
    });
    _panStartPosition = null;
    _currentGestureType = null;
  }

  Widget _buildGestureIndicator() {
    IconData icon;
    String label;

    if (_currentGestureType == 'volume') {
      icon = _gestureValue > 0.5
          ? Icons.volume_up
          : (_gestureValue > 0 ? Icons.volume_down : Icons.volume_off);
      label = '${(_gestureValue * 100).toInt()}%';
    } else if (_currentGestureType == 'brightness') {
      icon = _gestureValue > 0.5 ? Icons.brightness_high : Icons.brightness_low;
      label = '${(_gestureValue * 100).toInt()}%';
    } else if (_currentGestureType == 'channel') {
      // 棰戦亾切囨崲鎸囩ず
      if (_gestureValue < 0) {
        icon = Icons.keyboard_arrow_up;
        label = AppStrings.of(context)?.nextChannel ?? 'Next channel';
      } else {
        icon = Icons.keyboard_arrow_down;
        label = AppStrings.of(context)?.previousChannel ?? 'Previous channel';
      }
    } else {
      return const SizedBox.shrink();
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(180),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 36),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  DateTime? _lastSelectKeyDownTime;
  DateTime? _lastLeftKeyDownTime; // 用于检测长按左键
  Timer? _longPressTimer; // 长按定时器

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    _showControlsTemporarily();

    final playerProvider = context.read<PlayerProvider>();
    final key = event.logicalKey;

    // Play/Pause & Favorite (Select/Enter)
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space) {
      if (event is KeyDownEvent) {
        if (event is KeyRepeatEvent) return KeyEventResult.handled;
        _lastSelectKeyDownTime = DateTime.now();
        return KeyEventResult.handled;
      }

      if (event is KeyUpEvent && _lastSelectKeyDownTime != null) {
        final duration = DateTime.now().difference(_lastSelectKeyDownTime!);
        _lastSelectKeyDownTime = null;

        if (duration.inMilliseconds > 500) {
          // Long Press: Toggle Favorite
          // Channel Provider not needed, Favorites Provider is enough
          // final provider = context.read<ChannelProvider>();
          final favorites = context.read<FavoritesProvider>();
          final channel = playerProvider.currentChannel;

          if (channel != null) {
            favorites.toggleFavorite(channel);

            // Show toast
            final isFav = favorites.isFavorite(channel.id ?? 0);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isFav ? 'Added to Favorites' : 'Removed from Favorites',
                ),
                duration: const Duration(seconds: 1),
                backgroundColor: AppTheme.accentColor,
              ),
            );
          }
        } else {
          // Short Press: Play/Pause or Select Button if focused?
          // Actually, if we are focused on a button, the button handles it?
          // No, we are in the Parent Focus Capture.
          // If we handle it here, the child button's 'onSelect' might not trigger if we consume it?
          // Focus on the scaffold body is _playerFocusNode.
          // If focus is on a button, this _handleKeyEvent on _playerFocusNode might NOT receive it if the button consumes it?
          // Wait, Focus(onKeyEvent) usually bubbles UP if not handled by child.
          // If the child (button) handles it, this won't run.
          // So this logic only applies when no button handles it (e.g. video area focused).
          playerProvider.togglePlayPause();
        }
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }

    // Left key - 切囨崲个婁竴个簮 / 闀挎寜手撳紑切嗙被闈㈡澘
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (event is KeyDownEvent) {
        if (event is KeyRepeatEvent) return KeyEventResult.handled;
        _lastLeftKeyDownTime = DateTime.now();
        // 启动长按定时器
        _longPressTimer?.cancel();
        _longPressTimer = Timer(const Duration(milliseconds: 500), () {
          if (mounted && _lastLeftKeyDownTime != null) {
            // 闀挎寜锛氭墦开切嗙被闈㈡澘骞跺畾浣嶅埌当前前棰戦亾
            final playerProvider = context.read<PlayerProvider>();
            final channelProvider = context.read<ChannelProvider>();
            final currentChannel = playerProvider.currentChannel;
            
            setState(() {
              _showCategoryPanel = true;
              // 如果有当前频道，自动选中其所属分类
              if (currentChannel != null && currentChannel.groupName != null) {
                _selectedCategory = currentChannel.groupName;
                
                // 延迟滚动到当前频道位置
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_selectedCategory != null) {
                    final channels = channelProvider.getChannelsByGroup(_selectedCategory!);
                    final currentIndex = channels.indexWhere((ch) => ch.id == currentChannel.id);
                    
                    if (currentIndex >= 0 && _channelScrollController.hasClients) {
                      // 计算滚动位置（每个频道项高 44 像素高）
                      final itemHeight = 44.0;
                      final scrollOffset = currentIndex * itemHeight;
                      
                      _channelScrollController.animateTo(
                        scrollOffset,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  }
                });
              } else {
                _selectedCategory = null;
              }
            });
            _lastLeftKeyDownTime = null; // 标记已处理长按
          }
        });
        return KeyEventResult.handled;
      }

      if (event is KeyUpEvent) {
        _longPressTimer?.cancel();
        if (_lastLeftKeyDownTime != null) {
          // 短按：切换上一个源或重新显示分类面板
          _lastLeftKeyDownTime = null;

          if (_showCategoryPanel) {
            // 如果分屏面板已显示且在频道列表，返回分类列表
            if (_selectedCategory != null) {
              setState(() => _selectedCategory = null);
              return KeyEventResult.handled;
            }
            // 如果在分类列表，关闭面板
            setState(() {
              _showCategoryPanel = false;
              _selectedCategory = null;
            });
            return KeyEventResult.handled;
          }

          // 切囨崲切颁笂个€个簮
          final channel = playerProvider.currentChannel;
          if (channel != null && channel.hasMultipleSources) {
            playerProvider.switchToPreviousSource();
            _showSourceSwitchIndicator(playerProvider);
          }
        }
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }

    // Right key - 切囨崲个嬩竴个簮
    if (key == LogicalKeyboardKey.arrowRight) {
      if (_showCategoryPanel) {
        // 如果在分类面板，按键不做任何事
        return KeyEventResult.handled;
      }

      if (event is KeyDownEvent && event is! KeyRepeatEvent) {
        // 切囨崲切颁笅个€个簮
        final channel = playerProvider.currentChannel;
        if (channel != null && channel.hasMultipleSources) {
          playerProvider.switchToNextSource();
          _showSourceSwitchIndicator(playerProvider);
        }
      }
      return KeyEventResult.handled;
    }

    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    // I will keep Up/Down as Channel Switch for now, unless user explicitly requested navigation.
    // Wait, user complained "Navigate bar displays, Left/Right cannot seek (should move focus)".
    // They didn't complain about Up/Down. So I will ONLY modify Left/Right.

    // Previous Channel (Up)
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.channelUp) {
      _errorShown = false; // 切囨崲棰戦亾时堕噸缃敊璇爣璁?
      _errorHideTimer?.cancel(); // 取消错误提示隐藏定时器
      // 隐藏错误提示
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      final channelProvider = context.read<ChannelProvider>();
      playerProvider.playPrevious(channelProvider.allChannels);
      // 保存上次播放的频道 ID
      _saveLastChannelId(playerProvider.currentChannel);
      return KeyEventResult.handled;
    }

    // Next Channel (Down)
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.channelDown) {
      _errorShown = false; // 切囨崲棰戦亾时堕噸缃敊璇爣璁?
      _errorHideTimer?.cancel(); // 取消错误提示隐藏定时器
      // 隐藏错误提示
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      final channelProvider = context.read<ChannelProvider>();
      playerProvider.playNext(channelProvider.allChannels);
      // 保存上次播放的频道 ID
      _saveLastChannelId(playerProvider.currentChannel);
      return KeyEventResult.handled;
    }

    // Back/Exit
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
      // 沉浸模式下先退出迷你模式
      if (WindowsPipChannel.isInPipMode) {
        WindowsPipChannel.exitPipMode();
        setState(() {});
        // 恢复焦点到播放器
        _playerFocusNode.requestFocus();
        return KeyEventResult.handled;
      }

      // 先清除所有错误提示和状态
      _errorHideTimer?.cancel();
      _errorShown = false;
      ScaffoldMessenger.of(context).clearSnackBars();

      // 不需要手动调用 stop()，dispose 会自动处理
      // 直接返回即可，dispose 会在页面销毁时调用

      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      return KeyEventResult.handled;
    }

    // Mute - 只在 TV 端处理
    if (key == LogicalKeyboardKey.keyM ||
        (key == LogicalKeyboardKey.audioVolumeMute &&
            !PlatformDetector.isMobile)) {
      playerProvider.toggleMute();
      return KeyEventResult.handled;
    }

    // Explicit Volume Keys (for TV remotes with dedicated buttons)
    // 手机端让系统处理音量键
    if (!PlatformDetector.isMobile) {
      if (key == LogicalKeyboardKey.audioVolumeUp) {
        playerProvider.setVolume(playerProvider.volume + 0.1);
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.audioVolumeDown) {
        playerProvider.setVolume(playerProvider.volume - 0.1);
        return KeyEventResult.handled;
      }
    }

    // Settings / Menu
    if (key == LogicalKeyboardKey.settings ||
        key == LogicalKeyboardKey.contextMenu) {
      _showSettingsSheet(context);
      return KeyEventResult.handled;
    }

    // Back (explicit handling for some remotes)
    if (key == LogicalKeyboardKey.backspace) {
      ServiceLocator.log.d('========================================');
      ServiceLocator.log.d('PlayerScreen: Back key pressed (backspace)');

      // 先清除所有错误提示和状态
      ServiceLocator.log.d('PlayerScreen: Clearing error state');
      _errorHideTimer?.cancel();
      _errorShown = false;
      ScaffoldMessenger.of(context).clearSnackBars();
      ServiceLocator.log.d('PlayerScreen: SnackBars cleared');

      // 不需要手动调用 stop()，dispose 会自动处理
      ServiceLocator.log
          .d('PlayerScreen: Navigating back (stop will be called in dispose)');

      if (Navigator.canPop(context)) {
        ServiceLocator.log.d('PlayerScreen: Popping navigation');
        Navigator.of(context).pop();
      }
      ServiceLocator.log.d('========================================');
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          // 椤甸潰宸茬粡 pop锛岀珛启虫竻闄ら敊璇彁绀?
          _errorHideTimer?.cancel();
          _errorShown = false;
          try {
            ScaffoldMessenger.of(context).clearSnackBars();
          } catch (e) {
            ServiceLocator.log.d(
                'PlayerScreen: Error clearing SnackBars in onPopInvoked: $e');
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          focusNode: _playerFocusNode,
          autofocus: true,
          onKeyEvent: _handleKeyEvent,
          child: MouseRegion(
            cursor: _showControls
                ? SystemMouseCursors.basic
                : SystemMouseCursors.none,
            onEnter: (_) {
              _mouseOver = true;
              _showControlsTemporarily();
            },
            onHover: (_) {
              _showControlsTemporarily();
            },
            onExit: (_) {
              _mouseOver = false;
              if (mounted) {
                _hideControlsTimer?.cancel();
                _hideControlsTimer =
                    Timer(const Duration(milliseconds: 300), () {
                  if (mounted && !_mouseOver) {
                    setState(() => _showControls = false);
                  }
                });
              }
            },
            child: GestureDetector(
              // 使用 translucent 让子组件也能接收点击事件
              behavior: HitTestBehavior.translucent,
              onTap: () {
                if (_showCategoryPanel) {
                  setState(() {
                    _showCategoryPanel = false;
                    _selectedCategory = null;
                  });
                } else {
                  _showControlsTemporarily();
                }
              },
              onDoubleTap: () {
                context.read<PlayerProvider>().togglePlayPause();
              },
              // 手机端手动控制 - 使用 Pan 手势统一处理
              onPanStart: PlatformDetector.isMobile ? _onPanStart : null,
              onPanUpdate: PlatformDetector.isMobile ? _onPanUpdate : null,
              onPanEnd: PlatformDetector.isMobile ? _onPanEnd : null,
              child: Stack(
                children: [
                  // 全屏背景，确保手势可以在整个屏幕响应
                  const Positioned.fill(
                    child: ColoredBox(color: Colors.transparent),
                  ),

                  // Video Player
                  _buildVideoPlayer(),

                  // Controls Overlay - 分屏模式下不显示全局控制栏
                  if (!_isMultiScreenMode())
                    AnimatedOpacity(
                      opacity: _showControls ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: IgnorePointer(
                        ignoring: !_showControls,
                        child: WindowsPipChannel.isInPipMode
                            ? _buildMiniControlsOverlay()
                            : _buildControlsOverlay(),
                      ),
                    ),

                  // Category Panel (Left side) - 沉浸模式和分屏模式不显示
                  if (_showCategoryPanel &&
                      !WindowsPipChannel.isInPipMode &&
                      !_isMultiScreenMode())
                    _buildCategoryPanel(),

                  // 手前娍鎸囩ず器?手嬫満绔?
                  if (_showGestureIndicator) _buildGestureIndicator(),

                  // Loading Indicator - 切嗗睆模式紡个嬩笉显示全ㄥ眬加浇鎸囩ず器?
                  if (_isLoading && !_isMultiScreenMode())
                    Center(
                      child: Transform.scale(
                        scale: WindowsPipChannel.isInPipMode ? 0.6 : 1.0,
                        child: CircularProgressIndicator(
                          color: AppTheme.getPrimaryColor(context),
                        ),
                      ),
                    ),

                  // FPS 显示 - 只充笂视掔孩鑹诧紙杩蜂綘模式紡启曠嫭显示锛?
                  Builder(
                    builder: (context) {
                      final settings = context.watch<SettingsProvider>();
                      final player = context.watch<PlayerProvider>();

                      // 非全屏模式下由底部组件统一显示
                      if (!WindowsPipChannel.isInPipMode) {
                        return const SizedBox.shrink();
                      }

                      if (!settings.showFps ||
                          player.state != PlayerState.playing) {
                        return const SizedBox.shrink();
                      }
                      final fps = player.currentFps;
                      if (fps <= 0) return const SizedBox.shrink();

                      return Positioned(
                        bottom: 4,
                        right: 4,
                        child: IgnorePointer(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Text(
                              '${fps.toStringAsFixed(0)} FPS',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                      // Windows 播放器信息显示 - 右上角（网速、时间、FPS、分辨率等）
                  // 分屏模式下不显示全局信息（每个分屏有自己的信息显示）
                  Builder(
                    builder: (context) {
                      final settings = context.watch<SettingsProvider>();
                      final player = context.watch<PlayerProvider>();

                      // 分屏模式、迷你模式或非播放状态不显示
                      if (_isMultiScreenMode() ||
                          WindowsPipChannel.isInPipMode ||
                          player.state != PlayerState.playing) {
                        return const SizedBox.shrink();
                      }

                      // 检查是否有任何信息需要显示
                      final showAny = settings.showNetworkSpeed ||
                          settings.showClock ||
                          settings.showFps ||
                          settings.showVideoInfo;
                      if (!showAny) return const SizedBox.shrink();

                      final fps = player.currentFps;

                      return Positioned(
                        top: MediaQuery.of(context).padding.top + 8,
                        right: 16,
                        child: IgnorePointer(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 缃戦€熸樉绀?- 已胯壊 (浠?TV 绔樉绀猴紝Windows 绔笉显示)
                              if (settings.showNetworkSpeed &&
                                  player.downloadSpeed > 0 &&
                                  PlatformDetector.isTV)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _formatSpeed(player.downloadSpeed),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              // 时堕棿显示 - 榛戣壊
                              if (settings.showClock)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: StreamBuilder(
                                    stream: Stream.periodic(
                                        const Duration(seconds: 1)),
                                    builder: (context, snapshot) {
                                      final now = DateTime.now();
                                      return Text(
                                        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              // FPS 显示 - 绾㈣壊
                              if (settings.showFps && fps > 0)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${fps.toStringAsFixed(0)} FPS',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              // 分辨率显示 - 蓝色
                              if (settings.showVideoInfo &&
                                  player.videoWidth > 0 &&
                                  player.videoHeight > 0)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${player.videoWidth}x${player.videoHeight}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // Error Display - Handled via Listener now to show SnackBar
                  // But we can keep a subtle indicator if needed, or remove it entirely
                  // to prevent blocking. Let's remove the blocking widget.
                ],
              ),
            ),
          ),
        ),
      ),
    ); // PopScope
  }

  Widget _buildVideoPlayer() {
    // 使用本地状态判断是否显示分屏模式
    if (_isMultiScreenMode()) {
      return _buildMultiScreenPlayer();
    }

    return Consumer<PlayerProvider>(
      builder: (context, provider, _) {
        // 已熶竴使用敤 media_kit
        if (provider.videoController == null) {
          return const SizedBox.expand(
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return Video(
          controller: provider.videoController!,
          controls: NoVideoControls,
        );
      },
    );
  }

  // 多屏播放器
  Widget _buildMultiScreenPlayer() {
    return MultiScreenPlayer(
      onExitMultiScreen: () {
        // 退出分屏模式，使用活动屏幕的频道全屏播放（不修改设置）
        final multiScreenProvider = context.read<MultiScreenProvider>();
        final activeChannel = multiScreenProvider.activeChannel;

        // 切回单屏前：释放多屏播放器，但保留每屏频道状态，方便再次进入
        multiScreenProvider.pauseAllScreens();

        // 切换到常规模式
        setState(() {
          _localMultiScreenMode = false;
        });

        if (activeChannel != null) {
          // 使用主播放器播放活动频道
          unawaited(_resumeSingleFromMultiScreen(activeChannel));
        }
      },
      onBack: () async {
        // 先保存分屏状态，再清空
        _saveMultiScreenState();
        // 返回时清空所有分屏（等待完成）
        final multiScreenProvider = context.read<MultiScreenProvider>();
        await multiScreenProvider.clearAllScreens();
        if (mounted) {
          Navigator.of(context).pop();
        }
      },
    );
  }

  // 切换到分屏模式

  Future<void> _resumeSingleFromMultiScreen(Channel activeChannel) async {
    final playerProvider = context.read<PlayerProvider>();
    final channelProvider = context.read<ChannelProvider>();

    // Prefer channel object from ChannelProvider to keep original source list/count.
    final matchedChannel = channelProvider.allChannels.cast<Channel?>().firstWhere(
          (c) =>
              c != null &&
              ((activeChannel.id != null && c.id == activeChannel.id) ||
                  c.name == activeChannel.name),
          orElse: () => null,
        );

    final baseChannel = matchedChannel ?? activeChannel;
    final targetSourceIndex = activeChannel.currentSourceIndex.clamp(
      0,
      baseChannel.sourceCount - 1,
    );

    if (matchedChannel != null) {
      matchedChannel.currentSourceIndex = targetSourceIndex;
    }

    final resumeChannel = baseChannel.copyWith(
      currentSourceIndex: targetSourceIndex,
    );
    await playerProvider.playChannel(
      resumeChannel,
      preserveCurrentSource: true,
    );
  }

  void _switchToMultiScreenMode() {
    if (!PlatformDetector.isDesktop) return;
    final playerProvider = context.read<PlayerProvider>();
    final multiScreenProvider = context.read<MultiScreenProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final currentChannel = playerProvider.currentChannel;

    // 切换到多屏前先暂停单屏播放
    unawaited(playerProvider.stop(silent: true));

    // 设置音噺澧炲己切板垎灞廝rovider
    multiScreenProvider.setVolumeSettings(
        playerProvider.volume, settingsProvider.volumeBoost);

    // 切换到分屏模式
    setState(() {
      _localMultiScreenMode = true;
    });

    // 如果分屏有记住的频道，恢复播放
    if (multiScreenProvider.hasAnyChannel) {
      multiScreenProvider.resumeAllScreens();
      // 如果有当前频道，更新活动屏幕为当前频道（保留源索引）
      if (currentChannel != null) {
        final activeIndex = multiScreenProvider.activeScreenIndex;
        multiScreenProvider.playChannelOnScreen(activeIndex, currentChannel);
      }
    } else if (currentChannel != null) {
      // 否则如果有当前频道，在默认位置播放
      final defaultPosition = settingsProvider.defaultScreenPosition;
      multiScreenProvider.playChannelAtDefaultPosition(
          currentChannel, defaultPosition);
    }
  }

  // 杩蜂綘模式紡个嬬殑绠€鍖栨帶切?
  Widget _buildMiniControlsOverlay() {
    return GestureDetector(
      // 整个区域可拖动
      onPanStart: (_) => windowManager.startDragging(),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.transparent,
              Colors.black.withOpacity(0.5),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Column(
          children: [
            // 顶部：只保留恢复和关闭，不显示标题文字和退出按钮
            Padding(
              padding: const EdgeInsets.all(6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // 恢复大小按钮
                  GestureDetector(
                    onTap: () async {
                      await WindowsPipChannel.exitPipMode();
                      // 延迟同步全屏状态，等待窗口恢复完成
                      if (PlatformDetector.isWindows) {
                        await Future.delayed(const Duration(milliseconds: 300));
                        _isFullScreen = await windowManager.isFullScreen();
                      }
                      setState(() {});
                      // 恢复焦点到播放器
                      _playerFocusNode.requestFocus();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.fullscreen,
                          color: Colors.white, size: 14),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // 全抽棴按挳
                  GestureDetector(
                    onTap: () {
                      WindowsPipChannel.exitPipMode();
                      context.read<PlayerProvider>().stop();
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 14),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // 底部：静音 + 播放/暂停按钮
            Padding(
              padding: const EdgeInsets.all(8),
              child: Consumer<PlayerProvider>(
                builder: (context, provider, _) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 闈欓煶按挳
                      GestureDetector(
                        onTap: provider.toggleMute,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            provider.isMuted
                                ? Icons.volume_off
                                : Icons.volume_up,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 播放/暂停按钮
                      GestureDetector(
                        onTap: provider.togglePlayPause,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            gradient: AppTheme.lotusGradient,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            provider.isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return Stack(
      children: [
        // Top gradient mask
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 160,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xCC000000), // 80% black
                  Color(0x66000000), // 40% black
                  Colors.transparent,
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
        // Bottom gradient mask
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 200,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Color(0x80000000), // 50% black
                  Color(0xE6000000), // 90% black
                ],
                stops: [0.0, 0.4, 1.0],
              ),
            ),
          ),
        ),
        // Content
        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTopBar(),
              const Spacer(),
              _buildBottomControls(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Padding(
      // 调整顶部间距为 30，使按钮向上移动，减少与信息窗口的距离，同时保持不重叠
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 16),
      child: Row(
        children: [
          // Semi-transparent channel logo/back button
          TVFocusable(
            onSelect: () async {
              // 先清除所有错误提示和状态
              _errorHideTimer?.cancel();
              _errorShown = false;
              ScaffoldMessenger.of(context).clearSnackBars();

              // 如果是全屏状态，先退出全屏 - 使用原生 API
              if (_isFullScreen && PlatformDetector.isWindows) {
                _isFullScreen = false;
                final success = WindowsFullscreenNative.exitFullScreen();
                if (!success) {
                  // 如果原生 API 失败，回退到 window_manager
                  unawaited(windowManager.setFullScreen(false));
                }
              }

              // 不需要手动调用 stop()，dispose 会自动处理

              // 最后导航返回
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
            focusScale: 1.0,
            showFocusBorder: false,
            builder: (context, isFocused, child) {
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isFocused
                      ? AppTheme.getPrimaryColor(context)
                      : const Color(0x33FFFFFF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isFocused
                        ? AppTheme.getPrimaryColor(context)
                        : const Color(0x1AFFFFFF),
                    width: isFocused ? 2 : 1,
                  ),
                ),
                child: child,
              );
            },
            child: const Icon(Icons.arrow_back_rounded,
                color: Colors.white, size: 18),
          ),

          const SizedBox(width: 16),

          // Minimal channel info
          Expanded(
            child: Consumer<PlayerProvider>(
              builder: (context, provider, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      provider.currentChannel?.name ?? widget.channelName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // Live indicator
                        if (provider.state == PlayerState.playing) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: AppTheme.getGradient(context),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle,
                                    color: Colors.white, size: 6),
                                SizedBox(width: 4),
                                Text('LIVE',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        // Source indicator (if multiple sources)
                        if (provider.currentChannel != null &&
                            provider.currentChannel!.hasMultipleSources) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.getPrimaryColor(context)
                                  .withOpacity(0.8),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.swap_horiz,
                                    color: Colors.white, size: 10),
                                const SizedBox(width: 4),
                                Text(
                                  '${AppStrings.of(context)?.source ?? 'Source'} ${provider.currentSourceIndex}/${provider.sourceCount}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        // Video info
                        if (provider.videoInfo.isNotEmpty)
                          Text(
                            provider.videoInfo,
                            style: const TextStyle(
                                color: Color(0x99FFFFFF), fontSize: 11),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),

          // Favorite button - minimal style
          Consumer<FavoritesProvider>(
            builder: (context, favorites, _) {
              final playerProvider = context.read<PlayerProvider>();
              final currentChannel = playerProvider.currentChannel;
              final isFav = currentChannel != null &&
                  favorites.isFavorite(currentChannel.id ?? 0);

              return TVFocusable(
                onSelect: () async {
                  if (currentChannel != null) {
                    ServiceLocator.log.d(
                        'TV播放器: 尝试切换收藏状态 - 频道: ${currentChannel.name}, ID: ${currentChannel.id}');
                    final success =
                        await favorites.toggleFavorite(currentChannel);
                    ServiceLocator.log.d('TV播放器: 收藏切换${success ? "成功" : "失败"}');

                    if (success) {
                      final newIsFav =
                          favorites.isFavorite(currentChannel.id ?? 0);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            newIsFav ? '已添加到收藏' : '已从收藏中移除',
                          ),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    }
                  } else {
                    ServiceLocator.log.d('TV播放器: 当前频道为空，无法切换收藏');
                  }
                },
                focusScale: 1.0,
                showFocusBorder: false,
                builder: (context, isFocused, child) {
                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: isFav ? AppTheme.getGradient(context) : null,
                      color: isFav
                          ? null
                          : (isFocused
                              ? AppTheme.getPrimaryColor(context)
                              : const Color(0x33FFFFFF)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isFocused
                            ? AppTheme.getPrimaryColor(context)
                            : const Color(0x1AFFFFFF),
                        width: isFocused ? 2 : 1,
                      ),
                    ),
                    child: child,
                  );
                },
                child: Icon(
                  isFav ? Icons.favorite : Icons.favorite_border_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              );
            },
          ),

          // PiP 画中画播放器按钮 - 仅 Windows
          if (WindowsPipChannel.isSupported) ...[
            const SizedBox(width: 8),
            _buildPipButton(),
          ],

          // 切嗗睆模式紡按挳 - 浠呮闈㈠钩只?
          if (PlatformDetector.isDesktop) ...[
            const SizedBox(width: 8),
            _buildMultiScreenButton(),
          ],
        ],
      ),
    );
  }

  // 切嗗睆模式紡切囨崲按挳
  Widget _buildMultiScreenButton() {
    return TVFocusable(
      onSelect: _switchToMultiScreenMode,
      focusScale: 1.0,
      showFocusBorder: false,
      builder: (context, isFocused, child) {
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isFocused
                ? AppTheme.getPrimaryColor(context)
                : const Color(0x33FFFFFF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isFocused
                  ? AppTheme.getPrimaryColor(context)
                  : const Color(0x1AFFFFFF),
              width: isFocused ? 2 : 1,
            ),
          ),
          child: child,
        );
      },
      child: const Icon(
        Icons.grid_view_rounded,
        color: Colors.white,
        size: 18,
      ),
    );
  }

  // PiP 画中画播放器按钮
  Widget _buildPipButton() {
    return StatefulBuilder(
      builder: (context, setState) {
        final isInPip = WindowsPipChannel.isInPipMode;
        final isPinned = WindowsPipChannel.isPinned;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // PiP 切囨崲按挳
            TVFocusable(
              onSelect: () async {
                await WindowsPipChannel.togglePipMode();
                // 延迟同步全屏状态，等待窗口状态稳定
                if (PlatformDetector.isWindows) {
                  await Future.delayed(const Duration(milliseconds: 300));
                  _isFullScreen = await windowManager.isFullScreen();
                }
                setState(() {});
              },
              focusScale: 1.0,
              showFocusBorder: false,
              builder: (context, isFocused, child) {
                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: isInPip ? AppTheme.getGradient(context) : null,
                    color: isInPip
                        ? null
                        : (isFocused
                            ? AppTheme.getPrimaryColor(context)
                            : const Color(0x33FFFFFF)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isFocused
                          ? AppTheme.getPrimaryColor(context)
                          : const Color(0x1AFFFFFF),
                      width: isFocused ? 2 : 1,
                    ),
                  ),
                  child: child,
                );
              },
              child: Icon(
                isInPip ? Icons.fullscreen : Icons.picture_in_picture_alt,
                color: Colors.white,
                size: 18,
              ),
            ),
            // 缃《按挳 - 浠呭湪杩蜂綘模式紡个嬫樉绀?
            if (isInPip) ...[
              const SizedBox(width: 8),
              TVFocusable(
                onSelect: () async {
                  await WindowsPipChannel.togglePin();
                  setState(() {});
                },
                focusScale: 1.0,
                showFocusBorder: false,
                builder: (context, isFocused, child) {
                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: isPinned ? AppTheme.getGradient(context) : null,
                      color: isPinned
                          ? null
                          : (isFocused
                              ? AppTheme.getPrimaryColor(context)
                              : const Color(0x33FFFFFF)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isFocused
                            ? AppTheme.getPrimaryColor(context)
                            : const Color(0x1AFFFFFF),
                        width: isFocused ? 2 : 1,
                      ),
                    ),
                    child: child,
                  );
                },
                child: Icon(
                  isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildBottomControls() {
    return Consumer<PlayerProvider>(
      builder: (context, provider, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // EPG 当前节目和下一个节目
              Consumer<EpgProvider>(
                builder: (context, epgProvider, _) {
                  final channel = provider.currentChannel;
                  final currentProgram = epgProvider.getCurrentProgram(
                      channel?.epgId, channel?.name);
                  final nextProgram =
                      epgProvider.getNextProgram(channel?.epgId, channel?.name);

                  if (currentProgram != null || nextProgram != null) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0x33000000),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (currentProgram != null)
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.getPrimaryColor(context),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                        AppStrings.of(context)?.nowPlaying ??
                                            'Now playing',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      currentProgram.title,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    (AppStrings.of(context)?.endsInMinutes ??
                                            'Ends in {minutes} min')
                                        .replaceFirst('{minutes}',
                                            '${currentProgram.remainingMinutes}'),
                                    style: const TextStyle(
                                        color: Color(0x99FFFFFF), fontSize: 11),
                                  ),
                                ],
                              ),
                            if (nextProgram != null) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppTheme.getPrimaryColor(context)
                                              .withOpacity(0.7),
                                          AppTheme.getSecondaryColor(context)
                                              .withOpacity(0.7),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                        AppStrings.of(context)?.upNext ??
                                            'Up next',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      nextProgram.title,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

              // Progress bar for seekable content (VOD, Replay) - EPG 淇℃伅个嬫柟
              Consumer<SettingsProvider>(
                builder: (context, settings, _) {
                  if (!provider
                      .shouldShowProgressBar(settings.progressBarMode)) {
                    return const SizedBox.shrink();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      children: [
                        // 进度条（更小的高度）
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2, // 减小轨道高度
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 5), // 减小滑块大小
                            overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 10), // 减皬视︽懜鍖哄煙
                            activeTrackColor: AppTheme.getPrimaryColor(context),
                            inactiveTrackColor: const Color(0x33FFFFFF),
                            thumbColor: Colors.white,
                            overlayColor: AppTheme.getPrimaryColor(context)
                                .withOpacity(0.3),
                          ),
                          child: Slider(
                            value: provider.position.inSeconds.toDouble().clamp(
                                0, provider.duration.inSeconds.toDouble()),
                            max: provider.duration.inSeconds
                                .toDouble()
                                .clamp(1, double.infinity),
                            onChanged: (value) {
                              provider.seek(Duration(seconds: value.toInt()));
                            },
                          ),
                        ),
                        // 时堕棿显示锛堟洿宽忕殑瀛椾綋鍜岄棿璺濓級
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(provider.position),
                                style: const TextStyle(
                                    color: Color(0x99FFFFFF), fontSize: 10),
                              ),
                              Text(
                                _formatDuration(provider.duration),
                                style: const TextStyle(
                                    color: Color(0x99FFFFFF), fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Control buttons row (moved above progress bar)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Volume control
                  _buildVolumeControl(provider),

                  const SizedBox(width: 16),

                  // 手嬫満绔簮切囨崲按挳 - 个婁竴个簮
                  if (PlatformDetector.isMobile &&
                      provider.currentChannel != null &&
                      provider.currentChannel!.hasMultipleSources)
                    TVFocusable(
                      onSelect: () {
                        provider.switchToPreviousSource();
                        _showSourceSwitchIndicator(provider);
                      },
                      focusScale: 1.0,
                      showFocusBorder: false,
                      builder: (context, isFocused, child) {
                        return Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isFocused
                                ? AppTheme.getPrimaryColor(context)
                                : const Color(0x33FFFFFF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isFocused
                                  ? AppTheme.getPrimaryColor(context)
                                  : const Color(0x1AFFFFFF),
                              width: isFocused ? 2 : 1,
                            ),
                          ),
                          child: child,
                        );
                      },
                      child: const Icon(Icons.skip_previous_rounded,
                          color: Colors.white, size: 18),
                    ),

                  if (PlatformDetector.isMobile &&
                      provider.currentChannel != null &&
                      provider.currentChannel!.hasMultipleSources)
                    const SizedBox(width: 8),

                  // Play/Pause - Lotus gradient button (smaller)
                  TVFocusable(
                    autofocus: true,
                    onSelect: provider.togglePlayPause,
                    focusScale: 1.0,
                    showFocusBorder: false,
                    builder: (context, isFocused, child) {
                      return Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: AppTheme.getGradient(context),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                isFocused ? Colors.white : Colors.transparent,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.getPrimaryColor(context)
                                  .withAlpha(isFocused ? 100 : 50),
                              blurRadius: isFocused ? 16 : 8,
                              spreadRadius: isFocused ? 2 : 1,
                            ),
                          ],
                        ),
                        child: child,
                      );
                    },
                    child: Icon(
                      provider.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),

                  // 手嬫満绔簮切囨崲按挳 - 个嬩竴个簮
                  if (PlatformDetector.isMobile &&
                      provider.currentChannel != null &&
                      provider.currentChannel!.hasMultipleSources)
                    const SizedBox(width: 8),

                  if (PlatformDetector.isMobile &&
                      provider.currentChannel != null &&
                      provider.currentChannel!.hasMultipleSources)
                    TVFocusable(
                      onSelect: () {
                        provider.switchToNextSource();
                        _showSourceSwitchIndicator(provider);
                      },
                      focusScale: 1.0,
                      showFocusBorder: false,
                      builder: (context, isFocused, child) {
                        return Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isFocused
                                ? AppTheme.getPrimaryColor(context)
                                : const Color(0x33FFFFFF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isFocused
                                  ? AppTheme.getPrimaryColor(context)
                                  : const Color(0x1AFFFFFF),
                              width: isFocused ? 2 : 1,
                            ),
                          ),
                          child: child,
                        );
                      },
                      child: const Icon(Icons.skip_next_rounded,
                          color: Colors.white, size: 18),
                    ),

                  if (!PlatformDetector.isMobile &&
                      provider.currentChannel != null &&
                      provider.currentChannel!.hasMultipleSources) ...[
                    const SizedBox(width: 8),
                    TVFocusable(
                      onSelect: () {
                        provider.switchToNextSource();
                        _showSourceSwitchIndicator(provider);
                      },
                      focusScale: 1.0,
                      showFocusBorder: false,
                      builder: (context, isFocused, child) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isFocused
                                ? AppTheme.getPrimaryColor(context)
                                : const Color(0x33FFFFFF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isFocused
                                  ? AppTheme.getPrimaryColor(context)
                                  : const Color(0x1AFFFFFF),
                              width: isFocused ? 2 : 1,
                            ),
                          ),
                          child: child,
                        );
                      },
                      child: Text(
                        '${AppStrings.of(context)?.source ?? 'Source'} ${provider.currentSourceIndex}/${provider.sourceCount}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],

                  const SizedBox(width: 16),

                  // Settings button (smaller)
                  TVFocusable(
                    onSelect: () => _showSettingsSheet(context),
                    focusScale: 1.0,
                    showFocusBorder: false,
                    builder: (context, isFocused, child) {
                      return Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isFocused
                              ? AppTheme.getPrimaryColor(context)
                              : const Color(0x33FFFFFF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isFocused
                                ? AppTheme.getPrimaryColor(context)
                                : const Color(0x1AFFFFFF),
                            width: isFocused ? 2 : 1,
                          ),
                        ),
                        child: child,
                      );
                    },
                    child: const Icon(Icons.settings_rounded,
                        color: Colors.white, size: 18),
                  ),

                  const SizedBox(width: 16),

                  // Category menu button
                  TVFocusable(
                    onSelect: () {
                      setState(() {
                        if (_showCategoryPanel) {
                          // 如果已显示，则隐藏
                          _showCategoryPanel = false;
                          _selectedCategory = null;
                        } else {
                          // 如果没显示，则显示并定位到当前频道
                          final playerProvider = context.read<PlayerProvider>();
                          final channelProvider = context.read<ChannelProvider>();
                          final currentChannel = playerProvider.currentChannel;
                          
                          _showCategoryPanel = true;
                          // 如果有当前频道，自动选中其所属分类
                          if (currentChannel != null && currentChannel.groupName != null) {
                            _selectedCategory = currentChannel.groupName;
                            
                            // 延迟滚动到当前频道位置
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (_selectedCategory != null) {
                                final channels = channelProvider.getChannelsByGroup(_selectedCategory!);
                                final currentIndex = channels.indexWhere((ch) => ch.id == currentChannel.id);
                                
                                if (currentIndex >= 0 && _channelScrollController.hasClients) {
                                  // 计算滚动位置（每个频道项高 44 像素高）
                                  final itemHeight = 44.0;
                                  final scrollOffset = currentIndex * itemHeight;
                                  
                                  _channelScrollController.animateTo(
                                    scrollOffset,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOut,
                                  );
                                }
                              }
                            });
                          } else {
                            _selectedCategory = null;
                          }
                        }
                      });
                    },
                    focusScale: 1.0,
                    showFocusBorder: false,
                    builder: (context, isFocused, child) {
                      return Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isFocused
                              ? AppTheme.getPrimaryColor(context)
                              : const Color(0x33FFFFFF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isFocused
                                ? AppTheme.getPrimaryColor(context)
                                : const Color(0x1AFFFFFF),
                            width: isFocused ? 2 : 1,
                          ),
                        ),
                        child: child,
                      );
                    },
                    child: const Icon(Icons.menu_rounded,
                        color: Colors.white, size: 18),
                  ),

                  // Windows 全ㄥ睆按挳
                  if (PlatformDetector.isWindows) ...[
                    const SizedBox(width: 16),
                    TVFocusable(
                      onSelect: () {
                        _toggleFullScreen();
                        Future.delayed(const Duration(milliseconds: 120), () {
                          if (mounted) _playerFocusNode.requestFocus();
                        });
                      },
                      focusScale: 1.0,
                      showFocusBorder: false,
                      builder: (context, isFocused, child) {
                        return Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isFocused
                                ? AppTheme.getPrimaryColor(context)
                                : const Color(0x33FFFFFF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isFocused
                                  ? AppTheme.getPrimaryColor(context)
                                  : const Color(0x1AFFFFFF),
                              width: isFocused ? 2 : 1,
                            ),
                          ),
                          child: child,
                        );
                      },
                      child: Icon(
                          _isFullScreen
                              ? Icons.fullscreen_exit_rounded
                              : Icons.fullscreen_rounded,
                          color: Colors.white,
                          size: 18),
                    ),
                  ],
                ],
              ),

              // Keyboard hints
              if (PlatformDetector.useDPadNavigation)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    AppStrings.of(context)?.playerHintTV ??
                        '☰️ 切换频道 · 🎛️ 切换源· 长按🔄 分类 · OK 播放/暂停 · 长按OK 收藏',
                    style:
                        const TextStyle(color: Color(0x66FFFFFF), fontSize: 11),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVolumeControl(PlayerProvider provider) {
    // 确保音量值在 0-1 范围内
    final volume = provider.volume.clamp(0.0, 1.0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TVFocusable(
          onSelect: provider.toggleMute,
          focusScale: 1.0,
          showFocusBorder: false,
          builder: (context, isFocused, child) {
            return Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isFocused
                    ? AppTheme.getPrimaryColor(context)
                    : const Color(0x33FFFFFF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isFocused
                      ? AppTheme.getPrimaryColor(context)
                      : const Color(0x1AFFFFFF),
                  width: isFocused ? 2 : 1,
                ),
              ),
              child: child,
            );
          },
          child: Icon(
            provider.isMuted || volume == 0
                ? Icons.volume_off_rounded
                : volume < 0.5
                    ? Icons.volume_down_rounded
                    : Icons.volume_up_rounded,
            color: Colors.white,
            size: 16,
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 70,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
            ),
            child: Slider(
              value: provider.isMuted ? 0 : volume,
              onChanged: (value) {
                // 如果当前是静音状态，拖动滑块时先取消静音
                if (provider.isMuted && value > 0) {
                  provider.toggleMute();
                }
                provider.setVolume(value);
              },
              activeColor: AppTheme.getPrimaryColor(context),
              inactiveColor: const Color(0x33FFFFFF),
            ),
          ),
        ),
      ],
    );
  }

  // 切囨崲全ㄥ睆模式紡 (浠?Windows)
  void _toggleFullScreen() {
    if (!PlatformDetector.isWindows) return;

    // 绠€启曠殑闃叉姈
    final now = DateTime.now();
    if (_lastFullScreenToggle != null &&
        now.difference(_lastFullScreenToggle!).inMilliseconds < 200) {
      return;
    }
    _lastFullScreenToggle = now;

    // 使用敤压熺敓 Windows API 切囨崲全ㄥ睆
    final success = WindowsFullscreenNative.toggleFullScreen();

    if (success) {
      // 异步更新UI状态
      Future.microtask(() {
        if (mounted) {
          setState(() {
            _isFullScreen = WindowsFullscreenNative.isFullScreen();
          });
          _playerFocusNode.requestFocus();
        }
      });
    } else {
      // 如果原生 API 失败，回退到 window_manager
      ServiceLocator.log
          .d('Native fullscreen failed, falling back to window_manager');
      windowManager
          .isFullScreen()
          .then((value) => windowManager.setFullScreen(!value));

      Future.microtask(() {
        if (mounted) {
          windowManager.isFullScreen().then((isFullScreen) {
            if (mounted) {
              setState(() {
                _isFullScreen = isFullScreen;
              });
              _playerFocusNode.requestFocus();
            }
          });
        }
      });
    }
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.getSurfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Consumer<PlayerProvider>(
          builder: (context, provider, _) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.of(context)?.playbackSettings ??
                        'Playback Settings',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Playback Speed
                  Text(
                    AppStrings.of(context)?.playbackSpeed ?? 'Playback Speed',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
                      final isSelected = provider.playbackSpeed == speed;
                      return ChoiceChip(
                        label: Text('${speed}x'),
                        selected: isSelected,
                        onSelected: (_) => provider.setPlaybackSpeed(speed),
                        selectedColor: AppTheme.getPrimaryColor(context),
                        backgroundColor: AppTheme.cardColor,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppTheme.textSecondary,
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryPanel() {
    final channelProvider = context.read<ChannelProvider>();
    final groups = channelProvider.groups;
    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      child: Row(
        children: [
          // 切嗙被切楄〃
          Container(
            width: 180,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xE6000000),
                  Color(0x99000000),
                  Colors.transparent,
                ],
                stops: [0.0, 0.7, 1.0],
              ),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      AppStrings.of(context)?.categories ?? 'Categories',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: _categoryScrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: groups.length,
                      itemBuilder: (context, index) {
                        final group = groups[index];
                        final isSelected = _selectedCategory == group.name;
                        return TVFocusable(
                          autofocus: index == 0 && _selectedCategory == null,
                          onSelect: () {
                            setState(() {
                              _selectedCategory = group.name;
                            });
                          },
                          focusScale: 1.0,
                          showFocusBorder: false,
                          builder: (context, isFocused, child) {
                            return Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                gradient: (isFocused || isSelected)
                                    ? AppTheme.getGradient(context)
                                    : null,
                                color: (isFocused || isSelected)
                                    ? null
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: child,
                            );
                          },
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  group.name,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${group.channelCount}',
                                style: const TextStyle(
                                    color: Color(0x99FFFFFF), fontSize: 11),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 棰戦亾切楄〃锛堝綋閫変腑切嗙被时舵樉绀猴級
          if (_selectedCategory != null) _buildChannelList(),
        ],
      ),
    );
  }

  Widget _buildChannelList() {
    final channelProvider = context.read<ChannelProvider>();
    final playerProvider = context.read<PlayerProvider>();
    final channels = channelProvider.getChannelsByGroup(_selectedCategory!);
    final currentChannel = playerProvider.currentChannel;

    return Container(
      width: 220,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xCC000000),
            Color(0x66000000),
            Colors.transparent,
          ],
          stops: [0.0, 0.7, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _selectedCategory = null),
                    child: const Icon(Icons.arrow_back_ios,
                        color: Colors.white, size: 14),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedCategory!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _channelScrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: channels.length,
                itemBuilder: (context, index) {
                  final channel = channels[index];
                  final isPlaying = currentChannel?.id == channel.id;
                  return TVFocusable(
                    autofocus: isPlaying, // 当前播放的频道自动获取焦点
                    onSelect: () {
                      // 保存上次播放的频道 ID
                      final settingsProvider = context.read<SettingsProvider>();
                      if (settingsProvider.rememberLastChannel &&
                          channel.id != null) {
                        settingsProvider.setLastChannelId(channel.id);
                      }

                      // 切囨崲切拌棰戦亾
                      playerProvider.playChannel(channel);
                      // 全抽棴闈㈡澘
                      setState(() {
                        _showCategoryPanel = false;
                        _selectedCategory = null;
                      });
                    },
                    focusScale: 1.0,
                    showFocusBorder: false,
                    builder: (context, isFocused, child) {
                      return Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          gradient:
                              isFocused ? AppTheme.getGradient(context) : null,
                          color: isPlaying && !isFocused
                              ? const Color(0x33E91E63)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: child,
                      );
                    },
                    child: Row(
                      children: [
                        if (isPlaying)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(Icons.play_arrow,
                                color: AppTheme.getPrimaryColor(context),
                                size: 16),
                          ),
                        Expanded(
                          child: Text(
                            channel.name,
                            style: TextStyle(
                              color: isPlaying
                                  ? AppTheme.getPrimaryColor(context)
                                  : Colors.white,
                              fontSize: 13,
                              fontWeight: isPlaying
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

