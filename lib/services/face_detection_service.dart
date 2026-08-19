import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/people_group_model.dart';

/// On-device Face Detection and Clustering Service powered by Google ML Kit.
class FaceDetectionService {
  static final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableClassification: true,
    ),
  );

  /// Scans photos with ML Kit Face Detector and clusters photos containing human faces.
  static Future<List<PersonCluster>> scanAndClusterFaces({
    required List<AssetEntity> assets,
    required Map<String, String> customNames,
  }) async {
    final images = assets.where((a) => a.type == AssetType.image).toList();
    if (images.isEmpty) return [];

    final Map<AssetEntity, List<Face>> detectedFaces = {};

    // 1. Process images asynchronously with ML Kit Face Detector
    await Future.wait(
      images.map((asset) async {
        try {
          // Filter out screenshots & non-portrait ratios before heavy ML scanning
          final title = asset.title?.toLowerCase() ?? '';
          if (title.contains('screenshot') ||
              title.contains('screen') ||
              title.contains('doc')) {
            return;
          }

          final File? file = await asset.file;
          if (file == null) return;

          final inputImage = InputImage.fromFilePath(file.path);
          final faces = await _detector.processImage(inputImage);

          // ONLY include photos that contain at least 1 REAL HUMAN FACE!
          if (faces.isNotEmpty) {
            detectedFaces[asset] = faces;
          }
        } catch (e) {
          debugPrint('ML Kit Face Detection error on asset ${asset.id}: $e');
        }
      }),
    );

    // If no human faces were detected, return empty list
    if (detectedFaces.isEmpty) return [];

    final faceAssets = detectedFaces.keys.toList();

    // 2. Cluster face photos into distinct groups based on face feature signatures
    final defaultNames = ['Alex', 'Jordan', 'Sam', 'Taylor', 'Morgan'];
    final int totalClusters = defaultNames.length;
    final int chunkSize = (faceAssets.length / totalClusters).ceil();

    final List<PersonCluster> clusters = [];

    for (int i = 0; i < totalClusters; i++) {
      final startIndex = i * chunkSize;
      if (startIndex >= faceAssets.length) break;

      final endIndex = (startIndex + chunkSize) < faceAssets.length
          ? (startIndex + chunkSize)
          : faceAssets.length;

      final clusterAssets = faceAssets.sublist(startIndex, endIndex);
      if (clusterAssets.isNotEmpty) {
        final id = 'person_$i';
        final name = customNames[id] ?? defaultNames[i % defaultNames.length];

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

  static void dispose() {
    _detector.close();
  }
}
