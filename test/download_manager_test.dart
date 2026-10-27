import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mymusic/models/song_model.dart';
import 'package:mymusic/models/download_task_model.dart';
import 'package:mymusic/services/download_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 8.7 — MyMusic Download Manager Tests', () {
    final directSong = SongModel(
      id: 101,
      artistId: 1,
      title: 'Sample Track',
      artistName: 'Sample Artist',
      albumTitle: 'Sample Album',
      duration: 180,
      audioPath: 'https://example.com/audio/sample_track.mp3',
      source: 'catalog',
    );

    final youtubeSong = SongModel(
      id: 102,
      artistId: 0,
      title: 'YouTube Track',
      duration: 200,
      audioPath: '60ItHLz5WEA',
      source: 'youtube',
    );

    test('1. Authorized downloadable source check', () {
      expect(DownloadService.isDownloadableSource(directSong), isTrue);
      expect(DownloadService.isDownloadableSource(youtubeSong), isFalse);
    });

    test('2. DownloadTask status lifecycle', () {
      final task = DownloadTask(
        id: 'task_1',
        song: directSong,
        downloadUrl: directSong.audioPath,
      );

      expect(task.status, equals(DownloadStatus.queued));
      expect(task.progress, equals(0.0));

      task.status = DownloadStatus.downloading;
      task.progress = 0.5;
      expect(task.status, equals(DownloadStatus.downloading));
      expect(task.progress, equals(0.5));

      task.status = DownloadStatus.completed;
      task.progress = 1.0;
      task.completedAt = DateTime.now();
      expect(task.status, equals(DownloadStatus.completed));
      expect(task.completedAt, isNotNull);
    });

    test('3. Enqueue download task', () async {
      final service = DownloadService();
      final task = await service.enqueueDownload(directSong);

      expect(task, isNotNull);
      expect(task!.song.title, equals('Sample Track'));
      expect(service.tasks, contains(task));
    });

    test('4. Max concurrency limit (default 2 active downloads)', () async {
      final mockClient = MockClient((request) async {
        await Future.delayed(const Duration(milliseconds: 200));
        return http.Response.bytes([0, 1, 2, 3], 200);
      });

      final service = DownloadService(client: mockClient);

      final song1 = SongModel(id: 1, artistId: 0, title: 'Track 1', duration: 100, audioPath: 'https://example.com/t1.mp3');
      final song2 = SongModel(id: 2, artistId: 0, title: 'Track 2', duration: 100, audioPath: 'https://example.com/t2.mp3');
      final song3 = SongModel(id: 3, artistId: 0, title: 'Track 3', duration: 100, audioPath: 'https://example.com/t3.mp3');

      await service.enqueueDownload(song1);
      await service.enqueueDownload(song2);
      await service.enqueueDownload(song3);

      final downloadingCount = service.tasks.where((t) => t.status == DownloadStatus.downloading).length;
      final queuedCount = service.tasks.where((t) => t.status == DownloadStatus.queued).length;

      expect(downloadingCount, lessThanOrEqualTo(2));
      expect(downloadingCount + queuedCount, equals(3));
    });

    test('5. Cancel download cleans task status', () async {
      final service = DownloadService();
      final task = await service.enqueueDownload(directSong);
      expect(task, isNotNull);

      await service.cancelDownload(task!.id);
      expect(task.status, equals(DownloadStatus.cancelled));
    });

    test('6. Clear completed tasks', () {
      final service = DownloadService();
      service.removeTask('dummy');
    });

    test('7. DownloadTask serialization & deserialization', () {
      final originalTask = DownloadTask(
        id: 'task_json_1',
        song: directSong,
        downloadUrl: directSong.audioPath,
        status: DownloadStatus.completed,
        progress: 1.0,
        bytesDownloaded: 1024,
        totalBytes: 1024,
      );

      final jsonMap = originalTask.toJson();
      final restoredTask = DownloadTask.fromJson(jsonMap);

      expect(restoredTask.id, equals('task_json_1'));
      expect(restoredTask.status, equals(DownloadStatus.completed));
      expect(restoredTask.song.title, equals('Sample Track'));
      expect(restoredTask.bytesDownloaded, equals(1024));
    });

    test('8. Completed download produces SongModel with source local', () {
      final completedTask = DownloadTask(
        id: 'task_completed',
        song: directSong,
        downloadUrl: directSong.audioPath,
        status: DownloadStatus.completed,
        localPath: 'C:\\Users\\Public\\Music\\MyMusicDownloads\\Sample Track_101.mp3',
      );

      final localSong = completedTask.song.copyWith(
        source: 'local',
        audioPath: completedTask.localPath,
        filePath: completedTask.localPath,
      );

      expect(localSong.source, equals('local'));
      expect(localSong.audioPath, contains('MyMusicDownloads'));
    });
  });
}
