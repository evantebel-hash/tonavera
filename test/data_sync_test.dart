import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mymusic/models/backup_model.dart';
import 'package:mymusic/models/playlist_export_model.dart';
import 'package:mymusic/models/song_model.dart';
import 'package:mymusic/models/playlist_model.dart';
import 'package:mymusic/services/playlist_export_import_service.dart';
import 'package:mymusic/services/api/cloud_sync_provider.dart';

SongModel createTestSong({
  required int id,
  required String title,
  required String artist,
  required String album,
  required String path,
}) {
  return SongModel(
    id: id,
    artistId: 1,
    title: title,
    duration: 200,
    artistName: artist,
    albumTitle: album,
    audioPath: path,
    filePath: path,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('7.1 Library Backup Tests', () {
    test('BackupPackage serialization & checksum validation', () {
      final manifest = BackupManifest(
        createdAt: '2026-10-05T20:00:00Z',
        platform: 'windows',
        checksum: '12345678',
        contains: {
          'library': true,
          'playlists': true,
          'favorites': true,
          'history': true,
          'playerState': true,
        },
      );

      final package = BackupPackage(
        manifest: manifest,
        songs: [
          {'id': 1, 'title': 'Bohemian Rhapsody', 'artist_name': 'Queen'}
        ],
        artists: [
          {'id': 1, 'name': 'Queen'}
        ],
        albums: [
          {'id': 1, 'title': 'A Night at the Opera'}
        ],
        genres: [],
        playlists: [
          {'id': 1, 'name': 'Rock Classics'}
        ],
        playlistSongs: [
          {'playlist_id': 1, 'song_id': 1, 'order_index': 0}
        ],
        favorites: [
          {'song_id': 1}
        ],
        listeningHistories: [],
        playerState: {'current_song_id': 1, 'position_ms': 5000},
        playerQueues: [],
      );

      final json = package.toJson();
      expect(json['manifest']['schemaVersion'], 6);
      expect(json['manifest']['backupVersion'], 1);
      expect(json['songs'].length, 1);
      expect(json['playlists'].length, 1);

      final decodedPackage = BackupPackage.fromJson(json);
      expect(decodedPackage.songs.first['title'], 'Bohemian Rhapsody');
      expect(decodedPackage.playlists.first['name'], 'Rock Classics');

      final checksum = package.calculateChecksum();
      expect(checksum, isNotEmpty);
      expect(checksum, isA<String>());
    });

    test('BackupManifest default schema and values', () {
      final json = {
        'createdAt': '2026-10-05T20:00:00Z',
        'platform': 'android',
        'checksum': 'abc123',
      };
      final manifest = BackupManifest.fromJson(json);
      expect(manifest.schemaVersion, 6);
      expect(manifest.backupVersion, 1);
      expect(manifest.contains['library'], true);
    });
  });

  group('7.3 & 7.4 Playlist Export / Import Tests', () {
    test('Export playlist to JSON and M3U format', () {
      final song1 = createTestSong(
        id: 1,
        title: 'Hotel California',
        artist: 'Eagles',
        album: 'Hotel California',
        path: '/music/eagles/hotel_california.mp3',
      );
      final song2 = createTestSong(
        id: 2,
        title: 'Stairway to Heaven',
        artist: 'Led Zeppelin',
        album: 'Led Zeppelin IV',
        path: '/music/led_zeppelin/stairway.mp3',
      );

      final playlist = PlaylistModel(
        id: 10,
        name: 'Classic Rock Favorites',
        description: 'Best rock tracks',
        songs: [song1, song2],
      );

      final exportPackage = PlaylistExportPackage.fromPlaylist(playlist);
      expect(exportPackage.name, 'Classic Rock Favorites');
      expect(exportPackage.songs.length, 2);

      final jsonStr = exportPackage.toJsonString();
      expect(jsonStr, contains('Classic Rock Favorites'));
      expect(jsonStr, contains('Hotel California'));

      final m3uStr = exportPackage.toM3uString();
      expect(m3uStr, contains('#EXTM3U'));
      expect(m3uStr, contains('#PLAYLIST:Classic Rock Favorites'));
      expect(m3uStr, contains('#EXTINF:200,Eagles - Hotel California'));
      expect(m3uStr, contains('/music/eagles/hotel_california.mp3'));
    });

    test('Import playlist matching strategy against local library', () {
      final localSong1 = createTestSong(
        id: 101,
        title: 'Imagine',
        artist: 'John Lennon',
        album: 'Imagine',
        path: 'C:/Music/John Lennon - Imagine.mp3',
      );
      final localSong2 = createTestSong(
        id: 102,
        title: 'Hey Jude',
        artist: 'The Beatles',
        album: 'Single',
        path: 'C:/Music/Beatles - Hey Jude.mp3',
      );

      final localLibrary = [localSong1, localSong2];
      final service = PlaylistExportImportService();

      final jsonContent = jsonEncode({
        'format': 'mymusic-playlist',
        'version': 1,
        'playlist': {
          'name': 'Peace Songs',
          'description': 'Calm music',
          'songs': [
            {
              'title': 'Imagine',
              'artist_name': 'John Lennon',
              'album_title': 'Imagine',
              'duration': 200,
              'audio_path': 'D:/OtherPath/Imagine.mp3',
              'track_hash': localSong1.trackHash,
            },
            {
              'title': 'Non Existent Track',
              'artist_name': 'Nobody',
              'duration': 180,
            }
          ]
        }
      });

      final result = service.parsePlaylistContent(jsonContent, 'peace.json', localLibrary);
      expect(result.playlistName, 'Peace Songs');
      expect(result.totalTracks, 2);
      expect(result.matchedCount, 1);
      expect(result.missingCount, 1);
      expect(result.matchedSongs.first.id, 101);
    });

    test('Import M3U playlist file', () {
      final localSong = createTestSong(
        id: 50,
        title: 'Sweet Child O Mine',
        artist: 'Guns N Roses',
        album: 'Appetite for Destruction',
        path: '/sdcard/Music/GNR/sweet_child.mp3',
      );

      final localLibrary = [localSong];
      final service = PlaylistExportImportService();

      final m3uContent = '''
#EXTM3U
#PLAYLIST:Hard Rock
#EXTINF:200,Guns N Roses - Sweet Child O Mine
/sdcard/Music/GNR/sweet_child.mp3
''';

      final result = service.parsePlaylistContent(m3uContent, 'rock.m3u', localLibrary);
      expect(result.playlistName, 'Hard Rock');
      expect(result.totalTracks, 1);
      expect(result.matchedCount, 1);
      expect(result.matchedSongs.first.id, 50);
    });
  });

  group('7.5 Cloud Sync Provider Tests', () {
    test('DefaultCloudSyncProvider initial state and sync status', () async {
      final syncProvider = DefaultCloudSyncProvider();
      expect(syncProvider.isCloudAvailable, false);

      final status = await syncProvider.getSyncStatus();
      expect(status['enabled'], false);
      expect(status['pendingCount'], 0);

      // Perform sync should succeed safely (no-op / offline outbox queue check)
      final result = await syncProvider.syncNow();
      expect(result, true);
    });
  });
}
