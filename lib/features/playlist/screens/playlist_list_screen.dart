import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../../core/widgets/tv_sidebar.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/platform/platform_detector.dart';
import '../providers/playlist_provider.dart';
import '../../channels/providers/channel_provider.dart';
import '../../favorites/providers/favorites_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../epg/providers/epg_provider.dart';

/// 直播源列表页面 - 只显示已保存的播放列表（只读）
class PlaylistListScreen extends StatefulWidget {
  const PlaylistListScreen({super.key});

  @override
  State<PlaylistListScreen> createState() => _PlaylistListScreenState();
}

class _PlaylistListScreenState extends State<PlaylistListScreen> {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTV = PlatformDetector.isTV || size.width > 1200;

    final content = _buildContent(context);

    if (isTV) {
      return Scaffold(
        body: Container(
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
          child: TVSidebar(
            selectedIndex: 2, // 直播源列表页
            child: content,
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.getBackgroundColor(context),
              AppTheme.getBackgroundColor(context).withOpacity(0.8),
              AppTheme.getPrimaryColor(context).withOpacity(0.05),
            ],
          ),
        ),
        child: Column(
          children: [
            // 手机端添加状态栏高度
            if (PlatformDetector.isMobile)
              SizedBox(height: MediaQuery.of(context).padding.top),
            AppBar(
              backgroundColor: Colors.transparent,
              primary: false,  // 禁用自动SafeArea padding
              toolbarHeight: PlatformDetector.isMobile && MediaQuery.of(context).size.width > 600 ? 24.0 : 56.0,  // 横屏时进一步减小到24px
              automaticallyImplyLeading: false,  // 不显示返回按钮
              title: Text(
                AppStrings.of(context)?.playlistList ?? 'Playlist List',
                style: TextStyle(
                  color: AppTheme.getTextPrimary(context),
                  fontSize: PlatformDetector.isMobile && MediaQuery.of(context).size.width > 600 ? 14 : 20,  // 横屏时字体14px
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Consumer<PlaylistProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppTheme.primaryColor),
                const SizedBox(height: 16),
                Text(
                  '${(provider.importProgress * 100).toInt()}%',
                  style: TextStyle(
                    color: AppTheme.getTextPrimary(context),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.of(context)?.processing ?? 'Processing, please wait...',
                  style: TextStyle(
                    color: AppTheme.getTextSecondary(context),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        if (provider.playlists.isEmpty) {
          return _buildEmptyState();
        }

        return _buildPlaylistsList(provider);
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
              Icons.playlist_add_rounded,
              size: 50,
              color: AppTheme.getTextMuted(context).withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            AppStrings.of(context)?.noPlaylists ?? 'No Playlists',
            style: TextStyle(
              color: AppTheme.getTextPrimary(context),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.of(context)?.goToHomeToAdd ?? 'Go to Home to add playlists',
            style: TextStyle(
              color: AppTheme.getTextSecondary(context),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistsList(PlaylistProvider provider) {
    // 按照 ID 降序排序（最新的在前面）
    final sortedPlaylists = List.from(provider.playlists)
      ..sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
    
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: sortedPlaylists.length,
      itemBuilder: (context, index) {
        final playlist = sortedPlaylists[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildPlaylistCard(provider, playlist, index),
        );
      },
    );
  }

  Widget _buildPlaylistCard(PlaylistProvider provider, dynamic playlist, int index) {
    final isActive = provider.activePlaylist?.id == playlist.id;
    final isMobile = PlatformDetector.isMobile;
    final isLandscape = isMobile && MediaQuery.of(context).size.width > 600;

    return TVFocusable(
      autofocus: index == 0,
      onSelect: () {
        provider.setActivePlaylist(
          playlist,
          onPlaylistChanged: (playlistId) {
            context.read<ChannelProvider>().loadChannels(playlistId);
          },
          favoritesProvider: context.read<FavoritesProvider>(),
        );
      },
      focusScale: 1.02,
      showFocusBorder: false,
      builder: (context, isFocused, child) {
        return AnimatedContainer(
          duration: AppTheme.animationFast,
          decoration: BoxDecoration(
            gradient: isActive
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.getPrimaryColor(context).withOpacity(0.2),
                      AppTheme.getPrimaryColor(context).withOpacity(0.1),
                    ],
                  )
                : null,
            color: isActive ? null : AppTheme.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(isLandscape ? 12 : 16),  // 横屏时圆角更小
            border: Border.all(
              color: isFocused
                  ? AppTheme.getPrimaryColor(context)
                  : isActive
                      ? AppTheme.getPrimaryColor(context).withOpacity(0.5)
                      : Colors.transparent,
              width: isFocused ? 2 : 1,
            ),
            boxShadow: isFocused
                ? [
                    BoxShadow(
                      color: AppTheme.getPrimaryColor(context).withOpacity(0.2),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: child,
        );
      },
      child: Padding(
        padding: EdgeInsets.all(isLandscape ? 6 : 10),  // 横屏时减少padding
        child: Row(
          children: [
            // Icon
            Container(
              width: isLandscape ? 36 : 48,  // 横屏时图标容器更小
              height: isLandscape ? 36 : 48,  // 横屏时图标容器更小
              decoration: BoxDecoration(
                color: AppTheme.getPrimaryColor(context).withOpacity(0.2),
                borderRadius: BorderRadius.circular(isLandscape ? 8 : 10),  // 横屏时圆角更小
              ),
              child: Icon(
                playlist.isRemote ? Icons.cloud_outlined : Icons.folder_outlined,
                color: AppTheme.getPrimaryColor(context),
                size: isLandscape ? 18 : 24,  // 横屏时图标更小
              ),
            ),

            SizedBox(width: isLandscape ? 10 : 16),  // 横屏时减少间距

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          playlist.name,
                          style: TextStyle(
                            color: AppTheme.getTextPrimary(context),
                            fontSize: isLandscape ? 12 : 14,  // 横屏时字体更小
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isActive)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isLandscape ? 4 : 6,  // 横屏时减少padding
                            vertical: isLandscape ? 2 : 3,  // 横屏时减少padding
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.getPrimaryColor(context),
                            borderRadius: BorderRadius.circular(isLandscape ? 4 : 6),  // 横屏时圆角更小
                          ),
                          child: Text(
                            AppStrings.of(context)?.active ?? 'ACTIVE',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${playlist.format} · ${playlist.isRemote ? 'URL' : (AppStrings.of(context)?.localFile ?? 'Local File')} · ${playlist.channelCount} ${AppStrings.of(context)?.channels ?? 'channels'}',
                    style: TextStyle(
                      color: AppTheme.getTextSecondary(context),
                      fontSize: 11,
                    ),
                  ),
                  if (playlist.lastUpdated != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${AppStrings.of(context)?.updated ?? 'Updated'}: ${_formatDate(playlist.lastUpdated!)}',
                      style: TextStyle(
                        color: AppTheme.getTextMuted(context),
                        fontSize: 10,
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
                // Copy URL Button (only for remote playlists)
                if (playlist.isRemote && playlist.url != null) ...[
                  TVFocusable(
                    onSelect: () => _copyUrl(playlist.url!),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.getCardColor(context),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.copy_rounded,
                        color: AppTheme.getTextSecondary(context),
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],

                // Refresh Button
                TVFocusable(
                  onSelect: () => _refreshPlaylist(provider, playlist),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.getPrimaryColor(context).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.refresh_rounded,
                      color: AppTheme.getPrimaryColor(context),
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Delete Button
                TVFocusable(
                  onSelect: () => _confirmDelete(provider, playlist),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppTheme.errorColor,
                      size: 20,
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}${AppStrings.of(context)?.minutesAgo ?? 'm ago'}';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}${AppStrings.of(context)?.hoursAgo ?? 'h ago'}';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}${AppStrings.of(context)?.daysAgo ?? 'd ago'}';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Future<void> _refreshPlaylist(PlaylistProvider provider, dynamic playlist) async {
    final success = await provider.refreshPlaylist(playlist);
    await Future.delayed(const Duration(milliseconds: 100));

    if (mounted) {
      if (success) {
        final channelProvider = context.read<ChannelProvider>();
        if (provider.activePlaylist?.id == playlist.id) {
          await channelProvider.loadChannels(playlist.id);
        }

        if (mounted) {
          final settingsProvider = context.read<SettingsProvider>();
          final epgProvider = context.read<EpgProvider>();
          
          if (settingsProvider.enableEpg) {
            final playlistEpgUrl = provider.lastExtractedEpgUrl;
            final fallbackEpgUrl = settingsProvider.epgUrl;
            
            if (playlistEpgUrl != null && playlistEpgUrl.isNotEmpty) {
              epgProvider.loadEpg(playlistEpgUrl, fallbackUrl: fallbackEpgUrl);
            } else if (fallbackEpgUrl != null && fallbackEpgUrl.isNotEmpty) {
              epgProvider.loadEpg(fallbackEpgUrl);
            }
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? (AppStrings.of(context)?.playlistRefreshed ?? 'Playlist refreshed successfully') : (AppStrings.of(context)?.playlistRefreshFailed ?? 'Failed to refresh playlist'),
            ),
            backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _copyUrl(String url) {
    Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('URL已复制到剪贴板'),
          duration: Duration(seconds: 2),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  void _confirmDelete(PlaylistProvider provider, dynamic playlist) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.getSurfaceColor(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            AppStrings.of(context)?.deletePlaylist ?? 'Delete Playlist',
            style: TextStyle(color: AppTheme.getTextPrimary(context)),
          ),
          content: Text(
            (AppStrings.of(context)?.deleteConfirmation ?? 'Are you sure you want to delete "{name}"? This will also remove all channels from this playlist.').replaceAll('{name}', playlist.name),
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
                final success = await provider.deletePlaylist(playlist.id);

                if (mounted && success) {
                  final channelProvider = context.read<ChannelProvider>();
                  
                  if (provider.activePlaylist != null && provider.activePlaylist!.id != null) {
                    await channelProvider.loadChannels(provider.activePlaylist!.id!);
                  } else {
                    await channelProvider.loadAllChannels();
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppStrings.of(context)?.playlistDeleted ?? 'Playlist deleted'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
              ),
              child: Text(AppStrings.of(context)?.delete ?? 'Delete'),
            ),
          ],
        );
      },
    );
  }
}
