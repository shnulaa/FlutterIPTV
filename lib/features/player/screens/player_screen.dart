import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';

import '../../../core/i18n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../../core/platform/platform_detector.dart';
import '../../../core/platform/native_player_channel.dart';
import '../providers/player_provider.dart';
import '../../favorites/providers/favorites_provider.dart';
import '../../channels/providers/channel_provider.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAndLaunchPlayer();
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
        
        // Get channel list for native player
        final channelProvider = context.read<ChannelProvider>();
        final channels = channelProvider.filteredChannels;
        
        // Find current channel index
        int currentIndex = 0;
        for (int i = 0; i < channels.length; i++) {
          if (channels[i].url == widget.channelUrl) {
            currentIndex = i;
            break;
          }
        }
        
        // Prepare channel lists
        final urls = channels.map((c) => c.url).toList();
        final names = channels.map((c) => c.name).toList();
        
        debugPrint('PlayerScreen: Launching native player for ${widget.channelName} (index $currentIndex of ${channels.length})');
        
        // Launch native player with channel list and callback for when it closes
        final launched = await NativePlayerChannel.launchPlayer(
          url: widget.channelUrl,
          name: widget.channelName,
          index: currentIndex,
          urls: urls,
          names: names,
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

    // Listen for errors
    final playerProvider = context.read<PlayerProvider>();
    playerProvider.addListener(_onError);
  }

  void _onError() {
    if (!mounted) return;
    final provider = context.read<PlayerProvider>();
    if (provider.hasError && provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${AppStrings.of(context)?.playbackError ?? "Error"}: ${provider.error}'),
          backgroundColor: AppTheme.errorColor,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: AppStrings.of(context)?.retry ?? 'Retry',
            textColor: Colors.white,
            onPressed: _startPlayback,
          ),
        ),
      );
    }
  }

  void _startPlayback() {
    final playerProvider = context.read<PlayerProvider>();
    final channelProvider = context.read<ChannelProvider>();

    try {
      // Try to find the matching channel to enable playlist navigation
      final channel = channelProvider.channels.firstWhere(
        (c) => c.url == widget.channelUrl,
      );
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
    WidgetsBinding.instance.removeObserver(this);
    _hideControlsTimer?.cancel();
    _playerFocusNode.dispose();

    // Only stop playback if we're using Flutter player (not native)
    if (!_usingNativePlayer) {
      try {
        context.read<PlayerProvider>().stop();
      } catch (_) {}

      try {
        context.read<PlayerProvider>().removeListener(_onError);
      } catch (_) {}
    }

    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    super.dispose();
  }

  DateTime? _lastSelectKeyDownTime;

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

    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Seek backward (Left)
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (_showControls) {
        // If controls are visible, let the focus system handle navigation
        return KeyEventResult.ignored;
      }
      playerProvider.seekBackward(10);
      return KeyEventResult.handled;
    }

    // Seek forward (Right)
    if (key == LogicalKeyboardKey.arrowRight) {
      if (_showControls) {
        // If controls are visible, let the focus system handle navigation
        return KeyEventResult.ignored;
      }
      playerProvider.seekForward(10);
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
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.channelUp) {
      final channelProvider = context.read<ChannelProvider>();
      playerProvider.playPrevious(channelProvider.filteredChannels);
      return KeyEventResult.handled;
    }

    // Next Channel (Down)
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.channelDown) {
      final channelProvider = context.read<ChannelProvider>();
      playerProvider.playNext(channelProvider.filteredChannels);
      return KeyEventResult.handled;
    }

    // Back/Exit
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
      playerProvider.stop();
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      return KeyEventResult.handled;
    }

    // Mute
    if (key == LogicalKeyboardKey.keyM ||
        key == LogicalKeyboardKey.audioVolumeMute) {
      playerProvider.toggleMute();
      return KeyEventResult.handled;
    }

    // Explicit Volume Keys (for remotes with dedicated buttons)
    if (key == LogicalKeyboardKey.audioVolumeUp) {
      playerProvider.setVolume(playerProvider.volume + 0.1);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.audioVolumeDown) {
      playerProvider.setVolume(playerProvider.volume - 0.1);
      return KeyEventResult.handled;
    }

    // Settings / Menu
    if (key == LogicalKeyboardKey.settings ||
        key == LogicalKeyboardKey.contextMenu) {
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
        // Use ExoPlayer on Android TV
        if (provider.useExoPlayer) {
          if (provider.exoPlayer == null || !provider.exoPlayer!.value.isInitialized) {
            return const SizedBox.expand();
          }
          return Center(
            child: AspectRatio(
              aspectRatio: provider.exoPlayer!.value.aspectRatio,
              child: VideoPlayer(provider.exoPlayer!),
            ),
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
                Consumer<PlayerProvider>(
                  builder: (context, provider, _) {
                    return Text(
                      provider.currentChannel?.name ?? widget.channelName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
                Consumer<PlayerProvider>(
                  builder: (context, provider, _) {
                    String statusText = 'Loading...';
                    Color statusColor = AppTheme.warningColor;

                    switch (provider.state) {
                      case PlayerState.playing:
                        statusText = AppStrings.of(context)?.live ?? 'LIVE';
                        statusColor = AppTheme.successColor;
                        break;
                      case PlayerState.buffering:
                        statusText =
                            AppStrings.of(context)?.buffering ?? 'Buffering...';
                        statusColor = AppTheme.warningColor;
                        break;
                      case PlayerState.paused:
                        statusText = AppStrings.of(context)?.paused ?? 'Paused';
                        statusColor = AppTheme.textMuted;
                        break;
                      case PlayerState.error:
                        statusText = AppStrings.of(context)?.error ?? 'Error';
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
                // Video Info
                Consumer<PlayerProvider>(
                  builder: (context, provider, _) {
                    if (provider.videoInfo.isEmpty)
                      return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        provider.videoInfo,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.5), fontSize: 10),
                      ),
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

                  // Fullscreen button removed as per request
                  /*
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
                  */

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
                  AppStrings.of(context)?.shortcutsHint ??
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
            Text(
              AppStrings.of(context)?.playbackError ?? 'Playback Error',
              style: const TextStyle(
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
                    label: Text(AppStrings.of(context)?.retry ?? 'Retry'),
                  ),
                ),
                const SizedBox(width: 16),
                TVFocusable(
                  onSelect: () => Navigator.of(context).pop(),
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(AppStrings.of(context)?.goBack ?? 'Go Back'),
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
