import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TextToolsScreen extends ConsumerWidget {
  const TextToolsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TextToolsScreen'),
      ),
      body: const Center(
        child: Text('TextToolsScreen is under construction'),
      ),
    );
  }
}
