import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationHistoryScreen extends ConsumerStatefulWidget {
  const NotificationHistoryScreen({super.key});

  @override
  ConsumerState<NotificationHistoryScreen> createState() => _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState extends ConsumerState<NotificationHistoryScreen> {
  // Mock data for now until local DB (Hive) + Native Listener is fully implemented
  final List<Map<String, dynamic>> _notifications = [
    {'title': 'John Doe', 'message': 'Hey, are we still meeting?', 'time': '10:42 AM', 'app': 'WhatsApp'},
    {'title': 'Alice', 'message': 'I sent the files.', 'time': '09:15 AM', 'app': 'WhatsApp Business'},
    {'title': 'Mom', 'message': 'Call me back', 'time': 'Yesterday', 'app': 'WhatsApp'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enable Notification Access in System Settings')),
              );
            },
            tooltip: 'Enable Notification Access',
          )
        ],
      ),
      body: _notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 64, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 16),
                  const Text('No notifications caught yet', style: TextStyle(fontSize: 18)),
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Tap the settings icon to enable Notification Access so we can save deleted messages.',
                      textAlign: TextAlign.center,
                    ),
                  )
                ],
              ),
            )
          : ListView.separated(
              itemCount: _notifications.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final notif = _notifications[index];
                final isBusiness = notif['app'] == 'WhatsApp Business';
                
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isBusiness ? Colors.green[800] : Colors.green,
                    child: const Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(notif['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(notif['message']),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(notif['time'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Icon(isBusiness ? Icons.business : Icons.chat, size: 12, color: Colors.grey),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
