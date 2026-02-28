import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';
import 'core/i18n/app_strings.dart';

import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'core/theme/app_theme.dart';
import 'core/navigation/app_router.dart';
import 'core/services/service_locator.dart';
import 'core/services/auto_refresh_service.dart';
import 'core/services/disclaimer_service.dart';
import 'core/services/native_log_channel.dart';
import 'core/platform/native_player_channel.dart';
import 'core/platform/platform_detector.dart';
import 'core/widgets/channel_logo_widget.dart';
import 'core/screens/disclaimer_screen.dart';
import 'core/screens/loading_screen.dart';
import 'features/channels/providers/channel_provider.dart';
import 'features/player/providers/player_provider.dart';
import 'features/playlist/providers/playlist_provider.dart';
import 'features/favorites/providers/favorites_provider.dart';
import 'features/settings/providers/settings_provider.dart';
import 'features/settings/providers/dlna_provider.dart';
import 'features/epg/providers/epg_provider.dart';
import 'features/multi_screen/providers/multi_screen_provider.dart';
import 'features/backup/providers/backup_provider.dart';
import 'core/widgets/window_title_bar.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize critical services FIRST (before any logging)
    await ServiceLocator.initPrefs();

    // Now we can set up error handlers that use logging
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      // Use debugPrint as fallback if log service fails
      try {
        if (ServiceLocator.isLogInitialized) {
          ServiceLocator.log.e('Flutter Error: ${details.exception}');
          ServiceLocator.log.e('Stack trace: ${details.stack}');
        } else {
          debugPrint('Flutter Error: ${details.exception}');
          debugPrint('Stack trace: ${details.stack}');
        }
      } catch (e) {
        debugPrint('Flutter Error: ${details.exception}');
        debugPrint('Stack trace: ${details.stack}');
      }
    };

    // Initialize MediaKit
    MediaKit.ensureInitialized();

    // Initialize native player channel for Android TV
    NativePlayerChannel.init();
    
    // Initialize native log channel for Android TV only
    if (Platform.isAndroid) {
      await NativeLogChannel.init();
    }

    // Initialize Windows/Linux/macOS Database Engine
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    // Initialize window manager for Windows
    if (Platform.isWindows) {
      await windowManager.ensureInitialized();

      WindowOptions windowOptions = const WindowOptions(
        size: Size(1280, 720),
        minimumSize: Size(360, 600),
        center: true,
        backgroundColor: Colors.black,
        titleBarStyle: TitleBarStyle.hidden,
        windowButtonVisibility: false,
      );

      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    }

    // Initialize PlatformDetector for settings page
    await PlatformDetector.init();
    
    // ✅ 初始化台标加载的HTTP连接池
    initializeLogoConnectionPool();

    // 初始屏幕方向将在 MaterialApp 构建后根据设置应用
    // 这里先允许所有方向，避免启动时的限制
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Set system UI overlay style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    runApp(const FlutterIPTVApp());
  } catch (e, stackTrace) {
    // Use debugPrint as fallback if log service is not initialized
    debugPrint('Fatal error during app initialization: $e');
    debugPrint('Stack trace: $stackTrace');

    // Show an error dialog for Windows
    runApp(MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Application Failed to Start',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  'Error: $e',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SelectableText(
                  stackTrace.toString(),
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ),
    ));
  }
}

class FlutterIPTVApp extends StatefulWidget {
  const FlutterIPTVApp({super.key});

  @override
  State<FlutterIPTVApp> createState() => _FlutterIPTVAppState();
}

class _FlutterIPTVAppState extends State<FlutterIPTVApp> {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => PlaylistProvider()),
        ChangeNotifierProvider(create: (_) => ChannelProvider()),
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => EpgProvider()),
        ChangeNotifierProvider(create: (_) => DlnaProvider()),
        ChangeNotifierProvider(create: (_) => MultiScreenProvider()),
        ChangeNotifierProvider(create: (_) => BackupProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return _DlnaAwareApp(settings: settings);
        },
      ),
    );
  }
}

/// 包装 MaterialApp，监听 DLNA 播放请求和管理自动刷新服务
class _DlnaAwareApp extends StatefulWidget {
  final SettingsProvider settings;

  const _DlnaAwareApp({required this.settings});

  @override
  State<_DlnaAwareApp> createState() => _DlnaAwareAppState();
}

class _DlnaAwareAppState extends State<_DlnaAwareApp> with WindowListener {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  String? _currentDlnaUrl; // 记录当前 DLNA 播放的 URL

  // 自动刷新服务
  final AutoRefreshService _autoRefreshService = AutoRefreshService();
  bool _lastAutoRefreshState = false;
  int _lastRefreshInterval = 24;
  
  // 免责声明状态
  bool _disclaimerAccepted = false;
  bool _disclaimerChecking = true;

  @override
  void initState() {
    super.initState();
    ServiceLocator.log.d('_DlnaAwareApp.initState() 被调用', tag: 'AutoRefresh');

    // 检查免责声明状态
    _checkDisclaimerStatus();

    // Windows 窗口关闭监听
    if (Platform.isWindows) {
      windowManager.addListener(this);
    }
    // 立即触发 DlnaProvider 的创建（会自动启动 DLNA 服务）
    // 使用 addPostFrameCallback 确保 context 可用
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ServiceLocator.log.d('addPostFrameCallback 触发', tag: 'DLNA');
      _setupDlnaCallbacks();
      // 初始化自动刷新服务
      ServiceLocator.log.d('addPostFrameCallback 执行', tag: 'AutoRefresh');
      _initAutoRefresh();
      // 应用屏幕方向设置
      _applyOrientationSettings();
    });
  }

  /// 检查免责声明状态
  Future<void> _checkDisclaimerStatus() async {
    ServiceLocator.log.d('开始检查免责声明状态', tag: 'Disclaimer');
    try {
      final hasAccepted = await DisclaimerService().hasAccepted();
      ServiceLocator.log.d('免责声明状态: $hasAccepted', tag: 'Disclaimer');
      
      if (mounted) {
        setState(() {
          _disclaimerAccepted = hasAccepted;
          _disclaimerChecking = false;
        });
        ServiceLocator.log.d('状态已更新: accepted=$_disclaimerAccepted, checking=$_disclaimerChecking', tag: 'Disclaimer');
      }
    } catch (e, stackTrace) {
      ServiceLocator.log.e('检查免责声明状态失败: $e', tag: 'Disclaimer');
      ServiceLocator.log.e('堆栈: $stackTrace', tag: 'Disclaimer');
      if (mounted) {
        setState(() {
          _disclaimerChecking = false;
        });
      }
    }
  }

  /// 处理免责声明同意
  void _handleDisclaimerAccepted() {
    ServiceLocator.log.d('收到免责声明同意回调', tag: 'Disclaimer');
    if (mounted) {
      setState(() {
        _disclaimerAccepted = true;
      });
      ServiceLocator.log.d('状态已更新为已同意，将显示正常应用', tag: 'Disclaimer');
    }
  }

  /// 应用屏幕方向设置
  Future<void> _applyOrientationSettings() async {
    if (!PlatformDetector.isMobile) return;

    final settings = context.read<SettingsProvider>();
    final orientation = settings.mobileOrientation;

    List<DeviceOrientation> orientations;
    switch (orientation) {
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
    ServiceLocator.log.d('应用屏幕方向设置: $orientation', tag: 'Orientation');
  }

  @override
  void dispose() {
    if (Platform.isWindows) {
      windowManager.removeListener(this);
    }
    _autoRefreshService.stop();
    super.dispose();
  }

  Future<void> _initAutoRefresh() async {
    ServiceLocator.log.d('_initAutoRefresh() 开始执行', tag: 'AutoRefresh');

    if (!mounted) {
      ServiceLocator.log.d('Widget 未挂载，退出初始化', tag: 'AutoRefresh');
      return;
    }

    try {
      // 加载上次刷新时间
      await _autoRefreshService.loadLastRefreshTime();

      // 获取设置
      final settings = context.read<SettingsProvider>();
      _lastAutoRefreshState = settings.autoRefresh;
      _lastRefreshInterval = settings.refreshInterval;

      ServiceLocator.log.d(
          '读取设置 - autoRefresh=${settings.autoRefresh}, interval=${settings.refreshInterval}',
          tag: 'AutoRefresh');

      if (settings.autoRefresh) {
        ServiceLocator.log
            .d('启用自动刷新，间隔: ${settings.refreshInterval}小时', tag: 'AutoRefresh');
        _startAutoRefresh(settings);
      } else {
        ServiceLocator.log.d('自动刷新已禁用', tag: 'AutoRefresh');
      }

      // 监听设置变化
      settings.addListener(() {
        if (!mounted) return;

        // 只在 autoRefresh 状态或间隔变化时才处理
        final currentAutoRefresh = settings.autoRefresh;
        final currentInterval = settings.refreshInterval;

        if (currentAutoRefresh != _lastAutoRefreshState ||
            (currentAutoRefresh && currentInterval != _lastRefreshInterval)) {
          _lastAutoRefreshState = currentAutoRefresh;
          _lastRefreshInterval = currentInterval;

          if (currentAutoRefresh) {
            ServiceLocator.log
                .d('设置已更改，重新启动服务 - 间隔: $currentInterval小时', tag: 'AutoRefresh');
            _startAutoRefresh(settings);
          } else {
            ServiceLocator.log.d('自动刷新已禁用', tag: 'AutoRefresh');
            _autoRefreshService.stop();
          }
        }
      });

      ServiceLocator.log.d('_initAutoRefresh() 完成', tag: 'AutoRefresh');
    } catch (e, stackTrace) {
      ServiceLocator.log.d('初始化失败 - $e', tag: 'AutoRefresh');
      ServiceLocator.log.d('堆栈跟踪 - $stackTrace', tag: 'AutoRefresh');
    }
  }

  void _startAutoRefresh(SettingsProvider settings) {
    _autoRefreshService.start(
      intervalHours: settings.refreshInterval,
      onRefresh: () => _performAutoRefresh(),
    );
  }

  Future<void> _performAutoRefresh() async {
    if (!mounted) return;

    ServiceLocator.log.d('开始执行自动刷新', tag: 'AutoRefresh');

    try {
      final playlistProvider = context.read<PlaylistProvider>();
      final settings = context.read<SettingsProvider>();
      final playlists = playlistProvider.playlists;

      if (playlists.isEmpty) {
        ServiceLocator.log.d('没有播放列表需要刷新', tag: 'AutoRefresh');
        return;
      }

      int successCount = 0;
      int failCount = 0;

      String? lastError;

      // 刷新所有播放列表（即使某个失败也继续刷新其他的）
      for (final playlist in playlists) {
        if (playlist.id != null) {
          try {
            ServiceLocator.log
                .d('刷新播放列表: ${playlist.name}', tag: 'AutoRefresh');
            final success = await playlistProvider.refreshPlaylist(playlist, mergeRule: settings.channelMergeRule);
            if (success) {
              successCount++;
            } else {
              failCount++;
              lastError = playlistProvider.error; // Get the error from provider
              ServiceLocator.log
                  .d('播放列表刷新失败: ${playlist.name}', tag: 'AutoRefresh');
            }
          } catch (e) {
            failCount++;
            lastError = e.toString();
            ServiceLocator.log
                .d('播放列表刷新异常: ${playlist.name} - $e', tag: 'AutoRefresh');
          }
        }
      }

      // 重新加载当前激活播放列表的频道
      if (playlistProvider.activePlaylist?.id != null) {
        try {
          final channelProvider = context.read<ChannelProvider>();
          await channelProvider
              .loadChannels(playlistProvider.activePlaylist!.id!);
        } catch (e) {
          ServiceLocator.log.d('重新加载频道失败: $e', tag: 'AutoRefresh');
        }
      }

      ServiceLocator.log
          .d('自动刷新完成 - 成功: $successCount, 失败: $failCount', tag: 'AutoRefresh');

      // 如果有失败的，记录但不影响下次刷新时间
      if (failCount > 0) {
        ServiceLocator.log.d('部分播放列表刷新失败，将在下次定时刷新时重试', tag: 'AutoRefresh');

        // Show error to user if mounted
        if (mounted) {
          String message = AppStrings.of(context)?.playlistRefreshFailed ??
              'Playlist refresh failed';
          if (lastError != null) {
            // Clean up error message
            String displayError = lastError.replaceAll('Exception:', '').trim();
            message = '$message: $displayError';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: AppStrings.of(context)?.close ?? 'Close',
                textColor: Colors.white,
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      ServiceLocator.log.d('自动刷新过程发生严重错误: $e', tag: 'AutoRefresh');
      // 即使出错，也不影响下次刷新（计时器已经重置）
    }
  }

  @override
  void onWindowClose() async {
    // 窗口关闭时停止 DLNA 服务
    try {
      final dlnaProvider = context.read<DlnaProvider>();
      await dlnaProvider.setEnabled(false);
      ServiceLocator.log.d('窗口关闭，服务已停止', tag: 'DLNA');
    } catch (e) {
      // 忽略错误
    }
    await windowManager.destroy();
  }

  void _setupDlnaCallbacks() {
    final dlnaProvider = context.read<DlnaProvider>();
    dlnaProvider.onPlayRequested = _handleDlnaPlay;
    dlnaProvider.onPauseRequested = _handleDlnaPause;
    dlnaProvider.onStopRequested = _handleDlnaStop;
    dlnaProvider.onSeekRequested = _handleDlnaSeek;
    dlnaProvider.onVolumeRequested = _handleDlnaVolume;
    ServiceLocator.log.d('Provider 已初始化，回调已设置', tag: 'DLNA');
  }

  void _handleDlnaPlay(String url, String? title) async {
    // 如果已经在播放相同的 URL，不重复导航
    if (_currentDlnaUrl == url) {
      return;
    }

    // 停止当前播放（包括分屏模式）
    try {
      final playerProvider = context.read<PlayerProvider>();
      playerProvider.stop();

      // 停止分屏播放（等待完成）
      final multiScreenProvider = context.read<MultiScreenProvider>();
      await multiScreenProvider.clearAllScreens();
    } catch (e) {
      ServiceLocator.log.d('停止当前播放失败 - $e', tag: 'DLNA');
    }

    // 先返回到首页，再导航到播放器
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);

    _currentDlnaUrl = url;
    ServiceLocator.log.d('播放 - ${title ?? url}', tag: 'DLNA');
    _navigatorKey.currentState?.pushNamed(
      AppRouter.player,
      arguments: {
        'channelUrl': url,
        'channelName': title ?? 'DLNA 投屏',
        'channelLogo': null,
      },
    );
  }

  void _handleDlnaPause() {
    try {
      // Android TV 使用原生播放器
      if (PlatformDetector.isTV && PlatformDetector.isAndroid) {
        NativePlayerChannel.pause();
      } else {
        final playerProvider = context.read<PlayerProvider>();
        playerProvider.pause();
      }
    } catch (e) {
      // 忽略错误
    }
  }

  void _handleDlnaStop() {
    _currentDlnaUrl = null;
    try {
      // Android TV 使用原生播放器
      if (PlatformDetector.isTV && PlatformDetector.isAndroid) {
        // closePlayer 会触发 onClosed 回调，回调中会处理导航
        NativePlayerChannel.closePlayer();
        // 不需要额外的 popUntil，onClosed 回调会处理
      } else {
        final playerProvider = context.read<PlayerProvider>();
        playerProvider.stop();
        _navigatorKey.currentState?.popUntil((route) => route.isFirst);
      }
    } catch (e) {
      // 忽略错误
    }
  }

  void _handleDlnaSeek(Duration position) {
    try {
      // Android TV 使用原生播放器
      if (PlatformDetector.isTV && PlatformDetector.isAndroid) {
        NativePlayerChannel.seekTo(position.inMilliseconds);
      } else {
        final playerProvider = context.read<PlayerProvider>();
        playerProvider.seek(position);
      }
    } catch (e) {
      // 忽略错误
    }
  }

  void _handleDlnaVolume(int volume) {
    try {
      // Android TV 使用原生播放器
      if (PlatformDetector.isTV && PlatformDetector.isAndroid) {
        NativePlayerChannel.setVolume(volume);
      } else {
        final playerProvider = context.read<PlayerProvider>();
        playerProvider.setVolume(volume / 100.0);
      }
    } catch (e) {
      // 忽略错误
    }
  }

  @override
  Widget build(BuildContext context) {
    ServiceLocator.log.d('_DlnaAwareAppState.build() - checking=$_disclaimerChecking, accepted=$_disclaimerAccepted', tag: 'Disclaimer');
    
    // 加载中
    if (_disclaimerChecking) {
      ServiceLocator.log.d('显示加载页面', tag: 'Disclaimer');
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: LoadingScreen(),
      );
    }

    // 未同意免责声明，显示免责声明页面
    if (!_disclaimerAccepted) {
      ServiceLocator.log.d('显示免责声明页面', tag: 'Disclaimer');
      
      // 从 SharedPreferences 读取用户设置的语言
      final prefs = ServiceLocator.prefs;
      final localeCode = prefs.getString('locale'); // 使用正确的键名
      ServiceLocator.log.d('从 SharedPreferences 读取语言 (locale): $localeCode', tag: 'Disclaimer');
      
      Locale? locale;
      if (localeCode != null && localeCode.isNotEmpty) {
        // 解析 locale 格式（可能是 "zh" 或 "zh_CN"）
        final parts = localeCode.split('_');
        locale = Locale(parts[0], parts.length > 1 ? parts[1] : '');
        ServiceLocator.log.d('使用用户设置的语言: ${locale.languageCode}_${locale.countryCode}', tag: 'Disclaimer');
      } else {
        // 如果用户没有设置，从系统获取语言
        try {
          final systemLocales = WidgetsBinding.instance.platformDispatcher.locales;
          ServiceLocator.log.d('系统语言列表: $systemLocales', tag: 'Disclaimer');
          if (systemLocales.isNotEmpty) {
            // 查找支持的语言（中文或英文）
            locale = systemLocales.firstWhere(
              (l) => l.languageCode == 'zh' || l.languageCode == 'en',
              orElse: () => systemLocales.first,
            );
            ServiceLocator.log.d('使用系统语言: ${locale.languageCode}', tag: 'Disclaimer');
          }
        } catch (e) {
          ServiceLocator.log.e('获取系统语言失败: $e', tag: 'Disclaimer');
        }
        
        if (locale == null) {
          ServiceLocator.log.d('未找到系统语言，使用默认中文', tag: 'Disclaimer');
          locale = const Locale('zh', ''); // 默认使用中文
        }
      }
      
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppThemeDynamic.getLightTheme('ocean', 'Microsoft YaHei'),
        darkTheme: AppThemeDynamic.getDarkTheme('ocean', 'Microsoft YaHei'),
        themeMode: ThemeMode.system,
        locale: locale, // 使用用户设置的语言或系统语言
        supportedLocales: const [
          Locale('en', ''),
          Locale('zh', ''),
        ],
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: DisclaimerScreen(
          onAccepted: _handleDisclaimerAccepted,
        ),
      );
    }

    // 已同意，显示正常应用
    ServiceLocator.log.d('免责声明已同意，显示正常应用', tag: 'Disclaimer');
    return _buildNormalApp(context);
  }

  /// 构建正常的应用（已同意免责声明后）
  Widget _buildNormalApp(BuildContext context) {
    // 监听 settings 变化，确保主题能够更新
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        ServiceLocator.log.d(
            '${settings.darkColorScheme}, 明亮配色: ${settings.lightColorScheme}, 主题模式: ${settings.themeMode}, 字体: ${settings.fontFamily}',
            tag: 'MaterialApp 重建 - 黑暗配色');
        final fontFamily = AppTheme.resolveFontFamily(settings.fontFamily);
        return MaterialApp(
          navigatorKey: _navigatorKey,
          navigatorObservers: [AppRouter.routeObserver], // 添加路由监听
          title: AppStrings.of(context)?.lotusIptv ?? 'Lotus IPTV',
          debugShowCheckedModeBanner: false,
          theme: AppThemeDynamic.getLightTheme(
              settings.lightColorScheme, fontFamily),
          darkTheme: AppThemeDynamic.getDarkTheme(
              settings.darkColorScheme, fontFamily),
          themeMode: settings.themeMode == 'light'
              ? ThemeMode.light
              : settings.themeMode == 'system'
                  ? ThemeMode.system
                  : ThemeMode.dark,
          locale: settings.locale,
          supportedLocales: const [
            Locale('en', ''),
            Locale('zh', ''),
          ],
          localizationsDelegates: const [
            AppStrings.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // Use shortcuts for TV remote support
          shortcuts: <ShortcutActivator, Intent>{
            ...WidgetsApp.defaultShortcuts,
            const SingleActivator(LogicalKeyboardKey.select):
                const ActivateIntent(),
            const SingleActivator(LogicalKeyboardKey.enter):
                const ActivateIntent(),
          },
          onGenerateRoute: AppRouter.generateRoute,
          initialRoute: AppRouter.splash,
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.0),
              ),
              child: Platform.isWindows
                  ? Stack(
                      children: [
                        child!,
                        const WindowTitleBar(),
                      ],
                    )
                  : child!,
            );
          },
        );
      },
    );
  }
}
