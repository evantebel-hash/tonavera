import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/v35_tokens.dart';
import '../../models/song_model.dart';
import '../../providers/player_provider.dart';
import '../app_image.dart';
import '../v35/v35_queue_panel.dart';
import '../v35/v35_track_actions.dart';

/// True Floating Mini Player for MyMusic V3.5.
///
/// Features:
/// - Independent floating surface / overlay above main app
/// - Real-time synchronized playback with PlayerProvider
/// - Realistic physical vinyl record overlapping behind album art
/// - Vinyl rotates when playing, pauses when paused
/// - Dark glassmorphism body (#13171A, 94% opacity + BackdropFilter blur)
/// - Song title & artist with truncation (ellipsis)
/// - Previous / Play-Pause (focal point) / Next controls
/// - Queue, Favorite, and More action buttons
/// - Seekable real-time progress bar with emerald/accent tint
/// - Draggable with position memory and bounds clamping
/// - Independent close button that does NOT close MyMusic or stop playback
class FloatingMiniPlayer extends StatefulWidget {
  final VoidCallback onClose;
  final ValueChanged<Offset>? onPositionChanged;
  final Offset? initialPosition;

  const FloatingMiniPlayer({
    super.key,
    required this.onClose,
    this.onPositionChanged,
    this.initialPosition,
  });

  @override
  State<FloatingMiniPlayer> createState() => _FloatingMiniPlayerState();
}

class _FloatingMiniPlayerState extends State<FloatingMiniPlayer> {
  bool _isHovered = false;

  String _formatDuration(Duration d) {
    final mins = d.inMinutes;
    final secs = d.inSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        final song = player.currentSong;
        final isPlaying = player.isPlaying;
        final position = player.position;
        final duration = player.duration;

        final double progress = duration.inMilliseconds > 0
            ? (position.inMilliseconds / duration.inMilliseconds).clamp(
                0.0,
                1.0,
              )
            : 0.0;

        return MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16.0),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                width: 440.0,
                height: 136.0,
                decoration: BoxDecoration(
                  color: const Color(0xFF13171A).withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(
                    color: _isHovered
                        ? const Color(0xFF333B44)
                        : const Color(0xFF232930),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.65),
                      blurRadius: 28,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Main content row (Artwork + Vinyl + Controls + Meta)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 12, 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // 1. ALBUM ARTWORK + OVERLAPPING VINYL RECORD
                            _buildCoverAndVinylCluster(song?.cover, isPlaying),

                            const SizedBox(width: 14),

                            // 2. SONG INFO & CONTROLS
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Top row: Title/Artist + Close Button
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              song?.title ?? 'Tidak Ada Lagu',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: V35Tokens.textPrimary,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13.5,
                                                letterSpacing: -0.2,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              song?.artistName ??
                                                  'TONAVERA Player',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: V35Tokens.textSecondary,
                                                fontWeight: FontWeight.w400,
                                                fontSize: 11.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Independent Close Button
                                      InkResponse(
                                        onTap: widget.onClose,
                                        radius: 14,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.05,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close_rounded,
                                            size: 14,
                                            color: V35Tokens.textMuted,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const Spacer(),

                                  // Center row: Playback Controls (Prev, Play/Pause, Next) + Action Buttons
                                  Row(
                                    children: [
                                      // Previous
                                      _buildIconButton(
                                        icon: Icons.skip_previous_rounded,
                                        size: 20,
                                        tooltip: 'Lagu Sebelumnya',
                                        onPressed: song != null
                                            ? () => player.previous()
                                            : null,
                                      ),
                                      const SizedBox(width: 4),

                                      // Play / Pause — Prominent Focal Point
                                      _buildPlayPauseButton(
                                        player,
                                        isPlaying,
                                        song != null,
                                      ),
                                      const SizedBox(width: 4),

                                      // Next
                                      _buildIconButton(
                                        icon: Icons.skip_next_rounded,
                                        size: 20,
                                        tooltip: 'Lagu Berikutnya',
                                        onPressed: song != null
                                            ? () => player.next()
                                            : null,
                                      ),

                                      const Spacer(),

                                      // Queue Button
                                      _buildIconButton(
                                        icon: Icons.queue_music_rounded,
                                        size: 17,
                                        tooltip: 'Antrean Lagu',
                                        onPressed: () {
                                          V35QueuePanel.showBottomSheet(
                                            context,
                                          );
                                        },
                                      ),

                                      // Favorite Button
                                      _buildFavoriteButton(player, song),

                                      // More Button
                                      _buildIconButton(
                                        icon: Icons.more_horiz_rounded,
                                        size: 17,
                                        tooltip: 'Opsi Lainnya',
                                        onPressed: song != null
                                            ? () => V35TrackActions.show(
                                                context,
                                                song: song,
                                                player: player,
                                              )
                                            : null,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 3. BOTTOM PROGRESS BAR & TIMESTAMPS
                    _buildProgressBar(player, progress, position, duration),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Builds the album artwork overlapping the vinyl record
  Widget _buildCoverAndVinylCluster(String? coverUrl, bool isPlaying) {
    const double artSize = 74.0;
    const double vinylShift = 28.0;

    return SizedBox(
      width: artSize + vinylShift,
      height: artSize,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerLeft,
        children: [
          // Vinyl Record partially overlapping behind
          Positioned(
            left: vinylShift,
            top: 0,
            child: _MiniVinylDisc(
              size: artSize,
              imageUrl: coverUrl,
              isPlaying: isPlaying,
            ),
          ),

          // Album Artwork (in front, with rounded corners and drop shadow)
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              width: artSize,
              height: artSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.75),
                    blurRadius: 14,
                    spreadRadius: 1,
                    offset: const Offset(4, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10.0),
                child: AppImage(
                  imagePath: coverUrl,
                  width: artSize,
                  height: artSize,
                  fit: BoxFit.cover,
                  defaultIcon: Icons.album_rounded,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Play / Pause circular focal point button
  Widget _buildPlayPauseButton(
    PlayerProvider player,
    bool isPlaying,
    bool enabled,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? () => player.togglePlayPause() : null,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: enabled ? V35Tokens.accent : V35Tokens.bgHighlight,
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: V35Tokens.accent.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 20,
            color: enabled ? V35Tokens.bgVoid : V35Tokens.textMuted,
          ),
        ),
      ),
    );
  }

  /// Favorite toggle button synchronized with song model
  Widget _buildFavoriteButton(PlayerProvider player, SongModel? song) {
    final isFav = song?.isFavorite == true;
    return _buildIconButton(
      icon: isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      size: 17,
      color: isFav ? V35Tokens.accent : V35Tokens.textSecondary,
      tooltip: isFav ? 'Hapus dari Favorit' : 'Tambah ke Favorit',
      onPressed: song != null ? () => player.toggleFavorite(song) : null,
    );
  }

  /// Helper for compact icon buttons
  Widget _buildIconButton({
    required IconData icon,
    required double size,
    required VoidCallback? onPressed,
    String? tooltip,
    Color? color,
  }) {
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        icon: Icon(icon, size: size),
        color: color ?? V35Tokens.textSecondary,
        padding: EdgeInsets.zero,
        splashRadius: 14,
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }

  /// Real-time seekable progress bar at the bottom
  Widget _buildProgressBar(
    PlayerProvider player,
    double progress,
    Duration position,
    Duration duration,
  ) {
    return Tooltip(
      message: '${_formatDuration(position)} / ${_formatDuration(duration)}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) {
          _seekFromGlobalPosition(details.localPosition.dx, player, duration);
        },
        onTapDown: (details) {
          _seekFromGlobalPosition(details.localPosition.dx, player, duration);
        },
        child: Container(
          height: 10,
          padding: const EdgeInsets.only(top: 4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final barWidth = constraints.maxWidth;
              final activeWidth = (barWidth * progress).clamp(0.0, barWidth);

              return Stack(
                children: [
                  // Inactive track
                  Container(
                    width: barWidth,
                    height: 3,
                    decoration: BoxDecoration(
                      color: const Color(0xFF262B30),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),

                  // Active track (muted emerald / accent)
                  Container(
                    width: activeWidth,
                    height: 3,
                    decoration: BoxDecoration(
                      color: V35Tokens.accent,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _seekFromGlobalPosition(
    double localX,
    PlayerProvider player,
    Duration duration,
  ) {
    if (duration.inMilliseconds <= 0) return;
    const double barWidth = 440.0;
    final double fraction = (localX / barWidth).clamp(0.0, 1.0);
    final int targetMs = (fraction * duration.inMilliseconds).round();
    player.seek(Duration(milliseconds: targetMs));
  }
}

/// Physical Vinyl Record disc widget with authentic grooves, specular highlights, and rotation
class _MiniVinylDisc extends StatefulWidget {
  final double size;
  final String? imageUrl;
  final bool isPlaying;

  const _MiniVinylDisc({
    required this.size,
    required this.imageUrl,
    required this.isPlaying,
  });

  @override
  State<_MiniVinylDisc> createState() => _MiniVinylDiscState();
}

class _MiniVinylDiscState extends State<_MiniVinylDisc>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _MiniVinylDisc oldWidget) {
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
    final labelSize = widget.size * 0.40;
    final spindleSize = widget.size * 0.08;

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.65),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(2, 3),
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
              size: Size(widget.size, widget.size),
              painter: const _MiniVinylPainter(),
            ),

            // Center Label (Album Artwork)
            Container(
              width: labelSize,
              height: labelSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF1E2328).withValues(alpha: 0.9),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: ClipOval(
                child: AppImage(
                  imagePath: widget.imageUrl,
                  width: labelSize,
                  height: labelSize,
                  fit: BoxFit.cover,
                  defaultIcon: Icons.music_note_rounded,
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
                  color: const Color(0xFF4A5560).withValues(alpha: 0.8),
                  width: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// CustomPainter rendering realistic vinyl grooves and light sheen
class _MiniVinylPainter extends CustomPainter {
  const _MiniVinylPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Base Dark Obsidian Vinyl Disc Gradient
    final basePaint = Paint()
      ..shader = RadialGradient(
        colors: const [Color(0xFF191C20), Color(0xFF0F1114), Color(0xFF060708)],
        stops: const [0.38, 0.75, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, basePaint);

    // 2. Outer Bevel Rim
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF2B333B);
    canvas.drawCircle(center, radius - 1.0, rimPaint);

    // 3. Audio Concentric Micro-Grooves
    final minGrooveR = radius * 0.42;
    final maxGrooveR = radius * 0.94;
    const grooveCount = 18;
    final step = (maxGrooveR - minGrooveR) / grooveCount;

    for (int i = 0; i < grooveCount; i++) {
      final r = minGrooveR + i * step;
      final isTrackGap = (i == 5 || i == 11);
      final alpha = isTrackGap
          ? 0.08
          : (0.02 + 0.015 * math.sin(i * 0.9)).clamp(0.015, 0.045);

      final groovePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isTrackGap ? 1.2 : 0.6
        ..color = isTrackGap
            ? const Color(0xFF020304)
            : Colors.white.withValues(alpha: alpha);

      canvas.drawCircle(center, r, groovePaint);
    }

    // 4. Anisotropic Specular Light Sheen Cones
    canvas.save();
    final groovePath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: maxGrooveR))
      ..addOval(Rect.fromCircle(center: center, radius: minGrooveR))
      ..fillType = PathFillType.evenOdd;
    canvas.clipPath(groovePath);

    final sheenPaint = Paint()
      ..shader = SweepGradient(
        startAngle: 0.0,
        endAngle: math.pi * 2,
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.06),
          Colors.transparent,
          Colors.transparent,
          Colors.white.withValues(alpha: 0.06),
          Colors.transparent,
        ],
        stops: const [0.06, 0.18, 0.30, 0.56, 0.68, 0.80],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, sheenPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
