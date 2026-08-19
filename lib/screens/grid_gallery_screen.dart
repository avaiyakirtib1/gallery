import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import '../providers/gallery_provider.dart';
import '../widgets/permission_prompt.dart';
import 'photo_viewer_screen.dart';
import 'calendar_screen.dart';
import 'search_hub_delegate.dart';

/// A full-device photo grid with pinch-to-zoom that changes the column count —
/// just like the native Android / iOS Photos app.
///
/// Default : 3 columns.
/// Pinch in  (zoom in)  → fewer columns (min 1).
/// Pinch out (zoom out) → more  columns (max 6).
class GridGalleryScreen extends StatefulWidget {
  final VoidCallback? onToggleView;
  final bool showTimeline;
  final bool showHeader;

  const GridGalleryScreen({
    super.key,
    this.onToggleView,
    this.showTimeline = false,
    this.showHeader = true,
  });

  @override
  State<GridGalleryScreen> createState() => _GridGalleryScreenState();
}

class _GridGalleryScreenState extends State<GridGalleryScreen> {
  static const int _minColumns = 1;
  static const int _maxColumns = 6;
  static const int _defaultColumns = 3;

  int _columns = _defaultColumns;

  // ── Pinch state ───────────────────────────────────────────────────────────
  // We lock in the column count at the START of each gesture and derive
  // the desired count from the live cumulative scale.  This means the grid
  // responds IMMEDIATELY frame-by-frame — just like the native gallery.

  int _startColumns = _defaultColumns;   // columns when gesture began

  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ── Pinch gesture ─────────────────────────────────────────────────────────

  void _onScaleStart(ScaleStartDetails details) {
    // Snapshot the current column count so the math stays consistent
    // throughout the entire pinch.
    _startColumns = _columns;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount < 2) return; // ignore single-finger pan

    // Map scale → desired column count in real-time.
    //
    // Logic:  scale > 1  = pinching IN  = zooming IN  = FEWER columns
    //         scale < 1  = pinching OUT = zooming OUT = MORE  columns
    //
    // Formula: desired = round( startColumns / scale )
    // Examples with startColumns = 3:
    //   scale 2.0 → 3/2 = 1.5 → 2 columns
    //   scale 0.5 → 3/0.5 = 6  → 6 columns
    final rawDesired = (_startColumns / details.scale).round();
    final desired = rawDesired.clamp(_minColumns, _maxColumns);

    if (desired != _columns) {
      HapticFeedback.selectionClick();
      setState(() => _columns = desired);
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    // Nothing to do — columns are already updated live.
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _columnLabel(int cols) =>
      cols == 1 ? '1 column' : '$cols columns';



  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final provider = context.watch<GalleryProvider>();

    // ── Permission denied ─────────────────────────────────────────────────
    if (!provider.hasPermission) {
      return Scaffold(
        body: PermissionPrompt(
          onGrantPermission: () => provider.loadGallery(),
          onOpenSettings: () => PhotoManager.openSetting(),
        ),
      );
    }

    // ── Loading ───────────────────────────────────────────────────────────
    if (provider.isLoading) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Loading your gallery…',
                style: textTheme.bodyMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    final assets = provider.allAssets;

    // ── Empty state ───────────────────────────────────────────────────────
    if (assets.isEmpty) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: widget.showHeader ? _buildAppBar(colorScheme, textTheme, 0) : null,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.photo_library_outlined,
                  size: 72, color: colorScheme.onSurfaceVariant),
              const SizedBox(height: 20),
              Text(
                'No photos yet',
                style:
                    textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Photos and videos will appear here.',
                style: textTheme.bodyMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: widget.showHeader ? _buildAppBar(colorScheme, textTheme, assets.length) : null,
      body: GestureDetector(
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: GridView.builder(
            key: ValueKey(_columns),
            controller: _scrollController,
            padding: EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _columns,
              crossAxisSpacing: _columns == 1 ? 0 : 2,
              mainAxisSpacing: _columns == 1 ? 0 : 2,
            ),
            itemCount: assets.length,
            itemBuilder: (context, index) {
              final asset = assets[index];
              return _GridTile(
                key: ValueKey(asset.id),
                asset: asset,
                showVideoIndicator: _columns <= 4,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PhotoViewerScreen(
                      assets: assets,
                      initialIndex: index,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
      // ── Column count reset pill (shown when not at default) ─────────────
      floatingActionButton: _columns != _defaultColumns
          ? _ColumnPill(
              label: _columnLabel(_columns),
              colorScheme: colorScheme,
              onReset: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _columns = _defaultColumns;
                });
              },
            )
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar(
      ColorScheme cs, TextTheme tt, int totalCount) {
    return AppBar(
      backgroundColor: cs.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'All Photos',
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (totalCount > 0)
            Text(
              '$totalCount items  •  pinch to zoom',
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
      actions: [
        if (widget.onToggleView != null)
          IconButton(
            icon: const Icon(Icons.view_agenda_rounded),
            tooltip: 'Switch to Timeline View',
            onPressed: widget.onToggleView,
          ),
        IconButton(
          icon: const Icon(Icons.calendar_month_rounded),
          tooltip: 'Calendar Explorer',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CalendarScreen(),
              ),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.search_rounded),
          tooltip: 'Search',
          onPressed: () {
            showSearch(
              context: context,
              delegate: SearchHubDelegate(),
            );
          },
        ),
        const SizedBox(width: 4),
        // Quick-access preset toggles: 2 / 3 / 5 columns
        _ColumnToggleRow(
          current: _columns,
          onChanged: (col) {
            HapticFeedback.selectionClick();
            setState(() {
              _columns = col;
            });
          },
          colorScheme: cs,
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

// ─── Quick column-count toggle chips ────────────────────────────────────────

class _ColumnToggleRow extends StatelessWidget {
  final int current;
  final ValueChanged<int> onChanged;
  final ColorScheme colorScheme;

  const _ColumnToggleRow({
    required this.current,
    required this.onChanged,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    const presets = [2, 3, 5];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: presets.map((col) {
        final selected = current == col;
        return GestureDetector(
          onTap: () => onChanged(col),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: selected
                  ? colorScheme.primary
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '$col',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Floating reset pill ─────────────────────────────────────────────────────

class _ColumnPill extends StatelessWidget {
  final String label;
  final ColorScheme colorScheme;
  final VoidCallback onReset;

  const _ColumnPill({
    required this.label,
    required this.colorScheme,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onReset,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.grid_view_rounded,
                size: 16, color: colorScheme.onInverseSurface),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: colorScheme.onInverseSurface,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.close_rounded,
              size: 14,
              color: colorScheme.onInverseSurface.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Single grid tile with lazy thumbnail loading ────────────────────────────

class _GridTile extends StatelessWidget {
  final AssetEntity asset;
  final VoidCallback onTap;
  final bool showVideoIndicator;

  const _GridTile({
    super.key,
    required this.asset,
    required this.onTap,
    required this.showVideoIndicator,
  });

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Thumbnail ──────────────────────────────────────────────────
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

          // ── Video duration badge ───────────────────────────────────────
          if (asset.type == AssetType.video && showVideoIndicator)
            Positioned(
              right: 5,
              bottom: 5,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 12),
                    const SizedBox(width: 2),
                    Text(
                      _formatDuration(
                          Duration(seconds: asset.duration)),
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
