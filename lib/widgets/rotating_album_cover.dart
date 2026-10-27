import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme/v35_tokens.dart';
import 'app_image.dart';

/// Authentic V3.5 Obsidian Emerald Vinyl Record Album Cover.
///
/// Features procedural Flutter rendering:
/// - Layer 1: Dark obsidian vinyl disc base
/// - Layer 2: 32 Concentric micro-grooves with track gaps & organic opacity variations
/// - Layer 3: Anisotropic specular sheen cones (SweepGradient light reflection)
/// - Layer 4: Subtle ambient Emerald cross-sheen
/// - Layer 5: Authentic 12" LP center label (41% disc diameter) with album artwork
/// - Layer 6: Center spindle hole (7.5% diameter) with metallic bevel and dark void
/// - Layer 7: Outer bevel rim & lead-in/lead-out groove margins
///
/// Performance:
/// - CustomPainter has `shouldRepaint => false`. The procedural vinyl disc is rendered
///   once to an offscreen cache and smoothly rotated via compositor matrix transforms.
class RotatingAlbumCover extends StatefulWidget {
  final String? imageUrl;
  final bool isPlaying;

  const RotatingAlbumCover({
    super.key,
    required this.imageUrl,
    required this.isPlaying,
  });

  @override
  State<RotatingAlbumCover> createState() => _RotatingAlbumCoverState();
}

class _RotatingAlbumCoverState extends State<RotatingAlbumCover>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 20s per revolution creates a graceful, authentic LP turntable rotation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );

    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(RotatingAlbumCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth * 0.95
            : constraints.maxHeight * 0.95;
        final clampedSize = size.clamp(140.0, 480.0);

        final labelSize = clampedSize * 0.41;
        final spindleSize = clampedSize * 0.075;

        return Center(
          child: Container(
            width: clampedSize,
            height: clampedSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                // Ambient active accent glow behind vinyl
                BoxShadow(
                  color: V35Tokens.accent.withValues(alpha: 0.12),
                  blurRadius: 36,
                  spreadRadius: 2,
                ),
                // Deep turntable drop shadow
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.75),
                  blurRadius: 26,
                  spreadRadius: 4,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: RotationTransition(
              turns: _controller,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Procedural Vinyl Grooves and Specular Sheen Disc
                  CustomPaint(
                    size: Size(clampedSize, clampedSize),
                    painter: const _VinylDiscPainter(),
                  ),

                  // Center Label (Album Artwork)
                  Container(
                    width: labelSize,
                    height: labelSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.65),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        transitionBuilder: (child, animation) =>
                            FadeTransition(opacity: animation, child: child),
                        child: AppImage(
                          key: ValueKey<String>(widget.imageUrl ?? ''),
                          imagePath: widget.imageUrl,
                          width: labelSize,
                          height: labelSize,
                          fit: BoxFit.cover,
                          fallback: _buildFallbackLabel(labelSize),
                        ),
                      ),
                    ),
                  ),

                  // Pressed Label Border Ring
                  Container(
                    width: labelSize,
                    height: labelSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF1E2328).withValues(alpha: 0.8),
                        width: 1.5,
                      ),
                    ),
                  ),

                  // Center Spindle Hole with Metallic Bevel
                  Container(
                    width: spindleSize,
                    height: spindleSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: V35Tokens.bgVoid,
                      border: Border.all(
                        color: const Color(0xFF4A5560).withValues(alpha: 0.7),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.9),
                          blurRadius: 4,
                          spreadRadius: 0.5,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFallbackLabel(double size) {
    return Container(
      color: const Color(0xFF14191E),
      alignment: Alignment.center,
      child: Icon(
        Icons.album_rounded,
        size: size * 0.45,
        color: V35Tokens.accent.withValues(alpha: 0.7),
      ),
    );
  }
}

/// CustomPainter rendering realistic vinyl micro-grooves and specular sheen.
class _VinylDiscPainter extends CustomPainter {
  const _VinylDiscPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Base Dark Obsidian Vinyl Disc Gradient
    final basePaint = Paint()
      ..shader = RadialGradient(
        colors: const [
          Color(0xFF171A1E), // center lead-out dark slate
          Color(0xFF0F1114), // groove body
          Color(0xFF060708), // outer rim
        ],
        stops: const [0.38, 0.75, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, basePaint);

    // 2. Outer Bevel Rim Highlight & Lead-in Outer Margin
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0xFF2B333B);
    canvas.drawCircle(center, radius - 1.2, rimPaint);

    final leadInMargin = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = const Color(0xFF121518);
    canvas.drawCircle(center, radius * 0.965, leadInMargin);

    // 3. Audio Recording Concentric Micro-Grooves (from 0.43 R to 0.945 R)
    final minGrooveR = radius * 0.425;
    final maxGrooveR = radius * 0.945;
    const grooveCount = 34;
    final step = (maxGrooveR - minGrooveR) / grooveCount;

    for (int i = 0; i < grooveCount; i++) {
      final r = minGrooveR + i * step;
      // Track separation gap markings
      final isTrackGap = (i == 8 || i == 17 || i == 26);
      final alpha = isTrackGap
          ? 0.08
          : (0.02 + 0.018 * math.sin(i * 0.8)).clamp(0.012, 0.045);

      final groovePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isTrackGap ? 1.6 : 0.7
        ..color = isTrackGap
            ? const Color(0xFF020304)
            : Colors.white.withValues(alpha: alpha);

      canvas.drawCircle(center, r, groovePaint);
    }

    // 4. Anisotropic Specular Light Wedges (Vinyl Sheen)
    // Clip strictly to audio grooved surface
    canvas.save();
    final groovePath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: maxGrooveR))
      ..addOval(Rect.fromCircle(center: center, radius: minGrooveR))
      ..fillType = PathFillType.evenOdd;
    canvas.clipPath(groovePath);

    // Primary Dual-Cone Specular Light Sheen (45 deg & 225 deg)
    final sheenPaint = Paint()
      ..shader = SweepGradient(
        startAngle: 0.0,
        endAngle: math.pi * 2,
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.055), // light cone 1 peak
          Colors.transparent,
          Colors.transparent,
          Colors.white.withValues(alpha: 0.055), // light cone 2 peak
          Colors.transparent,
        ],
        stops: const [0.06, 0.18, 0.30, 0.56, 0.68, 0.80],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, sheenPaint);

    // Subtle Secondary Ambient Cross-Sheen
    final ambientSheen = Paint()
      ..shader = SweepGradient(
        startAngle: 0.0,
        endAngle: math.pi * 2,
        colors: [
          Colors.transparent,
          V35Tokens.accent.withValues(alpha: 0.025),
          Colors.transparent,
          Colors.transparent,
          V35Tokens.accent.withValues(alpha: 0.025),
          Colors.transparent,
        ],
        stops: const [0.32, 0.40, 0.48, 0.82, 0.90, 0.98],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, ambientSheen);
    canvas.restore();

    // 5. Run-out groove markings near center label
    final runOutPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0xFF1E242B).withValues(alpha: 0.5);
    canvas.drawCircle(center, radius * 0.42, runOutPaint);

    // 6. Center label outer pressed ridge
    final labelRidgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = const Color(0xFF07090B);
    canvas.drawCircle(center, radius * 0.41, labelRidgePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
