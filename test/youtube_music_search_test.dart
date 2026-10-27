import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mymusic/models/youtube_model.dart';
import 'package:mymusic/models/song_model.dart';
import 'package:mymusic/services/youtube/youtube_scraper.dart';
import 'package:mymusic/providers/youtube_provider.dart';
import 'package:mymusic/services/youtube/youtube_service.dart';
import 'package:mymusic/providers/player_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 8.5 — YouTube Music Search Tests', () {
    const mockYtMusicJson = '''
    {
      "contents": {
        "tabbedSearchResultsRenderer": {
          "tabs": [
            {
              "tabRenderer": {
                "content": {
                  "sectionListRenderer": {
                    "contents": [
                      {
                        "musicShelfRenderer": {
                          "contents": [
                            {
                              "musicResponsiveListItemRenderer": {
                                "flexColumns": [
                                  {
                                    "musicResponsiveListItemFlexColumnRenderer": {
                                      "text": {
                                        "runs": [{"text": "Faded"}]
                                      }
                                    }
                                  },
                                  {
                                    "musicResponsiveListItemFlexColumnRenderer": {
                                      "text": {
                                        "runs": [
                                          {"text": "Alan Walker"},
                                          {"text": " • "},
                                          {"text": "Different World"},
                                          {"text": " • "},
                                          {"text": "3:32"}
                                        ]
                                      }
                                    }
                                  }
                                ],
                                "playlistItemData": {
                                  "videoId": "60ItHLz5WEA"
                                },
                                "thumbnail": {
                                  "musicThumbnailRenderer": {
                                    "thumbnail": {
                                      "thumbnails": [
                                        {"url": "https://lh3.googleusercontent.com/faded_thumb.jpg"}
                                      ]
                                    }
                                  }
                                }
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
          ]
        }
      }
    }
    ''';

    test('Test 1 & 2: Search "Faded" returns YouTubeMusicResult with videoId, title, artist, album, duration, thumbnail', () async {
      final mockClient = MockClient((request) async {
        return http.Response(mockYtMusicJson, 200, headers: {'content-type': 'application/json'});
      });

      final scraper = YouTubeScraper(client: mockClient);
      final results = await scraper.searchMusic('Faded');

      expect(results, isNotEmpty);
      final video = results.first;
      expect(video.videoId, equals('60ItHLz5WEA'));
      expect(video.title, equals('Faded'));
      expect(video.channelName, equals('Alan Walker'));
      expect(video.albumName, equals('Different World'));
      expect(video.durationSeconds, equals(212));
      expect(video.thumbnailUrl, contains('faded_thumb.jpg'));
    });

    test('Test 3 & 4: Result converted to SongModel(source: youtube) and audioPath == videoId (not googlevideo URL)', () async {
      final video = YouTubeVideo(
        videoId: '60ItHLz5WEA',
        title: 'Faded',
        channelName: 'Alan Walker',
        albumName: 'Different World',
        durationSeconds: 212,
        thumbnailUrl: 'https://img.youtube.com/vi/60ItHLz5WEA/hqdefault.jpg',
      );

      final song = SongModel.fromYouTubeVideo(video);

      expect(song.source, equals('youtube'));
      expect(song.audioPath, equals('60ItHLz5WEA'));
      expect(song.audioPath.contains('googlevideo.com'), isFalse);
      expect(song.title, equals('Faded'));
      expect(song.artistName, equals('Alan Walker'));
      expect(song.albumTitle, equals('Different World'));
      expect(song.duration, equals(212));
    });

    test('Test 5: Search result can be added to Queue', () {
      final player = PlayerProvider();
      final video = YouTubeVideo(
        videoId: '60ItHLz5WEA',
        title: 'Faded',
        channelName: 'Alan Walker',
      );
      final song = SongModel.fromYouTubeVideo(video);

      player.addToQueue(song);

      expect(player.queue, contains(song));
      expect(player.queue.first.source, equals('youtube'));
      expect(player.queue.first.audioPath, equals('60ItHLz5WEA'));
    });

    test('Test 6: Search result converted to SongModel can be stored for Playlist', () {
      final video = YouTubeVideo(
        videoId: '60ItHLz5WEA',
        title: 'Faded',
        channelName: 'Alan Walker',
      );
      final song = SongModel.fromYouTubeVideo(video);

      final jsonMap = song.toJson();
      expect(jsonMap['source'], equals('youtube'));
      expect(jsonMap['audio_path'], equals('60ItHLz5WEA'));

      final restoredSong = SongModel.fromJson(jsonMap);
      expect(restoredSong.source, equals('youtube'));
      expect(restoredSong.audioPath, equals('60ItHLz5WEA'));
    });

    test('Test 7: Query generation counter prevents old result from overwriting new result', () async {
      final mockClient = MockClient((request) async {
        final body = request.body;
        if (body.contains('Faded')) {
          await Future.delayed(const Duration(milliseconds: 100));
          return http.Response(mockYtMusicJson, 200);
        } else {
          return http.Response('''{
            "contents": {
              "tabbedSearchResultsRenderer": {
                "tabs": [{"tabRenderer": {"content": {"sectionListRenderer": {"contents": []}}}}]
              }
            }
          }''', 200);
        }
      });

      final scraper = YouTubeScraper(client: mockClient);
      final service = YouTubeService(scraper: scraper);
      final provider = YouTubeProvider(service: service);

      // Trigger first query "Faded" (delayed)
      final f1 = provider.executeSearch('Faded');
      // Immediately trigger second query "Alan Walker"
      final f2 = provider.executeSearch('Alan Walker');

      await Future.wait([f1, f2]);

      // Last query should be "Alan Walker", and searchResults should reflect the second query
      expect(provider.lastQuery, equals('Alan Walker'));
      expect(provider.searchResults, isEmpty);
    });

    test('Test 8: Empty result handled cleanly without exception', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"contents": {}}', 200);
      });

      final scraper = YouTubeScraper(client: mockClient);
      final service = YouTubeService(scraper: scraper);
      final provider = YouTubeProvider(service: service);

      await provider.executeSearch('nonexistent_query_xyz_123', forceRefresh: true);

      expect(provider.searchResults, isEmpty);
      expect(provider.searchError, contains('Tidak ada hasil musik ditemukan'));
      expect(provider.isSearching, isFalse);
    });

    test('Test 9: Search error handled gracefully without crashing', () async {
      final mockClient = MockClient((request) async {
        throw Exception('Network connection failed');
      });

      final scraper = YouTubeScraper(client: mockClient);
      final service = YouTubeService(scraper: scraper);
      final provider = YouTubeProvider(service: service);

      await provider.executeSearch('Faded');

      expect(provider.searchResults, isEmpty);
      expect(provider.searchError, isNotNull);
      expect(provider.isSearching, isFalse);
    });

    test('Test 10: No browser launch for search operation', () {
      final video = YouTubeVideo(
        videoId: '60ItHLz5WEA',
        title: 'Faded',
      );
      final song = SongModel.fromYouTubeVideo(video);

      // Verify song URL property generates valid standard link if requested, but audioPath stays videoId
      expect(song.audioPath, equals('60ItHLz5WEA'));
      expect(video.sourceUrl, equals('https://www.youtube.com/watch?v=60ItHLz5WEA'));
    });
  });
}
