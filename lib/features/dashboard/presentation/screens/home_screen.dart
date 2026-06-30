import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.storage,
      Permission.photos,
      Permission.videos,
      Permission.notification,
    ].request();
    // Manage external storage may be required for Android 11+
    if (await Permission.manageExternalStorage.isDenied) {
      await Permission.manageExternalStorage.request();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Chatflow', style: TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined), // Fallback icon as lucide is not installed
                onPressed: () => context.pushNamed('settings'),
              ),
            ],
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildWelcomeCard(colorScheme),
                SizedBox(height: 24.h),
                Text('Quick Actions', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                SizedBox(height: 16.h),
                _buildFeaturesGrid(context),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enhance your\nMessaging Experience',
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.flash_on, color: Colors.white, size: 16),
                SizedBox(width: 4.w),
                const Text('All tools active', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesGrid(BuildContext context) {
    final features = [
      {
        'title': 'Direct Chat',
        'subtitle': 'Message without saving',
        'icon': Icons.chat_bubble_outline,
        'route': 'directChat',
        'color': Colors.blue,
      },
      {
        'title': 'Status Saver',
        'subtitle': 'Save videos & images',
        'icon': Icons.download_outlined,
        'route': 'statusSaver',
        'color': Colors.green,
      },
      {
        'title': 'Recover Deleted Msgs',
        'subtitle': 'Catch deleted messages',
        'icon': Icons.delete_sweep,
        'route': 'notificationHistory',
        'color': Colors.purple,
      },
      {
        'title': 'Media Cleaner',
        'subtitle': 'Clean junk & duplicates',
        'icon': Icons.cleaning_services_outlined,
        'route': 'mediaCleaner',
        'color': Colors.orange,
      },
      {
        'title': 'QR Tools',
        'subtitle': 'Scan & Generate QR',
        'icon': Icons.qr_code_scanner,
        'route': 'qrTools',
        'color': Colors.teal,
      },
      {
        'title': 'Text Tools',
        'subtitle': 'Stylish text & repeater',
        'icon': Icons.text_fields,
        'route': 'textTools',
        'color': Colors.indigo,
      },
      {
        'title': 'File Manager',
        'subtitle': 'Manage media files',
        'icon': Icons.folder_open_outlined,
        'route': 'fileManager',
        'color': Colors.amber,
      },
      {
        'title': 'Status Creator',
        'subtitle': 'Create text & image status',
        'icon': Icons.brush_outlined,
        'route': 'statusCreator',
        'color': Colors.pink,
      },
      {
        'title': 'Chat Utilities',
        'subtitle': 'Quick replies & reminders',
        'icon': Icons.handyman_outlined,
        'route': 'chatUtilities',
        'color': Colors.cyan,
      },
      {
        'title': 'Backup',
        'subtitle': 'Backup & Restore settings',
        'icon': Icons.backup_outlined,
        'route': 'backup',
        'color': Colors.brown,
      },
      {
        'title': 'Settings',
        'subtitle': 'App preferences & lock',
        'icon': Icons.settings_outlined,
        'route': 'settings',
        'color': Colors.grey,
      },
      {
        'title': 'Profile',
        'subtitle': 'User info & about',
        'icon': Icons.person_outline,
        'route': 'profile',
        'color': Colors.deepOrange,
      },
    ];

    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16.w,
        mainAxisSpacing: 16.h,
        childAspectRatio: 0.85,
      ),
      itemCount: features.length,
      itemBuilder: (context, index) {
        final feature = features[index];
        return _FeatureCard(
          title: feature['title'] as String,
          subtitle: feature['subtitle'] as String,
          icon: feature['icon'] as IconData,
          color: feature['color'] as Color,
          onTap: () => context.pushNamed(feature['route'] as String),
        );
      },
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Material(
      color: theme.cardTheme.color,
      borderRadius: BorderRadius.circular(24.r),
      elevation: theme.cardTheme.elevation ?? 2,
      shadowColor: theme.cardTheme.shadowColor,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24.r),
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28.sp),
              ),
              const Spacer(),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
