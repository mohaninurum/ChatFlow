import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class QrToolsScreen extends ConsumerStatefulWidget {
  const QrToolsScreen({super.key});

  @override
  ConsumerState<QrToolsScreen> createState() => _QrToolsScreenState();
}

class _QrToolsScreenState extends ConsumerState<QrToolsScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('QR Tools'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Scan QR'), Tab(text: 'Generate QR')],
          ),
        ),
        body: TabBarView(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.qr_code_scanner, size: 120, color: Colors.grey),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Open Camera to Scan'),
                  )
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const TextField(
                    decoration: InputDecoration(labelText: 'Enter text to generate QR', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    width: 200, height: 200, color: Colors.grey[300],
                    child: const Center(child: Icon(Icons.qr_code, size: 100)),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: () {}, child: const Text('Save QR Code')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
