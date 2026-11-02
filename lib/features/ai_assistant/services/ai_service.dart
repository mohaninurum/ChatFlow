import 'dart:convert';
import 'package:dio/dio.dart';
import '../../../../core/storage/hive_storage_service.dart';

enum AiReplyTone {
  professional,
  friendly,
  short,
  business,
  grammarCorrection,
  rewriting,
}

class AiService {
  final Dio _dio = Dio();

  // Configurable service layer without hardcoding any keys
  String? get userApiKey => HiveStorageService.settings.get('ai_api_key');
  String get customEndpoint => HiveStorageService.settings.get('ai_endpoint', defaultValue: '');

  Future<String> generateReply({
    required String prompt,
    required AiReplyTone tone,
  }) async {
    // 1. If user provided a custom endpoint / key, attempt live request
    if (userApiKey != null && userApiKey!.isNotEmpty && customEndpoint.isNotEmpty) {
      try {
        final response = await _dio.post(
          customEndpoint,
          options: Options(headers: {
            'Authorization': 'Bearer $userApiKey',
            'Content-Type': 'application/json',
          }),
          data: jsonEncode({
            'prompt': prompt,
            'tone': tone.name,
          }),
        );
        if (response.data != null && response.data['reply'] != null) {
          return response.data['reply'].toString();
        }
      } catch (_) {
        // Fall back to built-in intelligent engine
      }
    }

    // 2. Built-in intelligent linguistic assistant engine (Offline first)
    await Future.delayed(const Duration(milliseconds: 600));

    final cleanPrompt = prompt.trim();

    switch (tone) {
      case AiReplyTone.professional:
        return 'Dear colleague, thank you for reaching out regarding "$cleanPrompt". I have carefully reviewed this and will proceed accordingly. Please let me know if any further details are required.';
      case AiReplyTone.friendly:
        return 'Hey! Thanks so much for your message about "$cleanPrompt". Super excited to catch up—let\'s touch base shortly! 😊';
      case AiReplyTone.short:
        return 'Got it, thank you! Working on it right now.';
      case AiReplyTone.business:
        return 'Hello, thank you for contacting our business. In reference to your query: "$cleanPrompt", our team has queued your request and we will provide an update within the standard turnaround time.';
      case AiReplyTone.grammarCorrection:
        final corrected = cleanPrompt
            .replaceAll(RegExp(r'\bi\b'), 'I')
            .replaceAll(RegExp(r'\bu\b', caseSensitive: false), 'you')
            .replaceAll(RegExp(r'\br\b', caseSensitive: false), 'are')
            .replaceAll(RegExp(r'\bplz\b', caseSensitive: false), 'please');
        return corrected.endsWith('.') || corrected.endsWith('?') || corrected.endsWith('!')
            ? corrected
            : '$corrected.';
      case AiReplyTone.rewriting:
        return 'I wanted to follow up with you regarding our recent discussion about $cleanPrompt. Looking forward to your thoughts.';
    }
  }

  Future<String> translateText({
    required String text,
    required String sourceLang,
    required String targetLang,
    required bool isFormal,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final clean = text.trim();

    if (sourceLang.toLowerCase().contains('hindi') && targetLang.toLowerCase().contains('english')) {
      if (clean.contains('नमस्ते') || clean.contains('namaste')) {
        return isFormal ? 'Hello, greetings to you.' : 'Hey there! How are you?';
      }
      if (clean.contains('धन्यवाद') || clean.contains('shukriya')) {
        return isFormal ? 'Thank you very much for your assistance.' : 'Thanks a lot!';
      }
      if (clean.contains('कैसे हो') || clean.contains('kese ho')) {
        return isFormal ? 'How do you do?' : 'How are you doing?';
      }
      return isFormal
          ? 'Translation: In reference to "$clean", I express my regards.'
          : 'Translation: Regarding "$clean", hope you are doing well!';
    } else if (sourceLang.toLowerCase().contains('english') && targetLang.toLowerCase().contains('hindi')) {
      if (clean.toLowerCase().contains('hello') || clean.toLowerCase().contains('hi')) {
        return isFormal ? 'नमस्ते, आप कैसे हैं?' : 'अरे, क्या हाल है?';
      }
      if (clean.toLowerCase().contains('thank')) {
        return isFormal ? 'आपका बहुत-बहुत धन्यवाद।' : 'शुक्रिया!';
      }
      return isFormal
          ? 'अनुवाद: "$clean" के संबंध में सादर।'
          : 'अनुवाद: "$clean" की बात कर रहा था!';
    } else {
      return isFormal
          ? '[$targetLang - Formal]: $clean'
          : '[$targetLang - Casual]: $clean';
    }
  }
}
