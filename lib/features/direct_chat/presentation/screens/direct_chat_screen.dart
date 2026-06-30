import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

class DirectChatScreen extends ConsumerStatefulWidget {
  const DirectChatScreen({super.key});

  @override
  ConsumerState<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends ConsumerState<DirectChatScreen> {
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();
  String _countryCode = '+91'; // Default

  Future<void> _openWhatsApp() async {
    final phone = _phoneController.text.trim();
    final message = _messageController.text.trim();
    if (phone.isEmpty) return;

    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final cleanCode = _countryCode.replaceAll('+', '');
    
    final url = Uri.parse('https://wa.me/$cleanCode$cleanPhone?text=${Uri.encodeComponent(message)}');
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch WhatsApp. Is it installed?')),
        );
      }
    }
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
              'Message anyone on WhatsApp without saving their contact.',
              style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
            ),
            SizedBox(height: 32.h),
            Row(
              children: [
                SizedBox(
                  width: 80.w,
                  child: TextField(
                    controller: TextEditingController(text: _countryCode),
                    decoration: InputDecoration(
                      labelText: 'Code',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r)),
                      filled: true,
                    ),
                    keyboardType: TextInputType.phone,
                    onChanged: (val) => _countryCode = val,
                  ),
                ),
                SizedBox(width: 16.w),
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
            TextField(
              controller: _messageController,
              decoration: InputDecoration(
                labelText: 'Message (Optional)',
                hintText: 'Type something...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r)),
                filled: true,
                alignLabelWithHint: true,
              ),
              maxLines: 4,
            ),
            SizedBox(height: 32.h),
            ElevatedButton(
              onPressed: _openWhatsApp,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
                elevation: 0,
              ),
              child: Text(
                'Open WhatsApp',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
