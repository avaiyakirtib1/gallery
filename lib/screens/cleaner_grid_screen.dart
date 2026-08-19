
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import '../providers/gallery_provider.dart';

enum CleanerCategory { duplicates, screenshots, largeFiles }

class CleanerGridScreen extends StatefulWidget {
  final CleanerCategory category;
  final String title;
  final List<AssetEntity> initialAssets;

  const CleanerGridScreen({
    super.key,
    required this.category,
    required this.title,
    required this.initialAssets,
  });

  @override
  State<CleanerGridScreen> createState() => _CleanerGridScreenState();
}

class _CleanerGridScreenState extends State<CleanerGridScreen> {
  final Set<AssetEntity> _selectedAssets = {};
  bool _isDeleting = false;
  int _selectedMinBytes = 0; // 0 = All
  Map<String, int> _assetSizes = {};

  @override
  void initState() {
    super.initState();
    if (widget.category == CleanerCategory.duplicates) {
      _preselectDuplicates();
    }
    _loadAssetSizes(widget.initialAssets);
  }

  Future<void> _loadAssetSizes(List<AssetEntity> assets) async {
    final map = <String, int>{};
    await Future.wait(assets.map((asset) async {
      try {
        final file = await asset.file;
        if (file != null) {
          final len = await file.length();
          map[asset.id] = len;
        }
      } catch (_) {}
    }));
    if (mounted) setState(() => _assetSizes = map);
  }

  void _preselectDuplicates() {
    final provider = context.read<GalleryProvider>();
    final groups = provider.duplicateGroups;
    for (final group in groups) {
      _selectedAssets.addAll(group.duplicateAssets);
    }
  }

  void _toggleSelectAll(List<AssetEntity> assets) {
    setState(() {
      if (_selectedAssets.length == assets.length) {
        _selectedAssets.clear();
      } else {
        _selectedAssets.addAll(assets);
      }
    });
  }

  String _formatSize(int bytes) {
    if (bytes >= 1073741824) {
      return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1048576) {
      return '${(bytes / 1048576).toStringAsFixed(0)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '$bytes B';
  }

  Future<void> _handleDelete() async {
    if (_selectedAssets.isEmpty) return;

    final countToDelete = _selectedAssets.length;
    final provider = context.read<GalleryProvider>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.delete_sweep_rounded, color: Colors.red),
            SizedBox(width: 10),
            Text('Confirm Delete'),
          ],
        ),
        content: Text(
          'Are you sure you want to move $countToDelete selected items to the Recycle Bin?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Move to Trash'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);

    try {
      final listToDelete = _selectedAssets.toList();
      await provider.moveMultiplePublicAssetsToTrash(listToDelete);

      if (mounted) {
        setState(() => _isDeleting = false);
        _showCelebrationDialog(context, countToDelete);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting assets: $e')),
        );
      }
    }
  }

  void _showCelebrationDialog(BuildContext context, int deletedCount) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.celebration_rounded,
                  size: 48,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Storage Reclaimed! 🎉',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Successfully moved $deletedCount items to the Recycle Bin and freed up clutter from your gallery!',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Return to Storage Hub
                  },
                  child: const Text('Great!'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final provider = context.watch<GalleryProvider>();

    final rawAssets = switch (widget.category) {
      CleanerCategory.duplicates => provider.duplicateGroups
          .expand((g) => g.assets)
          .toList(),
      CleanerCategory.screenshots => provider.screenshotAssets,
      CleanerCategory.largeFiles => provider.largeAssets,
    };

    // Filter by size if a size threshold is selected
    final assets = rawAssets.where((asset) {
      if (_selectedMinBytes == 0) return true;
      final size = _assetSizes[asset.id] ?? 0;
      return size >= _selectedMinBytes;
    }).toList();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: colorScheme.surface,
        actions: [
          if (assets.isNotEmpty)
            TextButton(
              onPressed: () => _toggleSelectAll(assets),
              child: Text(
                _selectedAssets.length == assets.length
                    ? 'Deselect All'
                    : 'Select All',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: _isDeleting
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Deleting items from device storage…'),
                ],
              ),
            )
          : Column(
              children: [
                // ─── File Size Filter Chips Bar for Large Files ─────────────────
                if (widget.category == CleanerCategory.largeFiles)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        _SizeFilterChip(
                          label: 'All Sizes',
                          isSelected: _selectedMinBytes == 0,
                          onSelected: () => setState(() => _selectedMinBytes = 0),
                        ),
                        const SizedBox(width: 8),
                        _SizeFilterChip(
                          label: '> 1 GB',
                          isSelected: _selectedMinBytes == 1073741824,
                          onSelected: () => setState(() => _selectedMinBytes = 1073741824),
                        ),
                        const SizedBox(width: 8),
                        _SizeFilterChip(
                          label: '> 500 MB',
                          isSelected: _selectedMinBytes == 524288000,
                          onSelected: () => setState(() => _selectedMinBytes = 524288000),
                        ),
                        const SizedBox(width: 8),
                        _SizeFilterChip(
                          label: '> 100 MB',
                          isSelected: _selectedMinBytes == 104857600,
                          onSelected: () => setState(() => _selectedMinBytes = 104857600),
                        ),
                        const SizedBox(width: 8),
                        _SizeFilterChip(
                          label: '> 50 MB',
                          isSelected: _selectedMinBytes == 52428800,
                          onSelected: () => setState(() => _selectedMinBytes = 52428800),
                        ),
                      ],
                    ),
                  ),

                // ─── Grid View ──────────────────────────────────────────────
                Expanded(
                  child: assets.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 72,
                                  color: Colors.green.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No Files Found',
                                  style: textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _selectedMinBytes > 0
                                      ? 'No items matching this size threshold.'
                                      : 'No ${widget.title.toLowerCase()} found in your gallery.',
                                  textAlign: TextAlign.center,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 100),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6,
                          ),
                          itemCount: assets.length,
                          itemBuilder: (context, index) {
                            final asset = assets[index];
                            final isSelected = _selectedAssets.contains(asset);
                            final bytes = _assetSizes[asset.id];

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedAssets.remove(asset);
                                  } else {
                                    _selectedAssets.add(asset);
                                  }
                                });
                              },
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // Thumbnail
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: _CleanerThumbnail(asset: asset),
                                  ),

                                  // Selected Overlay Border
                                  if (isSelected)
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.red.shade400,
                                          width: 3,
                                        ),
                                        color: Colors.black.withValues(alpha: 0.2),
                                      ),
                                    ),

                                  // Selection Checkbox Badge
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 150),
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.red.shade500
                                            : Colors.black.withValues(alpha: 0.4),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Icon(
                                        isSelected
                                            ? Icons.check
                                            : Icons.circle_outlined,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),

                                  // Size Badge
                                  Positioned(
                                    bottom: 6,
                                    left: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.7),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        bytes != null
                                            ? _formatSize(bytes)
                                            : '${asset.width}×${asset.height}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      bottomSheet: assets.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _selectedAssets.isEmpty ? null : _handleDelete,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      disabledBackgroundColor:
                          colorScheme.surfaceContainerHighest,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: Text(
                      _selectedAssets.isEmpty
                          ? 'Select Items to Delete'
                          : 'Delete ${_selectedAssets.length} Selected Items',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

// ─── Size Filter Chip Helper ─────────────────────────────────────────────────

class _SizeFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const _SizeFilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: colorScheme.primaryContainer,
      labelStyle: TextStyle(
        color: isSelected
            ? colorScheme.onPrimaryContainer
            : colorScheme.onSurfaceVariant,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

class _CleanerThumbnail extends StatelessWidget {
  final AssetEntity asset;

  const _CleanerThumbnail({required this.asset});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AssetEntityImage(
      asset,
      isOriginal: false,
      thumbnailSize: const ThumbnailSize.square(300),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: colorScheme.errorContainer,
        child: const Icon(Icons.error_outline),
      ),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(color: colorScheme.surfaceContainerHighest);
      },
    );
  }
}
