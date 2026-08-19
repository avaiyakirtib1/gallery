import 'package:photo_manager/photo_manager.dart';
import 'people_group_model.dart';

/// Represents a "Then & Now" Growth Story comparing two people across time.
class ThenAndNowStory {
  final String id;
  final String title;
  final PersonCluster personA;
  final PersonCluster personB;
  final List<AssetEntity> chronologicalAssets;

  const ThenAndNowStory({
    required this.id,
    required this.title,
    required this.personA,
    required this.personB,
    required this.chronologicalAssets,
  });

  AssetEntity get thenAsset => chronologicalAssets.first;

  AssetEntity get nowAsset => chronologicalAssets.last;

  int get startYear => thenAsset.createDateTime.year;

  int get endYear => nowAsset.createDateTime.year;

  int get yearsDifference => (endYear - startYear).abs();

  String get subtitle => '$startYear – $endYear • $yearsDifference Yrs Journey';
}
