import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/gallery_provider.dart';
import '../models/memory_model.dart';
import '../widgets/memory_card.dart';
import '../widgets/permission_prompt.dart';
import '../widgets/timeline_view_widgets.dart';
// import '../widgets/then_now_status_row.dart';
import 'search_hub_delegate.dart';
import 'calendar_screen.dart';

enum TimelineZoomLevel { years, months, days }

// ─── Timeline item types for Days view ──────────────────────────────────────

sealed class _Entry {}

class _YearEntry extends _Entry {
  final int year;
  _YearEntry(this.year);
}

class _MonthEntry extends _Entry {
  final int year;
  final int month;
  _MonthEntry(this.year, this.month);
}

class _DayEntry extends _Entry {
  final Memory memory;
  _DayEntry(this.memory);
}

// ─── Screen ───────────────────────────────────────────────────────────────

class TimelineScreen extends StatefulWidget {
  final VoidCallback? onToggleView;
  final bool showTimeline;
  final bool showHeader;

  const TimelineScreen({
    super.key,
    this.onToggleView,
    this.showTimeline = true,
    this.showHeader = true,
  });

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  TimelineZoomLevel _zoomLevel = TimelineZoomLevel.days;
  int? _selectedYearFilter;
  int? _selectedMonthFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<GalleryProvider>();
      if (provider.status == GalleryStatus.idle ||
          provider.status == GalleryStatus.error) {
        provider.loadGallery();
      }
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedYearFilter = null;
      _selectedMonthFilter = null;
    });
  }

  /// Flattens memories into a list with Year and Month separator entries.
  List<_Entry> _buildEntries(List<Memory> memories) {
    // Filter memories if a year or month filter is active
    final filtered = memories.where((m) {
      if (_selectedYearFilter != null && m.date.year != _selectedYearFilter) {
        return false;
      }
      if (_selectedMonthFilter != null && m.date.month != _selectedMonthFilter) {
        return false;
      }
      return true;
    }).toList();

    final items = <_Entry>[];
    int? currentYear;
    int? currentMonth;

    for (final memory in filtered) {
      final y = memory.date.year;
      final m = memory.date.month;

      if (y != currentYear) {
        items.add(_YearEntry(y));
        currentYear = y;
        currentMonth = null;
      }
      if (m != currentMonth) {
        items.add(_MonthEntry(y, m));
        currentMonth = m;
      }
      items.add(_DayEntry(memory));
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Consumer<GalleryProvider>(
        builder: (context, provider, _) {
          return CustomScrollView(
            slivers: [
              // ─── App Bar (only when standalone, not embedded) ───────────
              if (widget.showHeader) SliverAppBar(
                expandedHeight: 90,
                floating: true,
                snap: true,
                backgroundColor: colorScheme.surface,
                surfaceTintColor: Colors.transparent,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                  title: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [
                            colorScheme.primary,
                            colorScheme.tertiary,
                          ],
                        ).createShader(bounds),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Memories',
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  if (provider.status == GalleryStatus.loaded) ...[
                    if (widget.onToggleView != null)
                      IconButton(
                        icon: const Icon(Icons.grid_view_rounded),
                        tooltip: 'Switch to Grid View',
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
                      onPressed: () {
                        showSearch(
                          context: context,
                          delegate: SearchHubDelegate(),
                        );
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${provider.memories.length} memories',
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              // ─── View Switcher Segmented Control ───────────────────────
              if (provider.status == GalleryStatus.loaded &&
                  provider.memories.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Center(
                      child: SegmentedButton<TimelineZoomLevel>(
                        segments: const [
                          ButtonSegment<TimelineZoomLevel>(
                            value: TimelineZoomLevel.years,
                            label: Text('Years'),
                            icon: Icon(Icons.calendar_today_rounded, size: 16),
                          ),
                          ButtonSegment<TimelineZoomLevel>(
                            value: TimelineZoomLevel.months,
                            label: Text('Months'),
                            icon: Icon(Icons.grid_view_rounded, size: 16),
                          ),
                          ButtonSegment<TimelineZoomLevel>(
                            value: TimelineZoomLevel.days,
                            label: Text('Days'),
                            icon: Icon(Icons.view_agenda_rounded, size: 16),
                          ),
                        ],
                        selected: {_zoomLevel},
                        onSelectionChanged: (Set<TimelineZoomLevel> newSelection) {
                          setState(() {
                            _zoomLevel = newSelection.first;
                          });
                        },
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  ),
                ),

              // ─── Then & Now Growth Story Statuses Row (Disabled) ──────────
              // if (provider.status == GalleryStatus.loaded &&
              //     provider.memories.isNotEmpty &&
              //     _selectedYearFilter == null)
              //   const SliverToBoxAdapter(
              //     child: ThenNowStatusRow(),
              //   ),
              if (_selectedYearFilter != null || _selectedMonthFilter != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.filter_alt_outlined,
                            size: 16,
                            color: colorScheme.onTertiaryContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Filter: ${_selectedYearFilter ?? ''}'
                              '${_selectedMonthFilter != null ? ' • Month $_selectedMonthFilter' : ''}',
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onTertiaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: _clearFilters,
                            child: Icon(
                              Icons.cancel,
                              size: 18,
                              color: colorScheme.onTertiaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Photo Insights Dashboard relocated to Explore Screen

              // ─── Content Depending on Zoom Level ───────────────────────
              _buildContent(provider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(GalleryProvider provider) {
    switch (provider.status) {
      case GalleryStatus.idle:
        return const SliverFillRemaining(child: SizedBox.shrink());

      case GalleryStatus.loading:
        return const SliverFillRemaining(
          child: Center(child: _LoadingView()),
        );

      case GalleryStatus.permissionDenied:
        return SliverFillRemaining(
          child: PermissionPrompt(
            onGrantPermission: () =>
                context.read<GalleryProvider>().loadGallery(),
            onOpenSettings: () =>
                context.read<GalleryProvider>().openSettings(),
          ),
        );

      case GalleryStatus.error:
        return SliverFillRemaining(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    provider.errorMessage ?? 'Unknown error',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () =>
                        context.read<GalleryProvider>().loadGallery(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        );

      case GalleryStatus.loaded:
        if (provider.memories.isEmpty) {
          return const SliverFillRemaining(child: Center(child: _EmptyView()));
        }

        return switch (_zoomLevel) {
          TimelineZoomLevel.years => _buildYearsView(provider),
          TimelineZoomLevel.months => _buildMonthsView(provider),
          TimelineZoomLevel.days => _buildDaysView(provider),
        };
    }
  }

  // ─── 1. Years View ────────────────────────────────────────────────────────

  Widget _buildYearsView(GalleryProvider provider) {
    final years = provider.yearGroups;
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final yearGroup = years[index];
          return YearCard(
            yearGroup: yearGroup,
            onTap: () {
              setState(() {
                _selectedYearFilter = yearGroup.year;
                _selectedMonthFilter = null;
                _zoomLevel = TimelineZoomLevel.months;
              });
            },
          );
        },
        childCount: years.length,
      ),
    );
  }

  // ─── 2. Months View ───────────────────────────────────────────────────────

  Widget _buildMonthsView(GalleryProvider provider) {
    var months = provider.monthGroups;
    if (_selectedYearFilter != null) {
      months = months.where((m) => m.year == _selectedYearFilter).toList();
    }

    if (months.isEmpty) {
      return const SliverFillRemaining(
        child: Center(child: Text('No months found for selected filter')),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.1,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final monthGroup = months[index];
            return MonthCard(
              monthGroup: monthGroup,
              onTap: () {
                setState(() {
                  _selectedYearFilter = monthGroup.year;
                  _selectedMonthFilter = monthGroup.month;
                  _zoomLevel = TimelineZoomLevel.days;
                });
              },
            );
          },
          childCount: months.length,
        ),
      ),
    );
  }

  // ─── 3. Days View ─────────────────────────────────────────────────────────

  Widget _buildDaysView(GalleryProvider provider) {
    final entries = _buildEntries(provider.memories);

    if (entries.isEmpty) {
      return const SliverFillRemaining(
        child: Center(child: Text('No memories match the active filter')),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final entry = entries[index];
          return switch (entry) {
            _YearEntry(:final year) => _YearHeader(year: year),
            _MonthEntry(:final year, :final month) =>
              _MonthHeader(year: year, month: month),
            _DayEntry(:final memory) => MemoryCard(
                memory: memory,
                index: index,
              ),
          };
        },
        childCount: entries.length,
      ),
    );
  }
}

// ─── Year header ──────────────────────────────────────────────────────────

class _YearHeader extends StatelessWidget {
  final int year;
  const _YearHeader({required this.year});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colorScheme.primary, colorScheme.tertiary],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$year',
              style: TextStyle(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Divider(
              color: colorScheme.outlineVariant,
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Month header ─────────────────────────────────────────────────────────

class _MonthHeader extends StatelessWidget {
  final int year;
  final int month;

  const _MonthHeader({required this.year, required this.month});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(
        months[month - 1],
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}

// ─── Loading view ─────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Discovering your memories…',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

// ─── Empty view ───────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.photo_album_outlined,
          size: 80,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
        ),
        const SizedBox(height: 16),
        Text(
          'No memories found',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Take some photos to get started!',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
        ),
      ],
    );
  }
}
