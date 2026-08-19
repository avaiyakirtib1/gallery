import 'package:photo_manager/photo_manager.dart';

/// Represents a detected person/face cluster.
class PersonCluster {
  final String id;
  String name;
  final List<AssetEntity> assets;

  PersonCluster({
    required this.id,
    required this.name,
    required this.assets,
  });

  AssetEntity get avatarAsset => assets.first;

  int get count => assets.length;
}
