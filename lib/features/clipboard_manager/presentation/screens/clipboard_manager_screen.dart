import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/storage/hive_storage_service.dart';

class ClipboardManagerScreen extends ConsumerStatefulWidget {
  const ClipboardManagerScreen({super.key});

  @override
  ConsumerState<ClipboardManagerScreen> createState() => _ClipboardManagerScreenState();
}

class _ClipboardManagerScreenState extends ConsumerState<ClipboardManagerScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  bool _showFavoritesOnly = false;

  final List<String> _categories = [
    'All',
    'General',
    'Addresses',
    'Work',
    'Greetings',
    'Payment',
  ];

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      _showSnippetEditorDialog(initialContent: data.text!.trim());
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clipboard is currently empty')),
        );
      }
    }
  }

  Future<void> _showSnippetEditorDialog({String? initialContent, dynamic key, Map? existing}) async {
    final titleCtrl = TextEditingController(text: existing?['title'] ?? '');
    final contentCtrl = TextEditingController(text: existing?['content'] ?? (initialContent ?? ''));
    String category = existing?['category'] ?? 'General';
    bool isFavorite = existing?['isFavorite'] == true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          title: Text(existing != null ? 'Edit Snippet' : 'Save Clipboard Snippet'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title / Label', hintText: 'e.g. Office Address, UPI ID'),
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
                  controller: contentCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Snippet Content',
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
                    const Text('Add to Favorites'),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final content = contentCtrl.text.trim();
                final title = titleCtrl.text.trim().isEmpty ? 'Quick Note' : titleCtrl.text.trim();
                if (content.isEmpty) return;

                final data = {
                  'id': existing?['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  'title': title,
                  'content': content,
                  'category': category,
                  'isFavorite': isFavorite,
                  'updatedAt': DateTime.now().toIso8601String(),
                };

                if (key != null) {
                  await HiveStorageService.clipboard.put(key, data);
                } else {
                  await HiveStorageService.clipboard.add(data);
                }

                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save Snippet'),
            ),
          ],
        ),
      ),
    );
  }

  void _copySnippet(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Snippet copied to clipboard!')),
    );
  }

  Future<void> _shareToWhatsApp(String text) async {
    final encoded = Uri.encodeComponent(text);
    final url = Uri.parse('whatsapp://send?text=$encoded');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _copySnippet(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clipboard Manager'),
        actions: [
          IconButton(
            icon: Icon(
              _showFavoritesOnly ? Icons.star : Icons.star_border,
              color: _showFavoritesOnly ? Colors.amber : null,
            ),
            tooltip: _showFavoritesOnly ? 'Show All' : 'Show Favorites Only',
            onPressed: () => setState(() => _showFavoritesOnly = !_showFavoritesOnly),
          ),
          IconButton(
            icon: const Icon(Icons.paste),
            tooltip: 'Paste from Device Clipboard',
            onPressed: _pasteFromClipboard,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSnippetEditorDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Snippet'),
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
                hintText: 'Search snippets...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r)),
                contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            ),
          ),

          // Category Chips
          SizedBox(
            height: 40.h,
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

          // Snippets List
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: HiveStorageService.clipboard.listenable(),
              builder: (context, Box box, _) {
                final allEntries = box.toMap().entries.toList();

                final filtered = allEntries.where((entry) {
                  final item = entry.value as Map;
                  final title = (item['title'] ?? '').toString().toLowerCase();
                  final content = (item['content'] ?? '').toString().toLowerCase();
                  final cat = item['category'] ?? 'General';
                  final isFav = item['isFavorite'] == true;

                  if (_selectedCategory != 'All' && cat != _selectedCategory) return false;
                  if (_showFavoritesOnly && !isFav) return false;
                  if (_searchQuery.isNotEmpty && !title.contains(_searchQuery) && !content.contains(_searchQuery)) {
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
                          Icon(Icons.content_paste_off, size: 56.sp, color: Colors.grey),
                          SizedBox(height: 12.h),
                          Text('No snippets saved yet', style: TextStyle(color: Colors.grey, fontSize: 16.sp)),
                          SizedBox(height: 4.h),
                          const Text(
                            'Tap the top Paste icon to quickly save from your clipboard, or add one manually.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
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
                    final content = item['content'] ?? '';
                    final cat = item['category'] ?? 'General';
                    final isFav = item['isFavorite'] == true;

                    return Card(
                      elevation: 1.2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
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
                              content,
                              style: TextStyle(fontSize: 13.5.sp, color: isDark ? Colors.grey[300] : Colors.grey[800]),
                            ),
                            SizedBox(height: 8.h),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  tooltip: 'Edit',
                                  onPressed: () => _showSnippetEditorDialog(key: key, existing: item),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                  tooltip: 'Delete',
                                  onPressed: () => box.delete(key),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 18),
                                  tooltip: 'Copy',
                                  onPressed: () => _copySnippet(content),
                                ),
                                SizedBox(width: 4.w),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF25D366),
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                                  ),
                                  icon: const Icon(Icons.send, size: 14),
                                  label: const Text('Send'),
                                  onPressed: () => _shareToWhatsApp(content),
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
