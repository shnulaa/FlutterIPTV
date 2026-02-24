import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/platform/platform_detector.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/utils/app_restart_helper.dart';
import '../providers/backup_provider.dart';

/// WebDAV 备份区域组件
class WebDAVBackupSection extends StatefulWidget {
  const WebDAVBackupSection({super.key});

  @override
  State<WebDAVBackupSection> createState() => _WebDAVBackupSectionState();
}

class _WebDAVBackupSectionState extends State<WebDAVBackupSection> {
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  // 固定远程路径/lotus-iptv，不允许修改
  static const String _fixedRemotePath = '/lotus-iptv';
  bool _obscurePassword = true;
  bool _isTestingConnection = false;
  bool _isRefreshing = false;

  // 显示 loading 对话框
  void _showLoadingDialog(BuildContext context) {
    final textPrimary = AppTheme.getTextPrimary(context);
    final textSecondary = AppTheme.getTextSecondary(context);
    final cardColor = AppTheme.getCardColor(context);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Consumer<BackupProvider>(
          builder: (context, provider, child) {
            return AlertDialog(
              backgroundColor: cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    provider.progressMessage,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (provider.progress > 0) ...[
                    const SizedBox(height: 16),
                    LinearProgressIndicator(value: provider.progress),
                    const SizedBox(height: 8),
                    Text(
                      '${(provider.progress * 100).toInt()}%',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  //获取响应式样式（横屏适配）
  Map<String, dynamic> _getResponsiveStyle(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = PlatformDetector.isMobile;
    final isLandscape = isMobile && screenWidth > 600 && screenWidth < 900 && screenHeight < screenWidth;
    final isTV = PlatformDetector.isTV;
    
    return {
      'isLandscape': isLandscape,
      'containerPadding': isLandscape ? 6.0 : (isTV ? 32.0 : 20.0),
      'cardPadding': isLandscape ? 8.0 : 20.0,
      'titleFontSize': isLandscape ? 10.5 : (isTV ? 18.0 : 16.0),
      'bodyFontSize': isLandscape ? 9.5 : (isTV ? 16.0 : 14.0),
      'smallFontSize': isLandscape ? 8.5 : (isTV ? 14.0 : 13.0),
      'iconSize': isLandscape ? 13.0 : 20.0,
      'spacing': isLandscape ? 4.0 : (isTV ? 24.0 : 16.0),
      'sectionSpacing': isLandscape ? 8.0 : 24.0,
      'buttonPadding': EdgeInsets.symmetric(
        horizontal: isLandscape ? 8.0 : 16.0,
        vertical: isLandscape ? 4.0 : 12.0,
      ),
    };
  }

  @override
  void initState() {
    super.initState();
    _loadConfig();
    // 自动加载 WebDAV 备份列表（只执行一次）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _autoLoadWebDAVBackups();
      }
    });
  }

  void _loadConfig() {
    // SharedPreferences 加载配置
    final url = ServiceLocator.prefs.getString('webdav_url');
    final username = ServiceLocator.prefs.getString('webdav_username');
    final password = ServiceLocator.prefs.getString('webdav_password');

    if (url != null && url.isNotEmpty) {
      _urlController.text = url;
    }
    if (username != null && username.isNotEmpty) {
      _usernameController.text = username;
    }
    if (password != null && password.isNotEmpty) {
      _passwordController.text = password;
    }
  }

  Future<void> _autoLoadWebDAVBackups() async {
    // 如果已配WebDAV，自动加载备份列
    final url = ServiceLocator.prefs.getString('webdav_url');
    final username = ServiceLocator.prefs.getString('webdav_username');
    final password = ServiceLocator.prefs.getString('webdav_password');

    if (url != null && url.isNotEmpty && username != null && username.isNotEmpty) {
      final provider = context.read<BackupProvider>();
      
      // 先配置（不触发通知），使用固定的远程路
      provider.configureWebDAV(
        serverUrl: url,
        username: username,
        password: password ?? '',
        remotePath: _fixedRemotePath, // 使用固定路径
        notify: false, // 关键：不触发通知
      );
      
      try {
        // 加载备份列表（不触发通知，避免死循环
        await provider.loadWebDAVBackups(notify: false);
        // 加载完成后手动触发一次通知来更UI
        if (mounted) {
          setState(() {});
        }
      } catch (e) {
        ServiceLocator.log.w('自动加载 WebDAV 备份列表失败', tag: 'WebDAVBackupSection', error: e);
      }
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context)!;
    final provider = context.watch<BackupProvider>();
    final backgroundColor = AppTheme.getBackgroundColor(context);
    final cardColor = AppTheme.getCardColor(context);
    final textPrimary = AppTheme.getTextPrimary(context);
    final textSecondary = AppTheme.getTextSecondary(context);
    final primaryColor = AppTheme.getPrimaryColor(context);

    // 获取响应式样式
    final style = _getResponsiveStyle(context);
    final isTV = style['isLandscape'] ? false : PlatformDetector.isTV;

    return Container(
      color: backgroundColor,
      child: ListView(
        padding: EdgeInsets.all(style['containerPadding']),
        children: [
          // WebDAV 配置卡片
          Container(
            padding: EdgeInsets.all(style['cardPadding']),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(
                color: AppTheme.getGlassBorderColor(context),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.cloud_rounded, color: primaryColor, size: style['iconSize']),
                    SizedBox(width: style['spacing'] / 2),
                    Text(
                      strings.webdavConfig,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: style['titleFontSize'],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: style['spacing'] * 1.25),
                
                if (!isTV) ...[
                  _buildTextField(
                    controller: _urlController,
                    label: strings.serverUrl,
                    hint: 'http://192.168.50.11:5244/dav/video',
                    icon: Icons.link_rounded,
                  ),
                  SizedBox(height: style['spacing']),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _usernameController,
                          label: strings.username,
                          hint: 'admin',
                          icon: Icons.person_rounded,
                        ),
                      ),
                      SizedBox(width: style['spacing']),
                      Expanded(
                        child: _buildTextField(
                          controller: _passwordController,
                          label: strings.password,
                          obscureText: _obscurePassword,
                          icon: Icons.lock_rounded,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              color: textSecondary,
                              size: style['iconSize'],
                            ),
                            onPressed: () {
                              setState(() => _obscurePassword = !_obscurePassword);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 显示固定的远程路径（只读）
                  Container(
                    padding: EdgeInsets.all(style['isLandscape'] ? 8.0 : 16.0),
                    decoration: BoxDecoration(
                      color: AppTheme.getGlassColor(context),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      border: Border.all(
                        color: AppTheme.getGlassBorderColor(context),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.folder_rounded, size: style['iconSize'], color: textSecondary),
                        SizedBox(width: style['spacing'] * 0.75),
                        Text(
                          '${strings.remotePath}: ',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: style['bodyFontSize'],
                          ),
                        ),
                        Text(
                          _fixedRemotePath,
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: style['bodyFontSize'],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isTestingConnection ? null : _testConnection,
                          icon: _isTestingConnection
                              ? SizedBox(
                                  width: style['iconSize'],
                                  height: style['iconSize'],
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(Icons.wifi_find_rounded, size: style['iconSize']),
                          label: Text(
                            strings.testConnection,
                            style: TextStyle(fontSize: style['bodyFontSize']),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textPrimary,
                            side: BorderSide(color: textSecondary.withOpacity(0.3)),
                            padding: EdgeInsets.symmetric(
                              horizontal: style['isLandscape'] ? 10.0 : 20.0,
                              vertical: style['isLandscape'] ? 5.0 : 14.0,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: style['spacing'] * 0.75),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _saveConfig,
                          icon: Icon(Icons.save_rounded, size: style['iconSize']),
                          label: Text(
                            '保存配置',
                            style: TextStyle(fontSize: style['bodyFontSize']),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: style['isLandscape'] ? 10.0 : 20.0,
                              vertical: style['isLandscape'] ? 5.0 : 14.0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // TV 端使用远程配
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _showRemoteConfig,
                      icon: const Icon(Icons.qr_code_rounded),
                      label: Text(strings.scanToConfig),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          SizedBox(height: style['sectionSpacing']),

          // 备份操作和列
          Row(
            children: [
              Text(
                strings.backupList,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: style['titleFontSize'],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _isRefreshing ? null : _loadWebDAVBackups,
                icon: _isRefreshing
                    ? SizedBox(
                        width: style['iconSize'],
                        height: style['iconSize'],
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.refresh_rounded, size: style['iconSize']),
                label: Text(
                  strings.refresh,
                  style: TextStyle(fontSize: style['bodyFontSize']),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: textPrimary,
                  side: BorderSide(color: textPrimary.withOpacity(0.3)),
                  padding: EdgeInsets.symmetric(
                    horizontal: style['isLandscape'] ? 8.0 : 16.0,
                    vertical: style['isLandscape'] ? 5.0 : 12.0,
                  ),
                ),
              ),
              SizedBox(width: style['spacing'] * 0.75),
              ElevatedButton.icon(
                onPressed: _backupToWebDAV,
                icon: Icon(Icons.cloud_upload_rounded, size: style['iconSize']),
                label: Text(
                  strings.uploadToWebdav,
                  style: TextStyle(fontSize: style['bodyFontSize']),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: style['isLandscape'] ? 8.0 : 16.0,
                    vertical: style['isLandscape'] ? 5.0 : 12.0,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: style['spacing']),

          // WebDAV 备份列表
          if (provider.webdavBackups.isEmpty)
            SizedBox(
              height: 200,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      size: style['iconSize'] * 3.2,
                      color: textSecondary.withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      strings.noBackupsYet,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: style['titleFontSize'],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...provider.webdavBackups.map((backup) => _buildBackupItem(context, backup)).toList(),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool obscureText = false,
    IconData? icon,
    Widget? suffixIcon,
  }) {
    final textPrimary = AppTheme.getTextPrimary(context);
    final textSecondary = AppTheme.getTextSecondary(context);
    final primaryColor = AppTheme.getPrimaryColor(context);
    final style = _getResponsiveStyle(context);
    
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: TextStyle(color: textPrimary, fontSize: style['bodyFontSize']),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon, size: style['iconSize'], color: textSecondary) : null,
        labelStyle: TextStyle(color: textSecondary, fontSize: style['bodyFontSize']),
        hintStyle: TextStyle(color: textSecondary.withOpacity(0.5), fontSize: style['bodyFontSize']),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppTheme.getGlassColor(context),
        contentPadding: EdgeInsets.symmetric(
          horizontal: style['isLandscape'] ? 8.0 : 16.0,
          vertical: style['isLandscape'] ? 6.0 : 14.0,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          borderSide: BorderSide(color: AppTheme.getGlassBorderColor(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          borderSide: BorderSide(color: AppTheme.getGlassBorderColor(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
      ),
    );
  }

  Widget _buildBackupItem(BuildContext context, dynamic backup) {
    final cardColor = AppTheme.getCardColor(context);
    final textPrimary = AppTheme.getTextPrimary(context);
    final textSecondary = AppTheme.getTextSecondary(context);
    final primaryColor = AppTheme.getPrimaryColor(context);
    final strings = AppStrings.of(context)!;
    final style = _getResponsiveStyle(context);

    return Container(
      margin: EdgeInsets.only(bottom: style['isLandscape'] ? 8.0 : 12.0),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: AppTheme.getGlassBorderColor(context),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          onTap: () => _restoreFromWebDAV(backup.path),
          child: Padding(
            padding: EdgeInsets.all(style['isLandscape'] ? 10.0 : 16.0),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(style['isLandscape'] ? 8.0 : 12.0),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Icon(
                    Icons.cloud_rounded,
                    color: primaryColor,
                    size: style['iconSize'] * 1.2,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        backup.name,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: style['bodyFontSize'],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: style['smallFontSize'] + 1, color: textSecondary),
                          SizedBox(width: style['spacing'] / 4),
                          Text(
                            backup.formattedDate,
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: style['smallFontSize'],
                            ),
                          ),
                          SizedBox(width: style['spacing']),
                          Icon(Icons.storage_rounded, size: style['smallFontSize'] + 1, color: textSecondary),
                          SizedBox(width: style['spacing'] / 4),
                          Text(
                            backup.formattedSize,
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: style['smallFontSize'],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => _restoreFromWebDAV(backup.path),
                  icon: Icon(Icons.cloud_download_rounded, size: style['iconSize']),
                  label: Text(strings.restoreBackup),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: BorderSide(color: primaryColor),
                    padding: EdgeInsets.symmetric(
                      horizontal: style['isLandscape'] ? 10.0 : 16.0,
                      vertical: style['isLandscape'] ? 6.0 : 10.0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _deleteWebDAVBackup(backup.path),
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: AppTheme.errorColor,
                  tooltip: strings.delete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _testConnection() async {
    final strings = AppStrings.of(context)!;
    final provider = context.read<BackupProvider>();

    // 验证输入
    if (_urlController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_rounded, color: Colors.white),
                SizedBox(width: 12),
                Text('请输入服务器地址'),
              ],
            ),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
          ),
        );
      }
      return;
    }

    ServiceLocator.log.i('开始测WebDAV 连接', tag: 'WebDAVBackupSection');
    ServiceLocator.log.d('URL: ${_urlController.text}', tag: 'WebDAVBackupSection');
    ServiceLocator.log.d('Username: ${_usernameController.text}', tag: 'WebDAVBackupSection');
    ServiceLocator.log.d('Path: $_fixedRemotePath', tag: 'WebDAVBackupSection');

    // 配置 WebDAV（不触发 UI 更新
    provider.configureWebDAV(
      serverUrl: _urlController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      remotePath: _fixedRemotePath, // 使用固定路径
      notify: false, // 不触notifyListeners
    );

    bool success = false;
    String? errorMessage;

    try {
      ServiceLocator.log.d('调用 testWebDAVConnection', tag: 'WebDAVBackupSection');
      success = await provider.testWebDAVConnection(notify: false);
      ServiceLocator.log.i('测试连接结果: $success', tag: 'WebDAVBackupSection');
    } catch (e, stackTrace) {
      ServiceLocator.log.e('测试连接异常', tag: 'WebDAVBackupSection', error: e, stackTrace: stackTrace);
      errorMessage = e.toString();
      success = false;
    }

    if (mounted) {
      setState(() => _isTestingConnection = false);
    }

    ServiceLocator.log.d('准备显示 SnackBar, mounted: $mounted', tag: 'WebDAVBackupSection');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle_rounded : Icons.error_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  success 
                      ? strings.connectionSuccess 
                      : (errorMessage != null 
                          ? '${strings.connectionFailed}: $errorMessage' 
                          : strings.connectionFailed),
                ),
              ),
            ],
          ),
          backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
        ),
      );
      ServiceLocator.log.i('SnackBar 已显示', tag: 'WebDAVBackupSection');
    }
  }

  Future<void> _saveConfig() async {
    final provider = context.read<BackupProvider>();

    // 验证输入
    if (_urlController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_rounded, color: Colors.white),
                SizedBox(width: 12),
                Text('请输入服务器地址'),
              ],
            ),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
          ),
        );
      }
      return;
    }

    ServiceLocator.log.i('保存 WebDAV 配置', tag: 'WebDAVBackupSection');

    // 配置 WebDAV
    provider.configureWebDAV(
      serverUrl: _urlController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      remotePath: _fixedRemotePath, // 使用固定路径
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text('配置已保存'),
            ],
          ),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
        ),
      );
    }
  }

  Future<void> _backupToWebDAV() async {
    final strings = AppStrings.of(context)!;
    final provider = context.read<BackupProvider>();

    // 先保存配
    provider.configureWebDAV(
      serverUrl: _urlController.text,
      username: _usernameController.text,
      password: _passwordController.text,
      remotePath: _fixedRemotePath, // 使用固定路径
    );

    // 显示 loading 对话框
    _showLoadingDialog(context);

    final success = await provider.backupToWebDAV();

    // 关闭 loading 对话框
    if (mounted) {
      Navigator.of(context).pop();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle_rounded : Icons.error_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Text(success ? strings.backupCreated : strings.backupFailed),
            ],
          ),
          backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
        ),
      );
    }
  }

  Future<void> _loadWebDAVBackups() async {
    setState(() => _isRefreshing = true);
    
    final provider = context.read<BackupProvider>();
    
    // 先保存配置
    provider.configureWebDAV(
      serverUrl: _urlController.text,
      username: _usernameController.text,
      password: _passwordController.text,
      remotePath: _fixedRemotePath, // 使用固定路径
      notify: false,
    );
    
    await provider.loadWebDAVBackups();
    
    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  Future<void> _restoreFromWebDAV(String remotePath) async {
    final strings = AppStrings.of(context)!;
    final cardColor = AppTheme.getCardColor(context);
    final textPrimary = AppTheme.getTextPrimary(context);
    final textSecondary = AppTheme.getTextSecondary(context);
    final primaryColor = AppTheme.getPrimaryColor(context);
    final style = _getResponsiveStyle(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: const Icon(
                Icons.warning_rounded,
                color: AppTheme.warningColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              strings.restoreWarning,
              style: TextStyle(
                color: textPrimary,
                fontSize: style['titleFontSize'],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Text(
          strings.restoreWarningMessage,
          style: TextStyle(
            color: textSecondary,
            fontSize: style['bodyFontSize'],
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              strings.cancel,
              style: TextStyle(color: textSecondary),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: Icon(Icons.restore_rounded, size: style['iconSize']),
            label: Text(strings.restoreConfirm),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ServiceLocator.log.i('用户确认恢复 WebDAV 备份', tag: 'WebDAVBackupSection');
      
      final provider = context.read<BackupProvider>();
      
      // 显示 loading 对话框
      _showLoadingDialog(context);
      
      ServiceLocator.log.d('调用 provider.restoreFromWebDAV', tag: 'WebDAVBackupSection');
      final success = await provider.restoreFromWebDAV(remotePath);
      ServiceLocator.log.i('restoreFromWebDAV 返回: $success, mounted: $mounted', tag: 'WebDAVBackupSection');

      // 关闭 loading 对话框
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ServiceLocator.log.d('Context 仍然有效，success: $success', tag: 'WebDAVBackupSection');
        if (success) {
          ServiceLocator.log.i('恢复成功，显示重启对话框', tag: 'WebDAVBackupSection');
          // 恢复成功，显示重启对话框
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              backgroundColor: cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: AppTheme.successColor,
                      size: style['iconSize'] * 1.2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    strings.success,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: style['titleFontSize'],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    strings.restoreSuccess,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: style['bodyFontSize'],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.getGlassColor(context),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      border: Border.all(
                        color: AppTheme.getGlassBorderColor(context),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.restart_alt_rounded,
                          color: AppTheme.infoColor,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            AppRestartHelper.getRestartMessage(),
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: style['smallFontSize'],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                ElevatedButton.icon(
                  onPressed: () async {
                    ServiceLocator.log.i('用户点击重启按钮', tag: 'WebDAVBackupSection');
                    Navigator.pop(dialogContext);
                    // 延迟一下再重启，让对话框关闭动画完
                    await Future.delayed(const Duration(milliseconds: 500));
                    ServiceLocator.log.i('调用 AppRestartHelper.restartApp()', tag: 'WebDAVBackupSection');
                    await AppRestartHelper.restartApp();
                  },
                  icon: Icon(Icons.restart_alt_rounded, size: style['iconSize']),
                  label: Text(AppRestartHelper.getRestartButtonText()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_rounded, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(provider.error ?? strings.restoreFailed),
                  ),
                ],
              ),
              backgroundColor: AppTheme.errorColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteWebDAVBackup(String remotePath) async {
    final strings = AppStrings.of(context)!;
    final cardColor = AppTheme.getCardColor(context);
    final textPrimary = AppTheme.getTextPrimary(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        title: Text(strings.deleteBackup, style: TextStyle(color: textPrimary)),
        content: Text(strings.deleteBackupConfirm, style: TextStyle(color: textPrimary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: Text(strings.delete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = context.read<BackupProvider>();
      final success = await provider.deleteWebDAVBackup(remotePath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? strings.backupDeleted : strings.error),
            backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _showRemoteConfig() {
    // TODO: 实现 TV 端远程配置（显示二维码）
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('TV 端远程配置功能待实现'),
      ),
    );
  }
}

