import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MediaCleanerScreen extends ConsumerWidget {
  const MediaCleanerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MediaCleanerScreen'),
      ),
      body: const Center(
        child: Text('MediaCleanerScreen is under construction'),
      ),
    );
  }
}
