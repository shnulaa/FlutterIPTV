import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/services/local_server_service.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/widgets/tv_focusable.dart';

/// Dialog for exporting logs via QR code
class QrLogExportDialog extends StatefulWidget {
  const QrLogExportDialog({super.key});

  @override
  State<QrLogExportDialog> createState() => _QrLogExportDialogState();
}

class _QrLogExportDialogState extends State<QrLogExportDialog> {
  final LocalServerService _serverService = LocalServerService();
  bool _isLoading = true;
  bool _isServerRunning = false;
  String? _error;
  String? _logContent;

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
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // 先导出日志内容
    try {
      final logFiles = await ServiceLocator.log.getLogFiles();
      if (logFiles.isEmpty) {
        setState(() {
          _isLoading = false;
          _error = '没有可用的日志文件';
        });
        return;
      }

      // 合并所有日志文件
      final buffer = StringBuffer();
      buffer.writeln('========================================');
      buffer.writeln('Lotus IPTV 日志导出');
      buffer.writeln('导出时间: ${DateTime.now()}');
      buffer.writeln('========================================\n');

      for (final file in logFiles) {
        buffer.writeln('\n========== ${file.path.split('/').last.split('\\').last} ==========\n');
        final content = await file.readAsString();
        buffer.writeln(content);
      }

      _logContent = buffer.toString();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = '读取日志文件失败: $e';
      });
      return;
    }

    // 启动服务器
    final success = await _serverService.start();
    
    // 设置日志内容到服务器
    if (success && _logContent != null) {
      _serverService.setLogContent(_logContent!);
    }

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
              Row(
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
                      '扫码查看日志',
                      style: TextStyle(
                        color: AppTheme.getTextPrimary(context),
                        fontSize: isMobile ? 16 : 18,
                        fontWeight: FontWeight.bold,
                      ),
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
                _buildQrCodeState(isMobile),

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
                    child: const Text('关闭'),
                  ),
                ),
              ),
            ],
          ),
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
          '正在准备日志...',
          style: TextStyle(color: AppTheme.getTextSecondary(context)),
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
              foregroundColor: Colors.white,
            ),
            child: const Text('重试'),
          ),
        ),
      ],
    );
  }

  Widget _buildQrCodeState(bool isMobile) {
    // 生成日志查看URL（包含日志内容）
    final logUrl = '${_serverService.serverUrl}/logs';
    
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
              data: logUrl,
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
                _buildStep('1', '使用手机扫描二维码'),
                const SizedBox(height: 8),
                _buildStep('2', '在浏览器中查看日志内容'),
                const SizedBox(height: 8),
                _buildStep('3', '可以复制或分享日志给开发者'),
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
                    logUrl,
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

          // Log info
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
                    '日志已准备就绪，大小: ${(_logContent?.length ?? 0) ~/ 1024} KB',
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
            data: logUrl,
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
                    _buildStep('1', '使用手机扫描二维码'),
                    const SizedBox(height: 8),
                    _buildStep('2', '在浏览器中查看日志内容'),
                    const SizedBox(height: 8),
                    _buildStep('3', '可以复制或分享日志给开发者'),
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
                        logUrl,
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

              // Log info
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
                        '日志已准备就绪，大小: ${(_logContent?.length ?? 0) ~/ 1024} KB',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
