import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'dart:async';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../../core/platform/platform_detector.dart';
import '../providers/player_provider.dart';
import '../../favorites/providers/favorites_provider.dart';

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

class _PlayerScreenState extends State<PlayerScreen> {
  Timer? _hideControlsTimer;
  bool _showControls = true;
  final FocusNode _playerFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _startPlayback();
    _startHideControlsTimer();

    // Hide system UI for immersive experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _startPlayback() {
    final playerProvider = context.read<PlayerProvider>();
    playerProvider.playUrl(widget.channelUrl, name: widget.channelName);
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
    _hideControlsTimer?.cancel();
    _playerFocusNode.dispose();

    // Stop playback when leaving the screen
    try {
      context.read<PlayerProvider>().stop();
    } catch (_) {}

    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    _showControlsTemporarily();

    final playerProvider = context.read<PlayerProvider>();
    final key = event.logicalKey;

    // Play/Pause
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space) {
      playerProvider.togglePlayPause();
      return KeyEventResult.handled;
    }

    // Seek backward
    if (key == LogicalKeyboardKey.arrowLeft) {
      playerProvider.seekBackward(10);
      return KeyEventResult.handled;
    }

    // Seek forward
    if (key == LogicalKeyboardKey.arrowRight) {
      playerProvider.seekForward(10);
      return KeyEventResult.handled;
    }

    // Volume up
    if (key == LogicalKeyboardKey.arrowUp) {
      playerProvider.setVolume(playerProvider.volume + 0.1);
      return KeyEventResult.handled;
    }

    // Volume down
    if (key == LogicalKeyboardKey.arrowDown) {
      playerProvider.setVolume(playerProvider.volume - 0.1);
      return KeyEventResult.handled;
    }

    // Back/Exit
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
      playerProvider.stop();
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }

    // Mute
    if (key == LogicalKeyboardKey.keyM) {
      playerProvider.toggleMute();
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
            onTap: _showControlsTemporarily,
            onDoubleTap: () {
              context.read<PlayerProvider>().togglePlayPause();
            },
            child: Stack(
              children: [
                // Video Player
                _buildVideoPlayer(),

                // Controls Overlay
                AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: IgnorePointer(
                    ignoring: !_showControls,
                    child: _buildControlsOverlay(),
                  ),
                ),

                // Loading Indicator
                Consumer<PlayerProvider>(
                  builder: (context, provider, _) {
                    if (provider.isLoading) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryColor,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

                // Error Display
                Consumer<PlayerProvider>(
                  builder: (context, provider, _) {
                    if (provider.hasError) {
                      return _buildErrorDisplay(
                          provider.error ?? 'Unknown error');
                    }
                    return const SizedBox.shrink();
                  },
                ),
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
        if (provider.videoController == null) {
          return const SizedBox.expand();
        }

        return Center(
          child: Video(
            controller: provider.videoController!,
            fill: Colors.black,
          ),
        );
      },
    );
  }

  Widget _buildControlsOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withOpacity(0.8),
          ],
          stops: const [0.0, 0.2, 0.7, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Bar
            _buildTopBar(),

            const Spacer(),

            // Bottom Controls
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Back Button
          TVFocusable(
            onSelect: () {
              context.read<PlayerProvider>().stop();
              Navigator.of(context).pop();
            },
            focusScale: 1.1,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Channel Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.channelName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Consumer<PlayerProvider>(
                  builder: (context, provider, _) {
                    String statusText = 'Loading...';
                    Color statusColor = AppTheme.warningColor;

                    switch (provider.state) {
                      case PlayerState.playing:
                        statusText = 'LIVE';
                        statusColor = AppTheme.successColor;
                        break;
                      case PlayerState.buffering:
                        statusText = 'Buffering...';
                        statusColor = AppTheme.warningColor;
                        break;
                      case PlayerState.paused:
                        statusText = 'Paused';
                        statusColor = AppTheme.textMuted;
                        break;
                      case PlayerState.error:
                        statusText = 'Error';
                        statusColor = AppTheme.errorColor;
                        break;
                      default:
                        break;
                    }

                    return Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // Favorite Button
          Consumer<FavoritesProvider>(
            builder: (context, favorites, _) {
              final playerProvider = context.read<PlayerProvider>();
              final currentChannel = playerProvider.currentChannel;
              final isFav = currentChannel != null &&
                  favorites.isFavorite(currentChannel.id ?? 0);

              return TVFocusable(
                onSelect: () {
                  if (currentChannel != null) {
                    favorites.toggleFavorite(currentChannel);
                  }
                },
                focusScale: 1.1,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isFav
                        ? AppTheme.accentColor
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isFav ? Icons.favorite : Icons.favorite_border_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Consumer<PlayerProvider>(
      builder: (context, provider, _) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Volume and Settings
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Volume Control
                  _buildVolumeControl(provider),

                  const SizedBox(width: 32),

                  // Play/Pause Button
                  TVFocusable(
                    autofocus: true,
                    onSelect: provider.togglePlayPause,
                    focusScale: 1.15,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        provider.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),

                  const SizedBox(width: 32),

                  // Fullscreen
                  TVFocusable(
                    onSelect: provider.toggleFullscreen,
                    focusScale: 1.1,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        provider.isFullscreen
                            ? Icons.fullscreen_exit_rounded
                            : Icons.fullscreen_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Settings
                  TVFocusable(
                    onSelect: () => _showSettingsSheet(context),
                    focusScale: 1.1,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.settings_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Keyboard Shortcuts Hint (for TV/Desktop)
              if (PlatformDetector.useDPadNavigation)
                Text(
                  'Left/Right: Seek • Up/Down: Volume • Enter: Play/Pause • M: Mute',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVolumeControl(PlayerProvider provider) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TVFocusable(
          onSelect: provider.toggleMute,
          focusScale: 1.1,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              provider.isMuted || provider.volume == 0
                  ? Icons.volume_off_rounded
                  : provider.volume < 0.5
                      ? Icons.volume_down_rounded
                      : Icons.volume_up_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 100,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              value: provider.isMuted ? 0 : provider.volume,
              onChanged: (value) => provider.setVolume(value),
              activeColor: AppTheme.primaryColor,
              inactiveColor: Colors.white.withOpacity(0.3),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorDisplay(String error) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppTheme.errorColor,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Playback Error',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TVFocusable(
                  onSelect: _startPlayback,
                  child: ElevatedButton.icon(
                    onPressed: _startPlayback,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ),
                const SizedBox(width: 16),
                TVFocusable(
                  onSelect: () => Navigator.of(context).pop(),
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Go Back'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
                  const Text(
                    'Playback Settings',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Playback Speed
                  const Text(
                    'Playback Speed',
                    style: TextStyle(
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
}
