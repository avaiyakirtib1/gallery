import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';
import '../providers/gallery_provider.dart';
import '../widgets/photo_info_sheet.dart';
import '../widgets/video_player_widget.dart';
import 'image_editor_screen.dart';

class PhotoViewerScreen extends StatefulWidget {
  final List<AssetEntity> assets;
  final int initialIndex;

  const PhotoViewerScreen({
    super.key,
    required this.assets,
    required this.initialIndex,
  });

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen>
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
    _controlsFade =
        CurvedAnimation(parent: _controlsAnim, curve: Curves.easeInOut);

    // Enter immersive mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheAdjacentImages(_currentIndex);
  }

  void _precacheAdjacentImages(int index) {
    if (!mounted) return;
    if (index + 1 < widget.assets.length) {
      precacheImage(
        AssetEntityImageProvider(
          widget.assets[index + 1],
          isOriginal: false,
          thumbnailSize: const ThumbnailSize(1024, 1024),
        ),
        context,
      );
    }
    if (index - 1 >= 0) {
      precacheImage(
        AssetEntityImageProvider(
          widget.assets[index - 1],
          isOriginal: false,
          thumbnailSize: const ThumbnailSize(1024, 1024),
        ),
        context,
      );
    }
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

  void _showInfoSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          PhotoInfoSheet(asset: widget.assets[_currentIndex]),
    );
  }

  void _moveToVault() {
    final asset = widget.assets[_currentIndex];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: Colors.indigo),
            SizedBox(width: 8),
            Text('Move to Vault?'),
          ],
        ),
        content: const Text(
          'This will hide this photo/video from your public timeline and store it securely in your Private Vault.',
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
              final success = await provider.moveToVault(asset);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Moved to Private Vault.'
                          : 'Failed to move item to vault.',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                if (success) {
                  Navigator.pop(context); // Close viewer
                }
              }
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Move to Vault'),
          ),
        ],
      ),
    );
  }

  void _moveToTrash() {
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
          'This will remove this photo/video from your timeline and move it to the Recycle Bin. You can restore it within 30 days.',
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
              final success = await provider.movePublicAssetToTrash(asset);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Moved to Recycle Bin.'
                          : 'Failed to delete item.',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                if (success) {
                  Navigator.pop(context); // Close viewer
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

  void _editImage() async {
    final asset = widget.assets[_currentIndex];
    final file = await asset.file;
    if (file == null) return;
    
    if (!mounted) return;
    
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ImageEditorScreen(
          imageFile: file,
          assetName: asset.title ?? 'edited_photo.jpg',
        ),
      ),
    );
    
    if (result == true && mounted) {
      context.read<GalleryProvider>().loadGallery();
      Navigator.pop(context); // Close viewer to refresh timeline
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final total = widget.assets.length;
    final asset = widget.assets[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ─── Photo PageView ───────────────────────────────────────────
          PageView.builder(
            controller: _pageController,
            itemCount: widget.assets.length,
            onPageChanged: (i) {
              setState(() => _currentIndex = i);
              _precacheAdjacentImages(i);
            },
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: _toggleControls,
                child: _PhotoPage(asset: widget.assets[index]),
              );
            },
          ),

          // ─── Top bar (index counter + close) ─────────────────────────
          FadeTransition(
            opacity: _controlsFade,
            child: Align(
              alignment: Alignment.topCenter,
              child: SafeArea(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Row(
                    children: [
                      // Close button
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
                      // Counter
                      Text(
                        '${_currentIndex + 1} / $total',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      // Lock button
                      InkWell(
                        onTap: _moveToVault,
                        borderRadius: BorderRadius.circular(24),
                        child: const Icon(
                          Icons.lock_outline_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      // Info button
                      InkWell(
                        onTap: _showInfoSheet,
                        borderRadius: BorderRadius.circular(24),
                        child: const Icon(
                          Icons.info_outline_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      if (asset.type == AssetType.image) ...[
                        const SizedBox(width: 16),
                        // Edit button
                        InkWell(
                          onTap: _editImage,
                          borderRadius: BorderRadius.circular(24),
                          child: const Icon(
                            Icons.edit_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ],
                      const SizedBox(width: 16),
                      // Delete (Trash) button
                      InkWell(
                        onTap: _moveToTrash,
                        borderRadius: BorderRadius.circular(24),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ─── Bottom navigation arrows ─────────────────────────────────
          FadeTransition(
            opacity: _controlsFade,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Prev
                      _NavArrow(
                        icon: Icons.chevron_left_rounded,
                        enabled: _currentIndex > 0,
                        onTap: () => _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Page indicator dots (max 5 visible)
                      _PageDots(
                        total: total,
                        current: _currentIndex,
                        colorScheme: colorScheme,
                      ),
                      const SizedBox(width: 24),
                      // Next
                      _NavArrow(
                        icon: Icons.chevron_right_rounded,
                        enabled: _currentIndex < total - 1,
                        onTap: () => _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
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

// ─── Single photo page with photo_view ───────────────────────────────────────

class _PhotoPage extends StatefulWidget {
  final AssetEntity asset;
  const _PhotoPage({required this.asset});

  @override
  State<_PhotoPage> createState() => _PhotoPageState();
}

class _PhotoPageState extends State<_PhotoPage> {
  late final ImageProvider _imageProvider;

  @override
  void initState() {
    super.initState();
    // Use AssetEntityImageProvider for faster native decoding without manual file I/O.
    _imageProvider = AssetEntityImageProvider(
      widget.asset,
      isOriginal: false,
      thumbnailSize: const ThumbnailSize(1024, 1024), // High-res suitable for viewer
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.asset.type == AssetType.video) {
      return VideoPlayerWidget(asset: widget.asset);
    }

    return PhotoView(
      imageProvider: _imageProvider,
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 4,
      backgroundDecoration: const BoxDecoration(color: Colors.black),
      heroAttributes: PhotoViewHeroAttributes(tag: widget.asset.id),
      enableRotation: false,
      loadingBuilder: (context, event) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}

// ─── Navigation arrow button ─────────────────────────────────────────────────

class _NavArrow extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _NavArrow({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: enabled ? 1.0 : 0.3,
      duration: const Duration(milliseconds: 200),
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

// ─── Page indicator dots ─────────────────────────────────────────────────────

class _PageDots extends StatelessWidget {
  final int total;
  final int current;
  final ColorScheme colorScheme;

  const _PageDots({
    required this.total,
    required this.current,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    // Show at most 5 dots; for large galleries just show the counter
    if (total > 20) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final selected = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          width: selected ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.white38,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
