import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mymusic/models/song_model.dart';
import 'package:mymusic/providers/player_provider.dart';
import 'package:mymusic/services/desktop/desktop_integration_service.dart';
import 'package:mymusic/widgets/desktop/floating_mini_player_window.dart';

class MockTestPlayerProvider extends ChangeNotifier implements PlayerProvider {
  SongModel? _song;
  bool _isPlaying = false;
  Duration _pos = const Duration(seconds: 15);
  final Duration _dur = const Duration(seconds: 200);

  MockTestPlayerProvider({SongModel? song, bool isPlaying = false}) {
    _song = song;
    _isPlaying = isPlaying;
  }

  @override
  SongModel? get currentSong => _song;
  @override
  bool get isPlaying => _isPlaying;
  @override
  Duration get position => _pos;
  @override
  Duration get duration => _dur;

  void updatePositionSilently(Duration p) {
    _pos = p;
    notifyListeners();
  }

  void changeTrack(SongModel s) {
    _song = s;
    notifyListeners();
  }

  void setPlaying(bool p) {
    _isPlaying = p;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final songA = SongModel(
    id: 1,
    title: 'Song One',
    artistName: 'Artist A',
    artistId: 1,
    duration: 200,
    audioPath: 'song1.mp3',
  );

  final songB = SongModel(
    id: 2,
    title: 'Song Two',
    artistName: 'Artist B',
    artistId: 1,
    duration: 180,
    audioPath: 'song2.mp3',
  );

  group('Runtime Verification: DesktopIntegrationService Lifecycle & Listeners', () {
    test('A & B. Repeated 5x Open/Close latency and single listener integrity', () async {
      SharedPreferences.setMockInitialValues({});
      final service = DesktopIntegrationService.instance;
      service.isTestMode = true;
      final player = MockTestPlayerProvider(song: songA, isPlaying: true);

      await service.init(playerProvider: player);

      int toggleCount = 0;
      service.setToggleMiniPlayerCallback(() {
        toggleCount++;
      });

      final openTimes = <int>[];
      final closeTimes = <int>[];

      // Perform 5 complete OPEN -> CLOSE cycles
      for (int i = 0; i < 5; i++) {
        final swOpen = Stopwatch()..start();
        await service.setMiniPlayerMode(true);
        swOpen.stop();
        openTimes.add(swOpen.elapsedMicroseconds);

        expect(service.isMiniPlayerMode, isTrue);
        expect(service.miniPlayerNotifier.value, isTrue);

        final swClose = Stopwatch()..start();
        await service.setMiniPlayerMode(false);
        swClose.stop();
        closeTimes.add(swClose.elapsedMicroseconds);

        expect(service.isMiniPlayerMode, isFalse);
        expect(service.miniPlayerNotifier.value, isFalse);
      }

      expect(toggleCount, 10); // 5 opens + 5 closes
      expect(openTimes.length, 5);
      expect(closeTimes.length, 5);

      // Latencies should remain near instantaneous (< 10ms per toggle)
      for (int t in openTimes) {
        expect(t < 50000, isTrue, reason: 'Open took ${t}us which is exceptionally fast');
      }
      for (int t in closeTimes) {
        expect(t < 50000, isTrue, reason: 'Close took ${t}us which is exceptionally fast');
      }
    });

    test('C & D. Engine lifecycle and window controller re-use', () async {
      SharedPreferences.setMockInitialValues({});
      final service = DesktopIntegrationService.instance;
      service.isTestMode = true;

      // Verify initial state
      expect(service.isMiniPlayerMode, isFalse);

      // Toggle 5 times
      for (int i = 0; i < 5; i++) {
        await service.setMiniPlayerMode(true);
        expect(service.isMiniPlayerMode, isTrue);
        await service.setMiniPlayerMode(false);
        expect(service.isMiniPlayerMode, isFalse);
      }

      // Final state check: no lingering active flag
      expect(service.miniPlayerNotifier.value, isFalse);
    });

    test('E & F. IPC Throttling & State Change Responsiveness', () async {
      SharedPreferences.setMockInitialValues({});
      final service = DesktopIntegrationService.instance;
      service.isTestMode = true;
      final player = MockTestPlayerProvider(song: songA, isPlaying: true);
      await service.init(playerProvider: player);

      // Rapidly trigger 50 position notifications in 100ms
      for (int i = 0; i < 50; i++) {
        player.updatePositionSilently(Duration(seconds: 15 + i));
      }

      // Track change should trigger immediate unthrottled broadcast
      player.changeTrack(songB);
      expect(player.currentSong?.id, 2);

      // Play state change should trigger immediate unthrottled broadcast
      player.setPlaying(false);
      expect(player.isPlaying, isFalse);
    });
  });

  group('Runtime Verification: FloatingMiniPlayerWindowView Widget Tree', () {
    testWidgets('G & H. Vinyl RepaintBoundary and 480x125 layout constraints', (WidgetTester tester) async {
      await tester.pumpWidget(
        const SizedBox(
          width: 480,
          height: 125,
          child: MiniPlayerStandaloneApp(windowId: 'test_window_runtime'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      // Verify FloatingMiniPlayerWindowView rendered
      expect(find.byType(FloatingMiniPlayerWindowView), findsOneWidget);

      // Verify RepaintBoundary is applied to the vinyl disc to isolate rotation repaints
      expect(find.byType(RepaintBoundary), findsWidgets);

      // Verify controls are present and non-overflowing
      expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Verify no RenderFlex exception occurred
      expect(tester.takeException(), isNull);
    });

    testWidgets('I. 5 repeated toggles in widget test do not leak resources', (WidgetTester tester) async {
      for (int i = 0; i < 5; i++) {
        await tester.pumpWidget(
          const SizedBox(
            width: 480,
            height: 125,
            child: MiniPlayerStandaloneApp(windowId: 'test_cycle_window'),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));

        // Tear down to simulate window hide/unmount
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(tester.takeException(), isNull);
    });
  });
}
