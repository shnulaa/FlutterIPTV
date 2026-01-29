import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/platform/platform_detector.dart';
import '../providers/playlist_provider.dart';
import '../../channels/providers/channel_provider.dart';
import '../../favorites/providers/favorites_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../epg/providers/epg_provider.dart';
import 'qr_import_dialog.dart';

class AddPlaylistDialog extends StatefulWidget {
  const AddPlaylistDialog({super.key});

  @override
  State<AddPlaylistDialog> createState() => _AddPlaylistDialogState();
}

class _AddPlaylistDialogState extends State<AddPlaylistDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  late final FocusNode _nameFocusNode;
  late final FocusNode _urlFocusNode;

  @override
  void initState() {
    super.initState();
    _nameFocusNode = FocusNode(debugLabel: 'dialog_playlist_name');
    _urlFocusNode = FocusNode(debugLabel: 'dialog_playlist_url');
  }

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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    // 手机横屏：宽度600-900，高度小于宽度
    final isLandscape = screenWidth > 600 && screenWidth < 900 && screenHeight < screenWidth;
    
    return Consumer<PlaylistProvider>(
      builder: (context, provider, _) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isLandscape ? 480 : 600,  // 横屏时宽度更小
              maxHeight: isLandscape ? 250 : 700,  // 横屏时高度更小
            ),
            decoration: BoxDecoration(
              color: AppTheme.getBackgroundColor(context),
              borderRadius: BorderRadius.circular(isLandscape ? 16 : 24),  // 横屏时圆角更小
            ),
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: EdgeInsets.all(isLandscape ? 16 : 32),  // 横屏时padding更小
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon
                      Container(
                        width: isLandscape ? 50 : 80,  // 横屏时图标更小
                        height: isLandscape ? 50 : 80,
                        decoration: BoxDecoration(
                          gradient: AppTheme.getGradient(context),
                          borderRadius: BorderRadius.circular(isLandscape ? 12 : 20),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.getPrimaryColor(context).withOpacity(0.3),
                              blurRadius: isLandscape ? 10 : 20,
                              offset: Offset(0, isLandscape ? 5 : 10),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.playlist_add_rounded,
                          size: isLandscape ? 28 : 40,  // 横屏时图标更小
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: isLandscape ? 12 : 24),  // 横屏时间距更小
                      
                      // Title
                      Text(
                        AppStrings.of(context)?.addNewPlaylist ?? 'Add New Playlist',
                        style: TextStyle(
                          color: AppTheme.getTextPrimary(context),
                          fontSize: isLandscape ? 16 : 24,  // 横屏时字体更小
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: isLandscape ? 4 : 8),  // 横屏时间距更小
                      Text(
                        PlatformDetector.isTV
                            ? (AppStrings.of(context)?.addFirstPlaylistTV ?? 'Import via USB or scan QR code')
                            : (AppStrings.of(context)?.addPlaylistSubtitle ?? 'Import M3U/M3U8 playlist from URL or file'),
                        style: TextStyle(
                          color: AppTheme.getTextSecondary(context),
                          fontSize: isLandscape ? 11 : 14,  // 横屏时字体更小
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: isLandscape ? 16 : 32),  // 横屏时间距更小
                      
                      // Content
                      PlatformDetector.isTV ? _buildTVContent(provider) : _buildDesktopContent(provider),
                      
                      // Error message
                      if (provider.error != null) ...[
                        SizedBox(height: isLandscape ? 8 : 16),  // 横屏时间距更小
                        Container(
                          padding: EdgeInsets.all(isLandscape ? 8 : 12),  // 横屏时padding更小
                          decoration: BoxDecoration(
                            color: AppTheme.errorColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(isLandscape ? 8 : 12),
                            border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline_rounded, color: AppTheme.errorColor, size: isLandscape ? 14 : 18),
                              SizedBox(width: isLandscape ? 6 : 8),
                              Expanded(
                                child: Text(
                                  provider.error!,
                                  style: TextStyle(color: AppTheme.errorColor, fontSize: isLandscape ? 10 : 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Loading overlay
                if (provider.isLoading)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(isLandscape ? 16 : 24),
                      ),
                      child: Center(
                        child: Container(
                          padding: EdgeInsets.all(isLandscape ? 16 : 24),  // 横屏时padding更小
                          decoration: BoxDecoration(
                            color: AppTheme.getSurfaceColor(context),
                            borderRadius: BorderRadius.circular(isLandscape ? 12 : 16),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: isLandscape ? 30 : 40,  // 横屏时进度条更小
                                height: isLandscape ? 30 : 40,
                                child: const CircularProgressIndicator(color: AppTheme.primaryColor),
                              ),
                              SizedBox(height: isLandscape ? 10 : 16),
                              Text(
                                '${(provider.importProgress * 100).toInt()}%',
                                style: TextStyle(
                                  color: AppTheme.getTextPrimary(context),
                                  fontSize: isLandscape ? 14 : 20,  // 横屏时字体更小
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: isLandscape ? 4 : 8),
                              Text(
                                AppStrings.of(context)?.processing ?? 'Processing...',
                                style: TextStyle(
                                  color: AppTheme.getTextSecondary(context),
                                  fontSize: isLandscape ? 10 : 12,  // 横屏时字体更小
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                
                // Close button
                if (!provider.isLoading)
                  Positioned(
                    top: isLandscape ? 4 : 8,
                    right: isLandscape ? 4 : 8,
                    child: IconButton(
                      icon: Icon(Icons.close_rounded, size: isLandscape ? 20 : 24),  // 横屏时图标更小
                      onPressed: () => Navigator.pop(context),
                      color: AppTheme.getTextMuted(context),
                      padding: isLandscape ? const EdgeInsets.all(4) : null,  // 横屏时padding更小
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTVContent(PlaylistProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildImportCard(
          onPressed: () => _pickFile(provider),
          icon: Icons.folder_open_rounded,
          title: AppStrings.of(context)?.fromFile ?? 'From File',
          subtitle: AppStrings.of(context)?.importFromUsb ?? 'Import from USB or local storage',
          isPrimary: true,
        ),
        const SizedBox(height: 12),
        _buildImportCard(
          onPressed: () => _showQrImportDialog(context),
          icon: Icons.qr_code_scanner_rounded,
          title: AppStrings.of(context)?.scanToImport ?? 'Scan to Import',
          subtitle: AppStrings.of(context)?.scanQrToImport ?? 'Use your phone to scan QR code',
          isPrimary: false,
        ),
      ],
    );
  }

  Widget _buildDesktopContent(PlaylistProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTextField(
          controller: _nameController,
          focusNode: _nameFocusNode,
          hintText: AppStrings.of(context)?.playlistName ?? 'Playlist Name',
          prefixIcon: Icons.label_outline_rounded,
          autofocus: true,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _urlController,
          focusNode: _urlFocusNode,
          hintText: AppStrings.of(context)?.playlistUrlHint ?? 'M3U/M3U8/TXT URL',
          prefixIcon: Icons.link_rounded,
        ),
        const SizedBox(height: 20),
        _buildPrimaryButton(
          onPressed: provider.isLoading ? null : () => _addPlaylist(provider),
          icon: provider.isLoading ? null : Icons.add_rounded,
          label: provider.isLoading
              ? (AppStrings.of(context)?.importing ?? 'Importing...')
              : (AppStrings.of(context)?.addFromUrl ?? 'Add from URL'),
          isLoading: provider.isLoading,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: Divider(color: AppTheme.getTextMuted(context).withOpacity(0.3))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                AppStrings.of(context)?.or ?? 'or',
                style: TextStyle(color: AppTheme.getTextMuted(context), fontSize: 11),
              ),
            ),
            Expanded(child: Divider(color: AppTheme.getTextMuted(context).withOpacity(0.3))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSecondaryButton(
                onPressed: () => _pickFile(provider),
                icon: Icons.folder_open_rounded,
                label: AppStrings.of(context)?.fromFile ?? 'File',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSecondaryButton(
                onPressed: () => _showQrImportDialog(context),
                icon: Icons.qr_code_scanner_rounded,
                label: AppStrings.of(context)?.scanToImport ?? 'QR',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required IconData prefixIcon,
    bool autofocus = false,
  }) {
    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, child) {
        final isFocused = focusNode.hasFocus;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isFocused ? AppTheme.getPrimaryColor(context) : Colors.transparent,
              width: 2,
            ),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: autofocus,
            style: TextStyle(color: AppTheme.getTextPrimary(context), fontSize: 14),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(color: AppTheme.getTextMuted(context)),
              prefixIcon: Icon(prefixIcon, color: isFocused ? AppTheme.getPrimaryColor(context) : AppTheme.getTextMuted(context), size: 20),
              filled: true,
              fillColor: AppTheme.getCardColor(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPrimaryButton({
    required VoidCallback? onPressed,
    IconData? icon,
    required String label,
    bool isLoading = false,
  }) {
    return TVFocusable(
      onSelect: onPressed,
      focusScale: 1.02,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.getPrimaryColor(context),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            else if (icon != null)
              Icon(icon, size: 18),
            if (icon != null || isLoading) const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
  }) {
    return TVFocusable(
      onSelect: onPressed,
      focusScale: 1.02,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.getPrimaryColor(context),
          side: BorderSide(color: AppTheme.getPrimaryColor(context).withOpacity(0.5)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportCard({
    required VoidCallback? onPressed,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isPrimary,
  }) {
    return TVFocusable(
      onSelect: onPressed,
      focusScale: 1.02,
      showFocusBorder: true,
      builder: (context, isFocused, child) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: isPrimary && isFocused ? AppTheme.getGradient(context) : null,
            color: isPrimary && !isFocused
                ? AppTheme.getPrimaryColor(context)
                : !isPrimary && isFocused
                    ? AppTheme.getCardColor(context)
                    : AppTheme.getCardColor(context).withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: !isPrimary
                ? Border.all(
                    color: isFocused ? AppTheme.getPrimaryColor(context) : AppTheme.getPrimaryColor(context).withOpacity(0.3),
                    width: 2,
                  )
                : null,
          ),
          child: child,
        );
      },
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isPrimary ? Colors.white.withOpacity(0.2) : AppTheme.getPrimaryColor(context).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isPrimary ? Colors.white : AppTheme.getPrimaryColor(context),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isPrimary ? Colors.white : AppTheme.getTextPrimary(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isPrimary ? Colors.white.withOpacity(0.8) : AppTheme.getTextSecondary(context),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: isPrimary ? Colors.white : AppTheme.getTextMuted(context),
            size: 14,
          ),
        ],
      ),
    );
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
        provider.setActivePlaylist(playlist, favoritesProvider: context.read<FavoritesProvider>());
        await context.read<ChannelProvider>().loadChannels(playlist.id!);

        if (mounted) {
          final settingsProvider = context.read<SettingsProvider>();
          final epgProvider = context.read<EpgProvider>();
          
          if (settingsProvider.enableEpg) {
            final playlistEpgUrl = provider.lastExtractedEpgUrl;
            final fallbackEpgUrl = settingsProvider.epgUrl;
            
            if (playlistEpgUrl != null && playlistEpgUrl.isNotEmpty) {
              await epgProvider.loadEpg(playlistEpgUrl, fallbackUrl: fallbackEpgUrl);
            } else if (fallbackEpgUrl != null && fallbackEpgUrl.isNotEmpty) {
              await epgProvider.loadEpg(fallbackEpgUrl);
            }
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text((AppStrings.of(context)?.playlistAdded ?? 'Added "{name}"').replaceAll('{name}', playlist.name)),
              backgroundColor: AppTheme.successColor,
            ),
          );
          Navigator.pop(context, true);
        }
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

  Future<void> _showQrImportDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const QrImportDialog(),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.of(context)?.playlistImported ?? 'Playlist imported successfully'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  Future<void> _pickFile(PlaylistProvider provider) async {
    try {
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
            if (playlist != null) {
              provider.setActivePlaylist(playlist, favoritesProvider: context.read<FavoritesProvider>());
              await context.read<ChannelProvider>().loadChannels(playlist.id!);

              if (mounted) {
                final settingsProvider = context.read<SettingsProvider>();
                final epgProvider = context.read<EpgProvider>();
                
                if (settingsProvider.enableEpg) {
                  final playlistEpgUrl = provider.lastExtractedEpgUrl;
                  final fallbackEpgUrl = settingsProvider.epgUrl;
                  
                  if (playlistEpgUrl != null && playlistEpgUrl.isNotEmpty) {
                    await epgProvider.loadEpg(playlistEpgUrl, fallbackUrl: fallbackEpgUrl);
                  } else if (fallbackEpgUrl != null && fallbackEpgUrl.isNotEmpty) {
                    await epgProvider.loadEpg(fallbackEpgUrl);
                  }
                }
              }
            }

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppStrings.of(context)?.playlistImported ?? 'Playlist imported successfully'),
                backgroundColor: AppTheme.successColor,
              ),
            );
            Navigator.pop(context, true);
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: $e'),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text((AppStrings.of(context)?.errorPickingFile ?? 'Error picking file: {error}').replaceAll('{error}', '$e')),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}
