import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/v35_tokens.dart';
import '../core/theme/v35_accent.dart';
import '../providers/player_provider.dart';
import '../screens/player/player_screen.dart';
import '../services/desktop/desktop_integration_service.dart';
import 'app_image.dart';
import 'v35/v35_play_toggle_circle.dart';
import 'v35/v35_scrubber.dart';
import 'v35/v35_queue_panel.dart';

/// Reusable Mini Player widget for MyMusic V3.5 Obsidian Emerald design system.
///
/// Fully responsive:
/// - Desktop (>= 800px): Persistent docked playbar with left track info,
///   center controls & scrubber, and right volume & utilities.
/// - Mobile (< 800px): Compact floating bar with thin emerald progress line,
///   essential playback controls, and tap-to-open Now Playing.
///
/// Protected: Zero playback engine/state modification. Reuses PlayerProvider directly.
class MiniPlayer extends StatelessWidget {
  final VoidCallback? onQueueTap;
  final bool isQueueOpen;

  const MiniPlayer({super.key, this.onQueueTap, this.isQueueOpen = false});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<V35AccentPalette>(
      valueListenable: V35Accent.notifier,
      builder: (context, accentPalette, child) {
        return Consumer<PlayerProvider>(
          builder: (context, player, child) {
            final song = player.currentSong;
            if (song == null) return const SizedBox.shrink();

            final screenWidth = MediaQuery.of(context).size.width;
            final isDesktop = screenWidth >= V35Tokens.tabletBreakPoint;

            if (isDesktop) {
              return _buildDesktopPlaybar(context, player, song);
            } else {
              return _buildMobileMiniPlayer(context, player, song, screenWidth);
            }
          },
        );
      },
    );
  }

  // ===========================================================================
  // DESKTOP PLAYBAR (3-CLUSTER DOCKED BAR: HEIGHT 84PX)
  // ===========================================================================
  Widget _buildDesktopPlaybar(
    BuildContext context,
    PlayerProvider player,
    dynamic song,
  ) {
    return Container(
      height: V35Tokens.desktopPlaybarHeight,
      decoration: const BoxDecoration(
        color: V35Tokens.bgSurface,
        border: Border(
          top: BorderSide(color: V35Tokens.borderSubtle, width: 1.0),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: V35Tokens.space16),
      child: Row(
        children: [
          // 1. LEFT CLUSTER: Track Artwork & Metadata
          SizedBox(
            width: 240,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PlayerScreen()),
                  );
                },
                borderRadius: V35Tokens.brMd,
                hoverColor: V35Tokens.bgElevated.withValues(alpha: 0.5),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: V35Tokens.space8,
                    vertical: V35Tokens.space4,
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: V35Tokens.brMd,
                        child: SizedBox(
                          width: 52,
                          height: 52,
                          child: AppImage(
                            imagePath: song.cover,
                            width: 52,
                            height: 52,
                            defaultIcon: Icons.music_note_rounded,
                          ),
                        ),
                      ),
                      const SizedBox(width: V35Tokens.space12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              style: V35Tokens.body.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    song.artistName ?? 'Unknown Artist',
                                    style: V35Tokens.secondary.copyWith(
                                      fontSize: 12.0,
                                      color: V35Tokens.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (player.isSleepTimerActive)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: Icon(
                                      Icons.timer_outlined,
                                      size: 13,
                                      color: V35Tokens.accent,
                                    ),
                                  ),
                                if (player.equalizerEnabled)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: Icon(
                                      Icons.equalizer_rounded,
                                      size: 13,
                                      color: V35Tokens.accent,
                                    ),
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
            ),
          ),

          // 2. CENTER CLUSTER: Controls & Scrubber (Flexible)
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Playback Controls Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.shuffle_rounded,
                            size: 18,
                            color: player.isShuffle
                                ? V35Tokens.accent
                                : V35Tokens.textMuted,
                          ),
                          tooltip: 'Shuffle',
                          onPressed: () => player.toggleShuffle(),
                        ),
                        const SizedBox(width: V35Tokens.space4),
                        IconButton(
                          icon: const Icon(
                            Icons.skip_previous_rounded,
                            size: 22,
                            color: V35Tokens.textPrimary,
                          ),
                          tooltip: 'Sebelumnya (Previous)',
                          onPressed: () => player.previous(),
                        ),
                        const SizedBox(width: V35Tokens.space8),
                        V35PlayToggleCircle(
                          isPlaying: player.isPlaying,
                          isLoading: player.isLoadingAudio,
                          size: V35PlayButtonSize.sm,
                          onToggle: () => player.togglePlayPause(),
                          tooltip: player.isPlaying ? 'Jeda' : 'Putar',
                        ),
                        const SizedBox(width: V35Tokens.space8),
                        IconButton(
                          icon: const Icon(
                            Icons.skip_next_rounded,
                            size: 22,
                            color: V35Tokens.textPrimary,
                          ),
                          tooltip: 'Berikutnya (Next)',
                          onPressed: () => player.next(),
                        ),
                        const SizedBox(width: V35Tokens.space4),
                        _buildMiniRepeatButton(context, player),
                      ],
                    ),

                    // Interactive Scrubber with inline times
                    V35Scrubber(
                      value: player.position.inSeconds.toDouble(),
                      max: player.duration.inSeconds > 0
                          ? player.duration.inSeconds.toDouble()
                          : 1.0,
                      isCompact: true,
                      showTimeLabels: true,
                      enabled: player.duration.inSeconds > 0,
                      onChangeEnd: (val) {
                        player.seek(Duration(seconds: val.round()));
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. RIGHT CLUSTER: Volume & Utilities
          SizedBox(
            width: 240,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Volume Controls
                IconButton(
                  icon: Icon(
                    player.isMuted
                        ? Icons.volume_off_rounded
                        : (player.volume > 0.5
                              ? Icons.volume_up_rounded
                              : Icons.volume_down_rounded),
                    size: 18,
                    color: player.isMuted
                        ? V35Tokens.textMuted
                        : V35Tokens.textSecondary,
                  ),
                  tooltip: player.isMuted ? 'Unmute' : 'Mute',
                  onPressed: () => player.toggleMute(),
                ),
                SizedBox(
                  width: 76,
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 2.5,
                      activeTrackColor: V35Tokens.accent,
                      inactiveTrackColor: V35Tokens.borderSubtle,
                      thumbColor: V35Tokens.textPrimary,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 4.5,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 10.0,
                      ),
                    ),
                    child: Slider(
                      value: player.isMuted
                          ? 0.0
                          : player.volume.clamp(0.0, 1.0),
                      onChanged: (v) => player.setVolume(v),
                    ),
                  ),
                ),

                // Windows Picture-in-Picture Mini Player Mode
                if (!kIsWeb && Platform.isWindows)
                  ValueListenableBuilder<bool>(
                    valueListenable:
                        DesktopIntegrationService.instance.miniPlayerNotifier,
                    builder: (context, isMini, _) {
                      return IconButton(
                        icon: const Icon(
                          Icons.picture_in_picture_alt_rounded,
                          size: 18,
                        ),
                        color: isMini
                            ? V35Tokens.accent
                            : V35Tokens.textSecondary,
                        tooltip: isMini
                            ? 'Sembunyikan Mini Player Melayang'
                            : 'Buka Mini Player Melayang',
                        onPressed: () {
                          DesktopIntegrationService.instance.setMiniPlayerMode(
                            !isMini,
                          );
                        },
                      );
                    },
                  ),

                // Queue / Full Screen Player Toggle
                IconButton(
                  icon: Icon(
                    Icons.queue_music_rounded,
                    size: 20,
                    color: isQueueOpen
                        ? V35Tokens.accent
                        : V35Tokens.textSecondary,
                  ),
                  tooltip: isQueueOpen ? 'Tutup Antrean' : 'Buka Antrean',
                  onPressed:
                      onQueueTap ??
                      () {
                        V35QueuePanel.showBottomSheet(context);
                      },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // MOBILE MINI PLAYER (COMPACT TOUCH BAR: HEIGHT 64PX)
  // ===========================================================================
  Widget _buildMobileMiniPlayer(
    BuildContext context,
    PlayerProvider player,
    dynamic song,
    double screenWidth,
  ) {
    final progress = player.duration.inMilliseconds > 0
        ? player.position.inMilliseconds / player.duration.inMilliseconds
        : 0.0;

    return Container(
      height: V35Tokens.mobileMiniPlayerHeight,
      decoration: const BoxDecoration(
        color: V35Tokens.bgElevated,
        border: Border(
          top: BorderSide(color: V35Tokens.borderSubtle, width: 1.0),
        ),
      ),
      child: Column(
        children: [
          // Linear progress bar at top of mobile mini player
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: Colors.transparent,
            color: V35Tokens.accent,
            minHeight: 2.0,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: V35Tokens.space12,
              ),
              child: Row(
                children: [
                  // Tap area for Artwork + Title + Artist to open Now Playing
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PlayerScreen(),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: V35Tokens.brSm,
                            child: SizedBox(
                              width: 42,
                              height: 42,
                              child: AppImage(
                                imagePath: song.cover,
                                width: 42,
                                height: 42,
                                defaultIcon: Icons.music_note_rounded,
                              ),
                            ),
                          ),
                          const SizedBox(width: V35Tokens.space12),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  song.title,
                                  style: V35Tokens.body.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.0,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        song.artistName ?? 'Unknown Artist',
                                        style: V35Tokens.secondary.copyWith(
                                          fontSize: 11.5,
                                          color: V35Tokens.textSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (player.isSleepTimerActive)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 4),
                                        child: Icon(
                                          Icons.timer_outlined,
                                          size: 12,
                                          color: V35Tokens.accent,
                                        ),
                                      ),
                                    if (player.equalizerEnabled)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 4),
                                        child: Icon(
                                          Icons.equalizer_rounded,
                                          size: 12,
                                          color: V35Tokens.accent,
                                        ),
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

                  // Mobile Controls
                  if (screenWidth > 380)
                    IconButton(
                      icon: const Icon(
                        Icons.skip_previous_rounded,
                        size: 24,
                        color: V35Tokens.textPrimary,
                      ),
                      onPressed: () => player.previous(),
                    ),
                  V35PlayToggleCircle(
                    isPlaying: player.isPlaying,
                    isLoading: player.isLoadingAudio,
                    size: V35PlayButtonSize.sm,
                    onToggle: () => player.togglePlayPause(),
                    tooltip: player.isPlaying ? 'Jeda' : 'Putar',
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.skip_next_rounded,
                      size: 24,
                      color: V35Tokens.textPrimary,
                    ),
                    onPressed: () => player.next(),
                  ),
                  _buildMiniRepeatButton(context, player),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // REPEAT BUTTON WITH V3.5 EMERALD ACCENTS
  // ===========================================================================
  Widget _buildMiniRepeatButton(BuildContext context, PlayerProvider player) {
    final mode = player.repeatMode;
    Widget iconWidget;

    if (mode == AppRepeatMode.off) {
      iconWidget = const Icon(
        Icons.repeat_rounded,
        size: 18,
        color: V35Tokens.textMuted,
      );
    } else if (mode == AppRepeatMode.one) {
      iconWidget = Icon(
        Icons.repeat_one_rounded,
        size: 18,
        color: V35Tokens.accent,
      );
    } else if (mode == AppRepeatMode.forever) {
      iconWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.repeat_rounded, size: 16, color: V35Tokens.accent),
          Text(
            '∞',
            style: TextStyle(
              color: V35Tokens.accent,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    } else {
      final remaining = player.remainingRepeatCount;
      final displayVal = remaining > 0 ? remaining : player.targetRepeatCount;
      iconWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.repeat_rounded, size: 16, color: V35Tokens.accent),
          Text(
            '$displayVal',
            style: TextStyle(
              color: V35Tokens.accent,
              fontSize: 10,
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
    );
  }
}
