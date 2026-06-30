import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:notification_listener_service/notification_event.dart';

class NotificationHistoryScreen extends ConsumerStatefulWidget {
  const NotificationHistoryScreen({super.key});

  @override
  ConsumerState<NotificationHistoryScreen> createState() => _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState extends ConsumerState<NotificationHistoryScreen> {
  final List<ServiceNotificationEvent> _notifications = [];
  StreamSubscription? _subscription;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionAndListen();
  }

  Future<void> _checkPermissionAndListen() async {
    final bool status = await NotificationListenerService.isPermissionGranted();
    setState(() => _hasPermission = status);

    if (status) {
      _startListening();
    }
  }

  Future<void> _requestPermission() async {
    await NotificationListenerService.requestPermission();
    _checkPermissionAndListen();
  }

  void _startListening() {
    _subscription = NotificationListenerService.notificationsStream.listen((event) {
      // Only listen to WhatsApp and WhatsApp Business
      if (event.packageName == 'com.whatsapp' || event.packageName == 'com.whatsapp.w4b') {
        // Exclude system/ongoing notifications
        if (event.title != null && event.content != null && event.content != 'Checking for new messages') {
          setState(() {
            // Add at the beginning of the list
            _notifications.insert(0, event);
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  bool _isDeletedMessage(String? content) {
    if (content == null) return false;
    return content.contains('This message was deleted') || content.contains('You deleted this message');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deleted Messages'),
        actions: [
          IconButton(
            icon: Icon(_hasPermission ? Icons.check_circle : Icons.warning_amber),
            color: _hasPermission ? Colors.green : Colors.red,
            onPressed: _requestPermission,
            tooltip: _hasPermission ? 'Service Active' : 'Enable Notification Access',
          )
        ],
      ),
      body: !_hasPermission
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.settings_applications, size: 80, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 16),
                  const Text('Permission Required', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text(
                      'To catch and recover deleted messages, ChatFlow needs Notification Access permission to read incoming WhatsApp messages in real-time.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _requestPermission,
                    icon: const Icon(Icons.security),
                    label: const Text('Grant Permission'),
                  )
                ],
              ),
            )
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.mark_email_unread_outlined, size: 80, color: Theme.of(context).colorScheme.secondary.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      const Text('Listening for messages...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'New WhatsApp messages will appear here. If someone deletes a message, you will still be able to see the original text above the "deleted" notice.',
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
                    final isBusiness = notif.packageName == 'com.whatsapp.w4b';
                    final isDeleted = _isDeletedMessage(notif.content);
                    
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isBusiness ? Colors.green[800] : Colors.green,
                        child: const Icon(Icons.person, color: Colors.white),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(notif.title ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                          ),
                          if (isDeleted) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.red.withOpacity(0.5)),
                              ),
                              child: const Text('Deleted', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
                            )
                          ]
                        ],
                      ),
                      subtitle: Text(notif.content ?? '', style: TextStyle(color: isDeleted ? Colors.black87 : Colors.grey)),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Format time nicely if we had a timestamp, but ServiceNotificationEvent has no timestamp by default sometimes, 
                          // or we can just use "Just now" for this live stream
                          const Text('Just now', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
