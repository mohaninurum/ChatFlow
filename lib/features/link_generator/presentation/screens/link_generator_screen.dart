import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/storage/hive_storage_service.dart';
import '../../../../core/utils/country_codes.dart';

class LinkGeneratorScreen extends ConsumerStatefulWidget {
  const LinkGeneratorScreen({super.key});

  @override
  ConsumerState<LinkGeneratorScreen> createState() => _LinkGeneratorScreenState();
}

class _LinkGeneratorScreenState extends ConsumerState<LinkGeneratorScreen> {
  static const _channel = MethodChannel('com.chatflow.app/channel');
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();
  final GlobalKey _qrKey = GlobalKey();

  CountryCodeItem _selectedCountry = allCountryCodes.first;
  String _generatedUrl = '';

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_rebuildUrl);
    _messageController.addListener(_rebuildUrl);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _rebuildUrl() {
    final cleanPhone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    final cleanCode = _selectedCountry.dialCode.replaceAll('+', '').trim();
    final message = _messageController.text.trim();

    if (cleanPhone.isNotEmpty) {
      final fullNumber = '$cleanCode$cleanPhone';
      final encoded = Uri.encodeComponent(message);
      setState(() {
        _generatedUrl = message.isNotEmpty
            ? 'https://wa.me/$fullNumber?text=$encoded'
            : 'https://wa.me/$fullNumber';
      });
    } else {
      if (_generatedUrl.isNotEmpty) {
        setState(() => _generatedUrl = '');
      }
    }
  }

  Future<void> _saveToHistory() async {
    if (_generatedUrl.isEmpty) return;
    final cleanPhone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    final fullNumber = '${_selectedCountry.dialCode}$cleanPhone';

    await HiveStorageService.history.add({
      'type': 'link_generator',
      'phone': fullNumber,
      'url': _generatedUrl,
      'message': _messageController.text.trim(),
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void _copyLink() {
    if (_generatedUrl.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _generatedUrl));
    _saveToHistory();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('WhatsApp link copied to clipboard!')),
    );
  }

  Future<void> _shareLink() async {
    if (_generatedUrl.isEmpty) return;
    _saveToHistory();
    try {
      await _channel.invokeMethod('shareText', {
        'text': _generatedUrl,
        'title': 'Share WhatsApp Link',
      });
    } catch (_) {
      _copyLink();
    }
  }

  Future<void> _downloadQrCode() async {
    if (_generatedUrl.isEmpty) return;
    try {
      final boundary = _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final pngBytes = byteData.buffer.asUint8List();
      final dir = Directory('/storage/emulated/0/Pictures/Chatflow');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final fileName = 'wa_qr_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(pngBytes);

      _saveToHistory();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('QR Code saved to Pictures/Chatflow/$fileName'),
            backgroundColor: const Color(0xFF25D366),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save QR code: $e')),
        );
      }
    }
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filtered = allCountryCodes.where((c) {
              final q = query.toLowerCase();
              return c.name.toLowerCase().contains(q) || c.dialCode.contains(q);
            }).toList();

            return Container(
              height: 480.h,
              padding: EdgeInsets.all(16.w),
              child: Column(
                children: [
                  Text('Select Country Code', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10.h),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search country...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14.r)),
                    ),
                    onChanged: (val) => setSheetState(() => query = val),
                  ),
                  SizedBox(height: 10.h),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return ListTile(
                          leading: Text(item.flag, style: TextStyle(fontSize: 22.sp)),
                          title: Text(item.name),
                          trailing: Text(item.dialCode, style: const TextStyle(fontWeight: FontWeight.bold)),
                          onTap: () {
                            setState(() {
                              _selectedCountry = item;
                              _rebuildUrl();
                            });
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('WhatsApp Link Generator'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Create direct wa.me chat links & QR codes for your business or profile.',
              style: TextStyle(color: Colors.grey[600], fontSize: 13.sp),
            ),
            SizedBox(height: 16.h),

            // Phone input with country code
            Row(
              children: [
                InkWell(
                  onTap: _showCountryPicker,
                  borderRadius: BorderRadius.circular(14.r),
                  child: Container(
                    height: 54.h,
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(14.r),
                      color: isDark ? const Color(0xFF202C33) : Colors.white,
                    ),
                    child: Row(
                      children: [
                        Text(_selectedCountry.flag, style: TextStyle(fontSize: 20.sp)),
                        SizedBox(width: 6.w),
                        Text(_selectedCountry.dialCode, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const Icon(Icons.arrow_drop_down, color: Colors.grey),
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
                      filled: true,
                      fillColor: isDark ? const Color(0xFF202C33) : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14.r)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),

            // Predefined message input
            TextField(
              controller: _messageController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Predefined Message (Optional)',
                hintText: "e.g. Hello, I'm interested in your product catalog!",
                filled: true,
                fillColor: isDark ? const Color(0xFF202C33) : Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14.r)),
              ),
            ),
            SizedBox(height: 20.h),

            // Generated Link & QR Container
            if (_generatedUrl.isNotEmpty) ...[
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                elevation: 2,
                child: Padding(
                  padding: EdgeInsets.all(20.w),
                  child: Column(
                    children: [
                      // QR Code widget wrapped in RepaintBoundary
                      Center(
                        child: RepaintBoundary(
                          key: _qrKey,
                          child: Container(
                            color: Colors.white,
                            padding: EdgeInsets.all(12.w),
                            child: QrImageView(
                              data: _generatedUrl,
                              version: QrVersions.auto,
                              size: 190.w,
                              backgroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      SelectableText(
                        _generatedUrl,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: const Color(0xFF128C7E)),
                      ),
                      SizedBox(height: 16.h),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _copyLink,
                              icon: const Icon(Icons.copy, size: 16),
                              label: const Text('Copy Link'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _shareLink,
                              icon: const Icon(Icons.share, size: 16),
                              label: const Text('Share Link'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      OutlinedButton.icon(
                        onPressed: _downloadQrCode,
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Save QR Code to Gallery'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size(double.infinity, 44.h),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24.h),
            ],

            // History Section
            _buildLinkHistory(),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkHistory() {
    return ValueListenableBuilder(
      valueListenable: HiveStorageService.history.listenable(),
      builder: (context, Box box, _) {
        final items = box.values
            .where((item) => item is Map && item['type'] == 'link_generator')
            .toList()
            .reversed
            .take(6)
            .toList();

        if (items.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Generated Link History',
              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8.h),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => SizedBox(height: 8.h),
              itemBuilder: (context, index) {
                final item = items[index] as Map;
                final phone = item['phone']?.toString() ?? '';
                final url = item['url']?.toString() ?? '';
                final msg = item['message']?.toString() ?? '';

                return Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE8F5E9),
                      child: Icon(Icons.qr_code, color: Color(0xFF25D366)),
                    ),
                    title: Text(phone, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(msg.isNotEmpty ? msg : url, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: url));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Link copied!')),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.open_in_new, size: 18, color: Colors.green),
                          onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                        ),
                      ],
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
