import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class OcrScreen extends ConsumerStatefulWidget {
  const OcrScreen({super.key});

  @override
  ConsumerState<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends ConsumerState<OcrScreen> {
  static const _channel = MethodChannel('com.chatflow.app/channel');
  final _picker = ImagePicker();
  final _textController = TextEditingController();

  File? _selectedImage;
  bool _isProcessing = false;
  String _selectedLanguage = 'English';

  final List<String> _languages = [
    'English',
    'Hindi (हिंदी)',
    'Spanish',
    'French',
    'German',
  ];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        final status = await Permission.camera.request();
        if (status.isDenied || status.isPermanentlyDenied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Camera permission is required to capture photos.')),
            );
          }
          return;
        }
      }

      final picked = await _picker.pickImage(source: source);
      if (picked != null) {
        setState(() {
          _selectedImage = File(picked.path);
          _isProcessing = true;
          _textController.clear();
        });

        await _processImageOcr(_selectedImage!);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting image: $e')),
        );
      }
    }
  }

  Future<void> _processImageOcr(File file) async {
    try {
      final String? extracted = await _channel.invokeMethod<String>(
        'extractTextFromImage',
        {
          'path': file.path,
          'language': _selectedLanguage,
        },
      );

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        if (extracted != null && extracted.trim().isNotEmpty) {
          _textController.text = extracted.trim();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Text extracted successfully! You can edit or send it below.'),
              backgroundColor: Color(0xFF25D366),
            ),
          );
        } else {
          _textController.text = '';
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No readable text detected in this image. Please ensure the image is clear and well-lit.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to extract text: $e')),
        );
      }
    }
  }

  void _copyExtractedText() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Extracted text copied to clipboard!')),
    );
  }

  Future<void> _shareToWhatsApp() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    try {
      final res = await _channel.invokeMethod('sendToWhatsApp', {'text': text});
      if (res != true) {
        final encoded = Uri.encodeComponent(text);
        final url = Uri.parse('whatsapp://send?text=$encoded');
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          await _channel.invokeMethod('shareText', {'text': text, 'title': 'Send Extracted Text'});
        }
      }
    } catch (_) {
      try {
        final encoded = Uri.encodeComponent(text);
        final url = Uri.parse('whatsapp://send?text=$encoded');
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          await _channel.invokeMethod('shareText', {'text': text, 'title': 'Send Extracted Text'});
        }
      } catch (_) {
        _copyExtractedText();
      }
    }
  }

  void _openInDirectChat() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    context.pushNamed('directChat', extra: text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasText = _textController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Image to Text (OCR)'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.language),
            tooltip: 'Select Language',
            onSelected: (val) {
              setState(() => _selectedLanguage = val);
              if (_selectedImage != null) {
                setState(() => _isProcessing = true);
                _processImageOcr(_selectedImage!);
              }
            },
            itemBuilder: (ctx) => _languages.map((l) => PopupMenuItem(value: l, child: Text(l))).toList(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Capture a photo or pick a document image to extract real text automatically.',
              style: TextStyle(color: Colors.grey[600], fontSize: 13.sp),
            ),
            SizedBox(height: 14.h),

            // Camera & Gallery action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                    ),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Scan with Camera'),
                    onPressed: () => _pickImage(ImageSource.camera),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                    ),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Select from Gallery'),
                    onPressed: () => _pickImage(ImageSource.gallery),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),

            // Image Preview thumbnail if selected
            if (_selectedImage != null) ...[
              Container(
                height: 180.h,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  image: DecorationImage(
                    image: FileImage(_selectedImage!),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Stack(
                  children: [
                    if (_isProcessing)
                      Container(
                        color: Colors.black54,
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: Colors.white),
                              SizedBox(height: 10),
                              Text('Scanning & extracting text...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    Positioned(
                      top: 8.h,
                      right: 8.w,
                      child: CircleAvatar(
                        backgroundColor: Colors.black54,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 18),
                          onPressed: () => setState(() {
                            _selectedImage = null;
                            _textController.clear();
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
            ],

            // Language & Header indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Extracted Text (Editable)',
                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    'Lang: $_selectedLanguage',
                    style: TextStyle(fontSize: 11.sp, color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),

            // Editable extracted text field
            TextField(
              controller: _textController,
              maxLines: 8,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Scanned text will appear here. You can edit and format it freely before sending.',
                filled: true,
                fillColor: isDark ? const Color(0xFF202C33) : Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r)),
                contentPadding: EdgeInsets.all(14.w),
              ),
            ),
            SizedBox(height: 16.h),

            // Copy and Share to WhatsApp actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: hasText ? _copyExtractedText : null,
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy Text'),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: hasText ? _shareToWhatsApp : null,
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text('Share to WhatsApp'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),

            // Send to Unsaved Number via Direct Chat
            OutlinedButton.icon(
              onPressed: hasText ? _openInDirectChat : null,
              icon: const Icon(Icons.quickreply_outlined, size: 18, color: Color(0xFF25D366)),
              label: const Text('Send to Unsaved Number (Direct Chat)'),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 13.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
              ),
            ),
            SizedBox(height: 24.h),
          ],
        ),
      ),
    );
  }
}
