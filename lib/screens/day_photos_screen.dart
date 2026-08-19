import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../widgets/grid_thumbnail.dart';

class DayPhotosScreen extends StatelessWidget {
  final DateTime date;
  final List<AssetEntity> assets;

  const DayPhotosScreen({
    super.key,
    required this.date,
    required this.assets,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    const months = [
      'January', 'February', 'March', 'April',
      'May', 'June', 'July', 'August',
      'September', 'October', 'November', 'December',
    ];
    final titleString = '${date.day} ${months[date.month - 1]} ${date.year}';

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Photos on this Day',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              titleString,
              style: textTheme.titleSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: colorScheme.surface,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      body: Padding(
        padding: const EdgeInsets.all(4.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: assets.length,
          itemBuilder: (context, index) {
            return GridThumbnail(
              asset: assets[index],
              index: index,
              allAssets: assets,
            );
          },
        ),
      ),
    );
  }
}
