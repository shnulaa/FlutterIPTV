import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../../core/i18n/app_strings.dart';
import '../../channels/providers/channel_provider.dart';
import '../providers/playlist_provider.dart';

class PlaylistManagerScreen extends StatefulWidget {
  const PlaylistManagerScreen({super.key});

  @override
  State<PlaylistManagerScreen> createState() => _PlaylistManagerScreenState();
}

class _PlaylistManagerScreenState extends State<PlaylistManagerScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _urlFocusNode = FocusNode();

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _nameFocusNode.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        title: Text(
          AppStrings.of(context)?.playlistManager ?? 'Playlist Manager',
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Consumer<PlaylistProvider>(
            builder: (context, provider, _) {
              return IconButton(
                icon: Icon(
                  provider.sortBy.contains('name')
                      ? Icons.sort_by_alpha_rounded
                      : Icons.calendar_month_rounded,
                ),
                tooltip: provider.sortBy.contains('name')
                    ? 'Sort by Date'
                    : 'Sort by Name',
                onPressed: provider.toggleSortOrder,
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<PlaylistProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              // Add Playlist Section
              _buildAddPlaylistSection(provider),

              const Divider(color: AppTheme.cardColor, height: 1),

              // Playlists List
              Expanded(
                child: provider.playlists.isEmpty
                    ? _buildEmptyState()
                    : _buildPlaylistsList(provider),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAddPlaylistSection(PlaylistProvider provider) {
    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.of(context)?.addNewPlaylist ?? 'Add New Playlist',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // ... inputs
            // Name Input
            TVFocusable(
              onSelect: () => _nameFocusNode.requestFocus(),
              child: TextField(
                controller: _nameController,
                focusNode: _nameFocusNode,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText:
                      AppStrings.of(context)?.playlistName ?? 'Playlist Name',
                  hintStyle: const TextStyle(color: AppTheme.textMuted),
                  prefixIcon: const Icon(Icons.label_outline,
                      color: AppTheme.textMuted),
                  filled: true,
                  fillColor: AppTheme.cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppTheme.primaryColor, width: 2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // URL Input
            TVFocusable(
              onSelect: () => _urlFocusNode.requestFocus(),
              child: TextField(
                controller: _urlController,
                focusNode: _urlFocusNode,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText:
                      AppStrings.of(context)?.playlistUrl ?? 'M3U/M3U8 URL',
                  hintStyle: const TextStyle(color: AppTheme.textMuted),
                  prefixIcon: const Icon(Icons.link, color: AppTheme.textMuted),
                  filled: true,
                  fillColor: AppTheme.cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppTheme.primaryColor, width: 2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: TVFocusable(
                    onSelect: () => _addPlaylist(provider),
                    child: ElevatedButton.icon(
                      onPressed: provider.isLoading
                          ? null
                          : () => _addPlaylist(provider),
                      icon: provider.isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.add_rounded, size: 20),
                      label: Text(provider.isLoading
                          ? (AppStrings.of(context)?.importing ??
                              'Importing...')
                          : (AppStrings.of(context)?.addFromUrl ??
                              'Add from URL')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                TVFocusable(
                  onSelect: () => _pickFile(provider),
                  child: OutlinedButton.icon(
                    onPressed: () => _pickFile(provider),
                    icon: const Icon(Icons.folder_open_rounded, size: 20),
                    label:
                        Text(AppStrings.of(context)?.fromFile ?? 'From File'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: const BorderSide(color: AppTheme.primaryColor),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Progress Indicator
            if (provider.isLoading) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: provider.importProgress,
                  backgroundColor: AppTheme.cardColor,
                  color: AppTheme.primaryColor,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(provider.importProgress * 100).toInt()}% Complete',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],

            // Error Message
            if (provider.error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppTheme.errorColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        provider.error!,
                        style: const TextStyle(
                          color: AppTheme.errorColor,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      color: AppTheme.errorColor,
                      onPressed: provider.clearError,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
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
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Icon(
              Icons.playlist_add_rounded,
              size: 50,
              color: AppTheme.textMuted.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            AppStrings.of(context)?.noPlaylists ?? 'No Playlists',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.of(context)?.addFirstPlaylist ??
                'Add your first M3U playlist above',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistsList(PlaylistProvider provider) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: provider.playlists.length,
      itemBuilder: (context, index) {
        final playlist = provider.playlists[index];
        return _buildPlaylistCard(provider, playlist);
      },
    );
  }

  Widget _buildPlaylistCard(PlaylistProvider provider, dynamic playlist) {
    return TVFocusable(
      onSelect: () => provider.setActivePlaylist(playlist),
      focusScale: 1.02,
      showFocusBorder: false,
      builder: (context, isFocused, child) {
        final isActive = provider.activePlaylist?.id == playlist.id;

        return AnimatedContainer(
          duration: AppTheme.animationFast,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: isActive
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryColor.withOpacity(0.2),
                      AppTheme.primaryColor.withOpacity(0.1),
                    ],
                  )
                : null,
            color: isActive ? null : AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isFocused
                  ? AppTheme.focusBorderColor
                  : isActive
                      ? AppTheme.primaryColor.withOpacity(0.5)
                      : Colors.transparent,
              width: isFocused ? 2 : 1,
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
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              playlist.isRemote ? Icons.cloud_outlined : Icons.folder_outlined,
              color: AppTheme.primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),

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
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (provider.activePlaylist?.id == playlist.id)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          AppStrings.of(context)?.active ?? 'ACTIVE',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${playlist.channelCount} ${AppStrings.of(context)?.channels ?? 'channels'} • ${playlist.groupCount} ${AppStrings.of(context)?.categories ?? 'groups'}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                if (playlist.lastUpdated != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${AppStrings.of(context)?.updated ?? 'Updated'}: ${_formatDate(playlist.lastUpdated!)}',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
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
              // Refresh Button
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                color: AppTheme.textSecondary,
                onPressed: () => _refreshPlaylist(provider, playlist),
                tooltip: AppStrings.of(context)?.refresh ?? 'Refresh',
              ),
              // Delete Button
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                color: AppTheme.errorColor,
                onPressed: () => _confirmDelete(provider, playlist),
                tooltip: AppStrings.of(context)?.delete ?? 'Delete',
              ),
            ],
          ),
        ],
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

  Future<void> _addPlaylist(PlaylistProvider provider) async {
    final name = _nameController.text.trim();
    final url = _urlController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.of(context)?.pleaseEnterPlaylistName ??
              'Please enter a playlist name'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.of(context)?.pleaseEnterPlaylistUrl ??
              'Please enter a playlist URL'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    final playlist = await provider.addPlaylistFromUrl(name, url);

    if (playlist != null && mounted) {
      // Refresh channels
      context.read<ChannelProvider>().loadAllChannels();

      _nameController.clear();
      _urlController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              (AppStrings.of(context)?.playlistAdded ?? 'Added "{name}"')
                  .replaceAll('{name}', playlist.name)
                  .replaceAll('{count}', '${playlist.channelCount}')),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  Future<void> _refreshPlaylist(
      PlaylistProvider provider, dynamic playlist) async {
    final success = await provider.refreshPlaylist(playlist);

    if (mounted) {
      if (success) {
        context.read<ChannelProvider>().loadAllChannels();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? (AppStrings.of(context)?.playlistRefreshed ??
                    'Playlist refreshed successfully')
                : (AppStrings.of(context)?.playlistRefreshFailed ??
                    'Failed to refresh playlist'),
          ),
          backgroundColor:
              success ? AppTheme.successColor : AppTheme.errorColor,
        ),
      );
    }
  }

  void _confirmDelete(PlaylistProvider provider, dynamic playlist) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            AppStrings.of(context)?.deletePlaylist ?? 'Delete Playlist',
            style: const TextStyle(color: AppTheme.textPrimary),
          ),
          content: Text(
            (AppStrings.of(context)?.deleteConfirmation ??
                    'Are you sure you want to delete "{name}"? This will also remove all channels from this playlist.')
                .replaceAll('{name}', playlist.name),
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppStrings.of(context)?.cancel ?? 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await provider.deletePlaylist(playlist.id);

                if (mounted) {
                  // Refresh channels
                  context.read<ChannelProvider>().loadAllChannels();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppStrings.of(context)?.playlistDeleted ??
                          'Playlist deleted'),
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

  Future<void> _pickFile(PlaylistProvider provider) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['m3u', 'm3u8'],
      );

      if (result != null && result.files.single.path != null) {
        if (!mounted) return;

        final filePath = result.files.single.path!;
        final fileName =
            result.files.single.name.replaceAll(RegExp(r'\.m3u8?'), '');

        try {
          await provider.addPlaylistFromFile(fileName, filePath);

          if (mounted) {
            // Refresh channels
            context.read<ChannelProvider>().loadAllChannels();

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(AppStrings.of(context)?.playlistImported ??
                      'Playlist imported successfully')),
            );
            _nameController.clear();
            _urlController.clear();
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text((AppStrings.of(context)?.errorPickingFile ??
                      'Error picking file: {error}')
                  .replaceAll('{error}', '$e'))),
        );
      }
    }
  }
}
