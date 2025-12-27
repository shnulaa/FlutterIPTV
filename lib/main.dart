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
import 'features/channels/providers/channel_provider.dart';
import 'features/player/providers/player_provider.dart';
import 'features/playlist/providers/playlist_provider.dart';
import 'features/favorites/providers/favorites_provider.dart';
import 'features/settings/providers/settings_provider.dart';
import 'features/settings/providers/dlna_provider.dart';
import 'features/epg/providers/epg_provider.dart';
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

class _DlnaAwareAppState extends State<_DlnaAwareApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  String? _currentDlnaUrl; // 记录当前 DLNA 播放的 URL

  @override
  void initState() {
    super.initState();
    // 设置 DLNA 回调
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dlnaProvider = context.read<DlnaProvider>();
      dlnaProvider.onPlayRequested = _handleDlnaPlay;
      dlnaProvider.onPauseRequested = _handleDlnaPause;
      dlnaProvider.onStopRequested = _handleDlnaStop;
      dlnaProvider.onSeekRequested = _handleDlnaSeek;
      dlnaProvider.onVolumeRequested = _handleDlnaVolume;
    });
  }

  void _handleDlnaPlay(String url, String? title) {
    debugPrint('DLNA: 播放请求 - $url (当前: $_currentDlnaUrl)');
    
    // 如果已经在播放相同的 URL，不重复导航
    if (_currentDlnaUrl == url) {
      debugPrint('DLNA: 相同 URL，跳过导航');
      return;
    }
    
    // 如果已经在播放其他内容，先返回再导航
    if (_currentDlnaUrl != null) {
      _navigatorKey.currentState?.pop();
    }
    
    _currentDlnaUrl = url;
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
    debugPrint('DLNA: 暂停播放');
    try {
      final playerProvider = context.read<PlayerProvider>();
      playerProvider.pause();
    } catch (e) {
      debugPrint('DLNA: 暂停失败 - $e');
    }
  }
  
  void _handleDlnaStop() {
    debugPrint('DLNA: 停止播放（手机端断开）');
    _currentDlnaUrl = null; // 清除当前播放 URL
    try {
      final playerProvider = context.read<PlayerProvider>();
      playerProvider.stop();
      // 返回首页（可能需要 pop 多次）
      _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    } catch (e) {
      debugPrint('DLNA: 停止失败 - $e');
    }
  }
  
  void _handleDlnaSeek(Duration position) {
    debugPrint('DLNA: 跳转到 $position');
    try {
      final playerProvider = context.read<PlayerProvider>();
      playerProvider.seek(position);
    } catch (e) {
      debugPrint('DLNA: 跳转失败 - $e');
    }
  }
  
  void _handleDlnaVolume(int volume) {
    debugPrint('DLNA: 设置音量 $volume');
    try {
      final playerProvider = context.read<PlayerProvider>();
      playerProvider.setVolume(volume / 100.0);
    } catch (e) {
      debugPrint('DLNA: 设置音量失败 - $e');
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
