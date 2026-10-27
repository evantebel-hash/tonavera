import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mymusic/widgets/now_playing/audio_visualizer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioVisualizer Tests (Phase 3.3)', () {
    testWidgets('1. AudioVisualizer renders when enabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AudioVisualizer(
              isPlaying: true,
              enabled: true,
            ),
          ),
        ),
      );

      expect(find.byType(AudioVisualizer), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AudioVisualizer),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
    });

    testWidgets('2. AudioVisualizer renders empty SizedBox when disabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AudioVisualizer(
              isPlaying: true,
              enabled: false,
            ),
          ),
        ),
      );

      expect(find.byType(AudioVisualizer), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AudioVisualizer),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
    });

    testWidgets('3. Responds to paused state gracefully without crash', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AudioVisualizer(
              isPlaying: false,
              enabled: true,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AudioVisualizer), findsOneWidget);
    });

    testWidgets('4. Responds to buffering state without crash', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AudioVisualizer(
              isPlaying: false,
              isBuffering: true,
              enabled: true,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AudioVisualizer), findsOneWidget);
    });

    testWidgets('5. Song change triggers reset without exception', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AudioVisualizer(
              isPlaying: true,
              songId: 'song_1',
              enabled: true,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AudioVisualizer(
              isPlaying: true,
              songId: 'song_2',
              enabled: true,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AudioVisualizer), findsOneWidget);
    });
  });
}
