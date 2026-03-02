import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/color_scheme_manager.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../../core/widgets/tv_sidebar.dart';
import '../../../core/widgets/color_scheme_dialog.dart';
import '../../../core/platform/platform_detector.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/services/service_locator.dart';
import '../../player/providers/player_provider.dart';
import '../../multi_screen/providers/multi_screen_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/dlna_provider.dart';
import '../widgets/qr_log_export_dialog.dart';
import '../../epg/providers/epg_provider.dart';
import '../../backup/screens/backup_screen.dart';

class SettingsScreen extends StatefulWidget {
  final bool embedded;
  final bool autoCheckUpdate;
  
  const SettingsScreen({super.key, this.embedded = false, this.autoCheckUpdate = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    // 如果需要自动检查更新，延迟执行
    if (widget.autoCheckUpdate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkForUpdates(context);
      });
    }
  }

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

  // 获取对话框样式（横屏适配）
  Map<String, dynamic> _getDialogStyle(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isLandscape = screenWidth > 600 && screenWidth < 900 && screenHeight < screenWidth;
    
    return {
      'isLandscape': isLandscape,
      'shape': RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isLandscape ? 12 : 16),
      ),
      'contentPadding': EdgeInsets.all(isLandscape ? 12 : 20),
      'titlePadding': EdgeInsets.fromLTRB(
        isLandscape ? 16 : 24,
        isLandscape ? 12 : 20,
        isLandscape ? 16 : 24,
        isLandscape ? 8 : 16,
      ),
      'titleFontSize': isLandscape ? 14.0 : 18.0,
      'itemFontSize': isLandscape ? 12.0 : 14.0,
      'subtitleFontSize': isLandscape ? 9.0 : 11.0,
      'itemPadding': EdgeInsets.symmetric(
        horizontal: isLandscape ? 8.0 : 16.0,
        vertical: isLandscape ? 0.0 : 4.0,
      ),
      'visualDensity': isLandscape ? VisualDensity.compact : null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTV = PlatformDetector.isTV || size.width > 1200;
    final isWindows = PlatformDetector.isWindows;
    final isAndroid = PlatformDetector.isAndroid;
    final isMobile = PlatformDetector.isMobile;

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
              _buildDivider(),
              _buildSelectTile(
                context,
                title: AppStrings.of(context)?.colorScheme ?? 'Color Scheme',
                subtitle: _getCurrentColorSchemeName(context, settings),
                icon: Icons.color_lens_rounded,
                onTap: () => _showColorSchemeDialog(context),
              ),
              _buildDivider(),
              _buildSelectTile(
                context,
                title: AppStrings.of(context)?.fontFamily ?? '字体',
                subtitle: _getFontFamilyLabel(context, settings.fontFamily, settings),
                icon: Icons.text_fields_rounded,
                onTap: () => _showFontFamilyDialog(context, settings),
              ),
              _buildDivider(),
              _buildSwitchTile(
                context,
                title: AppStrings.of(context)?.simpleMenu ?? 'Simple Menu',
                subtitle: AppStrings.of(context)?.simpleMenuSubtitle ?? 'Keep menu collapsed (no auto-expand)',
                icon: Icons.menu_rounded,
                value: settings.simpleMenu,
                onChanged: (value) {
                  settings.setSimpleMenu(value);
                  final strings = AppStrings.of(context);
                  _showSuccess(context, value ? (strings?.simpleMenuEnabled ?? 'Simple menu enabled') : (strings?.simpleMenuDisabled ?? 'Simple menu disabled'));
                },
              ),
              _buildDivider(),
              _buildSwitchTile(
                context,
                title: AppStrings.of(context)?.showWatchHistoryOnHome ?? 'Show Watch History on Home',
                subtitle: AppStrings.of(context)?.showWatchHistoryOnHomeSubtitle ?? 'Display recently watched channels on home screen',
                icon: Icons.history_rounded,
                value: settings.showWatchHistoryOnHome,
                onChanged: (value) {
                  settings.setShowWatchHistoryOnHome(value);
                  final strings = AppStrings.of(context);
                  _showSuccess(context, value ? (strings?.watchHistoryOnHomeEnabled ?? 'Watch history on home enabled') : (strings?.watchHistoryOnHomeDisabled ?? 'Watch history on home disabled'));
                },
              ),
              _buildDivider(),
              _buildSwitchTile(
                context,
                title: AppStrings.of(context)?.showFavoritesOnHome ?? 'Show Favorites on Home',
                subtitle: AppStrings.of(context)?.showFavoritesOnHomeSubtitle ?? 'Display favorite channels on home screen',
                icon: Icons.favorite_rounded,
                value: settings.showFavoritesOnHome,
                onChanged: (value) {
                  settings.setShowFavoritesOnHome(value);
                  final strings = AppStrings.of(context);
                  _showSuccess(context, value ? (strings?.favoritesOnHomeEnabled ?? 'Favorites on home enabled') : (strings?.favoritesOnHomeDisabled ?? 'Favorites on home disabled'));
                },
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
              if (isWindows) ...[
                _buildDivider(),
                _buildSelectTile(
                  context,
                  title: AppStrings.of(context)?.decodingMode ?? 'Decoding Mode',
                  subtitle: _getDecodingModeLabel(context, settings.decodingMode),
                  icon: Icons.tune_rounded,
                  onTap: () => _showDecodingModeDialog(context, settings),
                ),
                _buildDivider(),
                _buildSelectTile(
                  context,
                  title: AppStrings.of(context)?.windowsHwdecMode ??
                      'Windows HW Decoder',
                  subtitle:
                      _getWindowsHwdecLabel(context, settings.windowsHwdecMode),
                  icon: Icons.speed_rounded,
                  onTap: () => _showWindowsHwdecDialog(context, settings),
                ),
                _buildDivider(),
                _buildSwitchTile(
                  context,
                  title: AppStrings.of(context)?.allowSoftwareFallback ??
                      'Allow Software Fallback',
                  subtitle: AppStrings.of(context)?.allowSoftwareFallbackDesc ??
                      'If hardware decode fails, automatically switch to software decoding.',
                  icon: Icons.swap_horiz_rounded,
                  value: settings.allowSoftwareFallback,
                  onChanged: (value) async {
                    await settings.setAllowSoftwareFallback(value);
                    await _reinitMediaKitPlayer(context, settings);
                    final strings = AppStrings.of(context);
                    _showSuccess(
                      context,
                      value
                          ? (strings?.allowSoftwareFallbackEnabled ??
                              'Software fallback enabled')
                          : (strings?.allowSoftwareFallbackDisabled ??
                              'Software fallback disabled'),
                    );
                  },
                ),
                _buildDivider(),
                _buildSelectTile(
                  context,
                  title: AppStrings.of(context)?.videoOutput ?? 'Video Output',
                  subtitle: _getVideoOutputLabel(context, settings.videoOutput),
                  icon: Icons.display_settings_rounded,
                  onTap: () => _showVideoOutputDialog(context, settings),
                ),
              ] else if (isAndroid && isMobile) ...[
                _buildDivider(),
                _buildSelectTile(
                  context,
                  title: AppStrings.of(context)?.decodingMode ?? 'Decoding Mode',
                  subtitle: _getDecodingModeLabel(context, settings.decodingMode),
                  icon: Icons.tune_rounded,
                  onTap: () => _showDecodingModeDialog(context, settings,
                      options: const ['auto', 'hardware', 'software']),
                ),
                _buildDivider(),
                _buildSwitchTile(
                  context,
                  title: AppStrings.of(context)?.allowSoftwareFallback ??
                      'Allow Software Fallback',
                  subtitle: AppStrings.of(context)?.allowSoftwareFallbackDesc ??
                      'If hardware decode fails, automatically switch to software decoding.',
                  icon: Icons.swap_horiz_rounded,
                  value: settings.allowSoftwareFallback,
                  onChanged: (value) async {
                    await settings.setAllowSoftwareFallback(value);
                    await _reinitMediaKitPlayer(context, settings);
                    final strings = AppStrings.of(context);
                    _showSuccess(
                      context,
                      value
                          ? (strings?.allowSoftwareFallbackEnabled ??
                              'Software fallback enabled')
                          : (strings?.allowSoftwareFallbackDisabled ??
                              'Software fallback disabled'),
                    );
                  },
                ),
                _buildDivider(),
                _buildSelectTile(
                  context,
                  title: AppStrings.of(context)?.videoOutput ?? 'Video Output',
                  subtitle: _getVideoOutputLabel(context, settings.videoOutput),
                  icon: Icons.display_settings_rounded,
                  onTap: () => _showVideoOutputDialog(
                    context,
                    settings,
                    options: const ['auto', 'libmpv'],
                  ),
                ),
              ] else if (isAndroid && isTV) ...[
                _buildDivider(),
                _buildSelectTile(
                  context,
                  title: AppStrings.of(context)?.decodingMode ?? 'Decoding Mode',
                  subtitle: _getDecodingModeLabel(context, settings.decodingMode),
                  icon: Icons.tune_rounded,
                  onTap: () => _showDecodingModeDialog(
                    context,
                    settings,
                    options: const ['auto', 'software'],
                  ),
                ),
                _buildDivider(),
                _buildSwitchTile(
                  context,
                  title: AppStrings.of(context)?.allowSoftwareFallback ??
                      'Allow Software Fallback',
                  subtitle: AppStrings.of(context)?.allowSoftwareFallbackDesc ??
                      'If hardware decode fails, automatically switch to software decoding.',
                  icon: Icons.swap_horiz_rounded,
                  value: settings.allowSoftwareFallback,
                  onChanged: (value) async {
                    await settings.setAllowSoftwareFallback(value);
                    await _reinitMediaKitPlayer(context, settings);
                    final strings = AppStrings.of(context);
                    _showSuccess(
                      context,
                      value
                          ? (strings?.allowSoftwareFallbackEnabled ??
                              'Software fallback enabled')
                          : (strings?.allowSoftwareFallbackDisabled ??
                              'Software fallback disabled'),
                    );
                  },
                ),
              ] else ...[
                _buildDivider(),
                _buildSwitchTile(
                  context,
                  title: AppStrings.of(context)?.allowSoftwareFallback ??
                      'Allow Software Fallback',
                  subtitle: AppStrings.of(context)?.allowSoftwareFallbackDesc ??
                      'If hardware decode fails, automatically switch to software decoding.',
                  icon: Icons.swap_horiz_rounded,
                  value: settings.allowSoftwareFallback,
                  onChanged: (value) async {
                    await settings.setAllowSoftwareFallback(value);
                    await _reinitMediaKitPlayer(context, settings);
                    final strings = AppStrings.of(context);
                    _showSuccess(
                      context,
                      value
                          ? (strings?.allowSoftwareFallbackEnabled ??
                              'Software fallback enabled')
                          : (strings?.allowSoftwareFallbackDisabled ??
                              'Software fallback disabled'),
                    );
                  },
                ),
                _buildDivider(),
                _buildSelectTile(
                  context,
                  title: AppStrings.of(context)?.videoOutput ?? 'Video Output',
                  subtitle: _getVideoOutputLabel(context, settings.videoOutput),
                  icon: Icons.display_settings_rounded,
                  onTap: () => _showVideoOutputDialog(context, settings),
                ),
              ],
                _buildDivider(),
                _buildSelectTile(
                  context,
                  title: AppStrings.of(context)?.channelMergeRule ?? 'Channel Merge Rule',
                  subtitle: _getChannelMergeRuleLabel(context, settings.channelMergeRule),
                  icon: Icons.merge_rounded,
                  onTap: () => _showChannelMergeRuleDialog(context, settings),
                ),
              // 缓冲大小 - 暂时隐藏（未实现）
              // _buildDivider(),
              // _buildSelectTile(
              //   context,
              //   title: AppStrings.of(context)?.bufferSize ?? 'Buffer Size',
              //   subtitle: '${settings.bufferSize} ${AppStrings.of(context)?.seconds ?? 'seconds'} ${AppStrings.of(context)?.notImplemented ?? '(Not implemented)'}',
              //   icon: Icons.storage_rounded,
              //   onTap: () => _showBufferSizeDialog(context, settings),
              // ),
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
              _buildDivider(),
              _buildSelectTile(
                context,
                title: AppStrings.of(context)?.progressBarMode ?? '进度条显示',
                subtitle: _getProgressBarModeLabel(context, settings.progressBarMode),
                icon: Icons.linear_scale_rounded,
                onTap: () => _showProgressBarModeDialog(context, settings),
              ),
              if (PlatformDetector.isTV) ...[
                _buildDivider(),
                _buildSelectTile(
                  context,
                  title: AppStrings.of(context)?.seekStepSeconds ?? '快进/快退跨度',
                  subtitle: _getSeekStepLabel(context, settings.seekStepSeconds),
                  icon: Icons.fast_forward_rounded,
                  onTap: () => _showSeekStepDialog(context, settings),
                ),
              ],
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
                _buildDivider(),
                _buildSwitchTile(
                  context,
                  title: AppStrings.of(context)?.showMultiScreenChannelName ?? 'Show Channel Names',
                  subtitle: AppStrings.of(context)?.showMultiScreenChannelNameSubtitle ?? 'Display channel names in multi-screen playback',
                  icon: Icons.text_fields_rounded,
                  value: settings.showMultiScreenChannelName,
                  onChanged: (value) {
                    settings.setShowMultiScreenChannelName(value);
                    final strings = AppStrings.of(context);
                    _showSuccess(context, value ? (strings?.multiScreenChannelNameEnabled ?? 'Multi-screen channel name display enabled') : (strings?.multiScreenChannelNameDisabled ?? 'Multi-screen channel name display disabled'));
                  },
                ),
              ],
              // 手机端屏幕方向设置
              if (PlatformDetector.isMobile) ...[
                _buildDivider(),
                _buildSelectTile(
                  context,
                  title: '屏幕方向',
                  subtitle: _getOrientationLabel(context, settings.mobileOrientation),
                  icon: Icons.screen_rotation_rounded,
                  onTap: () => _showOrientationDialog(context, settings),
                ),
              ],
              // 音量标准化 - 暂时隐藏（未实现）
              // _buildDivider(),
              // _buildSwitchTile(
              //   context,
              //   title: AppStrings.of(context)?.volumeNormalization ?? 'Volume Normalization',
              //   subtitle: '${AppStrings.of(context)?.volumeNormalizationSubtitle ?? 'Auto-adjust volume differences between channels'} ${AppStrings.of(context)?.notImplemented ?? '(Not implemented)'}',
              //   icon: Icons.volume_up_rounded,
              //   value: settings.volumeNormalization,
              //   onChanged: (value) {
              //     settings.setVolumeNormalization(value);
              //     final strings = AppStrings.of(context);
              //     _showError(context, strings?.volumeNormalizationNotImplemented ?? 'Volume normalization not implemented, setting will not take effect');
              //   },
              // ),
              // 音量增强 - 始终显示（已实现）
              _buildDivider(),
              _buildSelectTile(
                context,
                title: AppStrings.of(context)?.volumeBoost ?? 'Volume Boost',
                subtitle: settings.volumeBoost == 0 ? (AppStrings.of(context)?.noBoost ?? 'No boost') : '${settings.volumeBoost > 0 ? '+' : ''}${settings.volumeBoost} dB',
                icon: Icons.equalizer_rounded,
                onTap: () => _showVolumeBoostDialog(context, settings),
              ),
            ]),

            const SizedBox(height: 24),

            // Playlist Settings
            _buildSectionHeader(AppStrings.of(context)?.playlists ?? 'Playlists'),
            _buildSettingsCard([
              _buildSwitchTile(
                context,
                title: AppStrings.of(context)?.autoRefresh ?? 'Auto-refresh',
                subtitle: AppStrings.of(context)?.autoRefreshSubtitle ?? 'Automatically update playlists periodically',
                icon: Icons.refresh_rounded,
                value: settings.autoRefresh,
                onChanged: (value) {
                  settings.setAutoRefresh(value);
                  _showSuccess(context, value 
                    ? 'Auto-refresh enabled' 
                    : 'Auto-refresh disabled');
                },
              ),
              if (settings.autoRefresh) ...[
                _buildDivider(),
                _buildSelectTile(
                  context,
                  title: AppStrings.of(context)?.refreshInterval ?? 'Refresh Interval',
                  subtitle: 'Every ${settings.refreshInterval} ${AppStrings.of(context)?.hours ?? 'hours'}',
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

            // 家长控制 - 暂时隐藏（未实现）
            // const SizedBox(height: 24),
            // _buildSectionHeader(AppStrings.of(context)?.parentalControl ?? 'Parental Control'),
            // _buildSettingsCard([
            //   _buildSwitchTile(
            //     context,
            //     title: AppStrings.of(context)?.enableParentalControl ?? 'Enable Parental Control',
            //     subtitle: '${AppStrings.of(context)?.enableParentalControlSubtitle ?? 'Require PIN to access certain content'} ${AppStrings.of(context)?.notImplemented ?? '(Not implemented)'}',
            //     icon: Icons.lock_outline_rounded,
            //     value: settings.parentalControl,
            //     onChanged: (value) {
            //       settings.setParentalControl(value);
            //       final strings = AppStrings.of(context);
            //       _showError(context, strings?.parentalControlNotImplemented ?? 'Parental control not implemented, setting will not take effect');
            //     },
            //   ),
            //   if (settings.parentalControl) ...[
            //     _buildDivider(),
            //     _buildActionTile(
            //       context,
            //       title: AppStrings.of(context)?.changePin ?? 'Change PIN',
            //       subtitle: '${AppStrings.of(context)?.changePinSubtitle ?? 'Update your parental control PIN'} ${AppStrings.of(context)?.notImplemented ?? '(Not implemented)'}',
            //       icon: Icons.pin_rounded,
            //       onTap: () => _showChangePinDialog(context, settings),
            //     ),
            //   ],
            // ]),

            const SizedBox(height: 24),

            // Backup & Restore Section (所有平台都显示)
            _buildSectionHeader(AppStrings.of(context)?.backupAndRestore ?? '备份与恢复'),
            _buildSettingsCard([
              _buildActionTile(
                context,
                title: AppStrings.of(context)?.backupAndRestore ?? '备份与恢复',
                subtitle: AppStrings.of(context)?.backupAndRestoreSubtitle ?? '备份和恢复应用数据',
                icon: Icons.backup_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => BackupScreen()),
                  );
                },
              ),
            ]),
            const SizedBox(height: 24),

            // Developer & Debug Settings
            _buildSectionHeader(AppStrings.of(context)?.developerAndDebug ?? 'Developer & Debug'),
            _buildSettingsCard([
              _buildSelectTile(
                context,
                title: AppStrings.of(context)?.logLevel ?? 'Log Level',
                subtitle: _getLogLevelLabel(context, settings.logLevel),
                icon: Icons.bug_report_rounded,
                onTap: () => _showLogLevelDialog(context, settings),
              ),
              _buildDivider(),
              _buildActionTile(
                context,
                title: AppStrings.of(context)?.exportLogs ?? 'Export Logs',
                subtitle: AppStrings.of(context)?.exportLogsSubtitle ?? 'Export log files for diagnostics',
                icon: Icons.file_download_rounded,
                onTap: () => _exportLogs(context),
              ),
              _buildDivider(),
              _buildActionTile(
                context,
                title: AppStrings.of(context)?.clearLogs ?? 'Clear Logs',
                subtitle: AppStrings.of(context)?.clearLogsSubtitle ?? 'Delete all log files',
                icon: Icons.delete_sweep_rounded,
                onTap: () => _clearLogs(context),
              ),
              if (settings.logLevel != 'off') ...[
                _buildDivider(),
                _buildActionTile(
                  context,
                  title: AppStrings.of(context)?.logFileLocation ?? 'Log File Location',
                  subtitle: ServiceLocator.log.logFilePath ?? 'Unknown',
                  icon: Icons.folder_rounded,
                  onTap: () => _openLogFolder(context),
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
        body: Container(
          decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: Theme.of(context).brightness == Brightness.dark
                        ? [
                            AppTheme.getBackgroundColor(context),
                            AppTheme.getPrimaryColor(context).withOpacity(0.15),
                            AppTheme.getBackgroundColor(context),
                          ]
                        : [
                            AppTheme.getBackgroundColor(context),
                            AppTheme.getBackgroundColor(context).withOpacity(0.9),
                            AppTheme.getPrimaryColor(context).withOpacity(0.08),
                          ],
                  ),
          ),
          child: TVSidebar(
            selectedIndex: 5, // 设置页
            child: content,
          ),
        ),
      );
    }

    // 嵌入模式不使用Scaffold
    if (widget.embedded) {
      final isMobile = PlatformDetector.isMobile;
      final isLandscape = isMobile && MediaQuery.of(context).size.width > 700;
      final statusBarHeight = isMobile ? MediaQuery.of(context).padding.top : 0.0;
      final topPadding = isMobile ? (statusBarHeight > 0 ? statusBarHeight - 15.0 : 0.0) : 0.0;
      
      return Column(
        children: [
          // 简化的标题栏
          Container(
            padding: EdgeInsets.fromLTRB(
              12,
              topPadding + (isLandscape ? 4 : 8),  // 使用和首页相同的topPadding
              12,
              isLandscape ? 4 : 8,
            ),
            child: Row(
              children: [
                Text(
                  AppStrings.of(context)?.settings ?? 'Settings',
                  style: TextStyle(
                    color: AppTheme.getTextPrimary(context),
                    fontSize: isLandscape ? 14 : 18,  // 横屏时字体更小
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: content),
        ],
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.getBackgroundColor(context),
              AppTheme.getBackgroundColor(context).withOpacity(0.8),
              AppTheme.getPrimaryColor(context).withOpacity(0.05),
            ],
          ),
        ),
        child: Column(
          children: [
            // 手机端添加状态栏高度
            if (PlatformDetector.isMobile)
              SizedBox(height: MediaQuery.of(context).padding.top),
            AppBar(
              backgroundColor: Colors.transparent,
              primary: false,  // 禁用自动SafeArea padding
              toolbarHeight: PlatformDetector.isMobile && MediaQuery.of(context).size.width > 600 ? 24.0 : 56.0,  // 横屏时减小到24px
              automaticallyImplyLeading: false,  // 不显示返回按钮
              title: Text(
                AppStrings.of(context)?.settings ?? 'Settings',
                style: TextStyle(
                  color: AppTheme.getTextPrimary(context), 
                  fontSize: PlatformDetector.isMobile && MediaQuery.of(context).size.width > 600 ? 14 : 20,  // 横屏时字体14px
                  fontWeight: FontWeight.bold
                ),
              ),
            ),
            Expanded(child: content),
          ],
        ),
      ),
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

  String _getCurrentColorSchemeName(BuildContext context, SettingsProvider settings) {
    final strings = AppStrings.of(context);
    final manager = ColorSchemeManager.instance;
    
    // 判断当前是黑暗还是明亮模式
    final isDarkMode = _isDarkMode(context, settings);
    final schemeId = isDarkMode ? settings.darkColorScheme : settings.lightColorScheme;
    final scheme = isDarkMode 
        ? manager.getDarkScheme(schemeId) 
        : manager.getLightScheme(schemeId);
    
    // 返回配色名称
    switch (scheme.nameKey) {
      case 'colorSchemeLotus':
        return strings?.colorSchemeLotus ?? 'Lotus';
      case 'colorSchemeOcean':
        return strings?.colorSchemeOcean ?? 'Ocean';
      case 'colorSchemeForest':
        return strings?.colorSchemeForest ?? 'Forest';
      case 'colorSchemeSunset':
        return strings?.colorSchemeSunset ?? 'Sunset';
      case 'colorSchemeLavender':
        return strings?.colorSchemeLavender ?? 'Lavender';
      case 'colorSchemeMidnight':
        return strings?.colorSchemeMidnight ?? 'Midnight';
      case 'colorSchemeLotusLight':
        return strings?.colorSchemeLotusLight ?? 'Lotus Light';
      case 'colorSchemeSky':
        return strings?.colorSchemeSky ?? 'Sky';
      case 'colorSchemeSpring':
        return strings?.colorSchemeSpring ?? 'Spring';
      case 'colorSchemeCoral':
        return strings?.colorSchemeCoral ?? 'Coral';
      case 'colorSchemeViolet':
        return strings?.colorSchemeViolet ?? 'Violet';
      case 'colorSchemeClassic':
        return strings?.colorSchemeClassic ?? 'Classic';
      default:
        return scheme.id;
    }
  }

  bool _isDarkMode(BuildContext context, SettingsProvider settings) {
    if (settings.themeMode == 'dark') {
      return true;
    } else if (settings.themeMode == 'light') {
      return false;
    } else {
      // 跟随系统
      final brightness = MediaQuery.of(context).platformBrightness;
      return brightness == Brightness.dark;
    }
  }

  void _showColorSchemeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ColorSchemeDialog(),
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

  String _getDecodingModeDesc(BuildContext context, String mode) {
    final strings = AppStrings.of(context);
    switch (mode) {
      case 'hardware':
        return strings?.decodingModeHardwareDesc ??
            'Force hardware decoding. May fail on some GPUs.';
      case 'software':
        return strings?.decodingModeSoftwareDesc ??
            'Use CPU decoding for compatibility.';
      case 'auto':
      default:
        return strings?.decodingModeAutoDesc ??
            'Automatically choose the best option. Recommended.';
    }
  }

  void _showDecodingModeDialog(
    BuildContext context,
    SettingsProvider settings, {
    List<String>? options,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isLandscape = screenWidth > 600 && screenWidth < 900 && screenHeight < screenWidth;
    final modeOptions = options ?? const ['auto', 'hardware', 'software'];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.getSurfaceColor(dialogContext),
          contentPadding: EdgeInsets.fromLTRB(
            isLandscape ? 16 : 24,
            isLandscape ? 8 : 16,
            isLandscape ? 16 : 24,
            isLandscape ? 8 : 16,
          ),
          title: Text(
            AppStrings.of(context)?.decodingMode ?? 'Decoding Mode',
            style: TextStyle(
              color: AppTheme.getTextPrimary(context),
              fontSize: isLandscape ? 14 : 18,
            ),
          ),
          content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: modeOptions.map((mode) {
                  return RadioListTile<String>(
                  title: Text(
                    _getDecodingModeLabel(context, mode),
                    style: TextStyle(
                      color: AppTheme.getTextPrimary(context),
                      fontSize: isLandscape ? 12 : 14,
                    ),
                  ),
                  subtitle: Text(
                    _getDecodingModeDesc(context, mode),
                    style: TextStyle(
                      color: AppTheme.getTextMuted(context),
                      fontSize: isLandscape ? 9 : 11,
                    ),
                  ),
                  value: mode,
                  groupValue: settings.decodingMode,
                  onChanged: (value) async {
                    if (value != null) {
                      await settings.setDecodingMode(value);
                      await _reinitMediaKitPlayer(context, settings);
                      Navigator.pop(dialogContext);
                      final strings = AppStrings.of(context);
                      _showSuccess(
                        context,
                        (strings?.decodingModeSet ?? 'Decoding mode set to: {mode}')
                            .replaceFirst('{mode}', _getDecodingModeLabel(context, value)),
                      );
                    }
                  },
                  activeColor: AppTheme.getPrimaryColor(dialogContext),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: isLandscape ? 8 : 16,
                    vertical: isLandscape ? 0 : 4,
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  String _getVideoOutputLabel(BuildContext context, String mode) {
    final strings = AppStrings.of(context);
    switch (mode) {
      case 'libmpv':
        return strings?.videoOutputLibmpv ?? 'libmpv (Embedded)';
      case 'gpu':
        return strings?.videoOutputGpu ?? 'GPU (External Window)';
      case 'auto':
      default:
        return strings?.videoOutputAuto ?? 'Auto (Embedded)';
    }
  }

  String _getVideoOutputDesc(BuildContext context, String mode) {
    final strings = AppStrings.of(context);
    switch (mode) {
      case 'libmpv':
        return strings?.videoOutputLibmpvDesc ??
            'Use libmpv embedded renderer (recommended).';
      case 'gpu':
        return strings?.videoOutputGpuDesc ??
            'Use GPU output; may open a separate window.';
      case 'auto':
      default:
        return strings?.videoOutputAutoDesc ??
            'Default embedded output (recommended).';
    }
  }

  void _showVideoOutputDialog(
    BuildContext context,
    SettingsProvider settings, {
    List<String>? options,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isLandscape = screenWidth > 600 && screenWidth < 900 && screenHeight < screenWidth;
    final outputOptions = options ?? const ['auto', 'libmpv', 'gpu'];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.getSurfaceColor(dialogContext),
          contentPadding: EdgeInsets.fromLTRB(
            isLandscape ? 16 : 24,
            isLandscape ? 8 : 16,
            isLandscape ? 16 : 24,
            isLandscape ? 8 : 16,
          ),
          title: Text(
            AppStrings.of(context)?.videoOutput ?? 'Video Output',
            style: TextStyle(
              color: AppTheme.getTextPrimary(context),
              fontSize: isLandscape ? 14 : 18,
            ),
          ),
          content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: outputOptions.map((mode) {
                  return RadioListTile<String>(
                  title: Text(
                    _getVideoOutputLabel(context, mode),
                    style: TextStyle(
                      color: AppTheme.getTextPrimary(context),
                      fontSize: isLandscape ? 12 : 14,
                    ),
                  ),
                  subtitle: Text(
                    _getVideoOutputDesc(context, mode),
                    style: TextStyle(
                      color: AppTheme.getTextMuted(context),
                      fontSize: isLandscape ? 9 : 11,
                    ),
                  ),
                  value: mode,
                  groupValue: settings.videoOutput,
                  onChanged: (value) async {
                    if (value != null) {
                      await settings.setVideoOutput(value);
                      await _reinitMediaKitPlayer(context, settings);
                      Navigator.pop(dialogContext);
                      final strings = AppStrings.of(context);
                      _showSuccess(
                        context,
                        (strings?.videoOutputSet ?? 'Video output set to: {mode}')
                            .replaceFirst('{mode}', _getVideoOutputLabel(context, value)),
                      );
                    }
                  },
                  activeColor: AppTheme.getPrimaryColor(dialogContext),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: isLandscape ? 8 : 16,
                    vertical: isLandscape ? 0 : 4,
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  String _getWindowsHwdecLabel(BuildContext context, String mode) {
    final strings = AppStrings.of(context);
    switch (mode) {
      case 'auto-copy':
        return strings?.windowsHwdecAutoCopy ?? 'Auto (Copy)';
      case 'd3d11va':
        return strings?.windowsHwdecD3d11va ?? 'D3D11VA';
      case 'dxva2':
        return strings?.windowsHwdecDxva2 ?? 'DXVA2';
      case 'auto-safe':
      default:
        return strings?.windowsHwdecAutoSafe ?? 'Auto (Safe)';
    }
  }

  String _getWindowsHwdecDesc(BuildContext context, String mode) {
    final strings = AppStrings.of(context);
    switch (mode) {
      case 'auto-copy':
        return strings?.windowsHwdecAutoCopyDesc ??
            'More compatible, but slower due to copy-back.';
      case 'd3d11va':
        return strings?.windowsHwdecD3d11vaDesc ??
            'Prefer D3D11VA. Can fail on some GPUs.';
      case 'dxva2':
        return strings?.windowsHwdecDxva2Desc ??
            'Prefer DXVA2. Legacy path for older GPUs.';
      case 'auto-safe':
      default:
        return strings?.windowsHwdecAutoSafeDesc ??
            'Recommended. Only use safe hardware decoders.';
    }
  }

  void _showWindowsHwdecDialog(BuildContext context, SettingsProvider settings) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isLandscape = screenWidth > 600 && screenWidth < 900 && screenHeight < screenWidth;
    final options = ['auto-safe', 'auto-copy', 'd3d11va', 'dxva2'];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.getSurfaceColor(dialogContext),
          contentPadding: EdgeInsets.fromLTRB(
            isLandscape ? 16 : 24,
            isLandscape ? 8 : 16,
            isLandscape ? 16 : 24,
            isLandscape ? 8 : 16,
          ),
          title: Text(
            AppStrings.of(context)?.windowsHwdecMode ?? 'Windows HW Decoder',
            style: TextStyle(
              color: AppTheme.getTextPrimary(context),
              fontSize: isLandscape ? 14 : 18,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: options.map((mode) {
                return RadioListTile<String>(
                  title: Text(
                    _getWindowsHwdecLabel(context, mode),
                    style: TextStyle(
                      color: AppTheme.getTextPrimary(context),
                      fontSize: isLandscape ? 12 : 14,
                    ),
                  ),
                  subtitle: Text(
                    _getWindowsHwdecDesc(context, mode),
                    style: TextStyle(
                      color: AppTheme.getTextMuted(context),
                      fontSize: isLandscape ? 9 : 11,
                    ),
                  ),
                  value: mode,
                  groupValue: settings.windowsHwdecMode,
                  onChanged: (value) async {
                    if (value != null) {
                      await settings.setWindowsHwdecMode(value);
                      await _reinitMediaKitPlayer(context, settings);
                      Navigator.pop(dialogContext);
                      final strings = AppStrings.of(context);
                      _showSuccess(
                        context,
                        (strings?.windowsHwdecModeSet ??
                                'Windows HW decode set to: {mode}')
                            .replaceFirst('{mode}', _getWindowsHwdecLabel(context, value)),
                      );
                    }
                  },
                  activeColor: AppTheme.getPrimaryColor(dialogContext),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: isLandscape ? 8 : 16,
                    vertical: isLandscape ? 0 : 4,
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Future<void> _reinitMediaKitPlayer(BuildContext context, SettingsProvider settings) async {
    // Settings screen may appear without PlayerProvider in the widget tree.
    try {
      await context.read<PlayerProvider>().reinitializePlayer(
        bufferStrength: settings.bufferStrength,
      );
    } catch (_) {}
    // Reinitialize multi-screen players if available.
    try {
      await context.read<MultiScreenProvider>().reinitializePlayers(
        videoOutput: settings.videoOutput,
        windowsHwdecMode: settings.windowsHwdecMode,
        allowSoftwareFallback: settings.allowSoftwareFallback,
        decodingMode: settings.decodingMode,
        bufferStrength: settings.bufferStrength,
      );
    } catch (_) {}
  }

  String _getChannelMergeRuleLabel(BuildContext context, String rule) {
    final strings = AppStrings.of(context);
    switch (rule) {
      case 'name':
        return strings?.mergeByName ?? 'Merge by Name';
      case 'name_group':
      default:
        return strings?.mergeByNameGroup ?? 'Merge by Name + Group';
    }
  }

  void _showChannelMergeRuleDialog(BuildContext context, SettingsProvider settings) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isLandscape = screenWidth > 600 && screenWidth < 900 && screenHeight < screenWidth;
    final options = ['name_group', 'name'];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.getSurfaceColor(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isLandscape ? 12 : 16),
          ),
          contentPadding: EdgeInsets.all(isLandscape ? 12 : 20),
          titlePadding: EdgeInsets.fromLTRB(
            isLandscape ? 16 : 24,
            isLandscape ? 12 : 20,
            isLandscape ? 16 : 24,
            isLandscape ? 8 : 16,
          ),
          title: Text(
            AppStrings.of(context)?.channelMergeRule ?? 'Channel Merge Rule',
            style: TextStyle(
              color: AppTheme.getTextPrimary(context),
              fontSize: isLandscape ? 14 : 18,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: options.map((rule) {
                return RadioListTile<String>(
                  title: Text(
                    _getChannelMergeRuleLabel(context, rule),
                    style: TextStyle(
                      color: AppTheme.getTextPrimary(context),
                      fontSize: isLandscape ? 12 : 14,
                    ),
                  ),
                  subtitle: Text(
                    _getChannelMergeRuleDescription(context, rule),
                    style: TextStyle(
                      color: AppTheme.getTextMuted(context),
                      fontSize: isLandscape ? 9 : 11,
                    ),
                  ),
                  value: rule,
                  groupValue: settings.channelMergeRule,
                  onChanged: (value) {
                    if (value != null) {
                      settings.setChannelMergeRule(value);
                      Navigator.pop(dialogContext);
                      final strings = AppStrings.of(context);
                      _showSuccess(context, (strings?.channelMergeRuleSet ?? 'Channel merge rule set to: {rule}').replaceFirst('{rule}', _getChannelMergeRuleLabel(context, value)));
                    }
                  },
                  activeColor: AppTheme.getPrimaryColor(dialogContext),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: isLandscape ? 8 : 16,
                    vertical: isLandscape ? 0 : 4,
                  ),
                  visualDensity: isLandscape ? VisualDensity.compact : null,
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  String _getChannelMergeRuleDescription(BuildContext context, String rule) {
    final strings = AppStrings.of(context);
    switch (rule) {
      case 'name':
        return strings?.mergeByNameDesc ?? 'Merge channels with same name across all groups';
      case 'name_group':
      default:
        return strings?.mergeByNameGroupDesc ?? 'Only merge channels with same name AND group';
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
    final isMobile = PlatformDetector.isMobile;
    final isLandscape = isMobile && MediaQuery.of(context).size.width > 600;
    
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
        padding: EdgeInsets.symmetric(
          horizontal: isLandscape ? 12 : 16,
          vertical: isLandscape ? 8 : 14,
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isLandscape ? 6 : 8),
              decoration: BoxDecoration(
                color: AppTheme.getPrimaryColor(context).withOpacity(0.15),
                borderRadius: BorderRadius.circular(isLandscape ? 6 : 8),
              ),
              child: Icon(
                icon,
                color: AppTheme.getPrimaryColor(context),
                size: isLandscape ? 16 : 20,
              ),
            ),
            SizedBox(width: isLandscape ? 12 : 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppTheme.getTextPrimary(context),
                      fontSize: isLandscape ? 13 : 15,  // 横屏时字体更小
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppTheme.getTextMuted(context),
                      fontSize: isLandscape ? 10 : 12,  // 横屏时字体更小
                    ),
                  ),
                ],
              ),
            ),
            Transform.scale(
              scale: isLandscape ? 0.8 : 1.0,  // 横屏时开关更小
              child: Switch(
                value: value,
                onChanged: onChanged,
                activeColor: AppTheme.getPrimaryColor(context),
              ),
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
    final isMobile = PlatformDetector.isMobile;
    final isLandscape = isMobile && MediaQuery.of(context).size.width > 600;
    
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
          padding: EdgeInsets.symmetric(
            horizontal: isLandscape ? 12 : 16,
            vertical: isLandscape ? 8 : 14,
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(isLandscape ? 6 : 8),
                decoration: BoxDecoration(
                  color: AppTheme.getPrimaryColor(context).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(isLandscape ? 6 : 8),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.getPrimaryColor(context),
                  size: isLandscape ? 16 : 20,
                ),
              ),
              SizedBox(width: isLandscape ? 12 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppTheme.getTextPrimary(context),
                        fontSize: isLandscape ? 13 : 15,  // 横屏时字体更小
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppTheme.getTextMuted(context),
                        fontSize: isLandscape ? 10 : 12,  // 横屏时字体更小
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.getTextMuted(context),
                size: isLandscape ? 18 : 24,  // 横屏时图标更小
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
    final isMobile = PlatformDetector.isMobile;
    final isLandscape = isMobile && MediaQuery.of(context).size.width > 600;
    
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
          padding: EdgeInsets.symmetric(
            horizontal: isLandscape ? 12 : 16,
            vertical: isLandscape ? 8 : 14,
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(isLandscape ? 6 : 8),
                decoration: BoxDecoration(
                  color: (isDestructive ? AppTheme.errorColor : AppTheme.getPrimaryColor(context)).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(isLandscape ? 6 : 8),
                ),
                child: Icon(
                  icon,
                  color: isDestructive ? AppTheme.errorColor : AppTheme.getPrimaryColor(context),
                  size: isLandscape ? 16 : 20,
                ),
              ),
              SizedBox(width: isLandscape ? 12 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isDestructive ? AppTheme.errorColor : AppTheme.getTextPrimary(context),
                        fontSize: isLandscape ? 13 : 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppTheme.getTextMuted(context),
                        fontSize: isLandscape ? 10 : 12,
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
    final style = _getDialogStyle(context);
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
          backgroundColor: AppTheme.getSurfaceColor(context),
          shape: style['shape'],
          contentPadding: style['contentPadding'],
          titlePadding: style['titlePadding'],
          title: Text(
            strings?.bufferStrength ?? 'Buffer Strength',
            style: TextStyle(
              color: AppTheme.getTextPrimary(context),
              fontSize: style['titleFontSize'],
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: options.map((strength) {
                return RadioListTile<String>(
                  title: Text(
                    labels[strength] ?? strength,
                    style: TextStyle(
                      color: AppTheme.getTextPrimary(context),
                      fontSize: style['itemFontSize'],
                    ),
                  ),
                  value: strength,
                  groupValue: settings.bufferStrength,
                    onChanged: (value) async {
                      if (value != null) {
                        await settings.setBufferStrength(value);
                        await _reinitMediaKitPlayer(context, settings);
                        Navigator.pop(dialogContext);
                      }
                    },
                  activeColor: AppTheme.getPrimaryColor(dialogContext),
                  contentPadding: style['itemPadding'],
                  visualDensity: style['visualDensity'],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  void _showProgressBarModeDialog(BuildContext context, SettingsProvider settings) {
    final style = _getDialogStyle(context);
    final options = ['auto', 'always', 'never'];
    final strings = AppStrings.of(context);
    final labels = {
      'auto': strings?.progressBarModeAuto ?? '自动检测',
      'always': strings?.progressBarModeAlways ?? '始终显示',
      'never': strings?.progressBarModeNever ?? '不显示',
    };
    final descriptions = {
      'auto': strings?.progressBarModeAutoDesc ?? '根据内容类型自动显示（点播/回放显示，直播隐藏）',
      'always': strings?.progressBarModeAlwaysDesc ?? '所有内容都显示进度条',
      'never': strings?.progressBarModeNeverDesc ?? '所有内容都不显示进度条',
    };

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.getSurfaceColor(context),
          shape: style['shape'],
          contentPadding: style['contentPadding'],
          titlePadding: style['titlePadding'],
          title: Text(
            strings?.progressBarMode ?? '进度条显示',
            style: TextStyle(
              color: AppTheme.getTextPrimary(context),
              fontSize: style['titleFontSize'],
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: options.map((mode) {
                return RadioListTile<String>(
                  title: Text(
                    labels[mode] ?? mode,
                    style: TextStyle(
                      color: AppTheme.getTextPrimary(context),
                      fontSize: style['itemFontSize'],
                    ),
                  ),
                  subtitle: Text(
                    descriptions[mode] ?? '',
                    style: TextStyle(
                      color: AppTheme.getTextMuted(context),
                      fontSize: style['subtitleFontSize'],
                    ),
                  ),
                  value: mode,
                  groupValue: settings.progressBarMode,
                  onChanged: (value) {
                    if (value != null) {
                      settings.setProgressBarMode(value);
                      Navigator.pop(dialogContext);
                      final message = (strings?.progressBarModeSet ?? '进度条显示已设置为：{mode}')
                          .replaceFirst('{mode}', labels[value] ?? value);
                      _showSuccess(context, message);
                    }
                  },
                  activeColor: AppTheme.getPrimaryColor(dialogContext),
                  contentPadding: style['itemPadding'],
                  visualDensity: style['visualDensity'],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  String _getProgressBarModeLabel(BuildContext context, String mode) {
    final strings = AppStrings.of(context);
    switch (mode) {
      case 'auto':
        return strings?.progressBarModeAuto ?? '自动检测';
      case 'always':
        return strings?.progressBarModeAlways ?? '始终显示';
      case 'never':
        return strings?.progressBarModeNever ?? '不显示';
      default:
        return strings?.progressBarModeAuto ?? '自动检测';
    }
  }

  void _showSeekStepDialog(BuildContext context, SettingsProvider settings) {
    final style = _getDialogStyle(context);
    final options = [5, 10, 30, 60, 120];
    final strings = AppStrings.of(context);
    final labels = {
      5: strings?.seekStep5s ?? '5秒',
      10: strings?.seekStep10s ?? '10秒',
      30: strings?.seekStep30s ?? '30秒',
      60: strings?.seekStep60s ?? '60秒',
      120: strings?.seekStep120s ?? '120秒',
    };

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: style['backgroundColor'],
          shape: style['shape'],
          titlePadding: style['titlePadding'],
          title: Text(
            strings?.seekStepSeconds ?? '快进/快退跨度',
            style: TextStyle(
              color: AppTheme.getTextPrimary(context),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          contentPadding: style['contentPadding'],
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: options.map((seconds) {
                return RadioListTile<int>(
                  title: Text(
                    labels[seconds] ?? '$seconds秒',
                    style: TextStyle(
                      color: AppTheme.getTextPrimary(dialogContext),
                      fontSize: 14,
                    ),
                  ),
                  value: seconds,
                  groupValue: settings.seekStepSeconds,
                  onChanged: (value) {
                    if (value != null) {
                      settings.setSeekStepSeconds(value);
                      Navigator.pop(dialogContext);
                      final message = (strings?.seekStepSet ?? '快进/快退跨度已设置为：{seconds}秒')
                          .replaceFirst('{seconds}', value.toString());
                      _showSuccess(context, message);
                    }
                  },
                  activeColor: AppTheme.getPrimaryColor(dialogContext),
                  contentPadding: style['itemPadding'],
                  visualDensity: style['visualDensity'],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  String _getSeekStepLabel(BuildContext context, int seconds) {
    final strings = AppStrings.of(context);
    switch (seconds) {
      case 5:
        return strings?.seekStep5s ?? '5秒';
      case 10:
        return strings?.seekStep10s ?? '10秒';
      case 30:
        return strings?.seekStep30s ?? '30秒';
      case 60:
        return strings?.seekStep60s ?? '60秒';
      case 120:
        return strings?.seekStep120s ?? '120秒';
      default:
        return '$seconds秒';
    }
  }

  void _showBufferSizeDialog(BuildContext context, SettingsProvider settings) {
    final options = [10, 20, 30, 45, 60];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.getSurfaceColor(context),
          title: Text(
            AppStrings.of(context)?.bufferSize ?? 'Buffer Size',
            style: TextStyle(color: AppTheme.getTextPrimary(context)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((seconds) {
              return RadioListTile<int>(
                title: Text(
                  '$seconds ${AppStrings.of(context)?.seconds ?? 'seconds'}',
                  style: TextStyle(color: AppTheme.getTextPrimary(context)),
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
                activeColor: AppTheme.getPrimaryColor(dialogContext),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showVolumeBoostDialog(BuildContext context, SettingsProvider settings) {
    final style = _getDialogStyle(context);
    final options = [-10, -5, 0, 5, 10, 15, 20];

    showDialog(
      context: context,
      builder: (dialogContext) {
        final strings = AppStrings.of(context);
        return AlertDialog(
          backgroundColor: AppTheme.getSurfaceColor(context),
          shape: style['shape'],
          contentPadding: style['contentPadding'],
          titlePadding: style['titlePadding'],
          title: Text(
            strings?.volumeBoost ?? 'Volume Boost',
            style: TextStyle(
              color: AppTheme.getTextPrimary(context),
              fontSize: style['titleFontSize'],
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: options.map((db) {
                  return RadioListTile<int>(
                    title: Text(
                      db == 0 ? '${strings?.noBoost ?? "No boost"} (0 dB)' : '${db > 0 ? '+' : ''}$db dB',
                      style: TextStyle(
                        color: AppTheme.getTextPrimary(context),
                        fontSize: style['itemFontSize'],
                      ),
                    ),
                    subtitle: Text(
                      _getVolumeBoostDescription(context, db),
                      style: TextStyle(
                        color: AppTheme.getTextMuted(context),
                        fontSize: style['subtitleFontSize'],
                      ),
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
                    activeColor: AppTheme.getPrimaryColor(dialogContext),
                    contentPadding: style['itemPadding'],
                    visualDensity: style['visualDensity'],
                  );
                }).toList(),
              ),
            ),
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
    final style = _getDialogStyle(context);
    final options = [6, 12, 24, 48, 72];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.getSurfaceColor(context),
          shape: style['shape'],
          contentPadding: style['contentPadding'],
          titlePadding: style['titlePadding'],
          title: Text(
            AppStrings.of(context)?.refreshInterval ?? 'Refresh Interval',
            style: TextStyle(
              color: AppTheme.getTextPrimary(context),
              fontSize: style['titleFontSize'],
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: options.map((hours) {
                return RadioListTile<int>(
                  title: Text(
                    hours < 24
                        ? '$hours ${AppStrings.of(context)?.hours ?? 'hours'}'
                        : '${hours ~/ 24} ${hours ~/ 24 > 1 ? (AppStrings.of(context)?.days ?? 'days') : (AppStrings.of(context)?.day ?? 'day')}',
                    style: TextStyle(
                      color: AppTheme.getTextPrimary(context),
                      fontSize: style['itemFontSize'],
                    ),
                  ),
                  value: hours,
                  groupValue: settings.refreshInterval,
                  onChanged: (value) {
                    if (value != null) {
                      settings.setRefreshInterval(value);
                      Navigator.pop(dialogContext);
                      final strings = AppStrings.of(context);
                      _showSuccess(context, 'Refresh interval: $value ${strings?.hours ?? 'hours'}');
                    }
                  },
                  activeColor: AppTheme.getPrimaryColor(dialogContext),
                  contentPadding: style['itemPadding'],
                  visualDensity: style['visualDensity'],
                );
              }).toList(),
            ),
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
          backgroundColor: AppTheme.getSurfaceColor(context),
          title: Text(
            AppStrings.of(context)?.epgUrl ?? 'EPG URL',
            style: TextStyle(color: AppTheme.getTextPrimary(context)),
          ),
          content: TextField(
            controller: controller,
            style: TextStyle(color: AppTheme.getTextPrimary(context)),
            decoration: InputDecoration(
              hintText: AppStrings.of(context)?.enterEpgUrl ?? 'Enter EPG XMLTV URL',
              hintStyle: TextStyle(color: AppTheme.getTextMuted(context)),
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
                    // User-initiated action, show loading state
                    final success = await epgProvider.loadEpg(newUrl, silent: false);
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
          backgroundColor: AppTheme.getSurfaceColor(context),
          title: Text(
            AppStrings.of(context)?.setPin ?? 'Set PIN',
            style: TextStyle(color: AppTheme.getTextPrimary(context)),
          ),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            style: TextStyle(color: AppTheme.getTextPrimary(context)),
            decoration: InputDecoration(
              hintText: AppStrings.of(context)?.enterPin ?? 'Enter 4-digit PIN',
              hintStyle: TextStyle(color: AppTheme.getTextMuted(context)),
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
          backgroundColor: AppTheme.getSurfaceColor(context),
          title: Text(
            AppStrings.of(context)?.resetSettings ?? 'Reset Settings',
            style: TextStyle(color: AppTheme.getTextPrimary(context)),
          ),
          content: Text(
            AppStrings.of(context)?.resetConfirm ?? 'Are you sure you want to reset all settings to their default values?',
            style: TextStyle(color: AppTheme.getTextSecondary(context)),
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
          backgroundColor: AppTheme.getSurfaceColor(context),
          title: Text(
            AppStrings.of(context)?.language ?? 'Language',
            style: TextStyle(color: AppTheme.getTextPrimary(context)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String?>(
                title: Text(
                  AppStrings.of(context)?.followSystem ?? '跟随系统',
                  style: TextStyle(color: AppTheme.getTextPrimary(context)),
                ),
                value: null,
                groupValue: currentLang,
                onChanged: (value) {
                  settings.setLocale(null);
                  Navigator.pop(dialogContext);
                  _showSuccess(context, AppStrings.of(context)?.languageFollowSystem ?? '已设置为跟随系统语言');
                },
                activeColor: AppTheme.getPrimaryColor(dialogContext),
              ),
              RadioListTile<String?>(
                title: Text(
                  'English',
                  style: TextStyle(color: AppTheme.getTextPrimary(context)),
                ),
                value: 'en',
                groupValue: currentLang,
                onChanged: (value) {
                  settings.setLocale(const Locale('en'));
                  Navigator.pop(dialogContext);
                  _showSuccess(context, 'Language changed to English');
                },
                activeColor: AppTheme.getPrimaryColor(dialogContext),
              ),
              RadioListTile<String?>(
                title: Text(
                  AppStrings.of(context)?.chinese ?? '中文',
                  style: TextStyle(color: AppTheme.getTextPrimary(context)),
                ),
                value: 'zh',
                groupValue: currentLang,
                onChanged: (value) {
                  settings.setLocale(const Locale('zh'));
                  Navigator.pop(dialogContext);
                  final strings = AppStrings.of(context);
                  _showSuccess(context, strings?.languageSwitchedToChinese ?? 'Language switched to Chinese');
                },
                activeColor: AppTheme.getPrimaryColor(dialogContext),
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
    final style = _getDialogStyle(context);
    final options = ['system', 'light', 'dark'];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.getSurfaceColor(context),
          shape: style['shape'],
          contentPadding: style['contentPadding'],
          titlePadding: style['titlePadding'],
          title: Text(
            AppStrings.of(context)?.theme ?? 'Theme',
            style: TextStyle(
              color: AppTheme.getTextPrimary(context),
              fontSize: style['titleFontSize'],
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: options.map((mode) {
                return RadioListTile<String>(
                  title: Text(
                    _getThemeModeLabel(context, mode),
                    style: TextStyle(
                      color: AppTheme.getTextPrimary(context),
                      fontSize: style['itemFontSize'],
                    ),
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
                  activeColor: AppTheme.getPrimaryColor(dialogContext),
                  contentPadding: style['itemPadding'],
                  visualDensity: style['visualDensity'],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  void _showLogLevelDialog(BuildContext context, SettingsProvider settings) {
    final options = ['debug', 'release', 'off'];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.getSurfaceColor(context),
          title: Text(
            AppStrings.of(context)?.logLevel ?? 'Log Level',
            style: TextStyle(color: AppTheme.getTextPrimary(context)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((level) {
              return RadioListTile<String>(
                title: Text(
                  _getLogLevelLabel(context, level),
                  style: TextStyle(color: AppTheme.getTextPrimary(context)),
                ),
                subtitle: Text(
                  _getLogLevelDescription(context, level),
                  style: TextStyle(color: AppTheme.getTextSecondary(context), fontSize: 12),
                ),
                value: level,
                groupValue: settings.logLevel,
                onChanged: (value) async {
                  if (value != null) {
                    await settings.setLogLevel(value);
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                      _showSuccess(context, '${AppStrings.of(context)?.logLevel ?? "Log level"}: ${_getLogLevelLabel(context, value)}');
                    }
                  }
                },
                activeColor: AppTheme.getPrimaryColor(dialogContext),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Future<void> _exportLogs(BuildContext context) async {
    // 显示二维码对话框
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const QrLogExportDialog(),
    );
  }

  Future<void> _clearLogs(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.getSurfaceColor(context),
        title: Text(
          AppStrings.of(context)?.clearLogsConfirm ?? 'Clear Logs',
          style: TextStyle(color: AppTheme.getTextPrimary(context)),
        ),
        content: Text(
          AppStrings.of(context)?.clearLogsConfirmMessage ?? 'Are you sure you want to delete all log files? This action cannot be undone.',
          style: TextStyle(color: AppTheme.getTextSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.of(context)?.cancel ?? 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              AppStrings.of(context)?.delete ?? 'Delete',
              style: const TextStyle(color: AppTheme.errorColor),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ServiceLocator.log.clearLogs();
        if (context.mounted) {
          _showSuccess(context, AppStrings.of(context)?.logsCleared ?? 'Logs cleared');
        }
      } catch (e) {
        if (context.mounted) {
          _showError(context, '${AppStrings.of(context)?.error ?? "Error"}: $e');
        }
      }
    }
  }

  Future<void> _openLogFolder(BuildContext context) async {
    try {
      final logPath = ServiceLocator.log.logFilePath;
      if (logPath == null) {
        _showError(context, 'Log file path not available');
        return;
      }

      // 获取日志文件所在的目录
      final logDir = logPath.substring(0, logPath.lastIndexOf(Platform.pathSeparator));
      
      if (Platform.isWindows) {
        // Windows: 使用 explorer 打开文件夹
        await Process.run('explorer', [logDir]);
      } else if (Platform.isMacOS) {
        // macOS: 使用 open 命令
        await Process.run('open', [logDir]);
      } else if (Platform.isLinux) {
        // Linux: 使用 xdg-open 命令
        await Process.run('xdg-open', [logDir]);
      } else {
        _showError(context, 'Opening folders is not supported on this platform');
      }
    } catch (e) {
      if (context.mounted) {
        _showError(context, 'Failed to open folder: $e');
      }
    }
  }

  String _getLogLevelLabel(BuildContext context, String level) {
    final strings = AppStrings.of(context);
    switch (level) {
      case 'debug':
        return strings?.logLevelDebug ?? 'Debug';
      case 'release':
        return strings?.logLevelRelease ?? 'Release';
      case 'off':
        return strings?.logLevelOff ?? 'Off';
      default:
        return level;
    }
  }

  String _getLogLevelDescription(BuildContext context, String level) {
    final strings = AppStrings.of(context);
    switch (level) {
      case 'debug':
        return strings?.logLevelDebugDesc ?? 'Log everything for development and debugging';
      case 'release':
        return strings?.logLevelReleaseDesc ?? 'Only log warnings and errors (recommended)';
      case 'off':
        return strings?.logLevelOffDesc ?? 'Do not log anything';
      default:
        return '';
    }
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
          backgroundColor: AppTheme.getSurfaceColor(context),
          title: Text(
            strings?.defaultScreenPosition ?? 'Default Screen Position',
            style: TextStyle(color: AppTheme.getTextPrimary(context)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                strings?.screenPositionDesc ?? 'Choose which screen position to use by default when clicking a channel:',
                style: TextStyle(color: AppTheme.getTextSecondary(context), fontSize: 12),
              ),
              const SizedBox(height: 16),
              // 显示2x2网格示意图
              Container(
                width: 120,
                height: 90,
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.getTextMuted(context)),
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
                                border: Border.all(color: AppTheme.getTextMuted(context).withOpacity(0.3)),
                                color: settings.defaultScreenPosition == 1 ? AppTheme.getPrimaryColor(context).withOpacity(0.3) : null,
                              ),
                              child: Center(child: Text('1', style: TextStyle(color: AppTheme.getTextPrimary(context), fontSize: 12))),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: AppTheme.getTextMuted(context).withOpacity(0.3)),
                                color: settings.defaultScreenPosition == 2 ? AppTheme.getPrimaryColor(context).withOpacity(0.3) : null,
                              ),
                              child: Center(child: Text('2', style: TextStyle(color: AppTheme.getTextPrimary(context), fontSize: 12))),
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
                                border: Border.all(color: AppTheme.getTextMuted(context).withOpacity(0.3)),
                                color: settings.defaultScreenPosition == 3 ? AppTheme.getPrimaryColor(context).withOpacity(0.3) : null,
                              ),
                              child: Center(child: Text('3', style: TextStyle(color: AppTheme.getTextPrimary(context), fontSize: 12))),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: AppTheme.getTextMuted(context).withOpacity(0.3)),
                                color: settings.defaultScreenPosition == 4 ? AppTheme.getPrimaryColor(context).withOpacity(0.3) : null,
                              ),
                              child: Center(child: Text('4', style: TextStyle(color: AppTheme.getTextPrimary(context), fontSize: 12))),
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
                    style: TextStyle(color: AppTheme.getTextPrimary(context)),
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
                  activeColor: AppTheme.getPrimaryColor(dialogContext),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  String _getFontFamilyLabel(BuildContext context, String fontFamily, SettingsProvider settings) {
    // 获取当前语言代码，如果设置为跟随系统则使用系统语言
    final languageCode = settings.locale?.languageCode ?? WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final isChinese = languageCode.startsWith('zh');
    
    switch (fontFamily) {
      case 'System':
        return isChinese ? '系统字体' : 'System Font';
      case 'Source Han Sans SC Normal':
        return isChinese ? '思源黑体 常规' : 'Source Han Sans SC Normal';
      case 'Source Han Sans SC Bold':
        return isChinese ? '思源黑体 粗体' : 'Source Han Sans SC Bold';
      default:
        // 如果是旧字体，显示为"思源黑体 粗体"
        if (AppTheme.fontMigrationMap.containsKey(fontFamily)) {
          return isChinese ? '思源黑体 粗体' : 'Source Han Sans SC Bold';
        }
        return fontFamily;
    }
  }

  void _showFontFamilyDialog(BuildContext context, SettingsProvider settings) {
    final style = _getDialogStyle(context);
    final languageCode = settings.locale?.languageCode ?? WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final fonts = AppTheme.getAvailableFonts(languageCode);
    final strings = AppStrings.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.getSurfaceColor(context),
          shape: style['shape'],
          contentPadding: style['contentPadding'],
          titlePadding: style['titlePadding'],
          title: Text(
            strings?.fontFamily ?? '字体',
            style: TextStyle(
              color: AppTheme.getTextPrimary(context),
              fontSize: style['titleFontSize'],
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: fonts.length,
              itemBuilder: (context, index) {
                final font = fonts[index];
                final resolvedFont = AppTheme.resolveFontFamily(font);
                return RadioListTile<String>(
                  title: Text(
                    _getFontFamilyLabel(context, font, settings),
                    style: TextStyle(
                      color: AppTheme.getTextPrimary(context),
                      fontFamily: resolvedFont,
                      fontSize: style['itemFontSize'],
                    ),
                  ),
                  value: font,
                  groupValue: settings.fontFamily,
                  onChanged: (value) {
                    if (value != null) {
                      settings.setFontFamily(value);
                      Navigator.pop(dialogContext);
                      final fontLabel = _getFontFamilyLabel(context, value, settings);
                      final message = (strings?.fontChanged ?? '字体已更改为 {font}').replaceAll('{font}', fontLabel);
                      _showSuccess(context, message);
                    }
                  },
                  activeColor: AppTheme.getPrimaryColor(dialogContext),
                  contentPadding: style['itemPadding'],
                  visualDensity: style['visualDensity'],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: style['isLandscape'] ? 12.0 : 16.0,
                  vertical: style['isLandscape'] ? 6.0 : 8.0,
                ),
              ),
              child: Text(
                AppStrings.of(context)?.cancel ?? 'Cancel',
                style: TextStyle(fontSize: style['itemFontSize']),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 获取屏幕方向标签
  String _getOrientationLabel(BuildContext context, String orientation) {
    switch (orientation) {
      case 'portrait':
        return '竖屏';
      case 'landscape':
        return '横屏';
      case 'auto':
      default:
        return '自动旋转';
    }
  }

  /// 显示屏幕方向选择对话框
  void _showOrientationDialog(BuildContext context, SettingsProvider settings) {
    final style = _getDialogStyle(context);
    final options = ['portrait', 'landscape', 'auto'];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.getSurfaceColor(context),
          shape: style['shape'],
          contentPadding: style['contentPadding'],
          titlePadding: style['titlePadding'],
          title: Text(
            '屏幕方向',
            style: TextStyle(
              color: AppTheme.getTextPrimary(context),
              fontSize: style['titleFontSize'],
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: options.map((orientation) {
                IconData icon;
                switch (orientation) {
                  case 'landscape':
                    icon = Icons.screen_rotation_rounded;
                    break;
                  case 'portrait':
                    icon = Icons.stay_current_portrait_rounded;
                    break;
                  case 'auto':
                  default:
                    icon = Icons.screen_rotation_alt_rounded;
                    break;
                }
                
                return RadioListTile<String>(
                  title: Row(
                    children: [
                      Icon(
                        icon,
                        color: AppTheme.getTextPrimary(context),
                        size: style['isLandscape'] ? 16.0 : 20.0,
                      ),
                      SizedBox(width: style['isLandscape'] ? 8.0 : 12.0),
                      Text(
                        _getOrientationLabel(context, orientation),
                        style: TextStyle(
                          color: AppTheme.getTextPrimary(context),
                          fontSize: style['itemFontSize'],
                        ),
                      ),
                    ],
                  ),
                  value: orientation,
                  groupValue: settings.mobileOrientation,
                  onChanged: (value) async {
                    if (value != null) {
                      await settings.setMobileOrientation(value);
                      
                      // 应用屏幕方向
                      List<DeviceOrientation> orientations;
                      switch (value) {
                        case 'landscape':
                          orientations = [
                            DeviceOrientation.landscapeLeft,
                            DeviceOrientation.landscapeRight,
                          ];
                          break;
                        case 'portrait':
                          orientations = [
                            DeviceOrientation.portraitUp,
                          ];
                        break;
                      case 'auto':
                      default:
                        orientations = [
                          DeviceOrientation.portraitUp,
                          DeviceOrientation.landscapeLeft,
                          DeviceOrientation.landscapeRight,
                        ];
                        break;
                    }
                    
                    await SystemChrome.setPreferredOrientations(orientations);
                    
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                      _showSuccess(context, '屏幕方向已设置为: ${_getOrientationLabel(context, value)}');
                    }
                  }
                },
                activeColor: AppTheme.getPrimaryColor(dialogContext),
                contentPadding: style['itemPadding'],
                visualDensity: style['visualDensity'],
              );
            }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: style['isLandscape'] ? 12.0 : 16.0,
                  vertical: style['isLandscape'] ? 6.0 : 8.0,
                ),
              ),
              child: Text(
                AppStrings.of(context)?.cancel ?? 'Cancel',
                style: TextStyle(fontSize: style['itemFontSize']),
              ),
            ),
          ],
        );
      },
    );
  }
}




