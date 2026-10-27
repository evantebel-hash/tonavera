import 'package:sqflite/sqflite.dart';
import '../database/local_database_service.dart';
import '../models/lyric_line.dart';
import '../models/lyrics_model.dart';
import '../services/lrc_parser.dart';

class LyricsRepository {
  Future<Database> get _db async =>
      await LocalDatabaseService.instance.database;

  /// Retrieves cached lyrics for a specific song ID.
  Future<LyricsModel?> getLyricsBySongId(int songId) async {
    final db = await _db;
    final maps = await db.query(
      'lyrics_cache',
      where: 'song_id = ?',
      whereArgs: [songId],
      limit: 1,
    );

    if (maps.isEmpty) return null;

    final raw = maps.first;
    final syncedLyrics = raw['synced_lyrics']?.toString();
    final isSynced = raw['is_synced'] == 1;

    final List<LyricLine> parsedLines =
        (isSynced && syncedLyrics != null && syncedLyrics.isNotEmpty)
        ? LrcParser.parse(syncedLyrics)
        : const <LyricLine>[];

    return LyricsModel.fromMap(raw, parsedLines: parsedLines);
  }

  /// Inserts or replaces cached lyrics for a song.
  Future<int> saveLyrics(LyricsModel lyrics) async {
    final db = await _db;
    final map = lyrics.toMap();

    return await db.insert(
      'lyrics_cache',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Deletes cached lyrics for a specific song ID.
  Future<void> deleteLyrics(int songId) async {
    final db = await _db;
    await db.delete('lyrics_cache', where: 'song_id = ?', whereArgs: [songId]);
  }

  /// Clears all lyrics cached from online sources (e.g. lrclib) while keeping embedded ones if desired.
  Future<void> clearOnlineLyricsCache({int? songId}) async {
    final db = await _db;
    if (songId != null) {
      await db.delete(
        'lyrics_cache',
        where: 'song_id = ? AND source = ?',
        whereArgs: [songId, LyricsSource.lrclib.name],
      );
    } else {
      await db.delete(
        'lyrics_cache',
        where: 'source = ?',
        whereArgs: [LyricsSource.lrclib.name],
      );
    }
  }
}
