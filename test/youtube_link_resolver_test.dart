import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mymusic/models/song_model.dart';
import 'package:mymusic/services/youtube/youtube_scraper.dart';
import 'package:mymusic/services/youtube/youtube_parser.dart';
import 'package:mymusic/providers/youtube_provider.dart';
import 'package:mymusic/services/youtube/youtube_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 8.6 — YouTube & YouTube Music Link Resolver Tests', () {
    test('1. Standard YouTube Watch URL parsing', () {
      final info = YouTubeParser.parseLinkOrQuery('https://www.youtube.com/watch?v=dQw4w9WgXcQ');
      expect(info.type, equals(YouTubeLinkType.video));
      expect(info.videoId, equals('dQw4w9WgXcQ'));
    });

    test('2. YouTube Music Watch URL parsing', () {
      final info = YouTubeParser.parseLinkOrQuery('https://music.youtube.com/watch?v=60ItHLz5WEA');
      expect(info.type, equals(YouTubeLinkType.video));
      expect(info.videoId, equals('60ItHLz5WEA'));
    });

    test('3. Short YouTube URL parsing (youtu.be)', () {
      final info = YouTubeParser.parseLinkOrQuery('https://youtu.be/60ItHLz5WEA');
      expect(info.type, equals(YouTubeLinkType.video));
      expect(info.videoId, equals('60ItHLz5WEA'));
    });

    test('4. YouTube Playlist URL parsing', () {
      final info = YouTubeParser.parseLinkOrQuery('https://www.youtube.com/playlist?list=PLx0sYbCqOb8TBPRdmBHs5IFTvv9TPboYG');
      expect(info.type, equals(YouTubeLinkType.playlist));
      expect(info.playlistId, equals('PLx0sYbCqOb8TBPRdmBHs5IFTvv9TPboYG'));
    });

    test('5. YouTube Music Playlist URL parsing', () {
      final info = YouTubeParser.parseLinkOrQuery('https://music.youtube.com/playlist?list=OLAK5uy_k1234567890');
      expect(info.type, equals(YouTubeLinkType.playlist));
      expect(info.playlistId, equals('OLAK5uy_k1234567890'));
    });

    test('6. Watch URL with list & tracking query parameters (&si, &t, &index)', () {
      final info = YouTubeParser.parseLinkOrQuery('https://www.youtube.com/watch?v=60ItHLz5WEA&list=PL123456789&index=3&si=abcdef&t=45s');
      expect(info.type, equals(YouTubeLinkType.video));
      expect(info.videoId, equals('60ItHLz5WEA'));
      expect(info.playlistId, equals('PL123456789'));
    });

    test('7. Direct 11-char Video ID parsing', () {
      final info = YouTubeParser.parseLinkOrQuery('60ItHLz5WEA');
      expect(info.type, equals(YouTubeLinkType.video));
      expect(info.videoId, equals('60ItHLz5WEA'));
    });

    test('8. Plain text search query parsing', () {
      final info = YouTubeParser.parseLinkOrQuery('Alan Walker Faded');
      expect(info.type, equals(YouTubeLinkType.textSearch));
      expect(info.videoId, isNull);
      expect(info.playlistId, isNull);
    });

    test('9. Invalid non-YouTube URL falls back gracefully to textSearch', () {
      final info = YouTubeParser.parseLinkOrQuery('https://evil-site.com/watch?v=60ItHLz5WEA');
      expect(info.type, equals(YouTubeLinkType.textSearch));
    });

    test('10. Link Resolver Integration: Resolves YouTube Video link to SongModel', () async {
      final mockClient = MockClient((request) async {
        return http.Response('''{
          "contents": {
            "tabbedSearchResultsRenderer": {
              "tabs": [{"tabRenderer": {"content": {"sectionListRenderer": {"contents": []}}}}]
            }
          }
        }''', 200);
      });

      final scraper = YouTubeScraper(client: mockClient);
      final service = YouTubeService(scraper: scraper);
      final provider = YouTubeProvider(service: service);

      await provider.executeSearch('https://music.youtube.com/watch?v=60ItHLz5WEA', forceRefresh: true);

      expect(provider.detectedLinkInfo?.type, equals(YouTubeLinkType.video));
      expect(provider.searchResults, isNotEmpty);
      final song = SongModel.fromYouTubeVideo(provider.searchResults.first);
      expect(song.source, equals('youtube'));
      expect(song.audioPath, equals('60ItHLz5WEA'));
    });
  });
}
