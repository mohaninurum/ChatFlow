import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/storage/hive_storage_service.dart';

class MessageHubScreen extends ConsumerStatefulWidget {
  const MessageHubScreen({super.key});

  @override
  ConsumerState<MessageHubScreen> createState() => _MessageHubScreenState();
}

class _MessageHubScreenState extends ConsumerState<MessageHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _stylerController = TextEditingController();
  String _styleInput = 'Hello WhatsApp';
  String _selectedCategory = 'All';

  final List<String> _categories = ['All', 'Quick Replies', 'Business', 'Personal', 'Custom'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _stylerController.text = _styleInput;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _stylerController.dispose();
    super.dispose();
  }

  Future<void> _sendToWhatsApp(String message, [String? targetPhone]) async {
    final phoneController = TextEditingController(text: targetPhone ?? '');
    String countryCode = '+91';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20.h,
          left: 20.w,
          right: 20.w,
          top: 20.h,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Send via WhatsApp',
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                )
              ],
            ),
            SizedBox(height: 10.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.sp, color: Colors.grey[800]),
              ),
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                SizedBox(
                  width: 75.w,
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Code',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
                    ),
                    controller: TextEditingController(text: countryCode),
                    onChanged: (v) => countryCode = v,
                    keyboardType: TextInputType.phone,
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: TextField(
                    controller: phoneController,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      hintText: 'Enter recipient number',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                      prefixIcon: const Icon(Icons.phone_outlined),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                    ),
                    keyboardType: TextInputType.phone,
                    autofocus: true,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            ElevatedButton.icon(
              onPressed: () async {
                final phone = phoneController.text.trim().replaceAll(RegExp(r'\D'), '');
                final code = countryCode.replaceAll('+', '').trim();

                if (phone.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a phone number')),
                  );
                  return;
                }

                final fullNumber = '$code$phone';
                final encodedMsg = Uri.encodeComponent(message);
                final url = Uri.parse('https://wa.me/$fullNumber?text=$encodedMsg');

                // Log to history
                await HiveStorageService.history.add({
                  'phone': fullNumber,
                  'message': message,
                  'timestamp': DateTime.now().toIso8601String(),
                });

                if (ctx.mounted) Navigator.pop(ctx);

                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not open WhatsApp')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.send),
              label: Text('Open in WhatsApp', style: TextStyle(fontSize: 15.sp)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddTemplateDialog() async {
    final titleController = TextEditingController();
    final msgController = TextEditingController();
    String category = 'Custom';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          title: const Text('New Message Template'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. Order Update, Driving...'),
                ),
                SizedBox(height: 12.h),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: _categories.where((c) => c != 'All').map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => category = val);
                  },
                ),
                SizedBox(height: 12.h),
                TextField(
                  controller: msgController,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text.trim();
                final msg = msgController.text.trim();
                if (title.isEmpty || msg.isEmpty) return;

                await HiveStorageService.templates.add({
                  'title': title,
                  'message': msg,
                  'category': category,
                });

                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // Stylish Fonts Converter
  List<Map<String, String>> _generateFontStyles(String input) {
    if (input.isEmpty) input = 'Type something';

    final styles = <Map<String, String>>[];

    // 1. Bold Sans
    styles.add({'name': 'Bold Sans', 'text': _convertMath(input, 0x1D5D4, 0x1D5EE, 0x1D7EC)});
    // 2. Italic Serif
    styles.add({'name': 'Italic Serif', 'text': _convertMath(input, 0x1D434, 0x1D44E, null)});
    // 3. Bold Script (Cursive)
    styles.add({'name': 'Cursive Bold', 'text': _convertMath(input, 0x1D4D0, 0x1D4EA, null)});
    // 4. Double Struck (Outline)
    styles.add({'name': 'Outline / Double', 'text': _convertMath(input, 0x1D538, 0x1D552, 0x1D7D8)});
    // 5. Monospace
    styles.add({'name': 'Monospace / Code', 'text': _convertMath(input, 0x1D670, 0x1D68A, 0x1D7F6)});
    // 6. Circled / Bubble
    styles.add({'name': 'Bubble / Circled', 'text': _convertCircled(input)});
    // 7. Small Caps
    styles.add({'name': 'Small Caps', 'text': _convertSmallCaps(input)});
    // 8. Spaced Out
    styles.add({'name': 'Aesthetic Spaced', 'text': input.split('').join(' ')});

    return styles;
  }

  String _convertMath(String str, int upperBase, int lowerBase, int? digitBase) {
    final buffer = StringBuffer();
    for (var code in str.runes) {
      if (code >= 65 && code <= 90) {
        buffer.writeCharCode(upperBase + (code - 65));
      } else if (code >= 97 && code <= 122) {
        buffer.writeCharCode(lowerBase + (code - 97));
      } else if (digitBase != null && code >= 48 && code <= 57) {
        buffer.writeCharCode(digitBase + (code - 48));
      } else {
        buffer.writeCharCode(code);
      }
    }
    return buffer.toString();
  }

  String _convertCircled(String str) {
    final buffer = StringBuffer();
    for (var code in str.runes) {
      if (code >= 65 && code <= 90) {
        buffer.writeCharCode(0x24B6 + (code - 65));
      } else if (code >= 97 && code <= 122) {
        buffer.writeCharCode(0x24D0 + (code - 97));
      } else if (code >= 49 && code <= 57) {
        buffer.writeCharCode(0x2460 + (code - 49));
      } else if (code == 48) {
        buffer.writeCharCode(0x24EA);
      } else {
        buffer.writeCharCode(code);
      }
    }
    return buffer.toString();
  }

  String _convertSmallCaps(String str) {
    const normal = 'abcdefghijklmnopqrstuvwxyz';
    const smallCaps = 'ᴀʙᴄᴅᴇғɢʜɪᴊᴋʟᴍɴᴏᴘǫʀsᴛᴜᴠᴡxʏᴢ';
    final buffer = StringBuffer();
    for (var char in str.split('')) {
      final index = normal.indexOf(char.toLowerCase());
      if (index != -1) {
        buffer.write(smallCaps[index]);
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Message Hub'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.quickreply), text: 'Templates'),
            Tab(icon: Icon(Icons.auto_awesome), text: 'Stylish Fonts'),
            Tab(icon: Icon(Icons.history), text: 'Sent Logs'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTemplateDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Reply'),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTemplatesTab(theme),
          _buildStylerTab(theme),
          _buildHistoryTab(theme),
        ],
      ),
    );
  }

  Widget _buildTemplatesTab(ThemeData theme) {
    return Column(
      children: [
        SizedBox(height: 12.h),
        SizedBox(
          height: 38.h,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (_, __) => SizedBox(width: 8.w),
            itemBuilder: (context, index) {
              final cat = _categories[index];
              return ChoiceChip(
                label: Text(cat),
                selected: _selectedCategory == cat,
                onSelected: (_) => setState(() => _selectedCategory = cat),
              );
            },
          ),
        ),
        SizedBox(height: 8.h),
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: HiveStorageService.templates.listenable(),
            builder: (context, Box box, _) {
              final all = box.toMap().entries.toList();
              final items = _selectedCategory == 'All'
                  ? all
                  : all.where((e) => (e.value as Map)['category'] == _selectedCategory).toList();

              if (items.isEmpty) {
                return Center(
                  child: Text('No replies in this category', style: TextStyle(color: Colors.grey, fontSize: 16.sp)),
                );
              }

              return ListView.separated(
                padding: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 80.h),
                itemCount: items.length,
                separatorBuilder: (_, __) => SizedBox(height: 10.h),
                itemBuilder: (context, index) {
                  final entry = items[index];
                  final item = entry.value as Map;
                  final title = item['title'] ?? '';
                  final msg = item['message'] ?? '';
                  final cat = item['category'] ?? 'Custom';

                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                    elevation: 1.5,
                    child: Padding(
                      padding: EdgeInsets.all(14.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp)),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6.r),
                                ),
                                child: Text(cat, style: TextStyle(fontSize: 11.sp, color: theme.colorScheme.primary)),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Text(msg, style: TextStyle(fontSize: 13.5.sp, color: Colors.grey[800])),
                          SizedBox(height: 10.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.copy, size: 18),
                                tooltip: 'Copy',
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: msg));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Copied to clipboard')),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                tooltip: 'Delete',
                                onPressed: () => box.delete(entry.key),
                              ),
                              SizedBox(width: 8.w),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green[700],
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                                ),
                                onPressed: () => _sendToWhatsApp(msg),
                                icon: const Icon(Icons.send, size: 16),
                                label: const Text('Send'),
                              ),
                            ],
                          ),
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
    );
  }

  Widget _buildStylerTab(ThemeData theme) {
    final styles = _generateFontStyles(_styleInput);

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16.w),
          child: TextField(
            controller: _stylerController,
            decoration: InputDecoration(
              labelText: 'Enter text to stylize',
              hintText: 'e.g. Hello, Bio, Status...',
              prefixIcon: const Icon(Icons.text_format),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r)),
              filled: true,
            ),
            onChanged: (val) => setState(() => _styleInput = val.trim()),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            itemCount: styles.length,
            separatorBuilder: (_, __) => SizedBox(height: 8.h),
            itemBuilder: (context, index) {
              final style = styles[index];
              final name = style['name']!;
              final styledText = style['text']!;

              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                child: Padding(
                  padding: EdgeInsets.all(12.w),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: TextStyle(fontSize: 11.sp, color: Colors.grey)),
                            SizedBox(height: 4.h),
                            Text(styledText, style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20),
                        tooltip: 'Copy',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: styledText));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copied styled text!')),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.send, color: Colors.green, size: 20),
                        tooltip: 'Send to WhatsApp',
                        onPressed: () => _sendToWhatsApp(styledText),
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
  }

  Widget _buildHistoryTab(ThemeData theme) {
    return ValueListenableBuilder(
      valueListenable: HiveStorageService.history.listenable(),
      builder: (context, Box box, _) {
        if (box.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_toggle_off, size: 56.sp, color: Colors.grey),
                SizedBox(height: 12.h),
                Text('No message history yet', style: TextStyle(fontSize: 16.sp, color: Colors.grey)),
                SizedBox(height: 6.h),
                Text(
                  'Messages sent via Chatflow will appear here.',
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        final items = box.toMap().entries.toList().reversed.toList();

        return ListView.builder(
          padding: EdgeInsets.all(12.w),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final entry = items[index];
            final item = entry.value as Map;
            final phone = item['phone'] ?? '';
            final msg = item['message'] ?? '';
            final time = item['timestamp']?.toString().split('T').first ?? '';

            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.withOpacity(0.15),
                  child: const Icon(Icons.chat, color: Colors.green),
                ),
                title: Text('+$phone', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (msg.isNotEmpty) Text(msg, maxLines: 2, overflow: TextOverflow.ellipsis),
                    Text(time, style: TextStyle(fontSize: 11.sp, color: Colors.grey)),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.replay, color: Colors.green),
                  tooltip: 'Resend',
                  onPressed: () => _sendToWhatsApp(msg, phone),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
