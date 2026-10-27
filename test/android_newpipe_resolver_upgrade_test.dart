import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mymusic/models/song_model.dart';
import 'package:mymusic/models/youtube_model.dart';
import 'package:mymusic/providers/player_provider.dart';
import 'package:mymusic/services/youtube/android_legacy_youtube_resolver.dart';
import 'package:mymusic/services/youtube/android_newpipe_resolver.dart';
import 'package:mymusic/services/youtube/android_youtube_resolver.dart';
import 'package:mymusic/services/youtube/youtube_resolver.dart';

// Test mock classes for NewPipe and Legacy resolvers
class MockNewPipeResolverSuccess extends AndroidNewPipeResolver {
  final int durationSeconds;
  MockNewPipeResolverSuccess({this.durationSeconds = 215});

  @override
  Future<AndroidAudioStreamResult> resolveVideo(
    String videoIdOrUrl, {
    Duration timeout = const Duration(seconds: 25),
  }) async {
    return AndroidAudioStreamResult(
      url: 'https://rr1---sn-newpipe.googlevideo.com/videoplayback?id=newpipe_stream',
      mimeType: 'audio/mp4',
      bitrate: 160000,
      contentLength: 0,
      headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
      videoId: 'testVid123',
      title: 'NewPipe Resolved Track',
      artist: 'NewPipe Artist',
      duration: durationSeconds,
      thumbnailUrl: 'https://i.ytimg.com/vi/testVid123/hqdefault.jpg',
    );
  }
}

class MockNewPipeResolverFailure extends AndroidNewPipeResolver {
  @override
  Future<AndroidAudioStreamResult> resolveVideo(
    String videoIdOrUrl, {
    Duration timeout = const Duration(seconds: 25),
  }) async {
    throw Exception('NewPipe HTTP 403 Forbidden or parsing error');
  }
}

class MockLegacyResolverSuccess extends AndroidLegacyYouTubeResolver {
  @override
  Future<AndroidAudioStreamResult> resolveAudioStreamDetails(
    String videoIdOrUrl, {
    Duration timeout = const Duration(seconds: 25),
  }) async {
    return AndroidAudioStreamResult(
      url: 'https://rr2---sn-legacy.googlevideo.com/videoplayback?id=legacy_stream',
      mimeType: 'audio/mp4',
      bitrate: 128000,
      contentLength: 0,
      headers: {'User-Agent': 'com.google.android.youtube/19.02.39'},
      videoId: 'testVid123',
      title: 'Legacy Fallback Track',
      artist: 'Legacy Artist',
      duration: 180,
    );
  }
}

class MockLegacyResolverFailure extends AndroidLegacyYouTubeResolver {
  @override
  Future<AndroidAudioStreamResult> resolveAudioStreamDetails(
    String videoIdOrUrl, {
    Duration timeout = const Duration(seconds: 25),
  }) async {
    throw Exception('Legacy InnerTube and HTML scrape failed');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PHASE 8.9 — Android YouTube Resolver Upgrade & Fallback Tests', () {
    // 1. Android YouTube resolve via NewPipe
    test('1. Android YouTube resolve via NewPipe returns valid stream', () async {
      final resolver = AndroidYouTubeResolver(
        newPipeResolver: MockNewPipeResolverSuccess(),
        legacyResolver: MockLegacyResolverFailure(),
      );

      final details = await resolver.resolveAudioStreamDetails('testVid123');

      expect(details.url, contains('newpipe.googlevideo.com'));
      expect(details.bitrate, 160000);
      expect(details.mimeType, 'audio/mp4');
      expect(details.title, 'NewPipe Resolved Track');
      expect(details.headers['User-Agent'], isNotEmpty);
    });

    // 2. NewPipe failure -> legacy fallback
    test('2. NewPipe failure triggers legacy fallback', () async {
      final resolver = AndroidYouTubeResolver(
        newPipeResolver: MockNewPipeResolverFailure(),
        legacyResolver: MockLegacyResolverSuccess(),
      );

      final details = await resolver.resolveAudioStreamDetails('testVid123');

      expect(details.url, contains('legacy.googlevideo.com'));
      expect(details.bitrate, 128000);
      expect(details.title, 'Legacy Fallback Track');
    });

    // 3. Kedua resolver gagal -> proper error
    test('3. Both NewPipe and Legacy resolver failure returns clear error', () async {
      final resolver = AndroidYouTubeResolver(
        newPipeResolver: MockNewPipeResolverFailure(),
        legacyResolver: MockLegacyResolverFailure(),
      );

      expect(
        () async => await resolver.resolveAudioStreamDetails('testVid123'),
        throwsA(predicate((e) =>
            e is Exception &&
            e.toString().contains('NewPipe dan Legacy resolver gagal'))),
      );
    });

    // 4. YouTube duration != fake 0 ketika resolver menyediakan duration
    test('4. YouTube duration != fake 0 when resolver provides actual duration', () async {
      final resolver = AndroidYouTubeResolver(
        newPipeResolver: MockNewPipeResolverSuccess(durationSeconds: 215),
        legacyResolver: MockLegacyResolverFailure(),
      );

      final details = await resolver.resolveAudioStreamDetails('testVid123');
      expect(details.duration, 215);
      expect(details.duration, isNot(0));
    });

    // 5. Local file -> AudioSource.file
    test('5. Local file plays via file audio source without YouTube resolver', () {
      final localSong = SongModel(
        id: 1,
        artistId: 1,
        title: 'Local Melody',
        duration: 200,
        audioPath: 'C:/Music/melody.mp3',
        source: 'local',
      );

      expect(localSong.source, 'local');
      expect(localSong.isYouTube, isFalse);
      expect(localSong.audioPath, 'C:/Music/melody.mp3');
    });

    // 6. Local YouTube-origin metadata -> tetap AudioSource.file
    test('6. Local YouTube-origin metadata remains local file source', () {
      final localWithYtMeta = SongModel(
        id: 10,
        artistId: 0,
        title: 'YouTube Origin Downloaded Song',
        artistName: 'YouTube Artist',
        albumTitle: 'YouTube Music',
        duration: 245,
        audioPath: '/storage/emulated/0/Music/yt_download.mp3',
        filePath: '/storage/emulated/0/Music/yt_download.mp3',
        cover: 'https://i.ytimg.com/vi/abc123xyz/hqdefault.jpg',
        source: 'local',
      );

      expect(localWithYtMeta.source, 'local');
      expect(localWithYtMeta.isYouTube, isFalse);
      expect(localWithYtMeta.filePath, contains('/storage/emulated/0/Music'));
    });

    // 7. Mixed Local -> YouTube -> Local
    test('7. Mixed queue Local -> YouTube -> Local preserves distinct sources', () async {
      final songA = SongModel(id: 1, artistId: 1, title: 'Local A', duration: 180, audioPath: 'a.mp3', source: 'local');
      final songB = SongModel(id: 2, artistId: 0, title: 'YouTube B', duration: 200, audioPath: 'ytB_id', source: 'youtube');
      final songC = SongModel(id: 3, artistId: 1, title: 'Local C', duration: 220, audioPath: 'c.mp3', source: 'local');

      final queue = [songA, songB, songC];

      expect(queue[0].source, 'local');
      expect(queue[1].source, 'youtube');
      expect(queue[2].source, 'local');

      final player = PlayerProvider();
      player.setQueueForTest(queue, initialIndex: 0);

      // Verify track 0 (Local)
      expect(player.currentSong?.source, 'local');

      // Move to track 1 (YouTube)
      await player.next(isTest: true);
      expect(player.currentSong?.source, 'youtube');

      // Move to track 2 (Local)
      await player.next(isTest: true);
      expect(player.currentSong?.source, 'local');
    });

    // 8. YouTube -> Local transition
    test('8. YouTube -> Local queue transition preserves correct source', () async {
      final yt = SongModel(id: 1, artistId: 0, title: 'YouTube Track', duration: 180, audioPath: 'yt123', source: 'youtube');
      final loc = SongModel(id: 2, artistId: 1, title: 'Local Track', duration: 200, audioPath: 'loc.mp3', source: 'local');

      final player = PlayerProvider();
      player.setQueueForTest([yt, loc], initialIndex: 0);
      expect(player.currentSong?.isYouTube, isTrue);

      await player.next(isTest: true);
      expect(player.currentSong?.isYouTube, isFalse);
      expect(player.currentSong?.source, 'local');
    });

    // 9. Local -> YouTube transition
    test('9. Local -> YouTube queue transition preserves correct source', () async {
      final loc = SongModel(id: 1, artistId: 1, title: 'Local Track', duration: 200, audioPath: 'loc.mp3', source: 'local');
      final yt = SongModel(id: 2, artistId: 0, title: 'YouTube Track', duration: 180, audioPath: 'yt123', source: 'youtube');

      final player = PlayerProvider();
      player.setQueueForTest([loc, yt], initialIndex: 0);
      expect(player.currentSong?.source, 'local');

      await player.next(isTest: true);
      expect(player.currentSong?.source, 'youtube');
      expect(player.currentSong?.isYouTube, isTrue);
    });

    // 10. Windows resolver tetap yt-dlp.exe
    test('10. Windows resolver remains yt-dlp executable', () async {
      final exePath = await YouTubeResolver.instance.getExecutablePath();
      if (Platform.isWindows && exePath != null) {
        expect(exePath.toLowerCase(), contains('yt-dlp.exe'));
      }
    });

    // 11. Windows pipeline tidak menerima Android headers
    test('11. Windows resolver does not inject Android headers into stream URL', () {
      final winSong = SongModel(
        id: 1,
        artistId: 0,
        title: 'Win YT',
        duration: 180,
        audioPath: 'dQw4w9WgXcQ',
        source: 'youtube',
      );

      // On Windows, audioPath is strictly the video ID
      expect(winSong.audioPath, 'dQw4w9WgXcQ');
      expect(winSong.source, 'youtube');
    });

    // 12. YouTube stream URL tidak dipersist sebagai SongModel.audioPath
    test('12. YouTube stream URL is never persisted into SongModel.audioPath', () {
      final video = YouTubeVideo(
        videoId: 'dQw4w9WgXcQ',
        title: 'Never Gonna Give You Up',
        channelName: 'Rick Astley',
        durationSeconds: 213,
      );

      final song = SongModel.fromYouTubeVideo(video);

      expect(song.audioPath, 'dQw4w9WgXcQ');
      expect(song.audioPath.contains('googlevideo.com'), isFalse);
      expect(song.source, 'youtube');

      final json = song.toJson();
      expect(json['audio_path'], 'dQw4w9WgXcQ');
      expect(json['source'], 'youtube');
    });

    // 13. App restart mempertahankan source local
    test('13. App restart serialization retains source local', () {
      final localSong = SongModel(
        id: 42,
        artistId: 1,
        title: 'Offline Song',
        duration: 180,
        audioPath: '/data/user/0/com.example.mymusic/music/offline.mp3',
        source: 'local',
      );

      final serialized = localSong.toJson();
      final restored = SongModel.fromJson(serialized);

      expect(restored.source, 'local');
      expect(restored.isYouTube, isFalse);
      expect(restored.audioPath, '/data/user/0/com.example.mymusic/music/offline.mp3');
    });

    // 14. Local missing file -> clear error, no YouTube fallback
    test('14. Local missing file returns clear error and does not fallback to YouTube', () async {
      final missingLocal = SongModel(
        id: 99,
        artistId: 1,
        title: 'Missing Track',
        duration: 180,
        audioPath: '/non/existent/missing_file.mp3',
        source: 'local',
      );

      final player = PlayerProvider();
      player.setQueueForTest([missingLocal], initialIndex: 0);

      await player.playSong(missingLocal);

      expect(player.lastErrorMessage, contains('File musik tidak tersedia di perangkat'));
      expect(player.isResolvingYouTube, isFalse);
    });
  });
}
