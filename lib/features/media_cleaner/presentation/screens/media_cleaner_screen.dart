import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MediaCleanerScreen extends ConsumerWidget {
  const MediaCleanerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Media Cleaner')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Icon(Icons.cleaning_services, size: 80, color: Colors.orange),
            const SizedBox(height: 24),
            const Text('Scan and clean junk files from WhatsApp to free up space.', textAlign: TextAlign.center),
            const SizedBox(height: 32),
            Card(
              child: ListTile(
                leading: const Icon(Icons.image),
                title: const Text('Images (Junk)'),
                subtitle: const Text('234 MB'),
                trailing: const Icon(Icons.delete_outline, color: Colors.red),
                onTap: () {},
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.video_library),
                title: const Text('Videos (Duplicates)'),
                subtitle: const Text('1.2 GB'),
                trailing: const Icon(Icons.delete_outline, color: Colors.red),
                onTap: () {},
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cleaning up 1.4 GB...')));
                },
                child: const Text('Clean Now (1.4 GB)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
