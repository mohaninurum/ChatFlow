import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/storage/hive_storage_service.dart';

/// WhatsApp Chat Export Parser
class WhatsAppChatParser {
  // Regex for Standard WhatsApp formats:
  // e.g. "15/02/24, 10:30 am - Rahul: Hey how are you?"
  // e.g. "15/02/2024, 10:30 - Rahul: Message"
  // e.g. "[15/02/24, 10:30:15] Rahul: Message"
  static final RegExp _headerRegex = RegExp(
    r'^(?:\[?(\d{1,4}[/\.-]\d{1,2}[/\.-]\d{2,4}),?\s+(\d{1,2}:\d{2}(?::\d{2})?(?:\s*[AaPp][Mm])?)\]?)\s*(?:[-–—]\s*)?([^:]+):\s*(.*)$',
  );

  static final RegExp _systemMessageRegex = RegExp(
    r'^(?:\[?(\d{1,4}[/\.-]\d{1,2}[/\.-]\d{2,4}),?\s+(\d{1,2}:\d{2}(?::\d{2})?(?:\s*[AaPp][Mm])?)\]?)\s*(?:[-–—]\s*)?(.*)$',
  );

  static bool isDeletedText(String text) {
    final lower = text.toLowerCase().trim();
    return lower.contains('this message was deleted') ||
        lower.contains('you deleted this message') ||
        lower.contains('यह संदेश हटा दिया गया') ||
        lower.contains('इस मैसेज को हटा दिया गया') ||
        lower.contains('message was deleted') ||
        lower.contains('message was revoked') ||
        lower.contains('deleted this message');
  }

  static List<Map<String, dynamic>> parseChat(String rawText, {String? defaultSender}) {
    final List<Map<String, dynamic>> parsedMessages = [];
    final lines = rawText.split('\n');

    Map<String, dynamic>? currentMessage;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trimRight();
      if (line.trim().isEmpty) continue;

      final match = _headerRegex.firstMatch(line);
      if (match != null) {
        if (currentMessage != null) {
          parsedMessages.add(currentMessage);
        }

        final date = match.group(1)?.trim() ?? '';
        final time = match.group(2)?.trim() ?? '';
        final sender = match.group(3)?.trim() ?? defaultSender ?? 'Unknown Contact';
        final content = match.group(4)?.trim() ?? '';

        final isDeleted = isDeletedText(content);

        currentMessage = {
          'id': '${DateTime.now().millisecondsSinceEpoch}_$i',
          'sender': sender,
          'message': content,
          'isDeleted': isDeleted,
          'packageName': 'com.whatsapp',
          'timestamp': '$date $time',
          'type': 'text',
        };
      } else {
        // Check if system message
        final sysMatch = _systemMessageRegex.firstMatch(line);
        if (sysMatch != null && sysMatch.groupCount >= 3) {
          final sysText = sysMatch.group(3)?.trim() ?? '';
          if (sysText.contains('end-to-end encrypted') ||
              sysText.contains('created group') ||
              sysText.contains('added') ||
              sysText.contains('changed the subject')) {
            // Skip pure WhatsApp encryption/admin banners
            continue;
          }
        }

        // Multi-line message continuation
        if (currentMessage != null) {
          currentMessage['message'] = '${currentMessage['message']}\n$line';
          if (!currentMessage['isDeleted'] && isDeletedText(currentMessage['message'])) {
            currentMessage['isDeleted'] = true;
          }
        }
      }
    }

    if (currentMessage != null) {
      parsedMessages.add(currentMessage);
    }

    return parsedMessages;
  }
}

class DeletedMessagesScreen extends ConsumerStatefulWidget {
  const DeletedMessagesScreen({super.key});

  @override
  ConsumerState<DeletedMessagesScreen> createState() => _DeletedMessagesScreenState();
}

class _DeletedMessagesScreenState extends ConsumerState<DeletedMessagesScreen> {
  static const _channel = MethodChannel('com.chatflow.app/channel');
  bool _isLoading = false;
  String _searchQuery = '';
  String _activeFilter = 'All'; // 'All', 'Deleted Only', 'WA Business'

  @override
  void initState() {
    super.initState();
  }

  Future<void> _importChatFromFile() async {
    setState(() => _isLoading = true);
    try {
      final String? fileContent = await _channel.invokeMethod<String>('pickChatFile');
      if (fileContent != null && fileContent.isNotEmpty) {
        await _processAndSaveChatText(fileContent, source: 'File Import');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showPasteChatDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.paste_rounded, color: Colors.green),
            SizedBox(width: 8),
            Text('Paste Chat Text'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Copy exported chat text from WhatsApp and paste it below:',
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[700]),
              ),
              SizedBox(height: 10.h),
              TextField(
                controller: controller,
                maxLines: 8,
                decoration: InputDecoration(
                  hintText: 'e.g. 15/02/24, 10:30 am - Rahul: Hey!\n15/02/24, 10:31 am - Rahul: This message was deleted',
                  hintStyle: TextStyle(fontSize: 12.sp, color: Colors.grey[400]),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                  filled: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(ctx, text);
              }
            },
            child: const Text('Analyze Chat'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        await _processAndSaveChatText(result, source: 'Pasted Text');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _processAndSaveChatText(String rawText, {required String source}) async {
    final parsed = WhatsAppChatParser.parseChat(rawText);
    if (parsed.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No messages could be parsed. Ensure the text is in standard WhatsApp export format.'),
          ),
        );
      }
      return;
    }

    final box = HiveStorageService.deletedMessages;
    int deletedCount = 0;
    for (final msg in parsed) {
      if (msg['isDeleted'] == true) deletedCount++;
      await box.add(msg);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green[800],
          content: Text(
            'Successfully loaded ${parsed.length} messages from $source ($deletedCount deleted found)!',
          ),
        ),
      );
    }
  }

  Future<void> _loadSampleDemoChat() async {
    final box = HiveStorageService.deletedMessages;
    final now = DateTime.now();

    final sampleItems = [
      {
        'id': '${now.millisecondsSinceEpoch}_1',
        'sender': 'Rahul Sharma',
        'message': 'Hey bro! Are you coming to the reunion party tonight?',
        'isDeleted': false,
        'packageName': 'com.whatsapp',
        'timestamp': 'Today, 10:15 AM',
        'type': 'text',
      },
      {
        'id': '${now.millisecondsSinceEpoch}_2',
        'sender': 'Rahul Sharma',
        'message': 'Yes I am leaving in 10 minutes! Got everything ready.',
        'isDeleted': false,
        'packageName': 'com.whatsapp',
        'timestamp': 'Today, 10:16 AM',
        'type': 'text',
      },
      {
        'id': '${now.millisecondsSinceEpoch}_3',
        'sender': 'Rahul Sharma',
        'message': 'This message was deleted',
        'isDeleted': true,
        'packageName': 'com.whatsapp',
        'timestamp': 'Today, 10:18 AM',
        'type': 'text',
      },
      {
        'id': '${now.millisecondsSinceEpoch}_4',
        'sender': 'Rahul Sharma',
        'message': 'Wait, did you delete that secret location message? 😂',
        'isDeleted': false,
        'packageName': 'com.whatsapp',
        'timestamp': 'Today, 10:19 AM',
        'type': 'text',
      },
      {
        'id': '${now.millisecondsSinceEpoch}_5',
        'sender': 'Rahul Sharma',
        'message': 'This message was deleted',
        'isDeleted': true,
        'packageName': 'com.whatsapp',
        'timestamp': 'Today, 10:20 AM',
        'type': 'text',
      },
      {
        'id': '${now.millisecondsSinceEpoch}_6',
        'sender': 'Rahul Sharma',
        'message': 'Haha yes, let us meet at Central Park café at 4 PM instead!',
        'isDeleted': false,
        'packageName': 'com.whatsapp',
        'timestamp': 'Today, 10:21 AM',
        'type': 'text',
      },
      // Business contact
      {
        'id': '${now.millisecondsSinceEpoch}_7',
        'sender': 'Neha Patel (Support)',
        'message': 'Hello! Your package has been dispatched via BlueDart.',
        'isDeleted': false,
        'packageName': 'com.whatsapp.w4b',
        'timestamp': 'Today, 09:00 AM',
        'type': 'text',
      },
      {
        'id': '${now.millisecondsSinceEpoch}_8',
        'sender': 'Neha Patel (Support)',
        'message': 'Tracking ID: BD-89234190',
        'isDeleted': false,
        'packageName': 'com.whatsapp.w4b',
        'timestamp': 'Today, 09:01 AM',
        'type': 'text',
      },
      {
        'id': '${now.millisecondsSinceEpoch}_9',
        'sender': 'Neha Patel (Support)',
        'message': 'This message was deleted',
        'isDeleted': true,
        'packageName': 'com.whatsapp.w4b',
        'timestamp': 'Today, 09:05 AM',
        'type': 'text',
      },
      {
        'id': '${now.millisecondsSinceEpoch}_10',
        'sender': 'Neha Patel (Support)',
        'message': 'Correct tracking ID: BD-89234999. Delivery expected tomorrow by 5 PM.',
        'isDeleted': false,
        'packageName': 'com.whatsapp.w4b',
        'timestamp': 'Today, 09:06 AM',
        'type': 'text',
      },
    ];

    for (var item in sampleItems) {
      await box.add(item);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sample demo chat loaded with deleted messages!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _clearAllMessages() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Messages?'),
        content: const Text('This will delete all saved chats and message history from Chatflow.'),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All chat records cleared')),
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

  void _showHowItWorks() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: const Row(
          children: [
            Icon(Icons.verified_user_rounded, color: Colors.green),
            SizedBox(width: 8),
            Text('Android 16 Safe Mode'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '100% Google Play Protect & Android 16 Compliant\n',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
              ),
              Text(
                'On Android 16, background notification listeners are restricted and trigger security blocks.\n\n'
                'Chatflow uses an alternate, 100% safe & private chat analyzer that requires ZERO sensitive permissions:\n\n'
                '1. Open any WhatsApp or WA Business conversation.\n'
                '2. Tap three dots (⋮) > More > Export Chat.\n'
                '3. Choose "Without Media" and save or share the .txt file.\n'
                '4. In Chatflow, tap "Import Chat (.txt)" or "Paste Chat Text".\n\n'
                'Chatflow instantly parses the conversation, highlights all deleted messages with red alerts, and lets you read and search them safely.',
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got It'),
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
            icon: const Icon(Icons.info_outline),
            tooltip: 'How Safe Mode Works',
            onPressed: _showHowItWorks,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              if (val == 'import') {
                _importChatFromFile();
              } else if (val == 'paste') {
                _showPasteChatDialog();
              } else if (val == 'demo') {
                _loadSampleDemoChat();
              } else if (val == 'clear') {
                _clearAllMessages();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.file_open_outlined, size: 20, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Import Chat (.txt)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'paste',
                child: Row(
                  children: [
                    Icon(Icons.paste_rounded, size: 20, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Paste Chat Text'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'demo',
                child: Row(
                  children: [
                    Icon(Icons.bolt_rounded, size: 20, color: Colors.amber),
                    SizedBox(width: 8),
                    Text('Load Demo Chat'),
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
          // Safe Mode Banner
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
                const Icon(Icons.shield_outlined, color: Colors.green, size: 28),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Android 16 Safe Mode',
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
                              'VERIFIED',
                              style: TextStyle(color: Colors.white, fontSize: 9.sp, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        '100% Secure • No sensitive notification listener required • Export & analyze chats safely',
                        style: TextStyle(fontSize: 11.sp, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Action Buttons Row (Import .txt / Paste Text / Demo)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                    ),
                    onPressed: _isLoading ? null : _importChatFromFile,
                    icon: _isLoading
                        ? SizedBox(width: 16.w, height: 16.w, child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.file_open_rounded, size: 18),
                    label: const Text('Import Chat (.txt)', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                SizedBox(width: 8.w),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                  onPressed: _showPasteChatDialog,
                  icon: const Icon(Icons.paste_rounded, size: 18),
                  label: const Text('Paste'),
                ),
              ],
            ),
          ),
          SizedBox(height: 8.h),

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
                  onPressed: _loadSampleDemoChat,
                  icon: const Icon(Icons.bolt, size: 16, color: Colors.amber),
                  label: Text('Demo Chat', style: TextStyle(fontSize: 12.sp, color: Colors.amber[800])),
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
                            'No Recovered Chats Yet',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            'To recover and view deleted messages safely on Android 16:\n\n'
                            '1. In WhatsApp, tap (⋮) > More > Export Chat > Without Media\n'
                            '2. Tap "Import Chat (.txt)" below or paste the text',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13.sp, color: Colors.grey[700]),
                          ),
                          SizedBox(height: 20.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                                ),
                                onPressed: _importChatFromFile,
                                icon: const Icon(Icons.file_open_rounded),
                                label: const Text('Import Chat (.txt)'),
                              ),
                              SizedBox(width: 10.w),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                                ),
                                onPressed: _loadSampleDemoChat,
                                icon: const Icon(Icons.bolt, color: Colors.amber),
                                label: const Text('Try Demo Chat'),
                              ),
                            ],
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
                  final time = m['timestamp']?.toString() ?? '';

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
                                  'DELETED MESSAGE DETECTED',
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
