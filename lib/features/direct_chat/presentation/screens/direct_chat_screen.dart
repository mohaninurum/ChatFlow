import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/storage/hive_storage_service.dart';

class DirectChatScreen extends ConsumerStatefulWidget {
  const DirectChatScreen({super.key});

  @override
  ConsumerState<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends ConsumerState<DirectChatScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController(text: '+91');
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _openWhatsApp({bool isBusiness = false}) async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a phone number')),
      );
      return;
    }

    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final cleanCode = _codeController.text.replaceAll('+', '').trim();
    final fullNumber = '$cleanCode$cleanPhone';
    final message = _messageController.text.trim();

    // Log to history
    await HiveStorageService.history.add({
      'phone': fullNumber,
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
    });

    final String encodedMsg = Uri.encodeComponent(message);
    final String urlStr = message.isNotEmpty
        ? 'https://wa.me/$fullNumber?text=$encodedMsg'
        : 'https://wa.me/$fullNumber';

    final url = Uri.parse(urlStr);

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch WhatsApp. Is it installed?')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showTemplatePicker() {
    final templates = HiveStorageService.templates.values.toList();
    if (templates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No templates saved yet. Add one in Message Manager.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) => ListView.separated(
        padding: EdgeInsets.all(16.w),
        itemCount: templates.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (context, index) {
          final t = templates[index] as Map;
          final title = t['title'] ?? '';
          final msg = t['message'] ?? '';
          final cat = t['category'] ?? '';

          return ListTile(
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(msg, maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: Chip(
              label: Text(cat, style: TextStyle(fontSize: 10.sp)),
              visualDensity: VisualDensity.compact,
            ),
            onTap: () {
              setState(() {
                _messageController.text = msg;
              });
              Navigator.pop(ctx);
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Direct Chat'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Message anyone on WhatsApp without saving their contact number.',
              style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
            ),
            SizedBox(height: 24.h),
            Row(
              children: [
                SizedBox(
                  width: 80.w,
                  child: TextField(
                    controller: _codeController,
                    decoration: InputDecoration(
                      labelText: 'Code',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r)),
                      filled: true,
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      hintText: 'Enter mobile number',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r)),
                      filled: true,
                      prefixIcon: const Icon(Icons.phone_outlined),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Message (Optional)',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                TextButton.icon(
                  onPressed: _showTemplatePicker,
                  icon: const Icon(Icons.bookmark_border, size: 18),
                  label: const Text('Use Template'),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            TextField(
              controller: _messageController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Type your message or pick from templates...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r)),
                filled: true,
              ),
            ),
            SizedBox(height: 28.h),
            ElevatedButton.icon(
              onPressed: () => _openWhatsApp(),
              icon: const Icon(Icons.send),
              label: Text(
                'Open WhatsApp',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
