import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../../core/widgets/tv_sidebar.dart';
import '../../../core/platform/platform_detector.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/services/service_locator.dart';
import '../providers/settings_provider.dart';
import '../providers/dlna_provider.dart';
import '../../epg/providers/epg_provider.dart';

class SettingsScreen extends StatelessWidget {
  final bool embedded;
  
  const SettingsScreen({super.key, this.embedded = false});

  // 显示设置成功消息
  void _showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.successColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // 显示设置失败消息
  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTV = PlatformDetector.isTV || size.width > 1200;

    final content = Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // General Settings
            _buildSectionHeader(AppStrings.of(context)?.general ?? 'General'),
            _buildSettingsCard([
              _buildSelectTile(
                context,
                title: AppStrings.of(context)?.language ?? 'Language',
                subtitle: _getCurrentLanguageLabel(context, settings),
                icon: Icons.language_rounded,
                onTap: () => _showLanguageDialog(context, settings),
              ),
              _buildDivider(),
              _buildSelectTile(
                context,
                title: AppStrings.of(context)?.theme ?? 'Theme',
                subtitle: _getThemeModeLabel(context, settings.themeMode),
                icon: Icons.palette_rounded,
                onTap: () => _showThemeModeDialog(context, settings),
              ),
            ]),

            const SizedBox(height: 24),

            // Playback Settings
            _buildSectionHeader(AppStrings.of(context)?.playback ?? 'Playback'),
            _buildSettingsCard([
              _buildSwitchTile(
                context,
                title: AppStrings.of(context)?.autoPlay ?? 'Auto-play',
                subtitle: AppStrings.of(context)?.autoPlaySubtitle ?? 'Automatically start playback when selecting a channel',
                icon: Icons.play_circle_outline_rounded,
                value: settings.autoPlay,
                onChanged: (value) {
                  settings.setAutoPlay(value);
                  final strings = AppStrings.of(context);
                  _showSuccess(context, value ? (strings?.autoPlayEnabled ?? 'Auto-play enabled') : (strings?.autoPlayDisabled ?? 'Auto-play disabled'));
                },
              ),
              _buildDivider(),
              _buildSelectTile(
                context,
                title: AppStrings.of(context)?.decodingMode ?? 'Decoding Mode',
                subtitle: _getDecodingModeLabel(context, settings.decodingMode),
                icon: Icons.memory_rounded,
                onTap: () => _showDecodingModeDialog(context, settings),
              ),
              _buildDivider(),
              _buildSelectTile(
                context,
                title: AppStrings.of(context)?.bufferSize ?? 'Buffer Size',
                subtitle: '${settings.bufferSize} ${AppStrings.of(context)?.seconds ?? 'seconds'} ${AppStrings.of(context)?.notImplemented ?? '(Not implemented)'}',
                icon: Icons.storage_rounded,
                onTap: () => _showBufferSizeDialog(context, settings),
              ),
              _buildDivider(),
              _buildSelectTile(
                context,
                title: AppStrings.of(context)?.bufferStrength ?? 'Buffer Strength',
                subtitle: _getBufferStrengthLabel(context, settings.bufferStrength),
                icon: Icons.speed_rounded,
                onTap: () => _showBufferStrengthDialog(context, settings),
              ),
              _buildDivider(),
              _buildSwitchTile(
                context,
                title: AppStrings.of(context)?.showFps ?? 'Show FPS',
                subtitle: AppStrings.of(context)?.showFpsSubtitle ?? 'Show frame rate in top-right corner of player',
                icon: Icons.speed_rounded,
                value: settings.showFps,
                onChanged: (value) {
                  settings.setShowFps(value);
                  final strings = AppStrings.of(context);
                  _showSuccess(context, value ? (strings?.fpsEnabled ?? 'FPS display enabled') : (strings?.fpsDisabled ?? 'FPS display disabled'));
                },
              ),
              _buildDivider(),
              _buildSwitchTile(
                context,
                title: AppStrings.of(context)?.showClock ?? 'Show Clock',
                subtitle: AppStrings.of(context)?.showClockSubtitle ?? 'Show current time in top-right corner of player',
                icon: Icons.schedule_rounded,
                value: settings.showClock,
                onChanged: (value) {
                  settings.setShowClock(value);
                  final strings = AppStrings.of(context);
                  _showSuccess(context, value ? (strings?.clockEnabled ?? 'Clock display enabled') : (strings?.clockDisabled ?? 'Clock display disabled'));
                },
              ),
              _buildDivider(),
              _buildSwitchTile(
                context,
                title: AppStrings.of(context)?.showNetworkSpeed ?? 'Show Network Speed',
                subtitle: AppStrings.of(context)?.showNetworkSpeedSubtitle ?? 'Show download speed in top-right corner of player',
                icon: Icons.network_check_rounded,
                value: settings.showNetworkSpeed,
                onChanged: (value) {
                  settings.setShowNetworkSpeed(value);
                  final strings = AppStrings.of(context);
                  _showSuccess(context, value ? (strings?.networkSpeedEnabled ?? 'Network speed display enabled') : (strings?.networkSpeedDisabled ?? 'Network speed display disabled'));
                },
              ),
              _buildDivider(),
              _buildSwitchTile(
                context,
                title: AppStrings.of(context)?.showVideoInfo ?? 'Show Resolution',
                subtitle: AppStrings.of(context)?.showVideoInfoSubtitle ?? 'Show video resolution and bitrate in top-right corner',
                icon: Icons.high_quality_rounded,
                value: settings.showVideoInfo,
                onChanged: (value) {
                  settings.setShowVideoInfo(value);
                  final strings = AppStrings.of(context);
                  _showSuccess(context, value ? (strings?.videoInfoEnabled ?? 'Resolution display enabled') : (strings?.videoInfoDisabled ?? 'Resolution display disabled'));
                },
              ),
              if (PlatformDetector.isDesktop || PlatformDetector.isTV) ...[
                _buildDivider(),
                _buildSwitchTile(
                  context,
                  title: AppStrings.of(context)?.enableMultiScreen ?? 'Multi-Screen Mode',
                  subtitle: AppStrings.of(context)?.enableMultiScreenSubtitle ?? 'Enable 2x2 split screen for simultaneous viewing',
                  icon: Icons.view_quilt_rounded,
                  value: settings.enableMultiScreen,
                  onChanged: (value) {
                    settings.setEnableMultiScreen(value);
                    final strings = AppStrings.of(context);
                    _showSuccess(context, value ? (strings?.multiScreenEnabled ?? 'Multi-screen mode enabled') : (strings?.multiScreenDisabled ?? 'Multi-screen mode disabled'));
                  },
                ),
                if (settings.enableMultiScreen && PlatformDetector.isDesktop) ...[
                  _buildDivider(),
                  _buildSelectTile(
                    context,
                    title: AppStrings.of(context)?.defaultScreenPosition ?? 'Default Screen Position',
                    subtitle: _getScreenPositionLabel(context, settings.defaultScreenPosition),
                    icon: Icons.crop_free_rounded,
                    onTap: () => _showScreenPositionDialog(context, settings),
                  ),
                ],
              ],
              _buildDivider(),
              _buildSwitchTile(
                context,
                title: AppStrings.of(context)?.volumeNormalization ?? 'Volume Normalization',
                subtitle: '${AppStrings.of(context)?.volumeNormalizationSubtitle ?? 'Auto-adjust volume differences between channels'} ${AppStrings.of(context)?.notImplemented ?? '(Not implemented)'}',
                icon: Icons.volume_up_rounded,
                value: settings.volumeNormalization,
                onChanged: (value) {
                  settings.setVolumeNormalization(value);
                  final strings = AppStrings.of(context);
                  _showError(context, strings?.volumeNormalizationNotImplemented ?? 'Volume normalization not implemented, setting will not take effect');
                },
              ),
              if (settings.volumeNormalization) ...[
                _buildDivider(),
                _buildSelectTile(
                  context,
                  title: AppStrings.of(context)?.volumeBoost ?? 'Volume Boost',
                  subtitle: settings.volumeBoost == 0 ? (AppStrings.of(context)?.noBoost ?? 'No boost') : '${settings.volumeBoost > 0 ? '+' : ''}${settings.volumeBoost} dB',
                  icon: Icons.equalizer_rounded,
                  onTap: () => _showVolumeBoostDialog(context, settings),
                ),
              ],
            ]),

            const SizedBox(height: 24),

            // Playlist Settings
            _buildSectionHeader(AppStrings.of(context)?.playlists ?? 'Playlists'),
            _buildSettingsCard([
              _buildSwitchTile(
                context,
                title: AppStrings.of(context)?.autoRefresh ?? 'Auto-refresh',
                subtitle: '${AppStrings.of(context)?.autoRefreshSubtitle ?? 'Automatically update playlists periodically'} ${AppStrings.of(context)?.notImplemented ?? '(Not implemented)'}',
                icon: Icons.refresh_rounded,
                value: settings.autoRefresh,
                onChanged: (value) {
                  settings.setAutoRefresh(value);
                  final strings = AppStrings.of(context);
                  _showError(context, strings?.autoRefreshNotImplemented ?? 'Auto-refresh not implemented, setting will not take effect');
                },
              ),
              if (settings.autoRefresh) ...[
                _buildDivider(),
                _buildSelectTile(
                  context,
                  title: AppStrings.of(context)?.refreshInterval ?? 'Refresh Interval',
                  subtitle: 'Every ${settings.refreshInterval} ${AppStrings.of(context)?.hours ?? 'hours'} ${AppStrings.of(context)?.notImplemented ?? '(Not implemented)'}',
                  icon: Icons.schedule_rounded,
                  onTap: () => _showRefreshIntervalDialog(context, settings),
                ),
              ],
              _buildDivider(),
              _buildSwitchTile(
                context,
                title: AppStrings.of(context)?.rememberLastChannel ?? 'Remember Last Channel',
                subtitle: AppStrings.of(context)?.rememberLastChannelSubtitle ?? 'Resume playback from last watched channel',
                icon: Icons.history_rounded,
                value: settings.rememberLastChannel,
                onChanged: (value) {
                  settings.setRememberLastChannel(value);
                  final strings = AppStrings.of(context);
                  _showSuccess(context, value ? (strings?.rememberLastChannelEnabled ?? 'Remember last channel enabled') : (strings?.rememberLastChannelDisabled ?? 'Remember last channel disabled'));
                },
              ),
            ]),

            const SizedBox(height: 24),

            // EPG Settings
            _buildSectionHeader(AppStrings.of(context)?.epg ?? 'EPG (Electronic Program Guide)'),
            _buildSettingsCard([
              _buildSwitchTile(
                context,
                title: AppStrings.of(context)?.enableEpg ?? 'Enable EPG',
                subtitle: AppStrings.of(context)?.enableEpgSubtitle ?? 'Show program information for channels',
                icon: Icons.event_note_rounded,
                value: settings.enableEpg,
                onChanged: (value) async {
                  await settings.setEnableEpg(value);
                  final strings = AppStrings.of(context);
                  if (value) {
                    // 启用 EPG 时，如果有配置 URL 则加载
                    if (settings.epgUrl != null && settings.epgUrl!.isNotEmpty) {
                      final success = await context.read<EpgProvider>().loadEpg(settings.epgUrl!);
                      if (success) {
                        _showSuccess(context, strings?.epgEnabledAndLoaded ?? 'EPG enabled and loaded successfully');
                      } else {
                        _showError(context, strings?.epgEnabledButFailed ?? 'EPG enabled but failed to load');
                      }
                    } else {
                      _showSuccess(context, strings?.epgEnabledPleaseConfigure ?? 'EPG enabled, please configure EPG URL');
                    }
                  } else {
                    // 关闭 EPG 时清除已加载的数据
                    context.read<EpgProvider>().clear();
                    _showSuccess(context, strings?.epgDisabled ?? 'EPG disabled');
                  }
                },
              ),
              if (settings.enableEpg) ...[
                _buildDivider(),
                _buildInputTile(
                  context,
                  title: AppStrings.of(context)?.epgUrl ?? 'EPG URL',
                  subtitle: settings.epgUrl ?? (AppStrings.of(context)?.notConfigured ?? 'Not configured'),
                  icon: Icons.link_rounded,
                  onTap: () => _showEpgUrlDialog(context, settings),
                ),
              ],
            ]),

            const SizedBox(height: 24),

            // DLNA Settings
            _buildSectionHeader(AppStrings.of(context)?.dlnaCasting ?? 'DLNA Casting'),
            Consumer<DlnaProvider>(
              builder: (context, dlnaProvider, _) {
                final strings = AppStrings.of(context);
                return _buildSettingsCard([
                  _buildSwitchTile(
                    context,
                    title: strings?.enableDlnaService ?? 'Enable DLNA Service',
                    subtitle: dlnaProvider.isRunning
                        ? (strings?.dlnaServiceStarted ?? 'Started: {deviceName}').replaceFirst('{deviceName}', dlnaProvider.deviceName)
                        : strings?.allowOtherDevicesToCast ?? 'Allow other devices to cast to this device',
                    icon: Icons.cast_rounded,
                    value: dlnaProvider.isEnabled,
                    onChanged: (value) async {
                      final success = await dlnaProvider.setEnabled(value);
                      if (success) {
                        _showSuccess(context, value ? (strings?.dlnaServiceStartedMsg ?? 'DLNA service started') : (strings?.dlnaServiceStoppedMsg ?? 'DLNA service stopped'));
                      } else {
                        _showError(context, strings?.dlnaServiceStartFailed ?? 'Failed to start DLNA service, please check network connection');
                      }
                    },
                  ),
                ]);
              },
            ),

            const SizedBox(height: 24),

            // Parental Control
            _buildSectionHeader(AppStrings.of(context)?.parentalControl ?? 'Parental Control'),
            _buildSettingsCard([
              _buildSwitchTile(
                context,
                title: AppStrings.of(context)?.enableParentalControl ?? 'Enable Parental Control',
                subtitle: '${AppStrings.of(context)?.enableParentalControlSubtitle ?? 'Require PIN to access certain content'} ${AppStrings.of(context)?.notImplemented ?? '(Not implemented)'}',
                icon: Icons.lock_outline_rounded,
                value: settings.parentalControl,
                onChanged: (value) {
                  settings.setParentalControl(value);
                  final strings = AppStrings.of(context);
                  _showError(context, strings?.parentalControlNotImplemented ?? 'Parental control not implemented, setting will not take effect');
                },
              ),
              if (settings.parentalControl) ...[
                _buildDivider(),
                _buildActionTile(
                  context,
                  title: AppStrings.of(context)?.changePin ?? 'Change PIN',
                  subtitle: '${AppStrings.of(context)?.changePinSubtitle ?? 'Update your parental control PIN'} ${AppStrings.of(context)?.notImplemented ?? '(Not implemented)'}',
                  icon: Icons.pin_rounded,
                  onTap: () => _showChangePinDialog(context, settings),
                ),
              ],
            ]),

            const SizedBox(height: 24),

            // About Section
            _buildSectionHeader(AppStrings.of(context)?.about ?? 'About'),
            _buildSettingsCard([
              FutureBuilder<String>(
                future: _getCurrentVersion(),
                builder: (context, snapshot) {
                  return _buildInfoTile(
                    context,
                    title: AppStrings.of(context)?.version ?? 'Version',
                    value: snapshot.data ?? 'Loading...',
                    icon: Icons.info_outline_rounded,
                  );
                },
              ),
              _buildDivider(),
              _buildActionTile(
                context,
                title: AppStrings.of(context)?.checkUpdate ?? 'Check for Updates',
                subtitle: AppStrings.of(context)?.checkUpdateSubtitle ?? 'Check if a new version is available',
                icon: Icons.system_update_rounded,
                onTap: () => _checkForUpdates(context),
              ),
              _buildDivider(),
              _buildInfoTile(
                context,
                title: AppStrings.of(context)?.platform ?? 'Platform',
                value: _getPlatformName(),
                icon: Icons.devices_rounded,
              ),
            ]),

            const SizedBox(height: 24),

            // Reset Section
            _buildSettingsCard([
              _buildActionTile(
                context,
                title: AppStrings.of(context)?.resetAllSettings ?? 'Reset All Settings',
                subtitle: AppStrings.of(context)?.resetSettingsSubtitle ?? 'Restore all settings to default values',
                icon: Icons.restore_rounded,
                isDestructive: true,
                onTap: () => _confirmResetSettings(context, settings),
              ),
            ]),

            const SizedBox(height: 40),
          ],
        );
      },
    );

    if (isTV) {
      return Scaffold(
        backgroundColor: AppTheme.getBackgroundColor(context),
        body: TVSidebar(
          selectedIndex: 4, // 设置页
          child: content,
        ),
      );
    }

    // 嵌入模式不使用Scaffold
    if (embedded) {
      return Column(
        children: [
          // 简化的标题栏
          SafeArea(
            bottom: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Text(
                    AppStrings.of(context)?.settings ?? 'Settings',
                    style: TextStyle(
                      color: AppTheme.getTextPrimary(context),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: content),
        ],
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: AppTheme.getBackgroundColor(context),
        title: Text(
          AppStrings.of(context)?.settings ?? 'Settings',
          style: TextStyle(color: AppTheme.getTextPrimary(context), fontSize: 20, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: content,
    );
  }

  String _getCurrentLanguageLabel(BuildContext context, SettingsProvider settings) {
    final locale = settings.locale;
    final strings = AppStrings.of(context);
    if (locale == null) {
      // 没有设置，显示"跟随系统"
      final systemLocale = Localizations.localeOf(context);
      final systemLang = systemLocale.languageCode == 'zh' ? (strings?.chinese ?? '中文') : 'English';
      return '${strings?.followSystem ?? "Follow system"} ($systemLang)';
    }
    // 根据保存的设置显示
    if (locale.languageCode == 'zh') {
      return strings?.chinese ?? '中文';
    }
    return strings?.english ?? 'English';
  }

  String _getPlatformName() {
    if (PlatformDetector.isTV) return 'Android TV';
    if (PlatformDetector.isAndroid) return 'Android';
    if (PlatformDetector.isWindows) return 'Windows';
    return 'Unknown';
  }

  String _getDecodingModeLabel(BuildContext context, String mode) {
    final strings = AppStrings.of(context);
    switch (mode) {
      case 'hardware':
        return strings?.decodingModeHardware ?? 'Hardware';
      case 'software':
        return strings?.decodingModeSoftware ?? 'Software';
      case 'auto':
      default:
        return strings?.decodingModeAuto ?? 'Auto';
    }
  }

  void _showDecodingModeDialog(BuildContext context, SettingsProvider settings) {
    final options = ['auto', 'hardware', 'software'];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: Text(
            AppStrings.of(context)?.decodingMode ?? 'Decoding Mode',
            style: const TextStyle(color: AppTheme.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((mode) {
              return RadioListTile<String>(
                title: Text(
                  _getDecodingModeLabel(context, mode),
                  style: const TextStyle(color: AppTheme.textPrimary),
                ),
                subtitle: Text(
                  _getDecodingModeDescription(context, mode),
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
                value: mode,
                groupValue: settings.decodingMode,
                onChanged: (value) {
                  if (value != null) {
                    settings.setDecodingMode(value);
                    Navigator.pop(dialogContext);
                    final strings = AppStrings.of(context);
                    _showSuccess(context, (strings?.decodingModeSet ?? 'Decoding mode set to: {mode}').replaceFirst('{mode}', _getDecodingModeLabel(context, value)));
                  }
                },
                activeColor: AppTheme.primaryColor,
              );
            }).toList(),
          ),
        );
      },
    );
  }

  String _getDecodingModeDescription(BuildContext context, String mode) {
    final strings = AppStrings.of(context);
    switch (mode) {
      case 'hardware':
        return strings?.decodingModeHardwareDesc ?? 'Force MediaCodec. May cause errors on some devices.';
      case 'software':
        return strings?.decodingModeSoftwareDesc ?? 'Use CPU decoding. More compatible but uses more power.';
      case 'auto':
      default:
        return strings?.decodingModeAutoDesc ?? 'Automatically choose best option. Recommended.';
    }
  }

  Widget _buildSectionHeader(String title) {
    return Builder(
      builder: (context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 12),
        child: Text(
          title,
          style: TextStyle(
            color: AppTheme.getTextSecondary(context),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Builder(
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppTheme.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Builder(
      builder: (context) => Divider(
        color: AppTheme.getCardColor(context),
        height: 1,
        indent: 56,
      ),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return TVFocusable(
      onSelect: () => onChanged(!value),
      focusScale: 1.0,
      showFocusBorder: false,
      builder: (context, isFocused, child) {
        return Container(
          decoration: BoxDecoration(
            color: isFocused ? AppTheme.getFocusBackgroundColor(context) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: child,
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppTheme.primaryColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppTheme.getTextPrimary(context),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppTheme.getTextMuted(context),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppTheme.primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return TVFocusable(
      onSelect: onTap,
      focusScale: 1.0,
      showFocusBorder: false,
      builder: (context, isFocused, child) {
        return Container(
          decoration: BoxDecoration(
            color: isFocused ? AppTheme.getFocusBackgroundColor(context) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: child,
        );
      },
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppTheme.primaryColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppTheme.getTextPrimary(context),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppTheme.getTextMuted(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.getTextMuted(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return _buildSelectTile(
      context,
      title: title,
      subtitle: subtitle,
      icon: icon,
      onTap: onTap,
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return TVFocusable(
      onSelect: onTap,
      focusScale: 1.0,
      showFocusBorder: false,
      builder: (context, isFocused, child) {
        return Container(
          decoration: BoxDecoration(
            color: isFocused ? (isDestructive ? AppTheme.errorColor.withOpacity(0.1) : AppTheme.getFocusBackgroundColor(context)) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: child,
        );
      },
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isDestructive ? AppTheme.errorColor : AppTheme.primaryColor).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: isDestructive ? AppTheme.errorColor : AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isDestructive ? AppTheme.errorColor : AppTheme.getTextPrimary(context),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppTheme.getTextMuted(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.getTextMuted(context).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppTheme.getTextMuted(context), size: 20),
          ),
          const SizedBox(width: 16),
          Text(
            title,
            style: TextStyle(
              color: AppTheme.getTextPrimary(context),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: AppTheme.getTextSecondary(context),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  String _getBufferStrengthLabel(BuildContext context, String strength) {
    final strings = AppStrings.of(context);
    switch (strength) {
      case 'fast':
        return strings?.fastBuffer ?? 'Fast (Quick switching, may stutter)';
      case 'balanced':
        return strings?.balancedBuffer ?? 'Balanced';
      case 'stable':
        return strings?.stableBuffer ?? 'Stable (Slow switching, less stuttering)';
      default:
        return strength;
    }
  }

  void _showBufferStrengthDialog(BuildContext context, SettingsProvider settings) {
    final options = ['fast', 'balanced', 'stable'];
    final strings = AppStrings.of(context);
    final labels = {
      'fast': strings?.fastBuffer ?? 'Fast (Quick switching, may stutter)',
      'balanced': strings?.balancedBuffer ?? 'Balanced',
      'stable': strings?.stableBuffer ?? 'Stable (Slow switching, less stuttering)',
    };

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: Text(
            strings?.bufferStrength ?? 'Buffer Strength',
            style: const TextStyle(color: AppTheme.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((strength) {
              return RadioListTile<String>(
                title: Text(
                  labels[strength] ?? strength,
                  style: const TextStyle(color: AppTheme.textPrimary),
                ),
                value: strength,
                groupValue: settings.bufferStrength,
                onChanged: (value) {
                  if (value != null) {
                    settings.setBufferStrength(value);
                    Navigator.pop(dialogContext);
                  }
                },
                activeColor: AppTheme.primaryColor,
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showBufferSizeDialog(BuildContext context, SettingsProvider settings) {
    final options = [10, 20, 30, 45, 60];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: Text(
            AppStrings.of(context)?.bufferSize ?? 'Buffer Size',
            style: const TextStyle(color: AppTheme.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((seconds) {
              return RadioListTile<int>(
                title: Text(
                  '$seconds ${AppStrings.of(context)?.seconds ?? 'seconds'}',
                  style: const TextStyle(color: AppTheme.textPrimary),
                ),
                value: seconds,
                groupValue: settings.bufferSize,
                onChanged: (value) {
                  if (value != null) {
                    settings.setBufferSize(value);
                    Navigator.pop(dialogContext);
                    final strings = AppStrings.of(context);
                    _showError(context, strings?.bufferSizeNotImplemented ?? 'Buffer size setting not implemented, setting will not take effect');
                  }
                },
                activeColor: AppTheme.primaryColor,
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showVolumeBoostDialog(BuildContext context, SettingsProvider settings) {
    final options = [-10, -5, 0, 5, 10, 15, 20];

    showDialog(
      context: context,
      builder: (dialogContext) {
        final strings = AppStrings.of(context);
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: Text(
            strings?.volumeBoost ?? 'Volume Boost',
            style: const TextStyle(color: AppTheme.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((db) {
              return RadioListTile<int>(
                title: Text(
                  db == 0 ? '${strings?.noBoost ?? "No boost"} (0 dB)' : '${db > 0 ? '+' : ''}$db dB',
                  style: const TextStyle(color: AppTheme.textPrimary),
                ),
                subtitle: Text(
                  _getVolumeBoostDescription(context, db),
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
                value: db,
                groupValue: settings.volumeBoost,
                onChanged: (value) {
                  if (value != null) {
                    settings.setVolumeBoost(value);
                    Navigator.pop(dialogContext);
                    final strings = AppStrings.of(context);
                    final boostValue = value == 0 ? (strings?.noBoostValue ?? 'No boost') : '${value > 0 ? '+' : ''}$value dB';
                    _showSuccess(context, (strings?.volumeBoostSet ?? 'Volume boost set to {value}').replaceFirst('{value}', boostValue));
                  }
                },
                activeColor: AppTheme.primaryColor,
              );
            }).toList(),
          ),
        );
      },
    );
  }

  String _getVolumeBoostDescription(BuildContext context, int db) {
    final strings = AppStrings.of(context);
    if (db <= -10) return strings?.volumeBoostLow ?? 'Significantly lower volume';
    if (db < 0) return strings?.volumeBoostSlightLow ?? 'Slightly lower volume';
    if (db == 0) return strings?.volumeBoostNormal ?? 'Keep original volume';
    if (db <= 10) return strings?.volumeBoostSlightHigh ?? 'Slightly higher volume';
    return strings?.volumeBoostHigh ?? 'Significantly higher volume';
  }

  void _showRefreshIntervalDialog(BuildContext context, SettingsProvider settings) {
    final options = [6, 12, 24, 48, 72];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: Text(
            AppStrings.of(context)?.refreshInterval ?? 'Refresh Interval',
            style: const TextStyle(color: AppTheme.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((hours) {
              return RadioListTile<int>(
                title: Text(
                  hours < 24
                      ? '$hours ${AppStrings.of(context)?.hours ?? 'hours'}'
                      : '${hours ~/ 24} ${hours ~/ 24 > 1 ? (AppStrings.of(context)?.days ?? 'days') : (AppStrings.of(context)?.day ?? 'day')}',
                  style: const TextStyle(color: AppTheme.textPrimary),
                ),
                value: hours,
                groupValue: settings.refreshInterval,
                onChanged: (value) {
                  if (value != null) {
                    settings.setRefreshInterval(value);
                    Navigator.pop(dialogContext);
                    final strings = AppStrings.of(context);
                    _showError(context, strings?.autoRefreshNotImplemented ?? 'Auto-refresh not implemented, setting will not take effect');
                  }
                },
                activeColor: AppTheme.primaryColor,
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showEpgUrlDialog(BuildContext context, SettingsProvider settings) {
    final controller = TextEditingController(text: settings.epgUrl);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: Text(
            AppStrings.of(context)?.epgUrl ?? 'EPG URL',
            style: const TextStyle(color: AppTheme.textPrimary),
          ),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: AppStrings.of(context)?.enterEpgUrl ?? 'Enter EPG XMLTV URL',
              hintStyle: const TextStyle(color: AppTheme.textMuted),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(AppStrings.of(context)?.cancel ?? 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newUrl = controller.text.trim().isEmpty ? null : controller.text.trim();
                final oldUrl = settings.epgUrl;

                // 保存新 URL
                await settings.setEpgUrl(newUrl);
                Navigator.pop(dialogContext);

                // 如果 URL 变化了，清除旧数据并加载新数据
                if (newUrl != oldUrl) {
                  final epgProvider = context.read<EpgProvider>();
                  epgProvider.clear();
                  final strings = AppStrings.of(context);

                  if (newUrl != null && newUrl.isNotEmpty && settings.enableEpg) {
                    final success = await epgProvider.loadEpg(newUrl);
                    if (success) {
                      _showSuccess(context, strings?.epgUrlSavedAndLoaded ?? 'EPG URL saved and loaded successfully');
                    } else {
                      _showError(context, strings?.epgUrlSavedButFailed ?? 'EPG URL saved but failed to load');
                    }
                  } else if (newUrl == null) {
                    _showSuccess(context, strings?.epgUrlCleared ?? 'EPG URL cleared');
                  } else {
                    _showSuccess(context, strings?.epgUrlSaved ?? 'EPG URL saved');
                  }
                }
              },
              child: Text(AppStrings.of(context)?.save ?? 'Save'),
            ),
          ],
        );
      },
    );
  }

  void _showChangePinDialog(BuildContext context, SettingsProvider settings) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: Text(
            AppStrings.of(context)?.setPin ?? 'Set PIN',
            style: const TextStyle(color: AppTheme.textPrimary),
          ),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: AppStrings.of(context)?.enterPin ?? 'Enter 4-digit PIN',
              hintStyle: const TextStyle(color: AppTheme.textMuted),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(AppStrings.of(context)?.cancel ?? 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final strings = AppStrings.of(context);
                if (controller.text.length == 4) {
                  settings.setParentalPin(controller.text);
                  Navigator.pop(dialogContext);
                  _showError(context, strings?.pinNotImplemented ?? 'Parental control not implemented, PIN setting will not take effect');
                } else {
                  _showError(context, strings?.enter4DigitPin ?? 'Please enter 4-digit PIN');
                }
              },
              child: Text(AppStrings.of(context)?.save ?? 'Save'),
            ),
          ],
        );
      },
    );
  }

  void _confirmResetSettings(BuildContext context, SettingsProvider settings) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: Text(
            AppStrings.of(context)?.resetSettings ?? 'Reset Settings',
            style: const TextStyle(color: AppTheme.textPrimary),
          ),
          content: Text(
            AppStrings.of(context)?.resetConfirm ?? 'Are you sure you want to reset all settings to their default values?',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(AppStrings.of(context)?.cancel ?? 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                settings.resetSettings();
                context.read<EpgProvider>().clear();
                Navigator.pop(dialogContext);
                final strings = AppStrings.of(context);
                _showSuccess(context, strings?.allSettingsReset ?? 'All settings have been reset to default values');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
              ),
              child: Text(AppStrings.of(context)?.reset ?? 'Reset'),
            ),
          ],
        );
      },
    );
  }

  void _showLanguageDialog(BuildContext context, SettingsProvider settings) {
    // 获取当前设置的语言代码，null 表示跟随系统
    final currentLang = settings.locale?.languageCode;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: Text(
            AppStrings.of(context)?.language ?? 'Language',
            style: const TextStyle(color: AppTheme.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String?>(
                title: Text(
                  AppStrings.of(context)?.followSystem ?? '跟随系统',
                  style: const TextStyle(color: AppTheme.textPrimary),
                ),
                value: null,
                groupValue: currentLang,
                onChanged: (value) {
                  settings.setLocale(null);
                  Navigator.pop(dialogContext);
                  _showSuccess(context, AppStrings.of(context)?.languageFollowSystem ?? '已设置为跟随系统语言');
                },
                activeColor: AppTheme.primaryColor,
              ),
              RadioListTile<String?>(
                title: const Text(
                  'English',
                  style: TextStyle(color: AppTheme.textPrimary),
                ),
                value: 'en',
                groupValue: currentLang,
                onChanged: (value) {
                  settings.setLocale(const Locale('en'));
                  Navigator.pop(dialogContext);
                  _showSuccess(context, 'Language changed to English');
                },
                activeColor: AppTheme.primaryColor,
              ),
              RadioListTile<String?>(
                title: Text(
                  AppStrings.of(context)?.chinese ?? '中文',
                  style: const TextStyle(color: AppTheme.textPrimary),
                ),
                value: 'zh',
                groupValue: currentLang,
                onChanged: (value) {
                  settings.setLocale(const Locale('zh'));
                  Navigator.pop(dialogContext);
                  final strings = AppStrings.of(context);
                  _showSuccess(context, strings?.languageSwitchedToChinese ?? 'Language switched to Chinese');
                },
                activeColor: AppTheme.primaryColor,
              ),
            ],
          ),
        );
      },
    );
  }

  String _getThemeModeLabel(BuildContext context, String mode) {
    final strings = AppStrings.of(context);
    switch (mode) {
      case 'light':
        return strings?.themeLight ?? 'Light';
      case 'dark':
        return strings?.themeDark ?? 'Dark';
      case 'system':
      default:
        return strings?.themeSystem ?? 'Follow System';
    }
  }

  void _showThemeModeDialog(BuildContext context, SettingsProvider settings) {
    final options = ['system', 'light', 'dark'];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: Text(
            AppStrings.of(context)?.theme ?? 'Theme',
            style: const TextStyle(color: AppTheme.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((mode) {
              return RadioListTile<String>(
                title: Text(
                  _getThemeModeLabel(context, mode),
                  style: const TextStyle(color: AppTheme.textPrimary),
                ),
                value: mode,
                groupValue: settings.themeMode,
                onChanged: (value) {
                  if (value != null) {
                    settings.setThemeMode(value);
                    Navigator.pop(dialogContext);
                    final strings = AppStrings.of(context);
                    _showSuccess(context, (strings?.themeChangedMessage ?? 'Theme changed: {theme}').replaceFirst('{theme}', _getThemeModeLabel(context, value)));
                  }
                },
                activeColor: AppTheme.primaryColor,
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // 获取当前应用版本
  Future<String> _getCurrentVersion() async {
    try {
      return await ServiceLocator.updateService.getCurrentVersion();
    } catch (e) {
      return '1.1.11'; // 默认版本
    }
  }

  // 检查更新
  void _checkForUpdates(BuildContext context) {
    ServiceLocator.updateManager.manualCheckForUpdate(context);
  }

  String _getScreenPositionLabel(BuildContext context, int position) {
    final strings = AppStrings.of(context);
    switch (position) {
      case 1:
        return strings?.screenPosition1 ?? 'Top Left (1)';
      case 2:
        return strings?.screenPosition2 ?? 'Top Right (2)';
      case 3:
        return strings?.screenPosition3 ?? 'Bottom Left (3)';
      case 4:
      default:
        return strings?.screenPosition4 ?? 'Bottom Right (4)';
    }
  }

  void _showScreenPositionDialog(BuildContext context, SettingsProvider settings) {
    final options = [1, 2, 3, 4];
    final strings = AppStrings.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: Text(
            strings?.defaultScreenPosition ?? 'Default Screen Position',
            style: const TextStyle(color: AppTheme.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                strings?.screenPositionDesc ?? 'Choose which screen position to use by default when clicking a channel:',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 16),
              // 显示2x2网格示意图
              Container(
                width: 120,
                height: 90,
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.textMuted),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: AppTheme.textMuted.withOpacity(0.3)),
                                color: settings.defaultScreenPosition == 1 ? AppTheme.primaryColor.withOpacity(0.3) : null,
                              ),
                              child: const Center(child: Text('1', style: TextStyle(color: AppTheme.textPrimary, fontSize: 12))),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: AppTheme.textMuted.withOpacity(0.3)),
                                color: settings.defaultScreenPosition == 2 ? AppTheme.primaryColor.withOpacity(0.3) : null,
                              ),
                              child: const Center(child: Text('2', style: TextStyle(color: AppTheme.textPrimary, fontSize: 12))),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: AppTheme.textMuted.withOpacity(0.3)),
                                color: settings.defaultScreenPosition == 3 ? AppTheme.primaryColor.withOpacity(0.3) : null,
                              ),
                              child: const Center(child: Text('3', style: TextStyle(color: AppTheme.textPrimary, fontSize: 12))),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: AppTheme.textMuted.withOpacity(0.3)),
                                color: settings.defaultScreenPosition == 4 ? AppTheme.primaryColor.withOpacity(0.3) : null,
                              ),
                              child: const Center(child: Text('4', style: TextStyle(color: AppTheme.textPrimary, fontSize: 12))),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ...options.map((position) {
                return RadioListTile<int>(
                  title: Text(
                    _getScreenPositionLabel(context, position),
                    style: const TextStyle(color: AppTheme.textPrimary),
                  ),
                  value: position,
                  groupValue: settings.defaultScreenPosition,
                  onChanged: (value) {
                    if (value != null) {
                      settings.setDefaultScreenPosition(value);
                      Navigator.pop(dialogContext);
                      final strings = AppStrings.of(context);
                      _showSuccess(context, (strings?.screenPositionSet ?? 'Default screen position set to: {position}').replaceFirst('{position}', _getScreenPositionLabel(context, value)));
                    }
                  },
                  activeColor: AppTheme.primaryColor,
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }
}
