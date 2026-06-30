import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FileManagerScreen extends ConsumerWidget {
  const FileManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FileManagerScreen'),
      ),
      body: const Center(
        child: Text('FileManagerScreen is under construction'),
      ),
    );
  }
}
