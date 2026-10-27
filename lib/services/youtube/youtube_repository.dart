import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../database/local_database_service.dart';
import '../../models/youtube_model.dart';
import '../../models/song_model.dart';

class YouTubeRepository {
  final LocalDatabaseService _dbService;

  static const Duration searchTtl = Duration(hours: 1);
  static const Duration playlistTtl = Duration(hours: 24);

  YouTubeRepository({LocalDatabaseService? dbService})
    : _dbService = dbService ?? LocalDatabaseService.instance;

  // --- SEARCH CACHE ---

  Future<List<YouTubeVideo>?> getCachedSearch(
    String query, {
    bool allowStale = true,
  }) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'youtube_search_cache',
      where: 'query = ?',
      whereArgs: [query.trim().toLowerCase()],
    );

    if (maps.isEmpty) return null;

    final map = maps.first;
    final fetchedAt =
        DateTime.tryParse(map['fetched_at'].toString()) ?? DateTime.now();
    final isExpired = DateTime.now().difference(fetchedAt) > searchTtl;

    if (isExpired && !allowStale) return null;

    try {
      final List<dynamic> decoded = json.decode(map['results_json'].toString());
      return decoded
          .map((m) => YouTubeVideo.fromMap(m as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSearchCache(String query, List<YouTubeVideo> videos) async {
    final db = await _dbService.database;
    final jsonStr = json.encode(videos.map((v) => v.toMap()).toList());

    await db.insert('youtube_search_cache', {
      'query': query.trim().toLowerCase(),
      'results_json': jsonStr,
      'fetched_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    for (final v in videos) {
      await saveVideo(v);
    }
  }

  // --- VIDEOS ---

  Future<void> saveVideo(YouTubeVideo video) async {
    final db = await _dbService.database;
    await db.insert(
      'youtube_videos',
      video.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<YouTubeVideo?> getVideo(String videoId) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'youtube_videos',
      where: 'video_id = ?',
      whereArgs: [videoId],
    );

    if (maps.isEmpty) return null;
    return YouTubeVideo.fromMap(maps.first);
  }

  // --- PLAYLISTS ---

  Future<void> savePlaylist(YouTubePlaylist playlist) async {
    final db = await _dbService.database;
    await db.transaction((txn) async {
      await txn.insert(
        'youtube_playlists',
        playlist.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Replace items
      await txn.delete(
        'youtube_playlist_items',
        where: 'playlist_id = ?',
        whereArgs: [playlist.playlistId],
      );

      for (int i = 0; i < playlist.items.length; i++) {
        final item = playlist.items[i];
        final itemMap = item.toMap();
        itemMap['position_order'] = i;
        await txn.insert('youtube_playlist_items', itemMap);
      }
    });
  }

  Future<YouTubePlaylist?> getPlaylist(
    String playlistId, {
    bool allowStale = true,
  }) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'youtube_playlists',
      where: 'playlist_id = ?',
      whereArgs: [playlistId],
    );

    if (maps.isEmpty) return null;

    final plMap = maps.first;
    final itemMaps = await db.query(
      'youtube_playlist_items',
      where: 'playlist_id = ?',
      orderBy: 'position_order ASC',
      whereArgs: [playlistId],
    );

    final items = itemMaps.map((m) => YouTubePlaylistItem.fromMap(m)).toList();
    return YouTubePlaylist.fromMap(plMap, items: items);
  }

  Future<List<YouTubePlaylist>> getAllPlaylists() async {
    final db = await _dbService.database;
    final maps = await db.query(
      'youtube_playlists',
      orderBy: 'updated_at DESC, fetched_at DESC',
    );

    final playlists = <YouTubePlaylist>[];
    for (final map in maps) {
      final pId = map['playlist_id'].toString();
      final itemMaps = await db.query(
        'youtube_playlist_items',
        where: 'playlist_id = ?',
        orderBy: 'position_order ASC',
        whereArgs: [pId],
      );
      final items = itemMaps
          .map((m) => YouTubePlaylistItem.fromMap(m))
          .toList();
      playlists.add(YouTubePlaylist.fromMap(map, items: items));
    }

    return playlists;
  }

  Future<void> deletePlaylist(String playlistId) async {
    final db = await _dbService.database;
    await db.transaction((txn) async {
      await txn.delete(
        'youtube_playlists',
        where: 'playlist_id = ?',
        whereArgs: [playlistId],
      );
      await txn.delete(
        'youtube_playlist_items',
        where: 'playlist_id = ?',
        whereArgs: [playlistId],
      );
    });
  }

  // --- HYBRID PLAYLIST ITEMS ---

  Future<List<HybridPlaylistItem>> getHybridPlaylistItems(
    int playlistId,
  ) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'hybrid_playlist_items',
      where: 'playlist_id = ?',
      orderBy: 'position_order ASC',
      whereArgs: [playlistId],
    );

    final items = <HybridPlaylistItem>[];
    for (final map in maps) {
      final sTypeStr = map['source_type']?.toString() ?? 'local';
      final sType = sTypeStr == 'youtube'
          ? HybridSourceType.youtube
          : HybridSourceType.local;

      SongModel? song;
      YouTubeVideo? ytVideo;

      if (sType == HybridSourceType.local && map['song_id'] != null) {
        final sMaps = await db.query(
          'songs',
          where: 'id = ?',
          whereArgs: [map['song_id']],
        );
        if (sMaps.isNotEmpty) {
          song = SongModel.fromJson(sMaps.first);
        }
      } else if (sType == HybridSourceType.youtube &&
          map['youtube_video_id'] != null) {
        ytVideo = await getVideo(map['youtube_video_id'].toString());
      }

      items.add(
        HybridPlaylistItem(
          id: map['id'] as int?,
          playlistId: playlistId,
          sourceType: sType,
          songId: map['song_id'] as int?,
          youtubeVideoId: map['youtube_video_id']?.toString(),
          position: map['position_order'] as int? ?? 0,
          localSong: song,
          youtubeVideo: ytVideo,
        ),
      );
    }

    return items;
  }

  Future<void> addYouTubeTrackToHybridPlaylist(
    int playlistId,
    YouTubeVideo video,
  ) async {
    await saveVideo(video);
    final db = await _dbService.database;

    final countResult = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM hybrid_playlist_items WHERE playlist_id = ?',
      [playlistId],
    );
    final nextPos = Sqflite.firstIntValue(countResult) ?? 0;

    await db.insert('hybrid_playlist_items', {
      'playlist_id': playlistId,
      'source_type': 'youtube',
      'youtube_video_id': video.videoId,
      'position_order': nextPos,
    });
  }

  // --- CACHE CLEAR ---

  Future<void> clearAllCache() async {
    final db = await _dbService.database;
    await db.transaction((txn) async {
      await txn.delete('youtube_videos');
      await txn.delete('youtube_playlists');
      await txn.delete('youtube_playlist_items');
      await txn.delete('youtube_search_cache');
    });
  }
}
