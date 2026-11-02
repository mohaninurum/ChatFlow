import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/storage/hive_storage_service.dart';

class ChatUtilitiesScreen extends ConsumerStatefulWidget {
  const ChatUtilitiesScreen({super.key});

  @override
  ConsumerState<ChatUtilitiesScreen> createState() => _ChatUtilitiesScreenState();
}

class _ChatUtilitiesScreenState extends ConsumerState<ChatUtilitiesScreen> {
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Quick Replies', 'Business', 'Personal', 'Custom'];

  Future<void> _sendToWhatsApp(String message) async {
    final phoneController = TextEditingController();
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
                  'Send Template to WhatsApp',
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                )
              ],
            ),
            SizedBox(height: 12.h),
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

                // Save to history
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
              label: Text('Open & Send in WhatsApp', style: TextStyle(fontSize: 15.sp)),
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
          title: const Text('New Quick Reply'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. Greeting, Address...'),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat Utilities'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTemplateDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Reply'),
      ),
      body: Column(
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
          SizedBox(height: 10.h),
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
      ),
    );
  }
}
