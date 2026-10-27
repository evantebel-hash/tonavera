import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mymusic/models/song_model.dart';
import 'package:mymusic/services/artwork_color_service.dart';
import 'package:mymusic/widgets/now_playing/dynamic_background.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ArtworkColorService Tests', () {
    test('1. Null or empty artwork path returns default dark palette', () async {
      final service = ArtworkColorService.instance;
      final p1 = await service.extractPalette(null);
      final p2 = await service.extractPalette('');
      final p3 = await service.extractPalette('   ');

      expect(p1.dominantColor, ArtworkColorPalette.defaultDark.dominantColor);
      expect(p2.dominantColor, ArtworkColorPalette.defaultDark.dominantColor);
      expect(p3.dominantColor, ArtworkColorPalette.defaultDark.dominantColor);
    });

    test('2. Non-existent file path falls back gracefully without crash', () async {
      final service = ArtworkColorService.instance;
      final palette = await service.extractPalette('/invalid/non_existent/artwork.jpg');

      expect(palette.dominantColor, ArtworkColorPalette.defaultDark.dominantColor);
      expect(palette.secondaryColor, ArtworkColorPalette.defaultDark.secondaryColor);
    });

    test('3. Cache retention returns cached palette for same path', () async {
      final service = ArtworkColorService.instance;
      service.clearCache();

      const path = '/some/virtual/test_path.png';
      final p1 = await service.extractPalette(path);
      final p2 = await service.extractPalette(path);

      expect(identical(p1, p2), isTrue);
    });
  });

  group('DynamicBackground Widget Tests', () {
    testWidgets('4. Dynamic background renders child content properly when enabled', (tester) async {
      final song = SongModel(
        id: 1,
        artistId: 10,
        title: 'Song With Background',
        artistName: 'Artist A',
        duration: 200,
        audioPath: '/dummy/song.mp3',
        cover: '/dummy/cover.jpg',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DynamicBackground(
              song: song,
              enabled: true,
              child: const Text('Foreground Content'),
            ),
          ),
        ),
      );

      expect(find.text('Foreground Content'), findsOneWidget);
    });

    testWidgets('5. Dynamic background returns fallback container when disabled', (tester) async {
      final song = SongModel(
        id: 2,
        artistId: 10,
        title: 'Song Disabled BG',
        duration: 180,
        audioPath: '/dummy/song.mp3',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DynamicBackground(
              song: song,
              enabled: false,
              child: const Text('Disabled Mode Content'),
            ),
          ),
        ),
      );

      expect(find.text('Disabled Mode Content'), findsOneWidget);
      // AnimatedSwitcher should not be rendered when disabled
      expect(find.byType(AnimatedSwitcher), findsNothing);
    });

    testWidgets('6. Missing artwork renders fallback ambient gradient without throwing', (tester) async {
      final song = SongModel(
        id: 3,
        artistId: 10,
        title: 'Missing Artwork Song',
        duration: 150,
        audioPath: '/dummy/song.mp3',
        cover: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DynamicBackground(
              song: song,
              enabled: true,
              child: const Text('No Artwork Content'),
            ),
          ),
        ),
      );

      expect(find.text('No Artwork Content'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('7. Song change transitions AnimatedSwitcher key', (tester) async {
      final songA = SongModel(
        id: 101,
        artistId: 1,
        title: 'Song A',
        duration: 200,
        audioPath: '/a.mp3',
        cover: '/cover_a.jpg',
      );

      final songB = SongModel(
        id: 102,
        artistId: 2,
        title: 'Song B',
        duration: 240,
        audioPath: '/b.mp3',
        cover: '/cover_b.jpg',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DynamicBackground(
              song: songA,
              enabled: true,
              child: Text('Now Playing: ${songA.title}'),
            ),
          ),
        ),
      );

      expect(find.text('Now Playing: Song A'), findsOneWidget);

      // Change song to songB
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DynamicBackground(
              song: songB,
              enabled: true,
              child: Text('Now Playing: ${songB.title}'),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Now Playing: Song B'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('8. Intensity variations adjust blur and overlay without errors', (tester) async {
      final song = SongModel(
        id: 200,
        artistId: 5,
        title: 'Intensity Test',
        duration: 120,
        audioPath: '/test.mp3',
      );

      for (final intensity in DynamicBackgroundIntensity.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DynamicBackground(
                song: song,
                enabled: true,
                intensity: intensity,
                child: Text('Intensity: ${intensity.name}'),
              ),
            ),
          ),
        );
        expect(find.text('Intensity: ${intensity.name}'), findsOneWidget);
      }
    });
  });
}
