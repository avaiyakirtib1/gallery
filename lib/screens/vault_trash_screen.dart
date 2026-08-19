import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';
import '../providers/gallery_provider.dart';
import '../models/vault_asset.dart';

class VaultTrashScreen extends StatefulWidget {
  const VaultTrashScreen({super.key});

  @override
  State<VaultTrashScreen> createState() => _VaultTrashScreenState();
}

class _VaultTrashScreenState extends State<VaultTrashScreen> {
  void _showTrashOptions(BuildContext context, VaultAsset asset) {
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
                'Trash Recovery Safeguard',
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Original location: ${asset.origin == 'gallery' ? 'Public Timeline' : 'Private Vault'}',
                style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const Divider(height: 24),
              ListTile(
                leading: Icon(Icons.settings_backup_restore_rounded, color: colorScheme.primary),
                title: const Text('Restore Asset'),
                subtitle: Text('Move back to original location (${asset.origin == 'gallery' ? 'Timeline' : 'Vault'})'),
                onTap: () async {
                  Navigator.pop(context);
                  final provider = context.read<GalleryProvider>();
                  final success = await provider.restoreFromTrash(asset);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success ? 'Item restored successfully.' : 'Failed to restore item.',
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                title: const Text('Delete Permanently'),
                subtitle: const Text('Purge asset from device storage forever'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmPermanentDelete(context, asset);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmPermanentDelete(BuildContext context, VaultAsset asset) {
    final provider = context.read<GalleryProvider>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Delete Permanently?'),
          ],
        ),
        content: const Text(
          'This will permanently delete this item from your device storage. This operation is IRREVERSIBLE.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await provider.deleteFromVaultPermanently(asset);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? 'Item permanently deleted.' : 'Failed to delete item.',
                    ),
                    backgroundColor: Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmEmptyTrash(BuildContext context) {
    final provider = context.read<GalleryProvider>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Empty Recycle Bin?'),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete all ${provider.trashAssetsCount} items in the Recycle Bin? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await provider.emptyTrash();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? 'Recycle Bin emptied.' : 'Failed to empty Recycle Bin.',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Empty Trash'),
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
    final trashed = provider.trashAssets;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.delete_sweep_rounded, color: colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Recycle Bin',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          if (trashed.isNotEmpty)
            TextButton.icon(
              onPressed: () => _confirmEmptyTrash(context),
              icon: const Icon(Icons.delete_forever_rounded, size: 18, color: Colors.redAccent),
              label: const Text(
                'Empty Trash',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ),
        ],
        elevation: 0,
        backgroundColor: colorScheme.surface,
      ),
      body: Column(
        children: [
          // Informational Warning Banner
          if (trashed.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recycle Bin Lifespan',
                          style: textTheme.labelLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Items deleted from your gallery or vault stay here for 30 days before being permanently deleted.',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Main Grid view or Empty state
          Expanded(
            child: trashed.isEmpty
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
                              Icons.delete_outline_rounded,
                              size: 64,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Trash is Empty',
                            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No deleted items inside the Recycle Bin. Items will appear here when you delete photos or videos.',
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
                    itemCount: trashed.length,
                    itemBuilder: (context, index) {
                      final asset = trashed[index];
                      return _TrashGridThumbnail(
                        asset: asset,
                        onTap: () => _showTrashOptions(context, asset),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _TrashGridThumbnail extends StatelessWidget {
  final VaultAsset asset;
  final VoidCallback onTap;

  const _TrashGridThumbnail({
    required this.asset,
    required this.onTap,
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
