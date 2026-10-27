import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:audiotags/audiotags.dart';
import 'package:path_provider/path_provider.dart';
import '../models/song_model.dart';
import '../repositories/local_music_repository.dart';
import '../core/utils/audio_file_validator.dart';
import '../core/utils/metadata_normalizer.dart';
import '../models/lyrics_model.dart';
import 'artwork_cache_service.dart';
import 'lrc_parser.dart';

class ImportProgressUpdate {
  final int totalFiles;
  final int processedFiles;
  final String currentFile;
  final int importedCount;
  final int skippedDuplicates;
  final int unsupportedCount;
  final int failedCount;
  final bool isCancelled;
  final bool isCompleted;

  ImportProgressUpdate({
    required this.totalFiles,
    required this.processedFiles,
    required this.currentFile,
    required this.importedCount,
    required this.skippedDuplicates,
    required this.unsupportedCount,
    required this.failedCount,
    this.isCancelled = false,
    this.isCompleted = false,
  });
}

class ImportResultSummary {
  final int totalScanned;
  final int importedCount;
  final int skippedDuplicates;
  final int unsupportedCount;
  final int failedCount;
  final bool cancelled;
  final List<SongModel> newlyImportedSongs;

  ImportResultSummary({
    required this.totalScanned,
    required this.importedCount,
    required this.skippedDuplicates,
    required this.unsupportedCount,
    required this.failedCount,
    required this.cancelled,
    required this.newlyImportedSongs,
  });
}

class MusicImportService {
  final LocalMusicRepository _repository;
  bool _isCancelled = false;

  MusicImportService({LocalMusicRepository? repository})
    : _repository = repository ?? LocalMusicRepository();

  void cancelImport() {
    _isCancelled = true;
  }

  Future<String> _ensurePersistentLocalFile(String rawPath) async {
    final cleanPath = rawPath.replaceAll('\\', '/');
    if (cleanPath.contains('/cache/file_picker/') ||
        cleanPath.contains('/cache/')) {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final musicDir = Directory('${appDir.path}/MyMusicLocal');
        if (!await musicDir.exists()) {
          await musicDir.create(recursive: true);
        }
        final fileName = rawPath.split(Platform.pathSeparator).last;
        final targetPath = '${musicDir.path}/$fileName';

        final srcFile = File(rawPath);
        if (await srcFile.exists()) {
          await srcFile.copy(targetPath);
          debugPrint(
            '[MusicImportService] Copied temporary cache file to persistent storage: $targetPath',
          );
          return targetPath;
        }
      } catch (e) {
        debugPrint(
          '[MusicImportService] Failed to copy cache file to persistent storage: $e',
        );
      }
    }
    return rawPath;
  }

  /// Imports list of raw paths (files or directories) with progress reporting.
  Future<ImportResultSummary> importPaths({
    required List<String> paths,
    int? targetPlaylistId,
    void Function(ImportProgressUpdate)? onProgress,
  }) async {
    _isCancelled = false;

    // 1. Resolve files & directories recursively
    final resolvedFiles = <File>[];
    int unsupportedCount = 0;
    final seenPaths = <String>{};

    for (final rawPath in paths) {
      if (rawPath.trim().isEmpty) continue;
      final type = FileSystemEntity.typeSync(rawPath);

      if (type == FileSystemEntityType.file) {
        if (AudioFileValidator.isSupportedAudioFile(rawPath)) {
          final file = File(rawPath);
          if (file.existsSync()) {
            final key = rawPath.replaceAll('\\', '/').toLowerCase();
            if (!seenPaths.contains(key)) {
              seenPaths.add(key);
              resolvedFiles.add(file);
            }
          }
        } else {
          unsupportedCount++;
        }
      } else if (type == FileSystemEntityType.directory) {
        try {
          final dir = Directory(rawPath);
          if (dir.existsSync()) {
            final entries = dir.listSync(recursive: true, followLinks: false);
            for (final entry in entries) {
              if (entry is File) {
                if (AudioFileValidator.isSupportedAudioFile(entry.path)) {
                  final key = entry.path.replaceAll('\\', '/').toLowerCase();
                  if (!seenPaths.contains(key)) {
                    seenPaths.add(key);
                    resolvedFiles.add(entry);
                  }
                } else {
                  unsupportedCount++;
                }
              }
            }
          }
        } catch (e) {
          debugPrint('MusicImportService: Error scanning folder $rawPath: $e');
        }
      }
    }

    final totalFiles = resolvedFiles.length;
    int processedFiles = 0;
    int importedCount = 0;
    int skippedDuplicates = 0;
    int failedCount = 0;
    final newlyImported = <SongModel>[];

    // Pre-fetch all existing songs to check duplicates via trackHash and path
    final existingSongs = await _repository.getAllSongs();
    final existingPathMap = <String, SongModel>{};
    final existingHashMap = <String, SongModel>{};

    for (final s in existingSongs) {
      final p = (s.filePath ?? s.audioPath).replaceAll('\\', '/').toLowerCase();
      existingPathMap[p] = s;
      if (s.trackHash.isNotEmpty) {
        existingHashMap[s.trackHash] = s;
      }
    }

    for (int i = 0; i < resolvedFiles.length; i++) {
      if (_isCancelled) {
        onProgress?.call(
          ImportProgressUpdate(
            totalFiles: totalFiles,
            processedFiles: processedFiles,
            currentFile: 'Cancelled',
            importedCount: importedCount,
            skippedDuplicates: skippedDuplicates,
            unsupportedCount: unsupportedCount,
            failedCount: failedCount,
            isCancelled: true,
            isCompleted: false,
          ),
        );
        break;
      }

      final file = resolvedFiles[i];
      final path = await _ensurePersistentLocalFile(file.path);
      final fileName = path.split(Platform.pathSeparator).last;
      processedFiles++;

      onProgress?.call(
        ImportProgressUpdate(
          totalFiles: totalFiles,
          processedFiles: processedFiles,
          currentFile: fileName,
          importedCount: importedCount,
          skippedDuplicates: skippedDuplicates,
          unsupportedCount: unsupportedCount,
          failedCount: failedCount,
        ),
      );

      try {
        final canonicalKey = path.replaceAll('\\', '/').toLowerCase();

        // Exact path duplicate check
        if (existingPathMap.containsKey(canonicalKey)) {
          skippedDuplicates++;
          continue;
        }

        // Extract metadata using existing tag reader & normalizer
        final rawTitle = fileName.contains('.')
            ? fileName.substring(0, fileName.lastIndexOf('.'))
            : fileName;
        Tag? tag;
        try {
          tag = await AudioTags.read(path);
        } catch (_) {}

        final normalized = NormalizedSongMetadata.fromTag(
          tag,
          fallbackTitle: rawTitle,
        );

        // TrackHash duplicate check
        final tempSong = SongModel(
          id: 0,
          artistId: 0,
          title: normalized.title,
          duration: normalized.duration,
          audioPath: path,
          filePath: path,
          artistName: normalized.artist,
          albumTitle: normalized.album,
          genreName: normalized.genre,
        );

        if (tempSong.trackHash.isNotEmpty &&
            existingHashMap.containsKey(tempSong.trackHash)) {
          // Exact trackHash match with existing database item
          skippedDuplicates++;
          continue;
        }

        // Extract and cache artwork if available
        String? cachedCover;
        if (normalized.pictures.isNotEmpty) {
          try {
            cachedCover = await ArtworkCacheService.extractAndCacheArtwork(
              audioFilePath: path,
              pictures: normalized.pictures,
            );
          } catch (_) {}
        }

        final newSong = SongModel(
          id: 0,
          artistId: 0,
          title: normalized.title,
          duration: normalized.duration,
          audioPath: path,
          filePath: path,
          source: 'local',
          artistName: normalized.artist,
          albumTitle: normalized.album,
          genreName: normalized.genre,
          lyrics: normalized.lyrics,
          cover: cachedCover,
        );

        final insertedId = await _repository.insertOrUpdateSong(newSong);
        final persistedSong = newSong.copyWith(id: insertedId);
        newlyImported.add(persistedSong);
        importedCount++;

        // Save embedded lyrics to lyrics_cache if present
        if (normalized.lyrics != null && normalized.lyrics!.trim().isNotEmpty) {
          try {
            final lrcNorm = LrcParser.normalize(normalized.lyrics!);
            final parsed = LrcParser.parse(lrcNorm);
            final isSyn = parsed.isNotEmpty;
            await _repository.saveLyrics(
              LyricsModel(
                songId: insertedId,
                source: LyricsSource.embedded,
                plainLyrics: isSyn ? null : lrcNorm,
                syncedLyrics: isSyn ? lrcNorm : null,
                fetchedAt: DateTime.now(),
                isSynced: isSyn,
              ),
            );
          } catch (_) {}
        }

        // Add to existing lookups for subsequent files in the same batch
        existingPathMap[canonicalKey] = persistedSong;
        if (persistedSong.trackHash.isNotEmpty) {
          existingHashMap[persistedSong.trackHash] = persistedSong;
        }

        if (targetPlaylistId != null && targetPlaylistId > 0) {
          await _repository.addSongToPlaylist(targetPlaylistId, insertedId);
        }
      } catch (e) {
        debugPrint('MusicImportService: Failed to import $path: $e');
        failedCount++;
      }
    }

    onProgress?.call(
      ImportProgressUpdate(
        totalFiles: totalFiles,
        processedFiles: processedFiles,
        currentFile: 'Done',
        importedCount: importedCount,
        skippedDuplicates: skippedDuplicates,
        unsupportedCount: unsupportedCount,
        failedCount: failedCount,
        isCompleted: true,
        isCancelled: _isCancelled,
      ),
    );

    return ImportResultSummary(
      totalScanned: totalFiles + unsupportedCount,
      importedCount: importedCount,
      skippedDuplicates: skippedDuplicates,
      unsupportedCount: unsupportedCount,
      failedCount: failedCount,
      cancelled: _isCancelled,
      newlyImportedSongs: newlyImported,
    );
  }
}
