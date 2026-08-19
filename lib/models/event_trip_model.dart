import 'package:photo_manager/photo_manager.dart';

/// Represents an auto-grouped Trip or Event detected via photo time-density.
class SmartEvent {
  final String id;
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final List<AssetEntity> assets;
  final bool isTrip;

  const SmartEvent({
    required this.id,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.assets,
    required this.isTrip,
  });

  AssetEntity get coverAsset => assets.first;

  int get count => assets.length;

  String get durationLabel {
    if (isTrip) {
      final days = endDate.difference(startDate).inDays + 1;
      return '$days Days Trip';
    }
    final hour = startDate.hour;
    if (hour >= 5 && hour < 12) return 'Morning Event';
    if (hour >= 12 && hour < 17) return 'Afternoon Event';
    if (hour >= 17 && hour < 21) return 'Evening Outing';
    return 'Night Event';
  }
}
