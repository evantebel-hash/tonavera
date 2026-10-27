import 'package:flutter/material.dart';
import '../../core/theme/v35_tokens.dart';
import '../../core/theme/v35_accent.dart';

enum V35PlayButtonSize { sm, md, lg }

enum V35PlayButtonVariant { primary, secondary, subtle }

/// Reusable circular play/pause toggle button for V3.5 Obsidian Emerald UI.
///
/// Purely presentational; receives [isPlaying] state and emits [onToggle].
class V35PlayToggleCircle extends StatelessWidget {
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback? onToggle;
  final V35PlayButtonSize size;
  final V35PlayButtonVariant variant;
  final String? tooltip;

  const V35PlayToggleCircle({
    super.key,
    required this.isPlaying,
    this.isLoading = false,
    this.onToggle,
    this.size = V35PlayButtonSize.md,
    this.variant = V35PlayButtonVariant.primary,
    this.tooltip,
  });

  double get _dimension {
    switch (size) {
      case V35PlayButtonSize.sm:
        return 36.0;
      case V35PlayButtonSize.md:
        return 48.0;
      case V35PlayButtonSize.lg:
        return 56.0;
    }
  }

  double get _iconSize {
    switch (size) {
      case V35PlayButtonSize.sm:
        return 18.0;
      case V35PlayButtonSize.md:
        return 24.0;
      case V35PlayButtonSize.lg:
        return 30.0;
    }
  }

  Color get _backgroundColor {
    switch (variant) {
      case V35PlayButtonVariant.primary:
        return V35Tokens.accent;
      case V35PlayButtonVariant.secondary:
        return V35Tokens.bgElevated;
      case V35PlayButtonVariant.subtle:
        return Colors.transparent;
    }
  }

  Color get _iconColor {
    switch (variant) {
      case V35PlayButtonVariant.primary:
        return V35Tokens.bgVoid;
      case V35PlayButtonVariant.secondary:
        return V35Tokens.textPrimary;
      case V35PlayButtonVariant.subtle:
        return V35Tokens.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<V35AccentPalette>(
      valueListenable: V35Accent.notifier,
      builder: (context, accentPalette, child) {
        final dim = _dimension;
        final iconSz = _iconSize;
        final isInteractive = onToggle != null && !isLoading;

        Widget button = Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isInteractive ? onToggle : null,
            customBorder: const CircleBorder(),
            hoverColor: variant == V35PlayButtonVariant.primary
                ? V35Tokens.accentBright
                : V35Tokens.bgHighlight,
            splashColor: V35Tokens.accentDeep.withValues(alpha: 0.3),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: dim,
              height: dim,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _backgroundColor,
                border: variant == V35PlayButtonVariant.secondary
                    ? Border.all(color: V35Tokens.borderCard, width: 1.0)
                    : null,
                boxShadow: variant == V35PlayButtonVariant.primary
                    ? [
                        BoxShadow(
                          color: V35Tokens.accent.withValues(alpha: 0.25),
                          blurRadius: 12.0,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: isLoading
                    ? SizedBox(
                        width: iconSz * 0.85,
                        height: iconSz * 0.85,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(_iconColor),
                        ),
                      )
                    : Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: _iconColor,
                        size: iconSz,
                      ),
              ),
            ),
          ),
        );

        if (tooltip != null && tooltip!.isNotEmpty) {
          button = Tooltip(message: tooltip!, child: button);
        }

        return button;
      },
    );
  }
}
