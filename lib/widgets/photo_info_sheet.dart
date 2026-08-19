import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class PhotoInfoSheet extends StatefulWidget {
  final AssetEntity asset;

  const PhotoInfoSheet({super.key, required this.asset});

  @override
  State<PhotoInfoSheet> createState() => _PhotoInfoSheetState();
}

class _PhotoInfoSheetState extends State<PhotoInfoSheet> {
  String _fileSize = 'Loading…';
  String _location = 'Loading…';

  @override
  void initState() {
    super.initState();
    _loadFileSize();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    try {
      final latLng = await widget.asset.latlngAsync();
      if (mounted) {
        if (latLng != null) {
          final lat = latLng.latitude;
          final lng = latLng.longitude;
          if (lat != 0.0 || lng != 0.0) {
            final latDir = lat >= 0 ? 'N' : 'S';
            final lngDir = lng >= 0 ? 'E' : 'W';
            setState(() => _location =
                '${lat.abs().toStringAsFixed(4)}°$latDir, ${lng.abs().toStringAsFixed(4)}°$lngDir');
          } else {
            setState(() => _location = 'No location data');
          }
        } else {
          setState(() => _location = 'No location data');
        }
      }
    } catch (_) {
      if (mounted) setState(() => _location = 'No location data');
    }
  }

  Future<void> _loadFileSize() async {
    try {
      final file = await widget.asset.file;
      if (file != null && mounted) {
        final bytes = await file.length();
        setState(() => _fileSize = _formatBytes(bytes));
      }
    } catch (_) {
      if (mounted) setState(() => _fileSize = 'N/A');
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime dt) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $hour:$min';
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.asset;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.3,
      maxChildSize: 0.75,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Drag handle
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(
                      asset.type == AssetType.video
                          ? Icons.videocam_outlined
                          : Icons.photo_outlined,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'File Information',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Divider(
                color: colorScheme.outlineVariant,
                indent: 20,
                endIndent: 20,
              ),
              // Scrollable info rows
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  children: [
                    _InfoRow(
                      icon: Icons.insert_drive_file_outlined,
                      label: 'File Name',
                      value: asset.title ?? 'Unknown',
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                    ),
                    _InfoRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Date Taken',
                      value: _formatDate(asset.createDateTime),
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                    ),
                    _InfoRow(
                      icon: Icons.location_on_outlined,
                      label: 'Location',
                      value: _location,
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                    ),
                    _InfoRow(
                      icon: Icons.aspect_ratio_outlined,
                      label: 'Resolution',
                      value: '${asset.width} × ${asset.height} px',
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                    ),
                    _InfoRow(
                      icon: Icons.storage_outlined,
                      label: 'File Size',
                      value: _fileSize,
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                    ),
                    _InfoRow(
                      icon: Icons.photo_camera_outlined,
                      label: 'Type',
                      value: asset.mimeType ?? 'Unknown',
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: colorScheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
