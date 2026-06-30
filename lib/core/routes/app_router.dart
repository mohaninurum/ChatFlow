import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/dashboard/presentation/screens/home_screen.dart';
import '../../features/direct_chat/presentation/screens/direct_chat_screen.dart';
import '../../features/status_saver/presentation/screens/status_saver_screen.dart';
import '../../features/notification_history/presentation/screens/notification_history_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/media_cleaner/presentation/screens/media_cleaner_screen.dart';
import '../../features/qr_tools/presentation/screens/qr_tools_screen.dart';
import '../../features/text_tools/presentation/screens/text_tools_screen.dart';
import '../../features/file_manager/presentation/screens/file_manager_screen.dart';
import '../../features/status_creator/presentation/screens/status_creator_screen.dart';
import '../../features/chat_utilities/presentation/screens/chat_utilities_screen.dart';
import '../../features/backup/presentation/screens/backup_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';

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
        path: '/media-cleaner',
        name: 'mediaCleaner',
        builder: (context, state) => const MediaCleanerScreen(),
      ),
      GoRoute(
        path: '/qr-tools',
        name: 'qrTools',
        builder: (context, state) => const QrToolsScreen(),
      ),
      GoRoute(
        path: '/text-tools',
        name: 'textTools',
        builder: (context, state) => const TextToolsScreen(),
      ),
      GoRoute(
        path: '/file-manager',
        name: 'fileManager',
        builder: (context, state) => const FileManagerScreen(),
      ),
      GoRoute(
        path: '/status-creator',
        name: 'statusCreator',
        builder: (context, state) => const StatusCreatorScreen(),
      ),
      GoRoute(
        path: '/chat-utilities',
        name: 'chatUtilities',
        builder: (context, state) => const ChatUtilitiesScreen(),
      ),
      GoRoute(
        path: '/backup',
        name: 'backup',
        builder: (context, state) => const BackupScreen(),
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
