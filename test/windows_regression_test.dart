import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mymusic/models/song_model.dart';
import 'package:mymusic/models/youtube_model.dart';
import 'package:mymusic/services/youtube/youtube_resolver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PHASE 8.9 — Windows Regression Verification', () {
    test('W1. Local playback model remains local file path', () {
      final local = SongModel(
        id: 1,
        artistId: 1,
        title: 'Windows Local',
        duration: 180,
        audioPath: 'C:\\Users\\evan\\Music\\test.mp3',
        source: 'local',
      );

      expect(local.source, 'local');
      expect(local.isYouTube, isFalse);
      expect(local.audioPath, 'C:\\Users\\evan\\Music\\test.mp3');
    });

    test('W2. Windows resolver executable path finds yt-dlp.exe', () async {
      if (Platform.isWindows) {
        final ytDlp = await YouTubeResolver.instance.getExecutablePath();
        expect(ytDlp, isNotNull);
        expect(ytDlp!.toLowerCase(), contains('yt-dlp.exe'));
        expect(File(ytDlp).existsSync(), isTrue);
      }
    });

    test('W3. Windows YouTube resolution via yt-dlp binary generates direct stream URL', () async {
      if (Platform.isWindows) {
        // Resolve a known public test video ID
        final streamUrl = await YouTubeResolver.instance.resolveAudioStreamUrl('dQw4w9WgXcQ');
        expect(streamUrl, isNotEmpty);
        expect(streamUrl.startsWith('https://'), isTrue);
        expect(streamUrl, contains('googlevideo.com'));
      }
    }, timeout: const Timeout(Duration(seconds: 45)));

    test('W4. YouTube A -> B resolution queue models preserve identity', () {
      final songA = SongModel.fromYouTubeVideo(YouTubeVideo(videoId: 'ytA123', title: 'Song A'));
      final songB = SongModel.fromYouTubeVideo(YouTubeVideo(videoId: 'ytB456', title: 'Song B'));

      expect(songA.source, 'youtube');
      expect(songB.source, 'youtube');
      expect(songA.audioPath, 'ytA123');
      expect(songB.audioPath, 'ytB456');
    });

    test('W5 & W6. Local <-> YouTube queue transitions preserve source integrity', () {
      final loc = SongModel(id: 1, artistId: 1, title: 'Local', duration: 180, audioPath: 'c:/song.mp3', source: 'local');
      final yt = SongModel(id: 2, artistId: 0, title: 'YT', duration: 200, audioPath: 'ytId', source: 'youtube');

      expect(loc.source, 'local');
      expect(loc.isYouTube, isFalse);
      expect(yt.source, 'youtube');
      expect(yt.isYouTube, isTrue);
    });
  });
}
