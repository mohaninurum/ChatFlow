import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/dashboard/presentation/screens/home_screen.dart';
import '../../features/dashboard/presentation/screens/main_navigation_shell.dart';
import '../../features/dashboard/presentation/screens/tools_screen.dart';
import '../../features/direct_chat/presentation/screens/direct_chat_screen.dart';
import '../../features/status_saver/presentation/screens/status_saver_screen.dart';
import '../../features/message_hub/presentation/screens/message_hub_screen.dart';
import '../../features/deleted_messages/presentation/screens/deleted_messages_screen.dart';
import '../../features/chat_utilities/presentation/screens/chat_utilities_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/link_generator/presentation/screens/link_generator_screen.dart';
import '../../features/reminders/presentation/screens/reminders_screen.dart';
import '../../features/text_formatter/presentation/screens/text_formatter_screen.dart';
import '../../features/clipboard_manager/presentation/screens/clipboard_manager_screen.dart';
import '../../features/ocr/presentation/screens/ocr_screen.dart';
import '../../features/private_vault/presentation/screens/private_vault_screen.dart';
import '../../features/ai_assistant/presentation/screens/ai_assistant_screen.dart';
import '../../features/ai_assistant/presentation/screens/ai_translator_screen.dart';

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
        builder: (context, state) => const DirectChatScreen(),
      ),
      GoRoute(
        path: '/status-saver',
        name: 'statusSaver',
        builder: (context, state) => const StatusSaverScreen(),
      ),
      GoRoute(
        path: '/message-hub',
        name: 'messageHub',
        builder: (context, state) => const MessageHubScreen(),
      ),
      GoRoute(
        path: '/deleted-messages',
        name: 'deletedMessages',
        builder: (context, state) => const DeletedMessagesScreen(),
      ),
      GoRoute(
        path: '/chat-utilities',
        name: 'chatUtilities',
        builder: (context, state) => const ChatUtilitiesScreen(),
      ),
      GoRoute(
        path: '/link-generator',
        name: 'linkGenerator',
        builder: (context, state) => const LinkGeneratorScreen(),
      ),
      GoRoute(
        path: '/reminders',
        name: 'reminders',
        builder: (context, state) => const RemindersScreen(),
      ),
      GoRoute(
        path: '/text-formatter',
        name: 'textFormatter',
        builder: (context, state) => const TextFormatterScreen(),
      ),
      GoRoute(
        path: '/clipboard-manager',
        name: 'clipboardManager',
        builder: (context, state) => const ClipboardManagerScreen(),
      ),
      GoRoute(
        path: '/ocr',
        name: 'ocr',
        builder: (context, state) => const OcrScreen(),
      ),
      GoRoute(
        path: '/private-vault',
        name: 'privateVault',
        builder: (context, state) => const PrivateVaultScreen(),
      ),
      GoRoute(
        path: '/ai-assistant',
        name: 'aiAssistant',
        builder: (context, state) => const AiAssistantScreen(),
      ),
      GoRoute(
        path: '/ai-translator',
        name: 'aiTranslator',
        builder: (context, state) => const AiTranslatorScreen(),
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
