import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

class TextFormatterScreen extends ConsumerStatefulWidget {
  const TextFormatterScreen({super.key});

  @override
  ConsumerState<TextFormatterScreen> createState() => _TextFormatterScreenState();
}

class _TextFormatterScreenState extends ConsumerState<TextFormatterScreen> {
  final _inputController = TextEditingController(text: 'Hello WhatsApp');
  String _inputText = 'Hello WhatsApp';

  final List<String> _quickEmojis = [
    '👋', '✨', '🔥', '🎉', '🚀', '💯', '🙏', '❤️', '💼', '📌', '⚠️', '✅', '🕒', '💰', '👍'
  ];

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _applyFormat(String prefix, String suffix) {
    final text = _inputController.text;
    final selection = _inputController.selection;
    if (selection.start >= 0 && selection.end > selection.start) {
      final selectedText = text.substring(selection.start, selection.end);
      final newText = text.replaceRange(selection.start, selection.end, '$prefix$selectedText$suffix');
      _inputController.text = newText;
      setState(() => _inputText = newText);
    } else {
      final newText = '$prefix$text$suffix';
      _inputController.text = newText;
      setState(() => _inputText = newText);
    }
  }

  void _insertEmoji(String emoji) {
    final text = _inputController.text;
    final selection = _inputController.selection;
    final pos = selection.start >= 0 ? selection.start : text.length;
    final newText = text.replaceRange(pos, pos, emoji);
    _inputController.text = newText;
    _inputController.selection = TextSelection.collapsed(offset: pos + emoji.length);
    setState(() => _inputText = newText);
  }

  void _copyText(String text) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied formatted text!')),
    );
  }

  Future<void> _shareToWhatsApp(String text) async {
    if (text.isEmpty) return;
    final encoded = Uri.encodeComponent(text);
    final url = Uri.parse('whatsapp://send?text=$encoded');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      final webUrl = Uri.parse('https://api.whatsapp.com/send?text=$encoded');
      if (await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      } else {
        _copyText(text);
      }
    }
  }

  // Unicode font transformers
  List<Map<String, String>> _generateUnicodeStyles(String input) {
    if (input.isEmpty) input = 'Type something';

    final styles = <Map<String, String>>[];
    styles.add({'name': 'WhatsApp Bold (*text*)', 'text': '*$input*'});
    styles.add({'name': 'WhatsApp Italic (_text_)', 'text': '_${input}_'});
    styles.add({'name': 'WhatsApp Strikethrough (~text~)', 'text': '~$input~'});
    styles.add({'name': 'WhatsApp Monospace (```text```)', 'text': '```$input```'});
    styles.add({'name': 'Bold Sans Unicode', 'text': _convertMath(input, 0x1D5D4, 0x1D5EE, 0x1D7EC)});
    styles.add({'name': 'Italic Serif Unicode', 'text': _convertMath(input, 0x1D434, 0x1D44E, null)});
    styles.add({'name': 'Cursive Bold Script', 'text': _convertMath(input, 0x1D4D0, 0x1D4EA, null)});
    styles.add({'name': 'Double Struck / Outline', 'text': _convertMath(input, 0x1D538, 0x1D552, 0x1D7D8)});
    styles.add({'name': 'Bubble / Circled', 'text': _convertCircled(input)});
    styles.add({'name': 'Small Caps', 'text': _convertSmallCaps(input)});
    styles.add({'name': 'Aesthetic Spaced', 'text': input.split('').join(' ')});

    return styles;
  }

  String _convertMath(String str, int upperBase, int lowerBase, int? digitBase) {
    final buffer = StringBuffer();
    for (var code in str.runes) {
      if (code >= 65 && code <= 90) {
        buffer.writeCharCode(upperBase + (code - 65));
      } else if (code >= 97 && code <= 122) {
        buffer.writeCharCode(lowerBase + (code - 97));
      } else if (digitBase != null && code >= 48 && code <= 57) {
        buffer.writeCharCode(digitBase + (code - 48));
      } else {
        buffer.writeCharCode(code);
      }
    }
    return buffer.toString();
  }

  String _convertCircled(String str) {
    final buffer = StringBuffer();
    for (var code in str.runes) {
      if (code >= 65 && code <= 90) {
        buffer.writeCharCode(0x24B6 + (code - 65));
      } else if (code >= 97 && code <= 122) {
        buffer.writeCharCode(0x24D0 + (code - 97));
      } else if (code >= 49 && code <= 57) {
        buffer.writeCharCode(0x2460 + (code - 49));
      } else if (code == 48) {
        buffer.writeCharCode(0x24EA);
      } else {
        buffer.writeCharCode(code);
      }
    }
    return buffer.toString();
  }

  String _convertSmallCaps(String str) {
    const normal = 'abcdefghijklmnopqrstuvwxyz';
    const smallCaps = 'ᴀʙᴄᴅᴇғɢʜɪᴊᴋʟᴍɴᴏᴘǫʀsᴛᴜᴠᴡxʏᴢ';
    final buffer = StringBuffer();
    for (var char in str.split('')) {
      final index = normal.indexOf(char.toLowerCase());
      if (index != -1) {
        buffer.write(smallCaps[index]);
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final styles = _generateUnicodeStyles(_inputText);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Text Formatter'),
      ),
      body: Column(
        children: [
          // Text Input Box
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _inputController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Enter text to format or style',
                    filled: true,
                    fillColor: isDark ? const Color(0xFF202C33) : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r)),
                  ),
                  onChanged: (val) => setState(() => _inputText = val.trim()),
                ),
                SizedBox(height: 10.h),

                // Formatting Quick Actions Bar
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.format_bold, size: 16),
                        label: const Text('Bold *'),
                        onPressed: () => _applyFormat('*', '*'),
                      ),
                      SizedBox(width: 8.w),
                      ActionChip(
                        avatar: const Icon(Icons.format_italic, size: 16),
                        label: const Text('Italic _'),
                        onPressed: () => _applyFormat('_', '_'),
                      ),
                      SizedBox(width: 8.w),
                      ActionChip(
                        avatar: const Icon(Icons.format_strikethrough, size: 16),
                        label: const Text('Strikethrough ~'),
                        onPressed: () => _applyFormat('~', '~'),
                      ),
                      SizedBox(width: 8.w),
                      ActionChip(
                        avatar: const Icon(Icons.code, size: 16),
                        label: const Text('Monospace ```'),
                        onPressed: () => _applyFormat('```', '```'),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8.h),

                // Quick Emoji Bar
                SizedBox(
                  height: 38.h,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _quickEmojis.length,
                    separatorBuilder: (_, __) => SizedBox(width: 6.w),
                    itemBuilder: (context, i) {
                      final emoji = _quickEmojis[i];
                      return InkWell(
                        onTap: () => _insertEmoji(emoji),
                        borderRadius: BorderRadius.circular(8.r),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Center(
                            child: Text(emoji, style: TextStyle(fontSize: 18.sp)),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Styled Results List
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.all(16.w),
              itemCount: styles.length,
              separatorBuilder: (_, __) => SizedBox(height: 10.h),
              itemBuilder: (context, index) {
                final item = styles[index];
                final name = item['name']!;
                final styledText = item['text']!;

                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                  elevation: 1.2,
                  child: Padding(
                    padding: EdgeInsets.all(14.w),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: TextStyle(fontSize: 11.sp, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                              SizedBox(height: 6.h),
                              Text(styledText, style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 20),
                          tooltip: 'Copy',
                          onPressed: () => _copyText(styledText),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send, color: Color(0xFF25D366), size: 20),
                          tooltip: 'Share on WhatsApp',
                          onPressed: () => _shareToWhatsApp(styledText),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
