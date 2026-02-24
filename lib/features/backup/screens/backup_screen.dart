import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/platform/platform_detector.dart';
import '../providers/backup_provider.dart';
import '../widgets/local_backup_section.dart';
import '../widgets/webdav_backup_section.dart';

/// 备份和恢复设置页面
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  int _selectedSection = 0; // 0: 本地备份, 1: WebDAV

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<BackupProvider>();
      provider.loadWebDAVConfig();
      provider.loadLocalBackups();
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context)!;
    final isTV = PlatformDetector.isTV;
    final backgroundColor = AppTheme.getBackgroundColor(context);
    final surfaceColor = AppTheme.getSurfaceColor(context);
    final textPrimary = AppTheme.getTextPrimary(context);
    
    // 响应式样式
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = PlatformDetector.isMobile;
    final isLandscape = isMobile && screenWidth > 600 && screenWidth < 900 && screenHeight < screenWidth;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(isLandscape ? 36.0 : 56.0),
        child: AppBar(
          backgroundColor: surfaceColor,
          toolbarHeight: isLandscape ? 36.0 : 56.0,
          titleSpacing: isLandscape ? 0 : NavigationToolbar.kMiddleSpacing,
          title: Text(
            strings.backupAndRestore,
            style: TextStyle(
              color: textPrimary,
              fontSize: isLandscape ? 12.0 : 18.0,
            ),
          ),
          iconTheme: IconThemeData(
            color: textPrimary,
            size: isLandscape ? 16.0 : 24.0,
          ),
        ),
      ),
      body: Column(
        children: [
          // 顶部导航栏
          Container(
            color: surfaceColor,
            padding: EdgeInsets.symmetric(
              horizontal: isTV ? 32.0 : (isLandscape ? 8.0 : 16.0),
              vertical: isLandscape ? 4.0 : 12.0,
            ),
            child: Row(
              children: [
                _buildNavButton(
                  context,
                  icon: Icons.folder_rounded,
                  label: strings.localBackup,
                  isSelected: _selectedSection == 0,
                  onTap: () => setState(() => _selectedSection = 0),
                  isLandscape: isLandscape,
                ),
                SizedBox(width: isLandscape ? 6.0 : 16.0),
                _buildNavButton(
                  context,
                  icon: Icons.cloud_rounded,
                  label: 'WebDAV',
                  isSelected: _selectedSection == 1,
                  onTap: () => setState(() => _selectedSection = 1),
                  isLandscape: isLandscape,
                ),
              ],
            ),
          ),
          
          // 内容区域
          Expanded(
            child: _selectedSection == 0
                ? const LocalBackupSection()
                : const WebDAVBackupSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isLandscape,
  }) {
    final textPrimary = AppTheme.getTextPrimary(context);
    final textSecondary = AppTheme.getTextSecondary(context);
    final primaryColor = AppTheme.getPrimaryColor(context);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isLandscape ? 8.0 : 20.0,
          vertical: isLandscape ? 3.0 : 12.0,
        ),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: isSelected
              ? Border.all(color: primaryColor, width: isLandscape ? 1.5 : 2.0)
              : Border.all(color: Colors.transparent, width: isLandscape ? 1.5 : 2.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? primaryColor : textSecondary,
              size: isLandscape ? 14.0 : 20.0,
            ),
            SizedBox(width: isLandscape ? 4.0 : 8.0),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? primaryColor : textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: isLandscape ? 11.0 : 16.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
