import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/v35_tokens.dart';
import '../../models/song_model.dart';
import '../../services/artwork_color_service.dart';

enum DynamicBackgroundIntensity { low, medium, high }

class DynamicBackground extends StatefulWidget {
  final SongModel? song;
  final bool enabled;
  final DynamicBackgroundIntensity intensity;
  final Widget child;

  const DynamicBackground({
    super.key,
    required this.song,
    this.enabled = true,
    this.intensity = DynamicBackgroundIntensity.medium,
    required this.child,
  });

  @override
  State<DynamicBackground> createState() => _DynamicBackgroundState();
}

class _DynamicBackgroundState extends State<DynamicBackground> {
  ArtworkColorPalette _palette = ArtworkColorPalette.defaultDark;
  String? _lastLoadedCover;

  @override
  void initState() {
    super.initState();
    _extractColors();
  }

  @override
  void didUpdateWidget(DynamicBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.song?.id != oldWidget.song?.id ||
        widget.song?.cover != oldWidget.song?.cover) {
      _extractColors();
    }
  }

  void _extractColors() {
    final cover = widget.song?.cover;
    if (cover == _lastLoadedCover && _lastLoadedCover != null) return;
    _lastLoadedCover = cover;

    if (cover == null || cover.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _palette = ArtworkColorPalette.defaultDark;
        });
      }
      return;
    }

    ArtworkColorService.instance.extractPalette(cover).then((palette) {
      if (mounted && _lastLoadedCover == cover) {
        setState(() {
          _palette = palette;
        });
      }
    });
  }

  double get _blurSigma {
    switch (widget.intensity) {
      case DynamicBackgroundIntensity.low:
        return 30.0;
      case DynamicBackgroundIntensity.medium:
        return 45.0;
      case DynamicBackgroundIntensity.high:
        return 60.0;
    }
  }

  double get _overlayOpacity {
    switch (widget.intensity) {
      case DynamicBackgroundIntensity.low:
        return 0.82;
      case DynamicBackgroundIntensity.medium:
        return 0.74;
      case DynamicBackgroundIntensity.high:
        return 0.65;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || widget.song == null) {
      return Container(color: V35Tokens.bgVoid, child: widget.child);
    }

    final cover = widget.song?.cover;
    final hasValidCover = cover != null && cover.trim().isNotEmpty;

    return Stack(
      children: [
        // Base dark background
        Positioned.fill(child: Container(color: V35Tokens.bgVoid)),

        // Animated Artwork Background Layer
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: SizedBox.expand(
              key: ValueKey<String>('bg_${widget.song?.id}_${cover ?? 'none'}'),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Ambient Gradient base derived from extracted artwork palette
                  Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.0, -0.4),
                        radius: 1.2,
                        colors: [
                          _palette.dominantColor.withValues(alpha: 0.5),
                          _palette.secondaryColor.withValues(alpha: 0.35),
                          V35Tokens.bgVoid,
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),

                  // 2. Scaled Artwork Image
                  if (hasValidCover) _buildBackgroundImage(cover),

                  // 3. Image Blur Filter
                  if (hasValidCover)
                    Positioned.fill(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: _blurSigma,
                          sigmaY: _blurSigma,
                        ),
                        child: Container(color: Colors.transparent),
                      ),
                    ),

                  // 4. Subtle Dark Ambient Overlay for foreground text & controls readability
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            V35Tokens.bgVoid.withValues(
                              alpha: _overlayOpacity * 0.7,
                            ),
                            V35Tokens.bgVoid.withValues(alpha: _overlayOpacity),
                            V35Tokens.bgVoid.withValues(
                              alpha: (_overlayOpacity + 0.1).clamp(0.0, 0.96),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 5. Radial Vignette to focus center
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 1.0,
                          colors: [
                            Colors.transparent,
                            V35Tokens.bgVoid.withValues(alpha: 0.5),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Foreground content (Now Playing UI, controls, lyrics)
        Positioned.fill(child: widget.child),
      ],
    );
  }

  Widget _buildBackgroundImage(String path) {
    final cleanPath = path.trim();

    if (cleanPath.startsWith('http://') || cleanPath.startsWith('https://')) {
      return Image.network(
        cleanPath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      );
    }

    String localPath = cleanPath;
    if (localPath.startsWith('file://')) {
      localPath = localPath.substring(7);
    }

    final file = File(localPath);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        cacheWidth: 360, // Efficient downscaled decode to save GPU memory
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      );
    }

    return const SizedBox.shrink();
  }
}
