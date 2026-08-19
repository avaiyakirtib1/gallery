import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/gallery_provider.dart';
import 'cleaner_grid_screen.dart';
import 'vault_pin_entry_screen.dart';
import 'vault_trash_screen.dart';

class StorageHubScreen extends StatelessWidget {
  const StorageHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final provider = context.watch<GalleryProvider>();

    final totalDuplicates = provider.duplicateGroups.fold<int>(
        0, (sum, g) => sum + g.duplicateAssets.length);
    final totalScreenshots = provider.screenshotAssets.length;
    final totalLarge = provider.largeAssets.length;
    final totalCleanable = totalDuplicates + totalScreenshots;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.cleaning_services_rounded, color: colorScheme.primary),
            const SizedBox(width: 10),
            Text(
              'Utilities & Storage',
              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: colorScheme.surface,
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ─── Hero Storage Gauge Card ─────────────────────────────────
                _StorageGaugeCard(
                  totalItems: provider.totalAssetsCount,
                  cleanableItems: totalCleanable,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                ),
                const SizedBox(height: 24),

                Text(
                  'Storage Buckets to Clean',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),

                // ─── 1. Burst Shots & Duplicates Bucket ──────────────────────
                _BucketCard(
                  icon: Icons.burst_mode_rounded,
                  title: 'Duplicate & Burst Shots',
                  subtitle: '$totalDuplicates duplicate shots detected in gallery',
                  badgeText: '${provider.duplicateGroups.length} Burst Groups',
                  iconColor: Colors.amber.shade700,
                  buttonLabel: 'Review & Clean',
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CleanerGridScreen(
                          category: CleanerCategory.duplicates,
                          title: 'Duplicates & Burst Shots',
                          initialAssets: provider.duplicateGroups
                              .expand((g) => g.assets)
                              .toList(),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),

                // ─── 2. Screenshot Pile-up Bucket ───────────────────────────
                _BucketCard(
                  icon: Icons.screenshot_rounded,
                  title: 'Screenshot Pile-Up',
                  subtitle: '$totalScreenshots screenshots taking up storage space',
                  badgeText: '$totalScreenshots Items',
                  iconColor: Colors.blue.shade600,
                  buttonLabel: 'Clean Screenshots',
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CleanerGridScreen(
                          category: CleanerCategory.screenshots,
                          title: 'Screenshot Pile-Up',
                          initialAssets: provider.screenshotAssets,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),

                // ─── 3. Large Files & Videos Bucket ─────────────────────────
                _BucketCard(
                  icon: Icons.video_library_rounded,
                  title: 'Large Files & Videos',
                  subtitle: '$totalLarge largest video & photo files',
                  badgeText: '$totalLarge Large Items',
                  iconColor: Colors.purple.shade600,
                  buttonLabel: 'Manage Large Files',
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CleanerGridScreen(
                          category: CleanerCategory.largeFiles,
                          title: 'Large Files & Videos',
                          initialAssets: provider.largeAssets,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),

                // ─── 4. Secure Private Vault Bucket ─────────────────────────
                _BucketCard(
                  icon: Icons.lock_rounded,
                  title: 'Secure Private Vault',
                  subtitle: 'Hide and secure sensitive files behind a PIN passcode',
                  badgeText: '${provider.vaultedAssetsCount} Locked Items',
                  iconColor: Colors.deepPurple.shade600,
                  buttonLabel: 'Access Vault',
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const VaultPinEntryScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),

                // ─── 5. Recycle Bin / Trash Bucket ─────────────────────────
                _BucketCard(
                  icon: Icons.delete_sweep_rounded,
                  title: 'Recycle Bin',
                  subtitle: 'Recover soft-deleted photos and videos within 30 days',
                  badgeText: '${provider.trashAssetsCount} Items Trashed',
                  iconColor: Colors.red.shade600,
                  buttonLabel: 'Open Trash',
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const VaultTrashScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }
}

// ─── Hero Storage Gauge Card ─────────────────────────────────────────────────

class _StorageGaugeCard extends StatelessWidget {
  final int totalItems;
  final int cleanableItems;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _StorageGaugeCard({
    required this.totalItems,
    required this.cleanableItems,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    final pctCleanable = totalItems > 0 ? (cleanableItems / totalItems) : 0.0;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            colors: [
              colorScheme.primaryContainer,
              colorScheme.tertiaryContainer.withValues(alpha: 0.6),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gallery Storage Health',
                        style: textTheme.labelLarge?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$totalItems Total Media Items',
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.speed_rounded,
                    size: 28,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 8,
                child: LinearProgressIndicator(
                  value: pctCleanable.clamp(0.05, 1.0),
                  backgroundColor: Colors.black.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.auto_fix_high_rounded,
                  size: 16,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$cleanableItems clutter items recommended for cleanup',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bucket Action Card Helper Widget ────────────────────────────────────────

class _BucketCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String badgeText;
  final Color iconColor;
  final String buttonLabel;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback onTap;

  const _BucketCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.iconColor,
    required this.buttonLabel,
    required this.colorScheme,
    required this.textTheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badgeText,
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
