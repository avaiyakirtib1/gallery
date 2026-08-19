
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import '../models/memory_model.dart';
import '../screens/memory_detail_screen.dart';

class MemoryCard extends StatefulWidget {
  final Memory memory;
  final int index;

  const MemoryCard({super.key, required this.memory, required this.index});

  @override
  State<MemoryCard> createState() => _MemoryCardState();
}

class _MemoryCardState extends State<MemoryCard> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final memory = widget.memory;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Hero(
        tag: memory.heroTag,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTapDown: (_) => setState(() => _scale = 0.98),
            onTapUp: (_) => setState(() => _scale = 1.0),
            onTapCancel: () => setState(() => _scale = 1.0),
            onTap: () => _navigateToDetail(context),
            child: AnimatedScale(
              scale: _scale,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              child: Container(
                height: 250,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  color: colorScheme.surfaceContainerHighest,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // ─── Photo Collage Grid Layout ───────────────────────
                      _buildCollageGrid(colorScheme),

                      // ─── Gradient Scrim Overlay ─────────────────────────
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x55000000),
                              Colors.transparent,
                              Color(0xDD000000),
                            ],
                            stops: [0.0, 0.35, 1.0],
                          ),
                        ),
                      ),

                      // ─── Top-Left Date Badge ─────────────────────────────
                      Positioned(
                        top: 14,
                        left: 14,
                        child: _DateBadge(date: memory.date),
                      ),

                      // ─── Top-Right Total Photos Badge ───────────────────
                      Positioned(
                        top: 14,
                        right: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white24, width: 0.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.collections_outlined,
                                  size: 13, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                '${memory.assets.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ─── Bottom Info Overlay ─────────────────────────────
                      Positioned(
                        left: 18,
                        right: 18,
                        bottom: 16,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    memory.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.titleLarge?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                      shadows: [
                                        const Shadow(
                                          blurRadius: 8,
                                          color: Colors.black54,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      if (memory.photoCount > 0)
                                        _StatChip(
                                          icon: Icons.photo_camera_outlined,
                                          label: '${memory.photoCount} photos',
                                        ),
                                      if (memory.videoCount > 0)
                                        _StatChip(
                                          icon: Icons.videocam_outlined,
                                          label: '${memory.videoCount} videos',
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Arrow button
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white30, width: 0.5),
                              ),
                              child: const Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ─── Shimmer Glass Border ─────────────────────────────
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollageGrid(ColorScheme colorScheme) {
    final assets = widget.memory.assets;
    final count = assets.length;

    if (count == 0) {
      return Container(color: colorScheme.surfaceContainerHighest);
    }

    // Single photo layout
    if (count == 1) {
      return _buildImageTile(assets[0], const ThumbnailSize(500, 400), colorScheme);
    }

    // 2 Photos layout: 50/50 split
    if (count == 2) {
      return Row(
        children: [
          Expanded(child: _buildImageTile(assets[0], const ThumbnailSize(250, 400), colorScheme)),
          const SizedBox(width: 2),
          Expanded(child: _buildImageTile(assets[1], const ThumbnailSize(250, 400), colorScheme)),
        ],
      );
    }

    // 3+ Photos layout: Big left (65%), 2 small stacked right (35%)
    return Row(
      children: [
        Expanded(
          flex: 65,
          child: _buildImageTile(assets[0], const ThumbnailSize(350, 400), colorScheme),
        ),
        const SizedBox(width: 2),
        Expanded(
          flex: 35,
          child: Column(
            children: [
              Expanded(child: _buildImageTile(assets[1], const ThumbnailSize(200, 200), colorScheme)),
              const SizedBox(height: 2),
              Expanded(child: _buildImageTile(assets[2], const ThumbnailSize(200, 200), colorScheme)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageTile(AssetEntity asset, ThumbnailSize size, ColorScheme colorScheme) {
    return AssetEntityImage(
      asset,
      isOriginal: false,
      thumbnailSize: size,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) => Container(
        color: colorScheme.errorContainer,
        child: const Icon(Icons.error_outline),
      ),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: colorScheme.surfaceContainerHighest,
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
    );
  }

  void _navigateToDetail(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, _, _) => MemoryDetailScreen(memory: widget.memory),
        transitionsBuilder: (_, anim, _, child) => FadeTransition(
          opacity: anim,
          child: child,
        ),
      ),
    );
  }
}

// ─── Top-Left Date Pill ──────────────────────────────────────────────────────

class _DateBadge extends StatelessWidget {
  final DateTime date;

  const _DateBadge({required this.date});

  @override
  Widget build(BuildContext context) {
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
    ];

    final dayName = days[date.weekday - 1];
    final monthName = months[date.month - 1];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$dayName, $monthName ${date.day}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stat Chip ───────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
