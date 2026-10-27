import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mymusic/models/song_model.dart';
import 'package:mymusic/services/metadata/metadata_cache.dart';
import 'package:mymusic/services/metadata/metadata_model.dart';
import 'package:mymusic/services/metadata/metadata_service.dart';
import 'package:mymusic/services/metadata/spotify_metadata_provider.dart';
import 'package:mymusic/services/metadata/spotify_url_parser.dart';

void main() {
  group('SpotifyUrlParser Tests', () {
    // 1. Valid Spotify track URL
    test('1. Valid Spotify track URL parses correctly', () {
      final parsed = SpotifyUrlParser.parse('https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT');
      expect(parsed, isNotNull);
      expect(parsed!.type, equals(SpotifyEntityType.track));
      expect(parsed.id, equals('4cOdK2wGLETKBW3PvgPWqT'));
      expect(parsed.canonicalUrl, equals('https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT'));
      expect(parsed.isValid, isTrue);
    });

    // 2. Spotify track URL with ?si=
    test('2. Spotify track URL with query parameters ?si= strips parameters safely', () {
      final parsed = SpotifyUrlParser.parse('https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT?si=abc123xyz789&context=spotify');
      expect(parsed, isNotNull);
      expect(parsed!.type, equals(SpotifyEntityType.track));
      expect(parsed.id, equals('4cOdK2wGLETKBW3PvgPWqT'));
      expect(parsed.canonicalUrl, equals('https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT'));
    });

    // 3. Invalid Spotify URL
    test('3. Invalid Spotify URL returns null', () {
      expect(SpotifyUrlParser.parse('https://youtube.com/watch?v=12345'), isNull);
      expect(SpotifyUrlParser.parse('https://not-spotify.com/track/123'), isNull);
      expect(SpotifyUrlParser.isValid('https://google.com'), isFalse);
    });

    // 4. Spotify album URL
    test('4. Spotify album URL parses correctly', () {
      final parsed = SpotifyUrlParser.parse('https://open.spotify.com/album/4m2880jivSbbyEGAKfITCa');
      expect(parsed, isNotNull);
      expect(parsed!.type, equals(SpotifyEntityType.album));
      expect(parsed.id, equals('4m2880jivSbbyEGAKfITCa'));
      expect(parsed.canonicalUrl, equals('https://open.spotify.com/album/4m2880jivSbbyEGAKfITCa'));
    });

    // 5. Spotify artist URL
    test('5. Spotify artist URL parses correctly', () {
      final parsed = SpotifyUrlParser.parse('https://open.spotify.com/artist/0gxyHStUsqpMadRV0Di1Qt');
      expect(parsed, isNotNull);
      expect(parsed!.type, equals(SpotifyEntityType.artist));
      expect(parsed.id, equals('0gxyHStUsqpMadRV0Di1Qt'));
      expect(parsed.canonicalUrl, equals('https://open.spotify.com/artist/0gxyHStUsqpMadRV0Di1Qt'));
    });

    // 6. Spotify playlist URL
    test('6. Spotify playlist URL parses correctly', () {
      final parsed = SpotifyUrlParser.parse('https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M');
      expect(parsed, isNotNull);
      expect(parsed!.type, equals(SpotifyEntityType.playlist));
      expect(parsed.id, equals('37i9dQZF1DXcBWIGoYBM5M'));
      expect(parsed.canonicalUrl, equals('https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M'));
    });

    // 7. Empty URL
    test('7. Empty URL returns null', () {
      expect(SpotifyUrlParser.parse(''), isNull);
      expect(SpotifyUrlParser.parse('   '), isNull);
      expect(SpotifyUrlParser.parse(null), isNull);
      expect(SpotifyUrlParser.isValid(''), isFalse);
    });

    // 8. Malformed URL
    test('8. Malformed URL returns null', () {
      expect(SpotifyUrlParser.parse('https://open.spotify.com/unknown_type/123'), isNull);
      expect(SpotifyUrlParser.parse('spotify:::track'), isNull);
      expect(SpotifyUrlParser.parse('random characters not a link'), isNull);
    });

    // Extra: Internationalized URL & Spotify URI
    test('Internationalized URLs and URI schemes parse correctly', () {
      final intl = SpotifyUrlParser.parse('https://open.spotify.com/intl-id/track/4cOdK2wGLETKBW3PvgPWqT?si=abc');
      expect(intl, isNotNull);
      expect(intl!.id, equals('4cOdK2wGLETKBW3PvgPWqT'));

      final uri = SpotifyUrlParser.parse('spotify:track:4cOdK2wGLETKBW3PvgPWqT');
      expect(uri, isNotNull);
      expect(uri!.id, equals('4cOdK2wGLETKBW3PvgPWqT'));
      expect(uri.type, equals(SpotifyEntityType.track));
    });
  });

  group('SpotifyMetadataProvider HTTP & Network Tests', () {
    const sampleHtml = '''
<!DOCTYPE html>
<html>
<head></head>
<body>
<script id="__NEXT_DATA__" type="application/json">
{
  "props": {
    "pageProps": {
      "state": {
        "data": {
          "entity": {
            "type": "track",
            "name": "Never Gonna Give You Up",
            "uri": "spotify:track:4cOdK2wGLETKBW3PvgPWqT",
            "id": "4cOdK2wGLETKBW3PvgPWqT",
            "title": "Never Gonna Give You Up",
            "artists": [{"name": "Rick Astley", "uri": "spotify:artist:0gxyHStUsqpMadRV0Di1Qt"}],
            "releaseDate": {"isoString": "1987-11-12T00:00:00Z"},
            "duration": 213573,
            "isExplicit": false,
            "visualIdentity": {
              "image": [
                {"url": "https://image.example.com/300.jpg", "maxWidth": 300},
                {"url": "https://image.example.com/640.jpg", "maxWidth": 640}
              ]
            }
          }
        }
      }
    }
  }
}
</script>
</body>
</html>
''';

    test('Parses valid embed HTML successfully', () {
      final parsedUrl = SpotifyUrlParser.parse('https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT')!;
      final result = SpotifyMetadataProvider.parseEmbedHtml(sampleHtml, parsedUrl);

      expect(result, isNotNull);
      expect(result!.title, equals('Never Gonna Give You Up'));
      expect(result.artist, equals('Rick Astley'));
      expect(result.artists, equals(['Rick Astley']));
      expect(result.duration, equals(214)); // 213573 ms -> 214s
      expect(result.releaseDate, equals('1987-11-12'));
      expect(result.releaseYear, equals(1987));
      expect(result.artworkUrl, equals('https://image.example.com/640.jpg'));
      expect(result.spotifyId, equals('4cOdK2wGLETKBW3PvgPWqT'));
    });

    // 9. Network timeout
    test('9. Network timeout handled gracefully and returns null', () async {
      final mockClient = MockClient((request) async {
        await Future.delayed(const Duration(milliseconds: 150));
        return http.Response('timeout', 200);
      });

      final provider = SpotifyMetadataProvider(
        client: mockClient,
        timeout: const Duration(milliseconds: 50),
      );

      final result = await provider.fetchMetadata('https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT');
      expect(result, isNull); // Never throws
    });

    // 10. HTTP failure
    test('10. HTTP 404 and 500 failures handled gracefully and return null', () async {
      final mockClient404 = MockClient((request) async {
        return http.Response('Not Found', 404);
      });

      final provider404 = SpotifyMetadataProvider(client: mockClient404);
      final result404 = await provider404.fetchMetadata('https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT');
      expect(result404, isNull);

      final mockClient500 = MockClient((request) async {
        return http.Response('Server Error', 500);
      });

      final provider500 = SpotifyMetadataProvider(client: mockClient500);
      final result500 = await provider500.fetchMetadata('https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT');
      expect(result500, isNull);
    });

    // 11. Invalid JSON
    test('11. Invalid JSON handled gracefully without crashing', () async {
      const brokenHtml = '<script id="__NEXT_DATA__" type="application/json">{ broken json';
      final parsedUrl = SpotifyUrlParser.parse('https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT')!;
      final result = SpotifyMetadataProvider.parseEmbedHtml(brokenHtml, parsedUrl);
      expect(result, isNull);
    });

    // 12. Missing metadata fields
    test('12. Missing metadata fields handled safely with null defaults', () {
      const partialHtml = '''
<script id="__NEXT_DATA__" type="application/json">
{
  "props": {
    "pageProps": {
      "state": {
        "data": {
          "entity": {
            "name": "Minimal Track",
            "id": "min123"
          }
        }
      }
    }
  }
}
</script>
''';
      final parsedUrl = SpotifyUrlParser.parse('https://open.spotify.com/track/min123')!;
      final result = SpotifyMetadataProvider.parseEmbedHtml(partialHtml, parsedUrl);

      expect(result, isNotNull);
      expect(result!.title, equals('Minimal Track'));
      expect(result.artist, isNull);
      expect(result.album, isNull);
      expect(result.duration, isNull);
      expect(result.artworkUrl, isNull);
      expect(result.releaseDate, isNull);
    });
  });

  group('Metadata Cache Tests', () {
    // 13. Cache hit
    // 14. Cache miss
    test('13 & 14. Cache hit and cache miss work with stable keys', () {
      final cache = MetadataCache(capacity: 2);
      const key1 = 'spotify:track:4cOdK2wGLETKBW3PvgPWqT';
      const key2 = 'spotify:album:album123';

      expect(cache.get(key1), isNull); // Cache miss

      const meta = MusicMetadataResult(
        spotifyId: '4cOdK2wGLETKBW3PvgPWqT',
        title: 'Cached Track',
        artist: 'Cached Artist',
      );

      cache.put(key1, meta);
      expect(cache.contains(key1), isTrue);

      final retrieved = cache.get(key1); // Cache hit
      expect(retrieved, isNotNull);
      expect(retrieved!.title, equals('Cached Track'));

      // Test LRU eviction when capacity reached
      cache.put(key2, const MusicMetadataResult(title: 'Album', spotifyId: 'album123'));
      cache.put('spotify:track:third', const MusicMetadataResult(title: 'Third', spotifyId: 'third'));

      // First key should now be evicted
      expect(cache.contains(key1), isFalse);
      expect(cache.contains(key2), isTrue);
    });
  });

  group('Metadata Merge & Preservation Tests', () {
    // 15. Existing metadata preservation
    test('15. Safe merge preserves existing valid local metadata and only fills missing fields', () {
      final existingLocal = SongModel(
        id: 1,
        artistId: 10,
        title: 'My Custom Song Title',
        duration: 180,
        audioPath: 'c:/music/custom.mp3',
        artistName: 'My Local Artist',
        albumTitle: null, // missing album
        cover: null, // missing cover
        genreName: null, // missing genre
      );

      const spotifyMetadata = MusicMetadataResult(
        spotifyId: 'spot123',
        title: 'Spotify Official Title',
        artist: 'Spotify Artist',
        album: 'Spotify Album 2024',
        artworkUrl: 'https://cdn.spotify.com/art.jpg',
        genre: 'Pop',
      );

      // Safe merge (overwriteExisting = false)
      final merged = spotifyMetadata.mergeIntoSong(existingLocal, overwriteExisting: false);

      expect(merged.title, equals('My Custom Song Title'), reason: 'Local title must be preserved');
      expect(merged.artistName, equals('My Local Artist'), reason: 'Local artist must be preserved');
      expect(merged.albumTitle, equals('Spotify Album 2024'), reason: 'Missing album is filled');
      expect(merged.cover, equals('https://cdn.spotify.com/art.jpg'), reason: 'Missing cover is filled');
      expect(merged.genreName, equals('Pop'), reason: 'Missing genre is filled');
    });

    test('Overwrite merge replaces existing data with Spotify data when requested', () {
      final existingLocal = SongModel(
        id: 1,
        artistId: 10,
        title: 'Old Title',
        duration: 180,
        audioPath: 'c:/music/custom.mp3',
        artistName: 'Old Artist',
        albumTitle: 'Old Album',
      );

      const spotifyMetadata = MusicMetadataResult(
        spotifyId: 'spot123',
        title: 'New Spotify Title',
        artist: 'New Spotify Artist',
        album: 'New Spotify Album',
        artworkUrl: 'https://cdn.spotify.com/new_art.jpg',
      );

      final overwritten = spotifyMetadata.mergeIntoSong(existingLocal, overwriteExisting: true);

      expect(overwritten.title, equals('New Spotify Title'));
      expect(overwritten.artistName, equals('New Spotify Artist'));
      expect(overwritten.albumTitle, equals('New Spotify Album'));
      expect(overwritten.cover, equals('https://cdn.spotify.com/new_art.jpg'));
    });
  });

  group('MetadataService Integration Tests', () {
    test('MetadataService coordinates provider and cache properly', () async {
      int callCount = 0;
      final countingClient = MockClient((request) async {
        callCount++;
        return http.Response('''
<script id="__NEXT_DATA__" type="application/json">
{
  "props": {
    "pageProps": {
      "state": {
        "data": {
          "entity": {
            "name": "Integration Test Song",
            "id": "int123",
            "artists": [{"name": "Integration Artist"}]
          }
        }
      }
    }
  }
}
</script>
''', 200);
      });

      final service = MetadataService(
        providers: [SpotifyMetadataProvider(client: countingClient)],
        cache: MetadataCache(),
      );

      // First call -> Cache MISS -> HTTP request performed
      final result1 = await service.fetchSpotifyMetadata('https://open.spotify.com/track/int123');
      expect(result1, isNotNull);
      expect(result1!.title, equals('Integration Test Song'));
      expect(callCount, equals(1));

      // Second call -> Cache HIT -> No second HTTP request
      final result2 = await service.fetchSpotifyMetadata('https://open.spotify.com/track/int123');
      expect(result2, isNotNull);
      expect(result2!.title, equals('Integration Test Song'));
      expect(callCount, equals(1)); // Still 1!
    });
  });
}
