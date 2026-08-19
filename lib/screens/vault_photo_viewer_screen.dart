import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_view/photo_view.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import '../models/vault_asset.dart';
import '../providers/gallery_provider.dart';

class VaultPhotoViewerScreen extends StatefulWidget {
  final List<VaultAsset> assets;
  final int initialIndex;

  const VaultPhotoViewerScreen({
    super.key,
    required this.assets,
    required this.initialIndex,
  });

  @override
  State<VaultPhotoViewerScreen> createState() => _VaultPhotoViewerScreenState();
}

class _VaultPhotoViewerScreenState extends State<VaultPhotoViewerScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late int _currentIndex;
  bool _controlsVisible = true;
  late final AnimationController _controlsAnim;
  late final Animation<double> _controlsFade;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _controlsAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1.0,
    );
    _controlsFade = CurvedAnimation(parent: _controlsAnim, curve: Curves.easeInOut);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _controlsAnim.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) {
      _controlsAnim.forward();
    } else {
      _controlsAnim.reverse();
    }
  }

  void _restoreCurrent() {
    final asset = widget.assets[_currentIndex];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.settings_backup_restore_rounded, color: Colors.indigo),
            SizedBox(width: 8),
            Text('Restore to Gallery?'),
          ],
        ),
        content: const Text(
          'This item will be exported back to your public phone gallery and will disappear from your secure vault.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final provider = context.read<GalleryProvider>();
              final success = await provider.restoreFromVault(asset);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Item restored to public gallery.'
                          : 'Failed to restore item.',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                if (success) {
                  Navigator.pop(context); // Close viewer after restoring
                }
              }
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  void _deleteCurrent() {
    final asset = widget.assets[_currentIndex];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Move to Trash?'),
          ],
        ),
        content: const Text(
          'This will move this item to the Recycle Bin. You can recover it within 30 days.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final provider = context.read<GalleryProvider>();
              final success = await provider.moveToTrash(asset);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Item moved to Trash.'
                          : 'Failed to move item.',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                if (success) {
                  Navigator.pop(context); // Close viewer after trashing
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Move to Trash'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.assets.length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Pages viewer
          PageView.builder(
            controller: _pageController,
            itemCount: total,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, index) {
              final asset = widget.assets[index];
              return GestureDetector(
                onTap: _toggleControls,
                child: _VaultPage(asset: asset),
              );
            },
          ),

          // Top navigation bar
          FadeTransition(
            opacity: _controlsFade,
            child: Align(
              alignment: Alignment.topCenter,
              child: SafeArea(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(24),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_currentIndex + 1} / $total',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 22), // Balance spacing
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom quick action toolbar
          FadeTransition(
            opacity: _controlsFade,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Wrap(
                    spacing: 20,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      // Restore option
                      GestureDetector(
                        onTap: _restoreCurrent,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.white12, width: 0.5),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.settings_backup_restore_rounded, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Restore',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Permanent delete option
                      GestureDetector(
                        onTap: _deleteCurrent,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3), width: 0.5),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Delete',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VaultPage extends StatelessWidget {
  final VaultAsset asset;
  const _VaultPage({required this.asset});

  @override
  Widget build(BuildContext context) {
    if (asset.type == AssetType.video) {
      return _VaultVideoPlayerWidget(file: File(asset.localPath));
    }

    return PhotoView(
      imageProvider: FileImage(File(asset.localPath)),
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 4,
      backgroundDecoration: const BoxDecoration(color: Colors.black),
      heroAttributes: PhotoViewHeroAttributes(tag: asset.id),
      enableRotation: false,
    );
  }
}

class _VaultVideoPlayerWidget extends StatefulWidget {
  final File file;

  const _VaultVideoPlayerWidget({required this.file});

  @override
  State<_VaultVideoPlayerWidget> createState() => _VaultVideoPlayerWidgetState();
}

class _VaultVideoPlayerWidgetState extends State<_VaultVideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    if (await widget.file.exists() && mounted) {
      _controller = VideoPlayerController.file(widget.file);
      await _controller!.initialize();
      _controller!.setLooping(true);
      _controller!.play();
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return '${duration.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return GestureDetector(
      onTap: () => setState(() => _showControls = !_showControls),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            ),
          ),
          if (_showControls)
            GestureDetector(
              onTap: _togglePlayPause,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white38, width: 1),
                ),
                child: Icon(
                  _controller!.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 44,
                ),
              ),
            ),
          if (_showControls)
            Positioned(
              bottom: 100, // Elevated to avoid overlap with viewer buttons
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24, width: 0.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ValueListenableBuilder(
                      valueListenable: _controller!,
                      builder: (context, VideoPlayerValue value, child) {
                        return Row(
                          children: [
                            Text(
                              _formatDuration(value.position),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: VideoProgressIndicator(
                                _controller!,
                                allowScrubbing: true,
                                colors: VideoProgressColors(
                                  playedColor: Theme.of(context).colorScheme.primary,
                                  bufferedColor: Colors.white24,
                                  backgroundColor: Colors.white10,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _formatDuration(value.duration),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        );
                      },
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
