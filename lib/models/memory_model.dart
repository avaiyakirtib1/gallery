import 'package:photo_manager/photo_manager.dart';

/// Represents a group of media assets captured on the same day.
class Memory {
  final DateTime date;
  final List<AssetEntity> assets;

  const Memory({
    required this.date,
    required this.assets,
  });

  /// Cover asset used for card thumbnail and hero animation.
  AssetEntity get coverAsset => assets.first;

  /// Hero tag used to animate the cover between list and detail.
  String get heroTag => 'memory_cover_${date.toIso8601String()}';

  /// Number of photo assets in this memory.
  int get photoCount => assets.where((a) => a.type == AssetType.image).length;

  /// Number of video assets in this memory.
  int get videoCount => assets.where((a) => a.type == AssetType.video).length;

  /// Human-readable title, e.g. "Memory • 18 Dec 2025"
  String get title {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return 'Memory • ${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
