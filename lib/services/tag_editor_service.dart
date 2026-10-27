import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:audiotags/audiotags.dart';
import '../core/utils/metadata_normalizer.dart';
import '../models/song_model.dart';
import '../repositories/local_music_repository.dart';
import 'artwork_cache_service.dart';

class TagEditorService {
  static final Set<String> _writableExtensions = {'mp3', 'flac', 'm4a', 'ogg'};

  /// Checks whether an audio file format supports tag writing via audiotags.
  static bool isFormatSupported(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    return _writableExtensions.contains(ext);
  }

  /// Reads audio tags from a file safely.
  static Future<Tag?> readTags(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) return null;
    try {
      return await AudioTags.read(filePath);
    } catch (e) {
      debugPrint('TagEditorService: Error reading tags from $filePath: $e');
      return null;
    }
  }

  /// Writes tag metadata directly to the physical audio file, re-reads, normalizes, and synchronizes DB.
  static Future<SongModel> saveMetadata({
    required SongModel song,
    required String title,
    required String artist,
    required String album,
    required String albumArtist,
    required String genre,
    required int? year,
    required int? trackNumber,
    required int? discNumber,
    required String composer,
    required String comment,
    Uint8List? newArtworkBytes,
    String? newArtworkMime,
    bool removeArtwork = false,
  }) async {
    final targetPath = song.filePath ?? song.audioPath;
    final file = File(targetPath);

    if (!file.existsSync()) {
      throw Exception('File audio tidak ditemukan di perangkat: $targetPath');
    }

    final ext = targetPath.split('.').last.toLowerCase();
    final formatSupported = _writableExtensions.contains(ext);

    if (formatSupported) {
      // Permission / Lock check
      try {
        final accessTest = file.openSync(mode: FileMode.append);
        accessTest.closeSync();
      } catch (e) {
        throw Exception(
          'Metadata file tidak dapat diubah karena file tidak memiliki izin tulis atau sedang dikunci oleh player.',
        );
      }

      Tag? existingTag;
      try {
        existingTag = await AudioTags.read(targetPath);
      } catch (e) {
        debugPrint(
          'TagEditorService: Failed to read existing tag prior to write: $e',
        );
      }

      List<Picture> pictures = existingTag?.pictures ?? [];
      if (removeArtwork) {
        pictures = [];
      } else if (newArtworkBytes != null && newArtworkBytes.isNotEmpty) {
        MimeType mime = MimeType.jpeg;
        if (newArtworkMime?.contains('png') == true) {
          mime = MimeType.png;
        }
        pictures = [
          Picture(
            pictureType: PictureType.coverFront,
            mimeType: mime,
            bytes: newArtworkBytes,
          ),
        ];
      }

      final tagToWrite = Tag(
        title: title.trim().isEmpty ? null : title.trim(),
        trackArtist: artist.trim().isEmpty ? null : artist.trim(),
        album: album.trim().isEmpty ? null : album.trim(),
        albumArtist: albumArtist.trim().isEmpty ? null : albumArtist.trim(),
        genre: genre.trim().isEmpty ? null : genre.trim(),
        year: year,
        trackNumber: trackNumber,
        discNumber: discNumber,
        lyrics: existingTag?.lyrics,
        pictures: pictures,
      );

      try {
        await AudioTags.write(targetPath, tagToWrite);
        await ArtworkCacheService.invalidateCache(targetPath);
      } catch (e) {
        debugPrint('TagEditorService: Failed writing tags to audio file: $e');
        throw Exception('Gagal menulis tag ke file audio ($ext): $e');
      }
    }

    // RESCAN / READ-BACK WORKFLOW (Source of Truth)
    Tag? readBackTag;
    try {
      readBackTag = await AudioTags.read(targetPath);
    } catch (e) {
      debugPrint('TagEditorService: Read-back failed after write: $e');
    }

    final fallbackTitle = title.trim().isNotEmpty ? title.trim() : song.title;
    final normalized = NormalizedSongMetadata.fromTag(
      readBackTag,
      fallbackTitle: fallbackTitle,
    );

    String? cachedCover = song.cover;
    if (normalized.pictures.isNotEmpty) {
      cachedCover = await ArtworkCacheService.extractAndCacheArtwork(
        audioFilePath: targetPath,
        pictures: normalized.pictures,
      );
    } else if (removeArtwork) {
      cachedCover = null;
    }

    final repo = LocalMusicRepository();
    final songToSave = song.copyWith(
      title: normalized.title,
      artistName: normalized.artist,
      albumTitle: normalized.album,
      genreName: normalized.genre,
      lyrics: normalized.lyrics,
      cover: cachedCover,
    );

    final updatedId = await repo.insertOrUpdateSong(songToSave);
    final finalSong = songToSave.copyWith(
      id: updatedId > 0 ? updatedId : song.id,
    );

    return finalSong;
  }
}
