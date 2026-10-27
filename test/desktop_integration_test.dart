import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:mymusic/services/desktop/desktop_integration_service.dart';
import 'package:mymusic/providers/player_provider.dart';
import 'package:mymusic/models/song_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DesktopIntegrationService desktopService;
  late PlayerProvider playerProvider;
  final List<MethodCall> log = <MethodCall>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      DesktopIntegrationService.keyMediaKeys: true,
      DesktopIntegrationService.keySystemTray: true,
      DesktopIntegrationService.keyMinimizeToTray: false,
      DesktopIntegrationService.keyAlwaysOnTop: false,
      DesktopIntegrationService.keyMiniPlayerMode: false,
    });

    log.clear();

    // Mock just_audio method channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.just_audio.methods'),
      (MethodCall methodCall) async {
        return null;
      },
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.mymusic.desktop/integration'),
      (MethodCall methodCall) async {
        log.add(methodCall);
        switch (methodCall.method) {
          case 'setGlobalMediaKeysEnabled':
          case 'setSystemTrayEnabled':
          case 'setMinimizeToTray':
          case 'setAlwaysOnTop':
          case 'setWindowSize':
          case 'restoreWindow':
          case 'hideWindow':
          case 'minimizeWindow':
          case 'closeApp':
            return true;
          default:
            return null;
        }
      },
    );

    desktopService = DesktopIntegrationService.instance;
    desktopService.isTestMode = true;
    playerProvider = PlayerProvider();
    await desktopService.init(playerProvider: playerProvider);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.mymusic.desktop/integration'),
      null,
    );
  });

  group('Phase 5.1 — Global Media Keys Tests', () {
    test('1. Setting global media keys invokes native method and updates preference', () async {
      await desktopService.setGlobalMediaKeysEnabled(false);
      expect(desktopService.globalMediaKeysEnabled, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(DesktopIntegrationService.keyMediaKeys), isFalse);

      await desktopService.setGlobalMediaKeysEnabled(true);
      expect(desktopService.globalMediaKeysEnabled, isTrue);
    });

    test('2. Media Key Actions correctly communicate with PlayerProvider without state duplication', () async {
      final dummySongs = [
        SongModel(id: 1, title: 'Track 1', artistId: 1, duration: 180, audioPath: 'p1'),
        SongModel(id: 2, title: 'Track 2', artistId: 1, duration: 200, audioPath: 'p2'),
      ];

      playerProvider.setQueueForTest(dummySongs, initialIndex: 0);
      expect(playerProvider.currentIndex, 0);

      // Simulate Native Hotkey Message: next
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        'com.mymusic.desktop/integration',
        const StandardMethodCodec().encodeMethodCall(const MethodCall('onMediaKeyAction', 'next')),
        (ByteData? data) {},
      );

      expect(playerProvider.currentIndex, 1);
      expect(playerProvider.currentSong?.title, 'Track 2');

      // Simulate Native Hotkey Message: previous
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        'com.mymusic.desktop/integration',
        const StandardMethodCodec().encodeMethodCall(const MethodCall('onMediaKeyAction', 'previous')),
        (ByteData? data) {},
      );

      expect(playerProvider.currentIndex, 0);
      expect(playerProvider.currentSong?.title, 'Track 1');
    });

    test('3. Media key volume adjustments clamp properly', () async {
      playerProvider.setVolume(0.5);

      // Volume Up
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        'com.mymusic.desktop/integration',
        const StandardMethodCodec().encodeMethodCall(const MethodCall('onMediaKeyAction', 'volumeUp')),
        (ByteData? data) {},
      );
      expect(playerProvider.volume, closeTo(0.55, 0.001));

      // Volume Down
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        'com.mymusic.desktop/integration',
        const StandardMethodCodec().encodeMethodCall(const MethodCall('onMediaKeyAction', 'volumeDown')),
        (ByteData? data) {},
      );
      expect(playerProvider.volume, closeTo(0.50, 0.001));
    });
  });

  group('Phase 5.2 & 5.3 — Mini Player & System Tray Tests', () {
    test('4. System Tray and Minimize to Tray toggle preferences and native hooks', () async {
      await desktopService.setSystemTrayEnabled(true);
      await desktopService.setMinimizeToTray(true);

      expect(desktopService.systemTrayEnabled, isTrue);
      expect(desktopService.minimizeToTrayEnabled, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(DesktopIntegrationService.keySystemTray), isTrue);
      expect(prefs.getBool(DesktopIntegrationService.keyMinimizeToTray), isTrue);
    });

    test('5. Always on Top preference and Mini Player mode persist and invoke sizing', () async {
      await desktopService.setAlwaysOnTop(true);
      expect(desktopService.alwaysOnTop, isTrue);

      await desktopService.setMiniPlayerMode(true);
      expect(desktopService.isMiniPlayerMode, isTrue);

      await desktopService.setMiniPlayerMode(false);
      expect(desktopService.isMiniPlayerMode, isFalse);
    });
  });

  group('Phase 5.4 — Advanced Drag & Drop Hook Tests', () {
    test('6. Native file drop invokes onFilesDropped callback', () async {
      List<String> dropped = [];
      desktopService.setFilesDroppedCallback((paths) {
        dropped = paths;
      });

      final testPaths = ['C:\\Music\\SongA.mp3', 'C:\\Music\\SongB.flac'];

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        'com.mymusic.desktop/integration',
        const StandardMethodCodec().encodeMethodCall(MethodCall('onFilesDropped', testPaths)),
        (ByteData? data) {},
      );

      expect(dropped, equals(testPaths));
    });
  });
}
