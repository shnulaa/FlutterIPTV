import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../../core/widgets/tv_sidebar.dart';
import '../../../core/platform/platform_detector.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/services/service_locator.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
            _buildSectionHeader(AppStrings.of(context)?.categories ?? 'General'),
            _buildSettingsCard([
              _buildSelectTile(
                context,
                title: AppStrings.of(context)?.language ?? 'Language',
                subtitle: settings.locale?.languageCode == 'zh' 
                    ? (AppStrings.of(context)?.chinese ?? '中文')
                    : (AppStrings.of(context)?.english ?? 'English'),
                icon: Icons.language_rounded,
                onTap: () => _showLanguageDialog(context, settings),
              ),
            ]),

              const SizedBox(height: 24),

              // Playback Settings
              _buildSectionHeader(
                  AppStrings.of(context)?.playback ?? 'Playback'),
              _buildSettingsCard([
                _buildSwitchTile(
                  context,
                  title: AppStrings.of(context)?.autoPlay ?? 'Auto-play',
                  subtitle: AppStrings.of(context)?.autoPlaySubtitle ??
                      'Automatically start playback when selecting a channel',
                  icon: Icons.play_circle_outline_rounded,
                  value: settings.autoPlay,
                  onChanged: (value) => settings.setAutoPlay(value),
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
                  subtitle:
                      '${settings.bufferSize} ${AppStrings.of(context)?.seconds ?? 'seconds'}',
                  icon: Icons.storage_rounded,
                  onTap: () => _showBufferSizeDialog(context, settings),
                ),
                _buildDivider(),
                _buildSwitchTile(
                  context,
                  title: AppStrings.of(context)?.volumeNormalization ?? 'Volume Normalization',
                  subtitle: AppStrings.of(context)?.volumeNormalizationSubtitle ?? 'Auto-adjust volume differences between channels',
                  icon: Icons.volume_up_rounded,
                  value: settings.volumeNormalization,
                  onChanged: (value) => settings.setVolumeNormalization(value),
                ),
                if (settings.volumeNormalization) ...[
                  _buildDivider(),
                  _buildSelectTile(
                    context,
                    title: AppStrings.of(context)?.volumeBoost ?? 'Volume Boost',
                    subtitle: settings.volumeBoost == 0
                        ? (AppStrings.of(context)?.noBoost ?? 'No boost')
                        : '${settings.volumeBoost > 0 ? '+' : ''}${settings.volumeBoost} dB',
                    icon: Icons.equalizer_rounded,
                    onTap: () => _showVolumeBoostDialog(context, settings),
                  ),
                ],
              ]),

              const SizedBox(height: 24),

              // Playlist Settings
              _buildSectionHeader(
                  AppStrings.of(context)?.playlists ?? 'Playlists'),
              _buildSettingsCard([
                _buildSwitchTile(
                  context,
                  title: AppStrings.of(context)?.autoRefresh ?? 'Auto-refresh',
                  subtitle: AppStrings.of(context)?.autoRefreshSubtitle ??
                      'Automatically update playlists periodically',
                  icon: Icons.refresh_rounded,
                  value: settings.autoRefresh,
                  onChanged: (value) => settings.setAutoRefresh(value),
                ),
                if (settings.autoRefresh) ...[
                  _buildDivider(),
                  _buildSelectTile(
                    context,
                    title: AppStrings.of(context)?.refreshInterval ??
                        'Refresh Interval',
                    subtitle:
                        'Every ${settings.refreshInterval} ${AppStrings.of(context)?.hours ?? 'hours'}',
                    icon: Icons.schedule_rounded,
                    onTap: () => _showRefreshIntervalDialog(context, settings),
                  ),
                ],
                _buildDivider(),
                _buildSwitchTile(
                  context,
                  title: AppStrings.of(context)?.rememberLastChannel ??
                      'Remember Last Channel',
                  subtitle:
                      AppStrings.of(context)?.rememberLastChannelSubtitle ??
                          'Resume playback from last watched channel',
                  icon: Icons.history_rounded,
                  value: settings.rememberLastChannel,
                  onChanged: (value) => settings.setRememberLastChannel(value),
                ),
              ]),

              const SizedBox(height: 24),

              // EPG Settings
              _buildSectionHeader(AppStrings.of(context)?.epg ??
                  'EPG (Electronic Program Guide)'),
              _buildSettingsCard([
                _buildSwitchTile(
                  context,
                  title: AppStrings.of(context)?.enableEpg ?? 'Enable EPG',
                  subtitle: AppStrings.of(context)?.enableEpgSubtitle ??
                      'Show program information for channels',
                  icon: Icons.event_note_rounded,
                  value: settings.enableEpg,
                  onChanged: (value) => settings.setEnableEpg(value),
                ),
                if (settings.enableEpg) ...[
                  _buildDivider(),
                  _buildInputTile(
                    context,
                    title: AppStrings.of(context)?.epgUrl ?? 'EPG URL',
                    subtitle: settings.epgUrl ??
                        (AppStrings.of(context)?.notConfigured ??
                            'Not configured'),
                    icon: Icons.link_rounded,
                    onTap: () => _showEpgUrlDialog(context, settings),
                  ),
                ],
              ]),

              const SizedBox(height: 24),

              // Parental Control
              _buildSectionHeader(AppStrings.of(context)?.parentalControl ??
                  'Parental Control'),
              _buildSettingsCard([
                _buildSwitchTile(
                  context,
                  title: AppStrings.of(context)?.enableParentalControl ??
                      'Enable Parental Control',
                  subtitle:
                      AppStrings.of(context)?.enableParentalControlSubtitle ??
                          'Require PIN to access certain content',
                  icon: Icons.lock_outline_rounded,
                  value: settings.parentalControl,
                  onChanged: (value) => settings.setParentalControl(value),
                ),
                if (settings.parentalControl) ...[
                  _buildDivider(),
                  _buildActionTile(
                    context,
                    title: AppStrings.of(context)?.changePin ?? 'Change PIN',
                    subtitle: AppStrings.of(context)?.changePinSubtitle ??
                        'Update your parental control PIN',
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
                  title: AppStrings.of(context)?.resetAllSettings ??
                      'Reset All Settings',
                  subtitle: AppStrings.of(context)?.resetSettingsSubtitle ??
                      'Restore all settings to default values',
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
        backgroundColor: AppTheme.backgroundColor,
        body: TVSidebar(
          selectedIndex: 4, // 设置页
          child: content,
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        title: Text(
          AppStrings.of(context)?.settings ?? 'Settings',
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: content,
    );
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

  void _showDecodingModeDialog(
      BuildContext context, SettingsProvider settings) {
    final options = ['auto', 'hardware', 'software'];

    showDialog(
      context: context,
      builder: (context) {
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
                  style:
                      const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
                value: mode,
                groupValue: settings.decodingMode,
                onChanged: (value) {
                  if (value != null) {
                    settings.setDecodingMode(value);
                    Navigator.pop(context);
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
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      color: AppTheme.cardColor,
      height: 1,
      indent: 56,
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
            color: isFocused ? AppTheme.cardColor : Colors.transparent,
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
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
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
            color: isFocused ? AppTheme.cardColor : Colors.transparent,
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
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textMuted,
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
            color: isFocused
                ? (isDestructive
                    ? AppTheme.errorColor.withOpacity(0.1)
                    : AppTheme.cardColor)
                : Colors.transparent,
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
                  color: (isDestructive
                          ? AppTheme.errorColor
                          : AppTheme.primaryColor)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: isDestructive
                      ? AppTheme.errorColor
                      : AppTheme.primaryColor,
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
                        color: isDestructive
                            ? AppTheme.errorColor
                            : AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
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
              color: AppTheme.textMuted.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppTheme.textMuted, size: 20),
          ),
          const SizedBox(width: 16),
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _showBufferSizeDialog(BuildContext context, SettingsProvider settings) {
    final options = [10, 20, 30, 45, 60];

    showDialog(
      context: context,
      builder: (context) {
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
                    Navigator.pop(context);
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
      builder: (context) {
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
                    Navigator.pop(context);
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

  void _showRefreshIntervalDialog(
      BuildContext context, SettingsProvider settings) {
    final options = [6, 12, 24, 48, 72];

    showDialog(
      context: context,
      builder: (context) {
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
                    Navigator.pop(context);
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
      builder: (context) {
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
              hintText:
                  AppStrings.of(context)?.enterEpgUrl ?? 'Enter EPG XMLTV URL',
              hintStyle: const TextStyle(color: AppTheme.textMuted),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppStrings.of(context)?.cancel ?? 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                settings.setEpgUrl(controller.text.trim().isEmpty
                    ? null
                    : controller.text.trim());
                Navigator.pop(context);
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
      builder: (context) {
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
              onPressed: () => Navigator.pop(context),
              child: Text(AppStrings.of(context)?.cancel ?? 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.length == 4) {
                  settings.setParentalPin(controller.text);
                  Navigator.pop(context);
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
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: Text(
            AppStrings.of(context)?.resetSettings ?? 'Reset Settings',
            style: const TextStyle(color: AppTheme.textPrimary),
          ),
          content: Text(
            AppStrings.of(context)?.resetConfirm ??
                'Are you sure you want to reset all settings to their default values?',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppStrings.of(context)?.cancel ?? 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                settings.resetSettings();
                Navigator.pop(context);
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
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: Text(
            AppStrings.of(context)?.language ?? 'Language',
            style: const TextStyle(color: AppTheme.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: const Text(
                  'English',
                  style: TextStyle(color: AppTheme.textPrimary),
                ),
                value: 'en',
                groupValue: settings.locale?.languageCode ?? 'en',
                onChanged: (value) {
                  settings.setLocale(const Locale('en'));
                  Navigator.pop(context);
                },
                activeColor: AppTheme.primaryColor,
              ),
              RadioListTile<String>(
                title: Text(
                  AppStrings.of(context)?.chinese ?? '中文',
                  style: const TextStyle(color: AppTheme.textPrimary),
                ),
                value: 'zh',
                groupValue: settings.locale?.languageCode ?? 'en',
                onChanged: (value) {
                  settings.setLocale(const Locale('zh'));
                  Navigator.pop(context);
                },
                activeColor: AppTheme.primaryColor,
              ),
            ],
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
}
