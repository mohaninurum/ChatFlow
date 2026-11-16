import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

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
      {'title': 'Text Format', 'icon': Icons.text_format_rounded, 'color': Colors.pinkAccent, 'route': 'textFormatter'},
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
        'title': 'Direct Chat',
        'subtitle': 'Message without saving number',
        'icon': Icons.chat_bubble_outline,
        'route': 'directChat',
        'color': const Color(0xFF25D366),
      },
      {
        'title': 'Status Saver',
        'subtitle': 'Save photo & video status',
        'icon': Icons.download_rounded,
        'route': 'statusSaver',
        'color': Colors.blue,
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
        'subtitle': 'Bold, italics, & stylish fonts',
        'icon': Icons.text_format,
        'route': 'textFormatter',
        'color': Colors.pinkAccent,
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
}
