import 'package:sqflite/sqflite.dart';
import '../database/local_database_service.dart';
import '../models/listening_history_model.dart';
import '../models/listening_statistics_model.dart';

class ListeningStatisticsService {
  final LocalDatabaseService _dbService;

  ListeningStatisticsService({LocalDatabaseService? dbService})
    : _dbService = dbService ?? LocalDatabaseService.instance;

  Future<Database> get _db async => await _dbService.database;

  // --- 4.1 LISTENING STATISTICS AGGREGATION ---
  Future<ListeningStatisticsModel> getStatistics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await _db;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (startDate != null) {
      whereClauses.add('lh.started_at >= ?');
      whereArgs.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      whereClauses.add('lh.started_at <= ?');
      whereArgs.add(endDate.toIso8601String());
    }

    final whereSql = whereClauses.isNotEmpty
        ? 'WHERE ${whereClauses.join(' AND ')}'
        : '';

    final rawStats = await db.rawQuery('''
      SELECT 
        COUNT(lh.id) AS total_plays,
        COALESCE(SUM(lh.duration_played), 0) AS total_time_seconds,
        COUNT(DISTINCT lh.song_id) AS unique_songs,
        COUNT(DISTINCT s.artist_id) AS unique_artists,
        COUNT(DISTINCT s.album_id) AS unique_albums,
        COALESCE(SUM(CASE WHEN lh.completed = 1 THEN 1 ELSE 0 END), 0) AS completed_plays,
        COALESCE(SUM(CASE WHEN lh.skipped = 1 THEN 1 ELSE 0 END), 0) AS skipped_plays
      FROM listening_histories lh
      LEFT JOIN songs s ON lh.song_id = s.id
      $whereSql
    ''', whereArgs);

    if (rawStats.isEmpty) {
      return ListeningStatisticsModel();
    }

    return ListeningStatisticsModel.fromMap(rawStats.first);
  }

  // --- 4.2 TOP MUSIC QUERIES ---
  Future<List<TopMusicItemModel>> getTopSongs({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 20,
  }) async {
    final db = await _db;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (startDate != null) {
      whereClauses.add('lh.started_at >= ?');
      whereArgs.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      whereClauses.add('lh.started_at <= ?');
      whereArgs.add(endDate.toIso8601String());
    }

    final whereSql = whereClauses.isNotEmpty
        ? 'WHERE ${whereClauses.join(' AND ')}'
        : '';
    whereArgs.add(limit);

    final results = await db.rawQuery('''
      SELECT 
        lh.song_id AS id,
        COALESCE(s.title, 'Lagu #' || lh.song_id) AS title,
        s.artist_name AS subtitle,
        s.cover AS cover,
        s.artist_id AS artist_id,
        s.album_id AS album_id,
        s.audio_path AS audio_path,
        s.file_path AS file_path,
        COUNT(lh.id) AS play_count,
        COALESCE(SUM(lh.duration_played), 0) AS total_duration
      FROM listening_histories lh
      LEFT JOIN songs s ON lh.song_id = s.id
      $whereSql
      GROUP BY lh.song_id
      ORDER BY play_count DESC, total_duration DESC, title ASC
      LIMIT ?
    ''', whereArgs);

    return results
        .map(
          (row) => TopMusicItemModel(
            id: row['id'] as int,
            title: row['title'] as String,
            subtitle: row['subtitle'] as String?,
            cover: row['cover'] as String?,
            playCount: int.tryParse(row['play_count'].toString()) ?? 0,
            totalDurationSeconds:
                int.tryParse(row['total_duration'].toString()) ?? 0,
            artistId: row['artist_id'] as int?,
            albumId: row['album_id'] as int?,
            audioPath: row['audio_path'] as String?,
            filePath: row['file_path'] as String?,
          ),
        )
        .toList();
  }

  Future<List<TopMusicItemModel>> getTopArtists({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 20,
  }) async {
    final db = await _db;
    final whereClauses = <String>[
      "s.artist_name IS NOT NULL AND s.artist_name != ''",
    ];
    final whereArgs = <dynamic>[];

    if (startDate != null) {
      whereClauses.add('lh.started_at >= ?');
      whereArgs.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      whereClauses.add('lh.started_at <= ?');
      whereArgs.add(endDate.toIso8601String());
    }

    final whereSql = 'WHERE ${whereClauses.join(' AND ')}';
    whereArgs.add(limit);

    final results = await db.rawQuery('''
      SELECT 
        COALESCE(s.artist_id, 0) AS id,
        s.artist_name AS title,
        COUNT(DISTINCT s.id) || ' lagu diputar' AS subtitle,
        NULL AS cover,
        COUNT(lh.id) AS play_count,
        COALESCE(SUM(lh.duration_played), 0) AS total_duration
      FROM listening_histories lh
      JOIN songs s ON lh.song_id = s.id
      $whereSql
      GROUP BY s.artist_name
      ORDER BY play_count DESC, total_duration DESC, title ASC
      LIMIT ?
    ''', whereArgs);

    return results
        .map(
          (row) => TopMusicItemModel(
            id: row['id'] as int,
            title: row['title'] as String,
            subtitle: row['subtitle'] as String?,
            cover: null,
            playCount: int.tryParse(row['play_count'].toString()) ?? 0,
            totalDurationSeconds:
                int.tryParse(row['total_duration'].toString()) ?? 0,
          ),
        )
        .toList();
  }

  Future<List<TopMusicItemModel>> getTopAlbums({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 20,
  }) async {
    final db = await _db;
    final whereClauses = <String>[
      "s.album_title IS NOT NULL AND s.album_title != ''",
    ];
    final whereArgs = <dynamic>[];

    if (startDate != null) {
      whereClauses.add('lh.started_at >= ?');
      whereArgs.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      whereClauses.add('lh.started_at <= ?');
      whereArgs.add(endDate.toIso8601String());
    }

    final whereSql = 'WHERE ${whereClauses.join(' AND ')}';
    whereArgs.add(limit);

    final results = await db.rawQuery('''
      SELECT 
        COALESCE(s.album_id, 0) AS id,
        s.album_title AS title,
        s.artist_name AS subtitle,
        s.cover AS cover,
        COUNT(lh.id) AS play_count,
        COALESCE(SUM(lh.duration_played), 0) AS total_duration
      FROM listening_histories lh
      JOIN songs s ON lh.song_id = s.id
      $whereSql
      GROUP BY s.album_title, s.artist_name
      ORDER BY play_count DESC, total_duration DESC, title ASC
      LIMIT ?
    ''', whereArgs);

    return results
        .map(
          (row) => TopMusicItemModel(
            id: row['id'] as int,
            title: row['title'] as String,
            subtitle: row['subtitle'] as String?,
            cover: row['cover'] as String?,
            playCount: int.tryParse(row['play_count'].toString()) ?? 0,
            totalDurationSeconds:
                int.tryParse(row['total_duration'].toString()) ?? 0,
          ),
        )
        .toList();
  }

  // --- 4.3 LISTENING CALENDAR AGGREGATION ---
  Future<Map<String, DailyListeningActivityModel>> getMonthlyActivity({
    required int year,
    required int month,
  }) async {
    final db = await _db;
    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth = DateTime(year, month + 1, 0, 23, 59, 59, 999);

    final results = await db.rawQuery(
      '''
      SELECT 
        SUBSTR(lh.started_at, 1, 10) AS play_date,
        COUNT(lh.id) AS total_plays,
        COALESCE(SUM(lh.duration_played), 0) AS total_seconds,
        COUNT(DISTINCT lh.song_id) AS unique_songs
      FROM listening_histories lh
      WHERE lh.started_at >= ? AND lh.started_at <= ?
      GROUP BY SUBSTR(lh.started_at, 1, 10)
    ''',
      [startOfMonth.toIso8601String(), endOfMonth.toIso8601String()],
    );

    final map = <String, DailyListeningActivityModel>{};
    for (final row in results) {
      final dateStr = row['play_date'] as String;
      final parsedDate = DateTime.tryParse(dateStr) ?? DateTime(year, month);
      map[dateStr] = DailyListeningActivityModel(
        date: parsedDate,
        totalPlays: int.tryParse(row['total_plays'].toString()) ?? 0,
        totalSeconds: int.tryParse(row['total_seconds'].toString()) ?? 0,
        uniqueSongs: int.tryParse(row['unique_songs'].toString()) ?? 0,
      );
    }
    return map;
  }

  Future<List<ListeningHistoryModel>> getHistoryForDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

    return getHistory(startDate: startOfDay, endDate: endOfDay, limit: 100);
  }

  // --- 4.4 LISTENING HISTORY STREAM & PAGINATION ---
  Future<List<ListeningHistoryModel>> getHistory({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
    int offset = 0,
    String? searchQuery,
  }) async {
    final db = await _db;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (startDate != null) {
      whereClauses.add('lh.started_at >= ?');
      whereArgs.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      whereClauses.add('lh.started_at <= ?');
      whereArgs.add(endDate.toIso8601String());
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClauses.add(
        '(s.title LIKE ? OR s.artist_name LIKE ? OR s.album_title LIKE ?)',
      );
      final term = '%${searchQuery.trim()}%';
      whereArgs.addAll([term, term, term]);
    }

    final whereSql = whereClauses.isNotEmpty
        ? 'WHERE ${whereClauses.join(' AND ')}'
        : '';
    whereArgs.addAll([limit, offset]);

    final results = await db.rawQuery('''
      SELECT 
        lh.id,
        lh.song_id,
        COALESCE(s.title, 'Lagu #' || lh.song_id) AS title,
        COALESCE(s.artist_name, 'Artis Tidak Dikenal') AS artist_name,
        s.album_title,
        s.cover,
        s.audio_path,
        s.file_path,
        lh.started_at,
        lh.ended_at,
        lh.duration_played,
        lh.completed,
        lh.skipped
      FROM listening_histories lh
      LEFT JOIN songs s ON lh.song_id = s.id
      $whereSql
      ORDER BY lh.started_at DESC
      LIMIT ? OFFSET ?
    ''', whereArgs);

    return results.map((e) => ListeningHistoryModel.fromMap(e)).toList();
  }

  Future<int> clearHistory() async {
    final db = await _db;
    return await db.delete('listening_histories');
  }
}
