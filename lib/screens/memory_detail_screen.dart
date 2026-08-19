
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import '../models/memory_model.dart';
import 'photo_viewer_screen.dart';

class MemoryDetailScreen extends StatelessWidget {
  final Memory memory;

  const MemoryDetailScreen({super.key, required this.memory});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    const months = [
      'January', 'February', 'March', 'April',
      'May', 'June', 'July', 'August',
      'September', 'October', 'November', 'December',
    ];
    final dateLabel =
        '${memory.date.day} ${months[memory.date.month - 1]} ${memory.date.year}';

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // ─── Hero App Bar ────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            stretch: true,
            backgroundColor: colorScheme.surface,
            leading: _BackButton(colorScheme: colorScheme),
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.blurBackground,
              ],
              background: Hero(
                tag: memory.heroTag,
                child: _HeroCover(asset: memory.coverAsset),
              ),
            ),
          ),

          // ─── Header info ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    memory.title,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        dateLabel,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.perm_media_outlined,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${memory.assets.length} items',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Stat chips
                  Row(
                    children: [
                      if (memory.photoCount > 0)
                        _StatPill(
                          icon: Icons.photo_outlined,
                          label: '${memory.photoCount} Photos',
                          colorScheme: colorScheme,
                        ),
                      if (memory.photoCount > 0 && memory.videoCount > 0)
                        const SizedBox(width: 8),
                      if (memory.videoCount > 0)
                        _StatPill(
                          icon: Icons.videocam_outlined,
                          label: '${memory.videoCount} Videos',
                          colorScheme: colorScheme,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: colorScheme.outlineVariant),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // ─── 3-column media grid ──────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _GridThumbnail(
                  asset: memory.assets[index],
                  index: index,
                  allAssets: memory.assets,
                ),
                childCount: memory.assets.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 3,
                mainAxisSpacing: 3,
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

// ─── Back button with frosted look ──────────────────────────────────────────

class _BackButton extends StatelessWidget {
  final ColorScheme colorScheme;
  const _BackButton({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: InkWell(
        onTap: () => Navigator.pop(context),
        borderRadius: BorderRadius.circular(50),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.4),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

// ─── Hero cover image ────────────────────────────────────────────────────────

class _HeroCover extends StatelessWidget {
  final AssetEntity asset;
  const _HeroCover({required this.asset});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AssetEntityImage(
      asset,
      isOriginal: false,
      thumbnailSize: const ThumbnailSize(900, 600),
      fit: BoxFit.cover,
      width: double.infinity,
      errorBuilder: (context, error, stackTrace) => Container(
        color: colorScheme.errorContainer,
        child: const Icon(Icons.error_outline),
      ),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(color: Colors.black);
      },
    );
  }
}

// ─── Grid thumbnail cell ─────────────────────────────────────────────────────

class _GridThumbnail extends StatelessWidget {
  final AssetEntity asset;
  final int index;
  final List<AssetEntity> allAssets;

  const _GridThumbnail({
    required this.asset,
    required this.index,
    required this.allAssets,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PhotoViewerScreen(
              assets: allAssets,
              initialIndex: index,
            ),
          ),
        );
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Thumbnail
          AssetEntityImage(
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
          ),
          // Video badge overlay
          if (asset.type == AssetType.video)
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow, color: Colors.white, size: 12),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Stat pill ───────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme colorScheme;

  const _StatPill({
    required this.icon,
    required this.label,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.onPrimaryContainer),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: colorScheme.onPrimaryContainer,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
