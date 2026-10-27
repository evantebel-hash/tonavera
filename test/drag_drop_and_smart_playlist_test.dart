import 'package:flutter_test/flutter_test.dart';
import 'package:mymusic/core/utils/audio_file_validator.dart';
import 'package:mymusic/models/song_model.dart';
import 'package:mymusic/models/smart_playlist_model.dart';
import 'package:mymusic/services/smart_playlist_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioFileValidator & Drag-Drop Import Validation Tests', () {
    test('1. Supported MP3 extension validation', () {
      expect(AudioFileValidator.isSupportedAudioFile('music/track.mp3'), isTrue);
      expect(AudioFileValidator.isSupportedAudioFile('C:\\Music\\Song.MP3'), isTrue);
    });

    test('2. Supported FLAC extension validation', () {
      expect(AudioFileValidator.isSupportedAudioFile('/home/user/song.flac'), isTrue);
      expect(AudioFileValidator.isSupportedAudioFile('FLAC_TRACK.FLAC'), isTrue);
    });

    test('3. Supported M4A & AAC extension validation', () {
      expect(AudioFileValidator.isSupportedAudioFile('audio.m4a'), isTrue);
      expect(AudioFileValidator.isSupportedAudioFile('stream.aac'), isTrue);
      expect(AudioFileValidator.isSupportedAudioFile('track.wav'), isTrue);
      expect(AudioFileValidator.isSupportedAudioFile('track.ogg'), isTrue);
      expect(AudioFileValidator.isSupportedAudioFile('track.opus'), isTrue);
    });

    test('4. Unsupported files rejection (exe, zip, pdf, txt, mp4 without check)', () {
      expect(AudioFileValidator.isSupportedAudioFile('installer.exe'), isFalse);
      expect(AudioFileValidator.isSupportedAudioFile('music.zip'), isFalse);
      expect(AudioFileValidator.isSupportedAudioFile('lyrics.txt'), isFalse);
      expect(AudioFileValidator.isSupportedAudioFile('document.pdf'), isFalse);
      expect(AudioFileValidator.isSupportedAudioFile(''), isFalse);
      expect(AudioFileValidator.isSupportedAudioFile('folder/no_extension'), isFalse);
    });

    test('5. Get extension utility handles windows and unix paths correctly', () {
      expect(AudioFileValidator.getExtension('C:\\Music\\Album\\Song.flac'), 'flac');
      expect(AudioFileValidator.getExtension('/sdcard/Music/Song.M4A'), 'm4a');
      expect(AudioFileValidator.getExtension('noext'), '');
    });

    test('6. Audio path resolution handles empty lists safely without crash', () {
      final files = AudioFileValidator.resolveAudioFiles([]);
      expect(files, isEmpty);
    });

    test('7. Audio path resolution ignores non-existent or invalid paths gracefully', () {
      final files = AudioFileValidator.resolveAudioFiles(['/invalid/non_existent_path/song.mp3']);
      expect(files, isEmpty);
    });
  });

  group('Smart Playlist Rule Engine & Dynamic Evaluation Tests', () {
    final sampleSongs = [
      SongModel(
        id: 1,
        artistId: 10,
        title: 'Numb',
        artistName: 'Linkin Park',
        albumTitle: 'Meteora',
        genreName: 'Rock',
        duration: 187,
        audioPath: 'C:/Music/numb.flac',
        filePath: 'C:/Music/numb.flac',
        isFavorite: true,
      ),
      SongModel(
        id: 2,
        artistId: 10,
        title: 'In the End',
        artistName: 'Linkin Park',
        albumTitle: 'Hybrid Theory',
        genreName: 'Rock',
        duration: 216,
        audioPath: 'C:/Music/in_the_end.mp3',
        filePath: 'C:/Music/in_the_end.mp3',
        isFavorite: false,
      ),
      SongModel(
        id: 3,
        artistId: 20,
        title: 'Hello',
        artistName: 'Adele',
        albumTitle: '25',
        genreName: 'Pop',
        duration: 295,
        audioPath: 'C:/Music/hello.m4a',
        filePath: 'C:/Music/hello.m4a',
        isFavorite: true,
      ),
      SongModel(
        id: 4,
        artistId: 30,
        title: 'Bohemian Rhapsody',
        artistName: 'Queen',
        albumTitle: 'A Night at the Opera',
        genreName: 'Rock',
        duration: 354,
        audioPath: 'C:/Music/bohemian.flac',
        filePath: 'C:/Music/bohemian.flac',
        isFavorite: true,
      ),
      SongModel(
        id: 5,
        artistId: 40,
        title: 'Shape of You',
        artistName: 'Ed Sheeran',
        albumTitle: 'Divide',
        genreName: 'Pop',
        duration: 233,
        audioPath: 'C:/Music/shape_of_you.mp3',
        filePath: 'C:/Music/shape_of_you.mp3',
        isFavorite: false,
      ),
    ];

    final samplePlayCounts = {
      1: 25, // Numb
      2: 50, // In the End
      3: 12, // Hello
      4: 5,  // Bohemian
      5: 2,  // Shape of You
    };

    test('21. Create and serialize/deserialize Smart Playlist Config', () {
      final config = SmartPlaylistConfig(
        logic: SmartRuleLogic.all,
        rules: [
          SmartPlaylistRule(
            field: SmartRuleField.genre,
            operator: SmartRuleOperator.equals,
            value: 'Rock',
          ),
          SmartPlaylistRule(
            field: SmartRuleField.favorite,
            operator: SmartRuleOperator.isTrue,
            value: 'true',
          ),
        ],
        sort: SmartSortOption.playCountDesc,
        limit: 25,
      );

      final jsonStr = config.toJsonString();
      final parsed = SmartPlaylistConfig.fromJsonString(jsonStr);

      expect(parsed.logic, SmartRuleLogic.all);
      expect(parsed.rules.length, 2);
      expect(parsed.rules[0].field, SmartRuleField.genre);
      expect(parsed.rules[0].value, 'Rock');
      expect(parsed.rules[1].field, SmartRuleField.favorite);
      expect(parsed.sort, SmartSortOption.playCountDesc);
      expect(parsed.limit, 25);
    });

    test('22. Favorite = true rule filter', () {
      final config = SmartPlaylistConfig(
        rules: [
          SmartPlaylistRule(
            field: SmartRuleField.favorite,
            operator: SmartRuleOperator.isTrue,
            value: 'true',
          ),
        ],
      );

      final results = SmartPlaylistService.filterSongs(allSongs: sampleSongs, config: config);
      expect(results.length, 3); // Numb, Hello, Bohemian Rhapsody
      expect(results.every((s) => s.isFavorite), isTrue);
    });

    test('23. Genre = Rock rule filter', () {
      final config = SmartPlaylistConfig(
        rules: [
          SmartPlaylistRule(
            field: SmartRuleField.genre,
            operator: SmartRuleOperator.equals,
            value: 'Rock',
          ),
        ],
      );

      final results = SmartPlaylistService.filterSongs(allSongs: sampleSongs, config: config);
      expect(results.length, 3);
      expect(results.map((s) => s.title), containsAll(['Numb', 'In the End', 'Bohemian Rhapsody']));
    });

    test('24. Artist contains rule filter (case insensitive)', () {
      final config = SmartPlaylistConfig(
        rules: [
          SmartPlaylistRule(
            field: SmartRuleField.artist,
            operator: SmartRuleOperator.contains,
            value: 'linkin',
          ),
        ],
      );

      final results = SmartPlaylistService.filterSongs(allSongs: sampleSongs, config: config);
      expect(results.length, 2);
      expect(results.map((s) => s.title), containsAll(['Numb', 'In the End']));
    });

    test('25. Play Count >= 10 rule filter', () {
      final config = SmartPlaylistConfig(
        rules: [
          SmartPlaylistRule(
            field: SmartRuleField.playCount,
            operator: SmartRuleOperator.greaterThanOrEqual,
            value: '10',
          ),
        ],
      );

      final results = SmartPlaylistService.filterSongs(
        allSongs: sampleSongs,
        config: config,
        playCounts: samplePlayCounts,
      );
      expect(results.length, 3); // In the End (50), Numb (25), Hello (12)
      expect(results.map((s) => s.title), containsAll(['In the End', 'Numb', 'Hello']));
    });

    test('26. Format = FLAC rule filter', () {
      final config = SmartPlaylistConfig(
        rules: [
          SmartPlaylistRule(
            field: SmartRuleField.format,
            operator: SmartRuleOperator.equals,
            value: 'flac',
          ),
        ],
      );

      final results = SmartPlaylistService.filterSongs(allSongs: sampleSongs, config: config);
      expect(results.length, 2); // Numb, Bohemian Rhapsody
      expect(results.map((s) => s.title), containsAll(['Numb', 'Bohemian Rhapsody']));
    });

    test('27. AND Multiple Rules: Genre = Rock AND Favorite = true', () {
      final config = SmartPlaylistConfig(
        logic: SmartRuleLogic.all,
        rules: [
          SmartPlaylistRule(
            field: SmartRuleField.genre,
            operator: SmartRuleOperator.equals,
            value: 'Rock',
          ),
          SmartPlaylistRule(
            field: SmartRuleField.favorite,
            operator: SmartRuleOperator.isTrue,
            value: 'true',
          ),
        ],
      );

      final results = SmartPlaylistService.filterSongs(allSongs: sampleSongs, config: config);
      expect(results.length, 2); // Numb, Bohemian Rhapsody
      expect(results.map((s) => s.title), containsAll(['Numb', 'Bohemian Rhapsody']));
    });

    test('28. OR Multiple Rules: Genre = Pop OR Play Count >= 20', () {
      final config = SmartPlaylistConfig(
        logic: SmartRuleLogic.any,
        rules: [
          SmartPlaylistRule(
            field: SmartRuleField.genre,
            operator: SmartRuleOperator.equals,
            value: 'Pop',
          ),
          SmartPlaylistRule(
            field: SmartRuleField.playCount,
            operator: SmartRuleOperator.greaterThanOrEqual,
            value: '20',
          ),
        ],
      );

      final results = SmartPlaylistService.filterSongs(
        allSongs: sampleSongs,
        config: config,
        playCounts: samplePlayCounts,
      );
      // Pop: Hello, Shape of You. Play Count >= 20: Numb (25), In the End (50).
      expect(results.length, 4);
      expect(results.map((s) => s.title), containsAll(['Hello', 'Shape of You', 'Numb', 'In the End']));
    });

    test('29. Sorting by Duration Descending', () {
      final config = SmartPlaylistConfig(
        rules: [],
        sort: SmartSortOption.durationDesc,
      );

      final results = SmartPlaylistService.filterSongs(allSongs: sampleSongs, config: config);
      expect(results.first.title, 'Bohemian Rhapsody'); // 354 sec
      expect(results.last.title, 'Numb'); // 187 sec
    });

    test('30. Sorting by Play Count Descending with Limit = 2', () {
      final config = SmartPlaylistConfig(
        rules: [],
        sort: SmartSortOption.playCountDesc,
        limit: 2,
      );

      final results = SmartPlaylistService.filterSongs(
        allSongs: sampleSongs,
        config: config,
        playCounts: samplePlayCounts,
      );
      expect(results.length, 2);
      expect(results[0].title, 'In the End'); // 50
      expect(results[1].title, 'Numb'); // 25
    });

    test('31. Dynamic Refresh: when favorite toggles, filter result dynamically updates', () {
      final config = SmartPlaylistConfig(
        rules: [
          SmartPlaylistRule(
            field: SmartRuleField.favorite,
            operator: SmartRuleOperator.isTrue,
            value: 'true',
          ),
        ],
      );

      // Initial match
      var results = SmartPlaylistService.filterSongs(allSongs: sampleSongs, config: config);
      expect(results.any((s) => s.title == 'In the End'), isFalse);

      // User toggles favorite on 'In the End'
      final updatedSongs = sampleSongs.map((s) {
        if (s.title == 'In the End') return s.copyWith(isFavorite: true);
        return s;
      }).toList();

      results = SmartPlaylistService.filterSongs(allSongs: updatedSongs, config: config);
      expect(results.any((s) => s.title == 'In the End'), isTrue);
      expect(results.length, 4);
    });

    test('32. Human readable descriptions for rules generate clearly', () {
      final rule = SmartPlaylistRule(
        field: SmartRuleField.artist,
        operator: SmartRuleOperator.contains,
        value: 'Adele',
      );
      expect(rule.humanReadableDescription, contains('Artis mengandung "Adele"'));

      final favRule = SmartPlaylistRule(
        field: SmartRuleField.favorite,
        operator: SmartRuleOperator.isTrue,
        value: 'true',
      );
      expect(favRule.humanReadableDescription, contains('Favorit bernilai Benar'));
    });
  });
}
