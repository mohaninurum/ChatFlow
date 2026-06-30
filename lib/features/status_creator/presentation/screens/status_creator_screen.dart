import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StatusCreatorScreen extends ConsumerWidget {
  const StatusCreatorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('StatusCreatorScreen'),
      ),
      body: const Center(
        child: Text('StatusCreatorScreen is under construction'),
      ),
    );
  }
}
