import 'package:photo_manager/photo_manager.dart';

/// A cluster of burst photos or near-duplicate shots taken within < 3 seconds.
class DuplicateGroup {
  final List<AssetEntity> assets;

  const DuplicateGroup({required this.assets});

  AssetEntity get bestAsset => assets.first;

  List<AssetEntity> get duplicateAssets => assets.sublist(1);

  int get count => assets.length;
}
