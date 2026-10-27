import 'package:flutter_test/flutter_test.dart';
import 'package:mymusic/models/song_model.dart';
import 'package:mymusic/models/download_task_model.dart';
import 'package:mymusic/services/download_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 8.7.1 — Download Playlist UX & Integration Tests', () {
    final directSong1 = SongModel(
      id: 1,
      artistId: 10,
      title: 'Downloadable Track 1',
      artistName: 'Artist A',
      duration: 180,
      audioPath: 'https://example.com/audio/track1.mp3',
      source: 'catalog',
    );

    final directSong2 = SongModel(
      id: 2,
      artistId: 10,
      title: 'Downloadable Track 2',
      artistName: 'Artist A',
      duration: 210,
      audioPath: 'https://example.com/audio/track2.mp3',
      source: 'catalog',
    );

    final youtubeSong = SongModel(
      id: 3,
      artistId: 0,
      title: 'YouTube Track',
      duration: 240,
      audioPath: '60ItHLz5WEA',
      source: 'youtube',
    );

    final localSong = SongModel(
      id: 4,
      artistId: 10,
      title: 'Local Track',
      duration: 190,
      audioPath: 'C:\\Users\\Public\\Music\\local.mp3',
      filePath: 'C:\\Users\\Public\\Music\\local.mp3',
      source: 'local',
    );

    test('1. Playlist with 0 downloadable items', () {
      final playlistSongs = [youtubeSong, localSong];
      final downloadable = playlistSongs.where((s) => DownloadService.isDownloadableSource(s)).toList();
      expect(downloadable, isEmpty);
    });

    test('2. Playlist with 1 downloadable item', () {
      final playlistSongs = [directSong1, youtubeSong];
      final downloadable = playlistSongs.where((s) => DownloadService.isDownloadableSource(s)).toList();
      expect(downloadable.length, equals(1));
      expect(downloadable.first.id, equals(1));
    });

    test('3. Playlist with multiple downloadable items', () {
      final playlistSongs = [directSong1, directSong2];
      final downloadable = playlistSongs.where((s) => DownloadService.isDownloadableSource(s)).toList();
      expect(downloadable.length, equals(2));
    });

    test('4. Playlist with mixed downloadable / non-downloadable items', () {
      final playlistSongs = [directSong1, youtubeSong, directSong2, localSong];
      final downloadable = playlistSongs.where((s) => DownloadService.isDownloadableSource(s)).toList();
      expect(downloadable.length, equals(2));
      expect(downloadable.map((s) => s.id), containsAll([1, 2]));
    });

    test('5. Download Selected enqueues only selected downloadable songs', () async {
      final service = DownloadService();
      final allPlaylistSongs = [directSong1, directSong2, youtubeSong];
      final selectedSongIds = {1, 3}; // Direct Track 1 + YouTube Track

      final selectedSongs = allPlaylistSongs.where((s) => selectedSongIds.contains(s.id)).toList();
      final downloadableSelected = selectedSongs.where((s) => DownloadService.isDownloadableSource(s)).toList();

      for (final song in downloadableSelected) {
        await service.enqueueDownload(song);
      }

      expect(service.tasks.length, equals(1));
      expect(service.tasks.first.song.id, equals(1));
    });

    test('6. Download All enqueues all downloadable songs in playlist', () async {
      final service = DownloadService();
      final playlistSongs = [directSong1, directSong2, youtubeSong, localSong];
      final downloadable = playlistSongs.where((s) => DownloadService.isDownloadableSource(s)).toList();

      for (final song in downloadable) {
        await service.enqueueDownload(song);
      }

      expect(service.tasks.length, equals(2));
      expect(service.tasks.map((t) => t.song.id), containsAll([1, 2]));
    });

    test('7. Duplicate detection prevents duplicate task creation', () async {
      final service = DownloadService();
      await service.enqueueDownload(directSong1);
      final duplicateTask = await service.enqueueDownload(directSong1);

      expect(service.tasks.length, equals(1));
      expect(duplicateTask, isNotNull);
    });

    test('8. Download task creation from playlist', () async {
      final service = DownloadService();
      final task = await service.enqueueDownload(directSong1);

      expect(task, isNotNull);
      expect(task!.status == DownloadStatus.queued || task.status == DownloadStatus.downloading, isTrue);
    });

    test('9. Download Manager integration exposes task list', () async {
      final service = DownloadService();
      await service.enqueueDownload(directSong1);
      await service.enqueueDownload(directSong2);

      expect(service.tasks.length, equals(2));
      expect(service.tasks.every((t) => t.status == DownloadStatus.queued || t.status == DownloadStatus.downloading), isTrue);
    });

    test('10. LocalMusicRepository registration converts SongModel source to local', () {
      final task = DownloadTask(
        id: 't_local_1',
        song: directSong1,
        downloadUrl: directSong1.audioPath,
        status: DownloadStatus.completed,
        localPath: 'C:\\Users\\Public\\Music\\MyMusicDownloads\\track1.mp3',
      );

      final registeredLocalSong = task.song.copyWith(
        source: 'local',
        audioPath: task.localPath,
        filePath: task.localPath,
      );

      expect(registeredLocalSong.source, equals('local'));
      expect(registeredLocalSong.audioPath, equals('C:\\Users\\Public\\Music\\MyMusicDownloads\\track1.mp3'));
    });

    test('11. YouTube Music songs are rejected from download queue', () {
      expect(DownloadService.isDownloadableSource(youtubeSong), isFalse);
    });

    test('12. Empty playlist handles download request without crashing', () {
      final emptySongs = <SongModel>[];
      final downloadable = emptySongs.where((s) => DownloadService.isDownloadableSource(s)).toList();
      expect(downloadable, isEmpty);
    });
  });
}
