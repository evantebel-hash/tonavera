import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/youtube_model.dart';
import '../../models/song_model.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../providers/player_provider.dart';
import '../../repositories/local_music_repository.dart';
import '../../services/youtube/youtube_repository.dart';
import '../../services/youtube/youtube_service.dart';

class YouTubePlaylistDetailScreen extends StatefulWidget {
  final String playlistId;

  const YouTubePlaylistDetailScreen({super.key, required this.playlistId});

  @override
  State<YouTubePlaylistDetailScreen> createState() =>
      _YouTubePlaylistDetailScreenState();
}

class _YouTubePlaylistDetailScreenState
    extends State<YouTubePlaylistDetailScreen> {
  YouTubePlaylist? _playlist;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaylist();
  }

  Future<void> _loadPlaylist() async {
    setState(() => _isLoading = true);
    final repo = YouTubeRepository();
    final pl = await repo.getPlaylist(widget.playlistId);
    if (mounted) {
      setState(() {
        _playlist = pl;
        _isLoading = false;
      });
    }
  }

  void _openOnYouTube(String url) async {
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', url]);
      } else if (Platform.isAndroid) {
        await Process.run('am', [
          'start',
          '-a',
          'android.intent.action.VIEW',
          '-d',
          url,
        ]);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Buka URL: $url')));
      }
    }
  }

  void _exportMatchedToLocalPlaylist() async {
    if (_playlist == null) return;
    final catalog = Provider.of<CatalogProvider>(context, listen: false);

    final matchedSongs = <SongModel>[];
    for (final item in _playlist!.items) {
      final video = YouTubeVideo(
        videoId: item.videoId,
        title: item.title,
        channelName: item.channelName,
        durationSeconds: item.durationSeconds,
      );
      final match = YouTubeService.instance.matchLocalSong(
        video,
        catalog.songs,
      );
      if (match != null && !matchedSongs.any((s) => s.id == match.id)) {
        matchedSongs.add(match);
      }
    }

    if (matchedSongs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tidak ada lagu lokal yang cocok untuk diekspor ke playlist lokal.',
          ),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    final repo = LocalMusicRepository();
    final newPlaylistId = await repo.createPlaylist(
      '${_playlist!.title} (Local Match)',
      description: 'Diimpor dari YouTube playlist ${_playlist!.playlistId}',
    );

    await repo.addSongsToPlaylist(
      newPlaylistId,
      matchedSongs.map((s) => s.id).toList(),
    );

    if (mounted) {
      Provider.of<PlaylistProvider>(context, listen: false).fetchPlaylists();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Playlist lokal baru dibuat dengan ${matchedSongs.length} lagu cocok!',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _playlist?.title ?? 'YouTube Playlist Detail',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          if (_playlist != null)
            IconButton(
              icon: const Icon(
                Icons.playlist_add_check_rounded,
                color: Colors.greenAccent,
              ),
              tooltip: 'Ekspor lagu cocok ke Playlist Lokal',
              onPressed: _exportMatchedToLocalPlaylist,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _playlist == null
          ? const Center(
              child: Text('Playlist tidak ditemukan di cache lokal.'),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: _playlist!.thumbnailUrl != null
                                ? Image.network(
                                    _playlist!.thumbnailUrl!,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    width: 80,
                                    height: 80,
                                    color: Colors.grey[800],
                                    child: const Icon(
                                      Icons.playlist_play_rounded,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _playlist!.title,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Channel: ${_playlist!.channelName ?? "YouTube"}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  'Total Item: ${_playlist!.items.length} track',
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _playlist!.items.isEmpty
                                  ? null
                                  : () {
                                      final songModels = _playlist!.items.map((
                                        i,
                                      ) {
                                        return SongModel.fromYouTubeVideo(
                                          YouTubeVideo(
                                            videoId: i.videoId,
                                            title: i.title,
                                            channelName: i.channelName,
                                            thumbnailUrl: i.thumbnailUrl,
                                            durationSeconds: i.durationSeconds,
                                          ),
                                        );
                                      }).toList();
                                      final player =
                                          Provider.of<PlayerProvider>(
                                            context,
                                            listen: false,
                                          );
                                      player.setQueueAndPlay(
                                        songModels,
                                        context: context,
                                      );
                                    },
                              icon: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Putar Semua',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _playlist!.items.isEmpty
                                  ? null
                                  : () {
                                      final player =
                                          Provider.of<PlayerProvider>(
                                            context,
                                            listen: false,
                                          );
                                      final songModels = _playlist!.items.map((
                                        i,
                                      ) {
                                        return SongModel.fromYouTubeVideo(
                                          YouTubeVideo(
                                            videoId: i.videoId,
                                            title: i.title,
                                            channelName: i.channelName,
                                            thumbnailUrl: i.thumbnailUrl,
                                            durationSeconds: i.durationSeconds,
                                          ),
                                        );
                                      }).toList();
                                      for (final s in songModels) {
                                        player.addToQueue(s);
                                      }
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '${songModels.length} lagu YouTube ditambahkan ke queue.',
                                          ),
                                          backgroundColor: AppColors.primary,
                                        ),
                                      );
                                    },
                              icon: const Icon(
                                Icons.queue_music_rounded,
                                color: AppColors.primary,
                              ),
                              label: const Text(
                                'Tambah Queue',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: AppColors.primary,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(
                              Icons.download_for_offline_rounded,
                              color: AppColors.primary,
                              size: 28,
                            ),
                            tooltip: 'Unduh Playlist',
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Playlist YouTube ini tidak memiliki sumber audio langsung yang dapat diunduh (0 dari total lagu dapat diunduh).',
                                  ),
                                  backgroundColor: Colors.orangeAccent,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'DAFTAR TRACK YOUTUBE',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _openOnYouTube(_playlist!.sourceUrl),
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('Buka Web'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._playlist!.items.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  final songModel = SongModel.fromYouTubeVideo(
                    YouTubeVideo(
                      videoId: item.videoId,
                      title: item.title,
                      channelName: item.channelName,
                      thumbnailUrl: item.thumbnailUrl,
                      durationSeconds: item.durationSeconds,
                    ),
                  );

                  final allSongModels = _playlist!.items.map((i) {
                    return SongModel.fromYouTubeVideo(
                      YouTubeVideo(
                        videoId: i.videoId,
                        title: i.title,
                        channelName: i.channelName,
                        thumbnailUrl: i.thumbnailUrl,
                        durationSeconds: i.durationSeconds,
                      ),
                    );
                  }).toList();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListTile(
                      leading: Text(
                        '${idx + 1}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      title: Text(
                        item.title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        '${item.channelName ?? "YouTube"} • ${item.durationSeconds > 0 ? "${item.durationSeconds}s" : "Online Video"}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () {
                        final player = Provider.of<PlayerProvider>(
                          context,
                          listen: false,
                        );
                        player.playSong(
                          songModel,
                          playlist: allSongModels,
                          context: context,
                        );
                      },
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(
                          Icons.more_vert_rounded,
                          color: AppColors.textMuted,
                        ),
                        color: AppColors.card,
                        onSelected: (choice) {
                          final player = Provider.of<PlayerProvider>(
                            context,
                            listen: false,
                          );
                          if (choice == 'play') {
                            player.playSong(
                              songModel,
                              playlist: allSongModels,
                              context: context,
                            );
                          } else if (choice == 'queue') {
                            player.addToQueue(songModel);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '"${item.title}" ditambahkan ke antrean.',
                                ),
                                backgroundColor: AppColors.primary,
                              ),
                            );
                          } else if (choice == 'open') {
                            _openOnYouTube(
                              'https://www.youtube.com/watch?v=${item.videoId}',
                            );
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'play',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.play_arrow_rounded,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text('Putar'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'queue',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.queue_music_rounded,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text('Tambah ke Queue'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'open',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.open_in_browser_rounded,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text('Buka di Browser'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
