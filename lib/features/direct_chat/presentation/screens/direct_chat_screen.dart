import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/storage/hive_storage_service.dart';
import '../../../../core/utils/country_codes.dart';

class DirectChatScreen extends ConsumerStatefulWidget {
  final String? initialMessage;
  const DirectChatScreen({super.key, this.initialMessage});

  @override
  ConsumerState<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends ConsumerState<DirectChatScreen> {
  static const _channel = MethodChannel('com.chatflow.app/channel');
  final _imagePicker = ImagePicker();

  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();
  CountryCodeItem _selectedCountry = allCountryCodes.first; // Default India (+91)
  bool _isBusiness = false;
  String? _phoneValidationError;

  // Attachment state: { 'path': String, 'name': String, 'size': int, 'type': 'image'|'video'|'document'|'audio' }
  Map<String, dynamic>? _selectedAttachment;

  @override
  void initState() {
    super.initState();
    if (widget.initialMessage != null && widget.initialMessage!.isNotEmpty) {
      _messageController.text = widget.initialMessage!;
    }
    _phoneController.addListener(_validatePhone);
    _messageController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _validatePhone() {
    final raw = _phoneController.text.trim();
    final clean = raw.replaceAll(RegExp(r'\D'), '');
    if (raw.isNotEmpty && (clean.length < 7 || clean.length > 15)) {
      if (_phoneValidationError == null) {
        setState(() => _phoneValidationError = 'Enter a valid 7-15 digit number');
      }
    } else {
      if (_phoneValidationError != null) {
        setState(() => _phoneValidationError = null);
      }
    }
    if (mounted) setState(() {});
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    final kb = bytes / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

  Future<void> _pickDocument() async {
    try {
      final res = await _channel.invokeMethod<Map>('pickAttachment', {'type': 'document'});
      if (res != null) {
        setState(() {
          _selectedAttachment = {
            'path': res['path']?.toString() ?? '',
            'name': res['name']?.toString() ?? 'Document.pdf',
            'size': res['size'] as int? ?? 0,
            'type': 'document',
          };
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to select document: $e')),
        );
      }
    }
  }

  Future<void> _pickAudio() async {
    try {
      final res = await _channel.invokeMethod<Map>('pickAttachment', {'type': 'audio'});
      if (res != null) {
        setState(() {
          _selectedAttachment = {
            'path': res['path']?.toString() ?? '',
            'name': res['name']?.toString() ?? 'Audio_File.mp3',
            'size': res['size'] as int? ?? 0,
            'type': 'audio',
          };
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to select audio: $e')),
        );
      }
    }
  }

  Future<void> _pickGallery() async {
    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        final file = File(picked.path);
        final size = await file.length();
        setState(() {
          _selectedAttachment = {
            'path': picked.path,
            'name': picked.name,
            'size': size,
            'type': 'image',
          };
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _pickCamera() async {
    try {
      final status = await Permission.camera.request();
      if (status.isDenied || status.isPermanentlyDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Camera permission is required to capture photos.')),
          );
        }
        return;
      }
      final picked = await _imagePicker.pickImage(source: ImageSource.camera);
      if (picked != null) {
        final file = File(picked.path);
        final size = await file.length();
        setState(() {
          _selectedAttachment = {
            'path': picked.path,
            'name': picked.name,
            'size': size,
            'type': 'image',
          };
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to capture photo: $e')),
        );
      }
    }
  }

  void _clearAttachment() {
    setState(() {
      _selectedAttachment = null;
    });
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          margin: EdgeInsets.all(16.w),
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 22.h),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1F2C34) : Colors.white,
            borderRadius: BorderRadius.circular(24.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(height: 18.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildAttachmentItem(
                    icon: Icons.insert_drive_file_rounded,
                    label: 'Document',
                    gradient: const [Color(0xFF7F66FF), Color(0xFF533CE1)],
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickDocument();
                    },
                  ),
                  _buildAttachmentItem(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    gradient: const [Color(0xFFD3396D), Color(0xFFC2185B)],
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickCamera();
                    },
                  ),
                  _buildAttachmentItem(
                    icon: Icons.photo_rounded,
                    label: 'Gallery',
                    gradient: const [Color(0xFFAC44CF), Color(0xFF7B1FA2)],
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickGallery();
                    },
                  ),
                ],
              ),
              SizedBox(height: 20.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildAttachmentItem(
                    icon: Icons.headphones_rounded,
                    label: 'Audio',
                    gradient: const [Color(0xFFE37B14), Color(0xFFEF6C00)],
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAudio();
                    },
                  ),
                  _buildAttachmentItem(
                    icon: Icons.auto_stories_rounded,
                    label: 'Template',
                    gradient: const [Color(0xFF0294FF), Color(0xFF0277BD)],
                    onTap: () {
                      Navigator.pop(ctx);
                      _showTemplatePicker();
                    },
                  ),
                  _buildAttachmentItem(
                    icon: Icons.contacts_rounded,
                    label: 'Contact',
                    gradient: const [Color(0xFF00A884), Color(0xFF00796B)],
                    onTap: () {
                      Navigator.pop(ctx);
                      _showContactsOrFavoritesPicker();
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttachmentItem({
    required IconData icon,
    required String label,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56.w,
            height: 56.w,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: gradient.first.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 26.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filtered = allCountryCodes.where((c) {
              final query = searchQuery.toLowerCase();
              return c.name.toLowerCase().contains(query) ||
                  c.dialCode.contains(query) ||
                  c.code.toLowerCase().contains(query);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: EdgeInsets.only(
                top: 16.h,
                left: 16.w,
                right: 16.w,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16.h,
              ),
              child: Column(
                children: [
                  Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'Select Country Code',
                    style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12.h),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search country or code...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r)),
                      filled: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    ),
                    onChanged: (val) {
                      setSheetState(() => searchQuery = val);
                    },
                  ),
                  SizedBox(height: 12.h),
                  Expanded(
                    child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final isSelected = item.dialCode == _selectedCountry.dialCode &&
                            item.code == _selectedCountry.code;

                        return ListTile(
                          leading: Text(item.flag, style: TextStyle(fontSize: 24.sp)),
                          title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                          trailing: Text(
                            item.dialCode,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isSelected ? const Color(0xFF25D366) : Colors.grey[700],
                            ),
                          ),
                          tileColor: isSelected ? const Color(0xFF25D366).withValues(alpha: 0.12) : null,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                          onTap: () {
                            setState(() => _selectedCountry = item);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showContactsOrFavoritesPicker() {
    final favorites = HiveStorageService.getFavoriteContacts();
    final recentHistory = HiveStorageService.history.values.toList().reversed.toList();

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (ctx) {
        return DefaultTabController(
          length: 2,
          child: Container(
            height: 400.h,
            padding: EdgeInsets.all(16.w),
            child: Column(
              children: [
                TabBar(
                  labelColor: const Color(0xFF25D366),
                  indicatorColor: const Color(0xFF25D366),
                  tabs: const [
                    Tab(icon: Icon(Icons.star), text: 'Favorite Contacts'),
                    Tab(icon: Icon(Icons.history), text: 'Recent Contacts'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Favorites tab
                      favorites.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.star_border, size: 48.sp, color: Colors.grey),
                                  SizedBox(height: 8.h),
                                  const Text('No favorite contacts yet', style: TextStyle(color: Colors.grey)),
                                  SizedBox(height: 4.h),
                                  const Text('Star numbers in Direct Chat to save them here.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: favorites.length,
                              itemBuilder: (context, i) {
                                final phone = favorites[i];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.amber.withValues(alpha: 0.2),
                                    child: const Icon(Icons.star, color: Colors.amber),
                                  ),
                                  title: Text(phone, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                                  onTap: () {
                                    _phoneController.text = phone.replaceAll(RegExp(r'\D'), '');
                                    Navigator.pop(ctx);
                                  },
                                );
                              },
                            ),
                      // Recents tab
                      recentHistory.isEmpty
                          ? Center(
                              child: Text('No recent chat numbers', style: TextStyle(color: Colors.grey, fontSize: 14.sp)),
                            )
                          : ListView.builder(
                              itemCount: recentHistory.length.clamp(0, 15),
                              itemBuilder: (context, i) {
                                final item = recentHistory[i] as Map;
                                final phone = item['phone']?.toString() ?? '';
                                final msg = item['message']?.toString() ?? '';
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.15),
                                    child: const Icon(Icons.phone, color: Color(0xFF25D366)),
                                  ),
                                  title: Text(phone, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: msg.isNotEmpty
                                      ? Text(msg, maxLines: 1, overflow: TextOverflow.ellipsis)
                                      : null,
                                  onTap: () {
                                    _phoneController.text = phone.replaceAll(RegExp(r'\D'), '');
                                    Navigator.pop(ctx);
                                  },
                                );
                              },
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTemplatePicker() {
    final templates = HiveStorageService.templates.values.toList();
    if (templates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No templates saved yet.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (ctx) => Container(
        height: 450.h,
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pick Quick Reply Template',
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            SizedBox(height: 8.h),
            Expanded(
              child: ListView.separated(
                itemCount: templates.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final t = templates[index] as Map;
                  final title = t['title'] ?? '';
                  final msg = t['message'] ?? '';
                  final cat = t['category'] ?? '';

                  return ListTile(
                    title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(msg, maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: Chip(
                      label: Text(cat, style: TextStyle(fontSize: 10.sp)),
                      visualDensity: VisualDensity.compact,
                    ),
                    onTap: () {
                      _checkVariablesAndFill(msg);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _checkVariablesAndFill(String rawMessage) {
    final hasName = rawMessage.contains('{name}');
    final hasOrderId = rawMessage.contains('{order_id}');
    final hasAmount = rawMessage.contains('{amount}');

    if (!hasName && !hasOrderId && !hasAmount) {
      setState(() => _messageController.text = rawMessage);
      return;
    }

    final nameCtrl = TextEditingController();
    final orderCtrl = TextEditingController();
    final amountCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: const Text('Fill Template Variables'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasName) ...[
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name {name}', hintText: 'e.g. John Doe'),
                ),
                SizedBox(height: 10.h),
              ],
              if (hasOrderId) ...[
                TextField(
                  controller: orderCtrl,
                  decoration: const InputDecoration(labelText: 'Order ID {order_id}', hintText: 'e.g. ORD-1049'),
                ),
                SizedBox(height: 10.h),
              ],
              if (hasAmount) ...[
                TextField(
                  controller: amountCtrl,
                  decoration: const InputDecoration(labelText: 'Amount {amount}', hintText: 'e.g. 499'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Skip')),
          ElevatedButton(
            onPressed: () {
              String filled = rawMessage;
              if (hasName) filled = filled.replaceAll('{name}', nameCtrl.text.trim().isEmpty ? 'Customer' : nameCtrl.text.trim());
              if (hasOrderId) filled = filled.replaceAll('{order_id}', orderCtrl.text.trim().isEmpty ? '1234' : orderCtrl.text.trim());
              if (hasAmount) filled = filled.replaceAll('{amount}', amountCtrl.text.trim().isEmpty ? '0' : amountCtrl.text.trim());

              setState(() => _messageController.text = filled);
              Navigator.pop(ctx);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Future<void> _openWhatsApp() async {
    final rawPhone = _phoneController.text.trim();
    if (rawPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a phone number first')),
      );
      return;
    }

    final cleanPhone = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.length < 7 || cleanPhone.length > 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 7-15 digit phone number')),
      );
      return;
    }

    final cleanCode = _selectedCountry.dialCode.replaceAll('+', '').trim();
    final fullNumber = '$cleanCode$cleanPhone';
    final message = _messageController.text.trim();

    // Log to history
    await HiveStorageService.logDirectChat(
      phone: fullNumber,
      message: message,
      isBusiness: _isBusiness,
    );

    try {
      final res = await _channel.invokeMethod('sendToWhatsApp', {
        'phone': fullNumber,
        'text': message,
        'filePath': _selectedAttachment?['path'],
        'isBusiness': _isBusiness,
      });

      if (res != true) {
        final encodedMsg = Uri.encodeComponent(message);
        final appScheme = _isBusiness
            ? 'whatsapp://send?phone=$fullNumber${message.isNotEmpty ? '&text=$encodedMsg' : ''}'
            : 'https://wa.me/$fullNumber${message.isNotEmpty ? '?text=$encodedMsg' : ''}';

        final uri = Uri.parse(appScheme);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (mounted) _showWhatsAppNotInstalledDialog();
        }
      }
    } catch (_) {
      if (mounted) _showWhatsAppNotInstalledDialog();
    }
  }

  void _showWhatsAppNotInstalledDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('App Not Found'),
          ],
        ),
        content: Text(
          _isBusiness
              ? 'WhatsApp Business is not installed or could not be launched on this device.'
              : 'WhatsApp is not installed or could not be launched on this device.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final pkg = _isBusiness ? 'com.whatsapp.w4b' : 'com.whatsapp';
              final playStoreUrl = Uri.parse('market://details?id=$pkg');
              if (await canLaunchUrl(playStoreUrl)) {
                await launchUrl(playStoreUrl, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('Install from Play Store'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final currentClean = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    final fullNumber = currentClean.isNotEmpty ? '${_selectedCountry.dialCode}$currentClean' : '';
    final isFavorite = HiveStorageService.getFavoriteContacts().contains(fullNumber);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Direct Chat', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
              currentClean.isNotEmpty ? fullNumber : 'Message unsaved contacts',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[400]),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.contacts_outlined),
            tooltip: 'Favorites & Recents',
            onPressed: _showContactsOrFavoritesPicker,
          ),
          IconButton(
            icon: Icon(
              isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
              color: isFavorite ? Colors.amber : null,
            ),
            tooltip: isFavorite ? 'Remove Favorite' : 'Save as Favorite',
            onPressed: fullNumber.isNotEmpty
                ? () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await HiveStorageService.toggleFavoriteContact(fullNumber);
                    if (!mounted) return;
                    setState(() {});
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(isFavorite ? 'Removed from favorites' : 'Saved to favorite contacts!'),
                      ),
                    );
                  }
                : null,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Recipient Phone & App selector header
          _buildRecipientHeader(isDark),

          // 2. Chat Canvas with WhatsApp Wallpaper Background & Live Message Bubble
          Expanded(
            child: _buildChatCanvas(isDark),
          ),

          // 3. Authentic WhatsApp Input Bar & Professional Circular Send Button
          _buildWhatsAppInputBar(isDark),
        ],
      ),
    );
  }

  Widget _buildRecipientHeader(bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2C34) : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? Colors.black26 : Colors.grey[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // WhatsApp vs WA Business toggle chips
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isBusiness = false),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 7.h),
                    decoration: BoxDecoration(
                      color: !_isBusiness ? const Color(0xFF25D366) : (isDark ? Colors.grey[850] : Colors.grey[100]),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_rounded, size: 16.sp, color: !_isBusiness ? Colors.white : Colors.grey),
                        SizedBox(width: 6.w),
                        Text(
                          'WhatsApp',
                          style: TextStyle(
                            fontSize: 12.5.sp,
                            fontWeight: FontWeight.bold,
                            color: !_isBusiness ? Colors.white : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isBusiness = true),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 7.h),
                    decoration: BoxDecoration(
                      color: _isBusiness ? const Color(0xFF128C7E) : (isDark ? Colors.grey[850] : Colors.grey[100]),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.storefront_rounded, size: 16.sp, color: _isBusiness ? Colors.white : Colors.grey),
                        SizedBox(width: 6.w),
                        Text(
                          'WA Business',
                          style: TextStyle(
                            fontSize: 12.5.sp,
                            fontWeight: FontWeight.bold,
                            color: _isBusiness ? Colors.white : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),

          // Country code + Phone input field
          Row(
            children: [
              InkWell(
                onTap: _showCountryPicker,
                borderRadius: BorderRadius.circular(12.r),
                child: Container(
                  height: 48.h,
                  padding: EdgeInsets.symmetric(horizontal: 10.w),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF121B22) : const Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      Text(_selectedCountry.flag, style: TextStyle(fontSize: 18.sp)),
                      SizedBox(width: 4.w),
                      Text(
                        _selectedCountry.dialCode,
                        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
                      ),
                      const Icon(Icons.arrow_drop_down, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Container(
                  height: 48.h,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF121B22) : const Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: _phoneValidationError != null
                          ? Colors.red
                          : (isDark ? Colors.grey[800]! : Colors.grey[300]!),
                    ),
                  ),
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Enter phone number...',
                      hintStyle: TextStyle(fontSize: 14.sp, color: Colors.grey[500]),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_phoneController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () => _phoneController.clear(),
                            ),
                          IconButton(
                            icon: const Icon(Icons.content_paste_rounded, size: 18),
                            tooltip: 'Paste Number',
                            onPressed: () async {
                              final data = await Clipboard.getData('text/plain');
                              if (data?.text != null) {
                                _phoneController.text = data!.text!.replaceAll(RegExp(r'\D'), '');
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Validation Error
          if (_phoneValidationError != null) ...[
            SizedBox(height: 4.h),
            Text(
              _phoneValidationError!,
              style: TextStyle(color: Colors.redAccent, fontSize: 11.sp),
            ),
          ],

          // Quick Recent Numbers horizontal strip
          SizedBox(height: 8.h),
          _buildRecentNumbersStrip(),
        ],
      ),
    );
  }

  Widget _buildRecentNumbersStrip() {
    return ValueListenableBuilder(
      valueListenable: HiveStorageService.history.listenable(),
      builder: (context, Box box, _) {
        if (box.isEmpty) return const SizedBox.shrink();
        final rawItems = box.values.toList().reversed.toList();
        final seen = <String>{};
        final uniqueRecent = <String>[];
        for (var item in rawItems) {
          if (item is Map && item['phone'] != null) {
            final p = item['phone'].toString();
            if (seen.add(p)) {
              uniqueRecent.add(p);
            }
          }
          if (uniqueRecent.length >= 6) break;
        }

        if (uniqueRecent.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 28.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: uniqueRecent.length,
            separatorBuilder: (context, index) => SizedBox(width: 6.w),
            itemBuilder: (context, index) {
              final phone = uniqueRecent[index];
              return InkWell(
                onTap: () {
                  _phoneController.text = phone.replaceAll(RegExp(r'\D'), '');
                },
                borderRadius: BorderRadius.circular(8.r),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history, size: 12.sp, color: const Color(0xFF25D366)),
                      SizedBox(width: 4.w),
                      Text(
                        phone,
                        style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: const Color(0xFF25D366)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildChatCanvas(bool isDark) {
    final msg = _messageController.text;
    final hasContent = msg.trim().isNotEmpty || _selectedAttachment != null;

    return Container(
      width: double.infinity,
      color: isDark ? const Color(0xFF0B141A) : const Color(0xFFEFEAE2),
      child: Stack(
        children: [
          // Subtle authentic WhatsApp doodle background pattern effect
          Positioned.fill(
            child: Opacity(
              opacity: isDark ? 0.04 : 0.06,
              child: Image.network(
                'https://user-images.githubusercontent.com/15075759/28719144-86dc0f70-73b1-11e7-911d-60d70fcded21.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
              ),
            ),
          ),

          // Chat messages scrollable view
          ListView(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            children: [
              // Security end-to-end encryption pill
              Center(
                child: Container(
                  margin: EdgeInsets.symmetric(vertical: 8.h),
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF182229) : const Color(0xFFFFF9C4),
                    borderRadius: BorderRadius.circular(8.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_rounded, size: 12.sp, color: isDark ? Colors.amber[300] : Colors.orange[800]),
                      SizedBox(width: 6.w),
                      Flexible(
                        child: Text(
                          'Direct message to unsaved contact with 100% privacy',
                          style: TextStyle(
                            fontSize: 10.5.sp,
                            color: isDark ? Colors.amber[300] : Colors.orange[900],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 12.h),

              // Outgoing Message Bubble (WhatsApp Styled)
              Align(
                alignment: Alignment.centerRight,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 0.82.sw),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF005C4B) : const Color(0xFFE7FFDB),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16.r),
                        topRight: Radius.circular(4.r),
                        bottomLeft: Radius.circular(16.r),
                        bottomRight: Radius.circular(16.r),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(_selectedAttachment != null ? 6.w : 10.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Attachment preview in bubble
                        if (_selectedAttachment != null)
                          _buildBubbleAttachmentPreview(isDark),

                        // Message Text
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
                          child: Text(
                            hasContent
                                ? (msg.trim().isNotEmpty ? msg : '')
                                : 'Type your message or attach media/documents below...',
                            style: TextStyle(
                              fontSize: 14.5.sp,
                              height: 1.35,
                              color: hasContent
                                  ? (isDark ? Colors.white : const Color(0xFF111B21))
                                  : Colors.grey[600],
                              fontStyle: hasContent ? FontStyle.normal : FontStyle.italic,
                            ),
                          ),
                        ),

                        // Bubble Footer: Time + WhatsApp Double Blue Ticks
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                              SizedBox(width: 4.w),
                              Icon(
                                Icons.done_all_rounded,
                                size: 15.sp,
                                color: const Color(0xFF53BDEB), // Authentic WhatsApp blue tick
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBubbleAttachmentPreview(bool isDark) {
    final type = _selectedAttachment!['type'] as String;
    final name = _selectedAttachment!['name'] as String;
    final size = _selectedAttachment!['size'] as int;
    final path = _selectedAttachment!['path'] as String;

    if (type == 'image') {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: Image.file(
              File(path),
              width: double.infinity,
              height: 180.h,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 120.h,
                color: Colors.black12,
                child: const Center(child: Icon(Icons.broken_image)),
              ),
            ),
          ),
          Positioned(
            top: 6.h,
            right: 6.w,
            child: CircleAvatar(
              radius: 14.r,
              backgroundColor: Colors.black54,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.close, size: 16, color: Colors.white),
                onPressed: _clearAttachment,
              ),
            ),
          ),
        ],
      );
    }

    if (type == 'audio') {
      return Container(
        margin: EdgeInsets.only(bottom: 6.h),
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF182229) : Colors.white,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: const BoxDecoration(
                color: Color(0xFFE37B14),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.headphones_rounded, color: Colors.white, size: 20),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp),
                  ),
                  Text(
                    'Audio • ${_formatFileSize(size)}',
                    style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: Colors.grey),
              onPressed: _clearAttachment,
            ),
          ],
        ),
      );
    }

    // Default: Document / PDF
    return Container(
      margin: EdgeInsets.only(bottom: 6.h),
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF182229) : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: name.toLowerCase().endsWith('.pdf') ? Colors.redAccent : const Color(0xFF5A45FF),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(
              name.toLowerCase().endsWith('.pdf') ? Icons.picture_as_pdf_rounded : Icons.insert_drive_file_rounded,
              color: Colors.white,
              size: 22.sp,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp),
                ),
                Text(
                  '${name.split('.').last.toUpperCase()} • ${_formatFileSize(size)}',
                  style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.grey),
            onPressed: _clearAttachment,
          ),
        ],
      ),
    );
  }

  Widget _buildWhatsAppInputBar(bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121B22) : const Color(0xFFF0F2F5),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top attachment chip indicator if selected
            if (_selectedAttachment != null)
              Container(
                margin: EdgeInsets.only(bottom: 8.h),
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1F2C34) : Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      _selectedAttachment!['type'] == 'audio'
                          ? Icons.headphones_rounded
                          : (_selectedAttachment!['type'] == 'image' ? Icons.image_rounded : Icons.description_rounded),
                      color: const Color(0xFF25D366),
                      size: 18.sp,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'Attached: ${_selectedAttachment!['name']} (${_formatFileSize(_selectedAttachment!['size'] as int)})',
                        style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: _clearAttachment,
                      child: const Icon(Icons.cancel, size: 18, color: Colors.grey),
                    ),
                  ],
                ),
              ),

            // Authentic WhatsApp Rounded Pill Input + Professional Green Send Button
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1F2C34) : Colors.white,
                      borderRadius: BorderRadius.circular(26.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Smiley / Template button
                        IconButton(
                          icon: Icon(
                            Icons.emoji_emotions_outlined,
                            color: Colors.grey[600],
                            size: 24.sp,
                          ),
                          tooltip: 'Quick Templates',
                          onPressed: _showTemplatePicker,
                        ),

                        // Message Text input
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 4.h),
                            child: TextField(
                              controller: _messageController,
                              maxLines: 5,
                              minLines: 1,
                              textCapitalization: TextCapitalization.sentences,
                              style: TextStyle(fontSize: 15.sp),
                              decoration: InputDecoration(
                                hintText: 'Message',
                                hintStyle: TextStyle(color: Colors.grey[500], fontSize: 15.sp),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 8.h),
                              ),
                            ),
                          ),
                        ),

                        // Paperclip Attachment icon (rotated 45 deg like WhatsApp)
                        Transform.rotate(
                          angle: -0.7,
                          child: IconButton(
                            icon: Icon(
                              Icons.attach_file_rounded,
                              color: Colors.grey[600],
                              size: 24.sp,
                            ),
                            tooltip: 'Attach Media, Audio, or Document',
                            onPressed: _showAttachmentMenu,
                          ),
                        ),

                        // Camera Quick-Capture button
                        IconButton(
                          icon: Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.grey[600],
                            size: 22.sp,
                          ),
                          tooltip: 'Take Photo',
                          onPressed: _pickCamera,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 8.w),

                // Professional WhatsApp Iconic Circular Send Button
                Container(
                  width: 48.w,
                  height: 48.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF25D366).withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _openWhatsApp,
                      customBorder: const CircleBorder(),
                      splashColor: Colors.white.withValues(alpha: 0.3),
                      child: Center(
                        child: Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 22.sp,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
