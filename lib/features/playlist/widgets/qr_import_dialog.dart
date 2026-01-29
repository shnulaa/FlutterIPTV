import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/services/local_server_service.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../../core/i18n/app_strings.dart';
import '../../channels/providers/channel_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../epg/providers/epg_provider.dart';
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
    ServiceLocator.log.d('开始启动本地服务器...');

    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Set up callbacks
    _serverService.onUrlReceived = _handleUrlReceived;
    _serverService.onContentReceived = _handleContentReceived;

    final success = await _serverService.start();
    ServiceLocator.log.d('服务器启动结果: ${success ? "成功" : "失败"}');
    if (success) {
      ServiceLocator.log.d('服务器URL: ${_serverService.serverUrl}');
    }

    setState(() {
      _isLoading = false;
      _isServerRunning = success;
      if (!success) {
        // 使用服务器返回的详细错误信息
        _error = _serverService.lastError ?? 
                (AppStrings.of(context)?.serverStartFailed ?? 'Failed to start local server. Please check network connection.');
      }
    });
  }

  void _handleUrlReceived(String url, String name) async {
    if (_isImporting) return;

    ServiceLocator.log.d('收到URL导入请求 - 名称: $name, URL: $url');

    setState(() {
      _isImporting = true;
      _receivedMessage = '${AppStrings.of(context)?.importingPlaylist ?? "Importing"}: $name';
    });

    try {
      final provider = context.read<PlaylistProvider>();
      ServiceLocator.log.d('开始通过URL添加播放列表...');
      final playlist = await provider.addPlaylistFromUrl(name, url);

      if (playlist != null && mounted) {
        ServiceLocator.log.d('播放列表添加成功: ${playlist.name} (ID: ${playlist.id})');

        // 设置新导入的播放列表为激活状态
        final playlistProvider = context.read<PlaylistProvider>();
        final favoritesProvider = context.read<FavoritesProvider>();
        playlistProvider.setActivePlaylist(playlist, favoritesProvider: favoritesProvider);

        // 加载新播放列表的频道
        final channelProvider = context.read<ChannelProvider>();
        if (playlist.id != null) {
          ServiceLocator.log.d('加载新导入播放列表的频道...');
          await channelProvider.loadChannels(playlist.id!);
        }

        // Auto-load EPG: Try playlist EPG URL first, fallback to settings EPG URL
        if (mounted) {
          final settingsProvider = context.read<SettingsProvider>();
          final epgProvider = context.read<EpgProvider>();
          
          if (settingsProvider.enableEpg) {
            final playlistEpgUrl = provider.lastExtractedEpgUrl;
            final fallbackEpgUrl = settingsProvider.epgUrl;
            
            if (playlistEpgUrl != null && playlistEpgUrl.isNotEmpty) {
              ServiceLocator.log.d('加载播放列表EPG: $playlistEpgUrl (兜底: $fallbackEpgUrl)');
              await epgProvider.loadEpg(playlistEpgUrl, fallbackUrl: fallbackEpgUrl);
            } else if (fallbackEpgUrl != null && fallbackEpgUrl.isNotEmpty) {
              ServiceLocator.log.d('使用兜底EPG URL: $fallbackEpgUrl');
              await epgProvider.loadEpg(fallbackEpgUrl);
            }
          }
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
        ServiceLocator.log.d('播放列表添加失败');
        setState(() {
          _receivedMessage = '✗ ${AppStrings.of(context)?.importFailed ?? "Import failed"}';
          _isImporting = false;
        });
      }
    } catch (e) {
      ServiceLocator.log.d('URL导入过程中发生错误: $e');
      ServiceLocator.log.d('错误堆栈: ${StackTrace.current}');
      setState(() {
        _receivedMessage = '✗ ${AppStrings.of(context)?.importFailed ?? "Import failed"}: $e';
        _isImporting = false;
      });
    }
  }

  void _handleContentReceived(String content, String name) async {
    if (_isImporting) return;

    ServiceLocator.log.d('收到内容导入请求 - 名称: $name, 内容长度: ${content.length}');

    setState(() {
      _isImporting = true;
      _receivedMessage = '${AppStrings.of(context)?.importingPlaylist ?? "Importing"}: $name';
    });

    try {
      final provider = context.read<PlaylistProvider>();
      ServiceLocator.log.d('开始通过内容添加播放列表...');
      final playlist = await provider.addPlaylistFromContent(name, content);

      if (playlist != null && mounted) {
        ServiceLocator.log.d('播放列表添加成功: ${playlist.name} (ID: ${playlist.id})');

        // 设置新导入的播放列表为激活状态
        final playlistProvider = context.read<PlaylistProvider>();
        final favoritesProvider = context.read<FavoritesProvider>();
        playlistProvider.setActivePlaylist(playlist, favoritesProvider: favoritesProvider);

        // 加载新播放列表的频道
        final channelProvider = context.read<ChannelProvider>();
        if (playlist.id != null) {
          ServiceLocator.log.d('加载新导入播放列表的频道...');
          await channelProvider.loadChannels(playlist.id!);
        }

        // Auto-load EPG: Try playlist EPG URL first, fallback to settings EPG URL
        if (mounted) {
          final settingsProvider = context.read<SettingsProvider>();
          final epgProvider = context.read<EpgProvider>();
          
          if (settingsProvider.enableEpg) {
            final playlistEpgUrl = provider.lastExtractedEpgUrl;
            final fallbackEpgUrl = settingsProvider.epgUrl;
            
            if (playlistEpgUrl != null && playlistEpgUrl.isNotEmpty) {
              ServiceLocator.log.d('加载播放列表EPG: $playlistEpgUrl (兜底: $fallbackEpgUrl)');
              await epgProvider.loadEpg(playlistEpgUrl, fallbackUrl: fallbackEpgUrl);
            } else if (fallbackEpgUrl != null && fallbackEpgUrl.isNotEmpty) {
              ServiceLocator.log.d('使用兜底EPG URL: $fallbackEpgUrl');
              await epgProvider.loadEpg(fallbackEpgUrl);
            }
          }
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
        ServiceLocator.log.d('播放列表添加失败');
        setState(() {
          _receivedMessage = '✗ ${AppStrings.of(context)?.importFailed ?? "Import failed"}';
          _isImporting = false;
        });
      }
    } catch (e) {
      ServiceLocator.log.d('内容导入过程中发生错误: $e');
      ServiceLocator.log.d('错误堆栈: ${StackTrace.current}');
      setState(() {
        _receivedMessage = '✗ ${AppStrings.of(context)?.importFailed ?? "Import failed"}: $e';
        _isImporting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    // 手机横屏：宽度600-900，高度小于宽度
    final isLandscape = screenWidth > 600 && screenWidth < 900 && screenHeight < screenWidth;
    final isMobile = screenWidth < 600;
    
    return Dialog(
      backgroundColor: AppTheme.getSurfaceColor(context),
      insetPadding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isLandscape ? 12 : 20),  // 横屏时圆角更小
        child: Container(
          width: isLandscape ? 480 : (isMobile ? null : 520),  // 横屏时宽度更小
          constraints: isLandscape 
              ? const BoxConstraints(maxHeight: 350)  // 横屏时限制高度
              : (isMobile ? const BoxConstraints(maxWidth: 400) : null),
          decoration: BoxDecoration(
            color: AppTheme.getSurfaceColor(context),
          ),
          padding: EdgeInsets.all(isLandscape ? 16 : (isMobile ? 16 : 24)),  // 横屏时padding更小
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isLandscape ? 6 : 8),  // 横屏时padding更小
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withAlpha(51),
                      borderRadius: BorderRadius.circular(isLandscape ? 8 : 10),
                    ),
                    child: Icon(
                      Icons.qr_code_scanner_rounded,
                      color: AppTheme.primaryColor,
                      size: isLandscape ? 18 : 22,  // 横屏时图标更小
                    ),
                  ),
                  SizedBox(width: isLandscape ? 10 : 12),  // 横屏时间距更小
                  Expanded(
                    child: Text(
                      AppStrings.of(context)?.scanToImport ?? 'Scan to Import Playlist',
                      style: TextStyle(
                        color: AppTheme.getTextPrimary(context),
                        fontSize: isLandscape ? 14 : (isMobile ? 16 : 18),  // 横屏时字体更小
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: isLandscape ? 12 : 20),  // 横屏时间距更小

              // Content
              if (_isLoading) 
                _buildLoadingState(isLandscape) 
              else if (_error != null) 
                _buildErrorState(isLandscape) 
              else if (_isServerRunning) 
                _buildQrCodeState(isMobile, isLandscape),

              SizedBox(height: isLandscape ? 12 : 20),  // 横屏时间距更小

              // Close button
              TVFocusable(
                autofocus: true,
                onSelect: () => Navigator.of(context).pop(false),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.getTextSecondary(context),
                      side: BorderSide(color: AppTheme.getCardColor(context)),
                      padding: EdgeInsets.symmetric(vertical: isLandscape ? 8 : 12),  // 横屏时padding更小
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(isLandscape ? 6 : 10),
                      ),
                    ),
                    child: Text(
                      AppStrings.of(context)?.close ?? 'Close',
                      style: TextStyle(fontSize: isLandscape ? 11 : 14),  // 横屏时字体更小
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

  Widget _buildLoadingState(bool isLandscape) {
    return Column(
      children: [
        SizedBox(
          width: isLandscape ? 32 : 48,  // 横屏时进度条更小
          height: isLandscape ? 32 : 48,
          child: const CircularProgressIndicator(
            strokeWidth: 3,
            color: AppTheme.primaryColor,
          ),
        ),
        SizedBox(height: isLandscape ? 10 : 16),  // 横屏时间距更小
        Text(
          AppStrings.of(context)?.startingServer ?? 'Starting server...',
          style: TextStyle(
            color: AppTheme.getTextSecondary(context),
            fontSize: isLandscape ? 11 : 14,  // 横屏时字体更小
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(bool isLandscape) {
    return Column(
      children: [
        Icon(
          Icons.error_outline_rounded,
          color: AppTheme.errorColor,
          size: isLandscape ? 32 : 48,  // 横屏时图标更小
        ),
        SizedBox(height: isLandscape ? 10 : 16),  // 横屏时间距更小
        Text(
          _error!,
          style: TextStyle(
            color: AppTheme.errorColor,
            fontSize: isLandscape ? 11 : 14,  // 横屏时字体更小
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: isLandscape ? 10 : 16),  // 横屏时间距更小
        TVFocusable(
          onSelect: _startServer,
          child: ElevatedButton(
            onPressed: _startServer,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isLandscape ? 16 : 24,
                vertical: isLandscape ? 8 : 12,
              ),
            ),
            child: Text(
              AppStrings.of(context)?.retry ?? 'Retry',
              style: TextStyle(fontSize: isLandscape ? 11 : 14),  // 横屏时字体更小
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQrCodeState(bool isMobile, bool isLandscape) {
    if (isMobile || isLandscape) {
      // 手机端（竖屏或横屏）：纵向布局
      return Column(
        children: [
          // QR Code
          Container(
            padding: EdgeInsets.all(isLandscape ? 8 : 12),  // 横屏时padding更小
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(isLandscape ? 8 : 12),
            ),
            child: QrImageView(
              data: _serverService.importUrl,
              version: QrVersions.auto,
              size: isLandscape ? 120 : 200,  // 横屏时二维码更小
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
            ),
          ),

          SizedBox(height: isLandscape ? 10 : 16),  // 横屏时间距更小

          // Instructions
          Container(
            padding: EdgeInsets.all(isLandscape ? 8 : 12),  // 横屏时padding更小
            decoration: BoxDecoration(
              color: AppTheme.getCardColor(context),
              borderRadius: BorderRadius.circular(isLandscape ? 8 : 10),
            ),
            child: Column(
              children: [
                _buildStep('1', AppStrings.of(context)?.qrStep1 ?? 'Scan the QR code with your phone', isLandscape),
                SizedBox(height: isLandscape ? 6 : 8),  // 横屏时间距更小
                _buildStep('2', AppStrings.of(context)?.qrStep2 ?? 'Enter URL or upload file on the webpage', isLandscape),
                SizedBox(height: isLandscape ? 6 : 8),  // 横屏时间距更小
                _buildStep('3', AppStrings.of(context)?.qrStep3 ?? 'Click import, TV receives automatically', isLandscape),
              ],
            ),
          ),

          SizedBox(height: isLandscape ? 8 : 12),  // 横屏时间距更小

          // Server URL
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isLandscape ? 8 : 12,
              vertical: isLandscape ? 6 : 10,
            ),
            decoration: BoxDecoration(
              color: AppTheme.getCardColor(context).withAlpha(128),
              borderRadius: BorderRadius.circular(isLandscape ? 6 : 8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.wifi_rounded,
                  color: AppTheme.getTextMuted(context),
                  size: isLandscape ? 12 : 16,  // 横屏时图标更小
                ),
                SizedBox(width: isLandscape ? 6 : 8),  // 横屏时间距更小
                Expanded(
                  child: Text(
                    _serverService.importUrl,
                    style: TextStyle(
                      color: AppTheme.getTextMuted(context),
                      fontSize: isLandscape ? 9 : 11,  // 横屏时字体更小
                      fontFamily: 'monospace',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Status message
          if (_receivedMessage != null) ...[
            SizedBox(height: isLandscape ? 8 : 12),  // 横屏时间距更小
            Container(
              padding: EdgeInsets.all(isLandscape ? 6 : 10),  // 横屏时padding更小
              decoration: BoxDecoration(
                color: _receivedMessage!.contains('✓')
                    ? Colors.green.withAlpha(51)
                    : _receivedMessage!.contains('✗')
                        ? Colors.red.withAlpha(51)
                        : AppTheme.primaryColor.withAlpha(51),
                borderRadius: BorderRadius.circular(isLandscape ? 6 : 8),
              ),
              child: Row(
                children: [
                  if (_isImporting)
                    SizedBox(
                      width: isLandscape ? 12 : 14,  // 横屏时进度条更小
                      height: isLandscape ? 12 : 14,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  if (_isImporting) SizedBox(width: isLandscape ? 6 : 10),  // 横屏时间距更小
                  Expanded(
                    child: Text(
                      _receivedMessage!,
                      style: TextStyle(
                        color: _receivedMessage!.contains('✓')
                            ? Colors.green
                            : _receivedMessage!.contains('✗')
                                ? Colors.red
                                : AppTheme.getTextPrimary(context),
                        fontWeight: FontWeight.w500,
                        fontSize: isLandscape ? 10 : 12,  // 横屏时字体更小
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    }
    
    // TV/桌面端：横向布局
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
            data: _serverService.importUrl,
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
                  color: AppTheme.getCardColor(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    _buildStep('1', AppStrings.of(context)?.qrStep1 ?? 'Scan the QR code with your phone', false),
                    const SizedBox(height: 8),
                    _buildStep('2', AppStrings.of(context)?.qrStep2 ?? 'Enter URL or upload file on the webpage', false),
                    const SizedBox(height: 8),
                    _buildStep('3', AppStrings.of(context)?.qrStep3 ?? 'Click import, TV receives automatically', false),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Server URL
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.getCardColor(context).withAlpha(128),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.wifi_rounded,
                      color: AppTheme.getTextMuted(context),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _serverService.importUrl,
                        style: TextStyle(
                          color: AppTheme.getTextMuted(context),
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
                                    : AppTheme.getTextPrimary(context),
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

  Widget _buildStep(String number, String text, bool isLandscape) {
    return Row(
      children: [
        Container(
          width: isLandscape ? 18 : 22,  // 横屏时圆圈更小
          height: isLandscape ? 18 : 22,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withAlpha(51),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontSize: isLandscape ? 10 : 12,  // 横屏时字体更小
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SizedBox(width: isLandscape ? 6 : 10),  // 横屏时间距更小
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: AppTheme.getTextSecondary(context),
              fontSize: isLandscape ? 10 : 13,  // 横屏时字体更小
            ),
          ),
        ),
      ],
    );
  }
}
