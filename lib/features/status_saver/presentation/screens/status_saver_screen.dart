import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:permission_handler/permission_handler.dart';

class StatusSaverScreen extends ConsumerStatefulWidget {
  const StatusSaverScreen({super.key});

  @override
  ConsumerState<StatusSaverScreen> createState() => _StatusSaverScreenState();
}

class _StatusSaverScreenState extends ConsumerState<StatusSaverScreen>
    with SingleTickerProviderStateMixin {
  static const _channel = MethodChannel('com.chatflow.app/channel');
  late TabController _tabController;

  List<File> _photos = [];
  List<File> _videos = [];
  bool _isLoading = true;
  bool _permissionDenied = false;

  final List<String> _whatsappPaths = [
    '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/.Statuses',
    '/storage/emulated/0/WhatsApp/Media/.Statuses',
    '/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/.Statuses',
    '/storage/emulated/0/WhatsApp Business/Media/.Statuses',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStatuses();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStatuses() async {
    setState(() {
      _isLoading = true;
      _permissionDenied = false;
    });

    // Request permissions
    final storageStatus = await Permission.storage.request();
    final photosStatus = await Permission.photos.request();
    final videosStatus = await Permission.videos.request();

    if (storageStatus.isDenied && photosStatus.isDenied && videosStatus.isDenied) {
      setState(() {
        _isLoading = false;
        _permissionDenied = true;
      });
      return;
    }

    final List<File> photos = [];
    final List<File> videos = [];

    for (var path in _whatsappPaths) {
      try {
        final dir = Directory(path);
        if (await dir.exists()) {
          final items = dir.listSync();
          for (var item in items) {
            if (item is File) {
              final ext = item.path.split('.').last.toLowerCase();
              if (ext == 'jpg' || ext == 'jpeg' || ext == 'png' || ext == 'webp') {
                photos.add(item);
              } else if (ext == 'mp4' || ext == 'mkv' || ext == '3gp') {
                videos.add(item);
              }
            }
          }
        }
      } catch (_) {
        // Ignored, try next path
      }
    }

    // Sort newest first
    try {
      photos.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      videos.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    } catch (_) {}

    setState(() {
      _photos = photos;
      _videos = videos;
      _isLoading = false;
    });
  }

  Future<void> _saveFile(File file) async {
    try {
      final filename = file.path.split('/').last.split('\\').last;
      final saveDir = Directory('/storage/emulated/0/Pictures/Chatflow');
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }
      final target = File('${saveDir.path}/$filename');
      await file.copy(target.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to Gallery (Pictures/Chatflow/$filename)'),
            backgroundColor: Colors.green[700],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  Future<void> _shareFile(File file, bool isVideo) async {
    try {
      final mime = isVideo ? 'video/mp4' : 'image/jpeg';
      await _channel.invokeMethod('shareFile', {
        'path': file.path,
        'mimeType': mime,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share file: $e')),
        );
      }
    }
  }

  Future<void> _openFile(File file, bool isVideo) async {
    if (isVideo) {
      try {
        await _channel.invokeMethod('openFile', {
          'path': file.path,
          'mimeType': 'video/mp4',
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error playing video: $e')),
          );
        }
      }
    } else {
      // Photo viewer dialog
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(10.w),
          child: Stack(
            alignment: Alignment.center,
            children: [
              InteractiveViewer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16.r),
                  child: Image.file(file, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
              ),
              Positioned(
                bottom: 10,
                child: Row(
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      icon: const Icon(Icons.download, color: Colors.white),
                      label: const Text('Save', style: TextStyle(color: Colors.white)),
                      onPressed: () {
                        _saveFile(file);
                        Navigator.pop(ctx);
                      },
                    ),
                    SizedBox(width: 12.w),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                      icon: const Icon(Icons.share, color: Colors.white),
                      label: const Text('Share', style: TextStyle(color: Colors.white)),
                      onPressed: () {
                        _shareFile(file, false);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Status Saver'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Statuses',
            onPressed: _loadStatuses,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.image_outlined),
              text: 'Images (${_photos.length})',
            ),
            Tab(
              icon: const Icon(Icons.video_library_outlined),
              text: 'Videos (${_videos.length})',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _permissionDenied
              ? _buildPermissionPrompt()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildMediaGrid(_photos, false),
                    _buildMediaGrid(_videos, true),
                  ],
                ),
    );
  }

  Widget _buildPermissionPrompt() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_special, size: 70.sp, color: Colors.orange),
            SizedBox(height: 16.h),
            const Text(
              'Storage Permission Required',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8.h),
            const Text(
              'ChatFlow needs permission to view WhatsApp Status media saved on your device.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 24.h),
            ElevatedButton(
              onPressed: _loadStatuses,
              child: const Text('Grant Permission'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaGrid(List<File> files, bool isVideo) {
    if (files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isVideo ? Icons.videocam_off_outlined : Icons.image_not_supported_outlined,
              size: 64.sp,
              color: Colors.grey,
            ),
            SizedBox(height: 16.h),
            Text(
              isVideo ? 'No Video Statuses Found' : 'No Photo Statuses Found',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8.h),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                'Open WhatsApp, view your friends\' statuses, then refresh here to download and share them.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
            SizedBox(height: 16.h),
            ElevatedButton.icon(
              onPressed: _loadStatuses,
              icon: const Icon(Icons.refresh),
              label: const Text('Check Again'),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(10.w),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10.w,
        mainAxisSpacing: 10.h,
        childAspectRatio: 0.82,
      ),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];

        return Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          elevation: 2,
          child: Stack(
            fit: StackFit.expand,
            children: [
              InkWell(
                onTap: () => _openFile(file, isVideo),
                child: isVideo
                    ? Container(
                        color: Colors.black87,
                        child: Center(
                          child: Icon(
                            Icons.play_circle_fill,
                            color: Colors.white.withOpacity(0.85),
                            size: 54.sp,
                          ),
                        ),
                      )
                    : Image.file(
                        file,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black87, Colors.transparent],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.download_rounded, color: Colors.white),
                        tooltip: 'Save to Gallery',
                        onPressed: () => _saveFile(file),
                      ),
                      IconButton(
                        icon: const Icon(Icons.share_rounded, color: Colors.white),
                        tooltip: 'Share',
                        onPressed: () => _shareFile(file, isVideo),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
