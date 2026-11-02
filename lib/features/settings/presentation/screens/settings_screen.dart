import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/storage/hive_storage_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationGranted = false;
  bool _storageGranted = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final notif = await NotificationListenerService.isPermissionGranted();
    final storage = await Permission.storage.isGranted || await Permission.photos.isGranted;
    if (mounted) {
      setState(() {
        _notificationGranted = notif;
        _storageGranted = storage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Permissions', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ListTile(
            leading: Icon(
              _notificationGranted ? Icons.notifications_active : Icons.notifications_off_outlined,
              color: _notificationGranted ? Colors.green : Colors.red,
            ),
            title: const Text('Notification Access'),
            subtitle: Text(_notificationGranted ? 'Enabled (Catching deleted msgs)' : 'Disabled - Tap to enable'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () async {
              await NotificationListenerService.requestPermission();
              await _checkPermissions();
            },
          ),
          ListTile(
            leading: Icon(
              _storageGranted ? Icons.folder_outlined : Icons.folder_off_outlined,
              color: _storageGranted ? Colors.green : Colors.orange,
            ),
            title: const Text('Storage / Media Access'),
            subtitle: Text(_storageGranted ? 'Granted' : 'Tap to grant permission'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () async {
              await [Permission.storage, Permission.photos, Permission.videos].request();
              await _checkPermissions();
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text('Data Management', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined, color: Colors.redAccent),
            title: const Text('Clear Chat Logs & History'),
            subtitle: const Text('Deletes local direct chat logs and deleted messages'),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear All Data?'),
                  content: const Text('This will delete all saved chat logs and recovered message history stored in the app.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await HiveStorageService.history.clear();
                await HiveStorageService.deletedMessages.clear();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All local data cleared!')),
                  );
                }
              }
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text('App Information', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('ChatFlow WhatsApp Toolkit'),
            subtitle: Text('Version 1.0.0+1'),
          ),
        ],
      ),
    );
  }
}
