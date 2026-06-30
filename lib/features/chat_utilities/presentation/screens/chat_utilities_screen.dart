import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatUtilitiesScreen extends ConsumerWidget {
  const ChatUtilitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ChatUtilitiesScreen'),
      ),
      body: const Center(
        child: Text('ChatUtilitiesScreen is under construction'),
      ),
    );
  }
}
