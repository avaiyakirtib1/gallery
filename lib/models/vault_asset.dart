import 'package:photo_manager/photo_manager.dart';

/// Represents a media asset (photo/video) locked in the private vault or moved to trash.
class VaultAsset {
  final String id;
  final String localPath;
  final String originalName;
  final DateTime createDateTime;
  final AssetType type;
  final int duration;
  final int width;
  final int height;
  final double? latitude;
  final double? longitude;
  final DateTime? deletedAt;
  final String origin; // 'vault' or 'gallery'

  const VaultAsset({
    required this.id,
    required this.localPath,
    required this.originalName,
    required this.createDateTime,
    required this.type,
    this.duration = 0,
    required this.width,
    required this.height,
    this.latitude,
    this.longitude,
    this.deletedAt,
    this.origin = 'vault',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'localPath': localPath,
      'originalName': originalName,
      'createDateTime': createDateTime.toIso8601String(),
      'type': type.index, // Use index for standard enum serialization
      'duration': duration,
      'width': width,
      'height': height,
      'latitude': latitude,
      'longitude': longitude,
      'deletedAt': deletedAt?.toIso8601String(),
      'origin': origin,
    };
  }

  factory VaultAsset.fromJson(Map<String, dynamic> json) {
    // Determine the AssetType from the stored int value
    final typeValue = json['type'] as int;
    AssetType assetType = AssetType.other;
    for (final val in AssetType.values) {
      if (val.index == typeValue) {
        assetType = val;
        break;
      }
    }

    return VaultAsset(
      id: json['id'] as String,
      localPath: json['localPath'] as String,
      originalName: json['originalName'] as String,
      createDateTime: DateTime.parse(json['createDateTime'] as String),
      type: assetType,
      duration: json['duration'] as int? ?? 0,
      width: json['width'] as int? ?? 0,
      height: json['height'] as int? ?? 0,
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
      deletedAt: json['deletedAt'] != null ? DateTime.parse(json['deletedAt'] as String) : null,
      origin: json['origin'] as String? ?? 'vault',
    );
  }
}
