import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/dashboard/presentation/screens/main_navigation_shell.dart';
import '../../features/dashboard/presentation/screens/tools_screen.dart';
import '../../features/direct_chat/presentation/screens/direct_chat_screen.dart';
import '../../features/status_saver/presentation/screens/status_saver_screen.dart';
import '../../features/link_generator/presentation/screens/link_generator_screen.dart';
import '../../features/text_formatter/presentation/screens/text_formatter_screen.dart';
import '../../features/ocr/presentation/screens/ocr_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const MainNavigationShell(),
      ),
      GoRoute(
        path: '/tools',
        name: 'tools',
        builder: (context, state) => const ToolsScreen(),
      ),
      GoRoute(
        path: '/direct-chat',
        name: 'directChat',
        builder: (context, state) {
          final extra = state.extra;
          String? initialMessage;
          if (extra is String) {
            initialMessage = extra;
          } else if (extra is Map && extra['message'] != null) {
            initialMessage = extra['message']?.toString();
          }
          return DirectChatScreen(initialMessage: initialMessage);
        },
      ),
      GoRoute(
        path: '/status-saver',
        name: 'statusSaver',
        builder: (context, state) => const StatusSaverScreen(),
      ),
      GoRoute(
        path: '/link-generator',
        name: 'linkGenerator',
        builder: (context, state) => const LinkGeneratorScreen(),
      ),
      GoRoute(
        path: '/text-formatter',
        name: 'textFormatter',
        builder: (context, state) => const TextFormatterScreen(),
      ),
      GoRoute(
        path: '/ocr',
        name: 'ocr',
        builder: (context, state) => const OcrScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
  );
});
