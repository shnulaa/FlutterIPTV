import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/channel_logo_widget.dart';
import '../../../core/widgets/auto_scroll_text.dart';
import '../../../core/platform/platform_detector.dart';
import '../../../core/platform/windows_pip_channel.dart';
import '../../../core/platform/windows_fullscreen_native.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/services/epg_service.dart';
import '../../../core/services/service_locator.dart';
import '../providers/multi_screen_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../epg/providers/epg_provider.dart';
import '../../channels/providers/channel_provider.dart';

class MultiScreenPlayer extends StatefulWidget {
  final VoidCallback? onExitMultiScreen;
  final VoidCallback? onBack;

  const MultiScreenPlayer({
    super.key,
    this.onExitMultiScreen,
    this.onBack,
  });

  @override
  State<MultiScreenPlayer> createState() => _MultiScreenPlayerState();
}

class _MultiScreenPlayerState extends State<MultiScreenPlayer> {
  bool _showControls = true;
  bool _showChannelSelector = false;
  int _targetScreenIndex = 0;
  String? _selectedCategory;
  Timer? _hideControlsTimer;
  bool _isWindowFullscreen = false;
  DateTime? _lastFullScreenToggle;
  int? _hoveredScreenIndex;

  @override
  void initState() {
    super.initState();
    _syncWindowFullscreenState();
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    super.dispose();
  }

  Future<void> _syncWindowFullscreenState() async {
    if (!mounted) return;
    if (PlatformDetector.isWindows) {
      setState(() => _isWindowFullscreen = WindowsFullscreenNative.isFullScreen());
      return;
    }
    if (PlatformDetector.isDesktop) {
      final isFullscreen = await windowManager.isFullScreen();
      if (!mounted) return;
      setState(() => _isWindowFullscreen = isFullscreen);
    }
  }

  void _toggleWindowFullscreen() {
    if (!PlatformDetector.isDesktop) return;
    if (PlatformDetector.isWindows) {
      final now = DateTime.now();
      if (_lastFullScreenToggle != null &&
          now.difference(_lastFullScreenToggle!).inMilliseconds < 200) {
        return;
      }
      _lastFullScreenToggle = now;

      final success = WindowsFullscreenNative.toggleFullScreen();
      if (success) {
        Future.microtask(() {
          if (mounted) {
            setState(() {
              _isWindowFullscreen = WindowsFullscreenNative.isFullScreen();
            });
          }
        });
      } else {
        ServiceLocator.log.d(
            'MultiScreenPlayer: Native fullscreen failed, falling back to window_manager');
        windowManager
            .isFullScreen()
            .then((value) => windowManager.setFullScreen(!value));
        Future.microtask(() {
          if (mounted) {
            windowManager.isFullScreen().then((value) {
              if (mounted) setState(() => _isWindowFullscreen = value);
            });
          }
        });
      }
      return;
    }

    windowManager
        .isFullScreen()
        .then((value) => windowManager.setFullScreen(!value));
    Future.microtask(() {
      if (mounted) {
        windowManager
            .isFullScreen()
            .then((value) => setState(() => _isWindowFullscreen = value));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MultiScreenProvider>(
      builder: (context, multiScreenProvider, _) {
        final isMiniMode = WindowsPipChannel.isInPipMode;

        return MouseRegion(
          cursor: (!isMiniMode && !_showControls)
              ? SystemMouseCursors.none
              : SystemMouseCursors.basic,
          onHover: (_) {
            if (!isMiniMode) _showControlsTemporarily();
          },
          onExit: (_) {
            if (mounted && !isMiniMode) {
              _hideControlsTimer?.cancel();
              _hideControlsTimer = Timer(const Duration(milliseconds: 300), () {
                if (mounted) setState(() => _showControls = false);
              });
            }
          },
          child: GestureDetector(
            // Mini模式下整个区域可拖动
            onPanStart:
                isMiniMode ? (_) => windowManager.startDragging() : null,
            onTap: () {
              if (_showChannelSelector) {
                setState(() => _showChannelSelector = false);
              } else if (!isMiniMode) {
                _showControlsTemporarily();
              }
            },
            child: Stack(
              children: [
                // 2x2 缃戞牸
                Container(
                  color: Colors.black,
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            _buildScreenCell(context, 0, multiScreenProvider),
                            _buildScreenCell(context, 1, multiScreenProvider),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            _buildScreenCell(context, 2, multiScreenProvider),
                            _buildScreenCell(context, 3, multiScreenProvider),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 椤堕儴鎺у埗鏍忥紙闈濵ini妯″紡锛?
                if (_showControls && !isMiniMode)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _buildTopControls(context),
                  ),


                // Mini妯″紡鎺у埗鎸夐挳锛堝彸涓婅锛屽缁堟樉绀猴級
                if (isMiniMode)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () async {
                            await WindowsPipChannel.exitPipMode();
                            setState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(Icons.fullscreen,
                                color: Colors.white, size: 14),
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () {
                            WindowsPipChannel.exitPipMode();
                            widget.onBack?.call();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 14),
                          ),
                        ),
                      ],
                    ),
                  ),

                // 棰戦亾閫夋嫨鍣?
                if (_showChannelSelector)
                  _buildChannelSelector(context, multiScreenProvider),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showControlsTemporarily() {
    _hideControlsTimer?.cancel();
    setState(() => _showControls = true);
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _showControls = false);
      }
    });
  }

  Widget _buildTopControls(BuildContext context) {
    return Container(
      // 璋冩暣椤堕儴闂磋窛鏈?30锛屼娇鎸夐挳涓嬬Щ锛屼笌鍙充笂瑙掍俊鎭獥鍙ｉ敊寮€骞堕綈骞?
      padding: const EdgeInsets.fromLTRB(16, 30, 16, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: widget.onBack ?? () => Navigator.of(context).pop(),
              tooltip: AppStrings.of(context)?.backToPlayer ?? 'Back',
            ),
            const Spacer(),
            IconButton(
              icon:
                  const Icon(Icons.picture_in_picture_alt, color: Colors.white),
              onPressed: () async {
                await WindowsPipChannel.enterPipMode();
                setState(() {});
              },
              tooltip: AppStrings.of(context)?.miniMode ?? 'Mini Mode',
            ),
            if (PlatformDetector.isWindows)
              IconButton(
                icon: Icon(
                  _isWindowFullscreen
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                  color: Colors.white,
                ),
                onPressed: _toggleWindowFullscreen,
                tooltip: _isWindowFullscreen ? '退出全屏' : '全屏',
              ),
            IconButton(
              icon: const Icon(Icons.grid_off_rounded, color: Colors.white),
              onPressed: widget.onExitMultiScreen,
              tooltip: AppStrings.of(context)?.exitMultiScreen ??
                  '退出分屏',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScreenControlsOverlay(
    BuildContext context,
    MultiScreenProvider multiScreenProvider,
    int index,
    ScreenPlayerState screen,
    SettingsProvider settings,
  ) {
    final channel = screen.channel;
    if (channel == null) return const SizedBox.shrink();

    final durationSeconds = screen.duration.inSeconds;
    final showProgress = settings.progressBarMode != 'never' &&
        ((settings.progressBarMode == 'always' && durationSeconds > 0) ||
            (settings.progressBarMode == 'auto' &&
                channel.isSeekable &&
                durationSeconds > 0 &&
                durationSeconds <= 86400));
    final maxDuration = durationSeconds > 0 ? durationSeconds.toDouble() : 1.0;
    final currentPosition =
        screen.position.inSeconds.toDouble().clamp(0.0, maxDuration).toDouble();

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.black.withOpacity(0.3),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showProgress) ...[
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 1.5,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 3),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 6),
                activeTrackColor: AppTheme.getPrimaryColor(context),
                inactiveTrackColor: const Color(0x33FFFFFF),
                thumbColor: Colors.white,
              ),
              child: Slider(
                value: currentPosition,
                max: maxDuration,
                onChanged: (value) {
                  multiScreenProvider.setActiveScreen(index);
                  multiScreenProvider
                      .seekActiveScreen(Duration(seconds: value.toInt()));
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(screen.position),
                    style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 8),
                  ),
                  Text(
                    _formatDuration(screen.duration),
                    style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 8),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 3),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 66,
                child: Row(
                  children: [
                    const Icon(Icons.volume_up_rounded,
                        color: Colors.white, size: 12),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 1.5,
                          thumbShape:
                              const RoundSliderThumbShape(enabledThumbRadius: 2.5),
                        ),
                        child: Slider(
                          value: multiScreenProvider.volume,
                          max: 1.0,
                          min: 0.0,
                          onChanged: (value) {
                            multiScreenProvider.setActiveScreen(index);
                            multiScreenProvider.setVolume(value);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                height: 24,
                width: 24,
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.14),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: () {
                    multiScreenProvider.setActiveScreen(index);
                    multiScreenProvider.togglePlayPauseOnActiveScreen();
                  },
                  child: Icon(
                    screen.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 14,
                  ),
                ),
              ),
              if (channel.hasMultipleSources) ...[
                const SizedBox(width: 4),
                SizedBox(
                  height: 24,
                  child: FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.14),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    onPressed: () {
                      multiScreenProvider.setActiveScreen(index);
                      multiScreenProvider.switchToNextSourceOnActiveScreen();
                    },
                    child: Text(
                      '${AppStrings.of(context)?.source ?? 'Source'} ${channel.currentSourceIndex + 1}/${channel.sourceCount}',
                      style: const TextStyle(fontSize: 9),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildScreenCell(BuildContext context, int index,
      MultiScreenProvider multiScreenProvider) {
    final screen = multiScreenProvider.getScreen(index);
    final isActive = multiScreenProvider.activeScreenIndex == index;
    final settingsProvider = context.watch<SettingsProvider>();
    final isMiniMode = WindowsPipChannel.isInPipMode;

    return Expanded(
      child: MouseRegion(
        onEnter: (_) {
          if (!isMiniMode) {
            setState(() {
              _hoveredScreenIndex = index;
              _showControls = true;
            });
            _showControlsTemporarily();
          }
        },
        onHover: (_) {
          if (!isMiniMode && _hoveredScreenIndex != index) {
            setState(() => _hoveredScreenIndex = index);
          }
        },
        onExit: (_) {
          if (!isMiniMode && _hoveredScreenIndex == index) {
            setState(() => _hoveredScreenIndex = null);
          }
        },
        child: GestureDetector(
          onTap: () {
            multiScreenProvider.setActiveScreen(index);
            if (screen.channel == null && !isMiniMode) {
              setState(() {
                _targetScreenIndex = index;
                _showChannelSelector = true;
              });
            }
          },
          onDoubleTap: () {
            if (screen.channel != null) {
              multiScreenProvider.clearScreen(index);
            }
          },
          child: Container(
            margin: EdgeInsets.all(isMiniMode ? 1 : 2),
            decoration: BoxDecoration(
              border: Border.all(
                color: isActive
                    ? AppTheme.getPrimaryColor(context)
                    : Colors.grey.withOpacity(0.3),
                width: isActive ? (isMiniMode ? 2 : 3) : 1,
              ),
            ),
            child: Stack(
              children: [
                if (screen.channel != null && screen.videoController != null)
                  Video(
                    controller: screen.videoController!,
                    fill: Colors.black,
                    controls: NoVideoControls,
                  )
                else if (screen.channel != null)
                  _buildLoadingPlaceholder(screen)
                else
                  _buildEmptyScreenPlaceholder(context, index, isMiniMode),

                if (!isMiniMode) ...[
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppTheme.getPrimaryColor(context)
                            : Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (screen.channel != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child:
                          _buildInfoOverlay(context, screen, settingsProvider),
                    ),
                  if (screen.channel != null)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: _buildBottomInfo(context, screen),
                    ),
                  if (_showControls &&
                      _hoveredScreenIndex == index &&
                      screen.channel != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: settingsProvider.showMultiScreenChannelName
                          ? 30
                          : 0,
                      child: _buildScreenControlsOverlay(
                        context,
                        multiScreenProvider,
                        index,
                        screen,
                        settingsProvider,
                      ),
                    ),
                ],

                if (screen.isLoading)
                  Center(
                    child: SizedBox(
                      width: isMiniMode ? 16 : 32,
                      height: isMiniMode ? 16 : 32,
                      child: CircularProgressIndicator(
                        color: AppTheme.getPrimaryColor(context),
                        strokeWidth: 2,
                      ),
                    ),
                  ),

                if (screen.error != null)
                  Center(
                    child: Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: isMiniMode ? 16 : 32,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildChannelSelector(
      BuildContext context, MultiScreenProvider multiScreenProvider) {
    final channelProvider = context.watch<ChannelProvider>();

    return Container(
      color: Colors.black.withOpacity(0.95),
      child: Row(
        children: [
          // 宸︿晶鍒嗙被鍒楄〃
          Container(
            width: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: Theme.of(context).brightness == Brightness.dark
                    ? [
                        AppTheme.getBackgroundColor(context),
                        AppTheme.getPrimaryColor(context).withOpacity(0.15),
                        AppTheme.getBackgroundColor(context),
                      ]
                    : [
                        AppTheme.getBackgroundColor(context),
                        AppTheme.getBackgroundColor(context).withOpacity(0.9),
                        AppTheme.getPrimaryColor(context).withOpacity(0.08),
                      ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 鏍囬鏍?
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: AppTheme.getCardColor(context),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () =>
                            setState(() => _showChannelSelector = false),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.getCardColor(context),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.close,
                            color: AppTheme.getTextPrimary(context),
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          (AppStrings.of(context)?.screenNumber ??
                                  'Screen {number}')
                              .replaceAll(
                                  '{number}', '${_targetScreenIndex + 1}'),
                          style: TextStyle(
                            color: AppTheme.getTextPrimary(context),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 鍏ㄩ儴棰戦亾閫夐」
                _buildCategoryItem(
                  context,
                  name: AppStrings.of(context)?.allChannels ?? 'All Channels',
                  count: channelProvider.totalChannelCount,
                  isSelected: _selectedCategory == null,
                  onTap: () => setState(() => _selectedCategory = null),
                ),
                Divider(color: AppTheme.getCardColor(context), height: 1),
                // 鍒嗙被鍒楄〃
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: channelProvider.groups.length,
                    itemBuilder: (context, index) {
                      final group = channelProvider.groups[index];
                      return _buildCategoryItem(
                        context,
                        name: group.name,
                        count: group.channelCount,
                        isSelected: _selectedCategory == group.name,
                        onTap: () =>
                            setState(() => _selectedCategory = group.name),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // 鍙充晶棰戦亾缃戞牸
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: Theme.of(context).brightness == Brightness.dark
                      ? [
                          AppTheme.getBackgroundColor(context),
                          AppTheme.getPrimaryColor(context).withOpacity(0.15),
                          AppTheme.getBackgroundColor(context),
                        ]
                      : [
                          AppTheme.getBackgroundColor(context),
                          AppTheme.getBackgroundColor(context).withOpacity(0.9),
                          AppTheme.getPrimaryColor(context).withOpacity(0.08),
                        ],
                ),
              ),
              child: _buildChannelGrid(
                  context, channelProvider, multiScreenProvider),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(
    BuildContext context, {
    required String name,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.getPrimaryColor(context).withOpacity(0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? AppTheme.getPrimaryColor(context).withOpacity(0.5)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.getPrimaryColor(context)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      color: isSelected
                          ? AppTheme.getPrimaryColor(context)
                          : AppTheme.getTextPrimary(context),
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.getPrimaryColor(context).withOpacity(0.2)
                        : AppTheme.getCardColor(context),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      color: isSelected
                          ? AppTheme.getPrimaryColor(context)
                          : AppTheme.getTextMuted(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChannelGrid(
      BuildContext context,
      ChannelProvider channelProvider,
      MultiScreenProvider multiScreenProvider) {
    // 鉁?浣跨敤 allChannels 鑾峰彇鍏ㄩ儴棰戦亾锛岃€屼笉鏄垎椤电殑 channels
    List channels;
    if (_selectedCategory == null) {
      channels = channelProvider.allChannels;
    } else {
      channels = channelProvider.allChannels
          .where((c) => c.groupName == _selectedCategory)
          .toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 椤堕儴鏍囬
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                _selectedCategory ??
                    (AppStrings.of(context)?.allChannels ?? 'All Channels'),
                style: TextStyle(
                  color: AppTheme.getTextPrimary(context),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.getSurfaceColor(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${channels.length} ${AppStrings.of(context)?.channels ?? 'channels'}',
                  style: TextStyle(
                    color: AppTheme.getTextSecondary(context),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        // 棰戦亾缃戞牸
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 160,
              childAspectRatio: 1.1,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: channels.length,
            itemBuilder: (context, index) {
              final channel = channels[index];
              return _buildChannelCard(context, channel, multiScreenProvider);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChannelCard(BuildContext context, dynamic channel,
      MultiScreenProvider multiScreenProvider) {
    final forceAutoScroll = PlatformDetector.isWindows || PlatformDetector.isTV;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          multiScreenProvider.playChannelOnScreen(_targetScreenIndex, channel);
          setState(() => _showChannelSelector = false);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.getCardColor(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.getGlassBorderColor(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo鍖哄煙 - 鍥哄畾楂樺害
              Expanded(
                flex: 3,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  child: Container(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF0A0A0A)
                        : const Color(0xFFB8B8B8),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: ChannelLogoWidget(
                          channel: channel,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // 棰戦亾鍚嶅尯鍩?
              Expanded(
                flex: 1,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Center(
                    child: AutoScrollText(
                      text: channel.name,
                      style: TextStyle(
                        color: AppTheme.getTextPrimary(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      scrollSpeed: 30.0,
                      scrollDelay: const Duration(milliseconds: 500),
                      textAlign: TextAlign.center,
                      forceScroll: forceAutoScroll,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoOverlay(BuildContext context, ScreenPlayerState screen,
      SettingsProvider settings) {
    final showAny = settings.showClock || settings.showVideoInfo;
    if (!showAny) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (settings.showClock)
            StreamBuilder(
              stream: Stream.periodic(const Duration(seconds: 1)),
              builder: (context, snapshot) {
                return _buildInfoChip(_getCurrentTime(), Colors.blue);
              },
            ),
          if (settings.showVideoInfo &&
              screen.videoWidth > 0 &&
              screen.videoHeight > 0)
            _buildInfoChip(
                '${screen.videoWidth}x${screen.videoHeight}', Colors.purple),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.3),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: const TextStyle(
            color: Colors.white, fontSize: 9, fontWeight: FontWeight.w500),
      ),
    );
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildBottomInfo(BuildContext context, ScreenPlayerState screen) {
    final settingsProvider = context.watch<SettingsProvider>();
    final forceAutoScroll = PlatformDetector.isWindows || PlatformDetector.isTV;
    final nameWidth = (PlatformDetector.isWindows || PlatformDetector.isTV)
        ? 110.0
        : 60.0;

    // 如果配置为不显示频道名称，则返回空数组
    if (!settingsProvider.showMultiScreenChannelName) {
      return const SizedBox.shrink();
    }

    // 鉁?浣跨敤 select 鍙洃鍚綋鍓嶅睆骞曢閬撶殑 EPG 鏁版嵁
    final currentProgram = screen.channel != null
        ? context.select<EpgProvider, EpgProgram?>(
            (provider) => provider.getCurrentProgram(
              screen.channel!.epgId, 
              screen.channel!.name,
            ),
          )
        : null;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.8), Colors.transparent],
        ),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: nameWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AutoScrollText(
                key: ValueKey('ch_${screen.channel?.id}'),
                text: screen.channel?.name ?? '',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
                scrollSpeed: 30.0,
                scrollDelay: const Duration(milliseconds: 1000),
                textAlign: TextAlign.left,
                forceScroll: forceAutoScroll,
              ),
              if (currentProgram != null) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.play_circle_filled,
                        color: AppTheme.getPrimaryColor(context), size: 10),
                    const SizedBox(width: 4),
                    Expanded(
                      child: AutoScrollText(
                        key: ValueKey('pg_${currentProgram.title}'),
                        text: currentProgram.title,
                        style: TextStyle(
                            color: AppTheme.getPrimaryColor(context),
                            fontSize: 10),
                        scrollSpeed: 30.0,
                        scrollDelay: const Duration(milliseconds: 1000),
                        textAlign: TextAlign.left,
                        forceScroll: forceAutoScroll,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingPlaceholder(ScreenPlayerState screen) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.getPrimaryColor(context)),
            const SizedBox(height: 8),
            Text(
              screen.channel?.name ??
                  (AppStrings.of(context)?.loading ?? 'Loading...'),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyScreenPlaceholder(
      BuildContext context, int index, bool isMiniMode) {
    if (isMiniMode) {
      return Container(color: Colors.grey[900]);
    }

    return Container(
      color: Colors.grey[900],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, size: 36, color: Colors.grey[600]),
            const SizedBox(height: 8),
            Text(
                (AppStrings.of(context)?.screenNumber ?? 'Screen {number}')
                    .replaceAll('{number}', '${index + 1}'),
                style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            Text(
                AppStrings.of(context)?.clickToAddChannel ??
                    'Click to add channel',
                style: TextStyle(color: Colors.grey[700], fontSize: 10)),
          ],
        ),
      ),
    );
  }
}


