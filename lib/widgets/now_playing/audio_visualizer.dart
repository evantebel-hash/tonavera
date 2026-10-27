import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/v35_tokens.dart';
import '../../core/theme/v35_accent.dart';

enum VisualizerStyle { bars, wave, circular }

/// A lightweight, premium, non-intrusive audio visualizer widget.
///
/// Uses an internal simulation ticker linked to playback state and frequency synthesis
/// that reacts dynamically to track playback without overloading GPU or audio engine.
class AudioVisualizer extends StatefulWidget {
  final bool isPlaying;
  final bool isBuffering;
  final String? songId;
  final Color? accentColor;
  final Color? secondaryColor;
  final int barCount;
  final double height;
  final VisualizerStyle style;
  final bool enabled;

  const AudioVisualizer({
    super.key,
    required this.isPlaying,
    this.isBuffering = false,
    this.songId,
    this.accentColor,
    this.secondaryColor,
    this.barCount = 28,
    this.height = 48.0,
    this.style = VisualizerStyle.bars,
    this.enabled = true,
  });

  @override
  State<AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<AudioVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<double> _magnitudes = [];
  final List<double> _targetMagnitudes = [];
  final Random _random = Random();
  double _phase = 0.0;

  @override
  void initState() {
    super.initState();
    _initMagnitudes();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..addListener(_onTick);

    if (widget.isPlaying && widget.enabled) {
      _controller.repeat();
    }
  }

  void _initMagnitudes() {
    _magnitudes.clear();
    _targetMagnitudes.clear();
    for (int i = 0; i < widget.barCount; i++) {
      _magnitudes.add(0.05);
      _targetMagnitudes.add(0.05);
    }
  }

  @override
  void didUpdateWidget(covariant AudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.barCount != oldWidget.barCount) {
      _initMagnitudes();
    }

    if (widget.songId != oldWidget.songId) {
      // Song changed: smooth reset
      _initMagnitudes();
    }

    if (!widget.enabled || (!widget.isPlaying && !widget.isBuffering)) {
      if (_controller.isAnimating) {
        _controller.stop();
      }
      _decayMagnitudes();
    } else {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    }
  }

  void _decayMagnitudes() {
    for (int i = 0; i < _magnitudes.length; i++) {
      _magnitudes[i] = (_magnitudes[i] * 0.7).clamp(0.04, 1.0);
    }
    if (mounted) setState(() {});
  }

  void _onTick() {
    if (!mounted) return;

    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disableAnimations) {
      return; // Respect reduced motion
    }

    _phase += 0.08;
    if (_phase > 2 * pi) _phase -= 2 * pi;

    if (widget.isBuffering) {
      // Subtle sine wave animation while buffering
      for (int i = 0; i < _magnitudes.length; i++) {
        final progress = (i / _magnitudes.length) * 2 * pi;
        _magnitudes[i] = 0.15 + 0.15 * sin(_phase * 2 + progress);
      }
      setState(() {});
      return;
    }

    if (!widget.isPlaying) {
      _decayMagnitudes();
      return;
    }

    // Dynamic multi-frequency spectrum synthesis
    final count = _magnitudes.length;
    for (int i = 0; i < count; i++) {
      final normalizedIdx = i / count;

      // Bass presence in low bands, mid rhythms, crisp highs
      double bass = 0.45 * sin(_phase * 1.5 + normalizedIdx * 3.0).abs();
      double mid = 0.35 * sin(_phase * 3.2 - normalizedIdx * 6.0).abs();
      double treble = 0.25 * cos(_phase * 4.8 + normalizedIdx * 9.0).abs();
      double noise = _random.nextDouble() * 0.15;

      // Frequency bell weighting (slight boost in low-mids)
      double weight = 1.0 - pow((normalizedIdx - 0.35), 2) * 1.2;
      double target = ((bass + mid + treble + noise) * weight).clamp(
        0.08,
        0.98,
      );

      // Smooth interpolation (lerp)
      _magnitudes[i] = _magnitudes[i] + (target - _magnitudes[i]) * 0.35;
    }

    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<V35AccentPalette>(
      valueListenable: V35Accent.notifier,
      builder: (context, accentPalette, child) {
        final accent = widget.accentColor ?? V35Tokens.accent;
        final secondary = widget.secondaryColor ?? V35Tokens.accentBright;

        return RepaintBoundary(
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: CustomPaint(
              painter: _VisualizerPainter(
                magnitudes: List.unmodifiable(_magnitudes),
                accentColor: accent,
                secondaryColor: secondary,
                style: widget.style,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VisualizerPainter extends CustomPainter {
  final List<double> magnitudes;
  final Color accentColor;
  final Color secondaryColor;
  final VisualizerStyle style;

  _VisualizerPainter({
    required this.magnitudes,
    required this.accentColor,
    required this.secondaryColor,
    required this.style,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (magnitudes.isEmpty || size.width <= 0 || size.height <= 0) return;

    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          accentColor.withValues(alpha: 0.9),
          secondaryColor.withValues(alpha: 0.6),
        ],
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final count = magnitudes.length;
    final totalSpacing = (count - 1) * 3.0;
    final barWidth = ((size.width - totalSpacing) / count).clamp(2.0, 16.0);

    for (int i = 0; i < count; i++) {
      final mag = magnitudes[i].clamp(0.05, 1.0);
      final barHeight = (size.height * mag).clamp(3.0, size.height);
      final left = i * (barWidth + 3.0);
      final top = size.height - barHeight;

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, barWidth, barHeight),
        const Radius.circular(3.0),
      );
      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _VisualizerPainter oldDelegate) {
    return oldDelegate.magnitudes != magnitudes ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.secondaryColor != secondaryColor;
  }
}
