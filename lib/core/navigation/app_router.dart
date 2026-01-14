import 'package:flutter/material.dart';

import '../../features/splash/screens/splash_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/player/screens/player_screen.dart';
import '../../features/channels/screens/channels_screen.dart';
import '../../features/playlist/screens/playlist_manager_screen.dart';
import '../../features/favorites/screens/favorites_screen.dart';
import '../../features/search/screens/search_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/epg/screens/epg_screen.dart';

class AppRouter {
  // Route names
  static const String splash = '/';
  static const String home = '/home';
  static const String player = '/player';
  static const String channels = '/channels';
  static const String playlistManager = '/playlist-manager';
  static const String favorites = '/favorites';
  static const String search = '/search';
  static const String settings = '/settings';
  static const String epg = '/epg';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return _buildRoute(const SplashScreen(), settings);

      case home:
        return _buildRoute(const HomeScreen(), settings);

      case player:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(
          PlayerScreen(
            channelUrl: args?['channelUrl'] ?? '',
            channelName: args?['channelName'] ?? 'Unknown',
            channelLogo: args?['channelLogo'],
            isMultiScreen: args?['isMultiScreen'] ?? false,
          ),
          settings,
        );

      case channels:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(
          ChannelsScreen(
            groupName: args?['groupName'],
          ),
          settings,
        );

      case playlistManager:
        return _buildRoute(const PlaylistManagerScreen(), settings);

      case favorites:
        return _buildRoute(const FavoritesScreen(), settings);

      case search:
        return _buildRoute(const SearchScreen(), settings);

      case AppRouter.settings:
        return _buildRoute(const SettingsScreen(), settings);

      case epg:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(
          EpgScreen(
            channelId: args?['channelId'],
          ),
          settings,
        );

      default:
        return _buildRoute(
          Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
          settings,
        );
    }
  }

  static PageRouteBuilder _buildRoute(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;

        var tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );

        return SlideTransition(
          position: animation.drive(tween),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}
