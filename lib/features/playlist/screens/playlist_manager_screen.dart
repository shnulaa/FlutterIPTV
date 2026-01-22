import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import 'package:flutter_iptv/features/playlist/widgets/qr_import_dialog.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/platform/platform_detector.dart';
import '../providers/playlist_provider.dart';
import '../../channels/providers/channel_provider.dart';
import '../../favorites/providers/favorites_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../epg/providers/epg_provider.dart';

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
    return Consumer<PlaylistProvider>(
      builder: (context, provider, _) {
        return Stack(
          children: [
            Scaffold(
              backgroundColor: AppTheme.getBackgroundColor(context),
              appBar: AppBar(
                backgroundColor: AppTheme.getBackgroundColor(context),
                title: Text(
                  AppStrings.of(context)?.playlistManager ?? 'Playlist Manager',
                  style: TextStyle(
                    color: AppTheme.getTextPrimary(context),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: provider.isLoading ? null : () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: Icon(
                      provider.sortBy.contains('name') ? Icons.sort_by_alpha_rounded : Icons.calendar_month_rounded,
                    ),
                    tooltip: provider.sortBy.contains('name') ? 'Sort by Date' : 'Sort by Name',
                    onPressed: provider.isLoading ? null : provider.toggleSortOrder,
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              body: Column(
                children: [
                  // Add Playlist Section
                  _buildAddPlaylistSection(provider),

                  Divider(color: AppTheme.getCardColor(context), height: 1),

                  // Playlists List
                  Expanded(
                    child: provider.playlists.isEmpty ? _buildEmptyState() : _buildPlaylistsList(provider),
                  ),
                ],
              ),
            ),
            // Loading overlay
            if (provider.isLoading)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.getSurfaceColor(context),
                      borderRadius: BorderRadius.circular(16),
                    ),
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
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppStrings.of(context)?.processing ?? 'Processing, please wait...',
                          style: TextStyle(
                            color: AppTheme.getTextSecondary(context),
                            fontSize: 14,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildAddPlaylistSection(PlaylistProvider provider) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(20),
        ),
      ),
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.of(context)?.addNewPlaylist ?? 'Add New Playlist',
              style: TextStyle(
                color: AppTheme.getTextPrimary(context),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // For Android TV, only show file import and QR scan buttons (no text input)
            if (PlatformDetector.isTV) ...[
              // From File Button - Order 1
              FocusTraversalOrder(
                order: const NumericFocusOrder(1),
                child: _buildActionButton(
                  onPressed: () => _pickFile(provider),
                  icon: const Icon(Icons.folder_open_rounded, size: 20),
                  label: AppStrings.of(context)?.fromFile ?? 'From File',
                  isPrimary: true,
                ),
              ),
              const SizedBox(height: 12),
              // Scan QR Code Button - Order 2
              FocusTraversalOrder(
                order: const NumericFocusOrder(2),
                child: _buildActionButton(
                  onPressed: () => _showQrImportDialog(context),
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                  label: AppStrings.of(context)?.scanToImport ?? 'Scan to Import',
                  isPrimary: false,
                ),
              ),
            ] else ...[
              // For PC and Android Mobile, show full UI with text inputs
              // Name Input - Order 1
              FocusTraversalOrder(
                order: const NumericFocusOrder(1),
                child: _buildFocusableTextField(
                  controller: _nameController,
                  focusNode: _nameFocusNode,
                  hintText: AppStrings.of(context)?.playlistName ?? 'Playlist Name',
                  prefixIcon: Icons.label_outline,
                  autofocus: true,
                ),
              ),
              const SizedBox(height: 12),
              // URL Input - Order 2
              FocusTraversalOrder(
                order: const NumericFocusOrder(2),
                child: _buildFocusableTextField(
                  controller: _urlController,
                  focusNode: _urlFocusNode,
                  hintText: AppStrings.of(context)?.playlistUrl ?? 'M3U/M3U8 URL',
                  prefixIcon: Icons.link,
                ),
              ),
              const SizedBox(height: 16),
              // Action Buttons Row
              Row(
                children: [
                  // Add from URL Button - Order 3
                  Expanded(
                    child: FocusTraversalOrder(
                      order: const NumericFocusOrder(3),
                      child: _buildActionButton(
                        onPressed: provider.isLoading ? null : () => _addPlaylist(provider),
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
                        label: provider.isLoading ? (AppStrings.of(context)?.importing ?? 'Importing...') : (AppStrings.of(context)?.addFromUrl ?? 'Add from URL'),
                        isPrimary: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // From File Button - Order 4
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(4),
                    child: _buildActionButton(
                      onPressed: () => _pickFile(provider),
                      icon: const Icon(Icons.folder_open_rounded, size: 20),
                      label: AppStrings.of(context)?.fromFile ?? 'From File',
                      isPrimary: false,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Scan QR Code Button - Order 5
              FocusTraversalOrder(
                order: const NumericFocusOrder(5),
                child: _buildActionButton(
                  onPressed: () => _showQrImportDialog(context),
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                  label: AppStrings.of(context)?.scanToImport ?? 'Scan to Import',
                  isPrimary: false,
                ),
              ),
            ],

            // Progress Indicator
            if (provider.isLoading) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: provider.importProgress,
                  backgroundColor: AppTheme.getCardColor(context),
                  color: AppTheme.getPrimaryColor(context),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(provider.importProgress * 100).toInt()}% Complete',
                style: TextStyle(
                  color: AppTheme.getTextSecondary(context),
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
                  border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
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

  /// Build a focusable text field that works well with TV remote
  Widget _buildFocusableTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required IconData prefixIcon,
    bool autofocus = false,
  }) {
    return Focus(
      focusNode: focusNode,
      onFocusChange: (hasFocus) {
        // Trigger rebuild to show focus state
        if (mounted) setState(() {});
      },
      onKeyEvent: (node, event) {
        // Allow Enter/Select to focus the text field for editing
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter) {
            // TextField is already focused, just allow default behavior
            return KeyEventResult.ignored;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final isFocused = focusNode.hasFocus;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isFocused ? AppTheme.getPrimaryColor(context) : Colors.transparent,
                width: isFocused ? 3 : 0,
              ),
              boxShadow: isFocused
                  ? [
                      BoxShadow(
                        color: AppTheme.getPrimaryColor(context).withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              style: TextStyle(color: AppTheme.getTextPrimary(context)),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(color: AppTheme.getTextMuted(context)),
                prefixIcon: Icon(prefixIcon, color: AppTheme.getTextMuted(context)),
                filled: true,
                fillColor: AppTheme.getCardColor(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Build an action button that works well with TV remote
  Widget _buildActionButton({
    required VoidCallback? onPressed,
    required Widget icon,
    required String label,
    required bool isPrimary,
  }) {
    // TV端使用TVFocusable，确保遥控器按键正确处理
    if (PlatformDetector.isTV) {
      return TVFocusable(
        onSelect: onPressed,
        focusScale: 1.05,
        showFocusBorder: true,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: isPrimary ? AppTheme.getPrimaryColor(context) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isPrimary ? null : Border.all(color: AppTheme.getPrimaryColor(context).withOpacity(0.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconTheme(
                data: IconThemeData(
                  color: isPrimary ? Colors.white : AppTheme.getPrimaryColor(context),
                ),
                child: icon,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isPrimary ? Colors.white : AppTheme.getPrimaryColor(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 非TV端保持原有逻辑
    return Builder(
      builder: (context) {
        return Focus(
          onFocusChange: (hasFocus) {
            if (mounted) setState(() {});
          },
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.gameButtonA) {
                onPressed?.call();
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: Builder(
            builder: (context) {
              final isFocused = Focus.of(context).hasFocus;
              return GestureDetector(
                onTap: onPressed,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  transform: Matrix4.identity()..scale(isFocused ? 1.05 : 1.0),
                  transformAlignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isFocused
                        ? [
                            BoxShadow(
                              color: AppTheme.getPrimaryColor(context).withOpacity(0.4),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: isPrimary
                      ? ElevatedButton.icon(
                          onPressed: onPressed,
                          icon: icon,
                          label: Text(label),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.getPrimaryColor(context),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        )
                      : OutlinedButton.icon(
                          onPressed: onPressed,
                          icon: icon,
                          label: Text(label),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.getPrimaryColor(context),
                            side: BorderSide(
                              color: isFocused ? AppTheme.primaryColor : AppTheme.getPrimaryColor(context).withOpacity(0.5),
                              width: isFocused ? 2 : 1,
                            ),
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
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final platformText = PlatformDetector.isTV
        ? (AppStrings.of(context)?.addFirstPlaylistTV ?? 'Add your first M3U playlist\nYou can import via USB or scan QR code')
        : (AppStrings.of(context)?.addFirstPlaylist ?? 'Add your first M3U playlist above');

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
            platformText,
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
    final isTV = PlatformDetector.isTV;
    final isActive = provider.activePlaylist?.id == playlist.id;

    // TV端使用 FocusTraversalGroup 让内部按钮可以获取焦点
    if (isTV) {
      return FocusTraversalGroup(
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
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
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive ? AppTheme.getPrimaryColor(context).withOpacity(0.5) : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // 主体部分可点击选择播放列表
              Expanded(
                child: TVFocusable(
                  onSelect: () {
                    provider.setActivePlaylist(
                      playlist,
                      onPlaylistChanged: (playlistId) {
                        context.read<ChannelProvider>().loadChannels(playlistId);
                      },
                      favoritesProvider: context.read<FavoritesProvider>(),
                    );
                  },
                  focusScale: 1.0,
                  showFocusBorder: true,
                  child: Row(
                    children: [
                      // Icon
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.getPrimaryColor(context).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          playlist.isRemote ? Icons.cloud_outlined : Icons.folder_outlined,
                          color: AppTheme.getPrimaryColor(context),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
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
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isActive)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppTheme.getPrimaryColor(context),
                                      borderRadius: BorderRadius.circular(6),
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
                            Row(
                              children: [
                                Icon(
                                  playlist.isRemote ? Icons.cloud_outlined : Icons.folder_outlined,
                                  color: AppTheme.getTextMuted(context),
                                  size: 11,
                                ),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    '${playlist.format} · ${playlist.isRemote ? 'URL' : (AppStrings.of(context)?.localFile ?? 'Local File')} · ${playlist.channelCount} ${AppStrings.of(context)?.channels ?? 'channels'} · ${playlist.groupCount} ${AppStrings.of(context)?.categories ?? 'groups'}',
                                    style: TextStyle(color: AppTheme.getTextSecondary(context), fontSize: 10),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (playlist.lastUpdated != null) ...[
                              const SizedBox(height: 1),
                              Text(
                                '${AppStrings.of(context)?.updated ?? 'Updated'}: ${_formatDate(playlist.lastUpdated!)}',
                                style: TextStyle(color: AppTheme.getTextMuted(context), fontSize: 10),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // 复制URL按钮（仅远程播放列表显示）
              if (playlist.isRemote && playlist.url != null) ...[
                TVFocusable(
                  onSelect: () => _copyUrl(playlist.url!),
                  focusScale: 1.1,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.getCardColor(context),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.copy_rounded, color: AppTheme.getTextSecondary(context), size: 18),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              // 刷新按钮
              TVFocusable(
                onSelect: () => _refreshPlaylist(provider, playlist),
                focusScale: 1.1,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.getCardColor(context),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.refresh_rounded, color: AppTheme.getTextSecondary(context), size: 18),
                ),
              ),
              const SizedBox(width: 6),
              // 删除按钮
              TVFocusable(
                onSelect: () => _confirmDelete(provider, playlist),
                focusScale: 1.1,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.getCardColor(context),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: AppTheme.errorColor, size: 18),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 非TV端保持原有逻辑
    return TVFocusable(
      onSelect: () {
        provider.setActivePlaylist(
          playlist,
          onPlaylistChanged: (playlistId) {
            // Load channels for the selected playlist
            context.read<ChannelProvider>().loadChannels(playlistId);
          },
          favoritesProvider: context.read<FavoritesProvider>(),
        );
      },
      focusScale: 1.02,
      showFocusBorder: false,
      builder: (context, isFocused, child) {
        final isActive = provider.activePlaylist?.id == playlist.id;

        return AnimatedContainer(
          duration: AppTheme.animationFast,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
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
            borderRadius: BorderRadius.circular(16),
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
      child: Column(
        children: [
          Row(
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.getPrimaryColor(context).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  playlist.isRemote ? Icons.cloud_outlined : Icons.folder_outlined,
                  color: AppTheme.getPrimaryColor(context),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

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
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (provider.activePlaylist?.id == playlist.id)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.getPrimaryColor(context),
                                          borderRadius: BorderRadius.circular(6),
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
                            // 在 Windows/TV 上单行显示，手机上允许换行
                            Platform.isWindows || PlatformDetector.isTV
                                ? Row(
                                    children: [
                                      Icon(
                                        playlist.isRemote ? Icons.cloud_outlined : Icons.folder_outlined,
                                        color: AppTheme.getTextMuted(context),
                                        size: 11,
                                      ),
                                      const SizedBox(width: 3),
                                      Expanded(
                                        child: Text(
                                          '${playlist.format} · ${playlist.isRemote ? 'URL' : (AppStrings.of(context)?.localFile ?? 'Local File')} · ${playlist.channelCount} ${AppStrings.of(context)?.channels ?? 'channels'} · ${playlist.groupCount} ${AppStrings.of(context)?.categories ?? 'groups'}',
                                          style: TextStyle(
                                            color: AppTheme.getTextSecondary(context),
                                            fontSize: 10,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  )
                                : Wrap(
                                    spacing: 4,
                                    runSpacing: 2,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Icon(
                                        playlist.isRemote ? Icons.cloud_outlined : Icons.folder_outlined,
                                        color: AppTheme.getTextMuted(context),
                                        size: 11,
                                      ),
                                      Text(
                                        '${playlist.format} · ${playlist.isRemote ? 'URL' : (AppStrings.of(context)?.localFile ?? 'Local File')} · ${playlist.channelCount} ${AppStrings.of(context)?.channels ?? 'channels'} · ${playlist.groupCount} ${AppStrings.of(context)?.categories ?? 'groups'}',
                                        style: TextStyle(
                                          color: AppTheme.getTextSecondary(context),
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                            if (playlist.lastUpdated != null) ...[
                              const SizedBox(height: 1),
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
            ],
          ),

          // Actions - 手机端放到下面一行
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Refresh Button
              if (PlatformDetector.isTV) ...[
                // 复制URL按钮（仅远程播放列表显示）
                if (playlist.isRemote && playlist.url != null) ...[
                  TVFocusable(
                    onSelect: () => _copyUrl(playlist.url!),
                    focusScale: 1.1,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.getCardColor(context),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.copy_rounded, color: AppTheme.getTextSecondary(context), size: 20),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                TVFocusable(
                  onSelect: () => _refreshPlaylist(provider, playlist),
                  focusScale: 1.1,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.getCardColor(context),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.refresh_rounded, color: AppTheme.getTextSecondary(context), size: 20),
                  ),
                ),
                const SizedBox(width: 8),
                TVFocusable(
                  onSelect: () => _confirmDelete(provider, playlist),
                  focusScale: 1.1,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.getCardColor(context),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: AppTheme.errorColor, size: 20),
                  ),
                ),
              ] else ...[
                // 手机端：使用更紧凑的按钮
                // 复制URL按钮（仅远程播放列表显示）
                if (playlist.isRemote && playlist.url != null)
                  IconButton(
                    icon: const Icon(Icons.copy_rounded),
                    iconSize: 20,
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                    color: AppTheme.getTextSecondary(context),
                    onPressed: () => _copyUrl(playlist.url!),
                    tooltip: '复制URL',
                  ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  iconSize: 20,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                  color: AppTheme.getTextSecondary(context),
                  onPressed: () => _refreshPlaylist(provider, playlist),
                  tooltip: AppStrings.of(context)?.refresh ?? 'Refresh',
                ),
                // Delete Button
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  iconSize: 20,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                  color: AppTheme.errorColor,
                  onPressed: () => _confirmDelete(provider, playlist),
                  tooltip: AppStrings.of(context)?.delete ?? 'Delete',
                ),
              ],
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
          content: Text(AppStrings.of(context)?.pleaseEnterPlaylistName ?? 'Please enter a playlist name'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.of(context)?.pleaseEnterPlaylistUrl ?? 'Please enter a playlist URL'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    try {
      final playlist = await provider.addPlaylistFromUrl(name, url);

      if (playlist != null && mounted) {
        // Set the new playlist as active and load its channels
        provider.setActivePlaylist(playlist, favoritesProvider: context.read<FavoritesProvider>());
        await context.read<ChannelProvider>().loadChannels(playlist.id!);

        // Auto-load EPG: Try playlist EPG URL first, fallback to settings EPG URL
        if (mounted) {
          final settingsProvider = context.read<SettingsProvider>();
          final epgProvider = context.read<EpgProvider>();
          
          if (settingsProvider.enableEpg) {
            final playlistEpgUrl = provider.lastExtractedEpgUrl;
            final fallbackEpgUrl = settingsProvider.epgUrl;
            
            if (playlistEpgUrl != null && playlistEpgUrl.isNotEmpty) {
              debugPrint('DEBUG: 加载播放列表EPG: $playlistEpgUrl (兜底: $fallbackEpgUrl)');
              await epgProvider.loadEpg(playlistEpgUrl, fallbackUrl: fallbackEpgUrl);
            } else if (fallbackEpgUrl != null && fallbackEpgUrl.isNotEmpty) {
              debugPrint('DEBUG: 使用兜底EPG URL: $fallbackEpgUrl');
              await epgProvider.loadEpg(fallbackEpgUrl);
            }
          }
        }

        _nameController.clear();
        _urlController.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text((AppStrings.of(context)?.playlistAdded ?? 'Added "{name}"').replaceAll('{name}', playlist.name).replaceAll('{count}', '${playlist.channelCount}')),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _refreshPlaylist(PlaylistProvider provider, dynamic playlist) async {
    debugPrint('DEBUG: 开始刷新播放列表: ${playlist.name}');
    final success = await provider.refreshPlaylist(playlist);

    // refreshPlaylist 完成后 isLoading 应该已经是 false 了
    // 但为了确保，我们在这里等待一帧让 UI 更新
    await Future.delayed(const Duration(milliseconds: 100));

    if (mounted) {
      if (success) {
        final channelProvider = context.read<ChannelProvider>();
        
        // 如果刷新的是当前激活的播放列表，重新加载频道
        if (provider.activePlaylist?.id == playlist.id) {
          debugPrint('DEBUG: 刷新的是激活播放列表，重新加载频道');
          await channelProvider.loadChannels(playlist.id);
        } else {
          debugPrint('DEBUG: 刷新的不是激活播放列表，不重新加载频道');
        }

        // Auto-load EPG: Try playlist EPG URL first, fallback to settings EPG URL
        if (mounted) {
          final settingsProvider = context.read<SettingsProvider>();
          final epgProvider = context.read<EpgProvider>();
          
          if (settingsProvider.enableEpg) {
            final playlistEpgUrl = provider.lastExtractedEpgUrl;
            final fallbackEpgUrl = settingsProvider.epgUrl;
            
            if (playlistEpgUrl != null && playlistEpgUrl.isNotEmpty) {
              debugPrint('DEBUG: 加载播放列表EPG: $playlistEpgUrl (兜底: $fallbackEpgUrl)');
              epgProvider.loadEpg(playlistEpgUrl, fallbackUrl: fallbackEpgUrl);
            } else if (fallbackEpgUrl != null && fallbackEpgUrl.isNotEmpty) {
              debugPrint('DEBUG: 使用兜底EPG URL: $fallbackEpgUrl');
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
        SnackBar(
          content: const Text('URL已复制到剪贴板'),
          duration: const Duration(seconds: 2),
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
                  
                  // 如果还有播放列表，加载新的激活播放列表的频道
                  if (provider.activePlaylist != null && provider.activePlaylist!.id != null) {
                    await channelProvider.loadChannels(provider.activePlaylist!.id!);
                  } else {
                    // 没有播放列表了，清空频道
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

  Future<void> _showQrImportDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const QrImportDialog(),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Playlist imported successfully'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  Future<void> _pickFile(PlaylistProvider provider) async {
    try {
      // For Android TV, show a more user-friendly message
      if (PlatformDetector.isTV) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.of(context)?.selectM3uFile ?? 'Please select an M3U/M3U8 file'),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['m3u', 'm3u8', 'txt'],
      );

      if (result != null && result.files.single.path != null) {
        if (!mounted) return;

        final filePath = result.files.single.path!;
        final fileName = result.files.single.name.replaceAll(RegExp(r'\.(m3u8?|txt)$'), '');

        try {
          final playlist = await provider.addPlaylistFromFile(fileName, filePath);

          if (mounted) {
            // Set the new playlist as active and load its channels
            if (playlist != null) {
              provider.setActivePlaylist(playlist, favoritesProvider: context.read<FavoritesProvider>());
              await context.read<ChannelProvider>().loadChannels(playlist.id!);

              // Auto-load EPG: Try playlist EPG URL first, fallback to settings EPG URL
              if (mounted) {
                final settingsProvider = context.read<SettingsProvider>();
                final epgProvider = context.read<EpgProvider>();
                
                if (settingsProvider.enableEpg) {
                  final playlistEpgUrl = provider.lastExtractedEpgUrl;
                  final fallbackEpgUrl = settingsProvider.epgUrl;
                  
                  if (playlistEpgUrl != null && playlistEpgUrl.isNotEmpty) {
                    debugPrint('DEBUG: 加载播放列表EPG: $playlistEpgUrl (兜底: $fallbackEpgUrl)');
                    await epgProvider.loadEpg(playlistEpgUrl, fallbackUrl: fallbackEpgUrl);
                  } else if (fallbackEpgUrl != null && fallbackEpgUrl.isNotEmpty) {
                    debugPrint('DEBUG: 使用兜底EPG URL: $fallbackEpgUrl');
                    await epgProvider.loadEpg(fallbackEpgUrl);
                  }
                }
              }
            }

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppStrings.of(context)?.playlistImported ?? 'Playlist imported successfully')),
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
      } else if (PlatformDetector.isTV) {
        // For Android TV, show additional help if no file was selected
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppStrings.of(context)?.noFileSelected ?? 'No file selected. Please ensure your device has USB storage or network storage configured.'),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text((AppStrings.of(context)?.errorPickingFile ?? 'Error picking file: {error}').replaceAll('{error}', '$e'))),
        );
      }
    }
  }
}
