import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/listening_statistics_model.dart';
import '../../models/song_model.dart';
import '../../providers/player_provider.dart';

class TopMusicSectionWidget extends StatefulWidget {
  final List<TopMusicItemModel> topSongs;
  final List<TopMusicItemModel> topArtists;
  final List<TopMusicItemModel> topAlbums;

  const TopMusicSectionWidget({
    super.key,
    required this.topSongs,
    required this.topArtists,
    required this.topAlbums,
  });

  @override
  State<TopMusicSectionWidget> createState() => _TopMusicSectionWidgetState();
}

class _TopMusicSectionWidgetState extends State<TopMusicSectionWidget> {
  int _selectedCategory = 0; // 0: Lagu, 1: Artis, 2: Album

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Musik Teratas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  label: Text('Lagu', style: TextStyle(fontSize: 12)),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text('Artis', style: TextStyle(fontSize: 12)),
                ),
                ButtonSegment(
                  value: 2,
                  label: Text('Album', style: TextStyle(fontSize: 12)),
                ),
              ],
              selected: {_selectedCategory},
              onSelectionChanged: (set) {
                setState(() => _selectedCategory = set.first);
              },
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppColors.primary,
                selectedForegroundColor: Colors.white,
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_selectedCategory == 0)
          _buildSongList(widget.topSongs)
        else if (_selectedCategory == 1)
          _buildArtistList(widget.topArtists)
        else
          _buildAlbumList(widget.topAlbums),
      ],
    );
  }

  Widget _buildSongList(List<TopMusicItemModel> items) {
    if (items.isEmpty) {
      return _buildEmptyState('Belum ada lagu yang diputar dalam periode ini.');
    }

    final player = Provider.of<PlayerProvider>(context, listen: false);

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (ctx, idx) =>
          const Divider(color: AppColors.divider, height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        final rank = index + 1;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            vertical: 4,
            horizontal: 8,
          ),
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  '$rank',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: rank <= 3 ? AppColors.primary : AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 44,
                  height: 44,
                  color: AppColors.card,
                  child: const Icon(
                    Icons.music_note_rounded,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          title: Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            '${item.subtitle ?? "Artis Tidak Dikenal"} • ${item.playCount}x putar',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          trailing: IconButton(
            icon: const Icon(
              Icons.play_circle_filled_rounded,
              color: AppColors.primary,
              size: 28,
            ),
            onPressed: () {
              final song = SongModel(
                id: item.id,
                artistId: item.artistId ?? 0,
                albumId: item.albumId,
                title: item.title,
                duration: item.totalDurationSeconds > 0
                    ? (item.totalDurationSeconds ~/ item.playCount)
                    : 0,
                audioPath: item.audioPath ?? '',
                filePath: item.filePath,
                artistName: item.subtitle,
                cover: item.cover,
                source: item.filePath != null ? 'local' : 'catalog',
              );
              player.playSong(song, context: context);
            },
          ),
        );
      },
    );
  }

  Widget _buildArtistList(List<TopMusicItemModel> items) {
    if (items.isEmpty) {
      return _buildEmptyState('Belum ada artis dalam periode ini.');
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (ctx, idx) =>
          const Divider(color: AppColors.divider, height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        final rank = index + 1;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            vertical: 4,
            horizontal: 8,
          ),
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  '$rank',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: rank <= 3 ? AppColors.primary : AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.card,
                child: const Icon(
                  Icons.person_rounded,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          title: Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            '${item.playCount}x putaran • ${_formatDuration(item.totalDurationSeconds)}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        );
      },
    );
  }

  Widget _buildAlbumList(List<TopMusicItemModel> items) {
    if (items.isEmpty) {
      return _buildEmptyState('Belum ada album dalam periode ini.');
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (ctx, idx) =>
          const Divider(color: AppColors.divider, height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        final rank = index + 1;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            vertical: 4,
            horizontal: 8,
          ),
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  '$rank',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: rank <= 3 ? AppColors.primary : AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 44,
                  height: 44,
                  color: AppColors.card,
                  child: const Icon(
                    Icons.album_rounded,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          title: Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            '${item.subtitle ?? "Artis"} • ${item.playCount}x putar',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String msg) {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        msg,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    if (mins < 60) return '$mins mnt';
    final hours = mins ~/ 60;
    final rem = mins % 60;
    return '${hours}j ${rem}m';
  }
}
