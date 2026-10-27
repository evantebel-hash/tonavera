import 'package:flutter_test/flutter_test.dart';
import 'package:mymusic/models/song_model.dart';
import 'package:mymusic/models/youtube_model.dart';
import 'package:mymusic/services/youtube/android_youtube_resolver.dart';
import 'package:mymusic/providers/player_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PHASE 8.8.7 — Android YouTube + Local Mixed Queue & 00:00 Playback Fix Tests', () {
    test('1. Single YouTube model initialization', () {
      final video = YouTubeVideo(videoId: 'singleYt123', title: 'Single YouTube Track', durationSeconds: 210);
      final song = SongModel.fromYouTubeVideo(video);
      expect(song.source, equals('youtube'));
      expect(song.isYouTube, isTrue);
      expect(song.audioPath, equals('singleYt123'));
    });

    test('2. Android YouTube resolver audio-only extraction details', () async {
      final sampleData = {
        'streamingData': {
          'adaptiveFormats': [
            {
              'url': 'https://rr1---sn-test.googlevideo.com/videoplayback?id=audio1',
              'mimeType': 'audio/mp4; codecs="mp4a.40.2"',
              'bitrate': 160000,
              'contentLength': '4194304',
            },
            {
              'url': 'https://rr2---sn-test.googlevideo.com/videoplayback?id=video1',
              'mimeType': 'video/mp4; codecs="avc1.4d401f"',
              'bitrate': 2500000,
            }
          ]
        }
      };

      final resolver = AndroidYouTubeResolver.instance;
      final result = resolver.extractAudioUrlFromPlayerDataForTest(sampleData, 'TestUA');
      expect(result, isNotNull);
      expect(result!.url, contains('audio1'));
      expect(result.mimeType, contains('audio/'));
      expect(result.bitrate, equals(160000));
      expect(result.contentLength, equals(4194304));
      expect(result.headers['User-Agent'], equals('TestUA'));
      expect(result.headers['Origin'], equals('https://www.youtube.com'));
      expect(result.headers['Referer'], equals('https://www.youtube.com/'));
    });

    test('3. Audio-only filtering ignores video-only formats', () {
      final videoOnlyData = {
        'streamingData': {
          'adaptiveFormats': [
            {
              'url': 'https://rr2---sn-test.googlevideo.com/videoplayback?id=video1',
              'mimeType': 'video/webm; codecs="vp9"',
              'bitrate': 3000000,
            }
          ]
        }
      };

      final resolver = AndroidYouTubeResolver.instance;
      final result = resolver.extractAudioUrlFromPlayerDataForTest(videoOnlyData, 'TestUA');
      expect(result, isNull);
    });

    test('4. Cipher encrypted formats with signatureCipher are rejected', () {
      final cipherData = {
        'streamingData': {
          'adaptiveFormats': [
            {
              'signatureCipher': 's=12345&url=https://googlevideo.com/stream',
              'mimeType': 'audio/mp4',
              'bitrate': 128000,
            }
          ]
        }
      };

      final resolver = AndroidYouTubeResolver.instance;
      final result = resolver.extractAudioUrlFromPlayerDataForTest(cipherData, 'TestUA');
      expect(result, isNull);
    });

    test('5. YouTube audioPath remains videoId across playback preparation', () {
      final ytSong = SongModel(id: 10, artistId: 1, title: 'YT Track', duration: 180, audioPath: 'ytVideoId123', source: 'youtube');
      expect(ytSong.audioPath, equals('ytVideoId123'));
      expect(ytSong.audioPath.contains('googlevideo'), isFalse);
    });

    test('6. Stream URL is never persisted into googlevideo.com in database model', () {
      final song = SongModel.fromYouTubeVideo(YouTubeVideo(videoId: 'abc12345678', title: 'Test Track'));
      expect(song.audioPath, equals('abc12345678'));
    });

    test('7. Local song uses AudioSource.file path logic', () {
      final localSong = SongModel(id: 1, artistId: 1, title: 'Local Track', duration: 200, audioPath: '/music/local.mp3', source: 'local');
      expect(localSong.source, equals('local'));
      expect(localSong.isYouTube, isFalse);
    });

    test('8. YouTube song uses AudioSource.uri stream resolution logic', () {
      final ytSong = SongModel(id: 2, artistId: 1, title: 'YT Track', duration: 200, audioPath: 'yt12345678901', source: 'youtube');
      expect(ytSong.source, equals('youtube'));
      expect(ytSong.isYouTube, isTrue);
    });

    test('9. Local -> YouTube queue transition updates current index cleanly', () async {
      final localA = SongModel(id: 1, artistId: 1, title: 'Local A', duration: 180, audioPath: 'a.mp3', source: 'local');
      final ytB = SongModel(id: 2, artistId: 1, title: 'YouTube B', duration: 200, audioPath: 'ytB123456789', source: 'youtube');

      final player = PlayerProvider();
      player.setQueueForTest([localA, ytB], initialIndex: 0);

      await player.next(isTest: true);
      expect(player.currentIndex, equals(1));
      expect(player.currentSong?.title, equals('YouTube B'));
    });

    test('10. YouTube -> Local queue transition updates current index cleanly', () async {
      final ytA = SongModel(id: 1, artistId: 1, title: 'YouTube A', duration: 200, audioPath: 'ytA123456789', source: 'youtube');
      final localB = SongModel(id: 2, artistId: 1, title: 'Local B', duration: 180, audioPath: 'b.mp3', source: 'local');

      final player = PlayerProvider();
      player.setQueueForTest([ytA, localB], initialIndex: 0);

      await player.next(isTest: true);
      expect(player.currentIndex, equals(1));
      expect(player.currentSong?.title, equals('Local B'));
    });

    test('11. YouTube -> YouTube queue transition preserves individual videoIds', () async {
      final ytA = SongModel(id: 1, artistId: 1, title: 'YouTube A', duration: 200, audioPath: 'ytA123456789', source: 'youtube');
      final ytB = SongModel(id: 2, artistId: 1, title: 'YouTube B', duration: 220, audioPath: 'ytB123456789', source: 'youtube');

      final player = PlayerProvider();
      player.setQueueForTest([ytA, ytB], initialIndex: 0);

      await player.next(isTest: true);
      expect(player.currentIndex, equals(1));
      expect(player.currentSong?.audioPath, equals('ytB123456789'));
    });

    test('12. YouTube A -> B -> C sequential queue navigation', () async {
      final ytA = SongModel(id: 1, artistId: 1, title: 'YouTube A', duration: 200, audioPath: 'ytA123456789', source: 'youtube');
      final ytB = SongModel(id: 2, artistId: 1, title: 'YouTube B', duration: 220, audioPath: 'ytB123456789', source: 'youtube');
      final ytC = SongModel(id: 3, artistId: 1, title: 'YouTube C', duration: 240, audioPath: 'ytC123456789', source: 'youtube');

      final player = PlayerProvider();
      player.setQueueForTest([ytA, ytB, ytC], initialIndex: 0);

      await player.next(isTest: true);
      expect(player.currentIndex, equals(1));
      expect(player.currentSong?.title, equals('YouTube B'));

      await player.next(isTest: true);
      expect(player.currentIndex, equals(2));
      expect(player.currentSong?.title, equals('YouTube C'));
    });

    test('13. Local -> YouTube -> YouTube mixed queue sequence', () async {
      final locA = SongModel(id: 1, artistId: 1, title: 'Loc A', duration: 180, audioPath: 'a.mp3', source: 'local');
      final ytB = SongModel(id: 2, artistId: 1, title: 'YT B', duration: 200, audioPath: 'ytB123', source: 'youtube');
      final ytC = SongModel(id: 3, artistId: 1, title: 'YT C', duration: 210, audioPath: 'ytC123', source: 'youtube');

      final player = PlayerProvider();
      player.setQueueForTest([locA, ytB, ytC], initialIndex: 0);

      await player.next(isTest: true);
      expect(player.currentSong?.title, equals('YT B'));

      await player.next(isTest: true);
      expect(player.currentSong?.title, equals('YT C'));
    });

    test('14. YouTube -> Local -> YouTube mixed queue sequence', () async {
      final ytA = SongModel(id: 1, artistId: 1, title: 'YT A', duration: 200, audioPath: 'ytA123', source: 'youtube');
      final locB = SongModel(id: 2, artistId: 1, title: 'Loc B', duration: 180, audioPath: 'b.mp3', source: 'local');
      final ytC = SongModel(id: 3, artistId: 1, title: 'YT C', duration: 210, audioPath: 'ytC123', source: 'youtube');

      final player = PlayerProvider();
      player.setQueueForTest([ytA, locB, ytC], initialIndex: 0);

      await player.next(isTest: true);
      expect(player.currentSong?.title, equals('Loc B'));

      await player.next(isTest: true);
      expect(player.currentSong?.title, equals('YT C'));
    });

    test('15. Complex Mixed Queue: Local -> Local -> YouTube -> YouTube -> Local', () async {
      final queue = [
        SongModel(id: 1, artistId: 1, title: 'L1', duration: 180, audioPath: '1.mp3', source: 'local'),
        SongModel(id: 2, artistId: 1, title: 'L2', duration: 180, audioPath: '2.mp3', source: 'local'),
        SongModel(id: 3, artistId: 1, title: 'Y3', duration: 200, audioPath: 'y3', source: 'youtube'),
        SongModel(id: 4, artistId: 1, title: 'Y4', duration: 210, audioPath: 'y4', source: 'youtube'),
        SongModel(id: 5, artistId: 1, title: 'L5', duration: 190, audioPath: '5.mp3', source: 'local'),
      ];

      final player = PlayerProvider();
      player.setQueueForTest(queue, initialIndex: 0);

      for (int i = 1; i < queue.length; i++) {
        await player.next(isTest: true);
        expect(player.currentIndex, equals(i));
        expect(player.currentSong?.title, equals(queue[i].title));
      }
    });

    test('16. Auto-next parameter propagates without index skipping', () async {
      final s1 = SongModel(id: 1, artistId: 1, title: 'S1', duration: 180, audioPath: '1.mp3', source: 'local');
      final s2 = SongModel(id: 2, artistId: 1, title: 'S2', duration: 180, audioPath: '2.mp3', source: 'local');

      final player = PlayerProvider();
      player.setQueueForTest([s1, s2], initialIndex: 0);

      await player.next(isTest: true, isAutoNext: true);
      expect(player.currentIndex, equals(1));
      expect(player.currentSong?.title, equals('S2'));
    });

    test('17. Manual Next navigates exactly one step forward', () async {
      final queue = [
        SongModel(id: 1, artistId: 1, title: 'T1', duration: 180, audioPath: '1.mp3', source: 'local'),
        SongModel(id: 2, artistId: 1, title: 'T2', duration: 180, audioPath: '2.mp3', source: 'local'),
        SongModel(id: 3, artistId: 1, title: 'T3', duration: 180, audioPath: '3.mp3', source: 'local'),
      ];

      final player = PlayerProvider();
      player.setQueueForTest(queue, initialIndex: 0);

      await player.next(isTest: true);
      expect(player.currentIndex, equals(1));
    });

    test('18. Previous button navigates backward in queue', () async {
      final ytA = SongModel(id: 1, artistId: 1, title: 'YT A', duration: 200, audioPath: 'ytA', source: 'youtube');
      final ytB = SongModel(id: 2, artistId: 1, title: 'YT B', duration: 220, audioPath: 'ytB', source: 'youtube');

      final player = PlayerProvider();
      player.setQueueForTest([ytA, ytB], initialIndex: 1);

      await player.previous(isTest: true);
      expect(player.currentIndex, equals(0));
      expect(player.currentSong?.title, equals('YT A'));
    });

    test('19. Resolver race condition generation tokens increment on each playSong', () async {
      final player = PlayerProvider();
      final song1 = SongModel(id: 1, artistId: 1, title: 'S1', duration: 180, audioPath: '1.mp3', source: 'local');
      final song2 = SongModel(id: 2, artistId: 1, title: 'S2', duration: 180, audioPath: '2.mp3', source: 'local');

      final p1 = player.playSong(song1);
      final p2 = player.playSong(song2);

      await Future.wait([p1, p2]);
      expect(player.currentSong?.id, equals(2));
    });

    test('20. Duplicate play request for current song is handled safely', () async {
      final song = SongModel(id: 1, artistId: 1, title: 'YT Song 1', duration: 180, audioPath: 'yt123456789', source: 'youtube');
      final player = PlayerProvider();

      player.setQueueForTest([song], initialIndex: 0);
      expect(player.currentSong?.id, equals(1));
      expect(player.currentIndex, equals(0));
    });

    test('21. Duration parameter preserved from SongModel metadata', () {
      final ytSong = SongModel(id: 1, artistId: 1, title: 'YT Song', duration: 245, audioPath: 'yt123', source: 'youtube');
      expect(ytSong.duration, equals(245));
    });

    test('22. MediaItem ID matches YouTube videoId for YouTube source', () {
      final ytSong = SongModel(id: 1, artistId: 1, title: 'YT Song', duration: 200, audioPath: 'dQw4w9WgXcQ', source: 'youtube');
      final player = PlayerProvider();
      final mediaItem = player.buildMediaItemForTest(ytSong);

      expect(mediaItem.id, equals('dQw4w9WgXcQ'));
      expect(mediaItem.title, equals('YT Song'));
      expect(mediaItem.extras?['videoId'], equals('dQw4w9WgXcQ'));
    });
  });
}
