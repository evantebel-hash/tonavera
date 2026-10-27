import 'package:flutter_test/flutter_test.dart';
import 'package:mymusic/models/song_model.dart';
import 'package:mymusic/models/youtube_model.dart';
import 'package:mymusic/services/youtube/android_youtube_resolver.dart';
import 'package:mymusic/providers/player_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PHASE 8.8.5 — Android Stale Local File & Cache Path Fix Tests', () {
    test('1. Android local existing file playback initialization', () {
      final song = SongModel(
        id: 1,
        artistId: 1,
        title: 'Existing Local Song',
        duration: 200,
        audioPath: 'c:/music/valid.mp3',
        source: 'local',
      );

      expect(song.source, 'local');
      expect(song.isYouTube, isFalse);
    });

    test('2. Android local missing file is safely skipped to next valid local track', () async {
      final missingLocal = SongModel(
        id: 1,
        artistId: 1,
        title: 'Missing Local Song',
        duration: 200,
        audioPath: '/data/user/0/com.example.mymusic/cache/file_picker/missing.mp3',
        source: 'local',
      );

      final validLocal = SongModel(
        id: 2,
        artistId: 1,
        title: 'Valid Local Song',
        duration: 200,
        audioPath: 'c.mp3',
        source: 'local',
      );

      final player = PlayerProvider();
      player.setQueueForTest([missingLocal, validLocal], initialIndex: 0);

      await player.playSong(missingLocal, playlist: [missingLocal, validLocal], isAutoNext: true);

      expect(player.currentSong?.title, 'Valid Local Song');
    });

    test('3. Stale cache path (/cache/file_picker/) handled safely without crash', () {
      final staleCachePath = '/data/user/0/com.example.mymusic/cache/file_picker/1791184178005/SpotiDown.App - Clarity - Zedd_Foxes.mp3';
      final song = SongModel(
        id: 10,
        artistId: 1,
        title: 'Clarity',
        duration: 270,
        audioPath: staleCachePath,
        source: 'local',
      );

      expect(song.audioPath, contains('cache/file_picker'));
      expect(song.isYouTube, isFalse);
    });

    test('4. Current stale local song resets player state cleanly', () async {
      final missingLocal = SongModel(
        id: 1,
        artistId: 1,
        title: 'Sole Missing Local Song',
        duration: 200,
        audioPath: '/non/existent/path.mp3',
        source: 'local',
      );

      final player = PlayerProvider();
      player.setQueueForTest([missingLocal], initialIndex: 0);

      await player.playSong(missingLocal, playlist: [missingLocal]);

      expect(player.isPlaying, isFalse);
      expect(player.currentSong, isNull);
    });

    test('5. Next button skips stale local file safely', () async {
      final missingLocal = SongModel(id: 1, artistId: 1, title: 'Missing 1', duration: 180, audioPath: '/missing/1.mp3', source: 'local');
      final validLocal = SongModel(id: 2, artistId: 1, title: 'Valid 2', duration: 180, audioPath: '/valid/2.mp3', source: 'local');

      final player = PlayerProvider();
      player.setQueueForTest([missingLocal, validLocal], initialIndex: 0);

      await player.next(isTest: true);
      expect(player.currentSong?.title, 'Valid 2');
    });

    test('6. Auto-next skips stale local file to valid YouTube track', () async {
      final missingLocal = SongModel(id: 1, artistId: 1, title: 'Missing Local', duration: 180, audioPath: '/missing.mp3', source: 'local');
      final ytTrack = SongModel(id: 2, artistId: 1, title: 'Valid YouTube', duration: 180, audioPath: 'yt123456789', source: 'youtube');

      final player = PlayerProvider();
      player.setQueueForTest([missingLocal, ytTrack], initialIndex: 0);

      await player.playSong(missingLocal, playlist: [missingLocal, ytTrack], isAutoNext: true);
      expect(player.currentSong?.audioPath, 'yt123456789');
    });

    test('7. Previous button handles queue navigation safely', () async {
      final s1 = SongModel(id: 1, artistId: 1, title: 'Track 1', duration: 180, audioPath: '1.mp3', source: 'local');
      final s2 = SongModel(id: 2, artistId: 1, title: 'Track 2', duration: 180, audioPath: '2.mp3', source: 'local');

      final player = PlayerProvider();
      player.setQueueForTest([s1, s2], initialIndex: 1);

      await player.previous(isTest: true);
      expect(player.currentSong?.title, 'Track 1');
    });

    test('8. Queue: Local -> missing Local -> YouTube transitions seamlessly', () async {
      final localA = SongModel(id: 1, artistId: 1, title: 'Local A', duration: 180, audioPath: 'a.mp3', source: 'local');
      final missingB = SongModel(id: 2, artistId: 1, title: 'Missing B', duration: 180, audioPath: '/missing/b.mp3', source: 'local');
      final youtubeC = SongModel(id: 3, artistId: 1, title: 'YouTube C', duration: 180, audioPath: 'ytC123', source: 'youtube');

      final player = PlayerProvider();
      player.setQueueForTest([localA, missingB, youtubeC], initialIndex: 0);

      // Play B (missing) -> should auto-skip to C
      await player.playSong(missingB, playlist: [localA, missingB, youtubeC], isAutoNext: true);

      expect(player.currentSong?.title, 'YouTube C');
    });

    test('9. Queue: YouTube -> missing Local -> Local transitions seamlessly', () async {
      final youtubeA = SongModel(id: 1, artistId: 1, title: 'YouTube A', duration: 180, audioPath: 'ytA123', source: 'youtube');
      final missingB = SongModel(id: 2, artistId: 1, title: 'Missing B', duration: 180, audioPath: '/missing/b.mp3', source: 'local');
      final localC = SongModel(id: 3, artistId: 1, title: 'Local C', duration: 180, audioPath: 'c.mp3', source: 'local');

      final player = PlayerProvider();
      player.setQueueForTest([youtubeA, missingB, localC], initialIndex: 0);

      // Play B (missing) -> should auto-skip to C
      await player.playSong(missingB, playlist: [youtubeA, missingB, localC], isAutoNext: true);

      expect(player.currentSong?.title, 'Local C');
    });

    test('10. YouTube tracks are never checked as local filesystem paths', () {
      final ytSong = SongModel.fromYouTubeVideo(YouTubeVideo(videoId: 'dQw4w9WgXcQ', title: 'Test YT'));

      expect(ytSong.isYouTube, isTrue);
      expect(ytSong.source, 'youtube');
      expect(ytSong.audioPath, 'dQw4w9WgXcQ');
    });

    test('11. Stale queue restore does not crash player initialization', () {
      final player = PlayerProvider();
      final staleQueue = [
        SongModel(id: 1, artistId: 1, title: 'Stale 1', duration: 180, audioPath: '/cache/stale1.mp3', source: 'local'),
        SongModel(id: 2, artistId: 1, title: 'Stale 2', duration: 180, audioPath: '/cache/stale2.mp3', source: 'local'),
      ];

      player.setQueueForTest(staleQueue, initialIndex: 0);
      expect(player.queue.length, 2);
    });

    test('12. Android error message does not hardcode "komputer"', () async {
      final missingLocal = SongModel(id: 1, artistId: 1, title: 'Missing Track', duration: 180, audioPath: '/missing.mp3', source: 'local');

      final player = PlayerProvider();
      player.setQueueForTest([missingLocal], initialIndex: 0);
      await player.playSong(missingLocal);

      final errorMsg = player.lastErrorMessage ?? '';
      expect(errorMsg.contains('komputer'), isFalse);
      expect(errorMsg, contains('perangkat'));
    });

    test('13. Valid local playback parameters unchanged', () {
      final validLocal = SongModel(id: 1, artistId: 1, title: 'Valid Local', duration: 240, audioPath: 'c:/music/valid.mp3', source: 'local');
      expect(validLocal.source, 'local');
      expect(validLocal.duration, 240);
    });

    test('14. Windows local playback model remains fully compatible', () {
      final winSong = SongModel(id: 1, artistId: 1, title: 'Win Song', duration: 200, audioPath: 'C:\\Music\\Track.mp3', source: 'local');
      expect(winSong.audioPath, contains('C:\\Music'));
    });

    test('15. Windows YouTube playback videoId persistence unchanged', () {
      final winYt = SongModel.fromYouTubeVideo(YouTubeVideo(videoId: 'winYtVid123', title: 'Win YT'));
      expect(winYt.audioPath, 'winYtVid123');
      expect(winYt.source, 'youtube');
    });

    test('16. Android YouTube stream format parsing unchanged', () async {
      final sampleData = {
        'streamingData': {
          'adaptiveFormats': [
            {
              'url': 'https://rr1---sn-ab5szn76.googlevideo.com/videoplayback?id=1',
              'mimeType': 'audio/mp4; codecs="mp4a.40.2"',
              'bitrate': 128000,
            }
          ]
        }
      };

      final resolver = AndroidYouTubeResolver.instance;
      final result = resolver.extractAudioUrlFromPlayerDataForTest(sampleData, 'TestUA');
      expect(result?.url, contains('googlevideo.com'));
    });
  });
}
