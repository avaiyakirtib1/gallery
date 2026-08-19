import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/then_now_story_model.dart';

class ThenNowStoryViewerScreen extends StatefulWidget {
  final ThenAndNowStory story;

  const ThenNowStoryViewerScreen({super.key, required this.story});

  @override
  State<ThenNowStoryViewerScreen> createState() =>
      _ThenNowStoryViewerScreenState();
}

class _ThenNowStoryViewerScreenState extends State<ThenNowStoryViewerScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isSplitMode = false;
  Timer? _timer;
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _nextSlide();
        }
      });
    _startStory();
  }

  void _startStory() {
    _animController.forward(from: 0.0);
  }

  void _nextSlide() {
    if (_currentIndex < widget.story.chronologicalAssets.length - 1) {
      setState(() => _currentIndex++);
      _animController.forward(from: 0.0);
    } else {
      Navigator.pop(context); // Story complete
    }
  }

  void _prevSlide() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _animController.forward(from: 0.0);
    }
  }

  void _pause() {
    _animController.stop();
  }

  void _resume() {
    _animController.forward();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.story;
    final total = story.chronologicalAssets.length;
    final currentAsset = story.chronologicalAssets[_currentIndex];
    final isFirst = _currentIndex == 0;
    final isLast = _currentIndex == total - 1;
    final year = currentAsset.createDateTime.year;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onLongPressStart: (_) => _pause(),
          onLongPressEnd: (_) => _resume(),
          onTapUp: (details) {
            final dx = details.globalPosition.dx;
            final width = MediaQuery.of(context).size.width;
            if (dx < width * 0.3) {
              _prevSlide();
            } else {
              _nextSlide();
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ─── Story Image View or Split Comparison View ──────────────────
              _isSplitMode
                  ? _buildSplitComparisonView(story)
                  : _StoryImageTile(asset: currentAsset),

              // ─── Gradient Top Overlay ────────────────────────────────────────
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 140,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xDD000000), Colors.transparent],
                    ),
                  ),
                ),
              ),

              // ─── WhatsApp Status Segmented Progress Bars ─────────────────────
              Positioned(
                top: 10,
                left: 12,
                right: 12,
                child: Row(
                  children: List.generate(total, (i) {
                    return Expanded(
                      child: Container(
                        height: 3,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: AnimatedBuilder(
                            animation: _animController,
                            builder: (context, child) {
                              double value = 0.0;
                              if (i < _currentIndex) {
                                value = 1.0;
                              } else if (i == _currentIndex) {
                                value = _animController.value;
                              }
                              return LinearProgressIndicator(
                                value: value,
                                backgroundColor: Colors.white30,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              // ─── Top Header Info & Close Button ──────────────────────────────
              Positioned(
                top: 22,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Colors.amber, Colors.pink, Colors.purple],
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.black,
                        child: Text(
                          story.title.substring(0, 1),
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            story.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            story.subtitle,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // ─── Floating THEN / NOW Year Badge Banner ───────────────────────
              if (!_isSplitMode)
                Positioned(
                  bottom: 90,
                  left: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isFirst
                          ? Colors.amber.shade700
                          : isLast
                              ? Colors.purple.shade600
                              : Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white38, width: 0.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isFirst
                              ? Icons.history_toggle_off_rounded
                              : isLast
                                  ? Icons.star_rounded
                                  : Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isFirst
                              ? 'THEN ($year)'
                              : isLast
                                  ? 'NOW ($year)'
                                  : 'YEAR $year',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ─── Bottom Action Bar (Toggle Split View Mode) ──────────────────
              Positioned(
                bottom: 24,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() => _isSplitMode = !_isSplitMode);
                        if (_isSplitMode) {
                          _pause();
                        } else {
                          _resume();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                      icon: Icon(
                        _isSplitMode
                            ? Icons.view_carousel_rounded
                            : Icons.compare_rounded,
                      ),
                      label: Text(
                        _isSplitMode
                            ? 'Single Reel Mode'
                            : 'Compare Then vs Now Side-by-Side',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSplitComparisonView(ThenAndNowStory story) {
    return Padding(
      padding: const EdgeInsets.only(top: 80, bottom: 80, left: 12, right: 12),
      child: Row(
        children: [
          // Left Card: THEN
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade700,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'THEN (${story.startYear})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: _StoryImageTile(asset: story.thenAsset),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Right Card: NOW
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade600,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'NOW (${story.endYear})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: _StoryImageTile(asset: story.nowAsset),
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

class _StoryImageTile extends StatefulWidget {
  final AssetEntity asset;

  const _StoryImageTile({required this.asset});

  @override
  State<_StoryImageTile> createState() => _StoryImageTileState();
}

class _StoryImageTileState extends State<_StoryImageTile> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final file = await widget.asset.file;
    if (file != null && mounted) {
      final b = await file.readAsBytes();
      if (mounted) setState(() => _bytes = b);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Image.memory(
      _bytes!,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
  }
}
