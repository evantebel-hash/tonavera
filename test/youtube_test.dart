import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mymusic/models/youtube_model.dart';
import 'package:mymusic/models/song_model.dart';
import 'package:mymusic/services/youtube/youtube_parser.dart';
import 'package:mymusic/services/youtube/youtube_normalizer.dart';
import 'package:mymusic/services/youtube/youtube_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('8.1 YouTube URL & Parser Tests', () {
    test('Extract YouTube Video ID from URLs and raw IDs', () {
      expect(YouTubeParser.extractVideoId('dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
      expect(
        YouTubeParser.extractVideoId('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
      expect(
        YouTubeParser.extractVideoId('https://youtu.be/dQw4w9WgXcQ?t=43'),
        'dQw4w9WgXcQ',
      );
      expect(YouTubeParser.extractVideoId('not_a_valid_youtube_video_url'), null);
    });

    test('Extract YouTube Playlist ID from URLs and raw IDs', () {
      expect(
        YouTubeParser.extractPlaylistId('PLx0sYbCqOb8TBPRdmBHs5IFTvv9TPboYG'),
        'PLx0sYbCqOb8TBPRdmBHs5IFTvv9TPboYG',
      );
      expect(
        YouTubeParser.extractPlaylistId('https://www.youtube.com/playlist?list=PLx0sYbCqOb8TBPRdmBHs5IFTvv9TPboYG'),
        'PLx0sYbCqOb8TBPRdmBHs5IFTvv9TPboYG',
      );
      expect(
        YouTubeParser.extractPlaylistId('https://www.youtube.com/watch?v=abc12345678&list=PLx0sYbCqOb8TBPRdmBHs5IFTvv9TPboYG'),
        'PLx0sYbCqOb8TBPRdmBHs5IFTvv9TPboYG',
      );
      expect(YouTubeParser.extractPlaylistId('invalid_playlist'), null);
    });

    test('Metadata Normalizer Title & Duration parsing', () {
      expect(
        YouTubeNormalizer.normalizeTitle('Coldplay - Yellow (Official Music Video)'),
        'Coldplay - Yellow',
      );
      expect(
        YouTubeNormalizer.normalizeTitle('Queen – Bohemian Rhapsody [Official Video HD]'),
        'Queen – Bohemian Rhapsody',
      );

      expect(YouTubeNormalizer.parseDurationToSeconds('3:45'), 225);
      expect(YouTubeNormalizer.parseDurationToSeconds('01:15:30'), 4530);
      expect(YouTubeNormalizer.parseDurationToSeconds(180), 180);
      expect(YouTubeNormalizer.parseDurationToSeconds('invalid'), 0);
    });

    test('Offline Fixture HTML Parsing for Search Results', () {
      const fixtureHtml = '''
<html>
  <script>
    var ytInitialData = {
      "contents": {
        "twoColumnSearchResultsRenderer": {
          "primaryContents": {
            "sectionListRenderer": {
              "contents": [
                {
                  "itemSectionRenderer": {
                    "contents": [
                      {
                        "videoRenderer": {
                          "videoId": "abc12345678",
                          "title": {"runs": [{"text": "Sample Song (Official Video)"}]},
                          "ownerText": {"runs": [{"text": "Sample Artist"}]},
                          "lengthText": {"simpleText": "04:20"}
                        }
                      }
                    ]
                  }
                }
              ]
            }
          }
        }
      }
    };
  </script>
</html>
''';

      final videos = YouTubeParser.parseSearchResultsHtml(fixtureHtml);
      expect(videos.length, 1);
      expect(videos.first.videoId, 'abc12345678');
      expect(videos.first.title, 'Sample Song');
      expect(videos.first.channelName, 'Sample Artist');
      expect(videos.first.durationSeconds, 260);
    });
  });

  group('8.2 YouTube & Local Matching Tests', () {
    test('Match YouTube Video against Local Song Library', () {
      final localSong1 = SongModel(
        id: 1,
        artistId: 10,
        title: 'Fix You',
        duration: 295,
        artistName: 'Coldplay',
        albumTitle: 'X&Y',
        audioPath: 'coldplay_fix_you.mp3',
      );
      final localSong2 = SongModel(
        id: 2,
        artistId: 20,
        title: 'Hotel California',
        duration: 390,
        artistName: 'Eagles',
        albumTitle: 'Hotel California',
        audioPath: 'eagles_hotel.mp3',
      );

      final localLibrary = [localSong1, localSong2];
      final ytVideo = YouTubeVideo(
        videoId: 'k4V3Mo61fJM',
        title: 'Coldplay - Fix You (Official Video)',
        channelName: 'Coldplay',
        durationSeconds: 295,
      );

      final matched = YouTubeService.instance.matchLocalSong(ytVideo, localLibrary);
      expect(matched, isNotNull);
      expect(matched!.id, 1);
      expect(matched.title, 'Fix You');
    });

    test('HybridPlaylistItem model source separation', () {
      final localSong = SongModel(
        id: 5,
        artistId: 1,
        title: 'Local Track',
        duration: 180,
        audioPath: 'local.mp3',
      );

      final ytVideo = YouTubeVideo(
        videoId: 'yt123456789',
        title: 'Online Track',
        channelName: 'Online Channel',
      );

      final localHybrid = HybridPlaylistItem(
        playlistId: 100,
        sourceType: HybridSourceType.local,
        songId: 5,
        position: 0,
        localSong: localSong,
      );

      final ytHybrid = HybridPlaylistItem(
        playlistId: 100,
        sourceType: HybridSourceType.youtube,
        youtubeVideoId: 'yt123456789',
        position: 1,
        youtubeVideo: ytVideo,
      );

      expect(localHybrid.isLocal, true);
      expect(localHybrid.displayTitle, 'Local Track');

      expect(ytHybrid.isYouTube, true);
      expect(ytHybrid.displayTitle, 'Online Track');
    });
  });
}
