
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import '../providers/gallery_provider.dart';
import '../models/people_group_model.dart';
import '../models/event_trip_model.dart';
import '../screens/people_photos_screen.dart';
import '../screens/day_photos_screen.dart';

class PeopleEventsCarousel extends StatelessWidget {
  const PeopleEventsCarousel({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GalleryProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final people = provider.peopleClusters;
    final events = provider.smartEvents;

    if (people.isEmpty && events.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── People & Faces Section ──────────────────────────────────────────
        if (people.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.face_retouching_natural_rounded,
                    size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'People & Faces',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: people.length,
              itemBuilder: (context, index) {
                final person = people[index];
                return _PersonAvatarBubble(person: person);
              },
            ),
          ),
        ],

        // ─── Smart Trips & Events Section ─────────────────────────────────────
        if (events.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.flight_takeoff_rounded,
                    size: 18, color: colorScheme.tertiary),
                const SizedBox(width: 8),
                Text(
                  'Smart Trips & Auto-Grouped Events',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                return _EventCardTile(event: event);
              },
            ),
          ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }
}

// ─── Person Avatar Bubble Widget ─────────────────────────────────────────────

class _PersonAvatarBubble extends StatelessWidget {
  final PersonCluster person;

  const _PersonAvatarBubble({required this.person});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PeoplePhotosScreen(person: person),
            ),
          );
        },
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colorScheme.primary, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipOval(
                child: AssetEntityImage(
                  person.avatarAsset,
                  isOriginal: false,
                  thumbnailSize: const ThumbnailSize.square(200),
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
              ),
            ),
            const SizedBox(height: 4),
            Text(
              person.name,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Event Card Tile Widget ──────────────────────────────────────────────────

class _EventCardTile extends StatelessWidget {
  final SmartEvent event;

  const _EventCardTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DayPhotosScreen(
                date: event.startDate,
                assets: event.assets,
              ),
            ),
          );
        },
        child: Container(
          width: 160,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: colorScheme.surfaceContainerHighest,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                AssetEntityImage(
                  event.coverAsset,
                  isOriginal: false,
                  thumbnailSize: const ThumbnailSize(350, 220),
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
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xDD000000)],
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  bottom: 8,
                  right: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${event.count} items • ${event.durationLabel}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
