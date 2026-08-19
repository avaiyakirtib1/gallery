import 'package:photo_manager/photo_manager.dart';

/// A cluster of media assets captured near the same GPS location.
class LocationGroup {
  final double latitude;
  final double longitude;
  final List<AssetEntity> assets;

  const LocationGroup({
    required this.latitude,
    required this.longitude,
    required this.assets,
  });

  AssetEntity get coverAsset => assets.first;

  int get count => assets.length;

  /// Human-readable coordinate string.
  String get coordinateLabel {
    final latDir = latitude >= 0 ? 'N' : 'S';
    final lngDir = longitude >= 0 ? 'E' : 'W';
    return '${latitude.abs().toStringAsFixed(4)}°$latDir, '
        '${longitude.abs().toStringAsFixed(4)}°$lngDir';
  }
}
