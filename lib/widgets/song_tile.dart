import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song_model.dart';
import '../core/constants/app_colors.dart';
import '../providers/player_provider.dart';
import '../repositories/local_music_repository.dart';
import 'app_image.dart';
import 'dialogs/tag_editor_dialog.dart';
import 'dialogs/playlist_picker_dialog.dart';

class SongTile extends StatelessWidget {
  final SongModel song;
  final bool? isPlaying;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onMoreTap;
  final Widget? trailing;

  const SongTile({
    super.key,
    required this.song,
    this.isPlaying,
    this.isSelected = false,
    this.isSelectionMode = false,
    this.onTap,
    this.onLongPress,
    this.onFavoriteToggle,
    this.onMoreTap,
    this.trailing,
  });

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, child) {
        final isPlayingThis = player.currentSong?.id == song.id;

        return ListTile(
          onTap: onTap ?? () => player.playSong(song, context: context),
          onLongPress: onLongPress,
          tileColor: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : null,
          shape: isSelected
              ? RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Stack(
                children: [
                  AppImage(
                    imagePath: song.cover,
                    width: 48,
                    height: 48,
                    defaultIcon: Icons.music_note_rounded,
                  ),
                  if (isSelected)
                    Container(
                      color: AppColors.primary.withValues(alpha: 0.85),
                      child: const Center(
                        child: Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    )
                  else if (isPlayingThis)
                    Container(
                      color: Colors.black.withValues(alpha: 0.5),
                      child: Center(
                        child: player.isPlaying
                            ? const Icon(
                                Icons.graphic_eq_rounded,
                                color: AppColors.primaryLight,
                                size: 24,
                              )
                            : const Icon(
                                Icons.play_arrow_rounded,
                                color: AppColors.primaryLight,
                                size: 24,
                              ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          title: Text(
            song.title,
            style: TextStyle(
              color: isPlayingThis
                  ? AppColors.primaryLight
                  : AppColors.textPrimary,
              fontWeight: isPlayingThis ? FontWeight.bold : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${song.artistName ?? 'Unknown Artist'} • ${song.albumTitle ?? 'Single'} ${song.source == 'local' ? '• Lokal' : ''}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing:
              trailing ??
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatDuration(song.duration),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  if (onFavoriteToggle != null)
                    IconButton(
                      icon: Icon(
                        song.isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: song.isFavorite
                            ? AppColors.accent
                            : AppColors.textMuted,
                      ),
                      onPressed: onFavoriteToggle,
                    ),
                  IconButton(
                    icon: const Icon(
                      Icons.more_vert,
                      color: AppColors.textSecondary,
                    ),
                    onPressed:
                        onMoreTap ??
                        () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: AppColors.card,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                            ),
                            builder: (sheetContext) {
                              return SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(height: 12),
                                    Container(
                                      width: 44,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: AppColors.textMuted,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ListTile(
                                      leading: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          width: 48,
                                          height: 48,
                                          color: AppColors.primary.withValues(
                                            alpha: 0.1,
                                          ),
                                          child: const Icon(
                                            Icons.music_note_rounded,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        song.title,
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Text(
                                        song.artistName ?? 'Unknown Artist',
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const Divider(color: AppColors.divider),
                                    ListTile(
                                      leading: const Icon(
                                        Icons.queue_music_rounded,
                                        color: AppColors.textPrimary,
                                      ),
                                      title: const Text(
                                        'Play Next',
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      onTap: () {
                                        player.playNext(song);
                                        Navigator.of(sheetContext).pop();
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Lagu ditambahkan untuk diputar selanjutnya',
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(
                                        Icons.playlist_add_rounded,
                                        color: AppColors.textPrimary,
                                      ),
                                      title: const Text(
                                        'Add to Queue',
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      onTap: () {
                                        player.addToQueue(song);
                                        Navigator.of(sheetContext).pop();
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Lagu ditambahkan ke akhir antrean',
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(
                                        Icons.playlist_add_rounded,
                                        color: AppColors.primary,
                                      ),
                                      title: const Text(
                                        'Tambah ke Playlist',
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      onTap: () async {
                                        Navigator.of(sheetContext).pop();
                                        final repo = LocalMusicRepository();
                                        final playlists = await repo
                                            .getPlaylists();
                                        if (context.mounted) {
                                          final chosen =
                                              await PlaylistPickerDialog.show(
                                                context,
                                                playlists: playlists,
                                                selectedSongCount: 1,
                                              );
                                          if (chosen != null &&
                                              chosen.isNotEmpty &&
                                              context.mounted) {
                                            final res = await repo
                                                .addSongsToMultiplePlaylists(
                                                  chosen,
                                                  [song.id],
                                                );
                                            final added = res.values.fold<int>(
                                              0,
                                              (s, c) => s + c,
                                            );
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Berhasil menambahkan "${song.title}" ke ${chosen.length} playlist ($added penambahan).',
                                                  ),
                                                  backgroundColor:
                                                      AppColors.primary,
                                                ),
                                              );
                                            }
                                          }
                                        }
                                      },
                                    ),
                                    if (song.source == 'local' ||
                                        song.filePath != null)
                                      ListTile(
                                        leading: const Icon(
                                          Icons.edit_note_rounded,
                                          color: AppColors.primary,
                                        ),
                                        title: const Text(
                                          'Edit Metadata',
                                          style: TextStyle(
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        onTap: () {
                                          Navigator.of(sheetContext).pop();
                                          TagEditorDialog.show(
                                            context,
                                            song: song,
                                          );
                                        },
                                      ),
                                    const SizedBox(height: 16),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                  ),
                ],
              ),
        );
      },
    );
  }
}
