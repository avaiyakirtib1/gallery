import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/gallery_provider.dart';
import 'timeline_screen.dart';
import 'grid_gallery_screen.dart';
import 'calendar_screen.dart';
import 'search_hub_delegate.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  bool _showTimeline = true;

  void _toggleView() {
    HapticFeedback.selectionClick();
    setState(() => _showTimeline = !_showTimeline);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final provider = context.watch<GalleryProvider>();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Column(
        children: [
          // ─── Premium unified header ────────────────────────────────────
          _LibraryHeader(
            showTimeline: _showTimeline,
            onToggle: _toggleView,
            provider: provider,
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
          // ─── Content body ───────────────────────────────────────────────
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: CurvedAnimation(
                  parent: anim,
                  curve: Curves.easeInOut,
                ),
                child: child,
              ),
              child: _showTimeline
                  ? TimelineScreen(
                      key: const ValueKey('timeline'),
                      showHeader: false,
                    )
                  : GridGalleryScreen(
                      key: const ValueKey('grid'),
                      showHeader: false,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Premium Header Widget ────────────────────────────────────────────────────

class _LibraryHeader extends StatelessWidget {
  final bool showTimeline;
  final VoidCallback onToggle;
  final GalleryProvider provider;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _LibraryHeader({
    required this.showTimeline,
    required this.onToggle,
    required this.provider,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    // Respect the system status bar height
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.35),
            width: 0.8,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, topPadding + 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Row 1: Title + action icons ────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Gradient icon
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [
                      colorScheme.primary,
                      colorScheme.tertiary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: const Icon(
                    Icons.photo_library_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 10),
                // Title
                Text(
                  'Library',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                // Count badge
                if (provider.status == GalleryStatus.loaded &&
                    provider.totalAssetsCount > 0) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${provider.totalAssetsCount}',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                // ── Action icon buttons ──────────────────────────────────
                _HeaderIconButton(
                  icon: Icons.search_rounded,
                  tooltip: 'Search',
                  colorScheme: colorScheme,
                  onTap: () => showSearch(
                    context: context,
                    delegate: SearchHubDelegate(),
                  ),
                ),
                const SizedBox(width: 4),
                _HeaderIconButton(
                  icon: Icons.calendar_month_rounded,
                  tooltip: 'Calendar',
                  colorScheme: colorScheme,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CalendarScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Row 2: Segmented view-toggle pill ──────────────────────
            _ViewTogglePill(
              showTimeline: showTimeline,
              onToggle: onToggle,
              colorScheme: colorScheme,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Circular icon button used in header ─────────────────────────────────────

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(50),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.surfaceContainerHighest,
          ),
          child: Icon(
            icon,
            size: 20,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ─── Segmented view toggle pill ──────────────────────────────────────────────

class _ViewTogglePill extends StatelessWidget {
  final bool showTimeline;
  final VoidCallback onToggle;
  final ColorScheme colorScheme;

  const _ViewTogglePill({
    required this.showTimeline,
    required this.onToggle,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleSegment(
            icon: Icons.view_agenda_rounded,
            label: 'Timeline',
            isSelected: showTimeline,
            colorScheme: colorScheme,
            onTap: showTimeline ? null : onToggle,
          ),
          _ToggleSegment(
            icon: Icons.grid_view_rounded,
            label: 'Grid',
            isSelected: !showTimeline,
            colorScheme: colorScheme,
            onTap: showTimeline ? onToggle : null,
          ),
        ],
      ),
    );
  }
}

class _ToggleSegment extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final ColorScheme colorScheme;
  final VoidCallback? onTap;

  const _ToggleSegment({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
