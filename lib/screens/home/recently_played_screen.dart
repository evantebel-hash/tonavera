import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/v35_tokens.dart';
import '../../core/theme/v35_accent.dart';
import '../../providers/history_provider.dart';
import '../../providers/player_provider.dart';
import '../../models/song_model.dart';
import '../../widgets/v35/v35_track_row.dart';
import '../../widgets/v35/v35_track_actions.dart';
import '../../widgets/v35/v35_empty_state.dart';

/// V3.5 Obsidian Emerald Recently Played Screen.
class RecentlyPlayedScreen extends StatefulWidget {
  const RecentlyPlayedScreen({super.key});

  @override
  State<RecentlyPlayedScreen> createState() => _RecentlyPlayedScreenState();
}

class _RecentlyPlayedScreenState extends State<RecentlyPlayedScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<HistoryProvider>(
        context,
        listen: false,
      ).fetchRecentlyPlayed(limit: 50);
    });
  }

  String _formatRelativeTime(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Baru saja';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} menit lalu';
    } else if (difference.inHours < 24 && now.day == date.day) {
      return '${difference.inHours} jam lalu';
    } else if (difference.inDays < 2 || (now.day - date.day == 1)) {
      return 'Kemarin';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} hari lalu';
    } else {
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des',
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    }
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '00:00';
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _getGroup(DateTime? date) {
    if (date == null) return 'SEBELUMNYA';
    final now = DateTime.now();
    final difference = now.difference(date);

    if (now.day == date.day &&
        now.month == date.month &&
        now.year == date.year) {
      return 'HARI INI';
    } else if (difference.inDays < 2 || (now.day - date.day == 1)) {
      return 'KEMARIN';
    } else {
      return 'SEBELUMNYA';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<V35AccentPalette>(
      valueListenable: V35Accent.notifier,
      builder: (context, accentPalette, _) {
        return Scaffold(
          backgroundColor: V35Tokens.bgVoid,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: V35Tokens.textPrimary,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              'Recently Played',
              style: V35Tokens.title.copyWith(
                fontWeight: FontWeight.w700,
                color: V35Tokens.textPrimary,
              ),
            ),
            actions: [
              Consumer<HistoryProvider>(
                builder: (context, history, child) {
                  if (history.recentlyPlayed.isEmpty)
                    return const SizedBox.shrink();
                  return IconButton(
                    icon: Icon(
                      Icons.play_arrow_rounded,
                      color: V35Tokens.accent,
                      size: 28,
                    ),
                    tooltip: 'Putar Semua',
                    onPressed: () {
                      Provider.of<PlayerProvider>(
                        context,
                        listen: false,
                      ).setQueueAndPlay(history.recentlyPlayed);
                    },
                  );
                },
              ),
            ],
          ),
          body: Consumer<HistoryProvider>(
            builder: (context, history, child) {
              if (history.isLoading && history.recentlyPlayed.isEmpty) {
                return Center(
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: V35Tokens.accent,
                    ),
                  ),
                );
              }

              if (history.error != null && history.recentlyPlayed.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        history.error!,
                        style: V35Tokens.body.copyWith(
                          color: V35Tokens.textMuted,
                        ),
                      ),
                      const SizedBox(height: V35Tokens.space16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: V35Tokens.accent,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: () => history.fetchRecentlyPlayed(limit: 50),
                        child: const Text(
                          'Coba Lagi',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (history.recentlyPlayed.isEmpty) {
                return const V35EmptyState(
                  icon: Icons.history_rounded,
                  title: 'Belum Ada Riwayat',
                  description:
                      'Lagu yang Anda putar akan muncul di sini secara kronologis.',
                );
              }

              final groupedSongs = <String, List<SongModel>>{};
              for (final song in history.recentlyPlayed) {
                final group = _getGroup(song.playedAt);
                if (!groupedSongs.containsKey(group)) {
                  groupedSongs[group] = [];
                }
                groupedSongs[group]!.add(song);
              }

              final order = ['HARI INI', 'KEMARIN', 'SEBELUMNYA'];
              final displayGroups = order
                  .where((o) => groupedSongs.containsKey(o))
                  .toList();

              return RefreshIndicator(
                color: V35Tokens.accent,
                backgroundColor: V35Tokens.bgElevated,
                onRefresh: () => history.fetchRecentlyPlayed(limit: 50),
                child: Consumer<PlayerProvider>(
                  builder: (context, player, child) {
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: V35Tokens.space12,
                        vertical: V35Tokens.space8,
                      ),
                      itemCount: displayGroups.length,
                      itemBuilder: (context, index) {
                        final groupName = displayGroups[index];
                        final songs = groupedSongs[groupName]!;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                              child: Text(
                                groupName,
                                style: V35Tokens.mono.copyWith(
                                  color: V35Tokens.accentBright,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                            for (final song in songs)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2.0,
                                ),
                                child: V35TrackRow(
                                  title: song.title,
                                  artist:
                                      '${song.artistName ?? 'Unknown Artist'} • ${_formatRelativeTime(song.playedAt)}',
                                  album: song.albumTitle,
                                  duration: _formatDuration(song.duration),
                                  artworkPath: song.cover,
                                  isPlaying: player.currentSong?.id == song.id,
                                  onTap: () {
                                    final songIndex = history.recentlyPlayed
                                        .indexOf(song);
                                    player.setQueueAndPlay(
                                      history.recentlyPlayed,
                                      initialIndex: songIndex >= 0
                                          ? songIndex
                                          : 0,
                                    );
                                  },
                                  onMore: () {
                                    V35TrackActions.show(
                                      context,
                                      song: song,
                                      player: player,
                                    );
                                  },
                                ),
                              ),
                          ],
                        );
                      },
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}
