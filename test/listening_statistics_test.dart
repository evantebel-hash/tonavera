import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mymusic/database/local_database_service.dart';
import 'package:mymusic/models/listening_statistics_model.dart';
import 'package:mymusic/services/listening_statistics_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database testDb;
  late ListeningStatisticsService statsService;

  setUp(() async {
    testDb = await openDatabase(
      inMemoryDatabasePath,
      version: 6,
      onCreate: (db, version) async {
        await LocalDatabaseService.createSchema(db);
      },
    );
    LocalDatabaseService.instance.setDatabaseForTesting(testDb);
    statsService = ListeningStatisticsService(dbService: LocalDatabaseService.instance);

    // Seed mock local library
    await testDb.insert('artists', {'id': 1, 'name': 'Coldplay'});
    await testDb.insert('artists', {'id': 2, 'name': 'Adele'});
    await testDb.insert('albums', {'id': 1, 'title': 'Parachutes', 'artist_id': 1});
    await testDb.insert('albums', {'id': 2, 'title': '21', 'artist_id': 2});

    await testDb.insert('songs', {
      'id': 1,
      'title': 'Yellow',
      'artist_id': 1,
      'album_id': 1,
      'artist_name': 'Coldplay',
      'album_title': 'Parachutes',
      'duration': 269,
      'audio_path': 'song1.mp3',
    });
    await testDb.insert('songs', {
      'id': 2,
      'title': 'Someone Like You',
      'artist_id': 2,
      'album_id': 2,
      'artist_name': 'Adele',
      'album_title': '21',
      'duration': 285,
      'audio_path': 'song2.mp3',
    });
    await testDb.insert('songs', {
      'id': 3,
      'title': 'Fix You',
      'artist_id': 1,
      'album_id': 1,
      'artist_name': 'Coldplay',
      'album_title': 'Parachutes',
      'duration': 295,
      'audio_path': 'song3.mp3',
    });
  });

  tearDown(() async {
    await testDb.close();
  });

  group('Phase 4.1 — Listening Statistics Tests', () {
    test('Empty database returns zeroed statistics without crashing', () async {
      final stats = await statsService.getStatistics();
      expect(stats.totalPlays, 0);
      expect(stats.totalListeningTimeSeconds, 0);
      expect(stats.uniqueSongs, 0);
      expect(stats.uniqueArtists, 0);
      expect(stats.uniqueAlbums, 0);
      expect(stats.completionRate, 0.0);
    });

    test('Aggregates plays, duration, unique entities, and completion rate accurately', () async {
      final now = DateTime.now();
      await testDb.insert('listening_histories', {
        'song_id': 1,
        'started_at': now.subtract(const Duration(minutes: 10)).toIso8601String(),
        'ended_at': now.subtract(const Duration(minutes: 5)).toIso8601String(),
        'duration_played': 269,
        'completed': 1,
        'skipped': 0,
      });
      await testDb.insert('listening_histories', {
        'song_id': 1,
        'started_at': now.subtract(const Duration(minutes: 4)).toIso8601String(),
        'ended_at': now.subtract(const Duration(minutes: 2)).toIso8601String(),
        'duration_played': 120,
        'completed': 0,
        'skipped': 1,
      });
      await testDb.insert('listening_histories', {
        'song_id': 2,
        'started_at': now.subtract(const Duration(minutes: 1)).toIso8601String(),
        'ended_at': now.toIso8601String(),
        'duration_played': 60,
        'completed': 0,
        'skipped': 1,
      });

      final stats = await statsService.getStatistics();
      expect(stats.totalPlays, 3);
      expect(stats.totalListeningTimeSeconds, 269 + 120 + 60);
      expect(stats.uniqueSongs, 2);
      expect(stats.uniqueArtists, 2);
      expect(stats.uniqueAlbums, 2);
      expect(stats.completedPlays, 1);
      expect(stats.skippedPlays, 2);
      expect(stats.completionRate, closeTo(33.33, 0.1));
    });

    test('Filters by time range accurately', () async {
      final now = DateTime.now();
      // Old record (30 days ago)
      await testDb.insert('listening_histories', {
        'song_id': 1,
        'started_at': now.subtract(const Duration(days: 30)).toIso8601String(),
        'ended_at': now.subtract(const Duration(days: 30)).toIso8601String(),
        'duration_played': 200,
        'completed': 1,
        'skipped': 0,
      });
      // Today's record
      await testDb.insert('listening_histories', {
        'song_id': 2,
        'started_at': now.toIso8601String(),
        'ended_at': now.toIso8601String(),
        'duration_played': 100,
        'completed': 1,
        'skipped': 0,
      });

      final todayStats = await statsService.getStatistics(
        startDate: StatisticsTimeRange.today.startDate,
        endDate: StatisticsTimeRange.today.endDate,
      );
      expect(todayStats.totalPlays, 1);
      expect(todayStats.totalListeningTimeSeconds, 100);

      final allTimeStats = await statsService.getStatistics();
      expect(allTimeStats.totalPlays, 2);
      expect(allTimeStats.totalListeningTimeSeconds, 300);
    });
  });

  group('Phase 4.2 — Top Music Tests', () {
    test('Calculates top songs with deterministic rank sorting', () async {
      final now = DateTime.now();
      // Song 1: 2 plays
      await testDb.insert('listening_histories', {
        'song_id': 1,
        'started_at': now.subtract(const Duration(minutes: 5)).toIso8601String(),
        'duration_played': 200,
        'completed': 1,
      });
      await testDb.insert('listening_histories', {
        'song_id': 1,
        'started_at': now.subtract(const Duration(minutes: 3)).toIso8601String(),
        'duration_played': 200,
        'completed': 1,
      });
      // Song 2: 3 plays
      await testDb.insert('listening_histories', {
        'song_id': 2,
        'started_at': now.subtract(const Duration(minutes: 2)).toIso8601String(),
        'duration_played': 100,
        'completed': 1,
      });
      await testDb.insert('listening_histories', {
        'song_id': 2,
        'started_at': now.subtract(const Duration(minutes: 1)).toIso8601String(),
        'duration_played': 100,
        'completed': 1,
      });
      await testDb.insert('listening_histories', {
        'song_id': 2,
        'started_at': now.toIso8601String(),
        'duration_played': 100,
        'completed': 1,
      });

      final topSongs = await statsService.getTopSongs();
      expect(topSongs.length, 2);
      expect(topSongs[0].id, 2); // 3 plays
      expect(topSongs[0].playCount, 3);
      expect(topSongs[1].id, 1); // 2 plays
      expect(topSongs[1].playCount, 2);
    });

    test('Calculates top artists and top albums', () async {
      final now = DateTime.now();
      await testDb.insert('listening_histories', {
        'song_id': 1,
        'started_at': now.toIso8601String(),
        'duration_played': 200,
        'completed': 1,
      });
      await testDb.insert('listening_histories', {
        'song_id': 3,
        'started_at': now.toIso8601String(),
        'duration_played': 300,
        'completed': 1,
      });

      final topArtists = await statsService.getTopArtists();
      expect(topArtists.length, 1);
      expect(topArtists.first.title, 'Coldplay');
      expect(topArtists.first.playCount, 2);

      final topAlbums = await statsService.getTopAlbums();
      expect(topAlbums.length, 1);
      expect(topAlbums.first.title, 'Parachutes');
      expect(topAlbums.first.playCount, 2);
    });
  });

  group('Phase 4.3 — Listening Calendar Tests', () {
    test('Aggregates daily activity by date string', () async {
      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      await testDb.insert('listening_histories', {
        'song_id': 1,
        'started_at': now.toIso8601String(),
        'duration_played': 180,
        'completed': 1,
      });

      final monthlyMap = await statsService.getMonthlyActivity(year: now.year, month: now.month);
      expect(monthlyMap.containsKey(dateStr), true);
      expect(monthlyMap[dateStr]!.totalPlays, 1);
      expect(monthlyMap[dateStr]!.totalSeconds, 180);
    });
  });

  group('Phase 4.4 — Listening History Stream & Clear Tests', () {
    test('Retrieves history newest first with pagination', () async {
      final now = DateTime.now();
      await testDb.insert('listening_histories', {
        'id': 1,
        'song_id': 1,
        'started_at': now.subtract(const Duration(hours: 2)).toIso8601String(),
        'duration_played': 100,
      });
      await testDb.insert('listening_histories', {
        'id': 2,
        'song_id': 2,
        'started_at': now.subtract(const Duration(hours: 1)).toIso8601String(),
        'duration_played': 150,
      });

      final history = await statsService.getHistory(limit: 10, offset: 0);
      expect(history.length, 2);
      expect(history.first.songId, 2); // Newest first
      expect(history.last.songId, 1);
    });

    test('Clear history empties listening_histories without deleting songs or albums', () async {
      await testDb.insert('listening_histories', {
        'song_id': 1,
        'started_at': DateTime.now().toIso8601String(),
        'duration_played': 100,
      });

      final deleted = await statsService.clearHistory();
      expect(deleted, 1);

      final historyAfter = await statsService.getHistory();
      expect(historyAfter.isEmpty, true);

      // Verify songs and albums are untouched
      final songs = await testDb.query('songs');
      expect(songs.length, 3);
    });
  });
}
