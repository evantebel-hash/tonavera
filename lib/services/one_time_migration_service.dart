import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../database/local_database_service.dart';
import '../services/api/api_service.dart';

enum MigrationStatus { notStarted, migrating, completed, failed }

class OneTimeMigrationService {
  static const String _statusKey = 'legacy_migration_status_v1';

  static Future<MigrationStatus> getStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(_statusKey);
    if (val == 'COMPLETED') return MigrationStatus.completed;
    if (val == 'MIGRATING') return MigrationStatus.migrating;
    if (val == 'FAILED') return MigrationStatus.failed;
    return MigrationStatus.notStarted;
  }

  static Future<void> setStatus(MigrationStatus status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_statusKey, status.name.toUpperCase());
  }

  static Future<void> migrateIfNeeded() async {
    final status = await getStatus();
    if (status == MigrationStatus.completed) {
      debugPrint('Migration: Already COMPLETED.');
      return;
    }

    debugPrint(
      'Migration: Starting one-time PostgreSQL legacy migration check...',
    );
    await setStatus(MigrationStatus.migrating);

    try {
      final db = await LocalDatabaseService.instance.database;

      // 1. Fetch songs from API if backend active
      Map<String, dynamic> songsRes;
      try {
        songsRes = await ApiService.get('songs');
      } catch (e) {
        debugPrint(
          'Migration: Backend API not reachable. Keeping migration status for next time. $e',
        );
        await setStatus(MigrationStatus.notStarted);
        return;
      }

      if (songsRes['status'] != true || songsRes['data'] == null) {
        await setStatus(MigrationStatus.notStarted);
        return;
      }

      final List legacySongs = songsRes['data'];
      if (legacySongs.isEmpty) {
        await setStatus(MigrationStatus.completed);
        return;
      }

      // Fetch playlists & favorites
      final playlistsRes = await ApiService.get('playlists');
      final favoritesRes = await ApiService.get('favorites');
      final historyRes = await ApiService.get('history/recently-played');

      final List legacyPlaylists =
          (playlistsRes['status'] == true && playlistsRes['data'] != null)
          ? playlistsRes['data']
          : [];
      final List legacyFavorites =
          (favoritesRes['status'] == true && favoritesRes['data'] != null)
          ? favoritesRes['data']
          : [];
      final List legacyHistory =
          (historyRes['status'] == true && historyRes['data'] != null)
          ? historyRes['data']
          : [];

      await db.transaction((txn) async {
        // Insert Artists, Albums, Genres & Songs preserving original IDs
        for (final item in legacySongs) {
          final songId = int.parse(item['id'].toString());
          final title = item['title'] ?? 'Unknown Title';
          final artistId = item['artist_id'] != null
              ? int.parse(item['artist_id'].toString())
              : null;
          final albumId = item['album_id'] != null
              ? int.parse(item['album_id'].toString())
              : null;
          final genreId = item['genre_id'] != null
              ? int.parse(item['genre_id'].toString())
              : null;
          final artistName = item['artist_name'] ?? 'Unknown Artist';
          final albumTitle = item['album_title'] ?? 'Unknown Album';
          final genreName = item['genre_name'] ?? '';
          final duration = int.parse((item['duration'] ?? 0).toString());
          final audioPath = item['audio_path'] ?? item['file_path'] ?? '';
          final filePath = item['file_path'] ?? audioPath;
          final cover = item['cover'];

          if (audioPath.isEmpty) continue;

          if (artistId != null && artistName.isNotEmpty) {
            await txn.insert('artists', {
              'id': artistId,
              'name': artistName,
              'created_at': DateTime.now().toIso8601String(),
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
          }

          if (albumId != null && albumTitle.isNotEmpty) {
            await txn.insert('albums', {
              'id': albumId,
              'artist_id': artistId,
              'title': albumTitle,
              'cover': cover,
              'created_at': DateTime.now().toIso8601String(),
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
          }

          if (genreId != null && genreName.isNotEmpty) {
            await txn.insert('genres', {
              'id': genreId,
              'name': genreName,
              'created_at': DateTime.now().toIso8601String(),
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
          }

          await txn.insert('songs', {
            'id': songId,
            'title': title,
            'artist_id': artistId,
            'album_id': albumId,
            'genre_id': genreId,
            'artist_name': artistName,
            'album_title': albumTitle,
            'genre_name': genreName,
            'duration': duration,
            'audio_path': audioPath,
            'file_path': filePath,
            'cover': cover,
            'source': item['source'] ?? 'local',
            'created_at': DateTime.now().toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }

        // Insert Playlists and Playlist Songs
        for (final p in legacyPlaylists) {
          final pid = int.parse(p['id'].toString());
          final name = p['name'] ?? 'Playlist';
          final desc = p['description'];

          await txn.insert('playlists', {
            'id': pid,
            'name': name,
            'description': desc,
            'created_at': DateTime.now().toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.ignore);

          if (p['songs'] != null && p['songs'] is List) {
            final List pSongs = p['songs'];
            for (int i = 0; i < pSongs.length; i++) {
              final sid = int.parse(pSongs[i]['id'].toString());
              await txn.insert('playlist_songs', {
                'playlist_id': pid,
                'song_id': sid,
                'position_order': i,
              }, conflictAlgorithm: ConflictAlgorithm.ignore);
            }
          }
        }

        // Insert Favorites
        for (final fav in legacyFavorites) {
          final sid = int.parse(fav['id'].toString());
          await txn.insert('favorites', {
            'song_id': sid,
            'created_at': DateTime.now().toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }

        // Insert History
        for (final h in legacyHistory) {
          final sid = int.parse(h['id'].toString());
          await txn.insert('listening_histories', {
            'song_id': sid,
            'started_at': h['started_at'] ?? DateTime.now().toIso8601String(),
            'duration_played': int.parse((h['duration'] ?? 0).toString()),
            'completed': 1,
          });
        }
      });

      // VALIDATION
      final validSongs = await db.rawQuery('''
        SELECT COUNT(*) as cnt FROM playlist_songs ps
        LEFT JOIN songs s ON ps.song_id = s.id
        WHERE s.id IS NULL
      ''');

      final orphanSongs = (validSongs.first['cnt'] as int? ?? 0);

      if (orphanSongs == 0) {
        await setStatus(MigrationStatus.completed);
        debugPrint('Migration: COMPLETED & VALIDATED successfully!');
      } else {
        await setStatus(MigrationStatus.failed);
        debugPrint(
          'Migration: FAILED validation due to $orphanSongs orphan songs.',
        );
      }
    } catch (e) {
      debugPrint('Migration error: $e');
      await setStatus(MigrationStatus.failed);
    }
  }
}
