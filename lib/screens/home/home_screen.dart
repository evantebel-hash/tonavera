import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/v35_tokens.dart';
import '../../core/theme/v35_accent.dart';
import '../../providers/auth_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/player_provider.dart';
import '../../widgets/v35/v35_filter_pill.dart';
import '../../widgets/v35/v35_media_card.dart';
import '../../widgets/v35/v35_track_row.dart';
import '../../widgets/v35/v35_track_actions.dart';
import '../../widgets/v35/v35_empty_state.dart';
import 'recently_played_screen.dart';
import '../catalog/artist_detail_screen.dart';
import '../catalog/album_detail_screen.dart';

/// V3.5 Obsidian Emerald Home Screen.
///
/// Features:
/// - Personalized music discovery dashboard
/// - Recently Played horizontal tray with quick-resume
/// - Genre filter pills
/// - Album and Artist media cards
/// - Newest tracks rendered via V35TrackRow
/// - Full preservation of CatalogProvider, HistoryProvider, and PlayerProvider.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '00:00';
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<V35AccentPalette>(
      valueListenable: V35Accent.notifier,
      builder: (context, accentPalette, _) {
        return Scaffold(
          backgroundColor: V35Tokens.bgVoid,
          body: SafeArea(
            child: Consumer<CatalogProvider>(
              builder: (context, catalog, child) {
                if (catalog.isLoading) {
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

                return RefreshIndicator(
                  onRefresh: () async {
                    final auth = Provider.of<AuthProvider>(
                      context,
                      listen: false,
                    );
                    await catalog.fetchCatalogData();
                    if (auth.isAuthenticated && context.mounted) {
                      Provider.of<HistoryProvider>(
                        context,
                        listen: false,
                      ).fetchRecentlyPlayed();
                    }
                  },
                  color: V35Tokens.accent,
                  backgroundColor: V35Tokens.bgElevated,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: V35Tokens.space20,
                            vertical: V35Tokens.space16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // --- HEADER ---
                              Text(
                                'Jelajahi Musik',
                                style: V35Tokens.display.copyWith(
                                  fontSize: 26.0,
                                  fontWeight: FontWeight.w700,
                                  color: V35Tokens.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Koleksi musik independen Anda',
                                style: V35Tokens.secondary.copyWith(
                                  color: V35Tokens.textMuted,
                                ),
                              ),
                              const SizedBox(height: V35Tokens.space24),

                              // --- RECENTLY PLAYED SECTION ---
                              Consumer2<AuthProvider, HistoryProvider>(
                                builder: (context, auth, history, child) {
                                  if (!auth.isAuthenticated)
                                    return const SizedBox.shrink();

                                  if (history.isLoading &&
                                      history.recentlyPlayed.isEmpty) {
                                    return SizedBox(
                                      height: 120,
                                      child: Center(
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.0,
                                            color: V35Tokens.accent,
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  if (history.recentlyPlayed.isEmpty) {
                                    return Container(
                                      margin: const EdgeInsets.only(
                                        bottom: V35Tokens.space24,
                                      ),
                                      padding: const EdgeInsets.all(
                                        V35Tokens.space16,
                                      ),
                                      decoration: BoxDecoration(
                                        color: V35Tokens.bgSurface,
                                        borderRadius: V35Tokens.brMd,
                                        border: Border.all(
                                          color: V35Tokens.borderSubtle,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.history_rounded,
                                            color: V35Tokens.accent,
                                            size: 32,
                                          ),
                                          const SizedBox(
                                            width: V35Tokens.space16,
                                          ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Recently Played',
                                                  style: V35Tokens.title
                                                      .copyWith(
                                                        fontSize: 14.5,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: V35Tokens
                                                            .textPrimary,
                                                      ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Belum ada riwayat pemutaran. Putar lagu untuk melihatnya di sini.',
                                                  style: V35Tokens.secondary
                                                      .copyWith(
                                                        color:
                                                            V35Tokens.textMuted,
                                                        fontSize: 12.0,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Recently Played',
                                            style: V35Tokens.title.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: V35Tokens.textPrimary,
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      const RecentlyPlayedScreen(),
                                                ),
                                              );
                                            },
                                            child: Text(
                                              'Lihat Semua >',
                                              style: V35Tokens.mono.copyWith(
                                                color: V35Tokens.accent,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12.0,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: V35Tokens.space8),
                                      SizedBox(
                                        height: 175,
                                        child: ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          itemCount:
                                              history.recentlyPlayed.length > 6
                                              ? 6
                                              : history.recentlyPlayed.length,
                                          itemBuilder: (context, index) {
                                            final song =
                                                history.recentlyPlayed[index];
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                right: V35Tokens.space12,
                                              ),
                                              child: V35MediaCard(
                                                title: song.title,
                                                subtitle:
                                                    song.artistName ??
                                                    'Unknown Artist',
                                                artworkPath: song.cover,
                                                width: 120,
                                                aspectRatio: 1.0,
                                                onTap: () {
                                                  Provider.of<PlayerProvider>(
                                                    context,
                                                    listen: false,
                                                  ).setQueueAndPlay(
                                                    history.recentlyPlayed,
                                                    initialIndex: index,
                                                  );
                                                },
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: V35Tokens.space24),
                                    ],
                                  );
                                },
                              ),

                              // --- GENRE FILTER PILLS ---
                              if (catalog.genres.isNotEmpty) ...[
                                SizedBox(
                                  height: 38,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: catalog.genres.length,
                                    itemBuilder: (context, index) {
                                      final g = catalog.genres[index];
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          right: V35Tokens.space8,
                                        ),
                                        child: V35FilterPill(
                                          label: g.name,
                                          isSelected: false,
                                          onTap: () {
                                            catalog.fetchSongs(genreId: g.id);
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: V35Tokens.space24),
                              ],

                              // --- ALBUMS HORIZONTAL TRAY ---
                              if (catalog.albums.isNotEmpty) ...[
                                Text(
                                  'Album Pilihan',
                                  style: V35Tokens.title.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: V35Tokens.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: V35Tokens.space12),
                                SizedBox(
                                  height: 195,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: catalog.albums.length,
                                    itemBuilder: (context, index) {
                                      final album = catalog.albums[index];
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          right: V35Tokens.space12,
                                        ),
                                        child: V35MediaCard(
                                          title: album.title,
                                          subtitle: album.artistName ?? 'Album',
                                          artworkPath: album.cover,
                                          width: 140,
                                          aspectRatio: 1.0,
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    AlbumDetailScreen(
                                                      album: album,
                                                    ),
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: V35Tokens.space24),
                              ],

                              // --- ARTISTS HORIZONTAL TRAY ---
                              if (catalog.artists.isNotEmpty) ...[
                                Text(
                                  'Artis Populer',
                                  style: V35Tokens.title.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: V35Tokens.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: V35Tokens.space12),
                                SizedBox(
                                  height: 155,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: catalog.artists.length,
                                    itemBuilder: (context, index) {
                                      final artist = catalog.artists[index];
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          right: V35Tokens.space12,
                                        ),
                                        child: V35MediaCard(
                                          title: artist.name,
                                          subtitle: 'Artis',
                                          artworkPath: artist.image,
                                          isCircular: true,
                                          width: 100,
                                          aspectRatio: 1.0,
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    ArtistDetailScreen(
                                                      artist: artist,
                                                    ),
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: V35Tokens.space24),
                              ],

                              // --- SONGS HEADER ---
                              Text(
                                'Lagu Terbaru',
                                style: V35Tokens.title.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: V35Tokens.textPrimary,
                                ),
                              ),
                              const SizedBox(height: V35Tokens.space8),
                            ],
                          ),
                        ),
                      ),

                      // --- SONGS SLIVER LIST ---
                      if (catalog.songs.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: V35EmptyState(
                            icon: Icons.music_off_rounded,
                            title: 'Belum Ada Lagu',
                            description:
                                'Koleksi lagu Anda belum tersedia di server katalog.',
                          ),
                        )
                      else
                        Consumer<PlayerProvider>(
                          builder: (context, player, child) {
                            return SliverList(
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                final song = catalog.songs[index];
                                final isPlayingThis =
                                    player.currentSong?.id == song.id;

                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: V35Tokens.space12,
                                    vertical: 2.0,
                                  ),
                                  child: V35TrackRow(
                                    index: index + 1,
                                    title: song.title,
                                    artist: song.artistName,
                                    album: song.albumTitle,
                                    duration: _formatDuration(song.duration),
                                    artworkPath: song.cover,
                                    isPlaying: isPlayingThis,
                                    onTap: () {
                                      player.playSong(
                                        song,
                                        playlist: catalog.songs,
                                        context: context,
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
                                );
                              }, childCount: catalog.songs.length),
                            );
                          },
                        ),

                      const SliverToBoxAdapter(
                        child: SizedBox(height: V35Tokens.space32),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
