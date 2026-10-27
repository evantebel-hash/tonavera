import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mymusic/models/song_model.dart';
import 'package:mymusic/providers/player_provider.dart';
import 'package:mymusic/screens/player/fullscreen_now_playing_screen.dart';
import 'package:mymusic/widgets/now_playing/dynamic_background.dart';
import 'package:mymusic/widgets/now_playing/audio_visualizer.dart';
import 'package:mymusic/widgets/now_playing/waveform_seek_bar.dart';

class MockPlayerProvider extends ChangeNotifier implements PlayerProvider {
  final SongModel? _song;
  bool _isPlaying = true;
  Duration _pos = const Duration(seconds: 40);
  final Duration _dur = const Duration(seconds: 200);
  final bool _dynBg = true;
  final bool _visEnabled = true;
  final bool _wfEnabled = true;
  bool _isShuffle = false;
  AppRepeatMode _repeat = AppRepeatMode.off;

  MockPlayerProvider(this._song);

  @override
  SongModel? get currentSong => _song;
  @override
  bool get isPlaying => _isPlaying;
  @override
  Duration get position => _pos;
  @override
  Duration get duration => _dur;
  @override
  bool get dynamicBackgroundEnabled => _dynBg;
  @override
  bool get visualizerEnabled => _visEnabled;
  @override
  bool get waveformSeekEnabled => _wfEnabled;
  @override
  bool get isShuffle => _isShuffle;
  @override
  AppRepeatMode get repeatMode => _repeat;

  @override
  Future<void> togglePlayPause() async {
    _isPlaying = !_isPlaying;
    notifyListeners();
  }

  @override
  Future<void> seek(Duration pos) async {
    _pos = pos;
    notifyListeners();
  }

  @override
  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    notifyListeners();
  }

  @override
  void toggleRepeat() {
    if (_repeat == AppRepeatMode.off) {
      _repeat = AppRepeatMode.forever;
    } else {
      _repeat = AppRepeatMode.off;
    }
    notifyListeners();
  }

  @override
  Future<void> toggleFavorite(SongModel song) async {
    notifyListeners();
  }

  @override
  Future<void> previous({bool isTest = false}) async {}

  @override
  Future<void> next({bool isTest = false, bool isAutoNext = false}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FullscreenNowPlayingScreen Tests (Phase 3.5)', () {
    final testSong = SongModel(
      id: 999,
      artistId: 1,
      title: 'Fullscreen Song Title',
      artistName: 'Immersive Artist',
      duration: 200,
      audioPath: 'test.mp3',
      filePath: '/path/to/test.mp3',
    );

    testWidgets('1. Renders FullscreenNowPlayingScreen with DynamicBg, Visualizer, and Waveform', (tester) async {
      final mockPlayer = MockPlayerProvider(testSong);

      await tester.pumpWidget(
        ChangeNotifierProvider<PlayerProvider>.value(
          value: mockPlayer,
          child: const MaterialApp(
            home: FullscreenNowPlayingScreen(),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(FullscreenNowPlayingScreen), findsOneWidget);
      expect(find.text('Fullscreen Song Title'), findsOneWidget);
      expect(find.text('Immersive Artist'), findsOneWidget);
      expect(find.byType(DynamicBackground), findsOneWidget);
      expect(find.byType(AudioVisualizer), findsOneWidget);
      expect(find.byType(WaveformSeekBar), findsOneWidget);
    });

    testWidgets('2. Toggle Play/Pause works in Fullscreen mode', (tester) async {
      final mockPlayer = MockPlayerProvider(testSong);

      await tester.pumpWidget(
        ChangeNotifierProvider<PlayerProvider>.value(
          value: mockPlayer,
          child: const MaterialApp(
            home: FullscreenNowPlayingScreen(),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(mockPlayer.isPlaying, isTrue);
      // Tap play/pause button
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump(const Duration(milliseconds: 100));

      expect(mockPlayer.isPlaying, isFalse);
    });

    testWidgets('3. Fallback message when currentSong is null', (tester) async {
      final mockPlayer = MockPlayerProvider(null);

      await tester.pumpWidget(
        ChangeNotifierProvider<PlayerProvider>.value(
          value: mockPlayer,
          child: const MaterialApp(
            home: FullscreenNowPlayingScreen(),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Tidak ada lagu yang sedang diputar'), findsOneWidget);
      expect(find.text('Kembali'), findsOneWidget);
    });
  });
}
