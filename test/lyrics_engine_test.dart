import 'package:flutter_test/flutter_test.dart';
import 'package:mymusic/models/lyric_line.dart';
import 'package:mymusic/models/lyrics_model.dart';
import 'package:mymusic/models/song_model.dart';
import 'package:mymusic/services/lrc_parser.dart';
import 'package:mymusic/services/lrclib_service.dart';
import 'package:mymusic/services/lyrics_fallback_provider.dart';

void main() {
  group('LrcParser Tests', () {
    test('1. LRC parser basic timestamp [mm:ss.xx]', () {
      const lrc = '''
[00:12.50]Hello world
[00:15.20]How are you?
''';
      final result = LrcParser.parse(lrc);
      expect(result.length, 2);
      expect(result[0].startTime.inMilliseconds, 12500);
      expect(result[0].text, 'Hello world');
      expect(result[1].startTime.inMilliseconds, 15200);
      expect(result[1].text, 'How are you?');
    });

    test('2. LRC parser 3-digit milliseconds [mm:ss.xxx]', () {
      const lrc = '[01:05.123]High precision timestamp';
      final result = LrcParser.parse(lrc);
      expect(result.length, 1);
      expect(result[0].startTime.inMilliseconds, 65123);
      expect(result[0].text, 'High precision timestamp');
    });

    test('3. LRC parser handles malformed timestamp gracefully', () {
      const lrc = '''
[invalid:time]Malformed line
[00:20.00]Valid line
Some header without timestamp
''';
      final result = LrcParser.parse(lrc);
      expect(result.length, 1);
      expect(result[0].startTime.inSeconds, 20);
      expect(result[0].text, 'Valid line');
    });

    test('4. LRC parser multiple timestamps per line', () {
      const lrc = '[00:10.00][00:20.00]Repeated chorus';
      final result = LrcParser.parse(lrc);
      expect(result.length, 2);
      expect(result[0].startTime.inSeconds, 10);
      expect(result[0].text, 'Repeated chorus');
      expect(result[1].startTime.inSeconds, 20);
      expect(result[1].text, 'Repeated chorus');
    });

    test('5. LRC sorting by start time', () {
      const lrc = '''
[00:30.00]Third line
[00:10.00]First line
[00:20.00]Second line
''';
      final result = LrcParser.parse(lrc);
      expect(result.length, 3);
      expect(result[0].text, 'First line');
      expect(result[1].text, 'Second line');
      expect(result[2].text, 'Third line');
    });

    test('6. Plain lyrics detection', () {
      const plain = 'Line 1 without timestamps\nLine 2 without timestamps';
      expect(LrcParser.hasTimestamps(plain), isFalse);

      const synced = '[00:05.00]Synced lyric';
      expect(LrcParser.hasTimestamps(synced), isTrue);
    });

    test('7. Binary search active lyric calculation & Seek', () {
      final lines = [
        const LyricLine(startTime: Duration(seconds: 5), text: 'Line 1'),
        const LyricLine(startTime: Duration(seconds: 10), text: 'Line 2'),
        const LyricLine(startTime: Duration(seconds: 15), text: 'Line 3'),
        const LyricLine(startTime: Duration(seconds: 25), text: 'Line 4'),
      ];

      // Before first line
      expect(
        LrcParser.findActiveLineIndex(lines, const Duration(seconds: 2)),
        -1,
      );

      // Exactly on line 1
      expect(
        LrcParser.findActiveLineIndex(lines, const Duration(seconds: 5)),
        0,
      );

      // Between line 1 and 2
      expect(
        LrcParser.findActiveLineIndex(lines, const Duration(seconds: 8)),
        0,
      );

      // On line 3
      expect(
        LrcParser.findActiveLineIndex(lines, const Duration(seconds: 18)),
        2,
      );

      // Seek forward to line 4
      expect(
        LrcParser.findActiveLineIndex(lines, const Duration(seconds: 30)),
        3,
      );

      // Seek backward to line 2
      expect(
        LrcParser.findActiveLineIndex(lines, const Duration(seconds: 12)),
        1,
      );
    });

    test('8. Unicode and multilingual lyrics support', () {
      const lrc = '''
[00:01.00]日本語の歌詞 (Japanese)
[00:05.00]한국어 가사 (Korean)
[00:10.00]中文歌词 (Chinese)
[00:15.00]Lirik bahasa Indonesia
[00:20.00]كلمات عربية (Arabic)
''';
      final result = LrcParser.parse(lrc);
      expect(result.length, 5);
      expect(result[0].text, '日本語の歌詞 (Japanese)');
      expect(result[1].text, '한국어 가사 (Korean)');
      expect(result[2].text, '中文歌词 (Chinese)');
      expect(result[3].text, 'Lirik bahasa Indonesia');
      expect(result[4].text, 'كلمات عربية (Arabic)');
    });

    test('9. Normalization of CRLF and extra whitespace', () {
      const raw =
          "\r\n[00:02.00]  Spaced line   \r\n\r\n[00:04.00]Clean line\r\n";
      final normalized = LrcParser.normalize(raw);
      expect(normalized.contains('\r'), isFalse);

      final parsed = LrcParser.parse(normalized);
      expect(parsed.length, 2);
      expect(parsed[0].text, 'Spaced line');
      expect(parsed[1].text, 'Clean line');
    });

    test(
      '9b. LRC offset positive tag delays timestamps (adds offset to startTime)',
      () {
        const lrc = '''
[offset:+500]
[00:02.000]Delayed lyric line
''';
        final parsed = LrcParser.parse(lrc);
        expect(parsed.length, 1);
        // Original 2000ms + 500ms offset = 2500ms
        expect(parsed[0].startTime.inMilliseconds, 2500);
        expect(parsed[0].text, 'Delayed lyric line');
      },
    );

    test(
      '9c. LRC offset negative tag advances timestamps (subtracts offset from startTime)',
      () {
        const lrc = '''
[offset:-800]
[00:02.000]Advanced lyric line
''';
        final parsed = LrcParser.parse(lrc);
        expect(parsed.length, 1);
        // Original 2000ms + (-800ms) offset = 1200ms
        expect(parsed[0].startTime.inMilliseconds, 1200);
        expect(parsed[0].text, 'Advanced lyric line');
      },
    );

    test(
      '9d. LRC offset clamping prevents negative timestamps when advanced past zero',
      () {
        const lrc = '''
[offset:-5000]
[00:02.000]Clamped lyric line
''';
        final parsed = LrcParser.parse(lrc);
        expect(parsed.length, 1);
        // Original 2000ms + (-5000ms) offset = -3000ms, clamped to 0ms
        expect(parsed[0].startTime.inMilliseconds, 0);
        expect(parsed[0].text, 'Clamped lyric line');
      },
    );

    test('9e. LRC without offset retains exact parsed timestamps', () {
      const lrc = '[00:02.500]Exact lyric line';
      final parsed = LrcParser.parse(lrc);
      expect(parsed.length, 1);
      expect(parsed[0].startTime.inMilliseconds, 2500);
      expect(parsed[0].text, 'Exact lyric line');
    });

    test(
      '9f. Online stream and offline file playback position tracking comparison',
      () {
        final lines = [
          const LyricLine(
            startTime: Duration(milliseconds: 1500),
            text: 'Intro vocal',
          ),
          const LyricLine(
            startTime: Duration(milliseconds: 4000),
            text: 'Verse 1',
          ),
          const LyricLine(
            startTime: Duration(milliseconds: 7500),
            text: 'Verse 2',
          ),
          const LyricLine(
            startTime: Duration(milliseconds: 12000),
            text: 'Chorus',
          ),
        ];

        // Scenario: Audio position advances steadily
        expect(LrcParser.findActiveLineIndex(lines, Duration.zero), -1);
        expect(
          LrcParser.findActiveLineIndex(
            lines,
            const Duration(milliseconds: 1499),
          ),
          -1,
        );
        expect(
          LrcParser.findActiveLineIndex(
            lines,
            const Duration(milliseconds: 1500),
          ),
          0,
        );
        expect(
          LrcParser.findActiveLineIndex(
            lines,
            const Duration(milliseconds: 3999),
          ),
          0,
        );
        expect(
          LrcParser.findActiveLineIndex(
            lines,
            const Duration(milliseconds: 4000),
          ),
          1,
        );
        expect(
          LrcParser.findActiveLineIndex(
            lines,
            const Duration(milliseconds: 7500),
          ),
          2,
        );
        expect(
          LrcParser.findActiveLineIndex(
            lines,
            const Duration(milliseconds: 12000),
          ),
          3,
        );
        expect(
          LrcParser.findActiveLineIndex(
            lines,
            const Duration(milliseconds: 30000),
          ),
          3,
        );
      },
    );

    test(
      '9g. Seek to intro resets active line to -1 (intro reset guarantee)',
      () {
        final lines = [
          const LyricLine(startTime: Duration(seconds: 3), text: 'Line 1'),
          const LyricLine(startTime: Duration(seconds: 8), text: 'Line 2'),
        ];

        // Playing at 5s -> Line 0 active
        expect(
          LrcParser.findActiveLineIndex(lines, const Duration(seconds: 5)),
          0,
        );

        // User seeks back to 1s (before first lyric line) -> must return -1
        expect(
          LrcParser.findActiveLineIndex(lines, const Duration(seconds: 1)),
          -1,
        );
        expect(LrcParser.findActiveLineIndex(lines, Duration.zero), -1);
      },
    );

    test('9h. Pause and resume keeps exact position and line sync', () {
      final lines = [
        const LyricLine(startTime: Duration(seconds: 10), text: 'Line 1'),
        const LyricLine(startTime: Duration(seconds: 20), text: 'Line 2'),
      ];

      // While paused at 15s, position is frozen at 15s
      const pausedPos = Duration(seconds: 15);
      expect(LrcParser.findActiveLineIndex(lines, pausedPos), 0);

      // On resume, position advances to 20s
      const resumedPos = Duration(seconds: 20);
      expect(LrcParser.findActiveLineIndex(lines, resumedPos), 1);
    });
  });

  group('LyricsModel Serialization Tests', () {
    test('10. LyricsModel toMap and fromMap serialization', () {
      final now = DateTime.now();
      final model = LyricsModel(
        id: 123,
        songId: 456,
        source: LyricsSource.lrclib,
        plainLyrics: 'Plain lyrics content',
        syncedLyrics: '[00:05.00]Synced lyrics content',
        language: 'id',
        fetchedAt: now,
        updatedAt: now,
        isSynced: true,
      );

      final map = model.toMap();
      final reconstructed = LyricsModel.fromMap(map);

      expect(reconstructed.id, model.id);
      expect(reconstructed.songId, model.songId);
      expect(reconstructed.source, LyricsSource.lrclib);
      expect(reconstructed.plainLyrics, model.plainLyrics);
      expect(reconstructed.syncedLyrics, model.syncedLyrics);
      expect(reconstructed.isSynced, isTrue);
      expect(reconstructed.hasSyncedLyrics, isTrue);
    });

    test('11. LyricsModel parsing from embedded plain text', () {
      final model = LyricsModel.fromEmbedded(
        songId: 789,
        rawLyrics: 'Just normal lines without time tags\nSecond line',
      );

      expect(model.source, LyricsSource.embedded);
      expect(model.isSynced, isFalse);
      expect(model.hasSyncedLyrics, isFalse);
      expect(model.plainLyrics, isNotNull);
      expect(model.syncedLyrics, isNull);
    });

    test('12. LyricsModel parsing from embedded synced LRC', () {
      final model = LyricsModel.fromEmbedded(
        songId: 101,
        rawLyrics: '[00:10.00]Embedded synced lyric line',
      );

      expect(model.source, LyricsSource.embedded);
      expect(model.isSynced, isTrue);
      expect(model.hasSyncedLyrics, isTrue);
    });
  });

  group('LRCLIB Service & Matching Tests', () {
    test('13. LRCLIB parsing valid JSON response', () {
      final json = {
        'id': 12345,
        'name': 'Shape of You',
        'trackName': 'Shape of You',
        'artistName': 'Ed Sheeran',
        'albumName': 'Divide',
        'duration': 233.0,
        'instrumental': false,
        'plainLyrics': 'The club isn\'t the best place to find a lover...',
        'syncedLyrics':
            '[00:10.00]The club isn\'t the best place to find a lover...',
      };

      final song = SongModel(
        id: 1,
        artistId: 10,
        title: 'Shape of You',
        artistName: 'Ed Sheeran',
        albumTitle: 'Divide',
        duration: 233,
        audioPath: '/dummy/path.mp3',
      );

      final service = LrclibService();
      final result = service.parseApiResponse(json, song);

      expect(result, isNotNull);
      expect(result!.source, LyricsSource.lrclib);
      expect(result.isSynced, isTrue);
      expect(result.songId, 1);
      expect(result.plainLyrics, contains('The club'));
      expect(result.syncedLyrics, contains('[00:10.00]'));
    });

    test('14. LRCLIB duration tolerance matching', () {
      final json = {
        'trackName': 'Song Title',
        'artistName': 'Artist',
        'duration': 200.0, // 200s
        'syncedLyrics': '[00:05.00]Lyric line',
      };

      // Song duration is 208s (diff is 8s <= 15s tolerance) -> Should Match
      final matchingSong = SongModel(
        id: 2,
        artistId: 10,
        title: 'Song Title',
        artistName: 'Artist',
        duration: 208,
        audioPath: '/dummy.mp3',
      );

      // Song duration is 250s (diff is 50s > 15s tolerance) -> Should Reject
      final mismatchedSong = SongModel(
        id: 3,
        artistId: 10,
        title: 'Song Title',
        artistName: 'Artist',
        duration: 250,
        audioPath: '/dummy2.mp3',
      );

      final service = LrclibService();
      final match1 = service.parseApiResponse(json, matchingSong);
      expect(match1, isNotNull);

      final match2 = service.parseApiResponse(json, mismatchedSong);
      expect(match2, isNull);
    });

    test('15. LRCLIB malformed response or empty content returns null', () {
      final service = LrclibService();
      final song = SongModel(
        id: 1,
        artistId: 1,
        title: 'A',
        duration: 100,
        audioPath: '/a.mp3',
      );

      expect(service.parseApiResponse({'empty': true}, song), isNull);
      expect(
        service.parseApiResponse({'syncedLyrics': '', 'plainLyrics': ''}, song),
        isNull,
      );
    });

    test('16. LocalAiFallbackProvider stub returns null gracefully', () async {
      final fallback = LocalAiLyricsProvider();
      final song = SongModel(
        id: 99,
        artistId: 1,
        title: 'Local AI Test',
        duration: 120,
        audioPath: '/local.mp3',
      );

      final result = await fallback.fetchLyrics(song);
      expect(result, isNull);
    });
  });
}
