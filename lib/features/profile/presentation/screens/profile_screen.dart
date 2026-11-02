import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/storage/hive_storage_service.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final historyCount = HiveStorageService.history.length;
    final templateCount = HiveStorageService.templates.length;
    final deletedCount = HiveStorageService.deletedMessages.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile & About')),
      body: ListView(
        children: [
          SizedBox(height: 24.h),
          Center(
            child: CircleAvatar(
              radius: 44.r,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
              child: Icon(Icons.person, size: 50.sp, color: theme.colorScheme.primary),
            ),
          ),
          SizedBox(height: 12.h),
          Center(
            child: Text(
              'ChatFlow User',
              style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold),
            ),
          ),
          Center(
            child: Text(
              'WhatsApp Companion Toolkit',
              style: TextStyle(color: Colors.grey, fontSize: 13.sp),
            ),
          ),
          SizedBox(height: 24.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                _buildStatCard(theme, '$historyCount', 'Direct Chats'),
                SizedBox(width: 10.w),
                _buildStatCard(theme, '$templateCount', 'Templates'),
                SizedBox(width: 10.w),
                _buildStatCard(theme, '$deletedCount', 'Msgs Logged'),
              ],
            ),
          ),
          SizedBox(height: 24.h),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            subtitle: const Text('All your data stays 100% offline on your device'),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Privacy Policy'),
                  content: const Text(
                    'ChatFlow is an offline companion utility. None of your WhatsApp chats, contacts, or media are uploaded to any external server. Everything stays encrypted and stored locally on your device.',
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Got it')),
                  ],
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About Developer'),
            subtitle: const Text('Chatflow Suite v1.0.0'),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(ThemeData theme, String value, String label) {
    return Expanded(
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        elevation: 1.5,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 14.h),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                label,
                style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
