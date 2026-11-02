import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:chatflow/features/ai_assistant/services/ai_service.dart';

class AiTranslatorScreen extends ConsumerStatefulWidget {
  const AiTranslatorScreen({super.key});

  @override
  ConsumerState<AiTranslatorScreen> createState() => _AiTranslatorScreenState();
}

class _AiTranslatorScreenState extends ConsumerState<AiTranslatorScreen> {
  final _aiService = AiService();
  final _inputController = TextEditingController();
  final _translatedController = TextEditingController();

  String _sourceLang = 'Hindi';
  String _targetLang = 'English';
  bool _isFormal = true;
  bool _isTranslating = false;

  final List<String> _languages = [
    'Hindi',
    'English',
    'Spanish',
    'French',
    'German',
    'Arabic',
  ];

  @override
  void dispose() {
    _inputController.dispose();
    _translatedController.dispose();
    super.dispose();
  }

  void _swapLanguages() {
    setState(() {
      final temp = _sourceLang;
      _sourceLang = _targetLang;
      _targetLang = temp;
      final tempText = _inputController.text;
      _inputController.text = _translatedController.text;
      _translatedController.text = tempText;
    });
  }

  Future<void> _translate() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter text to translate')),
      );
      return;
    }

    setState(() => _isTranslating = true);

    try {
      final result = await _aiService.translateText(
        text: text,
        sourceLang: _sourceLang,
        targetLang: _targetLang,
        isFormal: _isFormal,
      );
      if (mounted) {
        setState(() {
          _translatedController.text = result;
          _isTranslating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isTranslating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Translation error: $e')),
        );
      }
    }
  }

  void _copyTranslation() {
    final text = _translatedController.text.trim();
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Translation copied to clipboard!')),
    );
  }

  Future<void> _shareToWhatsApp() async {
    final text = _translatedController.text.trim();
    if (text.isEmpty) return;
    final encoded = Uri.encodeComponent(text);
    final url = Uri.parse('whatsapp://send?text=$encoded');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _copyTranslation();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Message Translator'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Language selector card with swap button
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.r)),
              elevation: 1.5,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _sourceLang,
                          isExpanded: true,
                          items: _languages.map((l) => DropdownMenuItem(value: l, child: Text(l, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _sourceLang = val);
                          },
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.swap_horiz, color: Color(0xFF25D366)),
                      onPressed: _swapLanguages,
                    ),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _targetLang,
                          isExpanded: true,
                          items: _languages.map((l) => DropdownMenuItem(value: l, child: Text(l, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _targetLang = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12.h),

            // Mode toggle: Formal vs Informal
            Row(
              children: [
                ChoiceChip(
                  label: const Text('Formal Translation'),
                  selected: _isFormal,
                  onSelected: (val) => setState(() => _isFormal = true),
                ),
                SizedBox(width: 8.w),
                ChoiceChip(
                  label: const Text('Casual / Informal'),
                  selected: !_isFormal,
                  onSelected: (val) => setState(() => _isFormal = false),
                ),
              ],
            ),
            SizedBox(height: 14.h),

            // Input Text
            TextField(
              controller: _inputController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Enter text in $_sourceLang',
                hintText: 'e.g. नमस्ते, आप कैसे हैं? / Hello, how are you?',
                filled: true,
                fillColor: isDark ? const Color(0xFF202C33) : Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r)),
              ),
            ),
            SizedBox(height: 14.h),

            // Translate button
            ElevatedButton.icon(
              onPressed: _isTranslating ? null : _translate,
              icon: _isTranslating
                  ? SizedBox(
                      width: 18.w,
                      height: 18.w,
                      child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.translate),
              label: Text(
                _isTranslating ? 'Translating...' : 'Translate to $_targetLang',
                style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
              ),
            ),
            SizedBox(height: 18.h),

            // Translation result
            if (_translatedController.text.isNotEmpty) ...[
              Text(
                'Translation Result ($_targetLang)',
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8.h),
              TextField(
                controller: _translatedController,
                maxLines: 4,
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
                      onPressed: _copyTranslation,
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy'),
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
}
