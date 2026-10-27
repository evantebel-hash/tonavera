import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mymusic/models/song_model.dart';
import 'package:mymusic/providers/player_provider.dart';

import 'fakes/fake_just_audio_platform.dart';

/// Regression test for the root cause of the TONAVERA report
/// ("auto-next tidak berjalan pada Spotify -> YouTube Music,
/// YouTube Music -> lagu lokal, lagu lokal -> Spotify; Next manual OK"),
/// reproduced on the real Windows engine by `tool/auto_next_probe.dart`
/// scenario 1 and pinned here as a deterministic interleaving.
///
/// Mechanism:
/// just_audio's `AudioPlayer.play()` broadcasts `playing = true`, then awaits
/// `AudioSession.instance` and `setActive(true)` — platform-channel round
/// trips on platforms without the audio_session plugin (Windows) — and only
/// then re-checks the flag (`if (!playing) return;`) before sending the
/// native play request. Windows `Broadcast()` carries the native `playing_`
/// flag, which stays false until that native play request lands; if such a
/// broadcast is delivered inside the round-trip window, `play()` returns
/// WITHOUT ever asking the engine to play. The track then stays silent, no
/// end-of-track event ever fires, and auto-next stalls — while manual Next
/// recovers because by then the audio session is warm and play()'s window
/// has collapsed to microtasks (probe scenarios 2/3 and manual Next all
/// passed for exactly that reason).
///
/// This test runs in its own isolate so `AudioSession` is genuinely cold
/// (first playback of the session), mocks the audio-session channel with a
/// realistic in-flight delay, and broadcasts `playing: false` while that
/// round trip is in flight — the exact production interleaving. Assertions
/// only rely on observable behavior: engine play request received,
/// playback confirmed, track runs to its natural end, queue advances.

const Duration kMedia = Duration(seconds: 180);
const Duration kNearEnd = Duration(seconds: 179);

const MethodChannel _sessionChannel =
    MethodChannel('com.ryanheise.audio_session');

late Directory tempDir;

Future<void> pump([Duration duration = const Duration(milliseconds: 150)]) =>
    Future<void>.delayed(duration);

Future<bool> waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
  Duration step = const Duration(milliseconds: 40),
}) async {
  final watch = Stopwatch()..start();
  while (watch.elapsed < timeout) {
    if (condition()) return true;
    await Future<void>.delayed(step);
  }
  return condition();
}

SongModel _makeLocalSong(Directory dir, int id, String title) {
  final path = '${dir.path}${Platform.pathSeparator}race_$id.mp3';
  File(path).writeAsStringSync('dummy-audio-$id');
  return SongModel(
    id: id,
    artistId: 1,
    title: title,
    duration: kMedia.inSeconds,
    audioPath: path,
    filePath: path,
    source: 'local',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = FakeJustAudioPlatform(defaultDuration: kMedia);
  JustAudioPlatform.instance = platform;

  late PlayerProvider provider;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('mymusic_race_');
  });

  tearDownAll(() async {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    platform.hangLoads = false;
    platform.failLoadsRemaining = 0;
    platform.players.clear();
    provider = PlayerProvider();
  });

  tearDown(() async {
    provider.dispose();
    await pump(const Duration(milliseconds: 50));
  });

  test(
      'first playback start survives an engine playing=false broadcast '
      'racing the audio-session round trips', () async {
    var sessionRoundTrips = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_sessionChannel, (call) async {
      sessionRoundTrips++;
      // While the round trip is in flight, the engine broadcasts its native
      // playing flag — still false, because the native play request has not
      // been sent yet (Windows Broadcast() semantics: `playing_` only turns
      // true when the native play method executes).
      final live = platform.livePlayers;
      if (live.isNotEmpty) {
        live.first.emitPlaying(false);
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
      // No audio_session plugin on this platform: both `getConfiguration`
      // and `setConfiguration` reject on Windows in production.
      return null;
    });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_sessionChannel, null),
    );

    final localA = _makeLocalSong(tempDir, 1, 'Race A');
    final localB = _makeLocalSong(tempDir, 2, 'Race B');
    final queue = [localA, localB];

    provider.setQueueForTest(queue, initialIndex: 0);
    await provider.playSong(localA, playlist: queue);

    final attached = await waitFor(() {
      final live = platform.livePlayers;
      return live.length == 1 && live.single.loadRequests > 0;
    });
    expect(attached, isTrue,
        reason: 'source was never attached during playSong (real path)');

    final fake = platform.livePlayer;
    final played = await waitFor(() => fake.playRequests > 0);
    expect(played, isTrue,
        reason: 'engine play() was never requested: play() aborted at its '
            '`if (!playing) return` guard after an engine playing=false '
            'broadcast raced the audio-session round trips. Playback would '
            'stay silent forever, no end-of-track event would ever fire, and '
            'auto-next would stall (manual Next recovers because the session '
            'is warm by then).');
    expect(fake.enginePlaying, isTrue,
        reason: 'engine is not playing after the play request');
    expect(provider.isPlaying, isTrue,
        reason: 'playback was never confirmed after playSong');
    expect(provider.currentIndex, 0);
    expect(sessionRoundTrips, greaterThan(0),
        reason: 'the audio-session round-trip mock was never exercised — '
            'this test must run first-of-session (own isolate)');

    // The actual observable from the bug report: the track must run to its
    // natural end and auto-advance to the next queue entry.
    fake.emitPosition(kNearEnd);
    await pump(const Duration(milliseconds: 350));
    fake.emitNaturalEnd();

    final advanced = await waitFor(() => provider.currentIndex == 1);
    expect(advanced, isTrue,
        reason: 'auto-next did not advance after a genuine end-of-track '
            'event (currentIndex=${provider.currentIndex})');

    final nextFake = platform.livePlayer;
    final nextPlayed = await waitFor(() => nextFake.playRequests > 0);
    expect(nextPlayed, isTrue,
        reason: 'the next track was never asked to play');
    expect(provider.isPlaying, isTrue);
    expect(provider.currentSong?.title, 'Race B');
  });
}
