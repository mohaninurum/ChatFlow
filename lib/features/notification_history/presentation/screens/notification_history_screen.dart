import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import '../../../../core/storage/hive_storage_service.dart';

class NotificationHistoryScreen extends ConsumerStatefulWidget {
  const NotificationHistoryScreen({super.key});

  @override
  ConsumerState<NotificationHistoryScreen> createState() => _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState extends ConsumerState<NotificationHistoryScreen> {
  StreamSubscription? _subscription;
  bool _hasPermission = false;
  bool _showOnlyDeleted = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionAndListen();
  }

  Future<void> _checkPermissionAndListen() async {
    final bool status = await NotificationListenerService.isPermissionGranted();
    if (!mounted) return;
    setState(() => _hasPermission = status);

    if (status) {
      _startListening();
    }
  }

  Future<void> _requestPermission() async {
    await NotificationListenerService.requestPermission();
    if (!mounted) return;
    _checkPermissionAndListen();
  }

  void _startListening() {
    _subscription?.cancel();
    _subscription = NotificationListenerService.notificationsStream.listen((event) async {
      // Only process WhatsApp and WhatsApp Business
      if (event.packageName != 'com.whatsapp' && event.packageName != 'com.whatsapp.w4b') {
        return;
      }

      final title = event.title?.trim();
      final content = event.content?.trim();

      if (title == null || content == null) return;
      if (content.isEmpty || content == 'Checking for new messages' || content.contains('WhatsApp Web is currently active')) {
        return;
      }

      final box = HiveStorageService.deletedMessages;
      final isDeletionNotice = content.contains('This message was deleted') ||
          content.contains('You deleted this message') ||
          content.contains('This message was revoked');

      if (isDeletionNotice) {
        // Find previous un-deleted message from this sender
        final entries = box.toMap().entries.toList().reversed;
        dynamic targetKey;
        Map? targetData;

        for (var entry in entries) {
          final data = entry.value as Map;
          if (data['sender'] == title && data['isDeleted'] != true) {
            targetKey = entry.key;
            targetData = Map.from(data);
            break;
          }
        }

        if (targetKey != null && targetData != null) {
          targetData['isDeleted'] = true;
          targetData['deletedAt'] = DateTime.now().toIso8601String();
          await box.put(targetKey, targetData);
        } else {
          // If no previous message found, log that a message was deleted by this sender
          await box.add({
            'sender': title,
            'message': '[Message content deleted before app was opened]',
            'packageName': event.packageName,
            'timestamp': DateTime.now().toIso8601String(),
            'isDeleted': true,
          });
        }
      } else {
        // Regular incoming WhatsApp message
        await box.add({
          'sender': title,
          'message': content,
          'packageName': event.packageName,
          'timestamp': DateTime.now().toIso8601String(),
          'isDeleted': false,
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recover Deleted Msgs'),
        actions: [
          IconButton(
            icon: Icon(
              _hasPermission ? Icons.check_circle : Icons.warning_amber_rounded,
              color: _hasPermission ? Colors.green : Colors.red,
            ),
            tooltip: _hasPermission ? 'Service Active' : 'Enable Notification Access',
            onPressed: _requestPermission,
          ),
        ],
      ),
      body: !_hasPermission
          ? _buildPermissionPrompt(theme)
          : _buildMessagesList(theme),
    );
  }

  Widget _buildPermissionPrompt(ThemeData theme) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.security, size: 64.sp, color: theme.colorScheme.primary),
            ),
            SizedBox(height: 24.h),
            Text(
              'Notification Access Required',
              style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12.h),
            Text(
              'To catch and restore deleted WhatsApp messages in real-time, ChatFlow needs Notification Access permission.\n\nNote: If prompted, select "Chatflow" and toggle allow.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
            ),
            SizedBox(height: 32.h),
            ElevatedButton.icon(
              onPressed: _requestPermission,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 14.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
              ),
              icon: const Icon(Icons.settings),
              label: const Text('Grant Notification Permission'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesList(ThemeData theme) {
    return ValueListenableBuilder(
      valueListenable: HiveStorageService.deletedMessages.listenable(),
      builder: (context, Box box, _) {
        final allEntries = box.toMap().entries.toList().reversed.toList();

        final filtered = _showOnlyDeleted
            ? allEntries.where((e) => (e.value as Map)['isDeleted'] == true).toList()
            : allEntries;

        final deletedCount = allEntries.where((e) => (e.value as Map)['isDeleted'] == true).length;

        return Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              color: theme.colorScheme.surface,
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text('All (${allEntries.length})'),
                    selected: !_showOnlyDeleted,
                    onSelected: (_) => setState(() => _showOnlyDeleted = false),
                  ),
                  SizedBox(width: 8.w),
                  ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.delete_sweep, size: 16, color: Colors.red),
                        SizedBox(width: 4.w),
                        Text('Deleted Only ($deletedCount)'),
                      ],
                    ),
                    selected: _showOnlyDeleted,
                    onSelected: (_) => setState(() => _showOnlyDeleted = true),
                  ),
                  const Spacer(),
                  if (allEntries.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.grey),
                      tooltip: 'Clear History',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Clear Messages?'),
                            content: const Text('Delete all captured WhatsApp message history?'),
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
                        if (confirm == true) {
                          await box.clear();
                        }
                      },
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.mark_chat_unread_outlined, size: 64.sp, color: Colors.grey),
                          SizedBox(height: 16.h),
                          Text(
                            _showOnlyDeleted ? 'No deleted messages yet' : 'Listening for WhatsApp messages...',
                            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8.h),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 32.w),
                            child: Text(
                              'Incoming WhatsApp messages will be logged automatically. When someone deletes a message, it will be highlighted in red here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[600], fontSize: 13.sp),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.all(12.w),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => SizedBox(height: 8.h),
                      itemBuilder: (context, index) {
                        final entry = filtered[index];
                        final item = entry.value as Map;
                        final sender = item['sender'] ?? 'Unknown';
                        final message = item['message'] ?? '';
                        final isDeleted = item['isDeleted'] == true;
                        final isBusiness = item['packageName'] == 'com.whatsapp.w4b';
                        final timestamp = item['timestamp']?.toString().split('T').last.split('.').first ?? '';

                        return Card(
                          elevation: isDeleted ? 3 : 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                            side: isDeleted
                                ? BorderSide(color: Colors.red.withOpacity(0.5), width: 1.5)
                                : BorderSide.none,
                          ),
                          color: isDeleted ? Colors.red.withOpacity(0.04) : null,
                          child: Padding(
                            padding: EdgeInsets.all(14.w),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16.r,
                                      backgroundColor: isBusiness ? Colors.green[800] : Colors.green,
                                      child: const Icon(Icons.person, color: Colors.white, size: 18),
                                    ),
                                    SizedBox(width: 10.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            sender,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15.sp,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            isBusiness ? 'WhatsApp Business' : 'WhatsApp',
                                            style: TextStyle(fontSize: 10.sp, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isDeleted)
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.circular(8.r),
                                        ),
                                        child: Text(
                                          'DELETED',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10.sp,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    SizedBox(width: 8.w),
                                    Text(
                                      timestamp,
                                      style: TextStyle(fontSize: 11.sp, color: Colors.grey),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 10.h),
                                Text(
                                  message,
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: isDeleted ? Colors.red[900] : Colors.black87,
                                    fontWeight: isDeleted ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                                SizedBox(height: 6.h),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.copy, size: 16, color: Colors.grey),
                                      tooltip: 'Copy Message',
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(text: message));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Message copied!')),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.grey),
                                      tooltip: 'Delete Log',
                                      onPressed: () => box.delete(entry.key),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
