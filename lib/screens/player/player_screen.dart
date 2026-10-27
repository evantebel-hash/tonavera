import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/v35_tokens.dart';
import '../../core/theme/v35_accent.dart';
import '../../models/song_model.dart';
import '../../providers/player_provider.dart';
import '../../widgets/app_image.dart';
import '../../widgets/rotating_album_cover.dart';
import '../../widgets/lyrics/lyrics_view.dart';
import '../../widgets/now_playing/dynamic_background.dart';
import '../../widgets/now_playing/audio_visualizer.dart';
import '../../widgets/now_playing/waveform_seek_bar.dart';
import '../../widgets/v35/v35_scrubber.dart';
import '../../widgets/v35/v35_play_toggle_circle.dart';
import '../../widgets/v35/v35_queue_panel.dart';
import 'fullscreen_now_playing_screen.dart';
import '../lyrics/lyrics_screen.dart';
import '../../widgets/dialogs/equalizer_dialog.dart';
import '../../widgets/dialogs/sleep_timer_dialog.dart';
import '../../widgets/dialogs/crossfade_dialog.dart';
import '../../widgets/dialogs/playback_speed_dialog.dart';

/// V3.5 Obsidian Emerald Now Playing Studio.
///
/// Features:
/// - Desktop: Responsive two-column studio layout (Controls + Live Lyrics)
/// - Mobile: Single-column playback with seamless lyrics toggle
/// - Obsidian dark surfaces with Emerald accents
/// - Responsive square artwork with safe clamping and zero overflow
/// - Waveform seek bar support with fallback to V35Scrubber
/// - V35PlayToggleCircle with resolving state support
/// - Preserves 100% of player logic, repeat modes, queue, and lyrics synchronization.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  /// Static helper to display the repeat mode options sheet.
  /// Called from both [PlayerScreen] and [MiniPlayer].
  static void showRepeatOptionsSheet(
    BuildContext context,
    PlayerProvider player,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: V35Tokens.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(V35Tokens.radiusXl),
        ),
      ),
      builder: (sheetContext) {
        return Consumer<PlayerProvider>(
          builder: (context, p, child) {
            final mode = p.repeatMode;
            final count = p.targetRepeatCount;

            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheetContext).size.height * 0.85,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: V35Tokens.space16,
                    horizontal: V35Tokens.space20,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          margin: const EdgeInsets.only(
                            bottom: V35Tokens.space16,
                          ),
                          decoration: BoxDecoration(
                            color: V35Tokens.borderSubtle,
                            borderRadius: V35Tokens.brFull,
                          ),
                        ),
                      ),
                      Text(
                        'Mode Pengulangan (Repeat)',
                        style: V35Tokens.title.copyWith(
                          color: V35Tokens.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: V35Tokens.space12),
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            _buildRepeatOptionTile(
                              sheetContext: sheetContext,
                              title: 'Off',
                              subtitle: 'Tidak ada pengulangan',
                              isSelected: mode == AppRepeatMode.off,
                              onTap: () => p.setRepeatMode(AppRepeatMode.off),
                            ),
                            _buildRepeatOptionTile(
                              sheetContext: sheetContext,
                              title: 'Repeat Song (Ulang 1 Lagu)',
                              subtitle: 'Ulangi lagu saat ini tanpa batas',
                              isSelected: mode == AppRepeatMode.one,
                              onTap: () => p.setRepeatMode(AppRepeatMode.one),
                            ),
                            for (final cnt in [1, 2, 3, 5, 10])
                              _buildRepeatOptionTile(
                                sheetContext: sheetContext,
                                title: '$cnt×',
                                subtitle:
                                    'Putar lagu saat ini sebanyak $cnt kali',
                                isSelected:
                                    mode == AppRepeatMode.count && count == cnt,
                                onTap: () => p.setRepeatMode(
                                  AppRepeatMode.count,
                                  count: cnt,
                                ),
                              ),
                            _buildRepeatOptionTile(
                              sheetContext: sheetContext,
                              title: 'Forever (∞)',
                              subtitle:
                                  'Ulangi seluruh antrean / lagu tanpa batas',
                              isSelected: mode == AppRepeatMode.forever,
                              onTap: () =>
                                  p.setRepeatMode(AppRepeatMode.forever),
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
      },
    );
  }

  static Widget _buildRepeatOptionTile({
    required BuildContext sheetContext,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3.0),
      decoration: BoxDecoration(
        color: isSelected
            ? V35Tokens.accentDeep.withValues(alpha: 0.16)
            : Colors.transparent,
        borderRadius: V35Tokens.brMd,
        border: Border.all(
          color: isSelected
              ? V35Tokens.accent.withValues(alpha: 0.35)
              : Colors.transparent,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: V35Tokens.space12,
        ),
        dense: true,
        title: Text(
          title,
          style: V35Tokens.body.copyWith(
            color: isSelected ? V35Tokens.accent : V35Tokens.textPrimary,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: V35Tokens.secondary.copyWith(
            color: V35Tokens.textMuted,
            fontSize: 12.0,
          ),
        ),
        trailing: isSelected
            ? Icon(Icons.check_rounded, color: V35Tokens.accent, size: 20)
            : null,
        onTap: () {
          onTap();
          Navigator.pop(sheetContext);
        },
      ),
    );
  }

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with SingleTickerProviderStateMixin {
  bool _showLyrics = false;
  bool _useVinylRecordCover = true;
  int _studioTabIndex = 0; // 0: Lyrics, 1: Queue, 2: Audio Info

  String _formatDuration(Duration d) {
    final mins = d.inMinutes;
    final secs = d.inSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _showQueueSheet(BuildContext context) {
    V35QueuePanel.showBottomSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<V35AccentPalette>(
      valueListenable: V35Accent.notifier,
      builder: (context, accentPalette, child) {
        final player = Provider.of<PlayerProvider>(context);
        final song = player.currentSong;

        if (song == null) {
          return Scaffold(
            backgroundColor: V35Tokens.bgVoid,
            appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
            body: Center(
              child: Text(
                'Tidak ada lagu yang sedang diputar',
                style: V35Tokens.body.copyWith(color: V35Tokens.textMuted),
              ),
            ),
          );
        }

        final isWideScreen = MediaQuery.of(context).size.width >= 800;

        return Scaffold(
          backgroundColor: V35Tokens.bgVoid,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 30,
                color: V35Tokens.textPrimary,
              ),
              splashRadius: 22,
              tooltip: 'Tutup Player',
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'NOW PLAYING',
                  style: V35Tokens.mono.copyWith(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: V35Tokens.accent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isWideScreen
                      ? 'Studio Session'
                      : (_showLyrics
                            ? 'Lirik Lagu'
                            : (song.albumTitle ?? 'Single')),
                  style: V35Tokens.secondary.copyWith(
                    fontSize: 12.0,
                    color: V35Tokens.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            centerTitle: true,
            actions: [
              // Fullscreen Toggle
              IconButton(
                icon: const Icon(
                  Icons.fullscreen_rounded,
                  color: V35Tokens.textSecondary,
                  size: 22,
                ),
                tooltip: 'Layar Penuh (Fullscreen)',
                splashRadius: 20,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const FullscreenNowPlayingScreen(),
                    ),
                  );
                },
              ),

              // Queue Button
              IconButton(
                icon: const Icon(
                  Icons.queue_music_rounded,
                  color: V35Tokens.textSecondary,
                  size: 22,
                ),
                tooltip: 'Antrean Putar',
                splashRadius: 20,
                onPressed: () => _showQueueSheet(context),
              ),

              // Mobile Lyrics View Toggle
              if (!isWideScreen)
                IconButton(
                  icon: Icon(
                    _showLyrics
                        ? Icons.music_note_rounded
                        : Icons.lyrics_outlined,
                    color: _showLyrics
                        ? V35Tokens.accent
                        : V35Tokens.textSecondary,
                    size: 22,
                  ),
                  tooltip: _showLyrics ? 'Tampilkan Player' : 'Tampilkan Lirik',
                  splashRadius: 20,
                  onPressed: () {
                    setState(() {
                      _showLyrics = !_showLyrics;
                    });
                  },
                ),

              // More Options Menu
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: V35Tokens.textSecondary,
                ),
                color: V35Tokens.bgElevated,
                shape: const RoundedRectangleBorder(
                  borderRadius: V35Tokens.brLg,
                  side: BorderSide(color: V35Tokens.borderSubtle),
                ),
                onSelected: (val) {
                  if (val == 'fullscreen') {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const FullscreenNowPlayingScreen(),
                      ),
                    );
                  } else if (val == 'lyrics_fullscreen') {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LyricsScreen(song: song),
                      ),
                    );
                  } else if (val == 'vinyl_cover') {
                    setState(() {
                      _useVinylRecordCover = !_useVinylRecordCover;
                    });
                  } else if (val == 'dynamic_bg') {
                    player.setDynamicBackgroundEnabled(
                      !player.dynamicBackgroundEnabled,
                    );
                  } else if (val == 'visualizer') {
                    player.setVisualizerEnabled(!player.visualizerEnabled);
                  } else if (val == 'waveform') {
                    player.setWaveformSeekEnabled(!player.waveformSeekEnabled);
                  } else if (val == 'eq') {
                    EqualizerDialog.show(context);
                  } else if (val == 'speed') {
                    PlaybackSpeedDialog.show(context);
                  } else if (val == 'sleep') {
                    SleepTimerDialog.show(context);
                  } else if (val == 'crossfade') {
                    CrossfadeDialog.show(context);
                  } else if (val == 'gapless') {
                    player.setGaplessEnabled(!player.gaplessEnabled);
                  }
                },
                itemBuilder: (ctx) => [
                  _buildPopupMenuItem(
                    'fullscreen',
                    Icons.fullscreen_rounded,
                    'Layar Penuh (Fullscreen)',
                  ),
                  _buildPopupMenuItem(
                    'lyrics_fullscreen',
                    Icons.lyrics_rounded,
                    'Buka Lirik Penuh',
                  ),
                  _buildPopupMenuItem(
                    'vinyl_cover',
                    Icons.album_rounded,
                    'Vinyl Cover Mode (${_useVinylRecordCover ? "ON" : "OFF"})',
                  ),
                  _buildPopupMenuItem(
                    'dynamic_bg',
                    Icons.wallpaper_rounded,
                    'Dynamic Background (${player.dynamicBackgroundEnabled ? "ON" : "OFF"})',
                  ),
                  _buildPopupMenuItem(
                    'visualizer',
                    Icons.graphic_eq_rounded,
                    'Audio Visualizer (${player.visualizerEnabled ? "ON" : "OFF"})',
                  ),
                  _buildPopupMenuItem(
                    'waveform',
                    Icons.waves_rounded,
                    'Waveform Seek (${player.waveformSeekEnabled ? "ON" : "OFF"})',
                  ),
                  _buildPopupMenuItem(
                    'eq',
                    Icons.equalizer_rounded,
                    'Equalizer',
                  ),
                  _buildPopupMenuItem(
                    'speed',
                    Icons.speed_rounded,
                    'Kecepatan Putar (${player.playbackSpeed.toStringAsFixed(2)}x)',
                  ),
                  _buildPopupMenuItem(
                    'sleep',
                    Icons.timer_outlined,
                    'Sleep Timer',
                  ),
                  _buildPopupMenuItem(
                    'crossfade',
                    Icons.tune_rounded,
                    'Crossfade',
                  ),
                  _buildPopupMenuItem(
                    'gapless',
                    Icons.space_bar_rounded,
                    'Gapless Playback (${player.gaplessEnabled ? "ON" : "OFF"})',
                  ),
                ],
              ),
              const SizedBox(width: V35Tokens.space8),
            ],
          ),
          body: DynamicBackground(
            song: song,
            enabled: player.dynamicBackgroundEnabled,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: V35Tokens.space24,
                  vertical: V35Tokens.space12,
                ),
                child: isWideScreen
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Left Column: Hero Vinyl Record + Acoustic Pulse Visualizer
                          Expanded(
                            flex: 5,
                            child: _buildDesktopLeftHeroStage(
                              context,
                              player,
                              song,
                            ),
                          ),
                          const SizedBox(width: V35Tokens.space24),
                          Container(width: 1.0, color: V35Tokens.borderSubtle),
                          const SizedBox(width: V35Tokens.space24),
                          // Right Column: Metadata, Controls & Studio Tabbed Hub
                          Expanded(
                            flex: 6,
                            child: _buildDesktopRightStage(
                              context,
                              player,
                              song,
                            ),
                          ),
                        ],
                      )
                    : (_showLyrics
                          ? LyricsView(song: song)
                          : _buildPlayerContent(context, player, song)),
              ),
            ),
          ),
        );
      },
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem(
    String value,
    IconData icon,
    String text,
  ) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: V35Tokens.accent, size: 20),
          const SizedBox(width: V35Tokens.space12),
          Text(
            text,
            style: V35Tokens.body.copyWith(
              color: V35Tokens.textPrimary,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Desktop Left Hero Stage: Authentic Vinyl Record + Acoustic Pulse Visualizer.
  Widget _buildDesktopLeftHeroStage(
    BuildContext context,
    PlayerProvider player,
    SongModel song,
  ) {
    return Column(
      children: [
        // Hero Vinyl Record Area with Ambient Color Bloom
        Expanded(
          child: Center(
            child: _useVinylRecordCover
                ? RotatingAlbumCover(
                    imageUrl: song.cover,
                    isPlaying: player.isPlaying,
                  )
                : _buildStudioAlbumArt(song, player, 360.0),
          ),
        ),
        const SizedBox(height: V35Tokens.space16),

        // Acoustic Pulse Card (Matching V3.5 Specification)
        _buildAcousticPulseCard(player, song),
      ],
    );
  }

  /// Acoustic Pulse visualizer telemetry container.
  Widget _buildAcousticPulseCard(PlayerProvider player, SongModel song) {
    final isLocal = song.source.toLowerCase() == 'local';
    final subtitle = isLocal
        ? 'High-quality local playback'
        : 'Streaming audio stream';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: V35Tokens.space16,
        vertical: V35Tokens.space12,
      ),
      decoration: BoxDecoration(
        color: V35Tokens.bgSurface,
        borderRadius: V35Tokens.brLg,
        border: Border.all(color: V35Tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: player.isPlaying
                          ? V35Tokens.accent
                          : V35Tokens.textMuted,
                      boxShadow: player.isPlaying
                          ? [
                              BoxShadow(
                                color: V35Tokens.accent.withValues(alpha: 0.6),
                                blurRadius: 6,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Acoustic Pulse',
                    style: V35Tokens.body.copyWith(
                      color: V35Tokens.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
              Text(
                subtitle,
                style: V35Tokens.mono.copyWith(
                  color: V35Tokens.accent,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AudioVisualizer(
            isPlaying: player.isPlaying,
            songId: song.id.toString(),
            enabled: player.visualizerEnabled,
            accentColor: V35Tokens.accent,
            secondaryColor: V35Tokens.accentBright,
            height: 36.0,
          ),
        ],
      ),
    );
  }

  /// Desktop Right Stage: Metadata, Actions, Scrubber, Transport, and Studio Tab Hub.
  Widget _buildDesktopRightStage(
    BuildContext context,
    PlayerProvider player,
    SongModel song,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Context Eyebrow
        Text(
          'PLAYING FROM · ${(song.albumTitle ?? 'SINGLE').toUpperCase()}',
          style: V35Tokens.mono.copyWith(
            fontSize: 11.0,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: V35Tokens.accent,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),

        // 2. Track Title & Favorite Button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                song.title,
                style: V35Tokens.heading.copyWith(
                  fontSize: 26.0,
                  fontWeight: FontWeight.w800,
                  color: V35Tokens.textPrimary,
                  letterSpacing: -0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: Icon(
                song.isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: song.isFavorite ? V35Tokens.accent : V35Tokens.textMuted,
                size: 24,
              ),
              tooltip: song.isFavorite
                  ? 'Hapus dari Favorit'
                  : 'Tambah ke Favorit',
              onPressed: () => player.toggleFavorite(song),
            ),
          ],
        ),

        // 3. Artist • Album • Year
        Row(
          children: [
            Flexible(
              child: Text(
                song.artistName ?? 'Unknown Artist',
                style: V35Tokens.body.copyWith(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: V35Tokens.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (song.albumTitle != null && song.albumTitle!.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6.0),
                child: Text(
                  '•',
                  style: TextStyle(color: V35Tokens.borderSubtle),
                ),
              ),
              Flexible(
                child: Text(
                  song.albumTitle!,
                  style: V35Tokens.secondary.copyWith(
                    fontSize: 13.5,
                    color: V35Tokens.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            if (song.genreName != null && song.genreName!.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6.0),
                child: Text(
                  '•',
                  style: TextStyle(color: V35Tokens.borderSubtle),
                ),
              ),
              Text(
                song.genreName!,
                style: V35Tokens.secondary.copyWith(
                  fontSize: 12.0,
                  color: V35Tokens.textMuted,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),

        // 4. Metadata & Format Chips
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _buildFormatChip(song),
            _buildSourcePill(song.source),
            _buildAudioQualityChip(song),
          ],
        ),
        const SizedBox(height: 14),

        // 5. Scrubber & Timestamps
        if (player.waveformSeekEnabled)
          WaveformSeekBar(
            songId: song.id.toString(),
            filePath: song.filePath,
            position: player.position,
            duration: player.duration,
            onSeek: (dur) => player.seek(dur),
            playedColor: V35Tokens.accent,
            remainingColor: V35Tokens.borderSubtle,
            height: 36.0,
          )
        else
          V35Scrubber(
            value: player.position.inSeconds.toDouble(),
            max: player.duration.inSeconds.toDouble() > 0
                ? player.duration.inSeconds.toDouble()
                : 1.0,
            onChanged: (val) {
              player.seek(Duration(seconds: val.toInt()));
            },
          ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatDuration(player.position),
              style: V35Tokens.mono.copyWith(
                color: V35Tokens.textMuted,
                fontSize: 11.5,
              ),
            ),
            Text(
              _formatDuration(player.duration),
              style: V35Tokens.mono.copyWith(
                color: V35Tokens.textMuted,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 6. Playback Media Controls
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Shuffle Button
            IconButton(
              icon: Icon(
                Icons.shuffle_rounded,
                color: player.isShuffle
                    ? V35Tokens.accent
                    : V35Tokens.textMuted,
                size: 22,
              ),
              tooltip: player.isShuffle ? 'Acak: Aktif' : 'Acak: Nonaktif',
              splashRadius: 20,
              onPressed: () => player.toggleShuffle(),
            ),

            // Previous Button
            IconButton(
              icon: const Icon(
                Icons.skip_previous_rounded,
                size: 34,
                color: V35Tokens.textPrimary,
              ),
              tooltip: 'Lagu Sebelumnya',
              splashRadius: 22,
              onPressed: () => player.previous(),
            ),

            // Play / Pause Circle
            V35PlayToggleCircle(
              isPlaying: player.isPlaying,
              isLoading: player.isLoadingAudio,
              onToggle: () => player.togglePlayPause(),
              size: V35PlayButtonSize.lg,
              variant: V35PlayButtonVariant.primary,
            ),

            // Next Button
            IconButton(
              icon: const Icon(
                Icons.skip_next_rounded,
                size: 34,
                color: V35Tokens.textPrimary,
              ),
              tooltip: 'Lagu Berikutnya',
              splashRadius: 22,
              onPressed: () => player.next(),
            ),

            // Repeat Button
            _buildRepeatButton(context, player),
          ],
        ),
        const SizedBox(height: 14),

        // 7. Studio Hub Tab Bar
        _buildStudioTabBar(player),
        const SizedBox(height: 8),

        // 8. Studio Hub Body (Lyrics / Queue / Audio Info)
        Expanded(child: _buildStudioTabBody(context, player, song)),
      ],
    );
  }

  /// Studio Hub tab bar header.
  Widget _buildStudioTabBar(PlayerProvider player) {
    return Container(
      padding: const EdgeInsets.all(3.5),
      decoration: BoxDecoration(
        color: V35Tokens.bgSurface,
        borderRadius: V35Tokens.brLg,
        border: Border.all(color: V35Tokens.borderSubtle),
      ),
      child: Row(
        children: [
          _buildStudioTabItem(
            index: 0,
            icon: Icons.lyrics_rounded,
            label: 'Lirik Lagu',
          ),
          _buildStudioTabItem(
            index: 1,
            icon: Icons.queue_music_rounded,
            label: 'Antrean (${player.queue.length})',
          ),
          _buildStudioTabItem(
            index: 2,
            icon: Icons.info_outline_rounded,
            label: 'Info Audio',
          ),
        ],
      ),
    );
  }

  Widget _buildStudioTabItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _studioTabIndex == index;
    return Expanded(
      child: InkWell(
        borderRadius: V35Tokens.brMd,
        onTap: () => setState(() => _studioTabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 7.0, horizontal: 8.0),
          decoration: BoxDecoration(
            color: isSelected
                ? V35Tokens.accentDeep.withValues(alpha: 0.22)
                : Colors.transparent,
            borderRadius: V35Tokens.brMd,
            border: Border.all(
              color: isSelected
                  ? V35Tokens.accent.withValues(alpha: 0.35)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? V35Tokens.accent : V35Tokens.textMuted,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: V35Tokens.body.copyWith(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? V35Tokens.accent : V35Tokens.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Studio Hub tab body switcher.
  Widget _buildStudioTabBody(
    BuildContext context,
    PlayerProvider player,
    SongModel song,
  ) {
    if (_studioTabIndex == 0) {
      // Synchronized Lyrics View
      return Container(
        decoration: BoxDecoration(
          color: V35Tokens.bgSurface.withValues(alpha: 0.5),
          borderRadius: V35Tokens.brXl,
          border: Border.all(color: V35Tokens.borderSubtle),
        ),
        clipBehavior: Clip.antiAlias,
        child: LyricsView(song: song),
      );
    } else if (_studioTabIndex == 1) {
      // Embedded Up Next Queue Tab
      return _buildStudioQueueTab(context, player, song);
    } else {
      // Audio Telemetry Info Tab
      return _buildStudioAudioInfoTab(context, player, song);
    }
  }

  /// In-place Up Next Queue list inside Studio Hub.
  Widget _buildStudioQueueTab(
    BuildContext context,
    PlayerProvider player,
    SongModel song,
  ) {
    final queue = player.queue;
    final currentIndex = player.currentIndex;

    if (queue.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: V35Tokens.bgSurface,
          borderRadius: V35Tokens.brXl,
          border: Border.all(color: V35Tokens.borderSubtle),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.queue_music_rounded,
              size: 40,
              color: V35Tokens.textMuted,
            ),
            const SizedBox(height: 8),
            Text(
              'Antrean Putar Kosong',
              style: V35Tokens.body.copyWith(color: V35Tokens.textSecondary),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: V35Tokens.bgSurface.withValues(alpha: 0.7),
        borderRadius: V35Tokens.brXl,
        border: Border.all(color: V35Tokens.borderSubtle),
      ),
      child: Column(
        children: [
          // Queue Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'UP NEXT (${queue.length})',
                style: V35Tokens.mono.copyWith(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: V35Tokens.textMuted,
                ),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () => player.clearQueue(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(
                      'Bersihkan',
                      style: V35Tokens.secondary.copyWith(
                        color: V35Tokens.textMuted,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    color: V35Tokens.textSecondary,
                    tooltip: 'Buka Panel Antrean Penuh',
                    onPressed: () => _showQueueSheet(context),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 1, color: V35Tokens.borderSubtle),
          const SizedBox(height: 6),

          // Scrollable Queue Items
          Expanded(
            child: ListView.separated(
              itemCount: queue.length,
              separatorBuilder: (context, index) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final item = queue[index];
                final isCurrent = index == currentIndex;

                return InkWell(
                  borderRadius: V35Tokens.brMd,
                  onTap: () => player.playQueueIndex(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? V35Tokens.accentDeep.withValues(alpha: 0.22)
                          : Colors.transparent,
                      borderRadius: V35Tokens.brMd,
                      border: Border.all(
                        color: isCurrent
                            ? V35Tokens.accent.withValues(alpha: 0.35)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Track Number or Indicator
                        SizedBox(
                          width: 24,
                          child: isCurrent
                              ? Icon(
                                  Icons.graphic_eq_rounded,
                                  size: 16,
                                  color: V35Tokens.accent,
                                )
                              : Text(
                                  (index + 1).toString().padLeft(2, '0'),
                                  style: V35Tokens.mono.copyWith(
                                    fontSize: 10.5,
                                    color: V35Tokens.textMuted,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 8),

                        // Artwork Thumbnail
                        ClipRRect(
                          borderRadius: V35Tokens.brSm,
                          child: SizedBox(
                            width: 32,
                            height: 32,
                            child: AppImage(
                              imagePath: item.cover,
                              fit: BoxFit.cover,
                              defaultIcon: Icons.music_note_rounded,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Title & Artist
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: V35Tokens.body.copyWith(
                                  fontSize: 12.5,
                                  fontWeight: isCurrent
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isCurrent
                                      ? V35Tokens.accent
                                      : V35Tokens.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                item.artistName ?? 'Unknown Artist',
                                style: V35Tokens.secondary.copyWith(
                                  fontSize: 11.0,
                                  color: V35Tokens.textMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        // Remove from queue button
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16),
                          color: V35Tokens.textMuted,
                          tooltip: 'Hapus dari Antrean',
                          splashRadius: 16,
                          onPressed: () => player.removeFromQueue(index),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Audio Telemetry Info Tab in Studio Hub.
  Widget _buildStudioAudioInfoTab(
    BuildContext context,
    PlayerProvider player,
    SongModel song,
  ) {
    final normSource = song.source.toLowerCase();
    final ext = (song.filePath != null && song.filePath!.contains('.'))
        ? song.filePath!.split('.').last.toUpperCase()
        : (normSource == 'local' ? 'FLAC' : 'OPUS / AAC');

    return Container(
      padding: const EdgeInsets.all(V35Tokens.space16),
      decoration: BoxDecoration(
        color: V35Tokens.bgSurface,
        borderRadius: V35Tokens.brXl,
        border: Border.all(color: V35Tokens.borderSubtle),
      ),
      child: ListView(
        children: [
          Text(
            'SPESIFIKASI AUDIO & TELEMETRI',
            style: V35Tokens.mono.copyWith(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: V35Tokens.accent,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Format Berkas', ext),
          _buildInfoRow(
            'Resolusi Audio',
            ext == 'FLAC'
                ? '24-bit / 96.0 kHz Lossless'
                : '16-bit / 44.1 kHz Stereo',
          ),
          _buildInfoRow('Saluran (Channels)', '2.0 Stereo'),
          _buildInfoRow('Sumber Lagu', song.source.toUpperCase()),
          _buildInfoRow('Durasi Total', _formatDuration(player.duration)),
          _buildInfoRow('Posisi Putar', _formatDuration(player.position)),
          if (song.filePath != null)
            _buildInfoRow('Lokasi Berkas', song.filePath!, isPath: true),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isPath = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: V35Tokens.secondary.copyWith(
                color: V35Tokens.textMuted,
                fontSize: 12.0,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: (isPath ? V35Tokens.mono : V35Tokens.body).copyWith(
                color: V35Tokens.textPrimary,
                fontSize: isPath ? 11.0 : 12.5,
                fontWeight: isPath ? FontWeight.normal : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatChip(SongModel song) {
    String label = 'LOSSLESS';
    if (song.filePath != null) {
      final p = song.filePath!.toLowerCase();
      if (p.endsWith('.flac')) {
        label = 'FLAC LOSSLESS';
      } else if (p.endsWith('.wav')) {
        label = 'WAV LOSSLESS';
      } else if (p.endsWith('.mp3')) {
        label = 'MP3 320 KBPS';
      } else if (p.endsWith('.m4a') || p.endsWith('.aac')) {
        label = 'AAC HIGH-RES';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7.5, vertical: 3.5),
      decoration: BoxDecoration(
        color: V35Tokens.bgSurface,
        borderRadius: V35Tokens.brSm,
        border: Border.all(color: V35Tokens.borderSubtle),
      ),
      child: Text(
        label,
        style: V35Tokens.mono.copyWith(
          color: V35Tokens.accent,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildAudioQualityChip(SongModel song) {
    final isFlac = song.filePath?.toLowerCase().endsWith('.flac') ?? false;
    final label = isFlac ? '24-bit / 96 kHz' : '44.1 kHz';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7.5, vertical: 3.5),
      decoration: BoxDecoration(
        color: V35Tokens.bgSurface,
        borderRadius: V35Tokens.brSm,
        border: Border.all(color: V35Tokens.borderSubtle),
      ),
      child: Text(
        label,
        style: V35Tokens.mono.copyWith(
          color: V35Tokens.textMuted,
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Mobile / Compact layout fallback.
  Widget _buildPlayerContent(
    BuildContext context,
    PlayerProvider player,
    SongModel song,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final rawArtSize = availableHeight - 270.0;
        final clampedArtSize = rawArtSize.clamp(140.0, 360.0);

        return Column(
          children: [
            const Spacer(),

            // Studio Artwork / Vinyl Record
            Center(
              child: _useVinylRecordCover
                  ? SizedBox(
                      width: clampedArtSize,
                      height: clampedArtSize,
                      child: RotatingAlbumCover(
                        imageUrl: song.cover,
                        isPlaying: player.isPlaying,
                      ),
                    )
                  : _buildStudioAlbumArt(song, player, clampedArtSize),
            ),

            if (player.visualizerEnabled)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: V35Tokens.space16,
                  vertical: V35Tokens.space8,
                ),
                child: AudioVisualizer(
                  isPlaying: player.isPlaying,
                  songId: song.id.toString(),
                  enabled: player.visualizerEnabled,
                  height: 32.0,
                ),
              )
            else
              const Spacer(),

            // Title & Favorite
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: V35Tokens.heading.copyWith(
                          fontSize: 22.0,
                          fontWeight: FontWeight.w700,
                          color: V35Tokens.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              song.artistName ?? 'Unknown Artist',
                              style: V35Tokens.body.copyWith(
                                fontSize: 14.5,
                                color: V35Tokens.textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: V35Tokens.space8),
                          _buildSourcePill(song.source),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    song.isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: song.isFavorite
                        ? V35Tokens.accent
                        : V35Tokens.textMuted,
                    size: 26,
                  ),
                  tooltip: song.isFavorite
                      ? 'Hapus dari Favorit'
                      : 'Tambah ke Favorit',
                  onPressed: () => player.toggleFavorite(song),
                ),
              ],
            ),
            const SizedBox(height: V35Tokens.space16),

            // Progress
            if (player.waveformSeekEnabled)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: WaveformSeekBar(
                  songId: song.id.toString(),
                  filePath: song.filePath,
                  position: player.position,
                  duration: player.duration,
                  onSeek: (dur) => player.seek(dur),
                  playedColor: V35Tokens.accent,
                  remainingColor: V35Tokens.borderSubtle,
                  height: 40.0,
                ),
              )
            else
              V35Scrubber(
                value: player.position.inSeconds.toDouble(),
                max: player.duration.inSeconds.toDouble() > 0
                    ? player.duration.inSeconds.toDouble()
                    : 1.0,
                onChanged: (val) {
                  player.seek(Duration(seconds: val.toInt()));
                },
              ),

            // Timestamps
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: V35Tokens.space4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(player.position),
                    style: V35Tokens.mono.copyWith(
                      color: V35Tokens.textMuted,
                      fontSize: 11.5,
                    ),
                  ),
                  Text(
                    _formatDuration(player.duration),
                    style: V35Tokens.mono.copyWith(
                      color: V35Tokens.textMuted,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: V35Tokens.space16),

            // Media Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.shuffle_rounded,
                    color: player.isShuffle
                        ? V35Tokens.accent
                        : V35Tokens.textMuted,
                    size: 22,
                  ),
                  tooltip: player.isShuffle ? 'Acak: Aktif' : 'Acak: Nonaktif',
                  splashRadius: 20,
                  onPressed: () => player.toggleShuffle(),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.skip_previous_rounded,
                    size: 36,
                    color: V35Tokens.textPrimary,
                  ),
                  tooltip: 'Lagu Sebelumnya',
                  splashRadius: 24,
                  onPressed: () => player.previous(),
                ),
                V35PlayToggleCircle(
                  isPlaying: player.isPlaying,
                  isLoading: player.isLoadingAudio,
                  onToggle: () => player.togglePlayPause(),
                  size: V35PlayButtonSize.lg,
                  variant: V35PlayButtonVariant.primary,
                ),
                IconButton(
                  icon: const Icon(
                    Icons.skip_next_rounded,
                    size: 36,
                    color: V35Tokens.textPrimary,
                  ),
                  tooltip: 'Lagu Berikutnya',
                  splashRadius: 24,
                  onPressed: () => player.next(),
                ),
                _buildRepeatButton(context, player),
              ],
            ),
            const SizedBox(height: V35Tokens.space20),
          ],
        );
      },
    );
  }

  Widget _buildStudioAlbumArt(
    SongModel song,
    PlayerProvider player,
    double size,
  ) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: V35Tokens.bgSurface,
        borderRadius: V35Tokens.brXl,
        border: Border.all(
          color: player.isPlaying
              ? V35Tokens.accent.withValues(alpha: 0.28)
              : V35Tokens.borderSubtle,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: player.isPlaying
                ? V35Tokens.accent.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.4),
            blurRadius: 28,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: V35Tokens.brXl,
        child: AspectRatio(
          aspectRatio: 1.0,
          child: AppImage(
            imagePath: song.cover,
            width: size,
            height: size,
            fit: BoxFit.cover,
            defaultIcon: Icons.music_note_rounded,
          ),
        ),
      ),
    );
  }

  Widget _buildSourcePill(String source) {
    String label;
    Color color;

    final normSource = source.toLowerCase();
    if (normSource == 'youtube') {
      label = 'YOUTUBE';
      color = const Color(0xFFEF4444); // Red
    } else if (normSource == 'spotify') {
      label = 'SPOTIFY';
      color = const Color(0xFF10B981); // Emerald Green
    } else if (normSource == 'local') {
      label = 'LOCAL';
      color = const Color(0xFF14B8A6); // Teal
    } else {
      label = 'CATALOG';
      color = V35Tokens.textMuted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2.0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: V35Tokens.brSm,
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Text(
        label,
        style: V35Tokens.mono.copyWith(
          color: color,
          fontSize: 9.0,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildRepeatButton(BuildContext context, PlayerProvider player) {
    final mode = player.repeatMode;

    Widget iconWidget;
    if (mode == AppRepeatMode.off) {
      iconWidget = const Icon(
        Icons.repeat_rounded,
        color: V35Tokens.textMuted,
        size: 22,
      );
    } else if (mode == AppRepeatMode.one) {
      iconWidget = Icon(
        Icons.repeat_one_rounded,
        color: V35Tokens.accent,
        size: 22,
      );
    } else if (mode == AppRepeatMode.forever) {
      iconWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.repeat_rounded, color: V35Tokens.accent, size: 20),
          const SizedBox(width: 1),
          Text(
            '∞',
            style: V35Tokens.mono.copyWith(
              color: V35Tokens.accent,
              fontSize: 12.0,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    } else {
      // Repeat count mode
      final remaining = player.remainingRepeatCount;
      final displayVal = remaining > 0 ? remaining : player.targetRepeatCount;
      iconWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.repeat_rounded, color: V35Tokens.accent, size: 20),
          const SizedBox(width: 1),
          Text(
            '${displayVal}x',
            style: V35Tokens.mono.copyWith(
              color: V35Tokens.accent,
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }

    return IconButton(
      icon: iconWidget,
      onPressed: () => PlayerScreen.showRepeatOptionsSheet(context, player),
      tooltip: 'Pilih Mode Repeat',
      splashRadius: 20,
    );
  }
}
