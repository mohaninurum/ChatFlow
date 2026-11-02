import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/storage/hive_storage_service.dart';
import '../../../../core/theme/theme_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const _channel = MethodChannel('com.chatflow.app/channel');
  bool _storageGranted = false;
  bool _notificationGranted = false;
  String _cacheSize = '0 KB';
  String _language = 'English';
  bool _appLockEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _calculateCache();
    _loadLocalSettings();
  }

  void _loadLocalSettings() {
    final lang = HiveStorageService.settings.get('language', defaultValue: 'English');
    final lock = HiveStorageService.settings.get('appLockEnabled', defaultValue: false);
    setState(() {
      _language = lang;
      _appLockEnabled = lock;
    });
  }

  Future<void> _checkPermissions() async {
    final storage = await Permission.storage.isGranted || await Permission.photos.isGranted;
    bool notification = false;
    try {
      notification = await _channel.invokeMethod('isNotificationAccessGranted') ?? false;
    } catch (_) {}

    if (mounted) {
      setState(() {
        _storageGranted = storage;
        _notificationGranted = notification;
      });
    }
  }

  Future<void> _calculateCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      int totalBytes = 0;
      if (tempDir.existsSync()) {
        final list = tempDir.listSync(recursive: true);
        for (var f in list) {
          if (f is File) totalBytes += f.lengthSync();
        }
      }
      final kb = totalBytes / 1024;
      if (kb < 1024) {
        setState(() => _cacheSize = '${kb.toStringAsFixed(1)} KB');
      } else {
        setState(() => _cacheSize = '${(kb / 1024).toStringAsFixed(1)} MB');
      }
    } catch (_) {
      setState(() => _cacheSize = '0 KB');
    }
  }

  Future<void> _clearCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
      await _calculateCache();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('App cache cleared successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to clear cache: $e')),
        );
      }
    }
  }

  Future<void> _backupData() async {
    final backup = {
      'templates': HiveStorageService.templates.toMap(),
      'history': HiveStorageService.history.toMap(),
      'favorites': HiveStorageService.favorites.toMap(),
      'statusDownloads': HiveStorageService.statusDownloads.toMap(),
      'backupDate': DateTime.now().toIso8601String(),
    };

    final jsonStr = jsonEncode(backup);
    try {
      await _channel.invokeMethod('shareText', {
        'text': jsonStr,
        'title': 'Chatflow Backup JSON',
      });
    } catch (_) {
      Clipboard.setData(ClipboardData(text: jsonStr));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup JSON copied to clipboard!')),
        );
      }
    }
  }

  void _showAppLockDialog() {
    final pinCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: const Text('Configure App Lock PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Set a 4-digit PIN to secure your Chatflow app.'),
            SizedBox(height: 12.h),
            TextField(
              controller: pinCtrl,
              maxLength: 4,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '4-Digit PIN', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final pin = pinCtrl.text.trim();
              if (pin.length == 4) {
                await HiveStorageService.settings.put('appLockPin', pin);
                await HiveStorageService.settings.put('appLockEnabled', true);
                if (ctx.mounted) Navigator.pop(ctx);
                if (!mounted) return;
                setState(() => _appLockEnabled = true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('App Lock PIN enabled!')),
                );
              }
            },
            child: const Text('Save PIN'),
          ),
        ],
      ),
    );
  }

  void _showThemeDialog(ThemeMode current) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Choose Theme'),
        children: [
          ListTile(
            title: const Text('System Default'),
            trailing: current == ThemeMode.system ? const Icon(Icons.check, color: Colors.green) : null,
            onTap: () {
              ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system);
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            title: const Text('Light'),
            trailing: current == ThemeMode.light ? const Icon(Icons.check, color: Colors.green) : null,
            onTap: () {
              ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light);
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            title: const Text('Dark'),
            trailing: current == ThemeMode.dark ? const Icon(Icons.check, color: Colors.green) : null,
            onTap: () {
              ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Choose Language'),
        children: [
          ListTile(
            title: const Text('English'),
            trailing: _language == 'English' ? const Icon(Icons.check, color: Colors.green) : null,
            onTap: () {
              HiveStorageService.settings.put('language', 'English');
              setState(() => _language = 'English');
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            title: const Text('हिंदी (Hindi)'),
            trailing: _language == 'हिंदी' ? const Icon(Icons.check, color: Colors.green) : null,
            onTap: () {
              HiveStorageService.settings.put('language', 'हिंदी');
              setState(() => _language = 'हिंदी');
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    String themeStr = 'System Default';
    if (themeMode == ThemeMode.light) themeStr = 'Light';
    if (themeMode == ThemeMode.dark) themeStr = 'Dark';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Appearance Section
          const _SectionHeader(title: 'Appearance & Display'),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Theme'),
            subtitle: Text(themeStr),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => _showThemeDialog(themeMode),
          ),
          ListTile(
            leading: const Icon(Icons.language_outlined),
            title: const Text('Language'),
            subtitle: Text(_language),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: _showLanguageDialog,
          ),
          const Divider(),

          // Permissions Section
          const _SectionHeader(title: 'Permissions & System Access'),
          ListTile(
            leading: Icon(
              _notificationGranted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
              color: _notificationGranted ? Colors.green : Colors.orange,
            ),
            title: const Text('Notification Listener Access'),
            subtitle: Text(_notificationGranted ? 'Enabled (Recovery Active)' : 'Disabled - Tap to enable in system settings'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () async {
              await _channel.invokeMethod('openNotificationSettings');
              await _checkPermissions();
            },
          ),
          ListTile(
            leading: Icon(
              _storageGranted ? Icons.folder_outlined : Icons.folder_off_outlined,
              color: _storageGranted ? Colors.green : Colors.orange,
            ),
            title: const Text('Storage & Media Access'),
            subtitle: Text(_storageGranted ? 'Granted' : 'Tap to grant permission'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () async {
              await [Permission.storage, Permission.photos, Permission.videos].request();
              await _checkPermissions();
            },
          ),
          const Divider(),

          // Security & App Lock
          const _SectionHeader(title: 'Privacy & Security'),
          SwitchListTile(
            secondary: const Icon(Icons.lock_outline),
            title: const Text('App Lock PIN'),
            subtitle: Text(_appLockEnabled ? 'App lock is active' : 'Protect Chatflow with a 4-digit PIN'),
            value: _appLockEnabled,
            onChanged: (val) {
              if (val) {
                _showAppLockDialog();
              } else {
                HiveStorageService.settings.put('appLockEnabled', false);
                setState(() => _appLockEnabled = false);
              }
            },
          ),
          const Divider(),

          // Storage & Cache Management
          const _SectionHeader(title: 'Data & Cache Management'),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('Clear Temporary Cache'),
            subtitle: Text('Current cache size: $_cacheSize'),
            trailing: TextButton(
              onPressed: _clearCache,
              child: const Text('Clear'),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Backup Data'),
            subtitle: const Text('Export all templates and chat history to JSON'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: _backupData,
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined, color: Colors.redAccent),
            title: const Text('Reset All Local Data'),
            subtitle: const Text('Deletes chat history, templates, and logs'),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Reset Everything?'),
                  content: const Text('This will delete all saved messages, direct chat history, and custom quick replies. Default templates will be restored.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Reset All'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await HiveStorageService.history.clear();
                await HiveStorageService.deletedMessages.clear();
                await HiveStorageService.templates.clear();
                await HiveStorageService.statusDownloads.clear();
                await HiveStorageService.init(); // re-seed defaults
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All data reset to initial state!')),
                  );
                }
              }
            },
          ),
          const Divider(),

          // About & Legal
          const _SectionHeader(title: 'About Chatflow'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('App Version'),
            subtitle: const Text('Chatflow v1.0.0+1 (Production Build)'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                  title: const Text('Privacy Policy'),
                  content: const SingleChildScrollView(
                    child: Text(
                      '1. Offline First: Chatflow operates 100% locally on your smartphone. We do not transmit or upload your phone numbers, chats, or media to any remote server.\n\n'
                      '2. Permissions: Storage permission is used solely to save WhatsApp status media to your device gallery. Notification access is used solely to archive incoming notification snippets locally.\n\n'
                      '3. Encryption & WhatsApp Terms: Chatflow never modifies WhatsApp binaries, bypasses encryption, or accesses WhatsApp SQLite databases.',
                    ),
                  ),
                  actions: [
                    ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                  ],
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms & Conditions'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                  title: const Text('Terms & Conditions'),
                  content: const SingleChildScrollView(
                    child: Text(
                      'Chatflow is an independent third-party companion toolkit designed for Android users. It is not affiliated, associated, authorized, endorsed by, or in any way officially connected with WhatsApp LLC or Meta Platforms, Inc.\n\n'
                      'By using this application, you agree to comply with all local privacy laws and respect the privacy of individuals whose media or messages you interact with.',
                    ),
                  ),
                  actions: [
                    ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                  ],
                ),
              );
            },
          ),
          SizedBox(height: 32.h),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 6.h),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
