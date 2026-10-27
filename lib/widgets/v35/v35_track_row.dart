import 'package:flutter/material.dart';
import '../../core/theme/v35_tokens.dart';
import '../../core/theme/v35_accent.dart';
import '../app_image.dart';

/// Reusable track row component for V3.5 Obsidian Emerald UI.
///
/// Suitable for Library, Playlists, Queue, Search, and Local Music screens.
/// Supports desktop hover states, selection states, and playing animations.
/// Purely presentational; receives callbacks without playback dependencies.
class V35TrackRow extends StatefulWidget {
  final String title;
  final String? artist;
  final String? album;
  final String? duration;
  final int? index;
  final Widget? artwork;
  final String? artworkPath;
  final Widget? trailing;
  final List<String>? badges;
  final bool isSelected;
  final bool isPlaying;
  final bool isCompact;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final VoidCallback? onMore;
  final VoidCallback? onSelect;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;

  const V35TrackRow({
    super.key,
    required this.title,
    this.artist,
    this.album,
    this.duration,
    this.index,
    this.artwork,
    this.artworkPath,
    this.trailing,
    this.badges,
    this.isSelected = false,
    this.isPlaying = false,
    this.isCompact = false,
    this.onTap,
    this.onPlay,
    this.onMore,
    this.onSelect,
    this.onDoubleTap,
    this.onLongPress,
  });

  @override
  State<V35TrackRow> createState() => _V35TrackRowState();
}

class _V35TrackRowState extends State<V35TrackRow> {
  bool _isHovered = false;

  Widget _buildArtwork(double size) {
    if (widget.artwork != null) {
      return SizedBox(
        width: size,
        height: size,
        child: ClipRRect(borderRadius: V35Tokens.brSm, child: widget.artwork!),
      );
    }

    return ClipRRect(
      borderRadius: V35Tokens.brSm,
      child: AppImage(
        imagePath: widget.artworkPath,
        width: size,
        height: size,
        defaultIcon: Icons.music_note_rounded,
      ),
    );
  }

  Widget _buildLeading(double artSize) {
    if (widget.index != null && !widget.isCompact) {
      // Desktop index / play toggle swap on hover
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            child: Center(
              child: _isHovered
                  ? GestureDetector(
                      onTap: widget.onPlay ?? widget.onTap,
                      child: Icon(
                        widget.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: V35Tokens.accent,
                        size: 20,
                      ),
                    )
                  : widget.isPlaying
                  ? Icon(
                      Icons.equalizer_rounded,
                      color: V35Tokens.accent,
                      size: 18,
                    )
                  : Text(
                      '${widget.index}',
                      style: V35Tokens.mono.copyWith(
                        color: V35Tokens.textMuted,
                        fontSize: 12,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: V35Tokens.space8),
          _buildArtwork(artSize),
        ],
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        _buildArtwork(artSize),
        if (widget.isPlaying)
          Container(
            width: artSize,
            height: artSize,
            decoration: BoxDecoration(
              color: V35Tokens.bgVoid.withValues(alpha: 0.55),
              borderRadius: V35Tokens.brSm,
            ),
            child: Icon(
              Icons.equalizer_rounded,
              color: V35Tokens.accent,
              size: 20,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<V35AccentPalette>(
      valueListenable: V35Accent.notifier,
      builder: (context, accentPalette, child) {
        final artSize = widget.isCompact ? 38.0 : 44.0;
        final rowHeight = widget.isCompact ? 50.0 : 58.0;

        // Background & Border resolution
        Color tileColor = Colors.transparent;
        Border? border;

        if (widget.isSelected) {
          tileColor = V35Tokens.accentDeep.withValues(alpha: 0.15);
          border = Border.all(color: V35Tokens.accent, width: 1.0);
        } else if (_isHovered) {
          tileColor = V35Tokens.bgElevated.withValues(alpha: 0.7);
        }

        return MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              onDoubleTap: widget.onDoubleTap,
              onLongPress: widget.onLongPress,
              onSecondaryTap: widget.onMore,
              borderRadius: V35Tokens.brMd,
              splashColor: V35Tokens.bgHighlight.withValues(alpha: 0.4),
              child: Container(
                height: rowHeight,
                padding: const EdgeInsets.symmetric(
                  horizontal: V35Tokens.space12,
                  vertical: V35Tokens.space4,
                ),
                decoration: BoxDecoration(
                  color: tileColor,
                  borderRadius: V35Tokens.brMd,
                  border: border,
                ),
                child: Row(
                  children: [
                    _buildLeading(artSize),
                    const SizedBox(width: V35Tokens.space12),

                    // Title & Artist section
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: V35Tokens.body.copyWith(
                              color: widget.isPlaying
                                  ? V35Tokens.accent
                                  : V35Tokens.textPrimary,
                              fontWeight: widget.isPlaying
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              fontSize: widget.isCompact ? 13.0 : 14.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (widget.badges != null)
                                for (final b in widget.badges!) ...[
                                  Container(
                                    margin: const EdgeInsets.only(right: 4),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: V35Tokens.bgHighlight,
                                      borderRadius: V35Tokens.brSm,
                                    ),
                                    child: Text(
                                      b,
                                      style: V35Tokens.caption.copyWith(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: V35Tokens.accentBright,
                                      ),
                                    ),
                                  ),
                                ],
                              Expanded(
                                child: Text(
                                  widget.artist ?? 'Unknown Artist',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: V35Tokens.secondary.copyWith(
                                    fontSize: widget.isCompact ? 11.5 : 12.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Optional Album column (visible when available and layout is not compact)
                    if (widget.album != null && !widget.isCompact) ...[
                      const SizedBox(width: V35Tokens.space16),
                      Expanded(
                        flex: 1,
                        child: Text(
                          widget.album!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: V35Tokens.secondary.copyWith(
                            color: V35Tokens.textMuted,
                            fontSize: 12.0,
                          ),
                        ),
                      ),
                    ],

                    // Duration display
                    if (widget.duration != null &&
                        widget.duration!.isNotEmpty) ...[
                      const SizedBox(width: V35Tokens.space12),
                      Text(
                        widget.duration!,
                        style: V35Tokens.mono.copyWith(
                          color: V35Tokens.textMuted,
                          fontSize: 12.0,
                        ),
                      ),
                    ],

                    // Optional Trailing or Context Menu
                    if (widget.trailing != null) ...[
                      const SizedBox(width: V35Tokens.space4),
                      widget.trailing!,
                    ] else if (widget.onMore != null) ...[
                      const SizedBox(width: V35Tokens.space4),
                      IconButton(
                        icon: const Icon(Icons.more_vert_rounded),
                        iconSize: 20,
                        color: _isHovered
                            ? V35Tokens.textPrimary
                            : V35Tokens.textMuted,
                        tooltip: 'Opsi lagu',
                        splashRadius: 20,
                        onPressed: widget.onMore,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
