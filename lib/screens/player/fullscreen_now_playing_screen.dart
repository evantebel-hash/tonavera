import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/v35_tokens.dart';
import '../../core/theme/v35_accent.dart';
import '../../providers/player_provider.dart';
import '../../models/song_model.dart';
import '../../widgets/rotating_album_cover.dart';
import '../../widgets/now_playing/dynamic_background.dart';
import '../../widgets/now_playing/audio_visualizer.dart';
import '../../widgets/now_playing/waveform_seek_bar.dart';
import '../../widgets/lyrics/lyrics_view.dart';
import '../lyrics/lyrics_screen.dart';

/// Immersive Fullscreen Now Playing screen (Phase 3.5 / V3.5).
///
/// Integrates:
/// - Dynamic Background
/// - Audio Visualizer
/// - Waveform Seek Bar
/// - Auto-hiding interactive controls (tap or mouse move to show)
/// - Synchronized Lyrics mode toggle
/// - Full keyboard shortcut support (Desktop: Escape exits fullscreen, Space toggles play/pause)
class FullscreenNowPlayingScreen extends StatefulWidget {
  const FullscreenNowPlayingScreen({super.key});

  @override
  State<FullscreenNowPlayingScreen> createState() =>
      _FullscreenNowPlayingScreenState();
}

class _FullscreenNowPlayingScreenState
    extends State<FullscreenNowPlayingScreen> {
  bool _showControls = true;
  bool _showLyrics = false;
  Timer? _hideTimer;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _startHideTimer();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _showControls) {
        setState(() => _showControls = false);
      }
    });
  }

  void _onUserInteraction() {
    if (!_showControls) {
      setState(() => _showControls = true);
    }
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<PlayerProvider>(context);
    final song = player.currentSong;

    if (song == null) {
      return Scaffold(
        backgroundColor: V35Tokens.bgVoid,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Tidak ada lagu yang sedang diputar',
                style: TextStyle(color: V35Tokens.textMuted),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Kembali'),
              ),
            ],
          ),
        ),
      );
    }

    return ValueListenableBuilder<V35AccentPalette>(
      valueListenable: V35Accent.notifier,
      builder: (context, accentPalette, _) {
        return KeyboardListener(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: (event) {
            if (event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.escape) {
                Navigator.pop(context);
              } else if (event.logicalKey == LogicalKeyboardKey.space) {
                player.togglePlayPause();
                _onUserInteraction();
              }
            }
          },
          child: Scaffold(
            backgroundColor: Colors.black,
            body: DynamicBackground(
              song: song,
              enabled: player.dynamicBackgroundEnabled,
              child: MouseRegion(
                onHover: (_) => _onUserInteraction(),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() => _showControls = !_showControls);
                    if (_showControls) _startHideTimer();
                  },
                  child: Stack(
                    children: [
                      // Main immersive content
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24.0,
                            vertical: 16.0,
                          ),
                          child: Column(
                            children: [
                              // Top App Bar Controls
                              _buildTopBar(context, player, song),

                              // Center View (Artwork + Visualizer OR Live Lyrics)
                              Expanded(
                                child: _showLyrics
                                    ? LyricsView(song: song)
                                    : _buildCenterArtwork(player, song),
                              ),

                              const SizedBox(height: 8),

                              // Audio Visualizer Layer
                              if (player.visualizerEnabled)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0,
                                    vertical: 8.0,
                                  ),
                                  child: AudioVisualizer(
                                    isPlaying: player.isPlaying,
                                    songId: song.id.toString(),
                                    enabled: player.visualizerEnabled,
                                    accentColor: V35Tokens.accent,
                                    secondaryColor: V35Tokens.accentBright,
                                    height: 36.0,
                                  ),
                                ),

                              // Bottom Player Section (Song Info, Waveform, Controls)
                              AnimatedOpacity(
                                opacity: _showControls ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 300),
                                child: _buildBottomControls(
                                  context,
                                  player,
                                  song,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    PlayerProvider player,
    SongModel song,
  ) {
    return AnimatedOpacity(
      opacity: _showControls ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: 'Tutup Fullscreen (Esc)',
            icon: const Icon(
              Icons.fullscreen_exit_rounded,
              color: V35Tokens.textPrimary,
              size: 28,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            _showLyrics ? 'LIRIK SINKRON' : 'NOW PLAYING',
            style: const TextStyle(
              color: V35Tokens.textSecondary,
              fontSize: 12,
              letterSpacing: 2.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            children: [
              IconButton(
                tooltip: _showLyrics ? 'Tampilkan Artwork' : 'Tampilkan Lirik',
                icon: Icon(
                  _showLyrics ? Icons.album_rounded : Icons.lyrics_rounded,
                  color: _showLyrics ? V35Tokens.accent : V35Tokens.textPrimary,
                ),
                onPressed: () {
                  _onUserInteraction();
                  setState(() => _showLyrics = !_showLyrics);
                },
              ),
              IconButton(
                tooltip: 'Buka Layar Penuh Lirik',
                icon: const Icon(
                  Icons.open_in_full_rounded,
                  color: V35Tokens.textSecondary,
                  size: 20,
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => LyricsScreen(song: song)),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCenterArtwork(PlayerProvider player, SongModel song) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: RotatingAlbumCover(
          imageUrl: song.cover,
          isPlaying: player.isPlaying,
        ),
      ),
    );
  }

  Widget _buildBottomControls(
    BuildContext context,
    PlayerProvider player,
    SongModel song,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Track Title & Favorite
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: V35Tokens.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.artistName ?? 'Unknown Artist',
                    style: const TextStyle(
                      fontSize: 14,
                      color: V35Tokens.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                song.isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: song.isFavorite ? V35Tokens.accent : V35Tokens.textMuted,
                size: 26,
              ),
              onPressed: () {
                _onUserInteraction();
                player.toggleFavorite(song);
              },
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Waveform Seek Bar (or standard slider fallback)
        if (player.waveformSeekEnabled)
          WaveformSeekBar(
            songId: song.id.toString(),
            filePath: song.filePath,
            position: player.position,
            duration: player.duration,
            playedColor: V35Tokens.accent,
            remainingColor: V35Tokens.borderSubtle,
            onSeek: (dur) {
              _onUserInteraction();
              player.seek(dur);
            },
            height: 38,
          )
        else
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: V35Tokens.accent,
              inactiveTrackColor: V35Tokens.borderSubtle,
              thumbColor: Colors.white,
            ),
            child: Slider(
              value: player.position.inSeconds.toDouble().clamp(
                0.0,
                player.duration.inSeconds.toDouble(),
              ),
              max: player.duration.inSeconds.toDouble() > 0
                  ? player.duration.inSeconds.toDouble()
                  : 1.0,
              onChanged: (val) {
                _onUserInteraction();
                player.seek(Duration(seconds: val.toInt()));
              },
            ),
          ),

        // Timestamps
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(player.position),
                style: const TextStyle(
                  fontSize: 12,
                  color: V35Tokens.textMuted,
                ),
              ),
              Text(
                _formatDuration(player.duration),
                style: const TextStyle(
                  fontSize: 12,
                  color: V35Tokens.textMuted,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Primary Playback Controls
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: Icon(
                Icons.shuffle_rounded,
                color: player.isShuffle
                    ? V35Tokens.accent
                    : V35Tokens.textMuted,
                size: 24,
              ),
              onPressed: () {
                _onUserInteraction();
                player.toggleShuffle();
              },
            ),
            IconButton(
              icon: const Icon(
                Icons.skip_previous_rounded,
                color: V35Tokens.textPrimary,
                size: 36,
              ),
              onPressed: () {
                _onUserInteraction();
                player.previous();
              },
            ),
            GestureDetector(
              onTap: () {
                _onUserInteraction();
                player.togglePlayPause();
              },
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: V35Tokens.accent,
                ),
                child: Icon(
                  player.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.black,
                  size: 36,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.skip_next_rounded,
                color: V35Tokens.textPrimary,
                size: 36,
              ),
              onPressed: () {
                _onUserInteraction();
                player.next();
              },
            ),
            IconButton(
              icon: Icon(
                player.repeatMode == AppRepeatMode.one
                    ? Icons.repeat_one_rounded
                    : Icons.repeat_rounded,
                color: player.repeatMode != AppRepeatMode.off
                    ? V35Tokens.accent
                    : V35Tokens.textMuted,
                size: 24,
              ),
              onPressed: () {
                _onUserInteraction();
                player.toggleRepeat();
              },
            ),
          ],
        ),
      ],
    );
  }
}
