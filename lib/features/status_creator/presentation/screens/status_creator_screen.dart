import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StatusCreatorScreen extends ConsumerWidget {
  const StatusCreatorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Status Creator')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 300,
              height: 400,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Colors.purple, Colors.pink]),
              ),
              child: const Center(
                child: Text('Type your status here', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(icon: const Icon(Icons.color_lens), onPressed: () {}),
                IconButton(icon: const Icon(Icons.text_fields), onPressed: () {}),
                ElevatedButton(onPressed: () {}, child: const Text('Save')),
              ],
            )
          ],
        ),
      ),
    );
  }
}
