import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/services/local_server_service.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../../core/i18n/app_strings.dart';
import '../../channels/providers/channel_provider.dart';
import '../providers/playlist_provider.dart';
import '../../favorites/providers/favorites_provider.dart';

/// Dialog for scanning QR code to import playlist on TV
class QrImportDialog extends StatefulWidget {
  const QrImportDialog({super.key});

  @override
  State<QrImportDialog> createState() => _QrImportDialogState();
}

class _QrImportDialogState extends State<QrImportDialog> {
  final LocalServerService _serverService = LocalServerService();
  bool _isLoading = true;
  bool _isServerRunning = false;
  String? _error;
  String? _receivedMessage;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _startServer();
  }

  @override
  void dispose() {
    _serverService.stop();
    super.dispose();
  }

  Future<void> _startServer() async {
    debugPrint('DEBUG: 开始启动本地服务器...');

    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Set up callbacks
    _serverService.onUrlReceived = _handleUrlReceived;
    _serverService.onContentReceived = _handleContentReceived;

    final success = await _serverService.start();
    debugPrint('DEBUG: 服务器启动结果: ${success ? "成功" : "失败"}');
    if (success) {
      debugPrint('DEBUG: 服务器URL: ${_serverService.serverUrl}');
    }

    setState(() {
      _isLoading = false;
      _isServerRunning = success;
      if (!success) {
        _error = AppStrings.of(context)?.serverStartFailed ?? 'Failed to start local server. Please check network connection.';
      }
    });
  }

  void _handleUrlReceived(String url, String name) async {
    if (_isImporting) return;

    debugPrint('DEBUG: 收到URL导入请求 - 名称: $name, URL: $url');

    setState(() {
      _isImporting = true;
      _receivedMessage = '${AppStrings.of(context)?.importingPlaylist ?? "Importing"}: $name';
    });

    try {
      final provider = context.read<PlaylistProvider>();
      debugPrint('DEBUG: 开始通过URL添加播放列表...');
      final playlist = await provider.addPlaylistFromUrl(name, url);

      if (playlist != null && mounted) {
        debugPrint('DEBUG: 播放列表添加成功: ${playlist.name} (ID: ${playlist.id})');

        // 设置新导入的播放列表为激活状态
        final playlistProvider = context.read<PlaylistProvider>();
        final favoritesProvider = context.read<FavoritesProvider>();
        playlistProvider.setActivePlaylist(playlist,
            favoritesProvider: favoritesProvider);

        // 加载新播放列表的频道
        final channelProvider = context.read<ChannelProvider>();
        if (playlist.id != null) {
          debugPrint('DEBUG: 加载新导入播放列表的频道...');
          await channelProvider.loadChannels(playlist.id!);
        }

        setState(() {
          _receivedMessage = '✓ ${AppStrings.of(context)?.importSuccess ?? "Import successful"}: ${playlist.name}';
          _isImporting = false;
        });

        // Auto close after success
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        debugPrint('DEBUG: 播放列表添加失败');
        setState(() {
          _receivedMessage = '✗ ${AppStrings.of(context)?.importFailed ?? "Import failed"}';
          _isImporting = false;
        });
      }
    } catch (e) {
      debugPrint('DEBUG: URL导入过程中发生错误: $e');
      debugPrint('DEBUG: 错误堆栈: ${StackTrace.current}');
      setState(() {
        _receivedMessage = '✗ ${AppStrings.of(context)?.importFailed ?? "Import failed"}: $e';
        _isImporting = false;
      });
    }
  }

  void _handleContentReceived(String content, String name) async {
    if (_isImporting) return;

    debugPrint('DEBUG: 收到内容导入请求 - 名称: $name, 内容长度: ${content.length}');

    setState(() {
      _isImporting = true;
      _receivedMessage = '${AppStrings.of(context)?.importingPlaylist ?? "Importing"}: $name';
    });

    try {
      final provider = context.read<PlaylistProvider>();
      debugPrint('DEBUG: 开始通过内容添加播放列表...');
      final playlist = await provider.addPlaylistFromContent(name, content);

      if (playlist != null && mounted) {
        debugPrint('DEBUG: 播放列表添加成功: ${playlist.name} (ID: ${playlist.id})');

        // 设置新导入的播放列表为激活状态
        final playlistProvider = context.read<PlaylistProvider>();
        final favoritesProvider = context.read<FavoritesProvider>();
        playlistProvider.setActivePlaylist(playlist,
            favoritesProvider: favoritesProvider);

        // 加载新播放列表的频道
        final channelProvider = context.read<ChannelProvider>();
        if (playlist.id != null) {
          debugPrint('DEBUG: 加载新导入播放列表的频道...');
          await channelProvider.loadChannels(playlist.id!);
        }

        setState(() {
          _receivedMessage = '✓ ${AppStrings.of(context)?.importSuccess ?? "Import successful"}: ${playlist.name}';
          _isImporting = false;
        });

        // Auto close after success
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        debugPrint('DEBUG: 播放列表添加失败');
        setState(() {
          _receivedMessage = '✗ ${AppStrings.of(context)?.importFailed ?? "Import failed"}';
          _isImporting = false;
        });
      }
    } catch (e) {
      debugPrint('DEBUG: 内容导入过程中发生错误: $e');
      debugPrint('DEBUG: 错误堆栈: ${StackTrace.current}');
      setState(() {
        _receivedMessage = '✗ ${AppStrings.of(context)?.importFailed ?? "Import failed"}: $e';
        _isImporting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withAlpha(51),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: AppTheme.primaryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  AppStrings.of(context)?.scanToImport ?? 'Scan to Import Playlist',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Content
            if (_isLoading)
              _buildLoadingState()
            else if (_error != null)
              _buildErrorState()
            else if (_isServerRunning)
              _buildQrCodeState(),

            const SizedBox(height: 20),

            // Close button
            TVFocusable(
              autofocus: true,
              onSelect: () => Navigator.of(context).pop(false),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: const BorderSide(color: AppTheme.cardColor),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(AppStrings.of(context)?.close ?? 'Close'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        const SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          AppStrings.of(context)?.startingServer ?? 'Starting server...',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Column(
      children: [
        const Icon(
          Icons.error_outline_rounded,
          color: AppTheme.errorColor,
          size: 48,
        ),
        const SizedBox(height: 16),
        Text(
          _error!,
          style: const TextStyle(color: AppTheme.errorColor),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        TVFocusable(
          onSelect: _startServer,
          child: ElevatedButton(
            onPressed: _startServer,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: Text(AppStrings.of(context)?.retry ?? 'Retry'),
          ),
        ),
      ],
    );
  }

  Widget _buildQrCodeState() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: QR Code
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: QrImageView(
            data: _serverService.serverUrl,
            version: QrVersions.auto,
            size: 160,
            backgroundColor: Colors.white,
            errorCorrectionLevel: QrErrorCorrectLevel.M,
          ),
        ),

        const SizedBox(width: 20),

        // Right: Instructions and URL
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Instructions
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    _buildStep('1', AppStrings.of(context)?.qrStep1 ?? 'Scan the QR code with your phone'),
                    const SizedBox(height: 8),
                    _buildStep('2', AppStrings.of(context)?.qrStep2 ?? 'Enter URL or upload file on the webpage'),
                    const SizedBox(height: 8),
                    _buildStep('3', AppStrings.of(context)?.qrStep3 ?? 'Click import, TV receives automatically'),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Server URL
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor.withAlpha(128),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.wifi_rounded,
                      color: AppTheme.textMuted,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _serverService.serverUrl,
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Status message
              if (_receivedMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _receivedMessage!.contains('✓')
                        ? Colors.green.withAlpha(51)
                        : _receivedMessage!.contains('✗')
                            ? Colors.red.withAlpha(51)
                            : AppTheme.primaryColor.withAlpha(51),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      if (_isImporting)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      if (_isImporting) const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _receivedMessage!,
                          style: TextStyle(
                            color: _receivedMessage!.contains('✓')
                                ? Colors.green
                                : _receivedMessage!.contains('✗')
                                    ? Colors.red
                                    : AppTheme.textPrimary,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep(String number, String text) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withAlpha(51),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
