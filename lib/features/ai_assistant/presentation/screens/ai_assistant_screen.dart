import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/storage/hive_storage_service.dart';
import 'package:chatflow/features/ai_assistant/services/ai_service.dart';

class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final _aiService = AiService();
  final _promptController = TextEditingController();
  final _resultController = TextEditingController();

  AiReplyTone _selectedTone = AiReplyTone.professional;
  bool _isLoading = false;

  @override
  void dispose() {
    _promptController.dispose();
    _resultController.dispose();
    super.dispose();
  }

  Future<void> _generateReply() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message to generate a reply')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final reply = await _aiService.generateReply(
        prompt: prompt,
        tone: _selectedTone,
      );
      if (mounted) {
        setState(() {
          _resultController.text = reply;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating reply: $e')),
        );
      }
    }
  }

  void _copyResult() {
    final text = _resultController.text.trim();
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('AI reply copied to clipboard!')),
    );
  }

  Future<void> _shareToWhatsApp() async {
    final text = _resultController.text.trim();
    if (text.isEmpty) return;
    final encoded = Uri.encodeComponent(text);
    final url = Uri.parse('whatsapp://send?text=$encoded');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _copyResult();
    }
  }

  void _showConfigureAiDialog() {
    final endpointCtrl = TextEditingController(
      text: HiveStorageService.settings.get('ai_endpoint', defaultValue: ''),
    );
    final keyCtrl = TextEditingController(
      text: HiveStorageService.settings.get('ai_api_key', defaultValue: ''),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: const Text('Configure AI Service'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Chatflow uses an offline linguistic assistant by default. Optionally connect your own OpenAI or proxy endpoint:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: endpointCtrl,
                decoration: const InputDecoration(
                  labelText: 'Custom Endpoint URL',
                  hintText: 'https://api.openai.com/v1/chat/completions',
                ),
              ),
              SizedBox(height: 10.h),
              TextField(
                controller: keyCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'API Key (Optional)',
                  hintText: 'sk-...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await HiveStorageService.settings.put('ai_endpoint', endpointCtrl.text.trim());
              await HiveStorageService.settings.put('ai_api_key', keyCtrl.text.trim());
              Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('AI settings updated!')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Reply Assistant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Configure AI Service',
            onPressed: _showConfigureAiDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Generate intelligent WhatsApp replies, rewrite texts, or fix grammar instantly.',
              style: TextStyle(color: Colors.grey[600], fontSize: 13.sp),
            ),
            SizedBox(height: 14.h),

            // Prompt text field
            TextField(
              controller: _promptController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Incoming Message / Context',
                hintText: 'Paste a message you received, or type what you want to say...',
                filled: true,
                fillColor: isDark ? const Color(0xFF202C33) : Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r)),
              ),
            ),
            SizedBox(height: 14.h),

            // Tone Selectors
            Text(
              'Select Response Style / Tone',
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                _buildToneChip(AiReplyTone.professional, '💼 Professional'),
                _buildToneChip(AiReplyTone.friendly, '😊 Friendly'),
                _buildToneChip(AiReplyTone.short, '⚡ Short & Fast'),
                _buildToneChip(AiReplyTone.business, '🏢 Business'),
                _buildToneChip(AiReplyTone.rewriting, '✍️ Rewrite'),
                _buildToneChip(AiReplyTone.grammarCorrection, '🔍 Fix Grammar'),
              ],
            ),
            SizedBox(height: 16.h),

            // Generate Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _generateReply,
              icon: _isLoading
                  ? SizedBox(
                      width: 18.w,
                      height: 18.w,
                      child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(
                _isLoading ? 'Generating...' : 'Generate AI Reply',
                style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
              ),
            ),
            SizedBox(height: 20.h),

            // Result container
            if (_resultController.text.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Generated Response (Editable)',
                    style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      'Ready to Send',
                      style: TextStyle(fontSize: 10.sp, color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              TextField(
                controller: _resultController,
                maxLines: 5,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark ? const Color(0xFF202C33) : Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r)),
                ),
              ),
              SizedBox(height: 14.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _copyResult,
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy Reply'),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _shareToWhatsApp,
                      icon: const Icon(Icons.send, size: 16),
                      label: const Text('Share to WhatsApp'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildToneChip(AiReplyTone tone, String label) {
    final isSelected = _selectedTone == tone;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedTone = tone),
    );
  }
}
