import 'package:flutter_test/flutter_test.dart';
import 'package:mymusic/models/song_model.dart';
import 'package:mymusic/models/youtube_model.dart';
import 'package:mymusic/services/youtube/youtube_normalizer.dart';
import 'package:mymusic/services/youtube/youtube_resolver.dart';
import 'package:mymusic/providers/player_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('YouTube Integration Unit Tests', () {
    test('1. YouTubeNormalizer cleans noisy title tags', () {
      final title = 'Alan Walker - Faded (Official Music Video)';
      final clean = YouTubeNormalizer.normalizeTitle(title);
      expect(clean, 'Alan Walker - Faded');
    });

    test('2. YouTubeNormalizer parses duration strings correctly', () {
      expect(YouTubeNormalizer.parseDurationToSeconds('3:45'), 225);
      expect(YouTubeNormalizer.parseDurationToSeconds('1:00:00'), 3600);
      expect(YouTubeNormalizer.parseDurationToSeconds(180), 180);
    });

    test('3. SongModel.fromYouTubeVideo converts YouTubeVideo correctly', () {
      final video = YouTubeVideo(
        videoId: '60ItHLz5WEA',
        title: 'Faded',
        channelName: 'Alan Walker',
        durationSeconds: 212,
        thumbnailUrl: 'https://img.youtube.com/vi/60ItHLz5WEA/hqdefault.jpg',
      );

      final song = SongModel.fromYouTubeVideo(video);

      expect(song.source, 'youtube');
      expect(song.isYouTube, true);
      expect(song.title, 'Faded');
      expect(song.artistName, 'Alan Walker');
      expect(song.duration, 212);
      expect(song.audioPath, '60ItHLz5WEA');
    });

    test('4. YouTubeResolver handles executable path check on Windows', () async {
      final path = await YouTubeResolver.instance.getExecutablePath();
      if (path != null) {
        expect(path.endsWith('yt-dlp.exe'), true);
      } else {
        expect(path, isNull);
      }
    });

    test('5. PlayerProvider handles YouTube SongModel queueing', () {
      final player = PlayerProvider();
      final ytSong = SongModel.fromYouTubeVideo(
        YouTubeVideo(
          videoId: '60ItHLz5WEA',
          title: 'Faded',
          channelName: 'Alan Walker',
          durationSeconds: 212,
        ),
      );

      player.addToQueue(ytSong);

      expect(player.queue.length, 1);
      expect(player.queue.first.isYouTube, true);
      expect(player.queue.first.title, 'Faded');
    });
  });
}
