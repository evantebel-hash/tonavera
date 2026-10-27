import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mymusic/services/waveform_service.dart';
import 'package:mymusic/widgets/now_playing/waveform_seek_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WaveformService Tests (Phase 3.4)', () {
    test('1. Generates normalized waveform samples for song ID', () async {
      final service = WaveformService.instance;
      final samples = await service.getWaveform(
        songId: 'test_song_123',
        duration: const Duration(seconds: 180),
        sampleCount: 50,
      );

      expect(samples.length, 50);
      for (final s in samples) {
        expect(s >= 0.0 && s <= 1.0, isTrue);
      }
    });

    test('2. Returns cached waveform for same song ID and duration', () async {
      final service = WaveformService.instance;
      final s1 = await service.getWaveform(
        songId: 'cache_test_song',
        duration: const Duration(seconds: 200),
        sampleCount: 60,
      );
      final s2 = await service.getWaveform(
        songId: 'cache_test_song',
        duration: const Duration(seconds: 200),
        sampleCount: 60,
      );

      expect(identical(s1, s2), isTrue);
    });
  });

  group('WaveformSeekBar Widget Tests (Phase 3.4)', () {
    testWidgets('3. Renders waveform seek bar and triggers seek on tap', (tester) async {
      Duration? seekTarget;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                height: 48,
                child: WaveformSeekBar(
                  songId: 'widget_test_song',
                  position: const Duration(seconds: 30),
                  duration: const Duration(seconds: 100),
                  onSeek: (dur) {
                    seekTarget = dur;
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(WaveformSeekBar), findsOneWidget);

      // Tap in the middle of the waveform seek bar (50% position -> ~50s)
      final center = tester.getCenter(find.byType(WaveformSeekBar));
      await tester.tapAt(center);
      await tester.pump();

      expect(seekTarget, isNotNull);
      expect(seekTarget!.inSeconds, inInclusiveRange(45, 55));
    });

    testWidgets('4. Fallback progress renders gracefully when duration is zero', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WaveformSeekBar(
              position: Duration.zero,
              duration: Duration.zero,
              onSeek: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(WaveformSeekBar), findsOneWidget);
    });
  });
}
