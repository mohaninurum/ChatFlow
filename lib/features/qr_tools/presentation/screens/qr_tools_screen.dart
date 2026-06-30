import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class QrToolsScreen extends ConsumerWidget {
  const QrToolsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QrToolsScreen'),
      ),
      body: const Center(
        child: Text('QrToolsScreen is under construction'),
      ),
    );
  }
}
