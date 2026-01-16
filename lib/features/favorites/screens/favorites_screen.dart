import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../../core/widgets/tv_sidebar.dart';
import '../../../core/platform/platform_detector.dart';
import '../../../core/i18n/app_strings.dart';
import '../providers/favorites_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../channels/providers/channel_provider.dart';
import '../../multi_screen/providers/multi_screen_provider.dart';
import '../../../core/platform/native_player_channel.dart';

class FavoritesScreen extends StatefulWidget {
  final bool embedded;
  
  const FavoritesScreen({super.key, this.embedded = false});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    context.read<FavoritesProvider>().loadFavorites();
  }

  void _playChannel(dynamic channel) {
    final settingsProvider = context.read<SettingsProvider>();
    
    // 保存上次播放的频道ID
    if (settingsProvider.rememberLastChannel && channel.id != null) {
      settingsProvider.setLastChannelId(channel.id);
    }

    // 检查是否启用了分屏模式
    if (settingsProvider.enableMultiScreen) {
      // TV 端使用原生分屏播放器
      if (PlatformDetector.isTV && PlatformDetector.isAndroid) {
        final channelProvider = context.read<ChannelProvider>();
        final channels = channelProvider.channels;
        
        // 找到当前点击频道的索引
        final clickedIndex = channels.indexWhere((c) => c.url == channel.url);
        
        // 准备频道数据
        final urls = channels.map((c) => c.url).toList();
        final names = channels.map((c) => c.name).toList();
        final groups = channels.map((c) => c.groupName ?? '').toList();
        final sources = channels.map((c) => c.sources).toList();
        final logos = channels.map((c) => c.logoUrl ?? '').toList();
        
        // 启动原生分屏播放器
        NativePlayerChannel.launchMultiScreen(
          urls: urls,
          names: names,
          groups: groups,
          sources: sources,
          logos: logos,
          initialChannelIndex: clickedIndex >= 0 ? clickedIndex : 0,
          volumeBoostDb: settingsProvider.volumeBoost,
          defaultScreenPosition: settingsProvider.defaultScreenPosition,
          onClosed: () {
            debugPrint('FavoritesScreen: Native multi-screen closed');
          },
        );
      } else if (PlatformDetector.isDesktop) {
        final multiScreenProvider = context.read<MultiScreenProvider>();
        final defaultPosition = settingsProvider.defaultScreenPosition;
        // 设置音量增强到分屏Provider
        multiScreenProvider.setVolumeSettings(1.0, settingsProvider.volumeBoost);
        multiScreenProvider.playChannelAtDefaultPosition(channel, defaultPosition);
        
        Navigator.pushNamed(context, AppRouter.player, arguments: {
          'channelUrl': '',
          'channelName': '',
          'channelLogo': null,
        });
      } else {
        Navigator.pushNamed(context, AppRouter.player, arguments: {
          'channelUrl': channel.url,
          'channelName': channel.name,
          'channelLogo': channel.logoUrl,
        });
      }
    } else {
      Navigator.pushNamed(context, AppRouter.player, arguments: {
        'channelUrl': channel.url,
        'channelName': channel.name,
        'channelLogo': channel.logoUrl,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTV = PlatformDetector.isTV || size.width > 1200;

    final content = _buildContent(context);

    if (isTV) {
      return Scaffold(
        backgroundColor: AppTheme.getBackgroundColor(context),
        body: TVSidebar(
          selectedIndex: 2, // 收藏页
          child: content,
        ),
      );
    }

    // 嵌入模式不使用Scaffold
    if (widget.embedded) {
      return Column(
        children: [
          // 简化的标题栏
          SafeArea(
            bottom: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Text(
                    AppStrings.of(context)?.favorites ?? 'Favorites',
                    style: TextStyle(
                      color: AppTheme.getTextPrimary(context),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Consumer<FavoritesProvider>(
                    builder: (context, provider, _) {
                      if (provider.favorites.isEmpty) return const SizedBox.shrink();
                      return IconButton(
                        icon: Icon(Icons.delete_sweep_rounded, color: AppTheme.getTextSecondary(context)),
                        onPressed: () => _confirmClearAll(context, provider),
                        tooltip: AppStrings.of(context)?.clearAll ?? 'Clear All',
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: content),
        ],
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: AppTheme.getBackgroundColor(context),
        title: Text(
          AppStrings.of(context)?.favorites ?? 'Favorites',
          style: TextStyle(
            color: AppTheme.getTextPrimary(context),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Consumer<FavoritesProvider>(
            builder: (context, provider, _) {
              if (provider.favorites.isEmpty) return const SizedBox.shrink();

              return IconButton(
                icon: const Icon(Icons.delete_sweep_rounded),
                onPressed: () => _confirmClearAll(context, provider),
                tooltip: AppStrings.of(context)?.clearAll ?? 'Clear All',
              );
            },
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildContent(BuildContext context) {
    return Consumer<FavoritesProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor),
          );
        }

        if (provider.favorites.isEmpty) {
          return _buildEmptyState();
        }

        return _buildFavoritesList(provider);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppTheme.getSurfaceColor(context),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Icon(
              Icons.favorite_outline_rounded,
              size: 50,
              color: AppTheme.getTextMuted(context).withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            AppStrings.of(context)?.noFavoritesYet ?? 'No Favorites Yet',
            style: TextStyle(
              color: AppTheme.getTextPrimary(context),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.of(context)?.favoritesHint ?? 'Long press on a channel to add it to favorites',
            style: TextStyle(
              color: AppTheme.getTextSecondary(context),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),
          TVFocusable(
            autofocus: true,
            onSelect: () => Navigator.pushNamed(context, AppRouter.channels),
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRouter.channels),
              icon: const Icon(Icons.live_tv_rounded),
              label: Text(AppStrings.of(context)?.browseChannels ?? 'Browse Channels'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesList(FavoritesProvider provider) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(20),
      buildDefaultDragHandles: false,
      itemCount: provider.favorites.length,
      onReorder: (oldIndex, newIndex) {
        provider.reorderFavorites(oldIndex, newIndex);
      },
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return Material(
              elevation: 8,
              color: Colors.transparent,
              shadowColor: AppTheme.primaryColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              child: child,
            );
          },
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final channel = provider.favorites[index];

        return ReorderableDragStartListener(
          key: ValueKey(channel.id),
          index: index,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildFavoriteCard(provider, channel, index),
          ),
        );
      },
    );
  }

  Widget _buildFavoriteCard(FavoritesProvider provider, dynamic channel, int index) {
    return TVFocusable(
      autofocus: index == 0,
      onSelect: () => _playChannel(channel),
      focusScale: 1.02,
      showFocusBorder: false,
      builder: (context, isFocused, child) {
        return AnimatedContainer(
          duration: AppTheme.animationFast,
          decoration: BoxDecoration(
            color: AppTheme.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isFocused ? AppTheme.focusBorderColor : Colors.transparent,
              width: isFocused ? 2 : 0,
            ),
            boxShadow: isFocused
                ? [
                    BoxShadow(
                      color: AppTheme.focusColor.withOpacity(0.2),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: child,
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Drag Handle
            ReorderableDragStartListener(
              index: index,
              child: Container(
                padding: const EdgeInsets.all(8),
                child: const Icon(
                  Icons.drag_indicator_rounded,
                  color: AppTheme.textMuted,
                  size: 20,
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Channel Logo
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppTheme.getCardColor(context),
                borderRadius: BorderRadius.circular(12),
                image: channel.logoUrl != null
                    ? DecorationImage(
                        image: NetworkImage(channel.logoUrl!),
                        fit: BoxFit.contain,
                      )
                    : null,
              ),
              child: channel.logoUrl == null
                  ? Icon(
                      Icons.live_tv_rounded,
                      color: AppTheme.getTextMuted(context),
                      size: 28,
                    )
                  : null,
            ),

            const SizedBox(width: 16),

            // Channel Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel.name,
                    style: TextStyle(
                      color: AppTheme.getTextPrimary(context),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (channel.groupName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      channel.groupName!,
                      style: TextStyle(
                        color: AppTheme.getTextSecondary(context),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Actions
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Play Button
                TVFocusable(
                  onSelect: () => _playChannel(channel),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Remove Button
                TVFocusable(
                  onSelect: () async {
                    await provider.removeFavorite(channel.id!);

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text((AppStrings.of(context)?.removedFromFavorites ?? 'Removed "{name}" from favorites').replaceAll('{name}', channel.name)),
                          action: SnackBarAction(
                            label: AppStrings.of(context)?.undo ?? 'Undo',
                            onPressed: () => provider.addFavorite(channel),
                          ),
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.favorite,
                      color: AppTheme.accentColor,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmClearAll(BuildContext context, FavoritesProvider provider) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.getSurfaceColor(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            AppStrings.of(context)?.clearAllFavorites ?? 'Clear All Favorites',
            style: TextStyle(color: AppTheme.getTextPrimary(context)),
          ),
          content: Text(
            AppStrings.of(context)?.clearFavoritesConfirm ?? 'Are you sure you want to remove all channels from your favorites?',
            style: TextStyle(color: AppTheme.getTextSecondary(context)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppStrings.of(context)?.cancel ?? 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await provider.clearFavorites();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppStrings.of(context)?.allFavoritesCleared ?? 'All favorites cleared'),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
              ),
              child: Text(AppStrings.of(context)?.clearAll ?? 'Clear All'),
            ),
          ],
        );
      },
    );
  }
}
