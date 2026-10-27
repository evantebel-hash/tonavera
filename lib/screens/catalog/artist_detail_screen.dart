import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/v35_tokens.dart';
import '../../core/theme/v35_accent.dart';
import '../../models/artist_model.dart';
import '../../models/album_model.dart';
import '../../models/song_model.dart';
import '../../providers/player_provider.dart';
import '../../repositories/local_music_repository.dart';
import '../../widgets/app_image.dart';
import '../../widgets/v35/v35_track_row.dart';
import '../../widgets/v35/v35_track_actions.dart';
import '../../widgets/v35/v35_media_card.dart';
import 'album_detail_screen.dart';

class ArtistDetailScreen extends StatefulWidget {
  final ArtistModel artist;

  const ArtistDetailScreen({super.key, required this.artist});

  @override
  State<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends State<ArtistDetailScreen> {
  final LocalMusicRepository _repo = LocalMusicRepository();
  List<SongModel> _songs = [];
  List<AlbumModel> _albums = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadArtistData();
  }

  Future<void> _loadArtistData() async {
    setState(() => _isLoading = true);
    try {
      final songs = await _repo.getSongsByArtistId(widget.artist.id);
      final albums = await _repo.getAlbumsByArtistId(widget.artist.id);
      if (mounted) {
        setState(() {
          _songs = songs;
          _albums = albums;
        });
      }
    } catch (e) {
      debugPrint('[ArtistDetailScreen] Error loading data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<V35AccentPalette>(
      valueListenable: V35Accent.notifier,
      builder: (context, activeAccent, child) {
        return Scaffold(
          backgroundColor: V35Tokens.bgVoid,
          body: _isLoading
              ? Center(
                  child: CircularProgressIndicator(color: V35Tokens.accent),
                )
              : CustomScrollView(
                  slivers: [
                    // --- APP BAR WITH ARTIST IMAGE ---
                    SliverAppBar(
                      expandedHeight: 240.0,
                      pinned: true,
                      backgroundColor: V35Tokens.bgSurface,
                      leading: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      flexibleSpace: FlexibleSpaceBar(
                        title: Text(
                          widget.artist.name,
                          style: V35Tokens.title.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        background: Stack(
                          fit: StackFit.expand,
                          children: [
                            AppImage(
                              imagePath: widget.artist.image,
                              fit: BoxFit.cover,
                              defaultIcon: Icons.person_rounded,
                            ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    V35Tokens.bgVoid.withValues(alpha: 0.8),
                                    V35Tokens.bgVoid,
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // --- PLAY BUTTON & STATS ---
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: V35Tokens.space20,
                          vertical: V35Tokens.space16,
                        ),
                        child: Row(
                          children: [
                            if (_songs.isNotEmpty)
                              ElevatedButton.icon(
                                onPressed: () {
                                  final playable = _songs
                                      .where(
                                        (s) =>
                                            s.source != 'spotify' &&
                                            !s.audioPath.startsWith('meta_') &&
                                            !s.audioPath.startsWith('spotify:'),
                                      )
                                      .toList();
                                  if (playable.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Artis ini berisi metadata tanpa file audio lokal.',
                                        ),
                                        backgroundColor: V35Tokens.bgElevated,
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                    return;
                                  }
                                  Provider.of<PlayerProvider>(
                                    context,
                                    listen: false,
                                  ).setQueueAndPlay(playable, initialIndex: 0);
                                },
                                icon: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.black,
                                ),
                                label: const Text(
                                  'Putar Semua',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: V35Tokens.accent,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: V35Tokens.brMd,
                                  ),
                                ),
                              ),
                            const SizedBox(width: V35Tokens.space12),
                            Text(
                              '${_songs.length} Lagu • ${_albums.length} Album',
                              style: V35Tokens.secondary.copyWith(
                                color: V35Tokens.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // --- ALBUMS HORIZONTAL TRAY ---
                    if (_albums.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: V35Tokens.space20,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Diskografi Album',
                                style: V35Tokens.title.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: V35Tokens.textPrimary,
                                ),
                              ),
                              const SizedBox(height: V35Tokens.space12),
                              SizedBox(
                                height: 185,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _albums.length,
                                  itemBuilder: (context, index) {
                                    final album = _albums[index];
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        right: V35Tokens.space12,
                                      ),
                                      child: V35MediaCard(
                                        title: album.title,
                                        subtitle: album.releaseYear != null
                                            ? '${album.releaseYear}'
                                            : 'Album',
                                        artworkPath: album.cover,
                                        width: 130,
                                        aspectRatio: 1.0,
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => AlbumDetailScreen(
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
                              const SizedBox(height: V35Tokens.space20),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // --- TRACK LIST HEADER ---
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: V35Tokens.space20,
                          vertical: V35Tokens.space8,
                        ),
                        child: Text(
                          'Semua Lagu',
                          style: V35Tokens.title.copyWith(
                            fontWeight: FontWeight.w700,
                            color: V35Tokens.textPrimary,
                          ),
                        ),
                      ),
                    ),

                    // --- TRACK ROWS ---
                    if (_songs.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(V35Tokens.space24),
                          child: Center(
                            child: Text(
                              'Belum ada lagu untuk artis ini.',
                              style: V35Tokens.body.copyWith(
                                color: V35Tokens.textMuted,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final song = _songs[index];
                          final player = Provider.of<PlayerProvider>(context);
                          final isPlaying =
                              player.currentSong?.id == song.id &&
                              player.isPlaying;

                          final isMetadataOnly =
                              song.source == 'spotify' ||
                              song.audioPath.startsWith('meta_') ||
                              song.audioPath.startsWith('spotify:');

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: V35Tokens.space20,
                              vertical: 2,
                            ),
                            child: V35TrackRow(
                              title: song.title,
                              artist: song.artistName,
                              album: song.albumTitle,
                              artworkPath: song.cover,
                              duration: song.duration > 0
                                  ? '${(song.duration ~/ 60)}:${(song.duration % 60).toString().padLeft(2, '0')}'
                                  : null,
                              isPlaying: isPlaying,
                              trailing: isMetadataOnly
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: V35Tokens.bgElevated,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'METADATA',
                                        style: V35Tokens.mono.copyWith(
                                          fontSize: 9,
                                          color: V35Tokens.textMuted,
                                        ),
                                      ),
                                    )
                                  : null,
                              onTap: () {
                                if (isMetadataOnly) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Item ini adalah metadata katalog tanpa file audio lokal.',
                                      ),
                                      backgroundColor: V35Tokens.bgElevated,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                  return;
                                }
                                player.setQueueAndPlay(
                                  _songs,
                                  initialIndex: index,
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
                        }, childCount: _songs.length),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
        );
      },
    );
  }
}
