import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audiotags/audiotags.dart';
import '../models/song_model.dart';
import '../repositories/local_music_repository.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/metadata_normalizer.dart';
import 'artwork_cache_service.dart';

class ImportFolderService {
  static Future<void> importFolder(BuildContext context) async {
    try {
      final String? selectedDirectory = await FilePicker.platform
          .getDirectoryPath();
      if (selectedDirectory == null) return;

      final directory = Directory(selectedDirectory);
      if (!directory.existsSync()) return;

      final folderName = selectedDirectory.split(Platform.pathSeparator).last;

      if (!context.mounted) return;
      final nav = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const AlertDialog(
          backgroundColor: AppColors.card,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Memindai folder dan membuat playlist...',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
      );

      final files = directory
          .listSync(recursive: true)
          .whereType<File>()
          .toList();
      final supportedExts = {'mp3', 'wav', 'flac', 'm4a', 'aac', 'ogg'};

      final audioFiles = files.where((f) {
        final ext = f.path.split('.').last.toLowerCase();
        return supportedExts.contains(ext);
      }).toList();

      if (audioFiles.isEmpty) {
        nav.pop();
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Tidak ada file audio ditemukan dalam folder tersebut.',
            ),
          ),
        );
        return;
      }

      final repository = LocalMusicRepository();
      final playlistId = await repository.createPlaylist(
        folderName,
        description: 'Dibuat otomatis dari folder lokal',
      );

      int successCount = 0;

      for (final file in audioFiles) {
        final filename = file.path.split(Platform.pathSeparator).last;
        final rawTitle = filename.contains('.')
            ? filename.substring(0, filename.lastIndexOf('.'))
            : filename;

        Tag? tag;
        try {
          tag = await AudioTags.read(file.path);
        } catch (e) {
          debugPrint('Gagal membaca ID3 untuk ${file.path}: $e');
        }

        final normalized = NormalizedSongMetadata.fromTag(
          tag,
          fallbackTitle: rawTitle,
        );

        String? cachedCover;
        if (normalized.pictures.isNotEmpty) {
          cachedCover = await ArtworkCacheService.extractAndCacheArtwork(
            audioFilePath: file.path,
            pictures: normalized.pictures,
          );
        }

        try {
          final song = SongModel(
            id: 0,
            artistId: 0,
            title: normalized.title,
            duration: normalized.duration,
            audioPath: file.path,
            filePath: file.path,
            source: 'local',
            artistName: normalized.artist,
            albumTitle: normalized.album,
            genreName: normalized.genre,
            lyrics: normalized.lyrics,
            cover: cachedCover,
          );

          final songId = await repository.insertOrUpdateSong(song);
          await repository.addSongToPlaylist(playlistId, songId);
          successCount++;
        } catch (e) {
          debugPrint('Gagal mengimpor lagu ${file.path}: $e');
        }
      }

      nav.pop();

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '$successCount lagu dari folder "$folderName" berhasil diimpor menjadi playlist!',
          ),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      debugPrint('Error import folder: $e');
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengimpor folder: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}
