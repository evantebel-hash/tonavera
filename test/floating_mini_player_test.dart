import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mymusic/models/song_model.dart';
import 'package:mymusic/providers/player_provider.dart';
import 'package:mymusic/widgets/desktop/floating_mini_player.dart';
import 'package:mymusic/widgets/desktop/floating_mini_player_window.dart';
import 'package:flutter/services.dart';
import 'package:mymusic/core/theme/v35_tokens.dart';
import 'package:mymusic/core/theme/v35_accent.dart';
import 'package:mymusic/services/desktop/desktop_integration_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockFloatingPlayerProvider extends ChangeNotifier implements PlayerProvider {
  SongModel? _song;
  bool _isPlaying = true;
  Duration _pos = const Duration(seconds: 45);
  final Duration _dur = const Duration(seconds: 180);
  final List<SongModel> _queueList = [];
  final int _currIdx = 0;
  bool togglePlayPauseCalled = false;
  bool nextCalled = false;
  bool previousCalled = false;
  Duration? lastSeekPosition;
  bool isFav = false;

  MockFloatingPlayerProvider({SongModel? song, bool isPlaying = true}) {
    _song = song;
    _isPlaying = isPlaying;
    if (song != null) {
      _queueList.add(song);
    }
  }

  @override
  SongModel? get currentSong => _song;
  @override
  bool get isPlaying => _isPlaying;
  @override
  Duration get position => _pos;
  @override
  Duration get duration => _dur;
  @override
  List<SongModel> get queue => _queueList;
  @override
  int get currentIndex => _currIdx;
  @override
  bool get isResolvingYouTube => false;
  @override
  bool get isLoadingAudio => false;
  @override
  bool get isShuffle => false;
  @override
  AppRepeatMode get repeatMode => AppRepeatMode.off;
  @override
  bool get dynamicBackgroundEnabled => false;
  @override
  bool get visualizerEnabled => false;
  @override
  bool get waveformSeekEnabled => false;

  @override
  Future<void> togglePlayPause() async {
    togglePlayPauseCalled = true;
    _isPlaying = !_isPlaying;
    notifyListeners();
  }

  @override
  Future<void> next({bool isTest = false, bool isAutoNext = false}) async {
    nextCalled = true;
    notifyListeners();
  }

  @override
  Future<void> previous({bool isTest = false}) async {
    previousCalled = true;
    notifyListeners();
  }

  @override
  Future<void> seek(Duration pos) async {
    lastSeekPosition = pos;
    _pos = pos;
    notifyListeners();
  }


  @override
  Future<void> toggleFavorite(SongModel s) async {
    isFav = !isFav;
    if (_song != null) {
      _song = _song!.copyWith(isFavorite: isFav);
    }
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testSong = SongModel(
    id: 101,
    title: 'Midnight City Sound',
    artistName: 'Luna Horizon',
    artistId: 1,
    duration: 180,
    audioPath: 'dummy.mp3',
  );

  Widget createWidgetUnderTest(MockFloatingPlayerProvider provider, {VoidCallback? onClose, double width = 430, double height = 140}) {
    return ChangeNotifierProvider<PlayerProvider>.value(
      value: provider,
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              height: height,
              child: FloatingMiniPlayer(onClose: onClose ?? () {}),
            ),
          ),
        ),
      ),
    );
  }

  group('FloatingMiniPlayer Widget & Visual Tests', () {
    testWidgets('1. Renders song title, artist, vinyl, controls, and progress bar without overflow', (WidgetTester tester) async {
      final mock = MockFloatingPlayerProvider(song: testSong);

      await tester.pumpWidget(createWidgetUnderTest(mock));
      await tester.pump(const Duration(milliseconds: 100));

      // Title & Artist verification
      expect(find.text('Midnight City Sound'), findsOneWidget);
      expect(find.text('Luna Horizon'), findsOneWidget);

      // Controls verification
      expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
      expect(find.byIcon(Icons.queue_music_rounded), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);

      // Close button
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Verify no RenderFlex overflow
      expect(tester.takeException(), isNull);
    });

    testWidgets('2. Play/Pause button toggles playback state and changes icon', (WidgetTester tester) async {
      final mock = MockFloatingPlayerProvider(song: testSong, isPlaying: true);

      await tester.pumpWidget(createWidgetUnderTest(mock));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump(const Duration(milliseconds: 100));

      expect(mock.togglePlayPauseCalled, isTrue);
      expect(mock.isPlaying, isFalse);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('3. Next and Previous buttons trigger player provider methods', (WidgetTester tester) async {
      final mock = MockFloatingPlayerProvider(song: testSong);

      await tester.pumpWidget(createWidgetUnderTest(mock));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byIcon(Icons.skip_next_rounded));
      expect(mock.nextCalled, isTrue);

      await tester.tap(find.byIcon(Icons.skip_previous_rounded));
      expect(mock.previousCalled, isTrue);
    });

    testWidgets('4. Close button calls onClose callback', (WidgetTester tester) async {
      bool closed = false;
      final mock = MockFloatingPlayerProvider(song: testSong);

      await tester.pumpWidget(createWidgetUnderTest(mock, onClose: () {
        closed = true;
      }));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byIcon(Icons.close_rounded));
      expect(closed, isTrue);
    });

    testWidgets('5. Responsive layout adapts at narrower width (340px) without overflow', (WidgetTester tester) async {
      final mock = MockFloatingPlayerProvider(song: testSong);

      await tester.pumpWidget(createWidgetUnderTest(mock, width: 340, height: 130));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Midnight City Sound'), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('6. Favorite button toggles favorite state', (WidgetTester tester) async {
      final mock = MockFloatingPlayerProvider(song: testSong);

      await tester.pumpWidget(createWidgetUnderTest(mock));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.favorite_border_rounded));
      await tester.pump(const Duration(milliseconds: 100));

      expect(mock.isFav, isTrue);
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    });
  });

  group('DesktopIntegrationService Mini Player Notification Tests', () {
    test('7. miniPlayerNotifier updates reactively when setMiniPlayerMode is called', () async {
      SharedPreferences.setMockInitialValues({});
      final service = DesktopIntegrationService.instance;
      service.isTestMode = true;

      expect(service.miniPlayerNotifier.value, isFalse);

      await service.setMiniPlayerMode(true);
      expect(service.miniPlayerNotifier.value, isTrue);
      expect(service.isMiniPlayerMode, isTrue);

      await service.setMiniPlayerMode(false);
      expect(service.miniPlayerNotifier.value, isFalse);
      expect(service.isMiniPlayerMode, isFalse);
    });
  });

  group('MiniPlayerStandaloneApp & FloatingMiniPlayerWindowView Tests', () {
    testWidgets('8. MiniPlayerStandaloneApp renders compact floating player window UI (480x125) without overflow', (WidgetTester tester) async {
      await tester.pumpWidget(
        const SizedBox(
          width: 480,
          height: 125,
          child: MiniPlayerStandaloneApp(windowId: 'test_window_1'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(FloatingMiniPlayerWindowView), findsOneWidget);
      expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('9. MiniPlayerStandaloneApp adapts to minimum compact size (420x115) without overflow', (WidgetTester tester) async {
      await tester.pumpWidget(
        const SizedBox(
          width: 420,
          height: 115,
          child: MiniPlayerStandaloneApp(windowId: 'test_window_2'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(FloatingMiniPlayerWindowView), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Mini Player Theme Color Dynamic Synchronization Tests', () {
    testWidgets('10. Mini Player follows global theme accent color and updates dynamically across changes', (WidgetTester tester) async {
      // 1. Initial default accent (Amber)
      V35Accent.setPreset(AccentPreset.amber);

      await tester.pumpWidget(
        const SizedBox(
          width: 480,
          height: 125,
          child: MiniPlayerStandaloneApp(windowId: 'test_theme_window'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final playBtnFinder = find.ancestor(
        of: find.byIcon(Icons.play_arrow_rounded),
        matching: find.byWidgetPredicate((w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle),
      );

      expect(playBtnFinder, findsOneWidget);
      var playBtnBox = tester.widget<Container>(playBtnFinder).decoration as BoxDecoration;
      expect(playBtnBox.color, V35Tokens.accent);
      expect(playBtnBox.color, AccentPreset.amber.base);

      // 2. Change accent to Ruby
      await V35Accent.setPreset(AccentPreset.ruby);
      await tester.pump(const Duration(milliseconds: 100));

      playBtnBox = tester.widget<Container>(playBtnFinder).decoration as BoxDecoration;
      expect(playBtnBox.color, AccentPreset.ruby.base);
      expect(playBtnBox.color, V35Tokens.accent);

      // 3. Change accent to Cyan
      await V35Accent.setPreset(AccentPreset.cyan);
      await tester.pump(const Duration(milliseconds: 100));

      playBtnBox = tester.widget<Container>(playBtnFinder).decoration as BoxDecoration;
      expect(playBtnBox.color, AccentPreset.cyan.base);
      expect(playBtnBox.color, V35Tokens.accent);

      // 4. Change accent to Emerald
      await V35Accent.setPreset(AccentPreset.emerald);
      await tester.pump(const Duration(milliseconds: 100));

      playBtnBox = tester.widget<Container>(playBtnFinder).decoration as BoxDecoration;
      expect(playBtnBox.color, AccentPreset.emerald.base);
      expect(playBtnBox.color, V35Tokens.accent);

      // 5. Change accent to Violet
      await V35Accent.setPreset(AccentPreset.violet);
      await tester.pump(const Duration(milliseconds: 100));

      playBtnBox = tester.widget<Container>(playBtnFinder).decoration as BoxDecoration;
      expect(playBtnBox.color, AccentPreset.violet.base);
      expect(playBtnBox.color, V35Tokens.accent);

      // 6. Close Mini Player and Reopen
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));

      await tester.pumpWidget(
        const SizedBox(
          width: 480,
          height: 125,
          child: MiniPlayerStandaloneApp(windowId: 'test_theme_reopened'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final reopenedBtn = tester.widget<Container>(playBtnFinder).decoration as BoxDecoration;
      expect(reopenedBtn.color, AccentPreset.violet.base);
      expect(reopenedBtn.color, V35Tokens.accent);

      // Reset to amber default
      await V35Accent.setPreset(AccentPreset.amber);
    });
  });

  group('Mini Player More Menu (⋯) Functionality Tests', () {
    testWidgets('11. More button opens contextual popup with 5 functional actions and zero overflow', (WidgetTester tester) async {
      await tester.pumpWidget(
        const SizedBox(
          width: 480,
          height: 125,
          child: MiniPlayerStandaloneApp(windowId: 'test_more_window'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Initially menu is closed
      expect(find.text('Add to Queue'), findsNothing);
      expect(find.text('Open Queue'), findsNothing);
      expect(find.text('Open Full Player'), findsNothing);
      expect(find.text('Hide Mini Player'), findsNothing);

      // Tap ⋯ button
      final moreBtn = find.byIcon(Icons.more_horiz_rounded);
      expect(moreBtn, findsOneWidget);
      await tester.tap(moreBtn);
      await tester.pump(const Duration(milliseconds: 50));

      // Menu is now open with all actions
      expect(find.text('Add to Queue'), findsOneWidget);
      expect(find.text('Add to Favorites'), findsOneWidget);
      expect(find.text('Open Queue'), findsOneWidget);
      expect(find.text('Open Full Player'), findsOneWidget);
      expect(find.text('Hide Mini Player'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('12. More menu closes on outside tap and on Escape key', (WidgetTester tester) async {
      await tester.pumpWidget(
        const SizedBox(
          width: 480,
          height: 125,
          child: MiniPlayerStandaloneApp(windowId: 'test_dismiss_window'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Open menu
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Add to Queue'), findsOneWidget);

      // Outside tap (e.g. top-left corner)
      await tester.tapAt(const Offset(20, 20));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Add to Queue'), findsNothing);

      // Open menu again
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Add to Queue'), findsOneWidget);

      // Press Escape key
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Add to Queue'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('13. Favorite menu action updates dynamic label and heart state immediately', (WidgetTester tester) async {
      await tester.pumpWidget(
        const SizedBox(
          width: 480,
          height: 125,
          child: MiniPlayerStandaloneApp(windowId: 'test_fav_action_window'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Open menu
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Add to Favorites'), findsOneWidget);

      // Tap 'Add to Favorites'
      await tester.tap(find.text('Add to Favorites'));
      await tester.pump(const Duration(milliseconds: 50));

      // Menu closes automatically
      expect(find.text('Add to Favorites'), findsNothing);

      // Heart icon in top bar is now active (favorite_rounded)
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

      // Reopen menu: label dynamically shows 'Remove from Favorites'
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Remove from Favorites'), findsOneWidget);

      // Tap 'Remove from Favorites'
      await tester.tap(find.text('Remove from Favorites'));
      await tester.pump(const Duration(milliseconds: 50));

      // Heart icon is back to unfilled
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('14. Queue, Full Player, and Hide actions execute and dismiss menu cleanly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const SizedBox(
          width: 480,
          height: 125,
          child: MiniPlayerStandaloneApp(windowId: 'test_actions_window'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Add to Queue action
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Add to Queue'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Add to Queue'), findsNothing);

      // 2. Open Queue action
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Open Queue'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Open Queue'), findsNothing);

      // 3. Open Full Player action
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Open Full Player'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Open Full Player'), findsNothing);

      // 4. Hide Mini Player action
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Hide Mini Player'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Hide Mini Player'), findsNothing);

      expect(tester.takeException(), isNull);
    });
  });
}

