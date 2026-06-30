import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/dashboard/presentation/screens/home_screen.dart';
import '../../features/direct_chat/presentation/screens/direct_chat_screen.dart';
import '../../features/status_saver/presentation/screens/status_saver_screen.dart';
import '../../features/notification_history/presentation/screens/notification_history_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/direct-chat',
        name: 'directChat',
        builder: (context, state) => const DirectChatScreen(),
      ),
      GoRoute(
        path: '/status-saver',
        name: 'statusSaver',
        builder: (context, state) => const StatusSaverScreen(),
      ),
      GoRoute(
        path: '/notification-history',
        name: 'notificationHistory',
        builder: (context, state) => const NotificationHistoryScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});
