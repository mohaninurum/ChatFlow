import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/storage/hive_storage_service.dart';

enum StatusSortOrder { newest, oldest, largest, smallest }

class StatusSaverScreen extends ConsumerStatefulWidget {
  const StatusSaverScreen({super.key});

  @override
  ConsumerState<StatusSaverScreen> createState() => _StatusSaverScreenState();
}

class _StatusSaverScreenState extends ConsumerState<StatusSaverScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _channel = MethodChannel('com.chatflow.app/channel');
  late TabController _tabController;

  List<File> _photos = [];
  List<File> _videos = [];
  List<File> _savedDownloads = [];
  final Map<String, Uint8List> _videoThumbnails = {};
  bool _isLoading = true;
  bool _permissionDenied = false;

  // Multi-select state
  bool _isSelectionMode = false;
  final Set<String> _selectedFilePaths = {};

  // Sort & filter state
  StatusSortOrder _sortOrder = StatusSortOrder.newest;
  bool _showFavoritesOnly = false;
  final String _searchQuery = '';

  final List<String> _whatsappPaths = [
    // WhatsApp Standard
    '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/.Statuses',
    '/storage/emulated/0/WhatsApp/Media/.Statuses',
    '/sdcard/Android/media/com.whatsapp/WhatsApp/Media/.Statuses',
    '/sdcard/WhatsApp/Media/.Statuses',
    '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/Statuses',
    '/storage/emulated/0/WhatsApp/Media/Statuses',

    // WhatsApp Business
    '/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/.Statuses',
    '/storage/emulated/0/WhatsApp Business/Media/.Statuses',
    '/sdcard/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/.Statuses',
    '/sdcard/WhatsApp Business/Media/.Statuses',
    '/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/Statuses',
    '/storage/emulated/0/WhatsApp Business/Media/Statuses',

    // Cloned / Dual Apps (Samsung Dual Messenger, Xiaomi Dual Apps, OnePlus Parallel)
    '/storage/emulated/999/Android/media/com.whatsapp/WhatsApp/Media/.Statuses',
    '/storage/emulated/999/WhatsApp/Media/.Statuses',
    '/storage/emulated/999/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/.Statuses',
    '/storage/emulated/999/WhatsApp Business/Media/.Statuses',
    '/storage/emulated/10/Android/media/com.whatsapp/WhatsApp/Media/.Statuses',
    '/storage/emulated/10/WhatsApp/Media/.Statuses',
    '/storage/emulated/11/Android/media/com.whatsapp/WhatsApp/Media/.Statuses',
    '/storage/emulated/11/WhatsApp/Media/.Statuses',

    // Modded WhatsApp variants
    '/storage/emulated/0/Android/media/com.gbwhatsapp/GBWhatsApp/Media/.Statuses',
    '/storage/emulated/0/GBWhatsApp/Media/.Statuses',
    '/storage/emulated/0/Android/media/com.fmwhatsapp/FMWhatsApp/Media/.Statuses',
    '/storage/emulated/0/Android/media/com.yowhatsapp/YoWhatsApp/Media/.Statuses',
  ];

  final String _savedDirectoryPath = '/storage/emulated/0/Pictures/Chatflow';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadStatuses();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadStatuses();
    }
  }

  Future<void> _openWhatsApp() async {
    try {
      final waUri = Uri.parse('whatsapp://');
      if (await canLaunchUrl(waUri)) {
        await launchUrl(waUri, mode: LaunchMode.externalApplication);
      } else {
        final webUri = Uri.parse('https://chat.whatsapp.com');
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Future<void> _requestManageAccess() async {
    try {
      final res = await _channel.invokeMethod('requestManageStorage');
      if (res != true) {
        await openAppSettings();
      }
    } catch (_) {
      await openAppSettings();
    }
  }

  Future<void> _loadStatuses() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _permissionDenied = false;
      _isSelectionMode = false;
      _selectedFilePaths.clear();
    });

    // Check storage permissions
    bool isGranted = false;
    if (Platform.isAndroid) {
      try {
        isGranted = await _channel.invokeMethod('isManageStorageGranted') ?? false;
      } catch (_) {
        isGranted = await Permission.manageExternalStorage.isGranted;
      }

      if (!isGranted) {
        // Check standard media permissions as well
        final storage = await Permission.storage.isGranted;
        final photos = await Permission.photos.isGranted;
        final videos = await Permission.videos.isGranted;
        if (storage || photos || videos) {
          isGranted = true;
        } else {
          // Request permissions once
          await [
            Permission.storage,
            Permission.photos,
            Permission.videos,
          ].request();
          
          try {
            isGranted = await _channel.invokeMethod('isManageStorageGranted') ?? false;
          } catch (_) {}
        }
      }
    }

    final List<File> photos = [];
    final List<File> videos = [];
    final List<File> savedList = [];
    final Set<String> seenPaths = {};

    // 1. Scan via Native MethodChannel (covers all paths in background thread)
    try {
      final List<dynamic>? nativeMedia = await _channel.invokeMethod<List<dynamic>>('getStatusMedia');
      if (nativeMedia != null) {
        for (var p in nativeMedia) {
          final file = File(p.toString());
          if (file.existsSync() && seenPaths.add(file.path)) {
            final ext = file.path.split('.').last.toLowerCase();
            if (['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
              photos.add(file);
            } else if (['mp4', 'mkv', '3gp', 'mov', 'gif'].contains(ext)) {
              videos.add(file);
            }
          }
        }
      }
    } catch (_) {}

    // 2. Direct Dart scan across all WhatsApp paths for 100% thoroughness
    for (var path in _whatsappPaths) {
      try {
        final dir = Directory(path);
        final items = dir.listSync();
        for (var item in items) {
          if (item is File && seenPaths.add(item.path)) {
            final name = item.path.split('/').last.split('\\').last;
            if (name.startsWith('.nomedia') || name.endsWith('.tmp') || name.endsWith('.thumb')) {
              continue;
            }
            final ext = name.split('.').last.toLowerCase();
            if (['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
              photos.add(item);
            } else if (['mp4', 'mkv', '3gp', 'mov', 'gif'].contains(ext)) {
              videos.add(item);
            }
          }
        }
      } catch (_) {}
    }

    // 3. Scan Chatflow saved directory (Download History)
    try {
      final savedDir = Directory(_savedDirectoryPath);
      if (await savedDir.exists()) {
        final items = savedDir.listSync();
        for (var item in items) {
          if (item is File) {
            savedList.add(item);
          }
        }
      }
    } catch (_) {}

    _sortFiles(photos);
    _sortFiles(videos);
    _sortFiles(savedList);

    if (mounted) {
      // Auto-switch to Videos tab if no photos are available but video statuses are loaded!
      if (photos.isEmpty && videos.isNotEmpty && _tabController.index == 0) {
        _tabController.animateTo(1);
      }

      setState(() {
        _photos = photos;
        _videos = videos;
        _savedDownloads = savedList;
        _isLoading = false;
        // If files are loaded, permissions are working!
        _permissionDenied = (photos.isEmpty && videos.isEmpty && !isGranted);
      });

      // Prefetch thumbnails for videos in background
      for (var v in videos) {
        _fetchThumbnail(v.path);
      }
    }
  }

  void _sortFiles(List<File> list) {
    try {
      switch (_sortOrder) {
        case StatusSortOrder.newest:
          list.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
          break;
        case StatusSortOrder.oldest:
          list.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
          break;
        case StatusSortOrder.largest:
          list.sort((a, b) => b.lengthSync().compareTo(a.lengthSync()));
          break;
        case StatusSortOrder.smallest:
          list.sort((a, b) => a.lengthSync().compareTo(b.lengthSync()));
          break;
      }
    } catch (_) {}
  }

  Future<void> _saveFile(File file, {bool showNotification = true}) async {
    try {
      final filename = file.path.split('/').last.split('\\').last;
      final saveDir = Directory(_savedDirectoryPath);
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }
      final target = File('${saveDir.path}/$filename');
      await file.copy(target.path);

      // Track in download history box
      await HiveStorageService.statusDownloads.put(filename, {
        'filename': filename,
        'path': target.path,
        'savedAt': DateTime.now().toIso8601String(),
        'size': await target.length(),
      });

      // Update saved list
      if (!_savedDownloads.any((f) => f.path == target.path)) {
        _savedDownloads.insert(0, target);
      }

      if (showNotification && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to Gallery: $filename'),
            backgroundColor: const Color(0xFF25D366),
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () => _tabController.animateTo(2),
            ),
          ),
        );
      }
    } catch (e) {
      if (showNotification && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  Future<void> _batchDownloadSelected() async {
    if (_selectedFilePaths.isEmpty) return;

    int successCount = 0;
    for (var path in _selectedFilePaths) {
      final file = File(path);
      if (await file.exists()) {
        await _saveFile(file, showNotification: false);
        successCount++;
      }
    }

    setState(() {
      _isSelectionMode = false;
      _selectedFilePaths.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully downloaded $successCount statuses!'),
          backgroundColor: const Color(0xFF25D366),
        ),
      );
    }
  }

  Future<void> _deleteDownloadedFile(File file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Downloaded Media?'),
        content: const Text('This will delete the file permanently from Pictures/Chatflow on your device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        if (await file.exists()) {
          await file.delete();
        }
        final filename = file.path.split('/').last.split('\\').last;
        await HiveStorageService.statusDownloads.delete(filename);

        setState(() {
          _savedDownloads.removeWhere((f) => f.path == file.path);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Delete failed: $e')),
          );
        }
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

  Future<void> _fetchThumbnail(String videoPath) async {
    if (_videoThumbnails.containsKey(videoPath)) return;
    try {
      final Uint8List? bytes = await _channel.invokeMethod<Uint8List>('getVideoThumbnail', {
        'path': videoPath,
      });
      if (bytes != null && mounted) {
        setState(() {
          _videoThumbnails[videoPath] = bytes;
        });
      }
    } catch (_) {}
  }

  Widget _buildVideoThumbnailWidget(File file) {
    final bytes = _videoThumbnails[file.path];
    if (bytes == null) {
      _fetchThumbnail(file.path);
      return Container(
        color: Colors.black87,
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF25D366)),
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: Colors.black87,
            child: const Icon(Icons.videocam_outlined, color: Colors.white54),
          ),
        ),
        Container(
          color: Colors.black26,
        ),
        Center(
          child: CircleAvatar(
            radius: 22.r,
            backgroundColor: Colors.black54,
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
          ),
        ),
      ],
    );
  }

  Future<void> _openFile(File file, bool isVideo) async {
    if (isVideo) {
      try {
        await _channel.invokeMethod('playVideoFullscreen', {
          'path': file.path,
        });
      } catch (_) {
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
      }
    } else {
      // Photo viewer with pinch-to-zoom
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.black.withOpacity(0.9),
          insetPadding: EdgeInsets.zero,
          child: Stack(
            alignment: Alignment.center,
            children: [
              InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Image.file(file, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: 40.h,
                left: 16.w,
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
              ),
              Positioned(
                bottom: 30.h,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                      ),
                      icon: const Icon(Icons.download),
                      label: const Text('Save to Gallery'),
                      onPressed: () {
                        _saveFile(file);
                        Navigator.pop(ctx);
                      },
                    ),
                    SizedBox(width: 12.w),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                      ),
                      icon: const Icon(Icons.share),
                      label: const Text('Share'),
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

  List<File> _filterFiles(List<File> originalList) {
    var list = originalList;
    if (_showFavoritesOnly) {
      final favs = HiveStorageService.getFavoriteStatuses();
      list = list.where((f) => favs.contains(f.path)).toList();
    }
    if (_searchQuery.isNotEmpty) {
      list = list.where((f) {
        final name = f.path.split('/').last.split('\\').last.toLowerCase();
        return name.contains(_searchQuery.toLowerCase());
      }).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final filteredPhotos = _filterFiles(_photos);
    final filteredVideos = _filterFiles(_videos);
    final filteredSaved = _filterFiles(_savedDownloads);

    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode
            ? Text('${_selectedFilePaths.length} Selected')
            : const Text('Status Saver'),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _isSelectionMode = false;
                  _selectedFilePaths.clear();
                }),
              )
            : null,
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.select_all),
              tooltip: 'Select All',
              onPressed: () {
                setState(() {
                  final activeList = _tabController.index == 0
                      ? filteredPhotos
                      : (_tabController.index == 1 ? filteredVideos : filteredSaved);
                  _selectedFilePaths.addAll(activeList.map((f) => f.path));
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Download Selected',
              onPressed: _selectedFilePaths.isNotEmpty ? _batchDownloadSelected : null,
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              tooltip: 'Open WhatsApp',
              onPressed: _openWhatsApp,
            ),
            IconButton(
              icon: Icon(
                _showFavoritesOnly ? Icons.star : Icons.star_border,
                color: _showFavoritesOnly ? Colors.amber : null,
              ),
              tooltip: _showFavoritesOnly ? 'Show All' : 'Show Favorites Only',
              onPressed: () => setState(() => _showFavoritesOnly = !_showFavoritesOnly),
            ),
            PopupMenuButton<StatusSortOrder>(
              icon: const Icon(Icons.sort),
              tooltip: 'Sort statuses',
              onSelected: (order) {
                setState(() {
                  _sortOrder = order;
                  _sortFiles(_photos);
                  _sortFiles(_videos);
                  _sortFiles(_savedDownloads);
                });
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: StatusSortOrder.newest, child: Text('Newest First')),
                const PopupMenuItem(value: StatusSortOrder.oldest, child: Text('Oldest First')),
                const PopupMenuItem(value: StatusSortOrder.largest, child: Text('Largest Size')),
                const PopupMenuItem(value: StatusSortOrder.smallest, child: Text('Smallest Size')),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh Statuses',
              onPressed: _loadStatuses,
            ),
          ],
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          indicatorColor: theme.colorScheme.primary,
          tabs: [
            Tab(icon: const Icon(Icons.image_outlined), text: 'Photos (${_photos.length})'),
            Tab(icon: const Icon(Icons.video_library_outlined), text: 'Videos (${_videos.length})'),
            Tab(icon: const Icon(Icons.download_done_rounded), text: 'Saved (${_savedDownloads.length})'),
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
                    _buildMediaGrid(filteredPhotos, isVideo: false, isSavedTab: false),
                    _buildMediaGrid(filteredVideos, isVideo: true, isSavedTab: false),
                    _buildMediaGrid(filteredSaved, isVideo: false, isSavedTab: true),
                  ],
                ),
    );
  }

  Widget _buildPermissionPrompt() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(28.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.folder_special_rounded, size: 54.sp, color: Colors.amber[800]),
            ),
            SizedBox(height: 20.h),
            Text(
              'Automatic WhatsApp Status Sync',
              style: TextStyle(fontSize: 19.sp, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10.h),
            Text(
              'Allow storage access once so Chatflow can automatically detect and display WhatsApp statuses without asking you to pick folders.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 13.5.sp, height: 1.4),
            ),
            SizedBox(height: 24.h),
            ElevatedButton.icon(
              onPressed: _requestManageAccess,
              icon: const Icon(Icons.security_update_good_rounded),
              label: const Text('Allow Automatic Access'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 13.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                elevation: 2,
              ),
            ),
            SizedBox(height: 12.h),
            TextButton.icon(
              onPressed: _loadStatuses,
              icon: const Icon(Icons.refresh),
              label: const Text('Check Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaGrid(List<File> files, {required bool isVideo, required bool isSavedTab}) {
    if (files.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadStatuses,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: 80.h),
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 28.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(20.w),
                      decoration: BoxDecoration(
                        color: isSavedTab
                            ? Colors.blueAccent.withOpacity(0.12)
                            : const Color(0xFF25D366).withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSavedTab
                            ? Icons.download_done_rounded
                            : (isVideo ? Icons.videocam_outlined : Icons.photo_library_outlined),
                        size: 50.sp,
                        color: isSavedTab ? Colors.blueAccent : const Color(0xFF25D366),
                      ),
                    ),
                    SizedBox(height: 18.h),
                    Text(
                      isSavedTab
                          ? 'No Saved Statuses Yet'
                          : (_showFavoritesOnly
                              ? 'No Favorite Statuses'
                              : (isVideo ? 'No Video Statuses Available' : 'No Photo Statuses Available')),
                      style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      isSavedTab
                          ? 'Saved statuses are stored permanently in Pictures/Chatflow and will appear here.'
                          : (_showFavoritesOnly
                              ? 'Star any status to add it to your favorites list.'
                              : 'Statuses are automatically loaded here after you view them in WhatsApp. Open WhatsApp, watch your friends\' statuses, and return here!'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13.5.sp, height: 1.4),
                    ),
                    SizedBox(height: 24.h),
                    if (!isSavedTab) ...[
                      ElevatedButton.icon(
                        onPressed: _openWhatsApp,
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('Open WhatsApp'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 13.h),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                          elevation: 2,
                        ),
                      ),
                      SizedBox(height: 12.h),
                    ],
                    OutlinedButton.icon(
                      onPressed: _loadStatuses,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh Statuses'),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 11.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStatuses,
      child: GridView.builder(
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
        final path = file.path;
        final isSelected = _selectedFilePaths.contains(path);
        final isFav = HiveStorageService.getFavoriteStatuses().contains(path);
        final fileIsVideo = isVideo || path.endsWith('.mp4') || path.endsWith('.mkv') || path.endsWith('.3gp');

        return Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
            side: isSelected
                ? const BorderSide(color: Color(0xFF25D366), width: 3)
                : BorderSide.none,
          ),
          elevation: 2,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Tap to preview or select
              InkWell(
                onLongPress: () {
                  setState(() {
                    _isSelectionMode = true;
                    _selectedFilePaths.add(path);
                  });
                },
                onTap: () {
                  if (_isSelectionMode) {
                    setState(() {
                      if (isSelected) {
                        _selectedFilePaths.remove(path);
                        if (_selectedFilePaths.isEmpty) _isSelectionMode = false;
                      } else {
                        _selectedFilePaths.add(path);
                      }
                    });
                  } else {
                    _openFile(file, fileIsVideo);
                  }
                },
                child: fileIsVideo
                    ? _buildVideoThumbnailWidget(file)
                    : Image.file(
                        file,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      ),
              ),

              // Selection checkbox overlay
              if (_isSelectionMode)
                Positioned(
                  top: 8.h,
                  right: 8.w,
                  child: CircleAvatar(
                    radius: 14.r,
                    backgroundColor: isSelected ? const Color(0xFF25D366) : Colors.black45,
                    child: Icon(
                      isSelected ? Icons.check : Icons.circle_outlined,
                      color: Colors.white,
                      size: 18.sp,
                    ),
                  ),
                ),

              // Favorite star button (top-left)
              if (!_isSelectionMode)
                Positioned(
                  top: 4.h,
                  left: 4.w,
                  child: IconButton(
                    icon: Icon(
                      isFav ? Icons.star : Icons.star_border,
                      color: isFav ? Colors.amber : Colors.white70,
                      size: 22.sp,
                    ),
                    onPressed: () async {
                      await HiveStorageService.toggleFavoriteStatus(path);
                      setState(() {});
                    },
                  ),
                ),

              // Bottom action bar
              if (!_isSelectionMode)
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
                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (isSavedTab) ...[
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                            tooltip: 'Delete Media',
                            onPressed: () => _deleteDownloadedFile(file),
                          ),
                        ] else ...[
                          IconButton(
                            icon: const Icon(Icons.download_rounded, color: Colors.white, size: 20),
                            tooltip: 'Save to Gallery',
                            onPressed: () => _saveFile(file),
                          ),
                        ],
                        IconButton(
                          icon: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                          tooltip: 'Share',
                          onPressed: () => _shareFile(file, fileIsVideo),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
  }
}
