import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/storage/hive_storage_service.dart';

class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _showReminderDialog({dynamic key, Map? existing}) async {
    final phoneCtrl = TextEditingController(text: existing?['phone'] ?? '');
    final msgCtrl = TextEditingController(text: existing?['message'] ?? '');
    DateTime selectedDate = existing != null && existing['scheduledTime'] != null
        ? DateTime.parse(existing['scheduledTime'])
        : DateTime.now().add(const Duration(hours: 1));
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(selectedDate);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          title: Text(existing != null ? 'Edit Reminder' : 'New Message Reminder'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Recipient Phone',
                    hintText: 'e.g. +919876543210',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                SizedBox(height: 12.h),
                TextField(
                  controller: msgCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Message Content',
                    hintText: 'What do you want to remind yourself to send?',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'Reminder Date & Time',
                  style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                          style: TextStyle(fontSize: 12.sp),
                        ),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              selectedDate = DateTime(
                                picked.year,
                                picked.month,
                                picked.day,
                                selectedTime.hour,
                                selectedTime.minute,
                              );
                            });
                          }
                        },
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.access_time, size: 16),
                        label: Text(
                          selectedTime.format(context),
                          style: TextStyle(fontSize: 12.sp),
                        ),
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                          );
                          if (picked != null) {
                            setDialogState(() {
                              selectedTime = picked;
                              selectedDate = DateTime(
                                selectedDate.year,
                                selectedDate.month,
                                selectedDate.day,
                                picked.hour,
                                picked.minute,
                              );
                            });
                          }
                        },
                      ),
                    ),
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
                final phone = phoneCtrl.text.trim();
                final msg = msgCtrl.text.trim();
                if (phone.isEmpty || msg.isEmpty) return;

                final scheduled = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );

                final data = {
                  'id': existing?['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  'phone': phone,
                  'message': msg,
                  'scheduledTime': scheduled.toIso8601String(),
                  'isCompleted': existing?['isCompleted'] ?? false,
                  'createdAt': existing?['createdAt'] ?? DateTime.now().toIso8601String(),
                };

                if (key != null) {
                  await HiveStorageService.reminders.put(key, data);
                } else {
                  await HiveStorageService.reminders.add(data);
                }

                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Set Reminder'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openWhatsApp(String phone, String message, dynamic key, Map item) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final encodedMsg = Uri.encodeComponent(message);
    final url = Uri.parse('https://wa.me/$cleanPhone?text=$encodedMsg');

    // Mark as completed
    final updated = Map<String, dynamic>.from(item);
    updated['isCompleted'] = true;
    await HiveStorageService.reminders.put(key, updated);

    // Save to history
    await HiveStorageService.logDirectChat(phone: cleanPhone, message: message, isBusiness: false);

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Message Reminders'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          indicatorColor: theme.colorScheme.primary,
          tabs: const [
            Tab(icon: Icon(Icons.alarm), text: 'Pending'),
            Tab(icon: Icon(Icons.task_alt), text: 'Completed'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showReminderDialog(),
        icon: const Icon(Icons.add_alarm),
        label: const Text('New Reminder'),
        backgroundColor: const Color(0xFF25D366),
        foregroundColor: Colors.white,
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRemindersList(isCompleted: false),
          _buildRemindersList(isCompleted: true),
        ],
      ),
    );
  }

  Widget _buildRemindersList({required bool isCompleted}) {
    return ValueListenableBuilder(
      valueListenable: HiveStorageService.reminders.listenable(),
      builder: (context, Box box, _) {
        final all = box.toMap().entries.toList();
        final filtered = all.where((e) {
          final item = e.value as Map;
          return (item['isCompleted'] == true) == isCompleted;
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(32.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isCompleted ? Icons.check_circle_outline : Icons.notifications_none_outlined,
                    size: 64.sp,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    isCompleted ? 'No Completed Reminders' : 'No Pending Reminders',
                    style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    isCompleted
                      ? 'Reminders you send will be archived here.'
                      : 'Schedule WhatsApp messages to be sent at specific dates and times.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.all(16.w),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => SizedBox(height: 10.h),
          itemBuilder: (context, index) {
            final entry = filtered[index];
            final item = entry.value as Map;
            final key = entry.key;
            final phone = item['phone'] ?? '';
            final msg = item['message'] ?? '';
            final timeStr = item['scheduledTime'] ?? '';

            DateTime? scheduledDate;
            try {
              scheduledDate = DateTime.parse(timeStr);
            } catch (_) {}

            final formattedDate = scheduledDate != null
                ? '${scheduledDate.day}/${scheduledDate.month}/${scheduledDate.year} at ${scheduledDate.hour}:${scheduledDate.minute.toString().padLeft(2, '0')}'
                : timeStr;

            final isPastDue = scheduledDate != null && scheduledDate.isBefore(DateTime.now()) && !isCompleted;

            return Card(
              elevation: 1.5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
              child: Padding(
                padding: EdgeInsets.all(14.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16.r,
                          backgroundColor: isCompleted
                              ? Colors.grey.withOpacity(0.15)
                              : (isPastDue ? Colors.red.withOpacity(0.15) : Colors.green.withOpacity(0.15)),
                          child: Icon(
                            isCompleted ? Icons.check : (isPastDue ? Icons.priority_high : Icons.alarm),
                            size: 16.sp,
                            color: isCompleted ? Colors.grey : (isPastDue ? Colors.red : Colors.green),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(phone, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)),
                              Text(
                                formattedDate,
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: isPastDue ? Colors.redAccent : Colors.grey,
                                  fontWeight: isPastDue ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                          onPressed: () => box.delete(key),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Container(
                      padding: EdgeInsets.all(10.w),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Text(msg, style: TextStyle(fontSize: 13.sp)),
                    ),
                    SizedBox(height: 10.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (!isCompleted) ...[
                          TextButton.icon(
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text('Edit'),
                            onPressed: () => _showReminderDialog(key: key, existing: item),
                          ),
                          SizedBox(width: 8.w),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                            ),
                            icon: const Icon(Icons.send, size: 16),
                            label: const Text('Send on WhatsApp'),
                            onPressed: () => _openWhatsApp(phone, msg, key, item),
                          ),
                        ] else ...[
                          Text(
                            'Completed',
                            style: TextStyle(fontSize: 11.sp, color: Colors.grey, fontStyle: FontStyle.italic),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            icon: const Icon(Icons.replay, size: 16, color: Colors.green),
                            label: const Text('Resend', style: TextStyle(color: Colors.green)),
                            onPressed: () => _openWhatsApp(phone, msg, key, item),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
