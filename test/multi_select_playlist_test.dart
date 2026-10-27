import 'package:flutter_test/flutter_test.dart';
import 'package:mymusic/controllers/multi_select_controller.dart';
import 'package:mymusic/models/song_model.dart';
import 'package:mymusic/repositories/local_music_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mymusic/database/local_database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('MultiSelectController Unit Tests', () {
    test('1. Start selection sets initial ID and enables selection mode', () {
      final controller = MultiSelectController();
      expect(controller.isSelectionMode, isFalse);
      expect(controller.selectedCount, 0);

      controller.startSelection(101, index: 0);
      expect(controller.isSelectionMode, isTrue);
      expect(controller.selectedCount, 1);
      expect(controller.isSelected(101), isTrue);
      expect(controller.isSelected(102), isFalse);
    });

    test('2. Toggle selection adds and removes IDs and auto-clears mode when empty', () {
      final controller = MultiSelectController();
      controller.toggleSelection(101);
      expect(controller.isSelected(101), isTrue);
      expect(controller.selectedCount, 1);

      controller.toggleSelection(102);
      expect(controller.selectedCount, 2);

      controller.toggleSelection(101);
      expect(controller.selectedCount, 1);
      expect(controller.isSelected(101), isFalse);

      controller.toggleSelection(102);
      expect(controller.selectedCount, 0);
      expect(controller.isSelectionMode, isFalse);
    });

    test('3. Select All and Deselect All work on visible IDs subset', () {
      final controller = MultiSelectController();
      final visibleIds = [1, 2, 3, 4, 5];

      controller.selectAll(visibleIds);
      expect(controller.selectedCount, 5);
      expect(controller.isSelected(3), isTrue);

      controller.deselectAll();
      expect(controller.selectedCount, 0);
      expect(controller.isSelectionMode, isFalse);
    });

    test('4. Range Selection (Shift+Click) selects inclusive range based on visible list', () {
      final controller = MultiSelectController();
      final visibleIds = [10, 20, 30, 40, 50, 60];

      // Anchor at index 1 (song 20)
      controller.startSelection(20, index: 1);

      // Range select up to index 4 (song 50)
      controller.selectRange(visibleIds, 4);

      expect(controller.selectedCount, 4);
      expect(controller.isSelected(20), isTrue);
      expect(controller.isSelected(30), isTrue);
      expect(controller.isSelected(40), isTrue);
      expect(controller.isSelected(50), isTrue);
      expect(controller.isSelected(10), isFalse);
      expect(controller.isSelected(60), isFalse);
    });

    test('5. Search/filter does not lose global selection', () {
      final controller = MultiSelectController();
      controller.toggleSelection(101);
      controller.toggleSelection(102);
      controller.toggleSelection(103);
      expect(controller.selectedCount, 3);

      // Simulated filtered list with only 102
      final filteredIds = [102];
      expect(controller.isSelected(101), isTrue);
      expect(controller.isSelected(102), isTrue);
      expect(controller.isSelected(103), isTrue);

      // Adding filtered selection
      controller.selectAll(filteredIds);
      expect(controller.selectedCount, 3);
      expect(controller.selectedIds, containsAll([101, 102, 103]));
    });
  });

  group('Bulk Playlist Repository Database Tests (Phase 2.11 & Urgent Multi-Song Fix)', () {
    late LocalMusicRepository repo;
    late Database testDb;
    late int testPlaylist1;
    late int testPlaylist2;
    late List<int> testSongIds;

    setUp(() async {
      testDb = await openDatabase(
        inMemoryDatabasePath,
        version: 6,
        onCreate: (db, v) => LocalDatabaseService.createSchema(db),
      );
      LocalDatabaseService.instance.setDatabaseForTesting(testDb);

      repo = LocalMusicRepository();
      testPlaylist1 = await repo.createPlaylist('Bulk Playlist 1');
      testPlaylist2 = await repo.createPlaylist('Bulk Playlist 2');

      testSongIds = [];
      for (int i = 1; i <= 15; i++) {
        final id = await repo.insertOrUpdateSong(SongModel(
          id: 1000 + i,
          title: 'Bulk Song $i',
          artistId: 1,
          duration: 180,
          audioPath: 'path_$i.mp3',
        ));
        testSongIds.add(id);
      }
    });

    tearDown(() async {
      await testDb.close();
    });

    test('6. Add 1 song to playlist works', () async {
      final added = await repo.addSongsToPlaylist(testPlaylist1, [testSongIds[0]]);
      expect(added, 1);
      final plSongs = await repo.getPlaylistSongs(testPlaylist1);
      expect(plSongs.length, 1);
    });

    test('7. Add 2 songs to playlist works', () async {
      final added = await repo.addSongsToPlaylist(testPlaylist1, [testSongIds[0], testSongIds[1]]);
      expect(added, 2);
      final plSongs = await repo.getPlaylistSongs(testPlaylist1);
      expect(plSongs.length, 2);
    });

    test('8. Add 5 songs to playlist works', () async {
      final added = await repo.addSongsToPlaylist(testPlaylist1, testSongIds.take(5).toList());
      expect(added, 5);
      final plSongs = await repo.getPlaylistSongs(testPlaylist1);
      expect(plSongs.length, 5);
    });

    test('9. Add 10+ songs to playlist works in single transaction', () async {
      final added = await repo.addSongsToPlaylist(testPlaylist1, testSongIds);
      expect(added, 15);
      final plSongs = await repo.getPlaylistSongs(testPlaylist1);
      expect(plSongs.length, 15);
      expect(plSongs.map((s) => s.id).toList(), testSongIds);
    });

    test('10. Bulk add songs preserves order and prevents duplicates', () async {
      final subset = testSongIds.take(5).toList();
      final addedCount = await repo.addSongsToPlaylist(testPlaylist1, subset);
      expect(addedCount, 5);

      final songsInPl = await repo.getPlaylistSongs(testPlaylist1);
      expect(songsInPl.length, 5);
      expect(songsInPl.map((s) => s.id).toList(), subset);

      // Attempt duplicate addition: should be ignored by UNIQUE constraint
      final dupAdded = await repo.addSongsToPlaylist(testPlaylist1, [subset[0], subset[1]]);
      expect(dupAdded, 0);

      final songsAfterDup = await repo.getPlaylistSongs(testPlaylist1);
      expect(songsAfterDup.length, 5);
    });

    test('11. Bulk add multiple songs to multiple playlists in atomic transaction', () async {
      final subset = testSongIds.take(5).toList();
      final results = await repo.addSongsToMultiplePlaylists(
        [testPlaylist1, testPlaylist2],
        subset,
      );

      expect(results[testPlaylist1], 5);
      expect(results[testPlaylist2], 5);

      final pl1Songs = await repo.getPlaylistSongs(testPlaylist1);
      final pl2Songs = await repo.getPlaylistSongs(testPlaylist2);
      expect(pl1Songs.length, 5);
      expect(pl2Songs.length, 5);
    });

    test('12. Bulk remove songs deletes only playlist relationships without deleting songs', () async {
      final subset = testSongIds.take(5).toList();
      await repo.addSongsToPlaylist(testPlaylist1, subset);

      // Remove 2 songs
      final removed = await repo.removeSongsFromPlaylist(testPlaylist1, [subset[0], subset[1]]);
      expect(removed, 2);

      final songsInPl = await repo.getPlaylistSongs(testPlaylist1);
      expect(songsInPl.length, 3);
      expect(songsInPl.any((s) => s.id == subset[0]), isFalse);

      // Verify song records still exist in library
      final song0 = await repo.getSongById(subset[0]);
      expect(song0, isNotNull);
    });
  });
}
