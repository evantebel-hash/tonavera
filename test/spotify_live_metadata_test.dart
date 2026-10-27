import 'package:flutter_test/flutter_test.dart';
import 'package:mymusic/services/metadata/metadata_service.dart';
import 'package:mymusic/services/metadata/spotify_metadata_provider.dart';

void main() {
  group('Live Spotify Public Metadata Integration Test', () {
    test('Fetches live track metadata from real public Spotify embed page', () async {
      final provider = SpotifyMetadataProvider();
      const trackUrl = 'https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT?si=test1234';

      final result = await provider.fetchMetadata(trackUrl);

      expect(result, isNotNull, reason: 'Public Spotify metadata provider should succeed for Never Gonna Give You Up');
      expect(result!.title, equals('Never Gonna Give You Up'));
      expect(result.artist, equals('Rick Astley'));
      expect(result.duration, isNotNull);
      expect(result.duration, greaterThan(200));
      expect(result.artworkUrl, isNotNull);
      expect(result.artworkUrl, startsWith('https://'));
      expect(result.releaseYear, equals(1987));
      expect(result.spotifyId, equals('4cOdK2wGLETKBW3PvgPWqT'));
    });

    test('Fetches live album metadata from real public Spotify embed page', () async {
      final service = MetadataService.instance;
      const albumUrl = 'https://open.spotify.com/album/4m2880jivSbbyEGAKfITCa';

      final result = await service.fetchSpotifyMetadata(albumUrl);

      expect(result, isNotNull);
      expect(result!.title, equals('Random Access Memories'));
      expect(result.displayArtist, contains('Daft Punk'));
      expect(result.artworkUrl, isNotNull);
      expect(result.trackList, isNotEmpty);
      expect(result.trackList.first.title, isNotEmpty);
    });
  });
}
