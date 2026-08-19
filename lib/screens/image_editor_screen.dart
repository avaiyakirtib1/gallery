import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:image/image.dart' as img_lib;

class ImageEditorScreen extends StatefulWidget {
  final File imageFile;
  final String assetName;

  const ImageEditorScreen({
    super.key,
    required this.imageFile,
    required this.assetName,
  });

  @override
  State<ImageEditorScreen> createState() => _ImageEditorScreenState();
}

class _ImageEditorScreenState extends State<ImageEditorScreen> {
  // ── State variables for adjustments ──────────────────────────────────────
  double _brightness = 0.0;     // -0.5 to 0.5 (default 0.0)
  double _contrast = 1.0;       // 0.5 to 2.0 (default 1.0)
  double _saturation = 1.0;     // 0.0 to 2.0 (default 1.0)

  // ── State variables for transformations ──────────────────────────────────
  int _rotationQuarterTurns = 0; // 0, 1, 2, 3 (quarter turns clockwise)
  bool _flipHorizontal = false;
  bool _flipVertical = false;

  // ── Active filter ────────────────────────────────────────────────────────
  String _activeFilter = 'none'; // 'none', 'grayscale', 'sepia', 'invert'

  // ── Crop coordinates ─────────────────────────────────────────────────────
  Rect _cropRect = const Rect.fromLTRB(0.0, 0.0, 1.0, 1.0); // fractions [0..1]
  double? _selectedRatio; // locked aspect ratio

  // ── Layout sizing derived from Image ──────────────────────────────────────
  double _originalWidth = 1000.0;
  double _originalHeight = 1000.0;

  // ── Tabs ─────────────────────────────────────────────────────────────────
  int _activeTab = 0; // 0: Crop/Rotate, 1: Filters, 2: Adjustments

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadImageSize();
  }

  Future<void> _loadImageSize() async {
    try {
      final decoded = await decodeImageFile(widget.imageFile.path);
      if (decoded != null && mounted) {
        setState(() {
          _originalWidth = decoded.width.toDouble();
          _originalHeight = decoded.height.toDouble();
        });
      }
    } catch (_) {}
  }

  // ── Matrix Multiplication for live GPU filters ───────────────────────────
  List<double> _buildColorMatrix() {
    List<double> matrix = [
      1, 0, 0, 0, 0,
      0, 1, 0, 0, 0,
      0, 0, 1, 0, 0,
      0, 0, 0, 1, 0,
    ];

    if (_activeFilter == 'grayscale') {
      matrix = _multiplyMatrices(matrix, [
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0,      0,      0,      1, 0,
      ]);
    } else if (_activeFilter == 'sepia') {
      matrix = _multiplyMatrices(matrix, [
        0.393, 0.769, 0.189, 0, 0,
        0.349, 0.686, 0.168, 0, 0,
        0.272, 0.534, 0.131, 0, 0,
        0,     0,     0,     1, 0,
      ]);
    } else if (_activeFilter == 'invert') {
      matrix = _multiplyMatrices(matrix, [
        -1,  0,  0, 0, 255,
         0, -1,  0, 0, 255,
         0,  0, -1, 0, 255,
         0,  0,  0, 1, 0,
      ]);
    }

    if (_brightness != 0.0) {
      final offset = _brightness * 255;
      matrix = _multiplyMatrices(matrix, [
        1, 0, 0, 0, offset,
        0, 1, 0, 0, offset,
        0, 0, 1, 0, offset,
        0, 0, 0, 1, 0,
      ]);
    }

    if (_contrast != 1.0) {
      final t = 128 * (1.0 - _contrast);
      matrix = _multiplyMatrices(matrix, [
        _contrast, 0, 0, 0, t,
        0, _contrast, 0, 0, t,
        0, 0, _contrast, 0, t,
        0, 0, 0, 1, 0,
      ]);
    }

    if (_saturation != 1.0) {
      final invSat = 1.0 - _saturation;
      final r = 0.2126 * invSat;
      final g = 0.7152 * invSat;
      final b = 0.0722 * invSat;
      matrix = _multiplyMatrices(matrix, [
        r + _saturation, g, b, 0, 0,
        r, g + _saturation, b, 0, 0,
        r, g, b + _saturation, 0, 0,
        0, 0, 0, 1, 0,
      ]);
    }

    return matrix;
  }

  List<double> _multiplyMatrices(List<double> a, List<double> b) {
    final m1 = List<double>.from(a)..addAll([0, 0, 0, 0, 1]);
    final m2 = List<double>.from(b)..addAll([0, 0, 0, 0, 1]);
    final result = List<double>.filled(25, 0.0);

    for (int r = 0; r < 5; r++) {
      for (int c = 0; c < 5; c++) {
        double sum = 0.0;
        for (int i = 0; i < 5; i++) {
          sum += m1[r * 5 + i] * m2[i * 5 + c];
        }
        result[r * 5 + c] = sum;
      }
    }
    return result.sublist(0, 20);
  }

  // ── Save Processing ──────────────────────────────────────────────────────
  Future<void> _saveEdits() async {
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final inputBytes = await widget.imageFile.readAsBytes();
      
      // Run the heavy image processing inside compute isolates
      final editedBytes = await compute(_processImageInIsolate, _ImageProcessParams(
        inputBytes: inputBytes,
        assetName: widget.assetName,
        rotationTurns: _rotationQuarterTurns,
        flipX: _flipHorizontal,
        flipY: _flipVertical,
        cropLeft: _cropRect.left,
        cropTop: _cropRect.top,
        cropRight: _cropRect.right,
        cropBottom: _cropRect.bottom,
        brightness: _brightness,
        contrast: _contrast,
        saturation: _saturation,
        filter: _activeFilter,
      ));

      if (editedBytes != null) {
        await PhotoManager.editor.saveImage(
          editedBytes,
          filename: 'edited_${DateTime.now().millisecondsSinceEpoch}_${widget.assetName}',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image saved to public gallery successfully!'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context, true);
          return;
        }
      }
      throw Exception('Failed to encode edited image');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving edited image: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // ── Render ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Edit Photo', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isSaving)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton.icon(
                onPressed: _saveEdits,
                icon: const Icon(Icons.check_rounded, color: Colors.greenAccent),
                label: const Text('Save', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Image canvas preview section
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Swap constraints if rotated by 90 or 270 deg
                      final isSwapped = _rotationQuarterTurns % 2 != 0;
                      final imageRatio = isSwapped 
                          ? _originalHeight / _originalWidth 
                          : _originalWidth / _originalHeight;
                      
                      final containerRatio = constraints.maxWidth / constraints.maxHeight;

                      double renderedWidth;
                      double renderedHeight;
                      if (imageRatio > containerRatio) {
                        renderedWidth = constraints.maxWidth;
                        renderedHeight = constraints.maxWidth / imageRatio;
                      } else {
                        renderedHeight = constraints.maxHeight;
                        renderedWidth = constraints.maxHeight * imageRatio;
                      }

                      return Center(
                        child: Container(
                          width: renderedWidth,
                          height: renderedHeight,
                          color: Colors.black,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Transformed and color filtered image preview
                              RotatedBox(
                                quarterTurns: _rotationQuarterTurns,
                                child: Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.diagonal3Values(
                                    _flipHorizontal ? -1.0 : 1.0,
                                    _flipVertical ? -1.0 : 1.0,
                                    1.0,
                                  ),
                                  child: ColorFiltered(
                                    colorFilter: ColorFilter.matrix(_buildColorMatrix()),
                                    child: Image.file(
                                      widget.imageFile,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                              // Interactive Crop box layer
                              if (_activeTab == 0)
                                _CropBoxWidget(
                                  cropRect: _cropRect,
                                  selectedRatio: _selectedRatio,
                                  renderedWidth: renderedWidth,
                                  renderedHeight: renderedHeight,
                                  onChanged: (newRect) {
                                    setState(() {
                                      _cropRect = newRect;
                                    });
                                  },
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Tool parameters & bottom panel
              _buildBottomPanel(colorScheme, textTheme),
            ],
          ),

          // Saving Overlay loader
          if (_isSaving)
            Container(
              color: Colors.black.withValues(alpha: 0.74),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.greenAccent),
                    const SizedBox(height: 16),
                    Text(
                      'Encoding image edits…',
                      style: textTheme.bodyLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel(ColorScheme cs, TextTheme tt) {
    return Container(
      color: const Color(0xFF0F0F0F),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Panel parameters matching active mode
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: _buildActiveControls(cs, tt),
            ),
            const Divider(height: 1, color: Colors.white10),
            // Navigation tabs
            Theme(
              data: ThemeData.dark(),
              child: BottomNavigationBar(
                currentIndex: _activeTab,
                onTap: (index) {
                  setState(() => _activeTab = index);
                },
                backgroundColor: Colors.black,
                selectedItemColor: cs.primary,
                unselectedItemColor: Colors.grey,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.crop_rotate_rounded),
                    label: 'Crop & Rotate',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.color_lens_rounded),
                    label: 'Filters',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.tune_rounded),
                    label: 'Adjustments',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveControls(ColorScheme cs, TextTheme tt) {
    switch (_activeTab) {
      case 0:
        return _buildCropRotateControls(cs, tt);
      case 1:
        return _buildFiltersControls(cs, tt);
      case 2:
        return _buildAdjustmentsControls(cs, tt);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCropRotateControls(ColorScheme cs, TextTheme tt) {
    return Column(
      children: [
        // Flips and Rotation
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.rotate_right_rounded, color: Colors.white),
              onPressed: () {
                setState(() {
                  _rotationQuarterTurns = (_rotationQuarterTurns + 1) % 4;
                  _cropRect = const Rect.fromLTRB(0, 0, 1, 1); // Reset crop on turn
                });
              },
              tooltip: 'Rotate 90°',
            ),
            IconButton(
              icon: const Icon(Icons.flip_rounded, color: Colors.white),
              onPressed: () {
                setState(() => _flipHorizontal = !_flipHorizontal);
              },
              tooltip: 'Flip Horizontal',
            ),
            IconButton(
              icon: const RotatedBox(
                quarterTurns: 1,
                child: Icon(Icons.flip_rounded, color: Colors.white),
              ),
              onPressed: () {
                setState(() => _flipVertical = !_flipVertical);
              },
              tooltip: 'Flip Vertical',
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Preset Aspect ratio options
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _buildAspectButton('Free', null),
              _buildAspectButton('1:1', 1.0),
              _buildAspectButton('4:3', 4.0 / 3.0),
              _buildAspectButton('16:9', 16.0 / 9.0),
              _buildAspectButton('9:16', 9.0 / 16.0),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAspectButton(String label, double? ratio) {
    final isSelected = _selectedRatio == ratio;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            _setCropPreset(ratio);
          }
        },
        selectedColor: Theme.of(context).colorScheme.primary,
        backgroundColor: Colors.grey.shade900,
        labelStyle: TextStyle(
          color: isSelected ? Colors.black : Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _setCropPreset(double? ratio) {
    if (ratio == null) {
      setState(() {
        _cropRect = const Rect.fromLTRB(0.0, 0.0, 1.0, 1.0);
        _selectedRatio = null;
      });
      return;
    }

    final isSwapped = _rotationQuarterTurns % 2 != 0;
    final wOrig = isSwapped ? _originalHeight : _originalWidth;
    final hOrig = isSwapped ? _originalWidth : _originalHeight;
    final physicalRatio = wOrig / hOrig;
    
    final targetCropRatio = ratio / physicalRatio;

    double w, h;
    if (targetCropRatio > 1.0) {
      w = 1.0;
      h = 1.0 / targetCropRatio;
    } else {
      h = 1.0;
      w = targetCropRatio;
    }

    final l = (1.0 - w) / 2;
    final t = (1.0 - h) / 2;

    setState(() {
      _cropRect = Rect.fromLTWH(l, t, w, h);
      _selectedRatio = ratio;
    });
  }

  Widget _buildFiltersControls(ColorScheme cs, TextTheme tt) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildFilterChip('Normal', 'none'),
          _buildFilterChip('Mono', 'grayscale'),
          _buildFilterChip('Sepia', 'sepia'),
          _buildFilterChip('Inverted', 'invert'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String code) {
    final isSelected = _activeFilter == code;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            setState(() => _activeFilter = code);
          }
        },
        selectedColor: Theme.of(context).colorScheme.primary,
        backgroundColor: Colors.grey.shade900,
        labelStyle: TextStyle(
          color: isSelected ? Colors.black : Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildAdjustmentsControls(ColorScheme cs, TextTheme tt) {
    return Column(
      children: [
        _buildSliderRow('Brightness', _brightness, -0.5, 0.5, (v) => setState(() => _brightness = v)),
        _buildSliderRow('Contrast', _contrast, 0.5, 2.0, (v) => setState(() => _contrast = v)),
        _buildSliderRow('Saturation', _saturation, 0.0, 2.0, (v) => setState(() => _saturation = v)),
      ],
    );
  }

  Widget _buildSliderRow(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: Theme.of(context).colorScheme.primary,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
                overlayColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              value.toStringAsFixed(1),
              textAlign: TextAlign.end,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Native-Grade Draggable Bounding Crop Box ───────────────────────────────

class _CropBoxWidget extends StatelessWidget {
  final Rect cropRect;
  final double? selectedRatio;
  final double renderedWidth;
  final double renderedHeight;
  final ValueChanged<Rect> onChanged;

  const _CropBoxWidget({
    required this.cropRect,
    required this.selectedRatio,
    required this.renderedWidth,
    required this.renderedHeight,
    required this.onChanged,
  });

  void _updateRect({double? left, double? top, double? right, double? bottom}) {
    double l = left ?? cropRect.left;
    double t = top ?? cropRect.top;
    double r = right ?? cropRect.right;
    double b = bottom ?? cropRect.bottom;

    if (selectedRatio != null) {
      final targetCropRatio = selectedRatio! / (renderedWidth / renderedHeight);

      if (left != null || right != null) {
        final w = r - l;
        final h = w / targetCropRatio;
        b = t + h;
        if (b > 1.0) {
          b = 1.0;
          t = b - h;
          if (t < 0.0) {
            t = 0.0;
            final maxH = 1.0;
            final maxW = maxH * targetCropRatio;
            r = l + maxW;
            b = 1.0;
          }
        }
      } else if (top != null || bottom != null) {
        final h = b - t;
        final w = h * targetCropRatio;
        r = l + w;
        if (r > 1.0) {
          r = 1.0;
          l = r - w;
          if (l < 0.0) {
            l = 0.0;
            final maxW = 1.0;
            final maxH = maxW / targetCropRatio;
            b = t + maxH;
            r = 1.0;
          }
        }
      }
    }

    onChanged(Rect.fromLTRB(l, t, r, b));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        return Stack(
          children: [
            // Darkened background outside crop area
            CustomPaint(
              size: Size(w, h),
              painter: _CropMaskPainter(cropRect: cropRect),
            ),

            // Draggable center area for panning the crop box
            Positioned(
              left: cropRect.left * w,
              top: cropRect.top * h,
              width: cropRect.width * w,
              height: cropRect.height * h,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanUpdate: (details) {
                  final dx = details.delta.dx / w;
                  final dy = details.delta.dy / h;

                  double l = cropRect.left + dx;
                  double r = cropRect.right + dx;
                  double t = cropRect.top + dy;
                  double b = cropRect.bottom + dy;

                  if (l < 0.0) {
                    r -= l;
                    l = 0.0;
                  }
                  if (r > 1.0) {
                    l -= (r - 1.0);
                    r = 1.0;
                  }
                  if (t < 0.0) {
                    b -= t;
                    t = 0.0;
                  }
                  if (b > 1.0) {
                    t -= (b - 1.0);
                    b = 1.0;
                  }

                  onChanged(Rect.fromLTRB(l, t, r, b));
                },
                child: const SizedBox.expand(),
              ),
            ),

            // Corner drag handles (30x30 touch targets)
            // Top-Left
            Positioned(
              left: cropRect.left * w - 15,
              top: cropRect.top * h - 15,
              child: _CornerHandle(
                onPanUpdate: (details) {
                  final dx = details.delta.dx / w;
                  final dy = details.delta.dy / h;
                  _updateRect(
                    left: (cropRect.left + dx).clamp(0.0, cropRect.right - 0.1),
                    top: (cropRect.top + dy).clamp(0.0, cropRect.bottom - 0.1),
                  );
                },
                iconRotation: 0,
              ),
            ),

            // Top-Right
            Positioned(
              left: cropRect.right * w - 15,
              top: cropRect.top * h - 15,
              child: _CornerHandle(
                onPanUpdate: (details) {
                  final dx = details.delta.dx / w;
                  final dy = details.delta.dy / h;
                  _updateRect(
                    right: (cropRect.right + dx).clamp(cropRect.left + 0.1, 1.0),
                    top: (cropRect.top + dy).clamp(0.0, cropRect.bottom - 0.1),
                  );
                },
                iconRotation: 1,
              ),
            ),

            // Bottom-Left
            Positioned(
              left: cropRect.left * w - 15,
              top: cropRect.bottom * h - 15,
              child: _CornerHandle(
                onPanUpdate: (details) {
                  final dx = details.delta.dx / w;
                  final dy = details.delta.dy / h;
                  _updateRect(
                    left: (cropRect.left + dx).clamp(0.0, cropRect.right - 0.1),
                    bottom: (cropRect.bottom + dy).clamp(cropRect.top + 0.1, 1.0),
                  );
                },
                iconRotation: 3,
              ),
            ),

            // Bottom-Right
            Positioned(
              left: cropRect.right * w - 15,
              top: cropRect.bottom * h - 15,
              child: _CornerHandle(
                onPanUpdate: (details) {
                  final dx = details.delta.dx / w;
                  final dy = details.delta.dy / h;
                  _updateRect(
                    right: (cropRect.right + dx).clamp(cropRect.left + 0.1, 1.0),
                    bottom: (cropRect.bottom + dy).clamp(cropRect.top + 0.1, 1.0),
                  );
                },
                iconRotation: 2,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CornerHandle extends StatelessWidget {
  final GestureDragUpdateCallback onPanUpdate;
  final int iconRotation; // Quarter turns

  const _CornerHandle({
    required this.onPanUpdate,
    required this.iconRotation,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: onPanUpdate,
      child: Container(
        width: 32,
        height: 32,
        color: Colors.transparent,
        child: Center(
          child: RotatedBox(
            quarterTurns: iconRotation,
            child: CustomPaint(
              size: const Size(14, 14),
              painter: _CornerPainter(),
            ),
          ),
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(0, 0)
      ..lineTo(0, size.height);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CropMaskPainter extends CustomPainter {
  final Rect cropRect;

  _CropMaskPainter({
    required this.cropRect,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black54;

    final rect = Rect.fromLTRB(
      cropRect.left * size.width,
      cropRect.top * size.height,
      cropRect.right * size.width,
      cropRect.bottom * size.height,
    );

    // Darken outer region
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(rect);
    path.fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);

    // Draw crop boundaries border
    final borderPaint = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(rect, borderPaint);

    // Draw 3x3 grid layout lines
    final gridPaint = Paint()
      ..color = Colors.white30
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final stepW = rect.width / 3;
    final stepH = rect.height / 3;

    // vertical
    canvas.drawLine(Offset(rect.left + stepW, rect.top), Offset(rect.left + stepW, rect.bottom), gridPaint);
    canvas.drawLine(Offset(rect.left + 2 * stepW, rect.top), Offset(rect.left + 2 * stepW, rect.bottom), gridPaint);

    // horizontal
    canvas.drawLine(Offset(rect.left, rect.top + stepH), Offset(rect.right, rect.top + stepH), gridPaint);
    canvas.drawLine(Offset(rect.left, rect.top + 2 * stepH), Offset(rect.right, rect.top + 2 * stepH), gridPaint);
  }

  @override
  bool shouldRepaint(covariant _CropMaskPainter oldDelegate) {
    return oldDelegate.cropRect != cropRect;
  }
}

// ─── Image Processing Decoders and Isolates ────────────────────────────────

Future<Size?> decodeImageFile(String path) async {
  try {
    final file = File(path);
    final bytes = await file.readAsBytes();
    final info = img_lib.decodeImage(bytes);
    if (info != null) {
      return Size(info.width.toDouble(), info.height.toDouble());
    }
  } catch (_) {}
  return null;
}

class _ImageProcessParams {
  final Uint8List inputBytes;
  final String assetName;
  final int rotationTurns;
  final bool flipX;
  final bool flipY;
  final double cropLeft;
  final double cropTop;
  final double cropRight;
  final double cropBottom;
  final double brightness;
  final double contrast;
  final double saturation;
  final String filter;

  _ImageProcessParams({
    required this.inputBytes,
    required this.assetName,
    required this.rotationTurns,
    required this.flipX,
    required this.flipY,
    required this.cropLeft,
    required this.cropTop,
    required this.cropRight,
    required this.cropBottom,
    required this.brightness,
    required this.contrast,
    required this.saturation,
    required this.filter,
  });
}

// Helper method running in Isolate background thread to avoid freezing UI
Uint8List? _processImageInIsolate(_ImageProcessParams params) {
  try {
    final name = params.assetName.toLowerCase();
    img_lib.Image? image;
    
    // Performance optimization: try specific decoders instead of searching all formats
    if (name.endsWith('.png')) {
      image = img_lib.PngDecoder().decode(params.inputBytes);
    } else if (name.endsWith('.gif')) {
      image = img_lib.GifDecoder().decode(params.inputBytes);
    } else {
      image = img_lib.JpegDecoder().decode(params.inputBytes);
    }
    
    // Fallback if specific decoder fails
    image ??= img_lib.decodeImage(params.inputBytes);
    
    if (image == null) return null;

    // Downscale extremely large images to speed up CPU processing considerably while maintaining QHD resolution
    if (image.width > 2560 || image.height > 2560) {
      final double ratio = image.width / image.height;
      int targetW, targetH;
      if (ratio > 1.0) {
        targetW = 2560;
        targetH = (2560 / ratio).round();
      } else {
        targetH = 2560;
        targetW = (2560 * ratio).round();
      }
      image = img_lib.copyResize(image, width: targetW, height: targetH);
    }

    // 1. FlipHorizontal & FlipVertical
    if (params.flipX) {
      image = img_lib.flip(image, direction: img_lib.FlipDirection.horizontal);
    }
    if (params.flipY) {
      image = img_lib.flip(image, direction: img_lib.FlipDirection.vertical);
    }

    // 2. Rotate Turns
    if (params.rotationTurns > 0) {
      final angle = params.rotationTurns * 90;
      image = img_lib.copyRotate(image, angle: angle);
    }

    // 3. Crop bounds
    if (params.cropLeft > 0.0 || params.cropTop > 0.0 || params.cropRight < 1.0 || params.cropBottom < 1.0) {
      final x = (params.cropLeft * image.width).round();
      final y = (params.cropTop * image.height).round();
      final w = ((params.cropRight - params.cropLeft) * image.width).round();
      final h = ((params.cropBottom - params.cropTop) * image.height).round();
      
      // Ensure positive dimensions
      if (w > 0 && h > 0) {
        image = img_lib.copyCrop(image, x: x, y: y, width: w, height: h);
      }
    }

    // 4. Adjust Color (brightness/contrast/saturation)
    if (params.brightness != 0.0 || params.contrast != 1.0 || params.saturation != 1.0) {
      image = img_lib.adjustColor(
        image,
        brightness: 1.0 + params.brightness,
        contrast: params.contrast,
        saturation: params.saturation,
      );
    }

    // 5. Predefined Filters
    if (params.filter == 'grayscale') {
      image = img_lib.grayscale(image);
    } else if (params.filter == 'sepia') {
      image = img_lib.sepia(image);
    } else if (params.filter == 'invert') {
      image = img_lib.invert(image);
    }

    // 6. Encode and output back (reduce quality to 85 for faster encoding and smaller size)
    return img_lib.encodeJpg(image, quality: 85);
  } catch (e) {
    debugPrint('Isolate image error: $e');
    return null;
  }
}
