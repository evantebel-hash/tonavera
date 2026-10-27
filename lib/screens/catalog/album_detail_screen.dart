import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/v35_tokens.dart';
import '../../core/theme/v35_accent.dart';
import '../../models/album_model.dart';
import '../../models/song_model.dart';
import '../../providers/player_provider.dart';
import '../../repositories/local_music_repository.dart';
import '../../widgets/app_image.dart';
import '../../widgets/v35/v35_track_row.dart';
import '../../widgets/v35/v35_track_actions.dart';

class AlbumDetailScreen extends StatefulWidget {
  final AlbumModel album;

  const AlbumDetailScreen({super.key, required this.album});

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  final LocalMusicRepository _repo = LocalMusicRepository();
  List<SongModel> _songs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlbumTracks();
  }

  Future<void> _loadAlbumTracks() async {
    setState(() => _isLoading = true);
    try {
      final songs = await _repo.getSongsByAlbumId(widget.album.id);
      if (mounted) {
        setState(() {
          _songs = songs;
        });
      }
    } catch (e) {
      debugPrint('[AlbumDetailScreen] Error loading album tracks: $e');
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
                    // --- APP BAR WITH COVER ART ---
                    SliverAppBar(
                      expandedHeight: 260.0,
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
                          widget.album.title,
                          style: V35Tokens.title.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        background: Stack(
                          fit: StackFit.expand,
                          children: [
                            AppImage(
                              imagePath: widget.album.cover,
                              fit: BoxFit.cover,
                              defaultIcon: Icons.album_rounded,
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

                    // --- ALBUM INFO & PLAY ALL BUTTON ---
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: V35Tokens.space20,
                          vertical: V35Tokens.space16,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.album.artistName != null)
                              Text(
                                widget.album.artistName!,
                                style: V35Tokens.title.copyWith(
                                  color: V35Tokens.accent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              '${widget.album.releaseYear != null ? "${widget.album.releaseYear} • " : ""}${_songs.length} Lagu',
                              style: V35Tokens.caption.copyWith(
                                color: V35Tokens.textMuted,
                              ),
                            ),
                            const SizedBox(height: V35Tokens.space16),
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
                                          'Album ini berisi metadata tanpa file audio lokal.',
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
                                  'Putar Album',
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
                            const SizedBox(height: V35Tokens.space12),
                            const Divider(color: V35Tokens.borderSubtle),
                          ],
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
                              'Belum ada lagu untuk album ini.',
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
