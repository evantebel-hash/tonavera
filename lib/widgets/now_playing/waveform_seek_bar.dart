import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/v35_tokens.dart';
import '../../core/theme/v35_accent.dart';
import '../../services/waveform_service.dart';

/// Waveform seek bar widget.
///
/// Shows amplitude bars with progress tint and supports tap and horizontal drag seeking.
/// If waveform data is empty, falls back gracefully to a clean linear progress indicator.
class WaveformSeekBar extends StatefulWidget {
  final String? songId;
  final String? filePath;
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final Color? playedColor;
  final Color? remainingColor;
  final double height;
  final bool enabled;

  const WaveformSeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    this.songId,
    this.filePath,
    this.playedColor,
    this.remainingColor,
    this.height = 42.0,
    this.enabled = true,
  });

  @override
  State<WaveformSeekBar> createState() => _WaveformSeekBarState();
}

class _WaveformSeekBarState extends State<WaveformSeekBar> {
  List<double> _samples = [];
  bool _isLoading = false;
  double? _dragFraction;

  @override
  void initState() {
    super.initState();
    _loadWaveformData();
  }

  @override
  void didUpdateWidget(covariant WaveformSeekBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.songId != oldWidget.songId ||
        widget.filePath != oldWidget.filePath) {
      _loadWaveformData();
    }
  }

  Future<void> _loadWaveformData() async {
    if (widget.songId == null && widget.filePath == null) return;
    setState(() => _isLoading = true);

    try {
      final samples = await WaveformService.instance.getWaveform(
        songId: widget.songId ?? widget.filePath ?? 'unknown',
        filePath: widget.filePath,
        duration: widget.duration,
      );
      if (mounted) {
        setState(() {
          _samples = samples;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleTapOrDrag(double localX, double width) {
    if (width <= 0 || widget.duration.inMilliseconds <= 0) return;
    final frac = (localX / width).clamp(0.0, 1.0);
    setState(() => _dragFraction = frac);
  }

  void _commitSeek(double localX, double width) {
    if (width <= 0 || widget.duration.inMilliseconds <= 0) {
      setState(() => _dragFraction = null);
      return;
    }
    final frac = (localX / width).clamp(0.0, 1.0);
    final targetMs = (frac * widget.duration.inMilliseconds).round();
    widget.onSeek(Duration(milliseconds: targetMs));
    setState(() => _dragFraction = null);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<V35AccentPalette>(
      valueListenable: V35Accent.notifier,
      builder: (context, accentPalette, child) {
        final playedColor = widget.playedColor ?? V35Tokens.accent;
        final remainingColor = widget.remainingColor ?? V35Tokens.borderSubtle;

        final totalMs = widget.duration.inMilliseconds;
        final curMs = widget.position.inMilliseconds;
        final progress = totalMs > 0 ? (curMs / totalMs).clamp(0.0, 1.0) : 0.0;
        final effectiveProgress = _dragFraction ?? progress;

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) {
                _handleTapOrDrag(details.localPosition.dx, width);
                _commitSeek(details.localPosition.dx, width);
              },
              onHorizontalDragStart: (details) {
                _handleTapOrDrag(details.localPosition.dx, width);
              },
              onHorizontalDragUpdate: (details) {
                _handleTapOrDrag(details.localPosition.dx, width);
              },
              onHorizontalDragEnd: (details) {
                if (_dragFraction != null) {
                  final targetMs = (_dragFraction! * totalMs).round();
                  widget.onSeek(Duration(milliseconds: targetMs));
                  setState(() => _dragFraction = null);
                }
              },
              onHorizontalDragCancel: () {
                setState(() => _dragFraction = null);
              },
              child: SizedBox(
                height: widget.height,
                width: double.infinity,
                child: _samples.isEmpty || _isLoading
                    ? _buildFallbackProgress(
                        effectiveProgress,
                        playedColor,
                        remainingColor,
                      )
                    : CustomPaint(
                        painter: _WaveformPainter(
                          samples: _samples,
                          progress: effectiveProgress,
                          playedColor: playedColor,
                          remainingColor: remainingColor,
                        ),
                      ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFallbackProgress(
    double progress,
    Color playedColor,
    Color remainingColor,
  ) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3.0),
        child: LinearProgressIndicator(
          value: progress,
          backgroundColor: remainingColor,
          valueColor: AlwaysStoppedAnimation<Color>(playedColor),
          minHeight: 6.0,
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> samples;
  final double progress;
  final Color playedColor;
  final Color remainingColor;

  _WaveformPainter({
    required this.samples,
    required this.progress,
    required this.playedColor,
    required this.remainingColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty || size.width <= 0 || size.height <= 0) return;

    final count = samples.length;
    final spacing = 2.0;
    final barWidth = ((size.width - (count - 1) * spacing) / count).clamp(
      1.5,
      8.0,
    );
    final splitX = progress * size.width;

    final playedPaint = Paint()
      ..color = playedColor
      ..style = PaintingStyle.fill;

    final remainingPaint = Paint()
      ..color = remainingColor
      ..style = PaintingStyle.fill;

    final centerY = size.height / 2.0;

    for (int i = 0; i < count; i++) {
      final sample = samples[i].clamp(0.08, 1.0);
      final barHeight = max(4.0, size.height * sample * 0.85);
      final left = i * (barWidth + spacing);
      final top = centerY - (barHeight / 2.0);

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, barWidth, barHeight),
        Radius.circular(barWidth / 2),
      );

      if (left + barWidth <= splitX) {
        canvas.drawRRect(rrect, playedPaint);
      } else if (left >= splitX) {
        canvas.drawRRect(rrect, remainingPaint);
      } else {
        // Bar is partially played
        final playedFraction = (splitX - left) / barWidth;
        canvas.save();
        canvas.clipRect(
          Rect.fromLTWH(left, top, barWidth * playedFraction, barHeight),
        );
        canvas.drawRRect(rrect, playedPaint);
        canvas.restore();

        canvas.save();
        canvas.clipRect(
          Rect.fromLTWH(
            left + barWidth * playedFraction,
            top,
            barWidth * (1 - playedFraction),
            barHeight,
          ),
        );
        canvas.drawRRect(rrect, remainingPaint);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.samples != samples ||
        oldDelegate.playedColor != playedColor ||
        oldDelegate.remainingColor != remainingColor;
  }
}
