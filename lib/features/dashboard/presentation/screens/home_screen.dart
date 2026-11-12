import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/storage/hive_storage_service.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning 👋';
    if (hour < 17) return 'Good afternoon ☀️';
    return 'Good evening 🌙';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Premium Greeting Header AppBar
          SliverAppBar.large(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getGreeting(),
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.normal,
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                ),
                Text(
                  'Chatflow Companion',
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.analytics_outlined),
                tooltip: 'Dashboard & Stats',
                onPressed: () => context.pushNamed('profile'),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Settings',
                onPressed: () => context.pushNamed('settings'),
              ),
              SizedBox(width: 8.w),
            ],
          ),

          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Welcome Hero Card
                _buildHeroCard(context, colorScheme),
                SizedBox(height: 24.h),

                // Quick Actions Header (clean, without View All button)
                Text(
                  'Quick Actions',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp,
                  ),
                ),
                SizedBox(height: 12.h),
                _buildQuickActionsRow(context),
                SizedBox(height: 24.h),

                // Core Tools Grid
                Text(
                  'Explore Companion Tools',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp,
                  ),
                ),
                SizedBox(height: 12.h),
                _buildFeaturesGrid(context),
                SizedBox(height: 24.h),

                // Recent Activities Header & List
                Text(
                  'Recent Activity',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp,
                  ),
                ),
                SizedBox(height: 10.h),
                _buildRecentActivitySection(),
                SizedBox(height: 32.h),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(22.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF25D366), Color(0xFF128C7E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF25D366).withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      '100% Offline & Private',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                onPressed: () => context.pushNamed('directChat'),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Text(
            'Message Directly\nWithout Saving Contacts',
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.25,
            ),
          ),
          SizedBox(height: 14.h),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF128C7E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
              elevation: 0,
            ),
            onPressed: () => context.pushNamed('directChat'),
            icon: const Icon(Icons.chat, size: 16),
            label: const Text('Start Direct Chat', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsRow(BuildContext context) {
    final actions = [
      {'title': 'Direct Chat', 'icon': Icons.send_rounded, 'color': const Color(0xFF25D366), 'route': 'directChat'},
      {'title': 'Status Saver', 'icon': Icons.download_rounded, 'color': Colors.blue, 'route': 'statusSaver'},
      {'title': 'Deleted Msg', 'icon': Icons.mark_chat_unread_outlined, 'color': Colors.redAccent, 'route': 'deletedMessages'},
      {'title': 'Link Maker', 'icon': Icons.qr_code, 'color': Colors.amber[800]!, 'route': 'linkGenerator'},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: actions.map((a) {
        final color = a['color'] as Color;
        return Expanded(
          child: GestureDetector(
            onTap: () => context.pushNamed(a['route'] as String),
            child: Column(
              children: [
                Container(
                  width: 54.w,
                  height: 54.w,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(a['icon'] as IconData, color: color, size: 24.sp),
                ),
                SizedBox(height: 6.h),
                Text(
                  a['title'] as String,
                  style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFeaturesGrid(BuildContext context) {
    final features = [
      {
        'title': 'Message Reminders',
        'subtitle': 'Schedule upcoming chats',
        'icon': Icons.alarm,
        'route': 'reminders',
        'color': Colors.deepOrange,
      },
      {
        'title': 'Image to Text',
        'subtitle': 'Extract text from documents',
        'icon': Icons.document_scanner_outlined,
        'route': 'ocr',
        'color': Colors.cyan[700]!,
      },
      {
        'title': 'Text Formatter',
        'subtitle': 'Bold, italics, & bubble fonts',
        'icon': Icons.text_format,
        'route': 'textFormatter',
        'color': Colors.pinkAccent,
      },
      {
        'title': 'Link Generator',
        'subtitle': 'Create wa.me links & QR codes',
        'icon': Icons.qr_code_2_rounded,
        'route': 'linkGenerator',
        'color': Colors.blueAccent,
      },
    ];

    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12.w,
        mainAxisSpacing: 12.h,
        childAspectRatio: 1.25,
      ),
      itemCount: features.length,
      itemBuilder: (context, index) {
        final f = features[index];
        final color = f['color'] as Color;

        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.r)),
          child: InkWell(
            onTap: () => context.pushNamed(f['route'] as String),
            borderRadius: BorderRadius.circular(18.r),
            child: Padding(
              padding: EdgeInsets.all(14.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(f['icon'] as IconData, color: color, size: 20.sp),
                  ),
                  const Spacer(),
                  Text(
                    f['title'] as String,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5.sp),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    f['subtitle'] as String,
                    style: TextStyle(fontSize: 10.5.sp, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentActivitySection() {
    return ValueListenableBuilder(
      valueListenable: HiveStorageService.history.listenable(),
      builder: (context, Box box, _) {
        if (box.isEmpty) {
          return Container(
            padding: EdgeInsets.all(20.w),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: const Text('No recent activity recorded yet.', style: TextStyle(color: Colors.grey)),
          );
        }

        final recent = box.values.toList().reversed.take(4).toList();

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: recent.length,
          separatorBuilder: (context, index) => SizedBox(height: 8.h),
          itemBuilder: (context, index) {
            final item = recent[index] as Map;
            final phone = item['phone']?.toString() ?? 'Direct Chat';
            final msg = item['message']?.toString() ?? '';
            final type = item['type']?.toString() ?? 'Chat';

            return Card(
              elevation: 0.8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
              child: ListTile(
                dense: true,
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.12),
                  child: const Icon(Icons.history, color: Color(0xFF25D366), size: 18),
                ),
                title: Text('$type: $phone', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: msg.isNotEmpty ? Text(msg, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
              ),
            );
          },
        );
      },
    );
  }
}
