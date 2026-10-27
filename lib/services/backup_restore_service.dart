import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../database/local_database_service.dart';
import '../models/backup_model.dart';

class RestorePreview {
  final int songsCount;
  final int artistsCount;
  final int albumsCount;
  final int genresCount;
  final int playlistsCount;
  final int favoritesCount;
  final int historyCount;
  final String createdAt;
  final String platform;
  final bool isValidChecksum;
  final int missingFilesCount;

  RestorePreview({
    required this.songsCount,
    required this.artistsCount,
    required this.albumsCount,
    required this.genresCount,
    required this.playlistsCount,
    required this.favoritesCount,
    required this.historyCount,
    required this.createdAt,
    required this.platform,
    required this.isValidChecksum,
    required this.missingFilesCount,
  });
}

class BackupRestoreService {
  static final BackupRestoreService instance = BackupRestoreService._internal();
  BackupRestoreService._internal();

  /// Creates a complete JSON backup package string containing all database tables & metadata
  Future<String> createBackupJson() async {
    final db = await LocalDatabaseService.instance.database;

    final songs = await db.query('songs');
    final artists = await db.query('artists');
    final albums = await db.query('albums');
    final genres = await db.query('genres');
    final playlists = await db.query('playlists');
    final playlistSongs = await db.query('playlist_songs');
    final favorites = await db.query('favorites');
    final listeningHistories = await db.query('listening_histories');
    final playerStates = await db.query('player_states');
    final playerQueues = await db.query('player_queues');

    final tempPkg = BackupPackage(
      manifest: BackupManifest(
        createdAt: DateTime.now().toIso8601String(),
        platform: Platform.operatingSystem,
        checksum: '',
        contains: {
          'library': true,
          'playlists': true,
          'favorites': true,
          'history': true,
          'playerState': true,
        },
      ),
      songs: songs,
      artists: artists,
      albums: albums,
      genres: genres,
      playlists: playlists,
      playlistSongs: playlistSongs,
      favorites: favorites,
      listeningHistories: listeningHistories,
      playerState: playerStates.isNotEmpty ? playerStates.first : null,
      playerQueues: playerQueues,
    );

    final checksum = tempPkg.calculateChecksum();

    final finalPkg = BackupPackage(
      manifest: BackupManifest(
        createdAt: tempPkg.manifest.createdAt,
        platform: tempPkg.manifest.platform,
        checksum: checksum,
        contains: tempPkg.manifest.contains,
      ),
      songs: songs,
      artists: artists,
      albums: albums,
      genres: genres,
      playlists: playlists,
      playlistSongs: playlistSongs,
      favorites: favorites,
      listeningHistories: listeningHistories,
      playerState: tempPkg.playerState,
      playerQueues: playerQueues,
    );

    return const JsonEncoder.withIndent('  ').convert(finalPkg.toJson());
  }

  /// Parses and generates a preview of the backup content without mutating local database
  RestorePreview previewBackup(String jsonStr) {
    final Map<String, dynamic> decoded = json.decode(jsonStr);
    final pkg = BackupPackage.fromJson(decoded);

    final checksum = pkg.calculateChecksum();
    final isValidChecksum =
        pkg.manifest.checksum.isEmpty || pkg.manifest.checksum == checksum;

    int missingCount = 0;
    for (final songMap in pkg.songs) {
      final audioPath = (songMap['audio_path'] ?? songMap['file_path'] ?? '')
          .toString();
      if (audioPath.isNotEmpty && !File(audioPath).existsSync()) {
        missingCount++;
      }
    }

    return RestorePreview(
      songsCount: pkg.songs.length,
      artistsCount: pkg.artists.length,
      albumsCount: pkg.albums.length,
      genresCount: pkg.genres.length,
      playlistsCount: pkg.playlists.length,
      favoritesCount: pkg.favorites.length,
      historyCount: pkg.listeningHistories.length,
      createdAt: pkg.manifest.createdAt,
      platform: pkg.manifest.platform,
      isValidChecksum: isValidChecksum,
      missingFilesCount: missingCount,
    );
  }

  /// Restores the library within an atomic transaction with path remapping option
  Future<bool> restoreBackup(
    String jsonStr, {
    Map<String, String>? pathRemap, // e.g. {'C:\\OldPath': 'D:\\NewPath'}
  }) async {
    final Map<String, dynamic> decoded = json.decode(jsonStr);
    final pkg = BackupPackage.fromJson(decoded);

    final db = await LocalDatabaseService.instance.database;

    try {
      await db.transaction((txn) async {
        // Clear active tables safely
        await txn.delete('playlist_songs');
        await txn.delete('playlists');
        await txn.delete('favorites');
        await txn.delete('listening_histories');
        await txn.delete('player_queues');
        await txn.delete('player_states');
        await txn.delete('songs');
        await txn.delete('albums');
        await txn.delete('artists');
        await txn.delete('genres');

        // Restore Genres
        for (final item in pkg.genres) {
          await txn.insert(
            'genres',
            item,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        // Restore Artists
        for (final item in pkg.artists) {
          await txn.insert(
            'artists',
            item,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        // Restore Albums
        for (final item in pkg.albums) {
          await txn.insert(
            'albums',
            item,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        // Restore Songs with path remapping
        for (final item in pkg.songs) {
          final mutableItem = Map<String, dynamic>.from(item);
          if (pathRemap != null && pathRemap.isNotEmpty) {
            String audioPath = mutableItem['audio_path']?.toString() ?? '';
            String filePath = mutableItem['file_path']?.toString() ?? '';

            for (final entry in pathRemap.entries) {
              if (audioPath.startsWith(entry.key)) {
                audioPath = audioPath.replaceFirst(entry.key, entry.value);
              }
              if (filePath.startsWith(entry.key)) {
                filePath = filePath.replaceFirst(entry.key, entry.value);
              }
            }
            mutableItem['audio_path'] = audioPath;
            mutableItem['file_path'] = filePath;
          }
          await txn.insert(
            'songs',
            mutableItem,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        // Restore Playlists
        for (final item in pkg.playlists) {
          await txn.insert(
            'playlists',
            item,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        // Restore Playlist Songs
        for (final item in pkg.playlistSongs) {
          await txn.insert(
            'playlist_songs',
            item,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        // Restore Favorites
        for (final item in pkg.favorites) {
          await txn.insert(
            'favorites',
            item,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        // Restore Listening Histories
        for (final item in pkg.listeningHistories) {
          await txn.insert(
            'listening_histories',
            item,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        // Restore Player States
        if (pkg.playerState != null) {
          await txn.insert(
            'player_states',
            pkg.playerState!,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        // Restore Player Queues
        for (final item in pkg.playerQueues) {
          await txn.insert(
            'player_queues',
            item,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });

      return true;
    } catch (e) {
      debugPrint('BackupRestoreService: Restore transaction failed: $e');
      rethrow;
    }
  }
}
