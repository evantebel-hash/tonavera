import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../database/local_database_service.dart';
import 'sync_outbox_repository.dart';
import '../models/song_model.dart';
import '../models/album_model.dart';
import '../models/artist_model.dart';
import '../models/genre_model.dart';
import '../models/playlist_model.dart';
import '../services/metadata/metadata_model.dart';
import '../services/metadata/spotify_url_parser.dart';

class LocalMusicRepository {
  Future<Database> get _db async =>
      await LocalDatabaseService.instance.database;

  // --- SONGS ---
  Future<List<SongModel>> getSongs({
    String? query,
    int? genreId,
    int? artistId,
    int? albumId,
  }) async {
    final db = await _db;
    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    if (query != null && query.trim().isNotEmpty) {
      whereClause +=
          ' AND (title LIKE ? OR artist_name LIKE ? OR album_title LIKE ?)';
      final q = '%${query.trim()}%';
      whereArgs.addAll([q, q, q]);
    }
    if (genreId != null) {
      whereClause += ' AND genre_id = ?';
      whereArgs.add(genreId);
    }
    if (artistId != null) {
      whereClause += ' AND artist_id = ?';
      whereArgs.add(artistId);
    }
    if (albumId != null) {
      whereClause += ' AND album_id = ?';
      whereArgs.add(albumId);
    }

    final maps = await db.query(
      'songs',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'title ASC',
    );
    return maps.map((map) => SongModel.fromJson(map)).toList();
  }

  Future<SongModel?> getSongById(int id) async {
    final db = await _db;
    final maps = await db.query('songs', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return SongModel.fromJson(maps.first);
  }

  Future<int> insertOrUpdateSong(SongModel song) async {
    final db = await _db;
    final existing = await db.query(
      'songs',
      where: 'audio_path = ?',
      whereArgs: [song.audioPath],
    );

    // Handle artist & album relation
    int? artistId = song.artistId > 0 ? song.artistId : null;
    if (artistId == null &&
        song.artistName != null &&
        song.artistName!.isNotEmpty) {
      artistId = await getOrCreateArtist(song.artistName!);
    }

    int? albumId = song.albumId;
    if (albumId == null &&
        song.albumTitle != null &&
        song.albumTitle!.isNotEmpty &&
        artistId != null) {
      albumId = await getOrCreateAlbum(
        song.albumTitle!,
        artistId,
        cover: song.cover,
      );
    }

    int? genreId = song.genreId;
    if (genreId == null &&
        song.genreName != null &&
        song.genreName!.isNotEmpty) {
      genreId = await getOrCreateGenre(song.genreName!);
    }

    final map = {
      'title': song.title,
      'artist_id': artistId,
      'album_id': albumId,
      'genre_id': genreId,
      'artist_name': song.artistName ?? 'Unknown Artist',
      'album_title': song.albumTitle ?? 'Unknown Album',
      'genre_name': song.genreName ?? '',
      'duration': song.duration,
      'audio_path': song.audioPath,
      'file_path': song.filePath ?? song.audioPath,
      'cover': song.cover,
      'source': song.source,
      'created_at': DateTime.now().toIso8601String(),
    };

    if (existing.isNotEmpty) {
      final id = existing.first['id'] as int;
      await db.update('songs', map, where: 'id = ?', whereArgs: [id]);
      return id;
    } else {
      if (song.id > 0) {
        map['id'] = song.id;
        await db.insert(
          'songs',
          map,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return song.id;
      } else {
        return await db.insert('songs', map);
      }
    }
  }

  // --- ARTISTS ---
  Future<int> getOrCreateArtist(String name, {String? image}) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return 0;
    final db = await _db;
    final maps = await db.rawQuery(
      'SELECT * FROM artists WHERE LOWER(TRIM(name)) = LOWER(TRIM(?))',
      [cleanName],
    );
    if (maps.isNotEmpty) {
      final id = maps.first['id'] as int;
      if (image != null &&
          image.isNotEmpty &&
          (maps.first['image'] == null ||
              (maps.first['image'] as String).isEmpty)) {
        await db.update(
          'artists',
          {'image': image},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
      return id;
    }
    return await db.insert('artists', {
      'name': cleanName,
      'image': image,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<ArtistModel>> getArtists() async {
    final db = await _db;
    final maps = await db.query('artists', orderBy: 'name ASC');
    return maps.map((e) => ArtistModel.fromJson(e)).toList();
  }

  // --- ALBUMS ---
  Future<int> getOrCreateAlbum(
    String title,
    int artistId, {
    String? cover,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) return 0;
    final db = await _db;
    final maps = await db.rawQuery(
      'SELECT * FROM albums WHERE LOWER(TRIM(title)) = LOWER(TRIM(?)) AND artist_id = ?',
      [cleanTitle, artistId],
    );
    if (maps.isNotEmpty) {
      final id = maps.first['id'] as int;
      if (cover != null &&
          cover.isNotEmpty &&
          (maps.first['cover'] == null ||
              (maps.first['cover'] as String).isEmpty)) {
        await db.update(
          'albums',
          {'cover': cover},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
      return id;
    }
    return await db.insert('albums', {
      'title': cleanTitle,
      'artist_id': artistId,
      'cover': cover,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<AlbumModel>> getAlbums() async {
    final db = await _db;
    final maps = await db.query('albums', orderBy: 'title ASC');
    return maps.map((e) => AlbumModel.fromJson(e)).toList();
  }

  // --- GENRES ---
  Future<int> getOrCreateGenre(String name) async {
    final db = await _db;
    final maps = await db.query('genres', where: 'name = ?', whereArgs: [name]);
    if (maps.isNotEmpty) return maps.first['id'] as int;
    return await db.insert('genres', {
      'name': name,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<GenreModel>> getGenres() async {
    final db = await _db;
    final maps = await db.query('genres', orderBy: 'name ASC');
    return maps.map((e) => GenreModel.fromJson(e)).toList();
  }

  // --- PLAYLISTS ---
  Future<List<PlaylistModel>> getPlaylists() async {
    final db = await _db;
    final maps = await db.query('playlists', orderBy: 'created_at DESC');
    final playlists = <PlaylistModel>[];

    for (final map in maps) {
      final pid = map['id'] as int;
      final songMaps = await db.rawQuery(
        '''
        SELECT s.* FROM songs s
        JOIN playlist_songs ps ON s.id = ps.song_id
        WHERE ps.playlist_id = ?
        ORDER BY ps.position_order ASC
      ''',
        [pid],
      );
      final songs = songMaps.map((e) => SongModel.fromJson(e)).toList();
      playlists.add(PlaylistModel.fromJson(map, songs: songs));
    }
    return playlists;
  }

  Future<PlaylistModel?> getPlaylistById(int id) async {
    final db = await _db;
    final maps = await db.query('playlists', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    final songMaps = await db.rawQuery(
      '''
      SELECT s.* FROM songs s
      JOIN playlist_songs ps ON s.id = ps.song_id
      WHERE ps.playlist_id = ?
      ORDER BY ps.position_order ASC
    ''',
      [id],
    );
    final songs = songMaps.map((e) => SongModel.fromJson(e)).toList();
    return PlaylistModel.fromJson(maps.first, songs: songs);
  }

  Future<Database> get database async => await _db;

  Future<int> createPlaylist(
    String name, {
    String? description,
    String playlistType = 'normal',
    String? smartConfig,
  }) async {
    final db = await _db;
    return await db.insert('playlists', {
      'name': name,
      'description': description,
      'playlist_type': playlistType,
      'smart_config': smartConfig,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> createSmartPlaylist({
    required String name,
    String? description,
    required dynamic config,
  }) async {
    final configStr = config is String ? config : config.toJsonString();
    return await createPlaylist(
      name,
      description: description,
      playlistType: 'smart',
      smartConfig: configStr,
    );
  }

  Future<void> updateSmartPlaylist({
    required int playlistId,
    required String name,
    String? description,
    required dynamic config,
  }) async {
    final db = await _db;
    final configStr = config is String ? config : config.toJsonString();
    await db.update(
      'playlists',
      {'name': name, 'description': description, 'smart_config': configStr},
      where: 'id = ?',
      whereArgs: [playlistId],
    );
  }

  Future<void> saveLyrics(dynamic lyrics) async {
    final db = await _db;
    final map = lyrics is Map<String, dynamic>
        ? lyrics
        : (lyrics.toMap() as Map<String, dynamic>);
    await db.insert(
      'lyrics_cache',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getLyricsBySongId(int songId) async {
    final db = await _db;
    final maps = await db.query(
      'lyrics_cache',
      where: 'song_id = ?',
      whereArgs: [songId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return maps.first;
  }

  Future<void> addSongToPlaylist(int playlistId, int songId) async {
    final db = await _db;
    final maxPosRes = await db.rawQuery(
      'SELECT MAX(position_order) as max_pos FROM playlist_songs WHERE playlist_id = ?',
      [playlistId],
    );
    int nextPos = 0;
    if (maxPosRes.isNotEmpty && maxPosRes.first['max_pos'] != null) {
      nextPos = (maxPosRes.first['max_pos'] as int) + 1;
    }
    await db.insert('playlist_songs', {
      'playlist_id': playlistId,
      'song_id': songId,
      'position_order': nextPos,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// Bulk add ordered list of songs to a playlist preserving exact order and preventing duplicates.
  Future<int> addSongsToPlaylist(int playlistId, List<int> songIds) async {
    if (songIds.isEmpty) return 0;
    final db = await _db;
    int addedCount = 0;

    await db.transaction((txn) async {
      final maxPosRes = await txn.rawQuery(
        'SELECT MAX(position_order) as max_pos FROM playlist_songs WHERE playlist_id = ?',
        [playlistId],
      );
      int nextPos = 0;
      if (maxPosRes.isNotEmpty && maxPosRes.first['max_pos'] != null) {
        nextPos = (maxPosRes.first['max_pos'] as int) + 1;
      }

      for (final sId in songIds) {
        final inserted = await txn.insert('playlist_songs', {
          'playlist_id': playlistId,
          'song_id': sId,
          'position_order': nextPos,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        if (inserted > 0) {
          nextPos++;
          addedCount++;
        }
      }
    });

    return addedCount;
  }

  /// Bulk add ordered list of songs to multiple playlists within a single atomic transaction.
  Future<Map<int, int>> addSongsToMultiplePlaylists(
    List<int> playlistIds,
    List<int> songIds,
  ) async {
    final results = <int, int>{};
    if (playlistIds.isEmpty || songIds.isEmpty) return results;
    final db = await _db;

    await db.transaction((txn) async {
      for (final pId in playlistIds) {
        final maxPosRes = await txn.rawQuery(
          'SELECT MAX(position_order) as max_pos FROM playlist_songs WHERE playlist_id = ?',
          [pId],
        );
        int nextPos = 0;
        if (maxPosRes.isNotEmpty && maxPosRes.first['max_pos'] != null) {
          nextPos = (maxPosRes.first['max_pos'] as int) + 1;
        }

        int count = 0;
        for (final sId in songIds) {
          final inserted = await txn.insert('playlist_songs', {
            'playlist_id': pId,
            'song_id': sId,
            'position_order': nextPos,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          if (inserted > 0) {
            nextPos++;
            count++;
          }
        }
        results[pId] = count;
      }
    });

    return results;
  }

  Future<void> removeSongFromPlaylist(int playlistId, int songId) async {
    final db = await _db;
    await db.delete(
      'playlist_songs',
      where: 'playlist_id = ? AND song_id = ?',
      whereArgs: [playlistId, songId],
    );
  }

  /// Atomically reorder songs in a playlist by rewriting position_order
  Future<void> reorderPlaylistSongs(
    int playlistId,
    List<int> orderedSongIds,
  ) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (int i = 0; i < orderedSongIds.length; i++) {
        await txn.update(
          'playlist_songs',
          {'position_order': i},
          where: 'playlist_id = ? AND song_id = ?',
          whereArgs: [playlistId, orderedSongIds[i]],
        );
      }
    });
  }

  /// Bulk remove multiple songs from a playlist within a single transaction.
  Future<int> removeSongsFromPlaylist(int playlistId, List<int> songIds) async {
    if (songIds.isEmpty) return 0;
    final db = await _db;
    int removedCount = 0;

    await db.transaction((txn) async {
      final placeholders = List.filled(songIds.length, '?').join(',');
      removedCount = await txn.delete(
        'playlist_songs',
        where: 'playlist_id = ? AND song_id IN ($placeholders)',
        whereArgs: [playlistId, ...songIds],
      );
    });

    return removedCount;
  }

  Future<void> deletePlaylist(int playlistId) async {
    final db = await _db;
    await db.delete('playlists', where: 'id = ?', whereArgs: [playlistId]);
  }

  // --- FAVORITES ---
  Future<List<SongModel>> getFavorites() async {
    final db = await _db;
    final maps = await db.rawQuery('''
      SELECT s.* FROM songs s
      JOIN favorites f ON s.id = f.song_id
      ORDER BY f.created_at DESC
    ''');
    return maps
        .map((e) => SongModel.fromJson(e).copyWith(isFavorite: true))
        .toList();
  }

  Future<void> addFavorite(int songId) async {
    final db = await _db;
    await db.insert('favorites', {
      'song_id': songId,
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    try {
      final song = await getSongById(songId);
      if (song != null) {
        await SyncOutboxRepository().enqueue(
          SyncOutboxItem(
            entityType: 'favorite',
            entityUuid: songId.toString(),
            operation: 'CREATE',
            payloadJson: json.encode({
              'song_id': songId,
              'track_hash': song.trackHash,
            }),
            createdAtUtc: DateTime.now().toUtc().toIso8601String(),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> removeFavorite(int songId) async {
    final db = await _db;
    await db.delete('favorites', where: 'song_id = ?', whereArgs: [songId]);

    try {
      final song = await getSongById(songId);
      await SyncOutboxRepository().enqueue(
        SyncOutboxItem(
          entityType: 'favorite',
          entityUuid: songId.toString(),
          operation: 'DELETE',
          payloadJson: json.encode({
            'song_id': songId,
            'track_hash': song?.trackHash ?? '',
          }),
          createdAtUtc: DateTime.now().toUtc().toIso8601String(),
        ),
      );
    } catch (_) {}
  }

  // --- HELPER ALIASES ---
  Future<List<SongModel>> getAllSongs() => getSongs();
  Future<List<PlaylistModel>> getAllPlaylists() => getPlaylists();
  Future<List<SongModel>> getPlaylistSongs(int playlistId) async {
    final pl = await getPlaylistById(playlistId);
    return pl?.songs ?? [];
  }

  Future<void> deleteSong(int id) async {
    final db = await _db;
    await db.delete('songs', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> toggleFavorite(int songId) async {
    final db = await _db;
    final existing = await db.query(
      'favorites',
      where: 'song_id = ?',
      whereArgs: [songId],
    );
    if (existing.isNotEmpty) {
      await removeFavorite(songId);
    } else {
      await addFavorite(songId);
    }
  }

  Future<void> addListeningHistory({
    required int songId,
    required DateTime startedAt,
    required DateTime endedAt,
    required int durationPlayed,
  }) => recordHistory(
    songId: songId,
    startedAt: startedAt,
    endedAt: endedAt,
    durationPlayed: durationPlayed,
  );

  // --- LISTENING HISTORY & RECENTLY PLAYED ---
  Future<void> recordHistory({
    required int songId,
    required DateTime startedAt,
    required DateTime endedAt,
    required int durationPlayed,
    bool completed = false,
    bool skipped = false,
  }) async {
    final db = await _db;
    await db.insert('listening_histories', {
      'song_id': songId,
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt.toIso8601String(),
      'duration_played': durationPlayed,
      'completed': completed ? 1 : 0,
      'skipped': skipped ? 1 : 0,
    });

    try {
      final song = await getSongById(songId);
      if (song != null) {
        await SyncOutboxRepository().enqueue(
          SyncOutboxItem(
            entityType: 'history',
            entityUuid: DateTime.now().millisecondsSinceEpoch.toString(),
            operation: 'CREATE',
            payloadJson: json.encode({
              'song_id': songId,
              'track_hash': song.trackHash,
              'started_at': startedAt.toUtc().toIso8601String(),
              'ended_at': endedAt.toUtc().toIso8601String(),
              'duration_played': durationPlayed,
              'completed': completed,
              'skipped': skipped,
            }),
            createdAtUtc: DateTime.now().toUtc().toIso8601String(),
          ),
        );
      }
    } catch (_) {}
  }

  Future<List<SongModel>> getRecentlyPlayed({int limit = 20}) async {
    final db = await _db;
    final maps = await db.rawQuery(
      '''
      SELECT s.*, lh.started_at FROM songs s
      JOIN listening_histories lh ON s.id = lh.song_id
      ORDER BY lh.started_at DESC
      LIMIT ?
    ''',
      [limit],
    );
    return maps.map((e) => SongModel.fromJson(e)).toList();
  }

  Future<int> clearListeningHistory() async {
    final db = await _db;
    return await db.delete('listening_histories');
  }

  // --- PERSISTENCE: PLAYER STATE & QUEUE ---
  Future<void> savePlayerState({
    int? currentSongId,
    int positionSeconds = 0,
    bool isPlaying = false,
    bool isShuffle = false,
    String repeatMode = 'off',
    double volume = 1.0,
  }) async {
    final db = await _db;
    await db.insert('player_states', {
      'id': 1,
      'current_song_id': currentSongId,
      'position_seconds': positionSeconds,
      'is_playing': isPlaying ? 1 : 0,
      'is_shuffle': isShuffle ? 1 : 0,
      'repeat_mode': repeatMode,
      'volume': volume,
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getPlayerState() async {
    final db = await _db;
    final maps = await db.query('player_states', where: 'id = 1');
    if (maps.isEmpty) return null;
    return maps.first;
  }

  Future<void> savePlayerQueue(List<int> songIds) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('player_queues');
      for (int i = 0; i < songIds.length; i++) {
        await txn.insert('player_queues', {
          'position_order': i,
          'song_id': songIds[i],
        });
      }
    });
  }

  Future<List<SongModel>> getPlayerQueue() async {
    final db = await _db;
    final maps = await db.rawQuery('''
      SELECT s.* FROM songs s
      JOIN player_queues pq ON s.id = pq.song_id
      ORDER BY pq.position_order ASC
    ''');
    return maps.map((e) => SongModel.fromJson(e)).toList();
  }

  // --- LOCAL USERS ---
  Future<Map<String, dynamic>> getOrCreateLocalUser(
    String username,
    String email,
  ) async {
    final db = await _db;
    final maps = await db.query(
      'local_users',
      where: 'username = ?',
      whereArgs: [username],
    );
    if (maps.isNotEmpty) {
      return Map<String, dynamic>.from(maps.first);
    }
    final id = await db.insert('local_users', {
      'username': username,
      'email': email,
      'created_at': DateTime.now().toIso8601String(),
    });
    return {
      'id': id,
      'username': username,
      'email': email,
      'avatar': null,
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  // --- QUERIES FOR ARTISTS & ALBUMS ---
  Future<List<SongModel>> getSongsByArtistId(int artistId) async {
    final db = await _db;
    final maps = await db.query(
      'songs',
      where: 'artist_id = ?',
      whereArgs: [artistId],
      orderBy: 'title ASC',
    );
    return maps.map((e) => SongModel.fromJson(e)).toList();
  }

  Future<List<SongModel>> getSongsByAlbumId(int albumId) async {
    final db = await _db;
    final maps = await db.query(
      'songs',
      where: 'album_id = ?',
      whereArgs: [albumId],
      orderBy: 'id ASC',
    );
    return maps.map((e) => SongModel.fromJson(e)).toList();
  }

  Future<List<AlbumModel>> getAlbumsByArtistId(int artistId) async {
    final db = await _db;
    final maps = await db.query(
      'albums',
      where: 'artist_id = ?',
      whereArgs: [artistId],
      orderBy: 'release_year DESC, title ASC',
    );
    return maps.map((e) => AlbumModel.fromJson(e)).toList();
  }

  Future<ArtistModel?> getArtistById(int id) async {
    final db = await _db;
    final maps = await db.query('artists', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return ArtistModel.fromJson(maps.first);
  }

  Future<AlbumModel?> getAlbumById(int id) async {
    final db = await _db;
    final maps = await db.query('albums', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return AlbumModel.fromJson(maps.first);
  }

  // --- TRANSACTIONAL IMPORT METADATA ---
  /// Imports normalized [MusicMetadataResult] into local database atomically.
  /// Enforces:
  /// 1. Provider & source_id deduplication: (provider = ? AND source_id = ?)
  /// 2. Relational integrity: Artist -> Album -> Song
  /// 3. Overwrite policy: If [overwriteExisting] is true, updates fields; else skips or preserves non-empty fields.
  /// 4. Database transaction: all items succeed or none are committed.
  Future<Map<String, int>> importMetadata({
    required dynamic metadata, // MusicMetadataResult or duck-typed
    bool overwriteExisting = false,
  }) async {
    final db = await _db;

    // Collect tracks to import
    final bool isArtistOnly =
        (metadata.type == SpotifyEntityType.artist) ||
        (metadata is MusicMetadataResult && metadata.typeString == 'artist');

    final List<dynamic> tracks = [];
    if (metadata.trackList != null && (metadata.trackList as List).isNotEmpty) {
      tracks.addAll(metadata.trackList);
    } else if (!isArtistOnly) {
      tracks.add(metadata);
    }

    int songsCreated = 0;
    int songsUpdated = 0;
    int albumsCreated = 0;
    int artistsCreated = 0;

    await db.transaction((txn) async {
      final String now = DateTime.now().toIso8601String();

      // If importing an artist profile with no trackList, import the artist record directly
      if (isArtistOnly && tracks.isEmpty) {
        final String artistName =
            (metadata.title ?? metadata.artist ?? 'Unknown Artist')
                .toString()
                .trim();
        if (artistName.isNotEmpty) {
          final String provider = (metadata.effectiveProvider ?? 'unknown')
              .toString();
          final String? sourceId = metadata.effectiveSourceId;
          final String? artistImage =
              metadata.effectiveArtistArtworkUrl ?? metadata.artistArtworkUrl;

          int resolvedId = 0;
          if (provider == 'spotify' &&
              sourceId != null &&
              sourceId.isNotEmpty) {
            final q = await txn.query(
              'artists',
              where: 'spotify_id = ?',
              whereArgs: [sourceId],
            );
            if (q.isNotEmpty) resolvedId = q.first['id'] as int;
          } else if (provider == 'youtube' &&
              sourceId != null &&
              sourceId.isNotEmpty) {
            final q = await txn.query(
              'artists',
              where: 'youtube_id = ?',
              whereArgs: [sourceId],
            );
            if (q.isNotEmpty) resolvedId = q.first['id'] as int;
          }
          if (resolvedId == 0) {
            final q = await txn.rawQuery(
              'SELECT * FROM artists WHERE LOWER(TRIM(name)) = LOWER(TRIM(?))',
              [artistName],
            );
            if (q.isNotEmpty) resolvedId = q.first['id'] as int;
          }

          if (resolvedId > 0) {
            final updateMap = <String, dynamic>{};
            final existingArtistRows = await txn.query(
              'artists',
              where: 'id = ?',
              whereArgs: [resolvedId],
            );
            final existingImg = existingArtistRows.isNotEmpty
                ? existingArtistRows.first['image'] as String?
                : null;
            if (artistImage != null &&
                (overwriteExisting ||
                    existingImg == null ||
                    existingImg.isEmpty)) {
              updateMap['image'] = artistImage;
            }
            if (provider == 'spotify' &&
                sourceId != null &&
                sourceId.isNotEmpty) {
              updateMap['spotify_id'] = sourceId;
            } else if (provider == 'youtube' &&
                sourceId != null &&
                sourceId.isNotEmpty) {
              updateMap['youtube_id'] = sourceId;
            }
            if (updateMap.isNotEmpty) {
              await txn.update(
                'artists',
                updateMap,
                where: 'id = ?',
                whereArgs: [resolvedId],
              );
            }
          } else {
            await txn.insert('artists', {
              'name': artistName,
              'image': artistImage,
              'spotify_id': (provider == 'spotify' && sourceId != null)
                  ? sourceId
                  : null,
              'youtube_id': (provider == 'youtube' && sourceId != null)
                  ? sourceId
                  : null,
              'created_at': now,
            });
            artistsCreated++;
          }
        }
        return;
      }
      for (final t in tracks) {
        final String title = (t.title ?? '').toString().trim();
        if (title.isEmpty) continue;

        final bool isAlbumMetadata =
            (metadata.type == SpotifyEntityType.album) ||
            (metadata is MusicMetadataResult && metadata.typeString == 'album');
        final String albumTitle =
            (t.album ?? (isAlbumMetadata ? metadata.title : 'Single'))
                .toString()
                .trim();
        final String provider =
            (t.effectiveProvider ?? metadata.effectiveProvider ?? 'unknown')
                .toString();
        final String sourceId = (t.effectiveSourceId ?? '').toString();
        final int duration = (t.duration is num)
            ? (t.duration as num).toInt()
            : 0;
        final int? releaseYear = t.releaseYear ?? metadata.releaseYear;
        final String now = DateTime.now().toIso8601String();

        // ---------------------------------------------------------
        // BUG 1 FIX: STRICT ARTWORK SEPARATION BY ENTITY
        // ---------------------------------------------------------
        // 1. Track artwork priority:
        //    a. Valid track-specific artwork
        //    b. Album / single artwork
        //    c. Neutral null fallback (never artist profile photo!)
        final String? trackCover =
            t.effectiveTrackArtworkUrl ??
            (isAlbumMetadata
                ? (metadata.effectiveAlbumArtworkUrl ??
                      metadata.albumArtworkUrl)
                : null);

        // 2. Album cover priority:
        //    a. Track's albumArtworkUrl
        //    b. Metadata's albumArtworkUrl if parent is album
        //    (Never artist profile photo!)
        final String? albumCover =
            t.effectiveAlbumArtworkUrl ??
            (isAlbumMetadata
                ? (metadata.effectiveAlbumArtworkUrl ??
                      metadata.albumArtworkUrl)
                : null) ??
            trackCover;

        // 3. Artist artwork:
        //    ONLY valid artist profile photo from provider
        final String? artistImage = (metadata.type == SpotifyEntityType.artist)
            ? (metadata.effectiveArtistArtworkUrl ?? metadata.artistArtworkUrl)
            : null;

        // ---------------------------------------------------------
        // BUG 2 FIX: COLLABORATION & MULTI-ARTIST RESOLUTION
        // ---------------------------------------------------------
        // Resolve distinct artists from structured list or parse carefully
        List<ArtistMetadataInfo> trackArtists = [];
        final dynamic rawArtistList = t.artistList;
        if (rawArtistList is List && rawArtistList.isNotEmpty) {
          trackArtists = rawArtistList.whereType<ArtistMetadataInfo>().toList();
        }
        if (trackArtists.isEmpty && metadata.type == SpotifyEntityType.artist) {
          final dynamic metaArtistList = metadata.artistList;
          if (metaArtistList is List && metaArtistList.isNotEmpty) {
            trackArtists = metaArtistList
                .whereType<ArtistMetadataInfo>()
                .toList();
          }
        }
        if (trackArtists.isEmpty) {
          final dynamic rawArtists = t.artists;
          if (rawArtists is List && rawArtists.isNotEmpty) {
            trackArtists = rawArtists
                .map<ArtistMetadataInfo>(
                  (name) => ArtistMetadataInfo(
                    name: name.toString(),
                    provider: provider,
                  ),
                )
                .toList();
          }
        }
        if (trackArtists.isEmpty) {
          // Fallback parsing from string without naively splitting on commas/ampersands inside band names
          final rawDisplay =
              (t.displayArtist.isNotEmpty
                      ? t.displayArtist
                      : (t.artist ?? metadata.artist ?? 'Unknown Artist'))
                  .toString()
                  .trim();
          trackArtists = _extractArtistsFromDisplayString(rawDisplay, provider);
        }

        // Full display string for SongModel.artist_name
        final String displayArtistString = t.displayArtist.isNotEmpty
            ? t.displayArtist
            : (trackArtists.isNotEmpty
                  ? trackArtists.map((a) => a.name).join(', ')
                  : 'Unknown Artist');

        // Resolve or create each individual artist entity in DB
        int primaryArtistId = 0;
        for (int i = 0; i < trackArtists.length; i++) {
          final artInfo = trackArtists[i];
          final aName = artInfo.name.trim();
          if (aName.isEmpty) continue;

          final aId =
              (i == 0 &&
                  (artInfo.id == null || artInfo.id!.isEmpty) &&
                  metadata.type == SpotifyEntityType.artist)
              ? metadata.effectiveSourceId
              : artInfo.id;
          final aProvider = artInfo.provider ?? provider;
          final aArt = (i == 0)
              ? (artInfo.artworkUrl ?? artistImage)
              : artInfo.artworkUrl;

          int resolvedId = 0;

          // 1. Try matching by provider + provider artist ID first (strongest identity)
          if (aId != null && aId.isNotEmpty) {
            final idCol = (aProvider == 'spotify')
                ? 'spotify_id'
                : (aProvider == 'youtube' ? 'youtube_id' : null);
            if (idCol != null) {
              final queryById = await txn.rawQuery(
                'SELECT * FROM artists WHERE $idCol = ?',
                [aId],
              );
              if (queryById.isNotEmpty) {
                resolvedId = queryById.first['id'] as int;
                // Update missing image if available
                if (aArt != null &&
                    (queryById.first['image'] == null ||
                        (queryById.first['image'] as String).isEmpty)) {
                  await txn.update(
                    'artists',
                    {'image': aArt},
                    where: 'id = ?',
                    whereArgs: [resolvedId],
                  );
                }
              }
            }
          }

          // 2. Fallback matching by normalized artist name
          if (resolvedId == 0) {
            final queryByName = await txn.rawQuery(
              'SELECT * FROM artists WHERE LOWER(TRIM(name)) = LOWER(TRIM(?))',
              [aName],
            );
            if (queryByName.isNotEmpty) {
              resolvedId = queryByName.first['id'] as int;
              final updateMap = <String, dynamic>{};
              if (aArt != null &&
                  (queryByName.first['image'] == null ||
                      (queryByName.first['image'] as String).isEmpty)) {
                updateMap['image'] = aArt;
              }
              if (aId != null && aId.isNotEmpty) {
                if (aProvider == 'spotify' &&
                    queryByName.first['spotify_id'] == null) {
                  updateMap['spotify_id'] = aId;
                } else if (aProvider == 'youtube' &&
                    queryByName.first['youtube_id'] == null) {
                  updateMap['youtube_id'] = aId;
                }
              }
              if (updateMap.isNotEmpty) {
                await txn.update(
                  'artists',
                  updateMap,
                  where: 'id = ?',
                  whereArgs: [resolvedId],
                );
              }
            }
          }

          // 3. Create new artist record if not found:
          // In artist profile imports, only the primary artist (i == 0 or matching metadata)
          // should be automatically created in the artist catalog.
          // Collaborators (i > 0) are credited on the song (via artist_name and displayArtistString)
          // and matched to existing artist records if already present, but NOT automatically
          // registered as new standalone artists in the artist catalog.
          final bool isPrimaryArtist = (i == 0);
          final bool shouldCreateArtist = isPrimaryArtist || !isArtistOnly;

          if (resolvedId == 0 && shouldCreateArtist) {
            resolvedId = await txn.insert('artists', {
              'name': aName,
              'image': aArt,
              'spotify_id':
                  (aProvider == 'spotify' && aId != null && aId.isNotEmpty)
                  ? aId
                  : null,
              'youtube_id':
                  (aProvider == 'youtube' && aId != null && aId.isNotEmpty)
                  ? aId
                  : null,
              'created_at': now,
            });
            artistsCreated++;
          }

          if (i == 0) {
            primaryArtistId = resolvedId;
          }
        }

        // Safety fallback if no artists were resolved
        if (primaryArtistId == 0) {
          final queryDefault = await txn.rawQuery(
            'SELECT * FROM artists WHERE LOWER(TRIM(name)) = ?',
            ['unknown artist'],
          );
          if (queryDefault.isNotEmpty) {
            primaryArtistId = queryDefault.first['id'] as int;
          } else {
            primaryArtistId = await txn.insert('artists', {
              'name': 'Unknown Artist',
              'created_at': now,
            });
            artistsCreated++;
          }
        }

        // 2. Get or create Album inside transaction
        int? albumId;
        if (albumTitle.isNotEmpty && primaryArtistId > 0) {
          final albumQuery = await txn.rawQuery(
            'SELECT * FROM albums WHERE LOWER(TRIM(title)) = LOWER(TRIM(?)) AND artist_id = ?',
            [albumTitle, primaryArtistId],
          );
          if (albumQuery.isNotEmpty) {
            albumId = albumQuery.first['id'] as int;
            final updateMap = <String, dynamic>{};
            if (albumCover != null &&
                (albumQuery.first['cover'] == null ||
                    (albumQuery.first['cover'] as String).isEmpty)) {
              updateMap['cover'] = albumCover;
            }
            if (releaseYear != null &&
                albumQuery.first['release_year'] == null) {
              updateMap['release_year'] = releaseYear;
            }
            if (isAlbumMetadata &&
                provider == 'spotify' &&
                albumQuery.first['spotify_id'] == null) {
              updateMap['spotify_id'] = metadata.effectiveSourceId;
            } else if (isAlbumMetadata &&
                provider == 'youtube' &&
                albumQuery.first['youtube_id'] == null) {
              updateMap['youtube_id'] = metadata.effectiveSourceId;
            }
            if (updateMap.isNotEmpty) {
              await txn.update(
                'albums',
                updateMap,
                where: 'id = ?',
                whereArgs: [albumId],
              );
            }
          } else {
            albumId = await txn.insert('albums', {
              'artist_id': primaryArtistId,
              'title': albumTitle,
              'cover': albumCover,
              'release_year': releaseYear,
              'spotify_id': (isAlbumMetadata && provider == 'spotify')
                  ? metadata.effectiveSourceId
                  : null,
              'youtube_id': (isAlbumMetadata && provider == 'youtube')
                  ? metadata.effectiveSourceId
                  : null,
              'created_at': now,
            });
            albumsCreated++;
          }
        }

        // 3. Deduplicate Song: by (provider + source_id) OR (title + primary artist_id) OR (title + displayArtistString)
        List<Map<String, dynamic>> existingSongs = [];
        if (provider.isNotEmpty && sourceId.isNotEmpty) {
          existingSongs = await txn.query(
            'songs',
            where: 'provider = ? AND source_id = ?',
            whereArgs: [provider, sourceId],
          );
        }
        if (existingSongs.isEmpty) {
          existingSongs = await txn.rawQuery(
            'SELECT * FROM songs WHERE LOWER(TRIM(title)) = LOWER(TRIM(?)) AND artist_id = ?',
            [title, primaryArtistId],
          );
        }
        if (existingSongs.isEmpty) {
          existingSongs = await txn.rawQuery(
            'SELECT * FROM songs WHERE LOWER(TRIM(title)) = LOWER(TRIM(?)) AND LOWER(TRIM(artist_name)) = LOWER(TRIM(?))',
            [title, displayArtistString],
          );
        }

        final String audioPath =
            (t.effectiveSourceUrl != null &&
                (t.effectiveSourceUrl as String).isNotEmpty)
            ? (t.effectiveSourceUrl as String)
            : (provider.isNotEmpty && sourceId.isNotEmpty
                  ? '$provider:$sourceId'
                  : 'meta_${provider}_${primaryArtistId}_$title');

        if (existingSongs.isNotEmpty) {
          final existingId = existingSongs.first['id'] as int;
          if (overwriteExisting) {
            final updateMap = <String, dynamic>{
              'title': title,
              'artist_id': primaryArtistId,
              'album_id': albumId,
              'artist_name': displayArtistString,
              'album_title': albumTitle,
              'cover': trackCover ?? existingSongs.first['cover'],
              'duration': duration > 0
                  ? duration
                  : existingSongs.first['duration'],
              'provider': provider,
              'source_id': sourceId.isNotEmpty
                  ? sourceId
                  : existingSongs.first['source_id'],
              'metadata_source': provider,
              'imported_at': now,
            };
            await txn.update(
              'songs',
              updateMap,
              where: 'id = ?',
              whereArgs: [existingId],
            );
            songsUpdated++;
          } else {
            // Fill missing fields non-destructively
            final updateMap = <String, dynamic>{};
            if (existingSongs.first['cover'] == null && trackCover != null) {
              updateMap['cover'] = trackCover;
            }
            if ((existingSongs.first['album_title'] == null ||
                    existingSongs.first['album_title'] == 'Unknown Album') &&
                albumTitle.isNotEmpty) {
              updateMap['album_title'] = albumTitle;
              updateMap['album_id'] = albumId;
            }
            if (existingSongs.first['provider'] == null) {
              updateMap['provider'] = provider;
              updateMap['source_id'] = sourceId;
              updateMap['metadata_source'] = provider;
            }
            if (updateMap.isNotEmpty) {
              await txn.update(
                'songs',
                updateMap,
                where: 'id = ?',
                whereArgs: [existingId],
              );
              songsUpdated++;
            }
          }
        } else {
          // New song insert
          await txn.insert('songs', {
            'title': title,
            'artist_id': primaryArtistId,
            'album_id': albumId,
            'genre_id': null,
            'artist_name': displayArtistString,
            'album_title': albumTitle,
            'genre_name': '',
            'duration': duration,
            'audio_path': audioPath,
            'file_path': null,
            'cover': trackCover,
            'source': provider,
            'provider': provider,
            'source_id': sourceId,
            'metadata_source': provider,
            'imported_at': now,
            'created_at': now,
          });
          songsCreated++;
        }
      }
    });

    return {
      'songsCreated': songsCreated,
      'songsUpdated': songsUpdated,
      'albumsCreated': albumsCreated,
      'artistsCreated': artistsCreated,
    };
  }

  /// Extracts individual artists from a display string (e.g. "Artist A feat. Artist B",
  /// "Artist A ft. Artist B", "Artist A with Artist B", "Artist A x Artist B")
  /// safely without blindly breaking known compound names or legitimate bands.
  static List<ArtistMetadataInfo> _extractArtistsFromDisplayString(
    String display,
    String provider,
  ) {
    final cleaned = display.trim();
    if (cleaned.isEmpty) return [];

    // Check for explicit collaboration markers: feat., ft., with, x, vs., featuring
    // Use word boundaries so words like 'Within', 'Extra', 'Faith' are preserved intact.
    final collabRegex = RegExp(
      r'\s+(?:feat\.?|ft\.?|featuring|with|x|vs\.?)\s+',
      caseSensitive: false,
    );
    if (collabRegex.hasMatch(cleaned)) {
      final parts = cleaned.split(collabRegex);
      final List<ArtistMetadataInfo> result = [];
      for (final p in parts) {
        final pTrim = p.trim();
        if (pTrim.isNotEmpty) {
          result.add(ArtistMetadataInfo(name: pTrim, provider: provider));
        }
      }
      if (result.isNotEmpty) {
        return result;
      }
    }

    // Default: return the full string as single verified artist to prevent splitting "Simon & Garfunkel" or "AC/DC"
    return [ArtistMetadataInfo(name: cleaned, provider: provider)];
  }
}
