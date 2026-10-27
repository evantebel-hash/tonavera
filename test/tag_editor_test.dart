import 'package:flutter_test/flutter_test.dart';
import 'package:mymusic/models/song_model.dart';
import 'package:mymusic/services/tag_editor_service.dart';

void main() {
  group('TagEditorService Tests', () {
    test('Format support check for audio extensions', () {
      expect(TagEditorService.isFormatSupported('/path/to/song.mp3'), isTrue);
      expect(TagEditorService.isFormatSupported('/path/to/song.flac'), isTrue);
      expect(TagEditorService.isFormatSupported('/path/to/song.m4a'), isTrue);
      expect(TagEditorService.isFormatSupported('/path/to/song.ogg'), isTrue);
      expect(TagEditorService.isFormatSupported('/path/to/song.wav'), isFalse);
    });

    test('SongModel metadata update creates updated model copy', () {
      final song = SongModel(
        id: 1,
        artistId: 1,
        title: 'Original Title',
        duration: 200,
        audioPath: 'c:/test/song.mp3',
        source: 'local',
        artistName: 'Original Artist',
        albumTitle: 'Original Album',
      );

      final updated = song.copyWith(
        title: 'New Title',
        artistName: 'New Artist',
        albumTitle: 'New Album',
        genreName: 'Rock',
      );

      expect(updated.id, equals(1));
      expect(updated.title, equals('New Title'));
      expect(updated.artistName, equals('New Artist'));
      expect(updated.albumTitle, equals('New Album'));
      expect(updated.genreName, equals('Rock'));
    });
  });
}
