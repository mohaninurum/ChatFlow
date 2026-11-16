import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

class ToolsScreen extends ConsumerWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            subtitle: 'Message any number on WhatsApp without saving contact',
            icon: Icons.chat_bubble_outline,
            color: const Color(0xFF25D366),
            route: 'directChat',
          ),
          _buildToolTile(
            context: context,
            title: 'Status Saver',
            subtitle: 'View, save and share photo & video statuses',
            icon: Icons.download_rounded,
            color: Colors.blue,
            route: 'statusSaver',
          ),
          _buildToolTile(
            context: context,
            title: 'WhatsApp Link Generator',
            subtitle: 'Generate wa.me links and downloadable QR codes',
            icon: Icons.qr_code_2_outlined,
            color: Colors.blueAccent,
            route: 'linkGenerator',
          ),
          SizedBox(height: 16.h),

          _buildCategoryHeader(context, 'TEXT & MEDIA UTILITIES'),
          _buildToolTile(
            context: context,
            title: 'Image to Text (OCR)',
            subtitle: 'Scan camera or gallery images to extract text',
            icon: Icons.document_scanner_outlined,
            color: Colors.cyan[700]!,
            route: 'ocr',
          ),
          _buildToolTile(
            context: context,
            title: 'Text Formatter & Fonts',
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
      margin: EdgeInsets.only(bottom: 10.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
        leading: Container(
          padding: EdgeInsets.all(10.w),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Icon(icon, color: color, size: 22.sp),
        ),
        title: Text(
          title,
          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: EdgeInsets.only(top: 2.h),
          child: Text(
            subtitle,
            style: TextStyle(fontSize: 11.5.sp, color: Colors.grey[600]),
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        onTap: () => context.pushNamed(route),
      ),
    );
  }
}
