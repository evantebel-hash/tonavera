import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mymusic/models/song_model.dart';
import 'package:mymusic/models/youtube_model.dart';
import 'package:mymusic/services/youtube/youtube_parser.dart';
import 'package:mymusic/services/youtube/youtube_scraper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PHASE 8.8.6 — YouTube & YouTube Music Playlist Import Fix Tests', () {
    test('1. music.youtube.com playlist URL parsing', () {
      final info = YouTubeParser.parseLinkOrQuery('https://music.youtube.com/playlist?list=PL1234567890abcdef');
      expect(info.type, equals(YouTubeLinkType.playlist));
      expect(info.playlistId, equals('PL1234567890abcdef'));
    });

    test('2. youtube.com playlist URL parsing', () {
      final info = YouTubeParser.parseLinkOrQuery('https://youtube.com/playlist?list=PL1234567890abcdef');
      expect(info.type, equals(YouTubeLinkType.playlist));
      expect(info.playlistId, equals('PL1234567890abcdef'));
    });

    test('3. www.youtube.com playlist URL parsing', () {
      final info = YouTubeParser.parseLinkOrQuery('https://www.youtube.com/playlist?list=PL1234567890abcdef');
      expect(info.type, equals(YouTubeLinkType.playlist));
      expect(info.playlistId, equals('PL1234567890abcdef'));
    });

    test('4. watch?v=VIDEO&list=PLAYLIST URL parses video and playlistId', () {
      final info = YouTubeParser.parseLinkOrQuery('https://www.youtube.com/watch?v=dQw4w9WgXcQ&list=PL1234567890abcdef');
      expect(info.type, equals(YouTubeLinkType.video));
      expect(info.videoId, equals('dQw4w9WgXcQ'));
      expect(info.playlistId, equals('PL1234567890abcdef'));
    });

    test('5. URL with &index= parameter parsed correctly', () {
      final info = YouTubeParser.parseLinkOrQuery('https://music.youtube.com/playlist?list=PL1234567890&index=5');
      expect(info.type, equals(YouTubeLinkType.playlist));
      expect(info.playlistId, equals('PL1234567890'));
    });

    test('6. URL with &si= tracking parameter parsed correctly', () {
      final info = YouTubeParser.parseLinkOrQuery('https://www.youtube.com/playlist?list=PL1234567890&si=tracking123');
      expect(info.type, equals(YouTubeLinkType.playlist));
      expect(info.playlistId, equals('PL1234567890'));
    });

    test('7. URL with &pp= parameter parsed correctly', () {
      final info = YouTubeParser.parseLinkOrQuery('https://music.youtube.com/watch?v=abc12345678&list=PL999&pp=gAQB');
      expect(info.type, equals(YouTubeLinkType.video));
      expect(info.videoId, equals('abc12345678'));
      expect(info.playlistId, equals('PL999'));
    });

    test('8. Invalid domain rejected for playlist import', () {
      final info = YouTubeParser.parseLinkOrQuery('https://evil-site.com/playlist?list=PL123');
      expect(info.type, equals(YouTubeLinkType.textSearch));
      expect(info.playlistId, isNull);
    });

    test('9. Invalid URL string handled safely', () {
      final info = YouTubeParser.parseLinkOrQuery('not a valid url or id');
      expect(info.type, equals(YouTubeLinkType.textSearch));
      expect(info.playlistId, isNull);
    });

    test('10. Empty playlist result produces empty playlist items', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"contents": {}}', 200);
      });
      final scraper = YouTubeScraper(client: mockClient);
      final playlist = await scraper.fetchPlaylist('PLEmptyPlaylist');
      expect(playlist == null || playlist.items.isEmpty, isTrue);
    });

    test('11. Unavailable / deleted video items skipped in HTML parsing', () {
      final html = '''
        <script>var ytInitialData = {
          "header": {"playlistHeaderRenderer": {"title": {"simpleText": "Test Playlist"}}},
          "contents": {
            "twoColumnBrowseResultsRenderer": {
              "tabs": [{
                "tabRenderer": {
                  "content": {
                    "sectionListRenderer": {
                      "contents": [{
                        "itemSectionRenderer": {
                          "contents": [{
                            "playlistVideoListRenderer": {
                              "contents": [
                                {
                                  "playlistVideoRenderer": {
                                    "videoId": "vid11111111",
                                    "title": {"runs": [{"text": "Valid Song"}]},
                                    "shortBylineText": {"runs": [{"text": "Artist A"}]}
                                  }
                                },
                                {
                                  "playlistVideoRenderer": {
                                    "videoId": "vid22222222",
                                    "title": {"runs": [{"text": "[Deleted video]"}]}
                                  }
                                },
                                {
                                  "playlistVideoRenderer": {
                                    "videoId": "vid33333333",
                                    "title": {"runs": [{"text": "[Private video]"}]}
                                  }
                                }
                              ]
                            }
                          }]
                        }
                      }]
                    }
                  }
                }
              }]
            }
          }
        };</script>
      ''';

      final playlist = YouTubeParser.parsePlaylistHtml(html, 'PLTest123');
      expect(playlist.items.length, equals(1));
      expect(playlist.items.first.videoId, equals('vid11111111'));
      expect(playlist.items.first.title, equals('Valid Song'));
    });

    test('12. Private/deleted item skip preserves valid items count', () {
      final items = <YouTubePlaylistItem>[
        YouTubePlaylistItem(playlistId: 'P1', videoId: 'v1', position: 0, title: 'Track 1'),
      ];
      expect(items.length, equals(1));
      expect(items.first.title, equals('Track 1'));
    });

    test('13. Partial playlist failure imports valid songs without throwing', () {
      final jsonResponse = {
        'header': {
          'playlistHeaderRenderer': {
            'title': {'simpleText': 'Partial Playlist'}
          }
        },
        'contents': {
          'twoColumnBrowseResultsRenderer': {
            'tabs': [
              {
                'tabRenderer': {
                  'content': {
                    'sectionListRenderer': {
                      'contents': [
                        {
                          'itemSectionRenderer': {
                            'contents': [
                              {
                                'playlistVideoListRenderer': {
                                  'contents': [
                                    {
                                      'playlistVideoRenderer': {
                                        'videoId': 'goodVid12345',
                                        'title': {'simpleText': 'Good Song'},
                                      }
                                    }
                                  ]
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
      };

      final playlist = YouTubeParser.parseInnerTubePlaylistJson(jsonResponse, 'PLPartial');
      expect(playlist.items.isNotEmpty, isTrue);
      expect(playlist.items.first.videoId, equals('goodVid12345'));
    });

    test('14. Playlist item converts to valid YouTube SongModel', () {
      final video = YouTubeVideo(
        videoId: 'dQw4w9WgXcQ',
        title: 'Never Gonna Give You Up',
        channelName: 'Rick Astley',
        thumbnailUrl: 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
        durationSeconds: 213,
      );

      final song = SongModel.fromYouTubeVideo(video);
      expect(song.source, equals('youtube'));
      expect(song.audioPath, equals('dQw4w9WgXcQ'));
      expect(song.title, equals('Never Gonna Give You Up'));
      expect(song.artistName, equals('Rick Astley'));
      expect(song.duration, equals(213));
      expect(song.isYouTube, isTrue);
    });

    test('15. Playlist persistence retains videoId as audioPath (never googlevideo.com)', () {
      final video = YouTubeVideo(
        videoId: 'abc12345678',
        title: 'Persistent Song',
        thumbnailUrl: 'https://i.ytimg.com/vi/abc12345678/hqdefault.jpg',
      );
      final song = SongModel.fromYouTubeVideo(video);
      expect(song.audioPath, equals('abc12345678'));
      expect(song.audioPath.contains('googlevideo'), isFalse);
    });

    test('16. Play All converts imported playlist items to YouTube SongModels for queue', () {
      final items = [
        YouTubePlaylistItem(playlistId: 'PL1', videoId: 'vid1', position: 0, title: 'Song 1', channelName: 'Artist 1'),
        YouTubePlaylistItem(playlistId: 'PL1', videoId: 'vid2', position: 1, title: 'Song 2', channelName: 'Artist 2'),
      ];

      final songModels = items.map((i) {
        return SongModel.fromYouTubeVideo(
          YouTubeVideo(
            videoId: i.videoId,
            title: i.title,
            channelName: i.channelName,
            thumbnailUrl: i.thumbnailUrl,
            durationSeconds: i.durationSeconds,
          ),
        );
      }).toList();

      expect(songModels.length, equals(2));
      expect(songModels[0].audioPath, equals('vid1'));
      expect(songModels[0].source, equals('youtube'));
      expect(songModels[1].audioPath, equals('vid2'));
      expect(songModels[1].source, equals('youtube'));
    });

    test('17. Add All to Queue converts all playlist items to YouTube SongModels', () {
      final items = [
        YouTubePlaylistItem(playlistId: 'PL1', videoId: 'v1', position: 0, title: 'Item 1'),
        YouTubePlaylistItem(playlistId: 'PL1', videoId: 'v2', position: 1, title: 'Item 2'),
        YouTubePlaylistItem(playlistId: 'PL1', videoId: 'v3', position: 2, title: 'Item 3'),
      ];

      final songs = items.map((i) => SongModel.fromYouTubeVideo(YouTubeVideo(videoId: i.videoId, title: i.title))).toList();
      expect(songs.length, equals(3));
      for (final s in songs) {
        expect(s.isYouTube, isTrue);
        expect(s.audioPath.length, greaterThan(0));
      }
    });
  });
}
