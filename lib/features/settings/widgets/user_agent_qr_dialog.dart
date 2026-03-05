import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/services/local_server_service.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/widgets/tv_focusable.dart';

/// Dialog for User-Agent input via QR code
class UserAgentQRDialog extends StatefulWidget {
  final Function(String userAgent) onUserAgentReceived;
  
  const UserAgentQRDialog({
    super.key,
    required this.onUserAgentReceived,
  });

  @override
  State<UserAgentQRDialog> createState() => _UserAgentQRDialogState();
}

class _UserAgentQRDialogState extends State<UserAgentQRDialog> {
  final LocalServerService _serverService = LocalServerService();
  bool _isLoading = true;
  bool _isServerRunning = false;
  String? _error;
  bool _userAgentReceived = false;

  @override
  void initState() {
    super.initState();
    _startServer();
  }

  @override
  void dispose() {
    _serverService.onUserAgentReceived = null;
    _serverService.stop();
    super.dispose();
  }

  Future<void> _startServer() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // 设置 User-Agent 接收回调
    _serverService.onUserAgentReceived = (userAgent) {
      ServiceLocator.log.i('收到 User-Agent', tag: 'UserAgentQRDialog');
      ServiceLocator.log.d('User-Agent: ', tag: 'UserAgentQRDialog');
      
      if (mounted) {
        setState(() {
          _userAgentReceived = true;
        });
        
        // 调用回调
        widget.onUserAgentReceived(userAgent);
        
        // 延迟关闭对话框
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    };

    // 启动服务器
    final success = await _serverService.start();

    setState(() {
      _isLoading = false;
      _isServerRunning = success;
      if (!success) {
        _error = _serverService.lastError ?? '启动服务器失败，请检查网络连接';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context)!;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    return Dialog(
      backgroundColor: AppTheme.getSurfaceColor(context),
      insetPadding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: isMobile ? null : 520,
          constraints: isMobile ? const BoxConstraints(maxWidth: 250) : null,
          decoration: BoxDecoration(
            color: AppTheme.getSurfaceColor(context),
          ),
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              _buildTitle(context, strings, isMobile),

              const SizedBox(height: 20),

              // Content
              if (_isLoading)
                _buildLoadingState(strings)
              else if (_error != null)
                _buildErrorState(strings)
              else if (_isServerRunning)
                _buildQrCodeState(strings, isMobile),

              const SizedBox(height: 20),

              // Close button
              TVFocusable(
                autofocus: true,
                onSelect: () => Navigator.of(context).pop(),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.getTextSecondary(context),
                      side: BorderSide(color: AppTheme.getCardColor(context)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(strings.close),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context, AppStrings strings, bool isMobile) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.getPrimaryColor(context).withAlpha(51),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.qr_code_scanner_rounded,
            color: AppTheme.getPrimaryColor(context),
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            strings.userAgentScanQR,
            style: TextStyle(
              color: AppTheme.getTextPrimary(context),
              fontSize: isMobile ? 16 : 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState(AppStrings strings) {
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
          strings.preparingConfig,
          style: TextStyle(color: AppTheme.getTextSecondary(context)),
        ),
      ],
    );
  }

  Widget _buildErrorState(AppStrings strings) {
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
              foregroundColor: Colors.white,
            ),
            child: Text(strings.refresh),
          ),
        ),
      ],
    );
  }

  Widget _buildQrCodeState(AppStrings strings, bool isMobile) {
    // 生成 User-Agent 输入 URL
    final userAgentUrl = '\/user-agent';
    
    if (isMobile) {
      // 手机端：纵向布局
      return Column(
        children: [
          // QR Code
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: QrImageView(
              data: userAgentUrl,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
            ),
          ),

          const SizedBox(height: 16),

          // Instructions
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.getCardColor(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _buildStep('1', strings.webdavConfigStep1),
                const SizedBox(height: 8),
                _buildStep('2', '在网页中输入 User-Agent'),
                const SizedBox(height: 8),
                _buildStep('3', '输入完成后将自动应用'),
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
                    userAgentUrl,
                    style: TextStyle(
                      color: AppTheme.getTextMuted(context),
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Status
          if (_userAgentReceived) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(51),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    color: Colors.green,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      strings.userAgentSaved,
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(51),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Colors.blue,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      strings.configReady,
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 12,
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
            data: userAgentUrl,
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
                    _buildStep('1', strings.webdavConfigStep1),
                    const SizedBox(height: 8),
                    _buildStep('2', '在网页中输入 User-Agent'),
                    const SizedBox(height: 8),
                    _buildStep('3', '输入完成后将自动应用'),
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
                        userAgentUrl,
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

              // Status
              if (_userAgentReceived) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(51),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        color: Colors.green,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          strings.userAgentSaved,
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(51),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: Colors.blue,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          strings.configReady,
                          style: const TextStyle(
                            color: Colors.blue,
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
            color: AppTheme.getPrimaryColor(context).withAlpha(51),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: AppTheme.getPrimaryColor(context),
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
            style: TextStyle(
              color: AppTheme.getTextSecondary(context),
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
