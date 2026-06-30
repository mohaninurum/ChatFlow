import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile & About')),
      body: ListView(
        children: [
          const SizedBox(height: 32),
          const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50)),
          const SizedBox(height: 16),
          const Center(child: Text('ChatFlow User', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
          const Center(child: Text('Version 1.0.0', style: TextStyle(color: Colors.grey))),
          const SizedBox(height: 32),
          const Divider(),
          ListTile(leading: const Icon(Icons.share), title: const Text('Share App'), onTap: () {}),
          ListTile(leading: const Icon(Icons.star), title: const Text('Rate Us'), onTap: () {}),
          ListTile(leading: const Icon(Icons.privacy_tip), title: const Text('Privacy Policy'), onTap: () {}),
          ListTile(leading: const Icon(Icons.info), title: const Text('About Developer'), onTap: () {}),
        ],
      ),
    );
  }
}
