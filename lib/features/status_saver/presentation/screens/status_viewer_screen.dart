import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/storage/hive_storage_service.dart';

bool isStatusVideo(String path) {
  final ext = path.split('.').last.toLowerCase();
  return ['mp4', 'mkv', '3gp', 'mov', 'webm', 'avi'].contains(ext);
}

class StatusViewerScreen extends StatefulWidget {
  final List<File> files;
  final int initialIndex;
  final List<File>? allFiles;
  final bool isSavedTab;
  final Future<void> Function(File file)? onSave;
  final Future<void> Function(File file, bool isVideo)? onShare;
  final Future<void> Function(File file)? onDelete;

  const StatusViewerScreen({
    super.key,
    required this.files,
    required this.initialIndex,
    this.allFiles,
    this.isSavedTab = false,
    this.onSave,
    this.onShare,
    this.onDelete,
  });

  @override
  State<StatusViewerScreen> createState() => _StatusViewerScreenState();
}

class _StatusViewerScreenState extends State<StatusViewerScreen> {
  static const _channel = MethodChannel('com.chatflow.app/channel');
  static const String _savedDirectoryPath = '/storage/emulated/0/Pictures/Chatflow';

  late PageController _pageController;
  late int _currentIndex;
  late List<File> _currentFiles;

  bool _showControls = true;
  bool _isShowingAll = false;
  final Set<String> _savedPaths = {};
  Set<String> _favoritePaths = {};

  @override
  void initState() {
    super.initState();
    _currentFiles = List<File>.from(widget.files);
    _currentIndex = widget.initialIndex.clamp(
      0,
      _currentFiles.isNotEmpty ? _currentFiles.length - 1 : 0,
    );
    _pageController = PageController(initialPage: _currentIndex);

    _loadFavorites();
    _checkSavedStatuses();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _loadFavorites() {
    try {
      _favoritePaths = Set<String>.from(HiveStorageService.getFavoriteStatuses());
    } catch (_) {
      _favoritePaths = {};
    }
  }

  void _checkSavedStatuses() {
    try {
      final savedDir = Directory(_savedDirectoryPath);
      if (savedDir.existsSync()) {
        final savedFiles = savedDir.listSync();
        for (var sf in savedFiles) {
          if (sf is File) {
            final name = sf.path.split('/').last.split('\\').last;
            _savedPaths.add(name);
          }
        }
      }
    } catch (_) {}
  }

  bool _isFileSaved(File file) {
    if (widget.isSavedTab) return true;
    final name = file.path.split('/').last.split('\\').last;
    return _savedPaths.contains(name) ||
        HiveStorageService.statusDownloads.containsKey(name);
  }

  Future<void> _toggleFavorite(File file) async {
    final path = file.path;
    await HiveStorageService.toggleFavoriteStatus(path);
    setState(() {
      if (_favoritePaths.contains(path)) {
        _favoritePaths.remove(path);
      } else {
        _favoritePaths.add(path);
      }
    });
  }

  Future<void> _saveCurrentFile(File file) async {
    if (widget.onSave != null) {
      await widget.onSave!(file);
    } else {
      try {
        final filename = file.path.split('/').last.split('\\').last;
        final saveDir = Directory(_savedDirectoryPath);
        if (!await saveDir.exists()) {
          await saveDir.create(recursive: true);
        }
        final target = File('${saveDir.path}/$filename');
        await file.copy(target.path);

        await HiveStorageService.statusDownloads.put(filename, {
          'filename': filename,
          'path': target.path,
          'savedAt': DateTime.now().toIso8601String(),
          'size': await target.length(),
        });
      } catch (_) {}
    }

    final filename = file.path.split('/').last.split('\\').last;
    setState(() {
      _savedPaths.add(filename);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 10.w),
              const Expanded(
                child: Text('Saved successfully to Pictures/Chatflow!'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF25D366),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _shareCurrentFile(File file, bool isVideo) async {
    if (widget.onShare != null) {
      await widget.onShare!(file, isVideo);
    } else {
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
  }

  Future<void> _deleteCurrentFile(File file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF202020),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: const Text('Delete Saved Media?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will permanently delete this media from your device.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (widget.onDelete != null) {
        await widget.onDelete!(file);
      } else {
        try {
          if (await file.exists()) {
            await file.delete();
          }
          final filename = file.path.split('/').last.split('\\').last;
          await HiveStorageService.statusDownloads.delete(filename);
        } catch (_) {}
      }

      setState(() {
        _currentFiles.removeAt(_currentIndex);
        if (_currentIndex >= _currentFiles.length && _currentFiles.isNotEmpty) {
          _currentIndex = _currentFiles.length - 1;
        }
      });

      if (_currentFiles.isEmpty && mounted) {
        Navigator.pop(context);
      }
    }
  }

  void _toggleAllMediaMode() {
    if (widget.allFiles == null || widget.allFiles!.isEmpty) return;

    final currentFile = _currentFiles.isNotEmpty ? _currentFiles[_currentIndex] : null;

    setState(() {
      _isShowingAll = !_isShowingAll;
      if (_isShowingAll) {
        _currentFiles = List<File>.from(widget.allFiles!);
      } else {
        _currentFiles = List<File>.from(widget.files);
      }

      if (currentFile != null) {
        final newIndex = _currentFiles.indexWhere((f) => f.path == currentFile.path);
        _currentIndex = newIndex != -1 ? newIndex : 0;
      } else {
        _currentIndex = 0;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_currentIndex);
      }
    });
  }

  void _goToPrevious() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToNext() {
    if (_currentIndex < _currentFiles.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentFiles.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: Text('No statuses available', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final currentFile = _currentFiles[_currentIndex];
    final fileIsVideo = isStatusVideo(currentFile.path);
    final isFav = _favoritePaths.contains(currentFile.path);
    final isSaved = _isFileSaved(currentFile);

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // PageView for swiping left and right between photos and videos
            GestureDetector(
              onTap: () {
                setState(() {
                  _showControls = !_showControls;
                });
              },
              child: PageView.builder(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                itemCount: _currentFiles.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  final file = _currentFiles[index];
                  final isVid = isStatusVideo(file.path);
                  final isCurrent = index == _currentIndex;

                  if (isVid) {
                    return _VideoStatusItem(
                      key: ValueKey(file.path),
                      file: file,
                      isCurrent: isCurrent,
                      showControls: _showControls,
                      onToggleControls: () {
                        setState(() {
                          _showControls = !_showControls;
                        });
                      },
                      onNativeFallback: () {
                        _channel.invokeMethod('playVideoFullscreen', {
                          'path': file.path,
                        });
                      },
                    );
                  } else {
                    return _PhotoStatusItem(
                      key: ValueKey(file.path),
                      file: file,
                      onTap: () {
                        setState(() {
                          _showControls = !_showControls;
                        });
                      },
                    );
                  }
                },
              ),
            ),

            // Left Navigation Arrow Button (Tap to go previous)
            if (_showControls && _currentIndex > 0)
              Positioned(
                left: 12.w,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(30.r),
                      onTap: _goToPrevious,
                      child: Container(
                        padding: EdgeInsets.all(10.r),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 0.8),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Right Navigation Arrow Button (Tap to go next)
            if (_showControls && _currentIndex < _currentFiles.length - 1)
              Positioned(
                right: 12.w,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(30.r),
                      onTap: _goToNext,
                      child: Container(
                        padding: EdgeInsets.all(10.r),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 0.8),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Top Header Bar
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              top: _showControls ? 0 : -100.h,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.85),
                      Colors.transparent,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8.h,
                  bottom: 16.h,
                  left: 12.w,
                  right: 12.w,
                ),
                child: Row(
                  children: [
                    // Back button
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                      onPressed: () => Navigator.pop(context),
                    ),
                    SizedBox(width: 4.w),

                    // Counter & Media Type
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${_currentIndex + 1} / ${_currentFiles.length}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  color: fileIsVideo
                                      ? Colors.deepOrangeAccent.withValues(alpha: 0.3)
                                      : const Color(0xFF25D366).withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(10.r),
                                  border: Border.all(
                                    color: fileIsVideo
                                        ? Colors.deepOrangeAccent
                                        : const Color(0xFF25D366),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      fileIsVideo
                                          ? Icons.videocam_rounded
                                          : Icons.image_rounded,
                                      size: 12.sp,
                                      color: fileIsVideo
                                          ? Colors.deepOrangeAccent
                                          : const Color(0xFF25D366),
                                    ),
                                    SizedBox(width: 4.w),
                                    Text(
                                      fileIsVideo ? 'VIDEO' : 'PHOTO',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            currentFile.path.split('/').last.split('\\').last,
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11.5.sp,
                            ),
                            maxLines: 1,
                            overflow: TextPathTrim.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Toggle All Statuses (Photos + Videos together)
                    if (widget.allFiles != null &&
                        widget.allFiles!.length > widget.files.length)
                      Container(
                        margin: EdgeInsets.only(right: 4.w),
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            backgroundColor: _isShowingAll
                                ? const Color(0xFF25D366).withValues(alpha: 0.25)
                                : Colors.white10,
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14.r),
                              side: BorderSide(
                                color: _isShowingAll
                                    ? const Color(0xFF25D366)
                                    : Colors.white24,
                              ),
                            ),
                          ),
                          icon: Icon(
                            _isShowingAll ? Icons.filter_alt_off : Icons.filter_alt,
                            size: 16.sp,
                            color: _isShowingAll
                                ? const Color(0xFF25D366)
                                : Colors.white70,
                          ),
                          label: Text(
                            _isShowingAll ? 'All Statuses' : 'This Tab',
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: _isShowingAll
                                  ? const Color(0xFF25D366)
                                  : Colors.white70,
                            ),
                          ),
                          onPressed: _toggleAllMediaMode,
                        ),
                      ),

                    // Favorite Button
                    IconButton(
                      icon: Icon(
                        isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: isFav ? Colors.amber : Colors.white70,
                        size: 26.sp,
                      ),
                      tooltip: isFav ? 'Remove Favorite' : 'Add to Favorites',
                      onPressed: () => _toggleFavorite(currentFile),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Action Bar
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              bottom: _showControls ? 0 : -120.h,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.85),
                      Colors.black,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                padding: EdgeInsets.only(
                  left: 16.w,
                  right: 16.w,
                  top: 16.h,
                  bottom: MediaQuery.of(context).padding.bottom + 16.h,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Delete button if already saved / viewing saved tab
                    if (widget.isSavedTab || isSaved)
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.redAccent.withValues(alpha: 0.25),
                          foregroundColor: Colors.redAccent,
                        ),
                        icon: const Icon(Icons.delete_outline_rounded),
                        tooltip: 'Delete',
                        onPressed: () => _deleteCurrentFile(currentFile),
                      ),

                    // Save / Download Button
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.w),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isSaved
                                ? Colors.grey[800]
                                : const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 13.h),
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24.r),
                            ),
                          ),
                          icon: Icon(
                            isSaved
                                ? Icons.check_circle_rounded
                                : Icons.download_rounded,
                            size: 22.sp,
                          ),
                          label: Text(
                            isSaved ? 'Saved in Gallery' : 'Save to Gallery',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () => _saveCurrentFile(currentFile),
                        ),
                      ),
                    ),

                    // Share Button
                    Expanded(
                      flex: 1,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E88E5),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 13.h),
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24.r),
                          ),
                        ),
                        icon: Icon(Icons.share_rounded, size: 20.sp),
                        label: Text(
                          'Share',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: () => _shareCurrentFile(currentFile, fileIsVideo),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TextPathTrim {
  static const TextOverflow ellipsis = TextOverflow.ellipsis;
}

// ---------------------------------------------------------
// Photo Viewer Item (Supports Pinch to Zoom)
// ---------------------------------------------------------
class _PhotoStatusItem extends StatelessWidget {
  final File file;
  final VoidCallback onTap;

  const _PhotoStatusItem({
    super.key,
    required this.file,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4.0,
          clipBehavior: Clip.none,
          child: Image.file(
            file,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image_rounded, size: 60.sp, color: Colors.white38),
                  SizedBox(height: 12.h),
                  const Text('Unable to display photo', style: TextStyle(color: Colors.white54)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// Video Viewer Item (Auto-play, Scrub Bar, Play/Pause, Mute)
// ---------------------------------------------------------
class _VideoStatusItem extends StatefulWidget {
  final File file;
  final bool isCurrent;
  final bool showControls;
  final VoidCallback onToggleControls;
  final VoidCallback onNativeFallback;

  const _VideoStatusItem({
    super.key,
    required this.file,
    required this.isCurrent,
    required this.showControls,
    required this.onToggleControls,
    required this.onNativeFallback,
  });

  @override
  State<_VideoStatusItem> createState() => _VideoStatusItemState();
}

class _VideoStatusItemState extends State<_VideoStatusItem> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _isPlaying = false;
  bool _isMuted = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      final controller = VideoPlayerController.file(widget.file);
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      controller.setLooping(true);
      controller.addListener(_videoListener);

      setState(() {
        _controller = controller;
        _isInitialized = true;
        _duration = controller.value.duration;
      });

      if (widget.isCurrent) {
        controller.play();
        setState(() => _isPlaying = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _videoListener() {
    if (_controller == null || !mounted) return;
    final isPlaying = _controller!.value.isPlaying;
    final pos = _controller!.value.position;
    if (_isPlaying != isPlaying || (_position.inSeconds != pos.inSeconds)) {
      setState(() {
        _isPlaying = isPlaying;
        _position = pos;
      });
    }
  }

  @override
  void didUpdateWidget(_VideoStatusItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isCurrent != widget.isCurrent) {
      if (widget.isCurrent) {
        _controller?.play();
        setState(() => _isPlaying = true);
      } else {
        _controller?.pause();
        setState(() => _isPlaying = false);
      }
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_videoListener);
    _controller?.pause();
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
      setState(() => _isPlaying = false);
    } else {
      _controller!.play();
      setState(() => _isPlaying = true);
    }
  }

  void _toggleMute() {
    if (_controller == null || !_isInitialized) return;
    final nextMute = !_isMuted;
    _controller!.setVolume(nextMute ? 0.0 : 1.0);
    setState(() => _isMuted = nextMute);
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.video_camera_back_outlined, size: 54.sp, color: Colors.orangeAccent),
              SizedBox(height: 14.h),
              const Text(
                'Video preview format not directly supported in-app',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8.h),
              Text(
                _errorMessage ?? '',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
              SizedBox(height: 20.h),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                ),
                onPressed: widget.onNativeFallback,
                icon: const Icon(Icons.play_circle_fill_rounded),
                label: const Text('Open in Fullscreen Player'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF25D366),
          strokeWidth: 2.5,
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        widget.onToggleControls();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video Player centered with correct aspect ratio
          Center(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio > 0
                  ? _controller!.value.aspectRatio
                  : 16 / 9,
              child: VideoPlayer(_controller!),
            ),
          ),

          // Big Center Play/Pause button overlay (when paused or when controls shown)
          if (!_isPlaying || widget.showControls)
            Center(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(40.r),
                  onTap: _togglePlayPause,
                  child: Container(
                    padding: EdgeInsets.all(16.r),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white30, width: 1.5),
                    ),
                    child: Icon(
                      _isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 44.sp,
                    ),
                  ),
                ),
              ),
            ),

          // Bottom Scrubber Bar & Mute Button (Above the main bottom action bar)
          if (widget.showControls)
            Positioned(
              left: 16.w,
              right: 16.w,
              bottom: 95.h,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    // Play/Pause icon button
                    GestureDetector(
                      onTap: _togglePlayPause,
                      child: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 22.sp,
                      ),
                    ),
                    SizedBox(width: 8.w),

                    // Timestamp
                    Text(
                      _formatDuration(_position),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11.5.sp,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),

                    // Slider
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3.h,
                          thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6.r),
                          overlayShape: RoundSliderOverlayShape(overlayRadius: 12.r),
                          activeTrackColor: const Color(0xFF25D366),
                          inactiveTrackColor: Colors.white24,
                          thumbColor: const Color(0xFF25D366),
                        ),
                        child: Slider(
                          value: _position.inMilliseconds
                              .clamp(0, _duration.inMilliseconds)
                              .toDouble(),
                          min: 0.0,
                          max: _duration.inMilliseconds > 0
                              ? _duration.inMilliseconds.toDouble()
                              : 1.0,
                          onChanged: (val) {
                            _controller?.seekTo(Duration(milliseconds: val.toInt()));
                          },
                        ),
                      ),
                    ),

                    // Total Duration
                    Text(
                      _formatDuration(_duration),
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11.5.sp,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    SizedBox(width: 8.w),

                    // Mute / Unmute Button
                    GestureDetector(
                      onTap: _toggleMute,
                      child: Icon(
                        _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                        color: _isMuted ? Colors.redAccent : Colors.white,
                        size: 20.sp,
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
}
