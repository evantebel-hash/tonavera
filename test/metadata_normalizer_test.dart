import 'package:flutter_test/flutter_test.dart';
import 'package:audiotags/audiotags.dart';
import 'package:mymusic/core/utils/metadata_normalizer.dart';

void main() {
  group('MetadataNormalizer Unit Tests', () {
    test('1. Artist = "Avicii" -> artist = "Avicii"', () {
      final tag = Tag(
        trackArtist: 'Avicii',
        title: 'Levels',
        pictures: const [],
      );
      final norm = NormalizedSongMetadata.fromTag(tag, fallbackTitle: 'Levels');
      expect(norm.artist, 'Avicii');
    });

    test('2. Artist kosong, Album Artist = "Avicii" -> artist fallback = "Avicii"', () {
      final tag = Tag(
        trackArtist: '   ',
        albumArtist: 'Avicii',
        title: 'Levels',
        pictures: const [],
      );
      final norm = NormalizedSongMetadata.fromTag(tag, fallbackTitle: 'Levels');
      expect(norm.artist, 'Avicii');
    });

    test('3. Artist = " Avicii " -> displayName = "Avicii"', () {
      final tag = Tag(
        trackArtist: ' Avicii ',
        title: 'Levels',
        pictures: const [],
      );
      final norm = NormalizedSongMetadata.fromTag(tag, fallbackTitle: 'Levels');
      expect(norm.artist, 'Avicii');
    });

    test('4. Artist = "AVICII" -> normalizedName = "avicii"', () {
      final tag = Tag(
        trackArtist: 'AVICII',
        title: 'Levels',
        pictures: const [],
      );
      final norm = NormalizedSongMetadata.fromTag(tag, fallbackTitle: 'Levels');
      expect(norm.normalizedArtist, 'avicii');
    });

    test('5. Artist = "Earth, Wind & Fire" -> preserve exact artist string without dangerous splitting', () {
      final tag = Tag(
        trackArtist: 'Earth, Wind & Fire',
        title: 'September',
        pictures: const [],
      );
      final norm = NormalizedSongMetadata.fromTag(tag, fallbackTitle: 'September');
      expect(norm.artist, 'Earth, Wind & Fire');
    });

    test('6. Artist metadata exists but artwork missing -> artist tetap terdeteksi', () {
      final tag = Tag(
        trackArtist: 'Avicii',
        title: 'Wake Me Up',
        pictures: const [],
      );
      final norm = NormalizedSongMetadata.fromTag(tag, fallbackTitle: 'Wake Me Up');
      expect(norm.artist, 'Avicii');
      expect(norm.pictures, isEmpty);
    });

    test('7. Artwork exists but artist field missing -> artist fallbacks to Album Artist or Unknown Artist safely', () {
      final tag = Tag(
        trackArtist: null,
        albumArtist: 'Swedish House Mafia',
        title: 'One',
        pictures: const [],
      );
      final norm = NormalizedSongMetadata.fromTag(tag, fallbackTitle: 'One');
      expect(norm.artist, 'Swedish House Mafia');
    });

    test('Normalization identity test for deduplication', () {
      expect(NormalizedSongMetadata.normalizeIdentity('  Avicii '), 'avicii');
      expect(NormalizedSongMetadata.normalizeIdentity('AVICII'), 'avicii');
      expect(NormalizedSongMetadata.normalizeIdentity('avicii'), 'avicii');
    });
  });
}
