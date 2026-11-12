import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/storage/hive_storage_service.dart';

class DeletedMessagesScreen extends ConsumerStatefulWidget {
  const DeletedMessagesScreen({super.key});

  @override
  ConsumerState<DeletedMessagesScreen> createState() => _DeletedMessagesScreenState();
}

class _DeletedMessagesScreenState extends ConsumerState<DeletedMessagesScreen>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel('com.chatflow.app/channel');
  bool _isNotificationAccessGranted = false;
  bool _isSyncing = false;
  String _searchQuery = '';
  String _activeFilter = 'All'; // 'All', 'Deleted Only', 'WA Business'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _channel.setMethodCallHandler(_handleNativeMethod);
    _initFlow();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initFlow();
    }
  }

  Future<void> _initFlow() async {
    await _checkNotificationPermission();
    await _syncArchivedNotifications();
  }

  Future<dynamic> _handleNativeMethod(MethodCall call) async {
    if (call.method == 'onNotificationReceived') {
      final data = call.arguments;
      if (data is Map) {
        await _processIncomingNotification(data);
      }
    }
  }

  Future<void> _processIncomingNotification(Map data) async {
    final box = HiveStorageService.deletedMessages;
    final id = data['id']?.toString() ?? '';
    final sender = data['sender']?.toString() ?? '';
    final message = data['message']?.toString() ?? '';
    final isDeleted = data['isDeleted'] == true;
    final timestamp = data['timestamp']?.toString() ?? DateTime.now().toIso8601String();
    final packageName = data['packageName']?.toString() ?? 'com.whatsapp';

    if (isDeleted && sender.isNotEmpty) {
      dynamic keyToUpdate;
      Map? mapToUpdate;
      for (var entry in box.toMap().entries) {
        if (entry.value is Map && entry.value['sender'] == sender && entry.value['isDeleted'] != true) {
          keyToUpdate = entry.key;
          mapToUpdate = entry.value as Map;
        }
      }

      if (keyToUpdate != null && mapToUpdate != null) {
        final updated = Map<String, dynamic>.from(mapToUpdate);
        updated['isDeleted'] = true;
        await box.put(keyToUpdate, updated);
        return;
      }
    }

    // Insert new notification
    await box.add({
      'id': id,
      'sender': sender,
      'message': message,
      'isDeleted': isDeleted,
      'packageName': packageName,
      'timestamp': timestamp,
      'type': 'text',
    });
  }

  Future<void> _checkNotificationPermission() async {
    try {
      final bool granted = await _channel.invokeMethod('isNotificationAccessGranted') ?? false;
      if (mounted) {
        setState(() => _isNotificationAccessGranted = granted);
      }
    } catch (_) {
      if (mounted) setState(() => _isNotificationAccessGranted = false);
    }
  }

  Future<void> _openNotificationSettings() async {
    try {
      await _channel.invokeMethod('openNotificationSettings');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open settings: $e')),
        );
      }
    }
  }

  Future<void> _syncArchivedNotifications({bool showToast = false}) async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);

    try {
      final List<dynamic>? rawList =
          await _channel.invokeMethod<List<dynamic>>('getArchivedNotifications');

      if (rawList != null && rawList.isNotEmpty) {
        final box = HiveStorageService.deletedMessages;
        final existingEntries = box.toMap();

        for (var raw in rawList) {
          if (raw is Map) {
            final id = raw['id']?.toString() ?? '';
            final sender = raw['sender']?.toString() ?? '';
            final message = raw['message']?.toString() ?? '';
            final isDeleted = raw['isDeleted'] == true;
            final timestamp = raw['timestamp']?.toString() ?? '';
            final packageName = raw['packageName']?.toString() ?? 'com.whatsapp';
            final type = raw['type']?.toString() ?? 'text';

            dynamic matchingKey;
            Map? existingMap;

            for (var entry in existingEntries.entries) {
              if (entry.value is Map) {
                final m = entry.value as Map;
                if ((id.isNotEmpty && m['id'] == id) ||
                    (m['sender'] == sender && m['timestamp'] == timestamp)) {
                  matchingKey = entry.key;
                  existingMap = m;
                  break;
                }
              }
            }

            if (matchingKey != null && existingMap != null) {
              if (isDeleted && existingMap['isDeleted'] != true) {
                final updated = Map<String, dynamic>.from(existingMap);
                updated['isDeleted'] = true;
                await box.put(matchingKey, updated);
              }
            } else {
              await box.add({
                'id': id,
                'sender': sender,
                'message': message,
                'isDeleted': isDeleted,
                'packageName': packageName,
                'timestamp': timestamp,
                'type': type,
              });
            }
          }
        }
      }

      if (showToast && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notifications synced successfully'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  void _addTestNotification() async {
    final now = DateTime.now().toIso8601String();
    final sample = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'sender': 'Alex Johnson',
      'message': 'Hey, are you free for a quick call? Wait, never mind!',
      'isDeleted': true,
      'packageName': 'com.whatsapp',
      'timestamp': now,
      'type': 'text',
    };
    await HiveStorageService.deletedMessages.add(sample);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test notification recorded with [Deleted] indicator!')),
      );
    }
  }

  Future<void> _clearAllNotifications() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Recovered Messages?'),
        content: const Text('This will delete all saved messages and logs permanently.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await HiveStorageService.deletedMessages.clear();
      try {
        await _channel.invokeMethod('clearArchivedNotifications');
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All recovered messages cleared')),
        );
      }
    }
  }

  Map<String, List<Map>> _groupMessagesBySender(List items) {
    final Map<String, List<Map>> grouped = {};
    for (var item in items) {
      if (item is Map) {
        final sender = item['sender']?.toString() ?? 'Unknown Sender';
        grouped.putIfAbsent(sender, () => []).add(item);
      }
    }
    return grouped;
  }

  void _openChatDetail(String sender, List<Map> messages) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => _ChatDetailScreen(sender: sender, messages: messages),
      ),
    );
  }

  void _showDisclaimer() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Colors.blue),
            SizedBox(width: 8),
            Text('How Recovery Works'),
          ],
        ),
        content: const Text(
          'Chatflow automatically recovers WhatsApp messages by monitoring incoming notifications in the background.\n\n'
          '• Make sure Notification Access is enabled for Chatflow.\n'
          '• When someone sends a message, Chatflow captures and securely saves the notification text.\n'
          '• When the sender clicks "Delete for Everyone", WhatsApp updates the notification to "This message was deleted" - and Chatflow marks the previous message as [DELETED] while keeping the original text visible for you!\n\n'
          'Note: Messages sent when your phone was turned off or chats that were muted without notifications cannot be recovered.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deleted Messages'),
        actions: [
          IconButton(
            icon: _isSyncing
                ? SizedBox(
                    width: 18.w,
                    height: 18.w,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: 'Sync Notifications',
            onPressed: () => _syncArchivedNotifications(showToast: true),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'How it Works',
            onPressed: _showDisclaimer,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              if (val == 'test') {
                _addTestNotification();
              } else if (val == 'clear') {
                _clearAllNotifications();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'test',
                child: Row(
                  children: [
                    Icon(Icons.add_comment_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Add Test Message'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Clear All Messages', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Permission status banner if not granted
          if (!_isNotificationAccessGranted)
            Container(
              margin: EdgeInsets.all(12.w),
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_paused_rounded, color: Colors.orange, size: 28),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Notification Access Required',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'Enable Notification Access for Chatflow to capture WhatsApp messages before they are deleted.',
                          style: TextStyle(fontSize: 11.sp, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                    ),
                    onPressed: _openNotificationSettings,
                    child: const Text('Enable', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

          // Search bar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search chats or deleted text...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r)),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            ),
          ),

          // Filters Row
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                _buildFilterChip('All'),
                SizedBox(width: 8.w),
                _buildFilterChip('Deleted Only'),
                SizedBox(width: 8.w),
                _buildFilterChip('WA Business'),
              ],
            ),
          ),
          SizedBox(height: 8.h),

          // Chat-wise grouping list
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: HiveStorageService.deletedMessages.listenable(),
              builder: (context, Box box, _) {
                final allItems = box.values.toList().reversed.toList();
                if (allItems.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.w),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.mark_chat_unread_outlined, size: 64.sp, color: Colors.grey),
                          SizedBox(height: 16.h),
                          const Text(
                            'No Recovered Messages Yet',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            _isNotificationAccessGranted
                                ? 'Monitoring active! Incoming WhatsApp messages will automatically appear here. When someone deletes a message, it will be marked [DELETED].'
                                : 'Notification access is off. Tap "Enable" above to start recovering deleted WhatsApp messages.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13.sp, color: Colors.grey),
                          ),
                          SizedBox(height: 16.h),
                          OutlinedButton.icon(
                            onPressed: _addTestNotification,
                            icon: const Icon(Icons.add_comment_outlined),
                            label: const Text('Add Test Message'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Filter items
                final filtered = allItems.where((item) {
                  if (item is! Map) return false;
                  final sender = (item['sender'] ?? '').toString().toLowerCase();
                  final msg = (item['message'] ?? '').toString().toLowerCase();
                  final isDel = item['isDeleted'] == true || msg.contains('deleted');
                  final isBiz = item['packageName'] == 'com.whatsapp.w4b';

                  if (_searchQuery.isNotEmpty && !sender.contains(_searchQuery) && !msg.contains(_searchQuery)) {
                    return false;
                  }
                  if (_activeFilter == 'Deleted Only' && !isDel) return false;
                  if (_activeFilter == 'WA Business' && !isBiz) return false;

                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text('No messages match the current filter', style: TextStyle(color: Colors.grey, fontSize: 14.sp)),
                  );
                }

                final grouped = _groupMessagesBySender(filtered);
                final senders = grouped.keys.toList();

                return ListView.separated(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  itemCount: senders.length,
                  separatorBuilder: (context, index) => SizedBox(height: 8.h),
                  itemBuilder: (context, index) {
                    final sender = senders[index];
                    final chatMessages = grouped[sender]!;
                    final lastMsg = chatMessages.first;
                    final deletedCount = chatMessages.where((m) => m['isDeleted'] == true || (m['message'] ?? '').toString().contains('deleted')).length;
                    final isBiz = lastMsg['packageName'] == 'com.whatsapp.w4b';

                    return Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                      child: ListTile(
                        onTap: () => _openChatDetail(sender, chatMessages),
                        leading: CircleAvatar(
                          backgroundColor: isBiz ? Colors.teal.withValues(alpha: 0.15) : Colors.green.withValues(alpha: 0.15),
                          child: Text(
                            sender.isNotEmpty ? sender[0].toUpperCase() : '?',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isBiz ? Colors.teal : Colors.green,
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(sender, style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            if (isBiz)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  color: Colors.teal.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6.r),
                                ),
                                child: Text('Business', style: TextStyle(fontSize: 10.sp, color: Colors.teal)),
                              ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: EdgeInsets.only(top: 4.h),
                          child: Text(
                            lastMsg['message']?.toString() ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: lastMsg['isDeleted'] == true ? Colors.redAccent : Colors.grey[700],
                              fontStyle: lastMsg['isDeleted'] == true ? FontStyle.italic : FontStyle.normal,
                            ),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (deletedCount > 0)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.delete_outline, size: 12, color: Colors.red),
                                    SizedBox(width: 2.w),
                                    Text(
                                      '$deletedCount',
                                      style: TextStyle(color: Colors.red, fontSize: 11.sp, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            SizedBox(width: 6.w),
                            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _activeFilter == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _activeFilter = label),
    );
  }
}

class _ChatDetailScreen extends StatelessWidget {
  final String sender;
  final List<Map> messages;

  const _ChatDetailScreen({required this.sender, required this.messages});

  static const _channel = MethodChannel('com.chatflow.app/channel');

  Future<void> _exportChat(BuildContext context) async {
    final buffer = StringBuffer();
    buffer.writeln('--- Chatflow Recovered Chat with $sender ---');
    buffer.writeln('Exported on: ${DateTime.now().toLocal()}\n');

    for (var m in messages.reversed) {
      final time = m['timestamp']?.toString().split('T').first ?? '';
      final isDel = m['isDeleted'] == true ? '[DELETED] ' : '';
      buffer.writeln('[$time] $isDel${m['message']}');
    }

    try {
      await _channel.invokeMethod('shareText', {
        'text': buffer.toString(),
        'title': 'Export Chat with $sender',
      });
    } catch (e) {
      Clipboard.setData(ClipboardData(text: buffer.toString()));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat copied to clipboard!')),
        );
      }
    }
  }

  Future<void> _clearThisChat(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Clear Chat with $sender?'),
        content: const Text('This will delete all recovered notification logs for this sender.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final box = HiveStorageService.deletedMessages;
      final keysToDelete = <dynamic>[];
      for (var entry in box.toMap().entries) {
        if (entry.value is Map && entry.value['sender'] == sender) {
          keysToDelete.add(entry.key);
        }
      }
      for (var k in keysToDelete) {
        await box.delete(k);
      }
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cleared chat history with $sender')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(sender),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Export Chat',
            onPressed: () => _exportChat(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Clear This Chat',
            onPressed: () => _clearThisChat(context),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111B21) : const Color(0xFFEFEAE2),
        ),
        child: ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          reverse: true,
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final m = messages[index];
            final text = m['message']?.toString() ?? '';
            final isDeleted = m['isDeleted'] == true || text.contains('deleted');
            final time = m['timestamp']?.toString().split('T').last.split('.').first ?? '';

            return Align(
              alignment: Alignment.centerLeft,
              child: Container(
                margin: EdgeInsets.only(bottom: 10.h),
                constraints: BoxConstraints(maxWidth: 280.w),
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF202C33) : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4.r),
                    topRight: Radius.circular(16.r),
                    bottomLeft: Radius.circular(16.r),
                    bottomRight: Radius.circular(16.r),
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isDeleted) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.block, size: 12, color: Colors.redAccent),
                          SizedBox(width: 4.w),
                          Text(
                            'Deleted / Cancelled Message',
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4.h),
                    ],
                    Text(
                      text,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        time,
                        style: TextStyle(fontSize: 10.sp, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
