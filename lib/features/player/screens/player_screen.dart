import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:video_player/video_player.dart';
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
import '../../../core/models/channel.dart';
import '../providers/player_provider.dart';
import '../../favorites/providers/favorites_provider.dart';
import '../../channels/providers/channel_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../settings/providers/dlna_provider.dart';
import '../../epg/providers/epg_provider.dart';

class PlayerScreen extends StatefulWidget {
  final String channelUrl;
  final String channelName;
  final String? channelLogo;

  const PlayerScreen({
    super.key,
    required this.channelUrl,
    required this.channelName,
    this.channelLogo,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with WidgetsBindingObserver {
  Timer? _hideControlsTimer;
  bool _showControls = true;
  final FocusNode _playerFocusNode = FocusNode();
  bool _usingNativePlayer = false;
  bool _showCategoryPanel = false;
  String? _selectedCategory;
  final ScrollController _categoryScrollController = ScrollController();
  final ScrollController _channelScrollController = ScrollController();

  // 保存 provider 引用，用于 dispose 时释放资源
  PlayerProvider? _playerProvider;

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 保持屏幕常亮
    WakelockPlus.enable();
    _checkAndLaunchPlayer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 保存 provider 引用并添加监听
    if (_playerProvider == null) {
      _playerProvider = context.read<PlayerProvider>();
      _playerProvider!.addListener(_onProviderUpdate);
      _isLoading = _playerProvider!.isLoading;
    }
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
    debugPrint('PlayerScreen: AppLifecycleState changed to $state');
  }

  Future<void> _checkAndLaunchPlayer() async {
    // Check if we should use native player on Android TV
    if (PlatformDetector.isTV && PlatformDetector.isAndroid) {
      final nativeAvailable = await NativePlayerChannel.isAvailable();
      debugPrint('PlayerScreen: Native player available: $nativeAvailable');
      if (nativeAvailable && mounted) {
        _usingNativePlayer = true;

        // Get channel list for native player (use all channels, not filtered)
        final channelProvider = context.read<ChannelProvider>();
        final channels = channelProvider.channels;

        // Find current channel index
        int currentIndex = 0;
        for (int i = 0; i < channels.length; i++) {
          if (channels[i].url == widget.channelUrl) {
            currentIndex = i;
            break;
          }
        }

        // Prepare channel lists with groups
        final urls = channels.map((c) => c.url).toList();
        final names = channels.map((c) => c.name).toList();
        final groups = channels.map((c) => c.groupName ?? '').toList();

        debugPrint('PlayerScreen: Launching native player for ${widget.channelName} (index $currentIndex of ${channels.length})');

        // Launch native player with channel list and callback for when it closes
        final launched = await NativePlayerChannel.launchPlayer(
          url: widget.channelUrl,
          name: widget.channelName,
          index: currentIndex,
          urls: urls,
          names: names,
          groups: groups,
          onClosed: () {
            debugPrint('PlayerScreen: Native player closed callback');
            if (mounted) {
              Navigator.of(context).pop();
            }
          },
        );

        if (launched && mounted) {
          // Don't pop - wait for native player to close via callback
          // The native player is now a Fragment overlay, not a separate Activity
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

    // 不再使用持续监听，改为一次性错误检查
  }

  void _checkAndShowError() {
    if (!mounted || _errorShown) return;
    final provider = context.read<PlayerProvider>();
    if (provider.hasError && provider.error != null) {
      final errorMessage = provider.error!;
      _errorShown = true;
      provider.clearError();

      ScaffoldMessenger.of(context).clearSnackBars();
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('${AppStrings.of(context)?.playbackError ?? "Error"}: $errorMessage'),
          backgroundColor: AppTheme.errorColor,
          duration: const Duration(seconds: 30), // 设置较长时间，用 Timer 控制
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: AppStrings.of(context)?.retry ?? 'Retry',
            textColor: Colors.white,
            onPressed: () {
              _errorShown = false;
              _startPlayback();
            },
          ),
        ),
      );

      // 3秒后自动关闭
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          scaffoldMessenger.hideCurrentSnackBar();
        }
      });
    }
  }

  void _startPlayback() {
    _errorShown = false; // 重置错误显示标记
    final playerProvider = context.read<PlayerProvider>();
    final channelProvider = context.read<ChannelProvider>();
    final settingsProvider = context.read<SettingsProvider>();

    try {
      // Try to find the matching channel to enable playlist navigation
      final channel = channelProvider.channels.firstWhere(
        (c) => c.url == widget.channelUrl,
      );

      // 保存上次播放的频道ID
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

  @override
  void dispose() {
    debugPrint('PlayerScreen: dispose() called, _usingNativePlayer=$_usingNativePlayer');
    WidgetsBinding.instance.removeObserver(this);
    _hideControlsTimer?.cancel();
    _playerFocusNode.dispose();
    _categoryScrollController.dispose();
    _channelScrollController.dispose();

    // Only stop playback if we're using Flutter player (not native)
    if (!_usingNativePlayer && _playerProvider != null) {
      debugPrint('PlayerScreen: calling _playerProvider.stop()');
      _playerProvider!.removeListener(_onProviderUpdate);
      _playerProvider!.stop();
    }

    // 重置亮度到系统默认
    try {
      ScreenBrightness.instance.resetApplicationScreenBrightness();
    } catch (_) {}

    // 关闭屏幕常亮
    WakelockPlus.disable();

    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    super.dispose();
  }

  void _saveLastChannelId(Channel? channel) {
    if (channel == null || channel.id == null) return;
    final settingsProvider = context.read<SettingsProvider>();
    if (settingsProvider.rememberLastChannel) {
      settingsProvider.setLastChannelId(channel.id);
    }
  }

  // ============ 手机端手势控制 ============

  // 简化手势控制
  Offset? _panStartPosition;
  String? _currentGestureType; // 'volume', 'brightness', 'channel', 'horizontal'

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

    // 首次移动超过阈值时决定手势类型
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
          // 水平滑动
          _currentGestureType = 'horizontal';
        }
      }
      return;
    }

    // 处理垂直滑动
    final screenHeight = MediaQuery.of(context).size.height;
    final deltaY = _gestureStartY - details.globalPosition.dy;

    if (_currentGestureType == 'volume') {
      final volumeChange = (deltaY / (screenHeight * 0.5)) * 1.0; // 滑动半屏改变100%音量
      final newVolume = (_initialVolume + volumeChange).clamp(0.0, 1.0);
      (_playerProvider ?? context.read<PlayerProvider>()).setVolume(newVolume);
      setState(() {
        _showGestureIndicator = true;
        _gestureValue = newVolume;
      });
    } else if (_currentGestureType == 'brightness') {
      final brightnessChange = (deltaY / (screenHeight * 0.5)) * 1.0;
      final newBrightness = (_initialBrightness + brightnessChange).clamp(0.0, 1.0);
      try {
        ScreenBrightness.instance.setApplicationScreenBrightness(newBrightness);
      } catch (_) {}
      setState(() {
        _showGestureIndicator = true;
        _gestureValue = newBrightness;
      });
    } else if (_currentGestureType == 'channel') {
      // 中间区域显示滑动指示
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
      final threshold = screenHeight * 0.08; // 滑动超过屏幕8%即可切换
      if (dy.abs() > threshold) {
        _errorShown = false; // 切换频道时重置错误标记
        final playerProvider = _playerProvider ?? context.read<PlayerProvider>();
        final channelProvider = context.read<ChannelProvider>();
        if (dy > 0) {
          // 下滑 -> 上一个频道
          playerProvider.playPrevious(channelProvider.filteredChannels);
          _saveLastChannelId(playerProvider.currentChannel);
        } else {
          // 上滑 -> 下一个频道
          playerProvider.playNext(channelProvider.filteredChannels);
          _saveLastChannelId(playerProvider.currentChannel);
        }
        // 强制刷新 UI
        setState(() {});
      }
    }

    // 处理水平滑动 - 显示/隐藏分类菜单
    if (_currentGestureType == 'horizontal') {
      final threshold = screenWidth * 0.15; // 滑动超过屏幕15%
      if (dx < -threshold && !_showCategoryPanel) {
        // 左滑显示分类菜单
        setState(() {
          _showCategoryPanel = true;
          _showControls = false;
        });
      } else if (dx > threshold && _showCategoryPanel) {
        // 右滑关闭分类菜单
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
      icon = _gestureValue > 0.5 ? Icons.volume_up : (_gestureValue > 0 ? Icons.volume_down : Icons.volume_off);
      label = '${(_gestureValue * 100).toInt()}%';
    } else if (_currentGestureType == 'brightness') {
      icon = _gestureValue > 0.5 ? Icons.brightness_high : Icons.brightness_low;
      label = '${(_gestureValue * 100).toInt()}%';
    } else if (_currentGestureType == 'channel') {
      // 频道切换指示
      if (_gestureValue < 0) {
        icon = Icons.keyboard_arrow_up;
        label = '下一频道';
      } else {
        icon = Icons.keyboard_arrow_down;
        label = '上一频道';
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
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  DateTime? _lastSelectKeyDownTime;

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    _showControlsTemporarily();

    final playerProvider = context.read<PlayerProvider>();
    final key = event.logicalKey;

    // Play/Pause & Favorite (Select/Enter)
    if (key == LogicalKeyboardKey.select || key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
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

    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Seek backward (Left) - 打开分类面板
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (_showCategoryPanel) {
        // 如果分类面板已显示且在频道列表，返回分类列表
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
      // 打开分类面板
      setState(() {
        _showCategoryPanel = true;
        _selectedCategory = null;
      });
      _showControlsTemporarily();
      return KeyEventResult.handled;
    }

    // Right key - 直播流不需要快进，禁用
    if (key == LogicalKeyboardKey.arrowRight) {
      if (_showCategoryPanel) {
        // 如果在分类面板，右键不做任何事
        return KeyEventResult.handled;
      }
      // 直播流禁用快进
      return KeyEventResult.handled;
    }

    // Previous/Next Channel (Up/Down)
    // If controls are shown, Up/Down might be needed for navigation too (e.g. Volume -> Play -> Settings row to Top Bar)?
    // Usually Up/Down in player (if simplistic) is Volume/Channel.
    // If we have a UI with Top Bar and Bottom Bar, Up from Bottom Bar should go to Top Bar?
    // Let's allow Up/Down to propagate IF focus is on a control?
    // But how do we know if focus is on a control?
    // _playerFocusNode is the parent. We don't know easily which child has focus here without checking FocusManager.
    // BUT user specifically complained about Left/Right.
    // User wants Up/Down to switch channels.
    // If I return ignored for UP/DOWN when controls shown, channel switching might stop working if a button is focused.
    // But if a button IS focused, Up/Down should probably navigate to other buttons?
    // Let's assume for now Up/Down ALWAYS switches Channel UNLESS we are in a vertical menu (Settings sheet handles its own).
    // The main player controls are a single Row (Left/Right).
    // The Top Bar is above.
    // If I press Up, should it go to Top Bar? Or switch Channel?
    // User asked "Up/Down switch channel".
    // I will keep Up/Down as Channel Switch for now, unless user explicitly requested navigation.
    // Wait, user complained "Navigate bar displays, Left/Right cannot seek (should move focus)".
    // They didn't complain about Up/Down. So I will ONLY modify Left/Right.

    // Previous Channel (Up)
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.channelUp) {
      _errorShown = false; // 切换频道时重置错误标记
      final channelProvider = context.read<ChannelProvider>();
      playerProvider.playPrevious(channelProvider.filteredChannels);
      // 保存上次播放的频道ID
      _saveLastChannelId(playerProvider.currentChannel);
      return KeyEventResult.handled;
    }

    // Next Channel (Down)
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.channelDown) {
      _errorShown = false; // 切换频道时重置错误标记
      final channelProvider = context.read<ChannelProvider>();
      playerProvider.playNext(channelProvider.filteredChannels);
      // 保存上次播放的频道ID
      _saveLastChannelId(playerProvider.currentChannel);
      return KeyEventResult.handled;
    }

    // Back/Exit
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
      // 迷你模式下先退出迷你模式
      if (WindowsPipChannel.isInPipMode) {
        WindowsPipChannel.exitPipMode();
        setState(() {});
        return KeyEventResult.handled;
      }
      playerProvider.stop();
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      return KeyEventResult.handled;
    }

    // Mute - 只在TV端处理
    if (key == LogicalKeyboardKey.keyM || (key == LogicalKeyboardKey.audioVolumeMute && !PlatformDetector.isMobile)) {
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
    if (key == LogicalKeyboardKey.settings || key == LogicalKeyboardKey.contextMenu) {
      _showSettingsSheet(context);
      return KeyEventResult.handled;
    }

    // Back (explicit handling for some remotes)
    if (key == LogicalKeyboardKey.backspace) {
      playerProvider.stop();
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _playerFocusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: MouseRegion(
          onHover: (_) => _showControlsTemporarily(),
          onExit: (_) {
            if (mounted) {
              _hideControlsTimer?.cancel();
              _hideControlsTimer = Timer(const Duration(seconds: 1), () {
                if (mounted) setState(() => _showControls = false);
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
            // 手机端手势控制 - 使用 Pan 手势统一处理
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

                // Controls Overlay - 迷你模式下使用简化版
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

                // Category Panel (Left side) - 迷你模式下不显示
                if (_showCategoryPanel && !WindowsPipChannel.isInPipMode) _buildCategoryPanel(),

                // 手势指示器 (手机端)
                if (_showGestureIndicator) _buildGestureIndicator(),

                // Loading Indicator - 使用本地状态
                if (_isLoading)
                  Center(
                    child: Transform.scale(
                      scale: WindowsPipChannel.isInPipMode ? 0.6 : 1.0,
                      child: const CircularProgressIndicator(
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),

                // Error Display - Handled via Listener now to show SnackBar
                // But we can keep a subtle indicator if needed, or remove it entirely
                // to prevent blocking. Let's remove the blocking widget.
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    return Consumer<PlayerProvider>(
      builder: (context, provider, _) {
        // Use ExoPlayer on Android phone
        if (provider.useExoPlayer) {
          final exoPlayer = provider.exoPlayer;
          // 确保 exoPlayer 存在
          if (exoPlayer == null) {
            return const SizedBox.expand();
          }

          // 使用 ValueListenableBuilder 监听 controller 变化
          return ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: exoPlayer,
            builder: (context, value, child) {
              if (!value.isInitialized) {
                return const SizedBox.expand();
              }

              return Center(
                child: AspectRatio(
                  aspectRatio: value.aspectRatio > 0 ? value.aspectRatio : 16 / 9,
                  child: VideoPlayer(exoPlayer),
                ),
              );
            },
          );
        }

        // Use media_kit on other platforms
        if (provider.videoController == null) {
          return const SizedBox.expand();
        }

        return Center(
          child: Video(
            controller: provider.videoController!,
            fill: Colors.black,
            controls: NoVideoControls,
          ),
        );
      },
    );
  }

  // 迷你模式下的简化控件
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
              Colors.black.withOpacity(0.5),
              Colors.transparent,
              Colors.black.withOpacity(0.5),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Column(
          children: [
            // 顶部：频道名 + 退出/恢复按钮
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: Consumer<PlayerProvider>(
                      builder: (context, provider, _) {
                        return Text(
                          provider.currentChannel?.name ?? widget.channelName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                  ),
                  // 恢复大小按钮
                  GestureDetector(
                    onTap: () async {
                      await WindowsPipChannel.exitPipMode();
                      setState(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.fullscreen, color: Colors.white, size: 16),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // 关闭按钮
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
                      child: const Icon(Icons.close, color: Colors.white, size: 16),
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
                      // 静音按钮
                      GestureDetector(
                        onTap: provider.toggleMute,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            provider.isMuted ? Icons.volume_off : Icons.volume_up,
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          // Semi-transparent channel logo/back button
          TVFocusable(
            onSelect: () {
              context.read<PlayerProvider>().stop();
              Navigator.of(context).pop();
            },
            focusScale: 1.0,
            showFocusBorder: false,
            builder: (context, isFocused, child) {
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isFocused ? AppTheme.primaryColor : const Color(0x33FFFFFF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isFocused ? AppTheme.focusBorderColor : const Color(0x1AFFFFFF),
                    width: isFocused ? 2 : 1,
                  ),
                ),
                child: child,
              );
            },
            child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
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
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: AppTheme.lotusGradient,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle, color: Colors.white, size: 6),
                                SizedBox(width: 4),
                                Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        // Video info
                        if (provider.videoInfo.isNotEmpty)
                          Text(
                            provider.videoInfo,
                            style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 11),
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
              final isFav = currentChannel != null && favorites.isFavorite(currentChannel.id ?? 0);

              return TVFocusable(
                onSelect: () {
                  if (currentChannel != null) favorites.toggleFavorite(currentChannel);
                },
                focusScale: 1.0,
                showFocusBorder: false,
                builder: (context, isFocused, child) {
                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: isFav ? AppTheme.lotusGradient : null,
                      color: isFav ? null : (isFocused ? AppTheme.primaryColor : const Color(0x33FFFFFF)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isFocused ? AppTheme.focusBorderColor : const Color(0x1AFFFFFF),
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

          // PiP 迷你播放器按钮 - 仅 Windows
          if (WindowsPipChannel.isSupported) ...[
            const SizedBox(width: 8),
            _buildPipButton(),
          ],

        ],
      ),
    );
  }

  // PiP 迷你播放器按钮
  Widget _buildPipButton() {
    return StatefulBuilder(
      builder: (context, setState) {
        final isInPip = WindowsPipChannel.isInPipMode;
        final isPinned = WindowsPipChannel.isPinned;
        
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // PiP 切换按钮
            TVFocusable(
              onSelect: () async {
                await WindowsPipChannel.togglePipMode();
                setState(() {});
              },
              focusScale: 1.0,
              showFocusBorder: false,
              builder: (context, isFocused, child) {
                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: isInPip ? AppTheme.lotusGradient : null,
                    color: isInPip ? null : (isFocused ? AppTheme.primaryColor : const Color(0x33FFFFFF)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isFocused ? AppTheme.focusBorderColor : const Color(0x1AFFFFFF),
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
            // 置顶按钮 - 仅在迷你模式下显示
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
                      gradient: isPinned ? AppTheme.lotusGradient : null,
                      color: isPinned ? null : (isFocused ? AppTheme.primaryColor : const Color(0x33FFFFFF)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isFocused ? AppTheme.focusBorderColor : const Color(0x1AFFFFFF),
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
                  final currentProgram = epgProvider.getCurrentProgram(channel?.epgId, channel?.name);
                  final nextProgram = epgProvider.getNextProgram(channel?.epgId, channel?.name);

                  if (currentProgram != null || nextProgram != null) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('正在播放', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      currentProgram.title,
                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '${currentProgram.remainingMinutes}分钟后结束',
                                    style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 11),
                                  ),
                                ],
                              ),
                            if (nextProgram != null) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0x66FFFFFF),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('即将播放', style: TextStyle(color: Colors.white, fontSize: 10)),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      nextProgram.title,
                                      style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12),
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

              // Control buttons row (moved above progress bar)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Volume control
                  _buildVolumeControl(provider),

                  const SizedBox(width: 16),

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
                          gradient: AppTheme.lotusGradient,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isFocused ? Colors.white : Colors.transparent,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withAlpha(isFocused ? 100 : 50),
                              blurRadius: isFocused ? 16 : 8,
                              spreadRadius: isFocused ? 2 : 1,
                            ),
                          ],
                        ),
                        child: child,
                      );
                    },
                    child: Icon(
                      provider.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),

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
                          color: isFocused ? AppTheme.primaryColor : const Color(0x33FFFFFF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isFocused ? AppTheme.focusBorderColor : const Color(0x1AFFFFFF),
                            width: isFocused ? 2 : 1,
                          ),
                        ),
                        child: child,
                      );
                    },
                    child: const Icon(Icons.settings_rounded, color: Colors.white, size: 18),
                  ),
                ],
              ),

              // Slim progress bar at bottom (if applicable)
              if (provider.duration.inSeconds > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                      activeTrackColor: AppTheme.primaryColor,
                      inactiveTrackColor: const Color(0x33FFFFFF),
                      thumbColor: AppTheme.primaryColor,
                    ),
                    child: Slider(
                      value: provider.position.inSeconds.toDouble(),
                      max: provider.duration.inSeconds.toDouble(),
                      onChanged: (value) => provider.seek(Duration(seconds: value.toInt())),
                    ),
                  ),
                ),

              // Keyboard hints
              if (PlatformDetector.useDPadNavigation)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    AppStrings.of(context)?.playerHintTV ?? '↑↓ Switch Channel · ← Categories · OK Play/Pause',
                    style: const TextStyle(color: Color(0x66FFFFFF), fontSize: 11),
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
                color: isFocused ? AppTheme.primaryColor : const Color(0x33FFFFFF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isFocused ? AppTheme.focusBorderColor : const Color(0x1AFFFFFF),
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
              onChanged: (value) => provider.setVolume(value),
              activeColor: AppTheme.primaryColor,
              inactiveColor: const Color(0x33FFFFFF),
            ),
          ),
        ),
      ],
    );
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
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
                    AppStrings.of(context)?.playbackSettings ?? 'Playback Settings',
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
                        selectedColor: AppTheme.primaryColor,
                        backgroundColor: AppTheme.cardColor,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppTheme.textSecondary,
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
          // 分类列表
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
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      '分类',
                      style: TextStyle(
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
                              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                gradient: (isFocused || isSelected) ? AppTheme.lotusGradient : null,
                                color: (isFocused || isSelected) ? null : Colors.transparent,
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
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${group.channelCount}',
                                style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 11),
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
          // 频道列表（当选中分类时显示）
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
                    child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 14),
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
                    autofocus: index == 0,
                    onSelect: () {
                      // 保存上次播放的频道ID
                      final settingsProvider = context.read<SettingsProvider>();
                      if (settingsProvider.rememberLastChannel && channel.id != null) {
                        settingsProvider.setLastChannelId(channel.id);
                      }

                      // 切换到该频道
                      playerProvider.playChannel(channel);
                      // 关闭面板
                      setState(() {
                        _showCategoryPanel = false;
                        _selectedCategory = null;
                      });
                    },
                    focusScale: 1.0,
                    showFocusBorder: false,
                    builder: (context, isFocused, child) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: isFocused ? AppTheme.lotusGradient : null,
                          color: isPlaying && !isFocused ? const Color(0x33E91E63) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: child,
                      );
                    },
                    child: Row(
                      children: [
                        if (isPlaying)
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Icon(Icons.play_arrow, color: AppTheme.primaryColor, size: 16),
                          ),
                        Expanded(
                          child: Text(
                            channel.name,
                            style: TextStyle(
                              color: isPlaying ? AppTheme.primaryColor : Colors.white,
                              fontSize: 13,
                              fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
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
