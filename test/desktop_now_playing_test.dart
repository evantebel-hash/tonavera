import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mymusic/models/song_model.dart';
import 'package:mymusic/providers/player_provider.dart';
import 'package:mymusic/screens/player/player_screen.dart';
import 'package:mymusic/widgets/rotating_album_cover.dart';

class MockDesktopPlayerProvider extends ChangeNotifier implements PlayerProvider {
  final SongModel? _song;
  bool _isPlaying = true;
  Duration _pos = const Duration(seconds: 45);
  final Duration _dur = const Duration(seconds: 210);
  final bool _dynBg = false;
  final bool _visEnabled = true;
  final bool _wfEnabled = false;
  bool _isShuffle = false;
  final AppRepeatMode _repeat = AppRepeatMode.off;
  final List<SongModel> _queueList;
  int _currIdx = 0;

  MockDesktopPlayerProvider(this._song, this._queueList);

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
  List<SongModel> get queue => _queueList;
  @override
  int get currentIndex => _currIdx;
  @override
  bool get isResolvingYouTube => false;
  @override
  bool get isLoadingAudio => false;

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
  Future<void> playQueueIndex(int index, {BuildContext? context}) async {
    _currIdx = index;
    notifyListeners();
  }

  @override
  void removeFromQueue(int index) {
    if (index >= 0 && index < _queueList.length) {
      _queueList.removeAt(index);
      notifyListeners();
    }
  }

  @override
  void clearQueue() {
    _queueList.clear();
    notifyListeners();
  }

  @override
  Future<void> toggleFavorite(SongModel song) async {
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Desktop Now Playing Fidelity Tests (Phase 7D)', () {
    final testSong = SongModel(
      id: 101,
      artistId: 1,
      title: 'Midnight Frequencies',
      artistName: 'Aura & The Soundscapes',
      albumTitle: 'Neon Echoes',
      genreName: 'Electronic',
      duration: 210,
      audioPath: 'song.flac',
      filePath: 'C:/Music/song.flac',
      source: 'local',
    );

    final queueTracks = [
      testSong,
      SongModel(
        id: 102,
        artistId: 1,
        title: 'Resonance',
        artistName: 'Aura & The Soundscapes',
        albumTitle: 'Neon Echoes',
        duration: 195,
        audioPath: 'res.flac',
        source: 'local',
      ),
      SongModel(
        id: 103,
        artistId: 1,
        title: 'Lost in Time',
        artistName: 'Aura & The Soundscapes',
        albumTitle: 'Neon Echoes',
        duration: 240,
        audioPath: 'lost.flac',
        source: 'local',
      ),
    ];

    testWidgets('1. Desktop layout renders Hero Vinyl Left Stage and Right Stage Studio Hub', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockPlayer = MockDesktopPlayerProvider(testSong, List.from(queueTracks));

      await tester.pumpWidget(
        ChangeNotifierProvider<PlayerProvider>.value(
          value: mockPlayer,
          child: const MaterialApp(
            home: PlayerScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Left Stage elements
      expect(find.byType(RotatingAlbumCover), findsOneWidget);
      expect(find.text('Acoustic Pulse'), findsOneWidget);
      expect(find.text('High-quality local playback'), findsOneWidget);

      // Verify Right Stage Header & Metadata
      expect(find.text('PLAYING FROM · NEON ECHOES'), findsOneWidget);
      expect(find.text('Midnight Frequencies'), findsOneWidget);
      expect(find.text('Aura & The Soundscapes'), findsOneWidget);
      expect(find.text('FLAC LOSSLESS'), findsOneWidget);

      // Verify Studio Hub Tab Bar
      expect(find.text('Lirik Lagu'), findsOneWidget);
      expect(find.text('Antrean (3)'), findsOneWidget);
      expect(find.text('Info Audio'), findsOneWidget);
    });

    testWidgets('2. Studio Hub switching: Antrean (Queue) and Info Audio tabs work seamlessly', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockPlayer = MockDesktopPlayerProvider(testSong, List.from(queueTracks));

      await tester.pumpWidget(
        ChangeNotifierProvider<PlayerProvider>.value(
          value: mockPlayer,
          child: const MaterialApp(
            home: PlayerScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Switch to Antrean Tab
      await tester.tap(find.text('Antrean (3)'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('UP NEXT (3)'), findsOneWidget);
      expect(find.text('Resonance'), findsOneWidget);
      expect(find.text('Lost in Time'), findsOneWidget);

      // Switch to Info Audio Tab
      await tester.tap(find.text('Info Audio'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('SPESIFIKASI AUDIO & TELEMETRI'), findsOneWidget);
      expect(find.text('24-bit / 96.0 kHz Lossless'), findsOneWidget);
      expect(find.text('2.0 Stereo'), findsOneWidget);
    });

    testWidgets('3. Responsive mobile layout renders safely without overflow', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockPlayer = MockDesktopPlayerProvider(testSong, List.from(queueTracks));

      await tester.pumpWidget(
        ChangeNotifierProvider<PlayerProvider>.value(
          value: mockPlayer,
          child: const MaterialApp(
            home: PlayerScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Midnight Frequencies'), findsOneWidget);
      expect(find.byType(RotatingAlbumCover), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
