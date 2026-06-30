import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StatusSaverScreen extends ConsumerStatefulWidget {
  const StatusSaverScreen({super.key});

  @override
  ConsumerState<StatusSaverScreen> createState() => _StatusSaverScreenState();
}

class _StatusSaverScreenState extends ConsumerState<StatusSaverScreen> {
  List<FileSystemEntity> _statuses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatuses();
  }

  Future<void> _loadStatuses() async {
    setState(() => _isLoading = true);
    
    // Check multiple possible paths
    final paths = [
      '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/.Statuses',
      '/storage/emulated/0/WhatsApp/Media/.Statuses',
      '/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/.Statuses',
    ];

    List<FileSystemEntity> foundStatuses = [];

    for (var path in paths) {
      final dir = Directory(path);
      if (await dir.exists()) {
        final items = dir.listSync();
        foundStatuses.addAll(items.where((item) {
          if (item is! File) return false;
          final ext = item.path.split('.').last.toLowerCase();
          return ext == 'jpg' || ext == 'mp4' || ext == 'gif';
        }));
      }
    }

    setState(() {
      _statuses = foundStatuses;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Status Saver'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStatuses,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _statuses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.hourglass_empty, size: 64, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 16),
                      const Text('No Statuses Found', style: TextStyle(fontSize: 18)),
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'Make sure you have viewed statuses in WhatsApp and granted storage permissions.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _statuses.length,
                  itemBuilder: (context, index) {
                    final file = _statuses[index] as File;
                    final isVideo = file.path.endsWith('.mp4');
                    
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          isVideo 
                            ? Container(
                                color: Colors.black87,
                                child: const Icon(Icons.play_circle_outline, color: Colors.white, size: 48),
                              )
                            : Image.file(file, fit: BoxFit.cover),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              color: Colors.black54,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.download, color: Colors.white),
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Saved to gallery! (Mocked)')),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.share, color: Colors.white),
                                    onPressed: () {},
                                  ),
                                ],
                              ),
                            ),
                          )
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
