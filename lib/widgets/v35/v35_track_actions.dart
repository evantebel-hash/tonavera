import 'package:flutter/material.dart';
import '../../core/theme/v35_tokens.dart';
import '../../models/song_model.dart';
import '../../providers/player_provider.dart';
import '../../repositories/local_music_repository.dart';
import '../app_image.dart';
import '../dialogs/playlist_picker_dialog.dart';
import '../dialogs/tag_editor_dialog.dart';
import '../dialogs/import_link_dialog.dart';
import 'v35_action_sheet.dart';

/// Reusable contextual track action menu for V3.5 Obsidian Emerald UI.
///
/// Features:
/// 1. Putar Berikutnya (Play Next via [PlayerProvider.playNext])
/// 2. Tambah ke Antrean (Enqueue via [PlayerProvider.addToQueue])
/// 3. Tambah ke Playlist (Add to Playlist dialog)
/// 4. Edit Metadata (Tag editor via [TagEditorDialog.show] for local tracks with safe remote fallback)
/// 5. Cari / Perbarui Metadata dari Tautan (ImportLinkDialog)
class V35TrackActions {
  const V35TrackActions._();

  /// Displays the contextual track action sheet.
  static void show(
    BuildContext context, {
    required SongModel song,
    required PlayerProvider player,
  }) {
    V35ActionSheet.show(
      context: context,
      title: song.title,
      subtitle: song.artistName ?? 'Unknown Artist',
      headerLeading: ClipRRect(
        borderRadius: V35Tokens.brSm,
        child: SizedBox(
          width: 44,
          height: 44,
          child: AppImage(
            imagePath: song.cover,
            fit: BoxFit.cover,
            defaultIcon: Icons.music_note_rounded,
          ),
        ),
      ),
      actions: [
        // 1. Putar Berikutnya
        V35ActionItem(
          icon: Icons.play_arrow_rounded,
          title: 'Putar Berikutnya',
          onTap: () {
            player.playNext(song);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${song.title} akan diputar berikutnya',
                  style: V35Tokens.body.copyWith(
                    color: V35Tokens.textPrimary,
                    fontSize: 13.0,
                  ),
                ),
                backgroundColor: V35Tokens.bgElevated,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),

        // 2. Tambah ke Antrean
        V35ActionItem(
          icon: Icons.queue_music_rounded,
          title: 'Tambah ke Antrean',
          onTap: () {
            player.addToQueue(song);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${song.title} ditambahkan ke antrean',
                  style: V35Tokens.body.copyWith(
                    color: V35Tokens.textPrimary,
                    fontSize: 13.0,
                  ),
                ),
                backgroundColor: V35Tokens.bgElevated,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),

        // 3. Tambah ke Playlist
        V35ActionItem(
          icon: Icons.playlist_add_rounded,
          title: 'Tambah ke Playlist',
          onTap: () async {
            final repo = LocalMusicRepository();
            final playlists = await repo.getPlaylists();
            if (context.mounted) {
              final chosen = await PlaylistPickerDialog.show(
                context,
                playlists: playlists,
                selectedSongCount: 1,
              );
              if (chosen != null && chosen.isNotEmpty && context.mounted) {
                final results = await repo.addSongsToMultiplePlaylists(chosen, [
                  song.id,
                ]);
                final totalAdded = results.values.fold<int>(
                  0,
                  (sum, count) => sum + count,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Berhasil menambahkan "${song.title}" ke ${chosen.length} playlist ($totalAdded lagu).',
                        style: V35Tokens.body.copyWith(
                          color: V35Tokens.textPrimary,
                          fontSize: 13.0,
                        ),
                      ),
                      backgroundColor: V35Tokens.success,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              }
            }
          },
        ),

        // 4. Edit Metadata
        V35ActionItem(
          icon: Icons.edit_note_rounded,
          title: 'Edit Metadata',
          onTap: () {
            final path = song.filePath ?? song.audioPath;
            final isRemote =
                path.startsWith('http://') ||
                path.startsWith('https://') ||
                song.source.toLowerCase() == 'youtube' ||
                song.source.toLowerCase() == 'spotify';

            if (isRemote || (song.filePath == null && !path.contains('.'))) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Metadata hanya dapat diedit untuk file audio lokal.',
                    style: V35Tokens.body.copyWith(
                      color: V35Tokens.textPrimary,
                      fontSize: 13.0,
                    ),
                  ),
                  backgroundColor: V35Tokens.bgElevated,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            } else {
              TagEditorDialog.show(context, song: song);
            }
          },
        ),

        // 5. Cari / Perbarui Metadata dari Tautan
        V35ActionItem(
          icon: Icons.link_rounded,
          title: 'Perbarui Metadata dari Tautan',
          onTap: () {
            ImportLinkDialog.show(context);
          },
        ),
      ],
      cancelLabel: 'Batal',
    );
  }
}
