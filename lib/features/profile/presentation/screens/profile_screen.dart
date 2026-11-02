import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/storage/hive_storage_service.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String _storageSizeStr = 'Calculating...';

  @override
  void initState() {
    super.initState();
    _calculateStorageUsage();
  }

  Future<void> _calculateStorageUsage() async {
    try {
      int totalBytes = 0;
      final savedDir = Directory('/storage/emulated/0/Pictures/Chatflow');
      if (await savedDir.exists()) {
        final list = savedDir.listSync();
        for (var f in list) {
          if (f is File) totalBytes += await f.length();
        }
      }

      final mb = totalBytes / (1024 * 1024);
      if (mb < 1) {
        setState(() => _storageSizeStr = '${(totalBytes / 1024).toStringAsFixed(1)} KB');
      } else {
        setState(() => _storageSizeStr = '${mb.toStringAsFixed(1)} MB');
      }
    } catch (_) {
      setState(() => _storageSizeStr = '< 1 MB');
    }
  }

  List<int> _calculateWeeklyActivity(List historyItems) {
    final now = DateTime.now();
    final counts = List.filled(7, 0);

    for (var item in historyItems) {
      if (item is Map && item['timestamp'] != null) {
        try {
          final dt = DateTime.parse(item['timestamp'].toString());
          final diffDays = now.difference(dt).inDays;
          if (diffDays >= 0 && diffDays < 7) {
            counts[6 - diffDays]++;
          }
        } catch (_) {}
      }
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final directChatCount = HiveStorageService.history.length;
    final templateCount = HiveStorageService.templates.length;
    final capturedCount = HiveStorageService.deletedMessages.length;
    final deletedRecordsCount = HiveStorageService.deletedMessages.values.where((m) {
      if (m is Map) {
        return m['isDeleted'] == true || (m['message'] ?? '').toString().toLowerCase().contains('deleted');
      }
      return false;
    }).length;
    final downloadedCount = HiveStorageService.statusDownloads.length;

    final allHistory = HiveStorageService.history.values.toList();
    final weeklyActivity = _calculateWeeklyActivity(allHistory);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard & Statistics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {});
              _calculateStorageUsage();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User Header Card
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24.r),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF25D366).withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32.r,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 36.sp, color: const Color(0xFF128C7E)),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chatflow Dashboard',
                          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'WhatsApp Companion Active',
                          style: TextStyle(fontSize: 12.sp, color: Colors.white70),
                        ),
                        SizedBox(height: 6.h),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Text(
                            'Local Offline Mode',
                            style: TextStyle(fontSize: 10.sp, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),

            // Statistics Grid (6 key real database metrics)
            Text(
              'Real Database Statistics',
              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10.h),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10.w,
              mainAxisSpacing: 10.h,
              childAspectRatio: 1.45,
              children: [
                _buildStatBox(
                  icon: Icons.chat_bubble_outline,
                  value: '$directChatCount',
                  label: 'Direct Chats',
                  color: Colors.blue,
                  theme: theme,
                ),
                _buildStatBox(
                  icon: Icons.quickreply_outlined,
                  value: '$templateCount',
                  label: 'Saved Templates',
                  color: Colors.purple,
                  theme: theme,
                ),
                _buildStatBox(
                  icon: Icons.notifications_none_outlined,
                  value: '$capturedCount',
                  label: 'Notifications Logged',
                  color: Colors.teal,
                  theme: theme,
                ),
                _buildStatBox(
                  icon: Icons.mark_chat_unread_outlined,
                  value: '$deletedRecordsCount',
                  label: 'Deleted Records',
                  color: Colors.redAccent,
                  theme: theme,
                ),
                _buildStatBox(
                  icon: Icons.download_done_rounded,
                  value: '$downloadedCount',
                  label: 'Statuses Saved',
                  color: Colors.green,
                  theme: theme,
                ),
                _buildStatBox(
                  icon: Icons.sd_storage_outlined,
                  value: _storageSizeStr,
                  label: 'Media Storage Used',
                  color: Colors.amber[800]!,
                  theme: theme,
                ),
              ],
            ),
            SizedBox(height: 24.h),

            // Weekly Activity Bar Chart
            Text(
              '7-Day Activity Trends',
              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10.h),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
              elevation: 1.5,
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Direct chats & actions logged over the past week',
                      style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                    ),
                    SizedBox(height: 18.h),
                    _buildWeeklyBarChart(weeklyActivity, theme),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24.h),

            // Recent Activity Stream
            Text(
              'Recent Activity Logs',
              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10.h),
            _buildRecentActivityList(),
            SizedBox(height: 32.h),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required ThemeData theme,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(6.w),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 18.sp),
                ),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              label,
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[600], fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyBarChart(List<int> counts, ThemeData theme) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxVal = (counts.reduce((a, b) => a > b ? a : b)).clamp(1, 100);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (i) {
        final count = counts[i];
        final heightFactor = (count / maxVal).clamp(0.15, 1.0);

        return Column(
          children: [
            Text(
              '$count',
              style: TextStyle(fontSize: 10.sp, color: count > 0 ? theme.colorScheme.primary : Colors.grey),
            ),
            SizedBox(height: 4.h),
            Container(
              width: 22.w,
              height: 70.h * heightFactor,
              decoration: BoxDecoration(
                color: count > 0 ? const Color(0xFF25D366) : Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6.r),
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              days[i],
              style: TextStyle(fontSize: 10.sp, color: Colors.grey),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildRecentActivityList() {
    return ValueListenableBuilder(
      valueListenable: HiveStorageService.history.listenable(),
      builder: (context, Box box, _) {
        if (box.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: const Text('No recent activity recorded yet.', style: TextStyle(color: Colors.grey)),
            ),
          );
        }

        final items = box.values.toList().reversed.take(6).toList();

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, __) => SizedBox(height: 8.h),
          itemBuilder: (context, index) {
            final item = items[index] as Map;
            final phone = item['phone']?.toString() ?? 'Direct Chat';
            final msg = item['message']?.toString() ?? '';
            final time = item['timestamp']?.toString().split('T').first ?? '';

            return Card(
              elevation: 0.8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
              child: ListTile(
                dense: true,
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF25D366).withOpacity(0.12),
                  child: const Icon(Icons.send_rounded, color: Color(0xFF25D366), size: 16),
                ),
                title: Text('Message to $phone', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: msg.isNotEmpty ? Text(msg, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
                trailing: Text(time, style: TextStyle(fontSize: 10.sp, color: Colors.grey)),
              ),
            );
          },
        );
      },
    );
  }
}
