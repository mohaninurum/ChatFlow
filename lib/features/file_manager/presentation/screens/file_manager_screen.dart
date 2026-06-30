import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FileManagerScreen extends ConsumerWidget {
  const FileManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = [
      {'name': 'Images', 'icon': Icons.image, 'count': '243 files'},
      {'name': 'Videos', 'icon': Icons.video_file, 'count': '45 files'},
      {'name': 'Audio', 'icon': Icons.audio_file, 'count': '12 files'},
      {'name': 'Documents', 'icon': Icons.description, 'count': '89 files'},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('File Manager')),
      body: ListView.builder(
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          return ListTile(
            leading: CircleAvatar(child: Icon(cat['icon'] as IconData)),
            title: Text(cat['name'] as String),
            subtitle: Text(cat['count'] as String),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          );
        },
      ),
    );
  }
}
