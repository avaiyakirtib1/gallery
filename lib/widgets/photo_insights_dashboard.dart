import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/gallery_provider.dart';

class PhotoInsightsDashboard extends StatefulWidget {
  const PhotoInsightsDashboard({super.key});

  @override
  State<PhotoInsightsDashboard> createState() => _PhotoInsightsDashboardState();
}

class _PhotoInsightsDashboardState extends State<PhotoInsightsDashboard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GalleryProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (provider.totalAssetsCount == 0) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
                colorScheme.surface.withValues(alpha: 0.95),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              // ─── Header Tap Target ──────────────────────────────────────────
              InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.insights_rounded,
                          color: colorScheme.onPrimaryContainer,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gallery Insights',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _isExpanded
                                  ? 'On-device analytics of your media habits'
                                  : 'Tap to view media patterns & statistics',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: _isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 250),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Expanded Dashboard Details ────────────────────────────────
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    children: [
                      const Divider(height: 1),
                      const SizedBox(height: 20),

                      // ─── Metric Cards Grid ──────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: _MetricCard(
                              icon: Icons.camera_alt_outlined,
                              title: 'Active Hour',
                              value: provider.peakHourLabel,
                              subtitle: 'Peak Capture Time',
                              colorScheme: colorScheme,
                              textTheme: textTheme,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _MetricCard(
                              icon: Icons.photo_library_outlined,
                              title: 'Total Media',
                              value: '${provider.totalAssetsCount}',
                              subtitle: '${provider.memories.length} Memories',
                              colorScheme: colorScheme,
                              textTheme: textTheme,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ─── Capture Habits (Weekday vs Weekend) ───────────────
                      _HabitsSection(
                        title: 'Media Habits',
                        item1Label: 'Camera Photos',
                        item1Value: provider.cameraCount,
                        item2Label: 'Screenshots',
                        item2Value: provider.screenshotCount,
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                        barColor1: colorScheme.primary,
                        barColor2: colorScheme.secondary,
                      ),
                      const SizedBox(height: 18),

                      _HabitsSection(
                        title: 'Activity Window',
                        item1Label: 'Weekdays',
                        item1Value: provider.weekdayCount,
                        item2Label: 'Weekends',
                        item2Value: provider.weekendCount,
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                        barColor1: colorScheme.tertiary,
                        barColor2: colorScheme.error,
                      ),
                      const SizedBox(height: 24),

                      // ─── Time of Day Distribution ──────────────────────────
                      _TimeOfDaySection(
                        provider: provider,
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                      ),
                    ],
                  ),
                ),
                crossFadeState: _isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 300),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Metric Card Helper Widget ───────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _MetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Habits Section (Ratio Split Bar) ────────────────────────────────────────

class _HabitsSection extends StatelessWidget {
  final String title;
  final String item1Label;
  final int item1Value;
  final String item2Label;
  final int item2Value;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final Color barColor1;
  final Color barColor2;

  const _HabitsSection({
    required this.title,
    required this.item1Label,
    required this.item1Value,
    required this.item2Label,
    required this.item2Value,
    required this.colorScheme,
    required this.textTheme,
    required this.barColor1,
    required this.barColor2,
  });

  @override
  Widget build(BuildContext context) {
    final total = item1Value + item2Value;
    final pct1 = total > 0 ? (item1Value / total) : 0.5;
    final pct2 = total > 0 ? (item2Value / total) : 0.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                Expanded(
                  flex: (pct1 * 100).toInt().clamp(1, 99),
                  child: Container(color: barColor1),
                ),
                Expanded(
                  flex: (pct2 * 100).toInt().clamp(1, 99),
                  child: Container(color: barColor2),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: barColor1),
                ),
                const SizedBox(width: 6),
                Text(
                  '$item1Label: ${(pct1 * 100).toStringAsFixed(0)}% ($item1Value)',
                  style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: barColor2),
                ),
                const SizedBox(width: 6),
                Text(
                  '$item2Label: ${(pct2 * 100).toStringAsFixed(0)}% ($item2Value)',
                  style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Time of Day Section (Bar Distributions) ─────────────────────────────────

class _TimeOfDaySection extends StatelessWidget {
  final GalleryProvider provider;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _TimeOfDaySection({
    required this.provider,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    final m = provider.morningCount;
    final a = provider.afternoonCount;
    final e = provider.eveningCount;
    final n = provider.nightCount;

    final maxVal = [m, a, e, n].reduce((curr, next) => curr > next ? curr : next);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Media Capture by Time of Day',
          style: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        _TimeOfDayBar(
          label: 'Morning (6 AM - 12 PM)',
          value: m,
          maxVal: maxVal,
          icon: Icons.wb_sunny_outlined,
          colorScheme: colorScheme,
          textTheme: textTheme,
        ),
        _TimeOfDayBar(
          label: 'Afternoon (12 PM - 5 PM)',
          value: a,
          maxVal: maxVal,
          icon: Icons.sunny,
          colorScheme: colorScheme,
          textTheme: textTheme,
        ),
        _TimeOfDayBar(
          label: 'Evening (5 PM - 9 PM)',
          value: e,
          maxVal: maxVal,
          icon: Icons.wb_twighlight,
          colorScheme: colorScheme,
          textTheme: textTheme,
        ),
        _TimeOfDayBar(
          label: 'Night (9 PM - 6 AM)',
          value: n,
          maxVal: maxVal,
          icon: Icons.nights_stay_outlined,
          colorScheme: colorScheme,
          textTheme: textTheme,
        ),
      ],
    );
  }
}

class _TimeOfDayBar extends StatelessWidget {
  final String label;
  final int value;
  final int maxVal;
  final IconData icon;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _TimeOfDayBar({
    required this.label,
    required this.value,
    required this.maxVal,
    required this.icon,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    final double pct = maxVal > 0 ? (value / maxVal) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ),
              Text(
                '$value items',
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
