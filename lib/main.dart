import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
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
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: AppStrings.of(context)?.lotusIptv ?? 'Lotus IPTV',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.dark,
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
                child: child!,
              );
            },
          );
        },
      ),
    );
  }
}
