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
    if (_isNotificationAccessGranted) {
      await _syncArchivedNotifications();
    }
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
    final sender = data['sender']?.toString() ?? 'WhatsApp User';
    final message = data['message']?.toString() ?? '';
    final isDeleted = data['isDeleted'] == true;
    final timestamp = data['timestamp']?.toString() ?? DateTime.now().toIso8601String();
    final packageName = data['packageName']?.toString() ?? 'com.whatsapp';

    if (isDeleted && sender.isNotEmpty) {
      // Find the most recent message from this sender to mark as deleted
      dynamic keyToUpdate;
      Map? mapToUpdate;
      for (var entry in box.toMap().entries) {
        if (entry.value is Map &&
            entry.value['sender'] == sender &&
            entry.value['isDeleted'] != true) {
          keyToUpdate = entry.key;
          mapToUpdate = entry.value as Map;
        }
      }

      if (keyToUpdate != null && mapToUpdate != null) {
        final updated = Map<String, dynamic>.from(mapToUpdate);
        updated['isDeleted'] = true;
        await box.put(keyToUpdate, updated);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red[700],
              content: Text('⚡ Deleted message detected from $sender! Original text preserved.'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }
    }

    // Insert new notification
    await box.add({
      'id': id.isNotEmpty ? id : DateTime.now().millisecondsSinceEpoch.toString(),
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
          SnackBar(content: Text('Could not open notification settings: $e')),
        );
      }
    }
  }

  Future<void> _openAppDetailsSettings() async {
    try {
      await _channel.invokeMethod('openAppDetailsSettings');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open App Info settings: $e')),
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
            content: Text('Notifications synchronized successfully'),
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

  void _simulateDeletedMessage() async {
    final now = DateTime.now();
    final box = HiveStorageService.deletedMessages;

    // Add a normal message first
    await box.add({
      'id': '${now.millisecondsSinceEpoch}_1',
      'sender': 'Alex Johnson',
      'message': 'Hey, meet me at the café at 4 PM! Don\'t tell anyone else.',
      'isDeleted': false,
      'packageName': 'com.whatsapp',
      'timestamp': 'Just now',
      'type': 'text',
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incoming WhatsApp message received from Alex Johnson!'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    // After 1.5 seconds, simulate sender deleting it ("Delete for Everyone")
    Future.delayed(const Duration(milliseconds: 1500), () async {
      final entries = box.toMap();
      for (var entry in entries.entries) {
        if (entry.value is Map &&
            entry.value['sender'] == 'Alex Johnson' &&
            entry.value['isDeleted'] != true) {
          final updated = Map<String, dynamic>.from(entry.value as Map);
          updated['isDeleted'] = true;
          await box.put(entry.key, updated);
          break;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red[800],
            content: const Text(
              '⚡ Alex Johnson clicked "Delete for Everyone"! Chatflow captured & preserved the deleted message!',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }

  Future<void> _clearAllMessages() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Recovered Messages?'),
        content: const Text('This will delete all saved messages and logs permanently from Chatflow.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
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
          const SnackBar(content: Text('All messages cleared')),
        );
      }
    }
  }

  Map<String, List<Map>> _groupMessagesBySender(List items) {
    final Map<String, List<Map>> grouped = {};
    for (var item in items) {
      if (item is Map) {
        final sender = item['sender']?.toString() ?? 'WhatsApp User';
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

  void _showAndroid16HelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Colors.green),
            SizedBox(width: 8),
            Text('Android 16 Setup Guide'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'How Automatic Deleted Message Recovery Works:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp),
              ),
              SizedBox(height: 6.h),
              Text(
                'Chatflow runs a local background notification listener. Whenever someone sends a message, it is recorded. If they delete it ("Delete for everyone"), Chatflow detects the deletion notice and highlights the original message for you!\n',
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[700]),
              ),
              Text(
                'If Android shows "Restricted Setting":',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp, color: Colors.orange[800]),
              ),
              SizedBox(height: 6.h),
              Text(
                '1. Open Phone Settings > Apps > Chatflow (or tap Step 1 button below)\n'
                '2. In the top-right corner, tap the 3 dots (⋮)\n'
                '3. Tap "Allow restricted settings" and enter your device PIN or fingerprint\n'
                '4. Return here and tap "Step 2: Enable Notification Access" to turn the switch ON!',
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[800], height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _openAppDetailsSettings();
            },
            child: const Text('Open App Info (Step 1)'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _openNotificationSettings();
            },
            child: const Text('Open Notification Access (Step 2)'),
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
            tooltip: 'Sync Messages',
            onPressed: () => _syncArchivedNotifications(showToast: true),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Android 16 Setup Guide',
            onPressed: _showAndroid16HelpDialog,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              if (val == 'simulate') {
                _simulateDeletedMessage();
              } else if (val == 'settings') {
                _openNotificationSettings();
              } else if (val == 'app_info') {
                _openAppDetailsSettings();
              } else if (val == 'clear') {
                _clearAllMessages();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'simulate',
                child: Row(
                  children: [
                    Icon(Icons.play_circle_outline, size: 20, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Simulate Deleted Message'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.notifications_active_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Notification Settings'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'app_info',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('App Info (Allow 3-Dots)'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
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
          // Dynamic Status Banner (Automatic Active vs Setup Needed)
          if (_isNotificationAccessGranted)
            Container(
              margin: EdgeInsets.all(12.w),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Automatic Live Recovery Active',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                            SizedBox(width: 6.w),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              child: Text(
                                'REAL-TIME',
                                style: TextStyle(color: Colors.white, fontSize: 9.sp, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'Background listener is active. Deleted messages are captured automatically with zero manual upload!',
                          style: TextStyle(fontSize: 11.sp, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              margin: EdgeInsets.all(12.w),
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bolt_rounded, color: Colors.orange, size: 26),
                      SizedBox(width: 8.w),
                      const Expanded(
                        child: Text(
                          'Enable Automatic Deleted Messages',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.info_outline, size: 20, color: Colors.orange),
                        onPressed: _showAndroid16HelpDialog,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'For 100% automatic recovery without manual upload, grant Notification Access. On Android 16, unlock via 2 simple steps:',
                    style: TextStyle(fontSize: 11.sp, color: Colors.grey[800]),
                  ),
                  SizedBox(height: 10.h),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.orange.shade700),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                            padding: EdgeInsets.symmetric(vertical: 8.h),
                          ),
                          onPressed: _openAppDetailsSettings,
                          child: Text(
                            'Step 1: Allow (3-Dots)',
                            style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                            padding: EdgeInsets.symmetric(vertical: 8.h),
                          ),
                          onPressed: _openNotificationSettings,
                          child: Text(
                            'Step 2: Enable Access',
                            style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Search bar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search chats or deleted text...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14.r)),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            ),
          ),
          SizedBox(height: 8.h),

          // Filters Row
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: Row(
              children: [
                _buildFilterChip('All'),
                SizedBox(width: 8.w),
                _buildFilterChip('Deleted Only'),
                SizedBox(width: 8.w),
                _buildFilterChip('WA Business'),
                const Spacer(),
                TextButton.icon(
                  onPressed: _simulateDeletedMessage,
                  icon: const Icon(Icons.play_circle_fill, size: 16, color: Colors.green),
                  label: Text('Test Auto Recovery', style: TextStyle(fontSize: 11.sp, color: Colors.green[800])),
                ),
              ],
            ),
          ),
          SizedBox(height: 6.h),

          // Chat-wise grouping list
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: HiveStorageService.deletedMessages.listenable(),
              builder: (context, Box box, _) {
                final allItems = box.values.toList().reversed.toList();
                if (allItems.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(28.w),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.mark_chat_unread_outlined, size: 64.sp, color: Colors.green.withValues(alpha: 0.6)),
                          SizedBox(height: 16.h),
                          const Text(
                            'Waiting For Messages',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            _isNotificationAccessGranted
                                ? 'Automatic Live Recovery is active! Whenever someone sends you a WhatsApp message and deletes it, Chatflow will automatically capture and preserve it here.'
                                : 'Notification access is off. Tap "Step 2: Enable Access" above to start capturing deleted messages automatically in the background.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13.sp, color: Colors.grey[700]),
                          ),
                          SizedBox(height: 20.h),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                            ),
                            onPressed: _simulateDeletedMessage,
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Simulate Test Deleted Message'),
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
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
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
                                      '$deletedCount Deleted',
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

class _ChatDetailScreen extends StatefulWidget {
  final String sender;
  final List<Map> messages;

  const _ChatDetailScreen({required this.sender, required this.messages});

  @override
  State<_ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<_ChatDetailScreen> {
  static const _channel = MethodChannel('com.chatflow.app/channel');
  bool _showOnlyDeleted = false;

  Future<void> _exportChat(BuildContext context) async {
    final buffer = StringBuffer();
    buffer.writeln('--- Chatflow Recovered Chat with ${widget.sender} ---');
    buffer.writeln('Exported on: ${DateTime.now().toLocal()}\n');

    for (var m in widget.messages.reversed) {
      final time = m['timestamp']?.toString() ?? '';
      final isDel = m['isDeleted'] == true ? '[DELETED] ' : '';
      buffer.writeln('[$time] $isDel${m['message']}');
    }

    try {
      await _channel.invokeMethod('shareText', {
        'text': buffer.toString(),
        'title': 'Export Chat with ${widget.sender}',
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
        title: Text('Clear Chat with ${widget.sender}?'),
        content: const Text('This will delete all saved messages for this contact from Chatflow.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
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
        if (entry.value is Map && entry.value['sender'] == widget.sender) {
          keysToDelete.add(entry.key);
        }
      }
      for (var k in keysToDelete) {
        await box.delete(k);
      }
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cleared chat history with ${widget.sender}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalDeleted = widget.messages.where((m) => m['isDeleted'] == true || (m['message'] ?? '').toString().contains('deleted')).length;

    final displayMessages = _showOnlyDeleted
        ? widget.messages.where((m) => m['isDeleted'] == true || (m['message'] ?? '').toString().contains('deleted')).toList()
        : widget.messages;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.sender, style: TextStyle(fontSize: 16.sp)),
            Text(
              '${widget.messages.length} messages • $totalDeleted deleted',
              style: TextStyle(fontSize: 11.sp, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showOnlyDeleted ? Icons.filter_alt : Icons.filter_alt_outlined,
              color: _showOnlyDeleted ? Colors.redAccent : null,
            ),
            tooltip: _showOnlyDeleted ? 'Show All Messages' : 'Show Only Deleted',
            onPressed: () {
              setState(() => _showOnlyDeleted = !_showOnlyDeleted);
            },
          ),
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
        child: displayMessages.isEmpty
            ? Center(
                child: Text(
                  'No deleted messages in this chat',
                  style: TextStyle(color: Colors.grey, fontSize: 14.sp),
                ),
              )
            : ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                reverse: true,
                itemCount: displayMessages.length,
                itemBuilder: (context, index) {
                  final m = displayMessages[index];
                  final text = m['message']?.toString() ?? '';
                  final isDeleted = m['isDeleted'] == true || text.contains('deleted');
                  final time = m['timestamp']?.toString().split('T').last.split('.').first ?? '';

                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: EdgeInsets.only(bottom: 10.h),
                      constraints: BoxConstraints(maxWidth: 300.w),
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: isDeleted
                            ? (isDark ? const Color(0xFF3B1D1D) : const Color(0xFFFFEBEE))
                            : (isDark ? const Color(0xFF202C33) : Colors.white),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(4.r),
                          topRight: Radius.circular(16.r),
                          bottomLeft: Radius.circular(16.r),
                          bottomRight: Radius.circular(16.r),
                        ),
                        border: isDeleted
                            ? Border.all(color: Colors.redAccent.withValues(alpha: 0.6), width: 1.2)
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isDeleted) ...[
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.block, size: 14, color: Colors.redAccent),
                                SizedBox(width: 4.w),
                                Text(
                                  'DELETED MESSAGE RECOVERED',
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
                              color: isDeleted
                                  ? (isDark ? Colors.red[200] : Colors.red[900])
                                  : (isDark ? Colors.white : Colors.black87),
                              fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,
                              fontWeight: isDeleted ? FontWeight.w500 : FontWeight.normal,
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
