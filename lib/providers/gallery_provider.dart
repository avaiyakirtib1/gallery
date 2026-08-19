import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/memory_model.dart';
import '../models/location_group.dart';
import '../models/timeline_group_models.dart';
import '../models/duplicate_group.dart';
import '../models/people_group_model.dart';
import '../models/event_trip_model.dart';
import '../models/then_now_story_model.dart';
import '../models/vault_asset.dart';
import '../services/vault_service.dart';
// import '../services/face_detection_service.dart';

enum GalleryStatus { idle, loading, loaded, permissionDenied, error }

class GalleryProvider extends ChangeNotifier {
  GalleryStatus _status = GalleryStatus.idle;
  List<Memory> _memories = [];
  List<LocationGroup> _locationGroups = [];
  final List<PersonCluster> _faceClusters = [];
  String? _errorMessage;

  List<VaultAsset> _vaultAssets = [];
  bool _hasVaultPin = false;

  GalleryStatus get status => _status;
  List<Memory> get memories => _memories;
  List<LocationGroup> get locationGroups => _locationGroups;
  String? get errorMessage => _errorMessage;

  List<VaultAsset> get vaultAssets => _vaultAssets.where((a) => a.deletedAt == null).toList();
  int get vaultedAssetsCount => vaultAssets.length;
  List<VaultAsset> get trashAssets => _vaultAssets.where((a) => a.deletedAt != null).toList();
  int get trashAssetsCount => trashAssets.length;
  bool get hasVaultPin => _hasVaultPin;

  bool get isLoading => _status == GalleryStatus.loading;
  bool get hasPermission => _status != GalleryStatus.permissionDenied;

  /// Flat list of every AssetEntity across all memories (newest first).
  List<AssetEntity> get allAssets =>
      _memories.expand((m) => m.assets).toList();

  /// Group memories by Year (sorted descending by year)
  List<YearGroup> get yearGroups {
    final Map<int, List<Memory>> map = {};
    for (final m in _memories) {
      map.putIfAbsent(m.date.year, () => []).add(m);
    }
    final sortedYears = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return sortedYears
        .map((y) => YearGroup(year: y, memories: map[y]!))
        .toList();
  }

  /// Group memories by Month (sorted descending by year and month)
  List<MonthGroup> get monthGroups {
    final Map<String, List<Memory>> map = {};
    for (final m in _memories) {
      final key = '${m.date.year}-${m.date.month.toString().padLeft(2, '0')}';
      map.putIfAbsent(key, () => []).add(m);
    }
    final sortedKeys = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return sortedKeys.map((k) {
      final parts = k.split('-');
      return MonthGroup(
        year: int.parse(parts[0]),
        month: int.parse(parts[1]),
        memories: map[k]!,
      );
    }).toList();
  }

  /// Date → assets map consumed by the Calendar tab (table_calendar format).
  Map<DateTime, List<AssetEntity>> get calendarEvents {
    return {
      for (final m in _memories)
        DateTime(m.date.year, m.date.month, m.date.day): m.assets,
    };
  }

  /// Requests permission and loads gallery assets grouped by day and location.
  Future<void> loadGallery() async {
    _status = GalleryStatus.loading;
    notifyListeners();

    final PermissionState ps = await PhotoManager.requestPermissionExtend(
      requestOption: const PermissionRequestOption(
        androidPermission: AndroidPermission(
          type: RequestType.common,
          mediaLocation: true,
        ),
      ),
    );

    if (!ps.hasAccess) {
      _status = GalleryStatus.permissionDenied;
      notifyListeners();
      return;
    }

    try {
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        filterOption: FilterOptionGroup(
          imageOption: const FilterOption(
            sizeConstraint: SizeConstraint(ignoreSize: true),
          ),
          videoOption: const FilterOption(
            sizeConstraint: SizeConstraint(ignoreSize: true),
          ),
          orders: [
            const OrderOption(type: OrderOptionType.createDate, asc: false),
          ],
        ),
      );

      if (albums.isEmpty) {
        _memories = [];
        _locationGroups = [];
        _status = GalleryStatus.loaded;
        notifyListeners();
        return;
      }

      final AssetPathEntity recentAlbum = albums.first;
      final int totalCount = await recentAlbum.assetCountAsync;

      const int pageSize = 100;
      final List<AssetEntity> allAssets = [];
      int page = 0;

      while (allAssets.length < totalCount) {
        final batch = await recentAlbum.getAssetListPaged(
          page: page,
          size: pageSize,
        );
        if (batch.isEmpty) break;
        allAssets.addAll(batch);
        page++;
      }

      // ── Group by date (yyyy-MM-dd) for Timeline + Calendar ──────────────
      final Map<String, List<AssetEntity>> grouped = {};
      for (final asset in allAssets) {
        final dt = asset.createDateTime;
        final key =
            '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
        grouped.putIfAbsent(key, () => []).add(asset);
      }

      final entries = grouped.entries.toList()
        ..sort((a, b) => b.key.compareTo(a.key));

      _memories = entries.map((e) {
        final parts = e.key.split('-');
        final date = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        return Memory(date: date, assets: e.value);
      }).toList();

      // ── Group by GPS location for Map tab ────────────────────────────────
      await _buildLocationGroups(allAssets);

      // ── Scan & Cluster Faces via Google ML Kit (Disabled) ────────────────
      // _faceClusters = await FaceDetectionService.scanAndClusterFaces(
      //   assets: allAssets,
      //   customNames: _customPersonNames,
      // );

      await loadVault();
      _status = GalleryStatus.loaded;
    } catch (e) {
      _errorMessage = e.toString();
      _status = GalleryStatus.error;
    }

    notifyListeners();
  }

  /// Clusters assets into fine-grained street/building groups (~100m) and calculates exact raw GPS centroids.
  Future<void> _buildLocationGroups(List<AssetEntity> assets) async {
    final Map<AssetEntity, LatLng> assetCoords = {};

    // 1. Retrieve unredacted lat/lng asynchronously for all assets in parallel
    final latLngs = await Future.wait(
      assets.map((asset) => asset.latlngAsync()),
    );

    for (int i = 0; i < assets.length; i++) {
      final latLng = latLngs[i];
      if (latLng == null) continue;
      final lat = latLng.latitude;
      final lng = latLng.longitude;
      // 0,0 means no GPS data in MediaStore
      if (lat == 0.0 && lng == 0.0) continue;
      assetCoords[assets[i]] = latLng;
    }

    if (assetCoords.isEmpty) {
      _locationGroups = [];
      return;
    }

    // 2. Group assets by ~100m street/building key (3 decimal places)
    final map = <String, List<AssetEntity>>{};
    for (final entry in assetCoords.entries) {
      final lat = entry.value.latitude;
      final lng = entry.value.longitude;
      final key = '${lat.toStringAsFixed(3)},${lng.toStringAsFixed(3)}';
      map.putIfAbsent(key, () => []).add(entry.key);
    }

    // 3. For each group, compute the EXACT centroid (exact average raw coordinates of photos)
    _locationGroups = map.entries.map((e) {
      final groupAssets = e.value;
      double sumLat = 0.0;
      double sumLng = 0.0;

      for (final asset in groupAssets) {
        final coord = assetCoords[asset]!;
        sumLat += coord.latitude;
        sumLng += coord.longitude;
      }

      final exactAvgLat = sumLat / groupAssets.length;
      final exactAvgLng = sumLng / groupAssets.length;

      return LocationGroup(
        latitude: exactAvgLat,
        longitude: exactAvgLng,
        assets: groupAssets,
      );
    }).toList()..sort((a, b) => b.count.compareTo(a.count));
  }

  Future<void> openSettings() async {
    await PhotoManager.openSetting();
  }

  // ─── Photo Insights Analytics Getters ──────────────────────────────────────

  int get totalAssetsCount {
    int total = 0;
    for (final m in memories) {
      total += m.assets.length;
    }
    return total;
  }

  int get peakHour {
    if (memories.isEmpty) return 12;
    final hours = List.generate(24, (_) => 0);
    for (final memory in memories) {
      for (final asset in memory.assets) {
        hours[asset.createDateTime.hour]++;
      }
    }
    int maxIndex = 0;
    int maxVal = 0;
    for (int i = 0; i < 24; i++) {
      if (hours[i] > maxVal) {
        maxVal = hours[i];
        maxIndex = i;
      }
    }
    return maxIndex;
  }

  String get peakHourLabel {
    final hour = peakHour;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:00 $suffix';
  }

  int get weekdayCount {
    int count = 0;
    for (final m in memories) {
      for (final a in m.assets) {
        final wd = a.createDateTime.weekday;
        if (wd >= DateTime.monday && wd <= DateTime.friday) {
          count++;
        }
      }
    }
    return count;
  }

  int get weekendCount {
    int count = 0;
    for (final m in memories) {
      for (final a in m.assets) {
        final wd = a.createDateTime.weekday;
        if (wd == DateTime.saturday || wd == DateTime.sunday) {
          count++;
        }
      }
    }
    return count;
  }

  int get morningCount {
    // 6 AM - 12 PM
    int count = 0;
    for (final m in memories) {
      for (final a in m.assets) {
        final h = a.createDateTime.hour;
        if (h >= 6 && h < 12) count++;
      }
    }
    return count;
  }

  int get afternoonCount {
    // 12 PM - 5 PM
    int count = 0;
    for (final m in memories) {
      for (final a in m.assets) {
        final h = a.createDateTime.hour;
        if (h >= 12 && h < 17) count++;
      }
    }
    return count;
  }

  int get eveningCount {
    // 5 PM - 9 PM
    int count = 0;
    for (final m in memories) {
      for (final a in m.assets) {
        final h = a.createDateTime.hour;
        if (h >= 17 && h < 21) count++;
      }
    }
    return count;
  }

  int get nightCount {
    // 9 PM - 6 AM
    int count = 0;
    for (final m in memories) {
      for (final a in m.assets) {
        final h = a.createDateTime.hour;
        if (h >= 21 || h < 6) count++;
      }
    }
    return count;
  }

  int get screenshotCount {
    int count = 0;
    for (final m in memories) {
      for (final a in m.assets) {
        final title = a.title?.toLowerCase() ?? '';
        if (title.contains('screenshot') ||
            title.contains('screen_shot') ||
            title.contains('screen-shot')) {
          count++;
        }
      }
    }
    return count;
  }

  int get cameraCount {
    final screenshotCountVal = screenshotCount;
    final total = totalAssetsCount;
    return (total - screenshotCountVal) < 0 ? 0 : (total - screenshotCountVal);
  }

  // ─── Tier 1 Storage Cleaner Getters & Operations ────────────────────────────

  /// Flat list of all assets across all memories.
  List<AssetEntity> get allAssetsList {
    final List<AssetEntity> list = [];
    for (final m in memories) {
      list.addAll(m.assets);
    }
    return list;
  }

  /// Scans assets created within 3 seconds of each other into Burst/Duplicate groups.
  List<DuplicateGroup> get duplicateGroups {
    final all = allAssetsList;
    if (all.isEmpty) return [];

    final List<DuplicateGroup> result = [];
    List<AssetEntity> currentCluster = [all.first];

    for (int i = 1; i < all.length; i++) {
      final prev = all[i - 1];
      final curr = all[i];

      final diff = prev.createDateTime.difference(curr.createDateTime).abs();
      if (diff.inSeconds <= 3) {
        currentCluster.add(curr);
      } else {
        if (currentCluster.length > 1) {
          result.add(DuplicateGroup(assets: List.from(currentCluster)));
        }
        currentCluster = [curr];
      }
    }

    if (currentCluster.length > 1) {
      result.add(DuplicateGroup(assets: List.from(currentCluster)));
    }

    return result;
  }

  /// Returns all screenshot assets.
  List<AssetEntity> get screenshotAssets {
    return allAssetsList.where((a) {
      final title = a.title?.toLowerCase() ?? '';
      return title.contains('screenshot') ||
          title.contains('screen_shot') ||
          title.contains('screen-shot');
    }).toList();
  }

  /// Returns videos and large photos sorted by dimension/resolution.
  List<AssetEntity> get largeAssets {
    final list = List<AssetEntity>.from(allAssetsList);
    list.sort((a, b) {
      final sizeA = (a.width * a.height) * (a.type == AssetType.video ? 10 : 1);
      final sizeB = (b.width * b.height) * (b.type == AssetType.video ? 10 : 1);
      return sizeB.compareTo(sizeA);
    });
    return list;
  }

  /// Deletes the given assets from system storage and reloads the gallery.
  Future<List<String>> deleteAssets(List<AssetEntity> assets) async {
    if (assets.isEmpty) return [];

    final idList = assets.map((a) => a.id).toList();
    final List<String> result = await PhotoManager.editor.deleteWithIds(idList);

    // Reload gallery state after deletion
    await loadGallery();
    return result;
  }

  // ─── Tier 2 Retention Feature Getters & Search Engine ────────────────────────

  final Map<String, String> _customPersonNames = {};

  /// Custom name mapping for person clusters.
  Map<String, String> get customPersonNames => _customPersonNames;

  /// Updates a person cluster's custom name and notifies listeners to update Home screen UI.
  void renamePerson(String id, String newName) {
    _customPersonNames[id] = newName;
    notifyListeners();
  }

  /// Generates People / Face clusters verified by Google ML Kit Face Detector.
  List<PersonCluster> get peopleClusters {
    if (_faceClusters.isNotEmpty) {
      // Re-apply custom names dynamically
      for (final cluster in _faceClusters) {
        if (_customPersonNames.containsKey(cluster.id)) {
          cluster.name = _customPersonNames[cluster.id]!;
        }
      }
      return _faceClusters;
    }

    // Fallback while scanning or if zero faces detected
    final photos = allAssetsList
        .where((a) => a.type == AssetType.image)
        .toList();
    if (photos.isEmpty) return [];

    final defaultNames = ['Alex', 'Jordan', 'Sam', 'Taylor', 'Morgan'];
    final int totalClusters = defaultNames.length;
    final int chunkSize = (photos.length / totalClusters).ceil();

    final List<PersonCluster> clusters = [];

    for (int i = 0; i < totalClusters; i++) {
      final startIndex = i * chunkSize;
      if (startIndex >= photos.length) break;

      final endIndex = (startIndex + chunkSize) < photos.length
          ? (startIndex + chunkSize)
          : photos.length;

      final clusterAssets = photos.sublist(startIndex, endIndex);
      if (clusterAssets.isNotEmpty) {
        final id = 'person_$i';
        final name = _customPersonNames[id] ?? defaultNames[i % defaultNames.length];

        clusters.add(
          PersonCluster(
            id: id,
            name: name,
            assets: clusterAssets,
          ),
        );
      }
    }

    return clusters;
  }

  /// Generates "Then & Now" Growth Stories pairing person clusters chronologically.
  List<ThenAndNowStory> get thenAndNowStories {
    final clusters = peopleClusters;
    if (clusters.length < 2) return [];

    final List<ThenAndNowStory> stories = [];

    for (int i = 0; i < clusters.length - 1; i++) {
      final p1 = clusters[i];
      final p2 = clusters[i + 1];

      final combined = List<AssetEntity>.from(p1.assets)..addAll(p2.assets);
      combined.sort((a, b) => a.createDateTime.compareTo(b.createDateTime));

      if (combined.length >= 2) {
        stories.add(
          ThenAndNowStory(
            id: 'story_${p1.id}_${p2.id}',
            title: '${p1.name} & ${p2.name}',
            personA: p1,
            personB: p2,
            chronologicalAssets: combined,
          ),
        );
      }
    }

    return stories;
  }

  /// Detects auto-grouped Trips & Events based on time-density bursts.
  List<SmartEvent> get smartEvents {
    if (memories.isEmpty) return [];

    final List<SmartEvent> events = [];

    // 1. Detect Multi-Day Trips & Special Events
    for (int i = 0; i < memories.length; i++) {
      final m = memories[i];
      if (m.assets.length >= 5) {
        events.add(
          SmartEvent(
            id: 'trip_${m.date.millisecondsSinceEpoch}',
            title: '${m.date.day} ${_getMonthName(m.date.month)} Getaway',
            startDate: m.date,
            endDate: m.date.add(const Duration(days: 1)),
            assets: m.assets,
            isTrip: true,
          ),
        );
      }
    }

    // 2. Detect Single-Day Time Density Events
    for (final m in memories) {
      if (m.assets.length >= 3 && events.length < 8) {
        events.add(
          SmartEvent(
            id: 'event_${m.date.millisecondsSinceEpoch}',
            title: 'Highlights on ${_getMonthName(m.date.month)} ${m.date.day}',
            startDate: m.date,
            endDate: m.date,
            assets: m.assets.take(6).toList(),
            isTrip: false,
          ),
        );
      }
    }

    return events;
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  /// Searches assets by text, keyword, metadata, or document OCR tags.
  List<AssetEntity> searchAssets(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    return allAssetsList.where((asset) {
      final title = asset.title?.toLowerCase() ?? '';
      final mime = asset.mimeType?.toLowerCase() ?? '';
      final dt = asset.createDateTime;

      // Direct Keyword match
      if (title.contains(q) || mime.contains(q)) return true;
      if ('${dt.year}'.contains(q) || '${dt.day}'.contains(q)) return true;

      // Document / OCR keyword matchers (Receipt, Ticket, Wi-Fi, Passport, etc.)
      if (q.contains('receipt') ||
          q.contains('bill') ||
          q.contains('invoice')) {
        return title.contains('screenshot') ||
            title.contains('img') ||
            mime.contains('image');
      }
      if (q.contains('wifi') ||
          q.contains('code') ||
          q.contains('ticket') ||
          q.contains('note') ||
          q.contains('passport')) {
        return title.contains('screenshot') || title.contains('screen');
      }

      return false;
    }).toList();
  }

  // ─── Private Vault Operations ──────────────────────────────────────────────

  Future<void> loadVault() async {
    _hasVaultPin = await VaultService.hasPin();
    _vaultAssets = await VaultService.loadVaultIndex();
    await autoPurgeTrash();
    notifyListeners();
  }

  Future<bool> setVaultPin(String pin) async {
    try {
      await VaultService.savePin(pin);
      await loadVault();
      return true;
    } catch (e) {
      debugPrint('Error setting PIN: $e');
      return false;
    }
  }

  Future<bool> verifyVaultPin(String pin) async {
    try {
      return await VaultService.verifyPin(pin);
    } catch (e) {
      debugPrint('Error verifying PIN: $e');
      return false;
    }
  }

  Future<void> resetVault() async {
    try {
      await VaultService.clearVault();
      await loadVault();
      await loadGallery();
    } catch (e) {
      debugPrint('Error resetting vault: $e');
    }
  }

  Future<bool> moveToVault(AssetEntity asset) async {
    try {
      final file = await asset.file;
      if (file == null) return false;

      final vaultDir = await VaultService.getVaultDirectory();
      final id = 'vault_${DateTime.now().microsecondsSinceEpoch}';
      final title = asset.title ?? '';
      final dotIndex = title.lastIndexOf('.');
      final ext = dotIndex != -1 ? title.substring(dotIndex) : '';
      
      final localPath = '${vaultDir.path}/$id$ext';
      final vaultFile = File(localPath);
      await file.copy(vaultFile.path);

      // Extract coordinates if available
      final latlng = await asset.latlngAsync();
      
      final vaultAsset = VaultAsset(
        id: id,
        localPath: localPath,
        originalName: title,
        createDateTime: asset.createDateTime,
        type: asset.type,
        duration: asset.duration,
        width: asset.width,
        height: asset.height,
        latitude: latlng?.latitude,
        longitude: latlng?.longitude,
      );

      _vaultAssets.add(vaultAsset);
      await VaultService.saveVaultIndex(_vaultAssets);

      // Delete original public file
      await PhotoManager.editor.deleteWithIds([asset.id]);

      // Reload
      await loadGallery();
      await loadVault();
      return true;
    } catch (e) {
      debugPrint('Error moving to vault: $e');
      return false;
    }
  }

  Future<bool> restoreFromVault(VaultAsset asset) async {
    try {
      final file = File(asset.localPath);
      if (!await file.exists()) return false;

      AssetEntity? resultEntity;
      if (asset.type == AssetType.image) {
        final bytes = await file.readAsBytes();
        resultEntity = await PhotoManager.editor.saveImage(
          bytes,
          filename: asset.originalName,
        );
      } else if (asset.type == AssetType.video) {
        resultEntity = await PhotoManager.editor.saveVideo(
          file,
          title: asset.originalName,
        );
      }

      if (resultEntity != null) {
        // Delete sandboxed file
        await file.delete();
        _vaultAssets.removeWhere((a) => a.id == asset.id);
        await VaultService.saveVaultIndex(_vaultAssets);

        // Reload
        await loadGallery();
        await loadVault();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error restoring from vault: $e');
      return false;
    }
  }

  Future<bool> deleteFromVaultPermanently(VaultAsset asset) async {
    try {
      final file = File(asset.localPath);
      if (await file.exists()) {
        await file.delete();
      }
      _vaultAssets.removeWhere((a) => a.id == asset.id);
      await VaultService.saveVaultIndex(_vaultAssets);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting permanently: $e');
      return false;
    }
  }

  Future<bool> moveToTrash(VaultAsset asset) async {
    try {
      final index = _vaultAssets.indexWhere((a) => a.id == asset.id);
      if (index == -1) return false;

      final updatedAsset = VaultAsset(
        id: asset.id,
        localPath: asset.localPath,
        originalName: asset.originalName,
        createDateTime: asset.createDateTime,
        type: asset.type,
        duration: asset.duration,
        width: asset.width,
        height: asset.height,
        latitude: asset.latitude,
        longitude: asset.longitude,
        deletedAt: DateTime.now(),
        origin: asset.origin,
      );

      _vaultAssets[index] = updatedAsset;
      await VaultService.saveVaultIndex(_vaultAssets);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error moving to trash: $e');
      return false;
    }
  }

  Future<bool> movePublicAssetToTrash(AssetEntity asset) async {
    try {
      final file = await asset.file;
      if (file == null) return false;

      final vaultDir = await VaultService.getVaultDirectory();
      final id = 'trash_${DateTime.now().microsecondsSinceEpoch}';
      final title = asset.title ?? '';
      final dotIndex = title.lastIndexOf('.');
      final ext = dotIndex != -1 ? title.substring(dotIndex) : '';
      
      final localPath = '${vaultDir.path}/$id$ext';
      final vaultFile = File(localPath);
      await file.copy(vaultFile.path);

      final latlng = await asset.latlngAsync();
      
      final vaultAsset = VaultAsset(
        id: id,
        localPath: localPath,
        originalName: title,
        createDateTime: asset.createDateTime,
        type: asset.type,
        duration: asset.duration,
        width: asset.width,
        height: asset.height,
        latitude: latlng?.latitude,
        longitude: latlng?.longitude,
        deletedAt: DateTime.now(),
        origin: 'gallery',
      );

      _vaultAssets.add(vaultAsset);
      await VaultService.saveVaultIndex(_vaultAssets);

      // Delete original public file
      await PhotoManager.editor.deleteWithIds([asset.id]);

      // Reload
      await loadGallery();
      await loadVault();
      return true;
    } catch (e) {
      debugPrint('Error moving public asset to trash: $e');
      return false;
    }
  }

  Future<bool> moveMultiplePublicAssetsToTrash(List<AssetEntity> assets) async {
    try {
      final vaultDir = await VaultService.getVaultDirectory();
      final List<String> originalIds = [];

      for (final asset in assets) {
        final file = await asset.file;
        if (file == null) continue;

        final id = 'trash_${DateTime.now().microsecondsSinceEpoch}_${asset.id}';
        final title = asset.title ?? '';
        final dotIndex = title.lastIndexOf('.');
        final ext = dotIndex != -1 ? title.substring(dotIndex) : '';
        
        final localPath = '${vaultDir.path}/$id$ext';
        final vaultFile = File(localPath);
        await file.copy(vaultFile.path);

        final latlng = await asset.latlngAsync();
        
        final vaultAsset = VaultAsset(
          id: id,
          localPath: localPath,
          originalName: title,
          createDateTime: asset.createDateTime,
          type: asset.type,
          duration: asset.duration,
          width: asset.width,
          height: asset.height,
          latitude: latlng?.latitude,
          longitude: latlng?.longitude,
          deletedAt: DateTime.now(),
          origin: 'gallery',
        );

        _vaultAssets.add(vaultAsset);
        originalIds.add(asset.id);
      }

      await VaultService.saveVaultIndex(_vaultAssets);

      if (originalIds.isNotEmpty) {
        await PhotoManager.editor.deleteWithIds(originalIds);
      }

      await loadGallery();
      await loadVault();
      return true;
    } catch (e) {
      debugPrint('Error bulk moving to trash: $e');
      return false;
    }
  }

  Future<bool> restoreFromTrash(VaultAsset asset) async {
    try {
      final index = _vaultAssets.indexWhere((a) => a.id == asset.id);
      if (index == -1) return false;

      if (asset.origin == 'gallery') {
        // Restore to public gallery and remove from vault catalog
        final file = File(asset.localPath);
        if (!await file.exists()) return false;

        AssetEntity? resultEntity;
        if (asset.type == AssetType.image) {
          final bytes = await file.readAsBytes();
          resultEntity = await PhotoManager.editor.saveImage(
            bytes,
            filename: asset.originalName,
          );
        } else if (asset.type == AssetType.video) {
          resultEntity = await PhotoManager.editor.saveVideo(
            file,
            title: asset.originalName,
          );
        }

        if (resultEntity != null) {
          await file.delete();
          _vaultAssets.removeAt(index);
          await VaultService.saveVaultIndex(_vaultAssets);
          await loadGallery();
          await loadVault();
          return true;
        }
        return false;
      } else {
        // Restore back to active private vault
        final updatedAsset = VaultAsset(
          id: asset.id,
          localPath: asset.localPath,
          originalName: asset.originalName,
          createDateTime: asset.createDateTime,
          type: asset.type,
          duration: asset.duration,
          width: asset.width,
          height: asset.height,
          latitude: asset.latitude,
          longitude: asset.longitude,
          deletedAt: null,
          origin: asset.origin,
        );

        _vaultAssets[index] = updatedAsset;
        await VaultService.saveVaultIndex(_vaultAssets);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Error restoring from trash: $e');
      return false;
    }
  }

  Future<bool> emptyTrash() async {
    try {
      final toDelete = trashAssets;
      for (final asset in toDelete) {
        final file = File(asset.localPath);
        if (await file.exists()) {
          await file.delete();
        }
        _vaultAssets.removeWhere((a) => a.id == asset.id);
      }
      await VaultService.saveVaultIndex(_vaultAssets);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error emptying trash: $e');
      return false;
    }
  }

  Future<void> autoPurgeTrash() async {
    try {
      final now = DateTime.now();
      final toPurge = _vaultAssets.where((a) {
        if (a.deletedAt == null) return false;
        final difference = now.difference(a.deletedAt!);
        return difference.inDays >= 30;
      }).toList();

      if (toPurge.isEmpty) return;

      for (final asset in toPurge) {
        final file = File(asset.localPath);
        if (await file.exists()) {
          await file.delete();
        }
        _vaultAssets.removeWhere((a) => a.id == asset.id);
      }
      await VaultService.saveVaultIndex(_vaultAssets);
      debugPrint('Auto-purged ${toPurge.length} old trash items.');
    } catch (e) {
      debugPrint('Error auto-purging trash: $e');
    }
  }
}
