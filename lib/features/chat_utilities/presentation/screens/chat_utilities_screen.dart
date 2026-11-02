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
  String _searchQuery = '';
  bool _showFavoritesOnly = false;

  final List<String> _categories = [
    'All',
    'Business',
    'Personal',
    'Driving',
    'Customer Support',
    'Custom',
  ];

  Future<void> _handleUseTemplate(Map item, dynamic key, {required bool isDirectSend}) async {
    // 1. Increment usage stats
    final currentCount = (item['useCount'] ?? 0) as int;
    final updated = Map<String, dynamic>.from(item);
    updated['useCount'] = currentCount + 1;
    updated['lastUsed'] = DateTime.now().toIso8601String();
    await HiveStorageService.templates.put(key, updated);

    final rawMessage = item['message']?.toString() ?? '';

    // Check if contains variables
    final hasName = rawMessage.contains('{name}');
    final hasOrderId = rawMessage.contains('{order_id}');
    final hasAmount = rawMessage.contains('{amount}');

    if (hasName || hasOrderId || hasAmount) {
      _showVariableFillerDialog(
        rawMessage: rawMessage,
        title: item['title']?.toString() ?? 'Template',
        onFilled: (filledText) {
          if (isDirectSend) {
            _showSendToWhatsAppSheet(filledText);
          } else {
            _copyToClipboard(filledText);
          }
        },
      );
    } else {
      if (isDirectSend) {
        _showSendToWhatsAppSheet(rawMessage);
      } else {
        _copyToClipboard(rawMessage);
      }
    }
  }

  void _showVariableFillerDialog({
    required String rawMessage,
    required String title,
    required Function(String filled) onFilled,
  }) {
    final nameCtrl = TextEditingController();
    final orderCtrl = TextEditingController();
    final amountCtrl = TextEditingController();

    final hasName = rawMessage.contains('{name}');
    final hasOrderId = rawMessage.contains('{order_id}');
    final hasAmount = rawMessage.contains('{amount}');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Text('Fill Template: $title'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Customize variables before sharing:',
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[700]),
              ),
              SizedBox(height: 12.h),
              if (hasName) ...[
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name {name}', hintText: 'e.g. John Doe'),
                ),
                SizedBox(height: 10.h),
              ],
              if (hasOrderId) ...[
                TextField(
                  controller: orderCtrl,
                  decoration: const InputDecoration(labelText: 'Order ID {order_id}', hintText: 'e.g. 98452'),
                ),
                SizedBox(height: 10.h),
              ],
              if (hasAmount) ...[
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount {amount}', hintText: 'e.g. 500'),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onFilled(rawMessage);
            },
            child: const Text('Use Raw'),
          ),
          ElevatedButton(
            onPressed: () {
              String filled = rawMessage;
              if (hasName) filled = filled.replaceAll('{name}', nameCtrl.text.trim().isEmpty ? 'Valued Customer' : nameCtrl.text.trim());
              if (hasOrderId) filled = filled.replaceAll('{order_id}', orderCtrl.text.trim().isEmpty ? '1001' : orderCtrl.text.trim());
              if (hasAmount) filled = filled.replaceAll('{amount}', amountCtrl.text.trim().isEmpty ? '0' : amountCtrl.text.trim());

              Navigator.pop(ctx);
              onFilled(filled);
            },
            child: const Text('Proceed'),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Template copied to clipboard!')),
    );
  }

  Future<void> _showSendToWhatsAppSheet(String message) async {
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
                  'Send via WhatsApp',
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            SizedBox(height: 10.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.green.withOpacity(0.2)),
              ),
              child: Text(
                message,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.sp),
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
                      labelText: 'Recipient Phone',
                      hintText: 'Enter phone number',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                      prefixIcon: const Icon(Icons.phone_outlined),
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
                    const SnackBar(content: Text('Please enter recipient phone number')),
                  );
                  return;
                }

                final fullNumber = '$code$phone';
                final encodedMsg = Uri.encodeComponent(message);
                final url = Uri.parse('https://wa.me/$fullNumber?text=$encodedMsg');

                // Save to history
                await HiveStorageService.logDirectChat(
                  phone: fullNumber,
                  message: message,
                  isBusiness: false,
                );

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
              label: Text('Open in WhatsApp', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
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

  Future<void> _showTemplateEditorDialog({dynamic key, Map? existing}) async {
    final titleController = TextEditingController(text: existing?['title'] ?? '');
    final msgController = TextEditingController(text: existing?['message'] ?? '');
    String category = existing?['category'] ?? 'Custom';
    bool isFavorite = existing?['isFavorite'] == true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          title: Text(existing != null ? 'Edit Template' : 'New Template'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                  decoration: const InputDecoration(
                    labelText: 'Message Body',
                    hintText: 'Tip: Use {name}, {order_id}, {amount} for variables',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Checkbox(
                      value: isFavorite,
                      onChanged: (val) => setDialogState(() => isFavorite = val ?? false),
                    ),
                    const Text('Mark as Favorite'),
                  ],
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

                final data = {
                  'id': existing?['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  'title': title,
                  'message': msg,
                  'category': category,
                  'isFavorite': isFavorite,
                  'useCount': existing?['useCount'] ?? 0,
                  'lastUsed': existing?['lastUsed'],
                };

                if (key != null) {
                  await HiveStorageService.templates.put(key, data);
                } else {
                  await HiveStorageService.templates.add(data);
                }

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
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat Utilities'),
        actions: [
          IconButton(
            icon: Icon(
              _showFavoritesOnly ? Icons.star : Icons.star_border,
              color: _showFavoritesOnly ? Colors.amber : null,
            ),
            tooltip: _showFavoritesOnly ? 'Show All' : 'Show Favorites Only',
            onPressed: () => setState(() => _showFavoritesOnly = !_showFavoritesOnly),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTemplateEditorDialog(),
        icon: const Icon(Icons.add),
        label: const Text('New Template'),
        backgroundColor: const Color(0xFF25D366),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search templates by title or text...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r)),
                contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            ),
          ),

          // Categories horizontal scroll
          SizedBox(
            height: 40.h,
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => SizedBox(width: 8.w),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == cat;
                return ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _selectedCategory = cat),
                );
              },
            ),
          ),
          SizedBox(height: 8.h),

          // Template List
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: HiveStorageService.templates.listenable(),
              builder: (context, Box box, _) {
                final allEntries = box.toMap().entries.toList();

                // Filter
                final filtered = allEntries.where((entry) {
                  final item = entry.value as Map;
                  final title = (item['title'] ?? '').toString().toLowerCase();
                  final msg = (item['message'] ?? '').toString().toLowerCase();
                  final cat = item['category'] ?? 'Custom';
                  final isFav = item['isFavorite'] == true;

                  if (_selectedCategory != 'All' && cat != _selectedCategory) return false;
                  if (_showFavoritesOnly && !isFav) return false;
                  if (_searchQuery.isNotEmpty && !title.contains(_searchQuery) && !msg.contains(_searchQuery)) {
                    return false;
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.w),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 56.sp, color: Colors.grey),
                          SizedBox(height: 12.h),
                          Text('No templates found', style: TextStyle(color: Colors.grey, fontSize: 16.sp)),
                          SizedBox(height: 4.h),
                          const Text('Tap "New Template" to create a custom quick reply.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 80.h, top: 4.h),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => SizedBox(height: 10.h),
                  itemBuilder: (context, index) {
                    final entry = filtered[index];
                    final item = entry.value as Map;
                    final key = entry.key;
                    final title = item['title'] ?? '';
                    final msg = item['message'] ?? '';
                    final cat = item['category'] ?? 'Custom';
                    final isFav = item['isFavorite'] == true;
                    final useCount = item['useCount'] ?? 0;

                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                      elevation: 1.5,
                      child: Padding(
                        padding: EdgeInsets.all(14.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp),
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Text(
                                    cat,
                                    style: TextStyle(fontSize: 10.sp, color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                SizedBox(width: 4.w),
                                IconButton(
                                  icon: Icon(
                                    isFav ? Icons.star : Icons.star_border,
                                    color: isFav ? Colors.amber : Colors.grey,
                                    size: 20,
                                  ),
                                  onPressed: () async {
                                    final updated = Map<String, dynamic>.from(item);
                                    updated['isFavorite'] = !isFav;
                                    await box.put(key, updated);
                                  },
                                ),
                              ],
                            ),
                            SizedBox(height: 6.h),
                            Text(
                              msg,
                              style: TextStyle(fontSize: 13.5.sp, color: isDark ? Colors.grey[300] : Colors.grey[800]),
                            ),
                            SizedBox(height: 10.h),
                            Row(
                              children: [
                                if (useCount > 0)
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(10.r),
                                    ),
                                    child: Text(
                                      'Used $useCount×',
                                      style: TextStyle(fontSize: 10.sp, color: Colors.grey[600]),
                                    ),
                                  ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  tooltip: 'Edit',
                                  onPressed: () => _showTemplateEditorDialog(key: key, existing: item),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                  tooltip: 'Delete',
                                  onPressed: () => box.delete(key),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 18),
                                  tooltip: 'Copy',
                                  onPressed: () => _handleUseTemplate(item, key, isDirectSend: false),
                                ),
                                SizedBox(width: 4.w),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF25D366),
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                                  ),
                                  onPressed: () => _handleUseTemplate(item, key, isDirectSend: true),
                                  icon: const Icon(Icons.send, size: 14),
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
