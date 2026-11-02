import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/storage/hive_storage_service.dart';
import '../../../../core/utils/country_codes.dart';

class DirectChatScreen extends ConsumerStatefulWidget {
  const DirectChatScreen({super.key});

  @override
  ConsumerState<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends ConsumerState<DirectChatScreen> {
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();
  CountryCodeItem _selectedCountry = allCountryCodes.first; // Default India (+91)
  bool _isBusiness = false;
  String? _phoneValidationError;

  @override
  void initState() {
    super.initState();
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
                      separatorBuilder: (_, __) => const Divider(height: 1),
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
                              color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[700],
                            ),
                          ),
                          tileColor: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.08) : null,
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
                  labelColor: Theme.of(context).colorScheme.primary,
                  indicatorColor: Theme.of(context).colorScheme.primary,
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
                                    backgroundColor: Colors.amber.withOpacity(0.2),
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
                                    backgroundColor: Colors.green.withOpacity(0.15),
                                    child: const Icon(Icons.phone, color: Colors.green),
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
                separatorBuilder: (_, __) => const Divider(),
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

    // Modal to fill variables
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
        const SnackBar(content: Text('Please enter a phone number')),
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

    final encodedMsg = Uri.encodeComponent(message);

    // Deep link schemes:
    // Standard WhatsApp: whatsapp://send?phone=fullNumber&text=encodedMsg
    // Or wa.me fallback
    final appScheme = _isBusiness
        ? 'whatsapp://send?phone=$fullNumber${message.isNotEmpty ? '&text=$encodedMsg' : ''}'
        : 'https://wa.me/$fullNumber${message.isNotEmpty ? '?text=$encodedMsg' : ''}';

    final uri = Uri.parse(appScheme);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to wa.me browser link
        final fallbackUri = Uri.parse('https://wa.me/$fullNumber${message.isNotEmpty ? '?text=$encodedMsg' : ''}');
        if (await canLaunchUrl(fallbackUri)) {
          await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
        } else {
          if (mounted) {
            _showWhatsAppNotInstalledDialog();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        _showWhatsAppNotInstalledDialog();
      }
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

  void _copyToClipboard(String text, String label) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied $label to clipboard!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final currentClean = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    final fullNumber = currentClean.isNotEmpty ? '${_selectedCountry.dialCode}$currentClean' : '';
    final isFavorite = HiveStorageService.getFavoriteContacts().contains(fullNumber);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Direct Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.contacts_outlined),
            tooltip: 'Pick from Favorites / Recents',
            onPressed: _showContactsOrFavoritesPicker,
          ),
          IconButton(
            icon: Icon(
              isFavorite ? Icons.star : Icons.star_border,
              color: isFavorite ? Colors.amber : null,
            ),
            tooltip: isFavorite ? 'Remove Favorite' : 'Save as Favorite',
            onPressed: fullNumber.isNotEmpty
                ? () async {
                    await HiveStorageService.toggleFavoriteContact(fullNumber);
                    setState(() {});
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isFavorite ? 'Removed from favorites' : 'Saved to favorite contacts!'),
                        ),
                      );
                    }
                  }
                : null,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // App selector chip toggle (WhatsApp vs WhatsApp Business)
            Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.grey[200],
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isBusiness = false),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 10.h),
                        decoration: BoxDecoration(
                          color: !_isBusiness ? const Color(0xFF25D366) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat,
                              size: 18.sp,
                              color: !_isBusiness ? Colors.white : Colors.grey,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              'WhatsApp',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: !_isBusiness ? Colors.white : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isBusiness = true),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 10.h),
                        decoration: BoxDecoration(
                          color: _isBusiness ? const Color(0xFF128C7E) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.storefront,
                              size: 18.sp,
                              color: _isBusiness ? Colors.white : Colors.grey,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              'WA Business',
                              style: TextStyle(
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
            ),
            SizedBox(height: 16.h),

            // Recently used numbers chips (horizontal)
            _buildRecentNumbersStrip(),
            SizedBox(height: 16.h),

            // Phone input row with Country Code button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: _showCountryPicker,
                  borderRadius: BorderRadius.circular(16.r),
                  child: Container(
                    height: 56.h,
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(16.r),
                      color: isDark ? const Color(0xFF202C33) : Colors.white,
                    ),
                    child: Row(
                      children: [
                        Text(_selectedCountry.flag, style: TextStyle(fontSize: 20.sp)),
                        SizedBox(width: 6.w),
                        Text(
                          _selectedCountry.dialCode,
                          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold),
                        ),
                        Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: 'Enter phone number',
                      errorText: _phoneValidationError,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF202C33) : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_phoneController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => _phoneController.clear(),
                            ),
                          IconButton(
                            icon: const Icon(Icons.paste, size: 18),
                            tooltip: 'Paste',
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
              ],
            ),
            SizedBox(height: 16.h),

            // Message Header with Quick Reply button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Message (Optional)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp),
                ),
                TextButton.icon(
                  onPressed: _showTemplatePicker,
                  icon: const Icon(Icons.auto_stories, size: 16),
                  label: const Text('Use Template'),
                ),
              ],
            ),
            SizedBox(height: 6.h),

            // Message TextField with Character Counter
            TextField(
              controller: _messageController,
              maxLines: 4,
              maxLength: 2000,
              decoration: InputDecoration(
                hintText: 'Type your message or pick a quick reply template...',
                filled: true,
                fillColor: isDark ? const Color(0xFF202C33) : Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r)),
                counterText: '${_messageController.text.length} / 2000 characters',
                contentPadding: EdgeInsets.all(16.w),
              ),
            ),
            SizedBox(height: 16.h),

            // Live WhatsApp Bubble Preview
            _buildMessagePreviewCard(isDark),
            SizedBox(height: 20.h),

            // Copy Action Buttons Row
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: fullNumber.isNotEmpty
                        ? () => _copyToClipboard(fullNumber, 'Phone Number')
                        : null,
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy Number'),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _messageController.text.isNotEmpty
                        ? () => _copyToClipboard(_messageController.text, 'Message')
                        : null,
                    icon: const Icon(Icons.message_outlined, size: 16),
                    label: const Text('Copy Message'),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),

            // Main Launch Button
            ElevatedButton.icon(
              onPressed: _openWhatsApp,
              icon: Icon(_isBusiness ? Icons.storefront : Icons.send, size: 20),
              label: Text(
                _isBusiness ? 'Open in WhatsApp Business' : 'Open in WhatsApp',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isBusiness ? const Color(0xFF128C7E) : const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                elevation: 1,
              ),
            ),
            SizedBox(height: 24.h),

            // Recent chats in Direct Chat
            _buildRecentChatHistorySection(),
          ],
        ),
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
            if (!seen.contains(p)) {
              seen.add(p);
              uniqueRecent.add(p);
            }
          }
          if (uniqueRecent.length >= 6) break;
        }

        if (uniqueRecent.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recently Used Numbers',
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: Colors.grey),
            ),
            SizedBox(height: 8.h),
            SizedBox(
              height: 36.h,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: uniqueRecent.length,
                separatorBuilder: (_, __) => SizedBox(width: 8.w),
                itemBuilder: (context, index) {
                  final phone = uniqueRecent[index];
                  return ActionChip(
                    avatar: const Icon(Icons.history, size: 14),
                    label: Text(phone, style: TextStyle(fontSize: 12.sp)),
                    onPressed: () {
                      _phoneController.text = phone.replaceAll(RegExp(r'\D'), '');
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMessagePreviewCard(bool isDark) {
    final msg = _messageController.text.trim();
    if (msg.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2C34) : const Color(0xFFE5DDD5),
        borderRadius: BorderRadius.circular(16.r),
        image: const DecorationImage(
          image: NetworkImage('https://user-images.githubusercontent.com/15075759/28719144-86dc0f70-73b1-11e7-911d-60d70fcded21.png'),
          fit: BoxFit.cover,
          opacity: 0.05,
        ),
      ),
      padding: EdgeInsets.all(14.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.remove_red_eye_outlined, size: 14.sp, color: Colors.grey[700]),
              SizedBox(width: 6.w),
              Text(
                'WhatsApp Message Preview',
                style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, color: Colors.grey[700]),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              constraints: BoxConstraints(maxWidth: 260.w),
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF005D4B) : const Color(0xFFD9FDD3),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14.r),
                  bottomLeft: Radius.circular(14.r),
                  topRight: Radius.circular(4.r),
                  bottomRight: Radius.circular(14.r),
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    msg,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Just now',
                        style: TextStyle(fontSize: 10.sp, color: Colors.grey[600]),
                      ),
                      SizedBox(width: 4.w),
                      Icon(Icons.done_all, size: 14.sp, color: Colors.blue),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentChatHistorySection() {
    return ValueListenableBuilder(
      valueListenable: HiveStorageService.history.listenable(),
      builder: (context, Box box, _) {
        if (box.isEmpty) return const SizedBox.shrink();

        final items = box.toMap().entries.toList().reversed.take(5).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Direct Chats',
                  style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () async {
                    await box.clear();
                  },
                  child: const Text('Clear', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => SizedBox(height: 8.h),
              itemBuilder: (context, index) {
                final entry = items[index];
                final item = entry.value as Map;
                final phone = item['phone']?.toString() ?? '';
                final msg = item['message']?.toString() ?? '';
                final isBiz = item['isBusiness'] == true;

                return Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                  child: ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      backgroundColor: isBiz ? Colors.teal.withOpacity(0.15) : Colors.green.withOpacity(0.15),
                      child: Icon(isBiz ? Icons.storefront : Icons.chat, color: isBiz ? Colors.teal : Colors.green, size: 18),
                    ),
                    title: Text(phone, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: msg.isNotEmpty ? Text(msg, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
                    trailing: IconButton(
                      icon: const Icon(Icons.replay, color: Colors.green, size: 20),
                      tooltip: 'Reuse',
                      onPressed: () {
                        _phoneController.text = phone.replaceAll(RegExp(r'\D'), '');
                        _messageController.text = msg;
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
