import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/youtube_model.dart';
import '../../models/song_model.dart';
import '../../providers/youtube_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/player_provider.dart';
import '../../services/youtube/youtube_service.dart';
import '../../services/youtube/youtube_parser.dart';
import '../../services/download_service.dart';
import '../../repositories/local_music_repository.dart';
import '../../widgets/dialogs/playlist_picker_dialog.dart';
import '../youtube/youtube_playlist_screen.dart';

class YouTubeSearchScreen extends StatefulWidget {
  const YouTubeSearchScreen({super.key});

  @override
  State<YouTubeSearchScreen> createState() => _YouTubeSearchScreenState();
}

class _YouTubeSearchScreenState extends State<YouTubeSearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        ).showSnackBar(SnackBar(content: Text('Buka URL di browser: $url')));
      }
    }
  }

  void _handleMatchLocal(YouTubeVideo video) {
    final catalog = Provider.of<CatalogProvider>(context, listen: false);
    final match = YouTubeService.instance.matchLocalSong(video, catalog.songs);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Matching Lagu Lokal',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'YouTube: ${video.title}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            if (match != null) ...[
              const Text(
                'Lagu Lokal Cocok Ditemukan:',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Judul: ${match.title}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              Text(
                'Artis: ${match.artistName ?? "Unknown Artist"}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              Text(
                'Durasi: ${match.duration} detik',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ] else ...[
              const Text(
                'Tidak ada lagu lokal yang cocok.',
                style: TextStyle(color: Colors.orangeAccent),
              ),
              const SizedBox(height: 4),
              const Text(
                'Anda dapat mengimpor file audio ke pustaka lokal terlebih dahulu.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
          if (match != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                final player = Provider.of<PlayerProvider>(
                  context,
                  listen: false,
                );
                player.playSong(match);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text(
                'Putar Lagu Lokal',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleAddToPlaylist(YouTubeVideo video) async {
    final repo = LocalMusicRepository();
    final playlists = await repo.getPlaylists();

    if (!mounted) return;

    final chosen = await PlaylistPickerDialog.show(
      context,
      playlists: playlists,
      selectedSongCount: 1,
    );

    if (chosen != null && chosen.isNotEmpty && mounted) {
      final songModel = SongModel.fromYouTubeVideo(video);
      final songId = await repo.insertOrUpdateSong(songModel);
      final res = await repo.addSongsToMultiplePlaylists(chosen, [songId]);
      final added = res.values.fold<int>(0, (s, c) => s + c);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Berhasil menambahkan "${video.title}" ke ${chosen.length} playlist ($added penambahan).',
            ),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ytProvider = Provider.of<YouTubeProvider>(context);
    final player = Provider.of<PlayerProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pencarian YouTube Music',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText:
                    'Cari judul, artis, atau paste link YouTube / YouTube Music...',
                hintStyle: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.primary,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          color: AppColors.textMuted,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          ytProvider.searchWithDebounce('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) {
                setState(() {});
                ytProvider.searchWithDebounce(val);
              },
            ),
          ),
          if (ytProvider.isSearching)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(
                    ytProvider.detectedLinkInfo?.type == YouTubeLinkType.video
                        ? 'Resolving YouTube Music link...'
                        : ytProvider.detectedLinkInfo?.type ==
                              YouTubeLinkType.playlist
                        ? 'Mendeteksi link playlist...'
                        : 'Mencari di YouTube Music...',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
          else if (ytProvider.detectedLinkInfo?.type ==
                  YouTubeLinkType.playlist &&
              ytProvider.detectedLinkInfo?.playlistId != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.playlist_play_rounded,
                          color: AppColors.primary,
                          size: 28,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Link Playlist Dideteksi',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ID Playlist: ${ytProvider.detectedLinkInfo!.playlistId}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        final playlistId =
                            ytProvider.detectedLinkInfo!.playlistId!;
                        final yt = Provider.of<YouTubeProvider>(
                          context,
                          listen: false,
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const YouTubePlaylistScreen(),
                          ),
                        ).then((_) {
                          if (!mounted) return;
                          yt.importPlaylist(playlistId);
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(
                        Icons.download_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      label: const Text(
                        'Buka Menu Impor Playlist',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (ytProvider.searchError != null &&
              ytProvider.searchResults.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                ytProvider.searchError!,
                style: const TextStyle(color: Colors.orangeAccent),
                textAlign: TextAlign.center,
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: ytProvider.searchResults.length,
                itemBuilder: (context, index) {
                  final video = ytProvider.searchResults[index];
                  final songModel = SongModel.fromYouTubeVideo(video);

                  final subtitleText = StringBuffer(
                    video.channelName ?? 'YouTube Music',
                  );
                  if (video.albumName != null && video.albumName!.isNotEmpty) {
                    subtitleText.write(' • ${video.albumName}');
                  }
                  if (video.durationSeconds > 0) {
                    subtitleText.write(' • ${video.durationSeconds}s');
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: video.thumbnailUrl != null
                            ? Image.network(
                                video.thumbnailUrl!,
                                width: 70,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      width: 70,
                                      height: 50,
                                      color: Colors.grey[800],
                                      child: const Icon(
                                        Icons.music_note_rounded,
                                        color: Colors.white54,
                                      ),
                                    ),
                              )
                            : Container(
                                width: 70,
                                height: 50,
                                color: Colors.grey[800],
                                child: const Icon(
                                  Icons.music_note_rounded,
                                  color: Colors.white54,
                                ),
                              ),
                      ),
                      title: Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        subtitleText.toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () {
                        player.playSong(songModel);
                      },
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(
                          Icons.more_vert_rounded,
                          color: AppColors.textMuted,
                        ),
                        color: AppColors.card,
                        onSelected: (choice) {
                          if (choice == 'play') {
                            player.playSong(songModel);
                          } else if (choice == 'play_next') {
                            player.playNext(songModel);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '"${video.title}" akan diputar berikutnya.',
                                ),
                                backgroundColor: AppColors.primary,
                              ),
                            );
                          } else if (choice == 'queue') {
                            player.addToQueue(songModel);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '"${video.title}" ditambahkan ke antrean.',
                                ),
                                backgroundColor: AppColors.primary,
                              ),
                            );
                          } else if (choice == 'playlist') {
                            _handleAddToPlaylist(video);
                          } else if (choice == 'download') {
                            if (DownloadService.isDownloadableSource(
                              songModel,
                            )) {
                              DownloadService.instance.enqueueDownload(
                                songModel,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '"${video.title}" ditambahkan ke antrean Download Manager.',
                                  ),
                                  backgroundColor: AppColors.primary,
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Download tidak tersedia untuk sumber ini. (Hanya sumber audio langsung yang diizinkan)',
                                  ),
                                  backgroundColor: Colors.orangeAccent,
                                ),
                              );
                            }
                          } else if (choice == 'open') {
                            _openOnYouTube(video.sourceUrl);
                          } else if (choice == 'match') {
                            _handleMatchLocal(video);
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
                                Text('Putar Sekarang'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'play_next',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.playlist_play_rounded,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text('Putar Berikutnya'),
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
                            value: 'playlist',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.playlist_add_rounded,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text('Tambah ke Playlist'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'download',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.download_rounded,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text('Unduh / Download'),
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
                                Text('Buka di YouTube'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'match',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.find_replace_rounded,
                                  color: Colors.greenAccent,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text('Cocokkan Lagu Lokal'),
                              ],
                            ),
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
}
