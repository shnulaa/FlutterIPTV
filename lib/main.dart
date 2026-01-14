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
import 'core/platform/native_player_channel.dart';
import 'core/platform/platform_detector.dart';
import 'features/channels/providers/channel_provider.dart';
import 'features/player/providers/player_provider.dart';
import 'features/playlist/providers/playlist_provider.dart';
import 'features/favorites/providers/favorites_provider.dart';
import 'features/settings/providers/settings_provider.dart';
import 'features/settings/providers/dlna_provider.dart';
import 'features/epg/providers/epg_provider.dart';
import 'features/multi_screen/providers/multi_screen_provider.dart';
import 'core/widgets/window_title_bar.dart';

void main() async {
  // Catch all Flutter errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Error: ${details.exception}');
    debugPrint('Stack trace: ${details.stack}');
  };

  try {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize MediaKit
    MediaKit.ensureInitialized();

    // Initialize native player channel for Android TV
    NativePlayerChannel.init();

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
        minimumSize: Size(800, 600),
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

    // Initialize critical services (Prefs) immediately for SettingsProvider
    // Database will be initialized in SplashScreen
    await ServiceLocator.initPrefs();
    
    // Initialize PlatformDetector for settings page
    await PlatformDetector.init();

    // Set preferred orientations for mobile
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
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
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

class FlutterIPTVApp extends StatelessWidget {
  const FlutterIPTVApp({super.key});

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
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return _DlnaAwareApp(settings: settings);
        },
      ),
    );
  }
}

/// 包装 MaterialApp，监听 DLNA 播放请求
class _DlnaAwareApp extends StatefulWidget {
  final SettingsProvider settings;
  
  const _DlnaAwareApp({required this.settings});

  @override
  State<_DlnaAwareApp> createState() => _DlnaAwareAppState();
}

class _DlnaAwareAppState extends State<_DlnaAwareApp> with WindowListener {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  String? _currentDlnaUrl; // 记录当前 DLNA 播放的 URL

  @override
  void initState() {
    super.initState();
    // Windows 窗口关闭监听
    if (Platform.isWindows) {
      windowManager.addListener(this);
    }
    // 立即触发 DlnaProvider 的创建（会自动启动 DLNA 服务）
    // 使用 addPostFrameCallback 确保 context 可用
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('DLNA: addPostFrameCallback 触发');
      _setupDlnaCallbacks();
    });
  }
  
  @override
  void dispose() {
    if (Platform.isWindows) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }
  
  @override
  void onWindowClose() async {
    // 窗口关闭时停止 DLNA 服务
    try {
      final dlnaProvider = context.read<DlnaProvider>();
      await dlnaProvider.setEnabled(false);
      debugPrint('DLNA: 窗口关闭，服务已停止');
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
    debugPrint('DLNA: Provider 已初始化，回调已设置');
  }
  
  void _handleDlnaPlay(String url, String? title) {
    // 如果已经在播放相同的 URL，不重复导航
    if (_currentDlnaUrl == url) {
      return;
    }
    
    // 停止当前播放（包括分屏模式）
    try {
      final playerProvider = context.read<PlayerProvider>();
      playerProvider.stop();
      
      // 停止分屏播放
      final multiScreenProvider = context.read<MultiScreenProvider>();
      multiScreenProvider.clearAllScreens();
    } catch (e) {
      debugPrint('DLNA: 停止当前播放失败 - $e');
    }
    
    // 先返回到首页，再导航到播放器
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    
    _currentDlnaUrl = url;
    debugPrint('DLNA: 播放 - ${title ?? url}');
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
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: AppStrings.of(context)?.lotusIptv ?? 'Lotus IPTV',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: widget.settings.themeMode == 'light'
          ? ThemeMode.light
          : widget.settings.themeMode == 'system'
              ? ThemeMode.system
              : ThemeMode.dark,
      locale: widget.settings.locale,
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
        const SingleActivator(LogicalKeyboardKey.select): const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.enter): const ActivateIntent(),
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
  }
}
