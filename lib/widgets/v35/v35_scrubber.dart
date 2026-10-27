import 'package:flutter/material.dart';
import '../../core/theme/v35_tokens.dart';
import '../../core/theme/v35_accent.dart';

/// Reusable audio scrubber/seek-bar for V3.5 Obsidian Emerald UI.
///
/// Features:
/// - Emerald active track progress
/// - Subtle buffered track indicator
/// - Minimalist thumb with smooth hover/drag response
/// - Optional inline time labels (mm:ss)
/// - Purely presentational; zero playback logic.
class V35Scrubber extends StatefulWidget {
  final double value;
  final double max;
  final double? bufferedValue;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;
  final bool enabled;
  final bool showTimeLabels;
  final bool isCompact;

  const V35Scrubber({
    super.key,
    required this.value,
    required this.max,
    this.bufferedValue,
    this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.enabled = true,
    this.showTimeLabels = false,
    this.isCompact = false,
  });

  @override
  State<V35Scrubber> createState() => _V35ScrubberState();
}

class _V35ScrubberState extends State<V35Scrubber> {
  bool _isDragging = false;
  double? _dragValue;
  bool _isHovered = false;

  String _formatDuration(double seconds) {
    if (seconds.isNaN || seconds.isInfinite || seconds < 0) return '00:00';
    final totalSecs = seconds.round();
    final mins = totalSecs ~/ 60;
    final secs = totalSecs % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<V35AccentPalette>(
      valueListenable: V35Accent.notifier,
      builder: (context, accentPalette, child) {
        final effectiveMax = widget.max > 0 ? widget.max : 1.0;
        final currentValue = _isDragging
            ? (_dragValue ?? widget.value)
            : widget.value.clamp(0.0, effectiveMax);

        final trackHeight = widget.isCompact ? 3.0 : 4.0;
        final thumbRadius = widget.isCompact
            ? 4.0
            : (_isHovered || _isDragging ? 7.0 : 5.0);

        Widget slider = MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: trackHeight,
              activeTrackColor: V35Tokens.accent,
              inactiveTrackColor: V35Tokens.borderSubtle,
              secondaryActiveTrackColor: widget.bufferedValue != null
                  ? V35Tokens.bgHighlight
                  : null,
              thumbColor: V35Tokens.textPrimary,
              overlayColor: V35Tokens.accent.withValues(alpha: 0.16),
              thumbShape: RoundSliderThumbShape(
                enabledThumbRadius: thumbRadius,
                pressedElevation: 3.0,
              ),
              overlayShape: RoundSliderOverlayShape(
                overlayRadius: thumbRadius * 2.2,
              ),
              trackShape: const RectangularSliderTrackShape(),
            ),
            child: Slider(
              value: currentValue.clamp(0.0, effectiveMax),
              max: effectiveMax,
              secondaryTrackValue: widget.bufferedValue?.clamp(
                0.0,
                effectiveMax,
              ),
              onChanged: widget.enabled
                  ? (val) {
                      setState(() => _dragValue = val);
                      widget.onChanged?.call(val);
                    }
                  : null,
              onChangeStart: widget.enabled
                  ? (val) {
                      setState(() {
                        _isDragging = true;
                        _dragValue = val;
                      });
                      widget.onChangeStart?.call(val);
                    }
                  : null,
              onChangeEnd: widget.enabled
                  ? (val) {
                      setState(() {
                        _isDragging = false;
                        _dragValue = null;
                      });
                      widget.onChangeEnd?.call(val);
                    }
                  : null,
            ),
          ),
        );

        if (!widget.showTimeLabels) {
          return slider;
        }

        return Row(
          children: [
            Text(
              _formatDuration(currentValue),
              style: V35Tokens.mono.copyWith(fontSize: 11),
            ),
            const SizedBox(width: V35Tokens.space8),
            Expanded(child: slider),
            const SizedBox(width: V35Tokens.space8),
            Text(
              _formatDuration(widget.max),
              style: V35Tokens.mono.copyWith(fontSize: 11),
            ),
          ],
        );
      },
    );
  }
}
