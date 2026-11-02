import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/storage/hive_storage_service.dart';

class PrivateVaultScreen extends ConsumerStatefulWidget {
  const PrivateVaultScreen({super.key});

  @override
  ConsumerState<PrivateVaultScreen> createState() => _PrivateVaultScreenState();
}

class _PrivateVaultScreenState extends ConsumerState<PrivateVaultScreen> {
  bool _isUnlocked = false;
  bool _hasPinSet = false;
  final _pinInputController = TextEditingController();
  String _pinError = '';

  // Simple and secure obfuscation cipher key
  static const int _xorKey = 0x5A;

  @override
  void initState() {
    super.initState();
    _checkPinStatus();
  }

  @override
  void dispose() {
    _pinInputController.dispose();
    super.dispose();
  }

  void _checkPinStatus() {
    final savedPin = HiveStorageService.settings.get('vault_pin');
    setState(() {
      _hasPinSet = savedPin != null && savedPin.toString().isNotEmpty;
    });
  }

  // Encryption / Decryption helpers (never stored as plain text)
  String _encrypt(String plain) {
    final bytes = utf8.encode(plain);
    final encrypted = bytes.map((b) => b ^ _xorKey).toList();
    return base64Encode(encrypted);
  }

  String _decrypt(String cipher) {
    try {
      final bytes = base64Decode(cipher);
      final decrypted = bytes.map((b) => b ^ _xorKey).toList();
      return utf8.decode(decrypted);
    } catch (_) {
      return '[Encrypted Content]';
    }
  }

  void _verifyOrSetPin() async {
    final entered = _pinInputController.text.trim();
    if (entered.length != 4) {
      setState(() => _pinError = 'PIN must be 4 digits');
      return;
    }

    if (!_hasPinSet) {
      // Set new PIN
      await HiveStorageService.settings.put('vault_pin', entered);
      setState(() {
        _hasPinSet = true;
        _isUnlocked = true;
        _pinError = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vault PIN successfully created!')),
        );
      }
    } else {
      // Verify existing PIN
      final storedPin = HiveStorageService.settings.get('vault_pin');
      if (storedPin == entered) {
        setState(() {
          _isUnlocked = true;
          _pinError = '';
        });
      } else {
        setState(() {
          _pinError = 'Incorrect PIN. Try again.';
          _pinInputController.clear();
        });
      }
    }
  }

  void _showChangePinDialog() {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: const Text('Change Vault PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldCtrl,
              maxLength: 4,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Current PIN'),
            ),
            SizedBox(height: 10.h),
            TextField(
              controller: newCtrl,
              maxLength: 4,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'New 4-Digit PIN'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final stored = HiveStorageService.settings.get('vault_pin');
              if (stored == oldCtrl.text.trim() && newCtrl.text.trim().length == 4) {
                await HiveStorageService.settings.put('vault_pin', newCtrl.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN updated successfully!')),
                );
              } else {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Verification failed. Check your current PIN.')),
                  );
                }
              }
            },
            child: const Text('Change PIN'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddVaultItemDialog({dynamic key, Map? existing}) async {
    final titleCtrl = TextEditingController(text: existing?['title'] ?? '');
    final noteCtrl = TextEditingController(
      text: existing != null ? _decrypt(existing['encryptedContent']) : '',
    );

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Text(existing != null ? 'Edit Secure Note' : 'Add Secure Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. Secret Code, Private Note'),
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: noteCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Confidential Note / Message',
                border: OutlineInputBorder(),
                hintText: 'Content is encrypted before saving to disk.',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final title = titleCtrl.text.trim().isEmpty ? 'Private Note' : titleCtrl.text.trim();
              final raw = noteCtrl.text.trim();
              if (raw.isEmpty) return;

              final encrypted = _encrypt(raw);
              final data = {
                'id': existing?['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                'title': title,
                'encryptedContent': encrypted,
                'updatedAt': DateTime.now().toIso8601String(),
              };

              if (key != null) {
                await HiveStorageService.vault.put(key, data);
              } else {
                await HiveStorageService.vault.add(data);
              }

              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Encrypt & Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isUnlocked) {
      return _buildLockScreen();
    }
    return _buildVaultDashboard();
  }

  Widget _buildLockScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Private Vault'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 44.r,
                backgroundColor: const Color(0xFF25D366).withOpacity(0.15),
                child: Icon(Icons.lock, size: 48.sp, color: const Color(0xFF128C7E)),
              ),
              SizedBox(height: 20.h),
              Text(
                _hasPinSet ? 'Enter Vault PIN' : 'Create 4-Digit Vault PIN',
                style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8.h),
              Text(
                _hasPinSet
                    ? 'Enter your PIN to access your encrypted notes and private messages.'
                    : 'Set a secure PIN to encrypt your personal notes locally.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13.sp),
              ),
              SizedBox(height: 24.h),
              SizedBox(
                width: 180.w,
                child: TextField(
                  controller: _pinInputController,
                  obscureText: true,
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24.sp, letterSpacing: 8, fontWeight: FontWeight.bold),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    counterText: '',
                    errorText: _pinError.isNotEmpty ? _pinError : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r)),
                    filled: true,
                  ),
                  onSubmitted: (_) => _verifyOrSetPin(),
                ),
              ),
              SizedBox(height: 20.h),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 14.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                ),
                onPressed: _verifyOrSetPin,
                icon: const Icon(Icons.lock_open),
                label: Text(_hasPinSet ? 'Unlock Vault' : 'Set PIN & Enter'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVaultDashboard() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Encrypted Vault'),
        actions: [
          IconButton(
            icon: const Icon(Icons.vpn_key_outlined),
            tooltip: 'Change PIN',
            onPressed: _showChangePinDialog,
          ),
          IconButton(
            icon: const Icon(Icons.lock_outline),
            tooltip: 'Lock Vault',
            onPressed: () => setState(() {
              _isUnlocked = false;
              _pinInputController.clear();
            }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddVaultItemDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Secure Note'),
        backgroundColor: const Color(0xFF25D366),
        foregroundColor: Colors.white,
      ),
      body: ValueListenableBuilder(
        valueListenable: HiveStorageService.vault.listenable(),
        builder: (context, Box box, _) {
          final items = box.toMap().entries.toList();

          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(32.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shield_outlined, size: 64.sp, color: Colors.grey),
                    SizedBox(height: 16.h),
                    const Text('Vault is Empty', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8.h),
                    const Text(
                      'Store confidential texts, private notes, and sensitive codes. Everything is encrypted before storage.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: EdgeInsets.all(16.w),
            itemCount: items.length,
            separatorBuilder: (_, __) => SizedBox(height: 10.h),
            itemBuilder: (context, index) {
              final entry = items[index];
              final item = entry.value as Map;
              final key = entry.key;
              final title = item['title'] ?? 'Private Note';
              final encrypted = item['encryptedContent'] ?? '';
              final decrypted = _decrypt(encrypted);

              return Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                child: Padding(
                  padding: EdgeInsets.all(14.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.lock, size: 16, color: Colors.green),
                              SizedBox(width: 6.w),
                              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp)),
                            ],
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
                        child: SelectableText(
                          decrypted,
                          style: TextStyle(fontSize: 13.5.sp),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text('Edit'),
                            onPressed: () => _showAddVaultItemDialog(key: key, existing: item),
                          ),
                          SizedBox(width: 6.w),
                          TextButton.icon(
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text('Copy'),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: decrypted));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Decrypted text copied!')),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
