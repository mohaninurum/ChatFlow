import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

class ToolsScreen extends ConsumerWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chatflow Tools'),
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        children: [
          _buildCategoryHeader(context, 'COMMUNICATION & CHAT'),
          _buildToolTile(
            context: context,
            title: 'Direct Chat',
            subtitle: 'Message any number on WhatsApp without saving',
            icon: Icons.chat_bubble_outline,
            color: const Color(0xFF25D366),
            route: 'directChat',
          ),
          _buildToolTile(
            context: context,
            title: 'WhatsApp Link Generator',
            subtitle: 'Generate wa.me links and downloadable QR codes',
            icon: Icons.qr_code_2_outlined,
            color: Colors.blueAccent,
            route: 'linkGenerator',
          ),
          _buildToolTile(
            context: context,
            title: 'Message Reminders',
            subtitle: 'Schedule upcoming WhatsApp messages with 1-tap send',
            icon: Icons.alarm_on_outlined,
            color: Colors.deepOrange,
            route: 'reminders',
          ),
          _buildToolTile(
            context: context,
            title: 'Quick Reply Templates',
            subtitle: 'Ready-to-use business, driving, & support templates',
            icon: Icons.quickreply_outlined,
            color: Colors.purple,
            route: 'chatUtilities',
          ),
          SizedBox(height: 16.h),

          _buildCategoryHeader(context, 'PRIVACY & SECURITY'),
          _buildToolTile(
            context: context,
            title: 'Recover Deleted Messages',
            subtitle: 'Archive incoming notifications & view deleted texts',
            icon: Icons.mark_chat_unread_outlined,
            color: Colors.redAccent,
            route: 'deletedMessages',
          ),
          _buildToolTile(
            context: context,
            title: 'Private Vault',
            subtitle: 'Encrypted storage with 4-digit PIN for private notes',
            icon: Icons.shield_outlined,
            color: Colors.teal,
            route: 'privateVault',
          ),
          _buildToolTile(
            context: context,
            title: 'Clipboard Manager',
            subtitle: 'Save frequent snippets and addresses safely',
            icon: Icons.assignment_outlined,
            color: Colors.indigo,
            route: 'clipboardManager',
          ),
          SizedBox(height: 16.h),

          _buildCategoryHeader(context, 'AI & PRODUCTIVITY SUITE'),
          _buildToolTile(
            context: context,
            title: 'AI Reply Assistant',
            subtitle: 'Generate professional, friendly, or business replies',
            icon: Icons.auto_awesome,
            color: Colors.amber[800]!,
            route: 'aiAssistant',
          ),
          _buildToolTile(
            context: context,
            title: 'AI Message Translator',
            subtitle: 'Translate Hindi <-> English in formal & casual styles',
            icon: Icons.translate,
            color: Colors.cyan,
            route: 'aiTranslator',
          ),
          _buildToolTile(
            context: context,
            title: 'Image to Text (OCR)',
            subtitle: 'Scan camera or gallery images to extract text',
            icon: Icons.document_scanner_outlined,
            color: Colors.green[700]!,
            route: 'ocr',
          ),
          _buildToolTile(
            context: context,
            title: 'Text Formatter & Unicode Fonts',
            subtitle: 'Bold, italics, stylish cursive & bubble fonts',
            icon: Icons.text_format,
            color: Colors.pinkAccent,
            route: 'textFormatter',
          ),
          SizedBox(height: 32.h),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(BuildContext context, String title) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 8.h, 4.w, 8.h),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildToolTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String route,
  }) {
    return Card(
      elevation: 1,
      margin: EdgeInsets.only(bottom: 8.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
        leading: Container(
          padding: EdgeInsets.all(10.w),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Icon(icon, color: color, size: 24.sp),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 11.5.sp, color: Colors.grey[600]),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        onTap: () => context.pushNamed(route),
      ),
    );
  }
}
