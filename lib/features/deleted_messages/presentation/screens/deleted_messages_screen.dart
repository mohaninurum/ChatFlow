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

class _DeletedMessagesScreenState extends ConsumerState<DeletedMessagesScreen> {
  static const _channel = MethodChannel('com.chatflow.app/channel');
  bool _isNotificationAccessGranted = false;
  String _searchQuery = '';
  String _activeFilter = 'All'; // 'All', 'Deleted Only', 'WA Business'

  @override
  void initState() {
    super.initState();
    _checkNotificationPermission();
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
          'Chatflow recovers messages by monitoring incoming notifications when Notification Access is enabled.\n\n'
          '• Encrypted chats are not cracked.\n'
          '• Messages sent while phone was offline, muted chats, or messages received before installing the app cannot be recovered.\n'
          '• When WhatsApp notifies "This message was deleted", Chatflow preserves the last captured notification preview.',
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Deleted Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Disclaimer & How it Works',
            onPressed: _showDisclaimer,
          ),
          IconButton(
            icon: const Icon(Icons.playlist_add),
            tooltip: 'Add Test Notification',
            onPressed: _addTestNotification,
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
                color: Colors.orange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
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
                          'Enable Notification Access to capture incoming WhatsApp notifications.',
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
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                    ),
                    onPressed: _openNotificationSettings,
                    child: const Text('Enable', style: TextStyle(fontSize: 12)),
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
                            'When WhatsApp notifications are received, they will be archived here. Tap the top-right button to test!',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13.sp, color: Colors.grey),
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
                  separatorBuilder: (_, __) => SizedBox(height: 8.h),
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
                          backgroundColor: isBiz ? Colors.teal.withOpacity(0.15) : Colors.green.withOpacity(0.15),
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
                                  color: Colors.teal.withOpacity(0.1),
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
                                  color: Colors.red.withOpacity(0.12),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat copied to clipboard!')),
      );
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
          reverse: true, // chronological WhatsApp chat style
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
                    BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2)),
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
                            'Deleted / Cancelled Notification',
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
