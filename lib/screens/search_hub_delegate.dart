import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';
import '../providers/gallery_provider.dart';
import '../widgets/grid_thumbnail.dart';

class SearchHubDelegate extends SearchDelegate<AssetEntity?> {
  SearchHubDelegate()
      : super(
          searchFieldLabel: 'Search text in images (Receipts, Wi-Fi, Notes…)',
        );

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear_rounded),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (query.isNotEmpty) {
      return _buildSearchResults(context);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Quick Document & Text Search (OCR)',
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _PresetChip(
              icon: Icons.receipt_long_outlined,
              label: 'Receipts & Bills',
              onTap: () => query = 'receipt',
            ),
            _PresetChip(
              icon: Icons.wifi_rounded,
              label: 'Wi-Fi Passwords',
              onTap: () => query = 'wifi',
            ),
            _PresetChip(
              icon: Icons.confirmation_number_outlined,
              label: 'Tickets & Passes',
              onTap: () => query = 'ticket',
            ),
            _PresetChip(
              icon: Icons.notes_outlined,
              label: 'Notes & Whiteboards',
              onTap: () => query = 'note',
            ),
            _PresetChip(
              icon: Icons.description_outlined,
              label: 'Invoices & Documents',
              onTap: () => query = 'invoice',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchResults(BuildContext context) {
    final provider = context.watch<GalleryProvider>();
    final results = provider.searchAssets(query);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.find_in_page_outlined,
                size: 64,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No matching text/document photos',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try searching for "receipt", "wifi", "ticket", or date keywords.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: results.length,
        itemBuilder: (context, index) {
          return GridThumbnail(
            asset: results[index],
            index: index,
            allAssets: results,
          );
        },
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PresetChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ActionChip(
      avatar: Icon(icon, size: 16, color: colorScheme.primary),
      label: Text(label),
      onPressed: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
