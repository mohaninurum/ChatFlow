import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TextToolsScreen extends ConsumerStatefulWidget {
  const TextToolsScreen({super.key});

  @override
  ConsumerState<TextToolsScreen> createState() => _TextToolsScreenState();
}

class _TextToolsScreenState extends ConsumerState<TextToolsScreen> {
  final _textController = TextEditingController();
  final _countController = TextEditingController(text: '5');
  String _result = '';

  void _repeat() {
    int count = int.tryParse(_countController.text) ?? 1;
    setState(() {
      _result = List.filled(count, _textController.text).join('\n');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Text Tools')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _textController, decoration: const InputDecoration(labelText: 'Enter Text', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: _countController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Repeat Count', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(onPressed: _repeat, child: const Text('Repeat Text')),
                ElevatedButton(
                  onPressed: () => setState(() => _result = '‎\n' * (int.tryParse(_countController.text) ?? 5)),
                  child: const Text('Blank Text'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                child: SingleChildScrollView(child: Text(_result.isEmpty ? 'Result will appear here' : _result)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
