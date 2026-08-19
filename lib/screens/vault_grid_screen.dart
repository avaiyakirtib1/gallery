import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';
import '../providers/gallery_provider.dart';
import '../models/vault_asset.dart';
import 'vault_photo_viewer_screen.dart';
import 'vault_trash_screen.dart';

class VaultGridScreen extends StatefulWidget {
  const VaultGridScreen({super.key});

  @override
  State<VaultGridScreen> createState() => _VaultGridScreenState();
}

class _VaultGridScreenState extends State<VaultGridScreen> {
  int _selectedFilterIndex = 0; // 0: All, 1: Photos, 2: Videos
  bool _showWarning = true;

  List<VaultAsset> _filterAssets(List<VaultAsset> assets) {
    if (_selectedFilterIndex == 0) return assets;
    if (_selectedFilterIndex == 1) {
      return assets.where((a) => a.type == AssetType.image).toList();
    }
    return assets.where((a) => a.type == AssetType.video).toList();
  }

  void _showOptions(BuildContext context, VaultAsset asset) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vault Item Settings',
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                asset.originalName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const Divider(height: 24),
              ListTile(
                leading: Icon(Icons.settings_backup_restore_rounded, color: colorScheme.primary),
                title: const Text('Restore to Public Gallery'),
                subtitle: const Text('Move photo back to main device storage'),
                onTap: () {
                  Navigator.pop(context);
                  _restoreAsset(context, asset);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: const Text('Move to Trash'),
                subtitle: const Text('Send item to the Recycle Bin'),
                onTap: () {
                  Navigator.pop(context);
                  _moveAssetToTrash(context, asset);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _moveAssetToTrash(BuildContext context, VaultAsset asset) async {
    final provider = context.read<GalleryProvider>();
    final success = await provider.moveToTrash(asset);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Moved to Trash.' : 'Failed to move to Trash.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _restoreAsset(BuildContext context, VaultAsset asset) async {
    final provider = context.read<GalleryProvider>();
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
          'This item will be exported back to your device\'s public library and will become visible in other apps.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
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



  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final provider = context.watch<GalleryProvider>();
    final filteredAssets = _filterAssets(provider.vaultAssets);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.lock, color: colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Private Vault',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'Recycle Bin',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VaultTrashScreen()),
              );
            },
          ),
          if (provider.vaultAssets.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${provider.vaultAssets.length} Items Locked',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
        elevation: 0,
        backgroundColor: colorScheme.surface,
      ),
      body: Column(
        children: [
          // Warning banner about uninstalling/clearing data
          if (_showWarning && provider.vaultAssets.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorScheme.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: colorScheme.onErrorContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Data Loss Warning',
                          style: textTheme.labelLarge?.copyWith(
                            color: colorScheme.onErrorContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Vault files are stored locally in the app sandbox. Wiping app data or uninstalling the app will permanently delete these files.',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onErrorContainer.withValues(alpha: 0.8),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: colorScheme.onErrorContainer),
                    onPressed: () {
                      setState(() {
                        _showWarning = false;
                      });
                    },
                  ),
                ],
              ),
            ),

          // Filter Tabs
          if (provider.vaultAssets.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: _selectedFilterIndex == 0,
                    onTap: () => setState(() => _selectedFilterIndex = 0),
                    colorScheme: colorScheme,
                  ),
                  _FilterChip(
                    label: 'Photos',
                    selected: _selectedFilterIndex == 1,
                    onTap: () => setState(() => _selectedFilterIndex = 1),
                    colorScheme: colorScheme,
                  ),
                  _FilterChip(
                    label: 'Videos',
                    selected: _selectedFilterIndex == 2,
                    onTap: () => setState(() => _selectedFilterIndex = 2),
                    colorScheme: colorScheme,
                  ),
                ],
              ),
            ),

          // Main Grid view or Empty state
          Expanded(
            child: filteredAssets.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.lock_person_outlined,
                              size: 64,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'No Private Memories',
                            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _selectedFilterIndex == 0
                                ? 'Your vault is currently empty. Tap the lock icon on any photo in your timeline to move it here.'
                                : 'No matching files in this category.',
                            textAlign: TextAlign.center,
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: filteredAssets.length,
                    itemBuilder: (context, index) {
                      final asset = filteredAssets[index];
                      return VaultGridThumbnail(
                        asset: asset,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => VaultPhotoViewerScreen(
                                assets: filteredAssets,
                                initialIndex: index,
                              ),
                            ),
                          );
                        },
                        onLongPress: () => _showOptions(context, asset),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? colorScheme.primary : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? colorScheme.primary : colorScheme.outline.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class VaultGridThumbnail extends StatelessWidget {
  final VaultAsset asset;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const VaultGridThumbnail({
    super.key,
    required this.asset,
    required this.onTap,
    required this.onLongPress,
  });

  String _formatDuration(int seconds) {
    final min = (seconds / 60).floor();
    final sec = seconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              File(asset.localPath),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.broken_image, color: Colors.white24),
                );
              },
            ),
          ),
          // Video duration label
          if (asset.type == AssetType.video)
            Positioned(
              right: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 12),
                    const SizedBox(width: 2),
                    Text(
                      _formatDuration(asset.duration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
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
