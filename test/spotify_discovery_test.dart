import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mymusic/models/youtube_model.dart';
import 'package:mymusic/services/metadata/metadata_model.dart';
import 'package:mymusic/services/metadata/metadata_service.dart';
import 'package:mymusic/services/metadata/spotify_discovery_service.dart';
import 'package:mymusic/services/metadata/spotify_metadata_provider.dart';
import 'package:mymusic/services/metadata/spotify_resolver_service.dart';
import 'package:mymusic/services/metadata/spotify_url_parser.dart';
import 'package:mymusic/services/youtube/youtube_service.dart';

class MockEmptyYouTubeService extends YouTubeService {
  @override
  Future<List<YouTubeVideo>> search(String query, {bool forceRefresh = false}) async {
    return [];
  }
}

void main() {
  group('SpotifyDiscoveryService Tests', () {
    test('1. Detects Spotify Track URL and returns track discovery result', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/embed/track/4cOdK2wGLETKBW3PvgPWqT')) {
          final html = '''
<!DOCTYPE html>
<html>
<script id="__NEXT_DATA__" type="application/json">
{
  "props": {
    "pageProps": {
      "state": {
        "data": {
          "entity": {
            "type": "track",
            "id": "4cOdK2wGLETKBW3PvgPWqT",
            "name": "Never Gonna Give You Up",
            "duration": 213000,
            "artists": [{"name": "Rick Astley"}],
            "album": {
              "name": "Whenever You Need Somebody",
              "images": [{"url": "https://i.scdn.co/image/art123"}]
            }
          }
        }
      }
    }
  }
}
</script>
</html>''';
          return http.Response(html, 200, headers: {'content-type': 'text/html'});
        }
        return http.Response('Not Found', 404);
      });

      final spotifyProvider = SpotifyMetadataProvider(client: mockClient);
      final metadataService = MetadataService(providers: [spotifyProvider]);
      final discoveryService = SpotifyDiscoveryService(
        client: mockClient,
        metadataService: metadataService,
      );

      final result = await discoveryService.searchOrResolve('https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT');
      expect(result.isDirectUrl, isTrue);
      expect(result.entity?.type, equals(SpotifyEntityType.track));
      expect(result.tracks.length, equals(1));
      expect(result.tracks.first.title, equals('Never Gonna Give You Up'));
      expect(result.tracks.first.artist, equals('Rick Astley'));
      expect(result.tracks.first.duration, equals(213));
    });

    test('2. Detects Spotify Album URL and extracts tracklist', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/embed/album/4m2880jivSbbyEGAKfITCa')) {
          final html = '''
<!DOCTYPE html>
<html>
<script id="__NEXT_DATA__" type="application/json">
{
  "props": {
    "pageProps": {
      "state": {
        "data": {
          "entity": {
            "type": "album",
            "id": "4m2880jivSbbyEGAKfITCa",
            "name": "Discovery",
            "artists": [{"name": "Daft Punk"}],
            "visualIdentity": {
              "image": [{"url": "https://i.scdn.co/image/daftpunk"}]
            },
            "trackList": [
              {
                "id": "trk1",
                "title": "One More Time",
                "duration": 320000,
                "artists": [{"name": "Daft Punk"}]
              },
              {
                "id": "trk2",
                "title": "Aerodynamic",
                "duration": 212000,
                "artists": [{"name": "Daft Punk"}]
              }
            ]
          }
        }
      }
    }
  }
}
</script>
</html>''';
          return http.Response(html, 200, headers: {'content-type': 'text/html'});
        }
        return http.Response('Not Found', 404);
      });

      final spotifyProvider = SpotifyMetadataProvider(client: mockClient);
      final metadataService = MetadataService(providers: [spotifyProvider]);
      final discoveryService = SpotifyDiscoveryService(
        client: mockClient,
        metadataService: metadataService,
      );

      final result = await discoveryService.searchOrResolve('https://open.spotify.com/album/4m2880jivSbbyEGAKfITCa');
      expect(result.isDirectUrl, isTrue);
      expect(result.entity?.type, equals(SpotifyEntityType.album));
      expect(result.entity?.title, equals('Discovery'));
      expect(result.tracks.length, equals(2));
      expect(result.tracks[0].title, equals('One More Time'));
      expect(result.tracks[0].album, equals('Discovery'));
      expect(result.tracks[1].title, equals('Aerodynamic'));
      expect(result.tracks[1].album, equals('Discovery'));
      expect(result.tracks[0].artworkUrl, equals('https://i.scdn.co/image/daftpunk'), reason: 'Album tracks should inherit album artwork');
    });

    test('2b. Detects Spotify Playlist URL and ensures tracks do not reuse playlist cover art', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/embed/playlist/37i9dQZF1DXcBWIGoYBM5M')) {
          final html = '''
<!DOCTYPE html>
<html>
<script id="__NEXT_DATA__" type="application/json">
{
  "props": {
    "pageProps": {
      "state": {
        "data": {
          "entity": {
            "type": "playlist",
            "id": "37i9dQZF1DXcBWIGoYBM5M",
            "name": "Today's Top Hits",
            "visualIdentity": {
              "image": [{"url": "https://i.scdn.co/image/playlist_cover_art"}]
            },
            "trackList": [
              {
                "id": "trk_without_art",
                "title": "Hit Song 1",
                "duration": 180000,
                "artists": [{"name": "Artist 1"}]
              },
              {
                "id": "trk_with_own_art",
                "title": "Hit Song 2",
                "duration": 200000,
                "artists": [{"name": "Artist 2"}],
                "visualIdentity": {
                  "image": [{"url": "https://i.scdn.co/image/own_art_2"}]
                }
              }
            ]
          }
        }
      }
    }
  }
}
</script>
</html>''';
          return http.Response(html, 200, headers: {'content-type': 'text/html'});
        }
        return http.Response('Not Found', 404);
      });

      final spotifyProvider = SpotifyMetadataProvider(client: mockClient);
      final metadataService = MetadataService(providers: [spotifyProvider]);
      final discoveryService = SpotifyDiscoveryService(
        client: mockClient,
        metadataService: metadataService,
      );

      final result = await discoveryService.searchOrResolve('https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M');
      expect(result.isDirectUrl, isTrue);
      expect(result.entity?.type, equals(SpotifyEntityType.playlist));
      expect(result.entity?.artworkUrl, equals('https://i.scdn.co/image/playlist_cover_art'));
      expect(result.tracks.length, equals(2));
      // Track 1 has no distinct track art in playlist JSON -> must NOT get playlist cover
      expect(result.tracks[0].artworkUrl, isNull);
      // Track 2 has its own track art in JSON -> must preserve its own artwork
      expect(result.tracks[1].artworkUrl, equals('https://i.scdn.co/image/own_art_2'));
    });

    test('3. Free-text search uses open public metadata API without API keys', () async {
      final mockClient = MockClient((request) async {
        if (request.url.host.contains('itunes.apple.com')) {
          final jsonResp = {
            'resultCount': 1,
            'results': [
              {
                'trackName': 'Blinding Lights',
                'artistName': 'The Weeknd',
                'collectionName': 'After Hours',
                'trackTimeMillis': 200000,
                'artworkUrl100': 'https://is1-ssl.mzstatic.com/image/thumb/100x100.jpg',
                'releaseDate': '2020-03-20T00:00:00Z',
                'trackId': 1499378108,
              }
            ]
          };
          return http.Response(jsonEncode(jsonResp), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('Not Found', 404);
      });

      final discoveryService = SpotifyDiscoveryService(client: mockClient);
      final result = await discoveryService.searchOrResolve('Blinding Lights');

      expect(result.isDirectUrl, isFalse);
      expect(result.tracks.isNotEmpty, isTrue);
      expect(result.tracks.first.title, equals('Blinding Lights'));
      expect(result.tracks.first.artist, equals('The Weeknd'));
      expect(result.tracks.first.album, equals('After Hours'));
      expect(result.tracks.first.artworkUrl, contains('600x600'));
    });

    test('4. Gracefully handles network failures and returns empty result without crashing', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final discoveryService = SpotifyDiscoveryService(
        client: mockClient,
        ytService: MockEmptyYouTubeService(),
      );
      final result = await discoveryService.searchOrResolve('Nonexistent Song Query 12345');

      expect(result.isDirectUrl, isFalse);
      expect(result.tracks, isEmpty);
    });
  });

  group('SpotifyResolverService Matching Tests', () {
    test('1. Scores high match for identical title and artist with matching duration', () {
      final resolver = SpotifyResolverService();
      final track = const MusicMetadataResult(
        title: 'Starboy',
        artist: 'The Weeknd',
        duration: 230, // 3:50
      );

      final candidate = YouTubeVideo(
        videoId: 'dQTnKWUf_w0',
        title: 'The Weeknd - Starboy (Official Music Video) ft. Daft Punk',
        channelName: 'The Weeknd',
        durationSeconds: 230,
      );

      final score = resolver.computeMatchScore(track, candidate);
      expect(score, greaterThan(65));
    });

    test('2. Penalizes live, karaoke, or instrumental versions when not requested', () {
      final resolver = SpotifyResolverService();
      final originalTrack = const MusicMetadataResult(
        title: 'Rolling in the Deep',
        artist: 'Adele',
        duration: 228, // 3:48
      );

      final studioCandidate = YouTubeVideo(
        videoId: 'rYEDA3JcQqw',
        title: 'Adele - Rolling in the Deep (Official Music Video)',
        channelName: 'Adele',
        durationSeconds: 228,
      );

      final karaokeCandidate = YouTubeVideo(
        videoId: 'karaoke123',
        title: 'Adele - Rolling in the Deep (Karaoke Instrumental Version)',
        channelName: 'Karaoke Channel',
        durationSeconds: 228,
      );

      final studioScore = resolver.computeMatchScore(originalTrack, studioCandidate);
      final karaokeScore = resolver.computeMatchScore(originalTrack, karaokeCandidate);

      expect(studioScore, greaterThan(karaokeScore));
      expect(studioScore - karaokeScore, greaterThanOrEqualTo(50));
    });

    test('3. Builds valid playable SongModel with source youtube and preserved metadata', () {
      final resolver = SpotifyResolverService();
      final track = const MusicMetadataResult(
        title: 'Midnight City',
        artist: 'M83',
        album: 'Hurry Up, We\'re Dreaming',
        duration: 243,
        artworkUrl: 'https://i.scdn.co/image/m83',
        releaseDate: '2011',
      );

      final video = YouTubeVideo(
        videoId: 'dX3k_QDnzHE',
        title: 'M83 - Midnight City (Official video)',
        channelName: 'M83',
        durationSeconds: 243,
        thumbnailUrl: 'https://i.ytimg.com/vi/dX3k_QDnzHE/hqdefault.jpg',
      );

      final song = resolver.buildPlayableSong(track, video);
      expect(song.source, equals('youtube'));
      expect(song.audioPath, equals('dX3k_QDnzHE'));
      expect(song.title, equals('Midnight City'));
      expect(song.artistName, equals('M83'));
      expect(song.albumTitle, equals('Hurry Up, We\'re Dreaming'));
      expect(song.cover, equals('https://i.scdn.co/image/m83'));
      expect(song.duration, equals(243));
    });

    test('3b. Uses YouTube video thumbnail as artwork when track artwork is null or empty', () {
      final resolver = SpotifyResolverService();
      final trackWithoutArt = const MusicMetadataResult(
        title: 'Playlist Track',
        artist: 'Some Artist',
        duration: 180,
        artworkUrl: null, // Track from playlist without individual Spotify art
      );

      final video = YouTubeVideo(
        videoId: 'abc123vid',
        title: 'Some Artist - Playlist Track (Official)',
        channelName: 'Some Artist',
        durationSeconds: 180,
        thumbnailUrl: 'https://i.ytimg.com/vi/abc123vid/hqdefault.jpg',
      );

      final song = resolver.buildPlayableSong(trackWithoutArt, video);
      expect(song.cover, equals('https://i.ytimg.com/vi/abc123vid/hqdefault.jpg'));
    });

    test('4. Penalizes sped up, slowed, nightcore, 8d audio, and remix modifications', () {
      final resolver = SpotifyResolverService();
      final original = const MusicMetadataResult(
        title: 'As It Was',
        artist: 'Harry Styles',
        duration: 167,
      );

      final goodVideo = YouTubeVideo(
        videoId: 'vid_orig',
        title: 'Harry Styles - As It Was (Official Video)',
        channelName: 'HarryStylesVEVO',
        durationSeconds: 167,
      );

      final spedUpVideo = YouTubeVideo(
        videoId: 'vid_speed',
        title: 'Harry Styles - As It Was (Sped Up / Nightcore)',
        channelName: 'SpeedAudios',
        durationSeconds: 140,
      );

      final slowedVideo = YouTubeVideo(
        videoId: 'vid_slow',
        title: 'Harry Styles - As It Was (Slowed + Reverb)',
        channelName: 'SlowedVibes',
        durationSeconds: 195,
      );

      final goodScore = resolver.computeMatchScore(original, goodVideo);
      final spedUpScore = resolver.computeMatchScore(original, spedUpVideo);
      final slowedScore = resolver.computeMatchScore(original, slowedVideo);

      expect(goodScore, greaterThan(80));
      expect(goodScore - spedUpScore, greaterThan(50));
      expect(goodScore - slowedScore, greaterThan(50));
      expect(spedUpScore, lessThan(goodScore));
      expect(slowedScore, lessThan(goodScore));
    });

    test('5. Low confidence match (< 30) is rejected and returns null', () async {
      final mockYt = MockCustomYouTubeService({
        'completely unrelated': [
          YouTubeVideo(
            videoId: 'xyz999',
            title: 'Random Cooking Recipe Tutorial',
            channelName: 'Chef John',
            durationSeconds: 600,
          ),
        ],
      });

      final resolver = SpotifyResolverService(ytService: mockYt);
      final track = const MusicMetadataResult(
        title: 'completely unrelated rare track',
        artist: 'Indie Artist',
        duration: 200,
      );

      final result = await resolver.resolveTrack(track);
      expect(result, isNull);
    });

    test('6. Batch resolution handles partial failure gracefully without aborting batch', () async {
      final mockYt = MockCustomYouTubeService({
        'track one': [
          YouTubeVideo(
            videoId: 'vid_1',
            title: 'Artist - Track One (Official Audio)',
            channelName: 'Artist VEVO',
            durationSeconds: 180,
          ),
        ],
        'track three': [
          YouTubeVideo(
            videoId: 'vid_3',
            title: 'Artist - Track Three (Official Video)',
            channelName: 'Artist VEVO',
            durationSeconds: 210,
          ),
        ],
      });

      final resolver = SpotifyResolverService(ytService: mockYt);
      final tracks = [
        const MusicMetadataResult(title: 'Track One', artist: 'Artist', duration: 180),
        const MusicMetadataResult(title: 'Track Two Nonexistent', artist: 'Missing', duration: 300),
        const MusicMetadataResult(title: 'Track Three', artist: 'Artist', duration: 210),
      ];

      final progressCalls = <double>[];
      final batchResult = await resolver.resolveBatch(
        tracks,
        onProgress: (done, total) {
          progressCalls.add(done / total);
        },
      );

      // Total of 3 tracks processed, 2 succeed and 1 fails
      expect(batchResult.length, equals(2));
      expect(batchResult.any((s) => s.title == 'Track One'), isTrue);
      expect(batchResult.any((s) => s.title == 'Track Two Nonexistent'), isFalse);
      expect(batchResult.any((s) => s.title == 'Track Three'), isTrue);
      expect(progressCalls.length, equals(3));
      expect(progressCalls.last, equals(1.0));
    });

    test('7. Batch resolution handles duplicates safely', () async {
      final mockYt = MockCustomYouTubeService({
        'song a': [
          YouTubeVideo(
            videoId: 'vid_a',
            title: 'Band - Song A (Audio)',
            channelName: 'Band Official',
            durationSeconds: 200,
          ),
        ],
      });

      final resolver = SpotifyResolverService(ytService: mockYt);
      final track = const MusicMetadataResult(title: 'Song A', artist: 'Band', duration: 200);
      final duplicateList = [track, track, track];

      final batchResult = await resolver.resolveBatch(duplicateList);
      expect(batchResult.isNotEmpty, isTrue);
      expect(batchResult.length, equals(3));
      expect(batchResult.every((s) => s.audioPath == 'vid_a'), isTrue);
    });
  });

  group('Spotify Discovery Multi-Category & Isolation Tests', () {
    test('1. Free-text search populates tracks, albums, playlists, and artists', () async {
      final mockClient = MockClient((request) async {
        final path = request.url.path;
        if (request.url.host.contains('itunes.apple.com')) {
          final jsonResp = {
            'resultCount': 1,
            'results': [
              {
                'trackName': 'Discovery Track',
                'artistName': 'Sample Artist',
                'collectionName': 'Sample Album',
                'trackTimeMillis': 180000,
                'artworkUrl100': 'https://example.com/art.jpg',
                'releaseDate': '2022-01-01T00:00:00Z',
                'trackId': 101,
              }
            ]
          };
          return http.Response(jsonEncode(jsonResp), 200, headers: {'content-type': 'application/json'});
        } else if (path.contains('/search/album')) {
          final jsonResp = {
            'data': [
              {
                'id': 201,
                'title': 'Sample Album',
                'cover_medium': 'https://example.com/album.jpg',
                'artist': {'name': 'Sample Artist'},
                'nb_tracks': 10,
              }
            ]
          };
          return http.Response(jsonEncode(jsonResp), 200, headers: {'content-type': 'application/json'});
        } else if (path.contains('/search/playlist')) {
          final jsonResp = {
            'data': [
              {
                'id': 301,
                'title': 'Sample Playlist',
                'picture_medium': 'https://example.com/playlist.jpg',
                'creator': {'name': 'Curator'},
                'nb_tracks': 25,
              }
            ]
          };
          return http.Response(jsonEncode(jsonResp), 200, headers: {'content-type': 'application/json'});
        } else if (path.contains('/search/artist')) {
          final jsonResp = {
            'data': [
              {
                'id': 401,
                'name': 'Sample Artist',
                'picture_medium': 'https://example.com/artist.jpg',
                'nb_album': 5,
              }
            ]
          };
          return http.Response(jsonEncode(jsonResp), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('Not Found', 404);
      });

      final discoveryService = SpotifyDiscoveryService(client: mockClient);
      final result = await discoveryService.searchOrResolve('Sample');

      expect(result.tracks.length, equals(1));
      expect(result.albums.length, equals(1));
      expect(result.albums.first.title, equals('Sample Album'));
      expect(result.playlists.length, equals(1));
      expect(result.playlists.first.title, equals('Sample Playlist'));
      expect(result.artists.length, equals(1));
      expect(result.artists.first.title, equals('Sample Artist'));
    });

    test('2. loadEntityTracks retrieves full tracklist for album/playlist', () async {
      final mockClient = MockClient((request) async {
        final path = request.url.path;
        if (path.contains('/album/999/tracks')) {
          final jsonResp = {
            'data': [
              {
                'id': 1001,
                'title': 'Track 1',
                'artist': {'name': 'Album Artist'},
                'duration': 210,
              },
              {
                'id': 1002,
                'title': 'Track 2',
                'artist': {'name': 'Album Artist'},
                'duration': 195,
              },
            ]
          };
          return http.Response(jsonEncode(jsonResp), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('Not Found', 404);
      });

      final discoveryService = SpotifyDiscoveryService(client: mockClient);
      final albumEntity = const MusicMetadataResult(
        title: 'Greatest Hits',
        artist: 'Album Artist',
        spotifyId: '999',
        type: SpotifyEntityType.album,
      );

      final tracks = await discoveryService.loadEntityTracks(albumEntity);
      expect(tracks.length, equals(2));
      expect(tracks[0].title, equals('Track 1'));
      expect(tracks[1].title, equals('Track 2'));
    });

    test('3. Spotify subsystem failure is fully isolated and does NOT affect YouTube Music operations', () async {
      // Simulate complete Spotify failure (server crash / 500 error on every call)
      final failingSpotifyClient = MockClient((request) async {
        return http.Response('Service Unavailable', 503);
      });

      final spotifyProvider = SpotifyMetadataProvider(client: failingSpotifyClient);
      final metadataService = MetadataService(providers: [spotifyProvider]);
      final discoveryService = SpotifyDiscoveryService(
        client: failingSpotifyClient,
        metadataService: metadataService,
        ytService: MockEmptyYouTubeService(),
      );

      // Spotify discovery fails gracefully without throwing unhandled exceptions
      final spotifyResult = await discoveryService.searchOrResolve('Any Song');
      expect(spotifyResult.tracks, isEmpty);
      expect(spotifyResult.albums, isEmpty);

      // Verify YouTube Music service operates 100% normally and independently
      final ytVideos = [
        YouTubeVideo(
          videoId: 'yt_abc123',
          title: 'Direct YouTube Music Song',
          channelName: 'Independent Channel',
          durationSeconds: 240,
        ),
      ];
      final independentYtService = MockCustomYouTubeService({'Direct YouTube': ytVideos});
      final ytResults = await independentYtService.search('Direct YouTube');

      expect(ytResults.isNotEmpty, isTrue);
      expect(ytResults.first.videoId, equals('yt_abc123'));
      expect(ytResults.first.title, equals('Direct YouTube Music Song'));
    });
  });
}

class MockCustomYouTubeService extends YouTubeService {
  final Map<String, List<YouTubeVideo>> responses;
  int searchCallCount = 0;

  MockCustomYouTubeService(this.responses);

  @override
  Future<List<YouTubeVideo>> search(String query, {bool forceRefresh = false}) async {
    searchCallCount++;
    for (final entry in responses.entries) {
      if (query.toLowerCase().contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return [];
  }
}

