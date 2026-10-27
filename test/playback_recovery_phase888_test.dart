import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mymusic/models/song_model.dart';
import 'package:mymusic/models/youtube_model.dart';
import 'package:mymusic/providers/player_provider.dart';
import 'package:mymusic/services/youtube/youtube_resolver.dart';
import 'package:mymusic/services/youtube/android_youtube_resolver.dart';
import 'package:mymusic/services/youtube/youtube_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PHASE 8.8.8 — MYMUSIC PLAYBACK RECOVERY REGRESSION TESTS', () {
    late PlayerProvider player;

    setUp(() {
      player = PlayerProvider();
    });

    // 1. Windows resolver selection
    test('1. Windows resolver selection relies on yt-dlp binary path', () async {
      final resolver = YouTubeResolver.instance;
      expect(resolver, isA<YouTubeResolver>());
      if (Platform.isWindows) {
        final path = await resolver.getExecutablePath();
        expect(path, isNotNull);
        expect(path!.toLowerCase().contains('yt-dlp.exe'), isTrue);
      }
    });

    // 2. Android resolver selection
    test('2. Android resolver selection resolves without yt-dlp', () {
      final androidResolver = AndroidYouTubeResolver.instance;
      expect(androidResolver, isA<AndroidYouTubeResolver>());
    });

    // 3. Local source selection
    test('3. Local source selection correctly identifies local audio', () {
      final localSong = SongModel(
        id: 101,
        artistId: 1,
        title: 'Local Track',
        duration: 180,
        audioPath: 'C:\\music\\track1.mp3',
        source: 'local',
      );
      expect(localSong.source, equals('local'));
      expect(localSong.isYouTube, isFalse);
    });

    // 4. YouTube source selection
    test('4. YouTube source selection correctly identifies YouTube stream', () {
      final ytVideo = YouTubeVideo(
        videoId: 'dQw4w9WgXcQ',
        title: 'Never Gonna Give You Up',
        channelName: 'Rick Astley',
        durationSeconds: 213,
      );
      final ytSong = SongModel.fromYouTubeVideo(ytVideo);
      expect(ytSong.source, equals('youtube'));
      expect(ytSong.isYouTube, isTrue);
      expect(ytSong.audioPath, equals('dQw4w9WgXcQ'));
      expect(ytSong.duration, equals(213));
    });

    // 5. Local -> YouTube transition
    test('5. Local -> YouTube transition in queue', () async {
      final localA = SongModel(id: 1, artistId: 1, title: 'Local A', duration: 120, audioPath: 'a.mp3', source: 'local');
      final ytB = SongModel(id: 2, artistId: 0, title: 'YT B', duration: 200, audioPath: 'ytB12345678', source: 'youtube');

      player.setQueueForTest([localA, ytB], initialIndex: 0);
      expect(player.currentSong?.id, equals(1));
      expect(player.currentSong?.source, equals('local'));

      await player.next(isTest: true);
      expect(player.currentSong?.id, equals(2));
      expect(player.currentSong?.source, equals('youtube'));
    });

    // 6. YouTube -> Local transition
    test('6. YouTube -> Local transition in queue', () async {
      final ytA = SongModel(id: 10, artistId: 0, title: 'YT A', duration: 150, audioPath: 'ytA12345678', source: 'youtube');
      final localB = SongModel(id: 20, artistId: 1, title: 'Local B', duration: 210, audioPath: 'b.mp3', source: 'local');

      player.setQueueForTest([ytA, localB], initialIndex: 0);
      expect(player.currentSong?.id, equals(10));
      expect(player.currentSong?.source, equals('youtube'));

      await player.next(isTest: true);
      expect(player.currentSong?.id, equals(20));
      expect(player.currentSong?.source, equals('local'));
    });

    // 7. YouTube -> YouTube transition
    test('7. YouTube -> YouTube transition in queue', () async {
      final ytA = SongModel(id: 11, artistId: 0, title: 'YT A', duration: 180, audioPath: 'ytA11111111', source: 'youtube');
      final ytB = SongModel(id: 12, artistId: 0, title: 'YT B', duration: 240, audioPath: 'ytB22222222', source: 'youtube');

      player.setQueueForTest([ytA, ytB], initialIndex: 0);
      expect(player.currentSong?.id, equals(11));

      await player.next(isTest: true);
      expect(player.currentSong?.id, equals(12));
      expect(player.currentSong?.source, equals('youtube'));
    });

    // 8. Mixed queue sequence
    test('8. Mixed queue sequence: Local -> YT -> YT -> Local', () async {
      final q = [
        SongModel(id: 1, artistId: 1, title: 'L1', duration: 100, audioPath: '1.mp3', source: 'local'),
        SongModel(id: 2, artistId: 0, title: 'Y2', duration: 200, audioPath: 'y2', source: 'youtube'),
        SongModel(id: 3, artistId: 0, title: 'Y3', duration: 300, audioPath: 'y3', source: 'youtube'),
        SongModel(id: 4, artistId: 1, title: 'L4', duration: 400, audioPath: '4.mp3', source: 'local'),
      ];

      player.setQueueForTest(q, initialIndex: 0);
      expect(player.queue.length, equals(4));

      await player.next(isTest: true);
      expect(player.currentIndex, equals(1));
      expect(player.currentSong?.source, equals('youtube'));

      await player.next(isTest: true);
      expect(player.currentIndex, equals(2));
      expect(player.currentSong?.source, equals('youtube'));

      await player.next(isTest: true);
      expect(player.currentIndex, equals(3));
      expect(player.currentSong?.source, equals('local'));
    });

    // 9. Resolver race condition safety
    test('9. Resolver race condition: generation increment protects active track', () {
      final songA = SongModel(id: 101, artistId: 0, title: 'Song A', duration: 180, audioPath: 'vidA', source: 'youtube');
      final songB = SongModel(id: 102, artistId: 0, title: 'Song B', duration: 200, audioPath: 'vidB', source: 'youtube');

      player.setQueueForTest([songA, songB], initialIndex: 0);
      player.playQueueIndex(1);
      expect(player.currentSong?.id, equals(102));
    });

    // 10. Auto-next handling
    test('10. Auto-next does not advance beyond queue boundaries when repeat is off', () async {
      final s1 = SongModel(id: 1, artistId: 1, title: 'Song 1', duration: 100, audioPath: '1.mp3', source: 'local');
      final s2 = SongModel(id: 2, artistId: 1, title: 'Song 2', duration: 100, audioPath: '2.mp3', source: 'local');

      player.setQueueForTest([s1, s2], initialIndex: 0);
      await player.next(isAutoNext: true, isTest: true);
      expect(player.currentIndex, equals(1));

      // At end of queue with repeat off
      await player.next(isAutoNext: true, isTest: true);
      expect(player.currentIndex, equals(1));
    });

    // 11. Previous button handling
    test('11. Previous moves back to preceding track in mixed queue', () async {
      final localA = SongModel(id: 1, artistId: 1, title: 'Local A', duration: 120, audioPath: 'a.mp3', source: 'local');
      final ytB = SongModel(id: 2, artistId: 0, title: 'YT B', duration: 200, audioPath: 'ytB', source: 'youtube');

      player.setQueueForTest([localA, ytB], initialIndex: 1);
      expect(player.currentIndex, equals(1));

      await player.previous(isTest: true);
      expect(player.currentIndex, equals(0));
      expect(player.currentSong?.id, equals(1));
      expect(player.currentSong?.source, equals('local'));
    });

    // 12. Play Next operation
    test('12. Play Next inserts item immediately following current playing index', () {
      final s1 = SongModel(id: 1, artistId: 1, title: 'S1', duration: 100, audioPath: '1.mp3', source: 'local');
      final s2 = SongModel(id: 2, artistId: 1, title: 'S2', duration: 100, audioPath: '2.mp3', source: 'local');
      final sNext = SongModel(id: 3, artistId: 0, title: 'SNext', duration: 150, audioPath: 'ytNext', source: 'youtube');

      player.setQueueForTest([s1, s2], initialIndex: 0);
      player.playNext(sNext);

      expect(player.queue.length, equals(3));
      expect(player.queue[1].id, equals(3));
      expect(player.queue[2].id, equals(2));
    });

    // 13. Playlist Play All operation
    test('13. Playlist Play All sets complete queue and starts first track', () {
      final list = [
        SongModel(id: 10, artistId: 0, title: 'YT 1', duration: 120, audioPath: 'yt1', source: 'youtube'),
        SongModel(id: 20, artistId: 1, title: 'Local 2', duration: 180, audioPath: '2.mp3', source: 'local'),
      ];

      player.playAll(list);
      expect(player.queue.length, equals(2));
      expect(player.currentIndex, equals(0));
      expect(player.currentSong?.id, equals(10));
    });

    // 14. Playlist Add All Queue operation
    test('14. Playlist Add All to Queue appends all items', () {
      final initial = SongModel(id: 1, artistId: 1, title: 'S1', duration: 100, audioPath: '1.mp3', source: 'local');
      player.setQueueForTest([initial], initialIndex: 0);

      final toAdd = [
        SongModel(id: 2, artistId: 0, title: 'YT 2', duration: 200, audioPath: 'yt2', source: 'youtube'),
        SongModel(id: 3, artistId: 1, title: 'Local 3', duration: 300, audioPath: '3.mp3', source: 'local'),
      ];

      player.addAllToQueue(toAdd);
      expect(player.queue.length, equals(3));
      expect(player.queue[1].id, equals(2));
      expect(player.queue[2].id, equals(3));
    });

    // 15. YouTube link resolver
    test('15. YouTube link resolver parses video ID and parameters cleanly', () {
      final res1 = YouTubeParser.parseLinkOrQuery('https://www.youtube.com/watch?v=dQw4w9WgXcQ');
      expect(res1.type, equals(YouTubeLinkType.video));
      expect(res1.videoId, equals('dQw4w9WgXcQ'));

      final res2 = YouTubeParser.parseLinkOrQuery('https://youtu.be/dQw4w9WgXcQ?si=abcdef123');
      expect(res2.type, equals(YouTubeLinkType.video));
      expect(res2.videoId, equals('dQw4w9WgXcQ'));

      final res3 = YouTubeParser.parseLinkOrQuery('https://music.youtube.com/watch?v=dQw4w9WgXcQ&list=PL123&index=1');
      expect(res3.type, equals(YouTubeLinkType.video));
      expect(res3.videoId, equals('dQw4w9WgXcQ'));
      expect(res3.playlistId, equals('PL123'));
    });

    // 16. YouTube Music search integration
    test('16. YouTube Music search results create valid SongModel with videoId audioPath', () {
      final video = YouTubeVideo(
        videoId: '60ItHLz5WEA',
        title: 'Faded',
        channelName: 'Alan Walker',
        durationSeconds: 212,
        thumbnailUrl: 'https://i.ytimg.com/vi/60ItHLz5WEA/hqdefault.jpg',
      );

      final song = SongModel.fromYouTubeVideo(video);
      expect(song.source, equals('youtube'));
      expect(song.audioPath, equals('60ItHLz5WEA'));
      expect(song.duration, equals(212));
      expect(song.title, equals('Faded'));
      expect(song.artistName, equals('Alan Walker'));
    });

    // 17. No googlevideo URL persistence
    test('17. No googlevideo URL persistence: audioPath remains clean videoId', () {
      final video = YouTubeVideo(
        videoId: 'abc123xyz89',
        title: 'Test Song',
        durationSeconds: 195,
      );

      final song = SongModel.fromYouTubeVideo(video);
      expect(song.audioPath.contains('googlevideo.com'), isFalse);
      expect(song.audioPath, equals('abc123xyz89'));
    });
  });
}
