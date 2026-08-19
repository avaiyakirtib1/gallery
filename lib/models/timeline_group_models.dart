import 'package:photo_manager/photo_manager.dart';
import 'memory_model.dart';

/// Aggregates all memories captured in a single year.
class YearGroup {
  final int year;
  final List<Memory> memories;

  const YearGroup({
    required this.year,
    required this.memories,
  });

  AssetEntity get coverAsset => memories.first.coverAsset;

  int get totalAssets =>
      memories.fold(0, (sum, m) => sum + m.assets.length);

  int get monthCount {
    final months = memories.map((m) => m.date.month).toSet();
    return months.length;
  }
}

/// Aggregates all memories captured in a single month of a year.
class MonthGroup {
  final int year;
  final int month;
  final List<Memory> memories;

  const MonthGroup({
    required this.year,
    required this.month,
    required this.memories,
  });

  AssetEntity get coverAsset => memories.first.coverAsset;

  int get totalAssets =>
      memories.fold(0, (sum, m) => sum + m.assets.length);

  String get monthName {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return months[month - 1];
  }

  String get title => '$monthName $year';
}
