import 'package:flutter/material.dart';
import '../../core/theme/v35_tokens.dart';
import '../app_image.dart';
import 'v35_play_toggle_circle.dart';

/// Reusable media card for albums, playlists, artists, and YouTube recommendations.
///
/// Follows V3.5 Obsidian Emerald aesthetics with rounded artwork, subtle borders,
/// and smooth hover elevation.
class V35MediaCard extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Widget? artwork;
  final String? artworkPath;
  final String? badge;
  final bool isCircular;
  final bool showPlayOverlay;
  final double width;
  final double? height;
  final double aspectRatio;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;

  const V35MediaCard({
    super.key,
    required this.title,
    this.subtitle,
    this.artwork,
    this.artworkPath,
    this.badge,
    this.isCircular = false,
    this.showPlayOverlay = true,
    this.width = 154.0,
    this.height,
    this.aspectRatio = 1.0,
    this.onTap,
    this.onPlay,
  });

  @override
  State<V35MediaCard> createState() => _V35MediaCardState();
}

class _V35MediaCardState extends State<V35MediaCard> {
  bool _isHovered = false;

  Widget _buildArtwork() {
    final br = widget.isCircular ? V35Tokens.brFull : V35Tokens.brMd;

    Widget imageContent;
    if (widget.artwork != null) {
      imageContent = widget.artwork!;
    } else {
      imageContent = AppImage(
        imagePath: widget.artworkPath,
        fit: BoxFit.cover,
        defaultIcon: widget.isCircular
            ? Icons.person_rounded
            : Icons.album_rounded,
      );
    }

    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: ClipRRect(
        borderRadius: br,
        child: Stack(
          fit: StackFit.expand,
          children: [
            imageContent,

            // Badge overlay (top-left)
            if (widget.badge != null && widget.badge!.isNotEmpty)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: V35Tokens.bgVoid.withValues(alpha: 0.8),
                    borderRadius: V35Tokens.brSm,
                    border: Border.all(
                      color: V35Tokens.borderSubtle,
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    widget.badge!,
                    style: V35Tokens.caption.copyWith(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: V35Tokens.accentBright,
                    ),
                  ),
                ),
              ),

            // Play overlay button (bottom-right, animated on hover)
            if (widget.showPlayOverlay && widget.onPlay != null)
              Positioned(
                right: 8,
                bottom: 8,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _isHovered ? 1.0 : 0.0,
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 180),
                    offset: _isHovered ? Offset.zero : const Offset(0, 0.2),
                    child: V35PlayToggleCircle(
                      isPlaying: false,
                      size: V35PlayButtonSize.sm,
                      onToggle: widget.onPlay,
                      tooltip: 'Play',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: V35Tokens.brLg,
          hoverColor: V35Tokens.bgElevated.withValues(alpha: 0.5),
          splashColor: V35Tokens.bgHighlight.withValues(alpha: 0.3),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: widget.width,
            height: widget.height,
            padding: const EdgeInsets.all(V35Tokens.space12),
            decoration: BoxDecoration(
              color: _isHovered ? V35Tokens.bgElevated : V35Tokens.bgSurface,
              borderRadius: V35Tokens.brLg,
              border: Border.all(
                color: _isHovered
                    ? V35Tokens.borderCard
                    : V35Tokens.borderSubtle,
                width: 1.0,
              ),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: widget.isCircular
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildArtwork(),
                const SizedBox(height: V35Tokens.space8),
                Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: widget.isCircular
                      ? TextAlign.center
                      : TextAlign.start,
                  style: V35Tokens.body.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
                if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: widget.isCircular
                        ? TextAlign.center
                        : TextAlign.start,
                    style: V35Tokens.secondary.copyWith(
                      fontSize: 12.0,
                      color: V35Tokens.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
