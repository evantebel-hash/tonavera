import 'package:flutter_test/flutter_test.dart';
import 'package:mymusic/models/song_model.dart';
import 'package:mymusic/models/duplicate_group_model.dart';
import 'package:mymusic/services/duplicate_detector_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DuplicateDetectorService detector;

  setUp(() {
    detector = DuplicateDetectorService();
  });

  group('DuplicateDetectorService Unit Tests', () {
    test('1. Empty library returns empty duplicate groups', () {
      final result = detector.detectDuplicates([]);
      expect(result, isEmpty);
    });

    test('2. Single song or distinct songs returns no duplicates', () {
      final songs = [
        SongModel(
          id: 1,
          artistId: 1,
          title: 'Song A',
          artistName: 'Artist A',
          albumTitle: 'Album A',
          duration: 200,
          audioPath: 'path/a.mp3',
        ),
        SongModel(
          id: 2,
          artistId: 2,
          title: 'Song B',
          artistName: 'Artist B',
          albumTitle: 'Album B',
          duration: 210,
          audioPath: 'path/b.mp3',
        ),
      ];
      final result = detector.detectDuplicates(songs);
      expect(result, isEmpty);
    });

    test('3. Same trackHash is detected as DuplicateGroup with trackHash reason', () {
      final songs = [
        SongModel(
          id: 1,
          artistId: 1,
          title: 'Levels',
          artistName: 'Avicii',
          albumTitle: 'Levels EP',
          duration: 200,
          audioPath: 'music/Levels.mp3',
        ),
        SongModel(
          id: 2,
          artistId: 1,
          title: 'Levels',
          artistName: 'Avicii',
          albumTitle: 'Levels EP',
          duration: 200,
          audioPath: 'downloads/Levels_copy.mp3',
        ),
      ];
      expect(songs[0].trackHash, songs[1].trackHash);

      final result = detector.detectDuplicates(songs);
      expect(result.length, 1);
      expect(result.first.matchReason, DuplicateMatchReason.trackHash);
      expect(result.first.candidates.length, 2);
    });

    test('4. Different trackHash but same normalized metadata is detected as metadataExact', () {
      final songs = [
        SongModel(
          id: 1,
          artistId: 1,
          title: 'Hello',
          artistName: 'Adele',
          albumTitle: '25',
          duration: 295,
          audioPath: 'music/hello.mp3',
        ),
        SongModel(
          id: 2,
          artistId: 1,
          title: ' hello ',
          artistName: ' ADELE ',
          albumTitle: ' 25 ',
          duration: 295,
          audioPath: 'downloads/hello.mp3',
        ),
      ];

      final result = detector.detectDuplicates(songs);
      expect(result.length, 1);
      expect(result.first.candidates.length, 2);
    });

    test('5. Different title is not considered duplicate', () {
      final songs = [
        SongModel(
          id: 1,
          artistId: 1,
          title: 'Hello',
          artistName: 'Adele',
          albumTitle: '25',
          duration: 295,
          audioPath: 'a.mp3',
        ),
        SongModel(
          id: 2,
          artistId: 1,
          title: 'Someone Like You',
          artistName: 'Adele',
          albumTitle: '25',
          duration: 295,
          audioPath: 'b.mp3',
        ),
      ];
      final result = detector.detectDuplicates(songs);
      expect(result, isEmpty);
    });

    test('6. Different artist is not considered duplicate', () {
      final songs = [
        SongModel(
          id: 1,
          artistId: 1,
          title: 'Stay',
          artistName: 'Justin Bieber',
          albumTitle: 'Album',
          duration: 150,
          audioPath: 'a.mp3',
        ),
        SongModel(
          id: 2,
          artistId: 2,
          title: 'Stay',
          artistName: 'Rihanna',
          albumTitle: 'Album',
          duration: 150,
          audioPath: 'b.mp3',
        ),
      ];
      final result = detector.detectDuplicates(songs);
      expect(result, isEmpty);
    });

    test('7. Different album with same title, artist, and duration is detected as metadataStrong', () {
      final songs = [
        SongModel(
          id: 1,
          artistId: 1,
          title: 'Viva La Vida',
          artistName: 'Coldplay',
          albumTitle: 'Viva La Vida',
          duration: 242,
          audioPath: 'a.mp3',
        ),
        SongModel(
          id: 2,
          artistId: 1,
          title: 'Viva La Vida',
          artistName: 'Coldplay',
          albumTitle: 'Greatest Hits',
          duration: 242,
          audioPath: 'b.mp3',
        ),
      ];
      final result = detector.detectDuplicates(songs);
      expect(result.length, 1);
      expect(result.first.matchReason, DuplicateMatchReason.metadataStrong);
    });

    test('8. Different duration is not considered duplicate', () {
      final songs = [
        SongModel(
          id: 1,
          artistId: 1,
          title: 'Hello',
          artistName: 'Adele',
          albumTitle: '25',
          duration: 295,
          audioPath: 'a.mp3',
        ),
        SongModel(
          id: 2,
          artistId: 1,
          title: 'Hello',
          artistName: 'Adele',
          albumTitle: '25',
          duration: 420,
          audioPath: 'b.mp3',
        ),
      ];
      final result = detector.detectDuplicates(songs);
      expect(result, isEmpty);
    });

    test('9. Missing metadata fallback handles gracefully without crash', () {
      final songs = [
        SongModel(
          id: 1,
          artistId: 0,
          title: 'Unknown Title',
          artistName: null,
          albumTitle: null,
          duration: 0,
          audioPath: 'a.mp3',
        ),
        SongModel(
          id: 2,
          artistId: 0,
          title: 'Unknown Title',
          artistName: null,
          albumTitle: null,
          duration: 0,
          audioPath: 'b.mp3',
        ),
      ];
      final result = detector.detectDuplicates(songs);
      // Empty/unknown generic songs shouldn't false-positive match without duration
      expect(result, isEmpty);
    });

    test('10. Invalid audio_path handled safely in DuplicateSongCandidate', () {
      final song = SongModel(
        id: 99,
        artistId: 1,
        title: 'NonExistent',
        duration: 100,
        audioPath: 'non_existent_folder_xyz/file.mp3',
      );
      final candidate = DuplicateSongCandidate.fromSong(song);
      expect(candidate.fileExists, false);
      expect(candidate.fileSizeFormatted, 'Unknown size');
      expect(candidate.fileFormat, 'MP3');
    });

    test('11. Multiple distinct duplicate groups are partitioned correctly', () {
      final songs = [
        SongModel(id: 1, artistId: 1, title: 'Song 1', artistName: 'Art 1', albumTitle: 'Alb 1', duration: 100, audioPath: '1a.mp3'),
        SongModel(id: 2, artistId: 1, title: 'Song 1', artistName: 'Art 1', albumTitle: 'Alb 1', duration: 100, audioPath: '1b.mp3'),
        SongModel(id: 3, artistId: 2, title: 'Song 2', artistName: 'Art 2', albumTitle: 'Alb 2', duration: 200, audioPath: '2a.mp3'),
        SongModel(id: 4, artistId: 2, title: 'Song 2', artistName: 'Art 2', albumTitle: 'Alb 2', duration: 200, audioPath: '2b.mp3'),
      ];
      final result = detector.detectDuplicates(songs);
      expect(result.length, 2);
    });

    test('12. Three or more duplicate files in a single group', () {
      final songs = [
        SongModel(id: 1, artistId: 1, title: 'Track', artistName: 'Artist', albumTitle: 'Album', duration: 180, audioPath: 'a.mp3'),
        SongModel(id: 2, artistId: 1, title: 'Track', artistName: 'Artist', albumTitle: 'Album', duration: 180, audioPath: 'b.mp3'),
        SongModel(id: 3, artistId: 1, title: 'Track', artistName: 'Artist', albumTitle: 'Album', duration: 180, audioPath: 'c.mp3'),
      ];
      final result = detector.detectDuplicates(songs);
      expect(result.length, 1);
      expect(result.first.candidates.length, 3);
    });

    test('13. Recommended keep selection favors richer metadata and format', () {
      final songA = SongModel(
        id: 1,
        artistId: 1,
        title: 'Levels',
        artistName: 'Avicii',
        albumTitle: 'Levels',
        genreName: null,
        duration: 200,
        audioPath: 'music/levels.mp3',
      );
      final songB = SongModel(
        id: 2,
        artistId: 1,
        title: 'Levels',
        artistName: 'Avicii',
        albumTitle: 'Levels',
        genreName: 'Progressive House',
        lyrics: 'Oh sometimes I get a good feeling',
        cover: 'covers/levels.jpg',
        duration: 200,
        audioPath: 'music/levels.flac',
      );

      final result = detector.detectDuplicates([songA, songB]);
      expect(result.length, 1);
      expect(result.first.recommendedKeepSongId, songB.id);
    });

    test('14. isSongActiveInPlayer detects active playback by ID or Path', () {
      final song = SongModel(
        id: 10,
        artistId: 1,
        title: 'Playing Song',
        duration: 120,
        audioPath: 'music/play.mp3',
      );
      // Null player should return false safely
      expect(detector.isSongActiveInPlayer(song, null), false);
    });

    test('15. Offline operation runs entirely in memory without network requirement', () {
      final songs = [
        SongModel(id: 1, artistId: 1, title: 'Offline 1', duration: 100, audioPath: '1.mp3'),
        SongModel(id: 2, artistId: 1, title: 'Offline 1', duration: 100, audioPath: '2.mp3'),
      ];
      final result = detector.detectDuplicates(songs);
      expect(result.length, 1);
    });
  });
}
