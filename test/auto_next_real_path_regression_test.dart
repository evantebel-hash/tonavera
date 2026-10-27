import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mymusic/models/song_model.dart';
import 'package:mymusic/models/youtube_model.dart';
import 'package:mymusic/providers/player_provider.dart';
import 'package:mymusic/services/metadata/metadata_model.dart';
import 'package:mymusic/services/metadata/spotify_resolver_service.dart';
import 'package:mymusic/services/youtube/youtube_resolver.dart';

import 'fakes/fake_just_audio_platform.dart';

/// Regression tests for the reported bug: auto-next did not fire on
/// Spotify -> YouTube Music, YouTube Music -> local, and local -> Spotify,
/// while manual Next kept working.
///
/// Unlike the existing suites (which go through `playSong(isTest: true)` and
/// therefore never attach a source, never confirm playback on the real path,
/// and never run the completion guards against a real engine event), these
/// tests run the FULL production chain for every transition:
///
///   Track selesai -> completion event -> completion guards -> next track
///   selection -> source prep -> player.play() -> playback confirmation
///
/// using a Windows-faithful in-memory audio engine
/// (see fakes/fake_just_audio_platform.dart). Assertions only rely on
/// observable behavior: current track, attached source, engine play requests,
/// playing state.

const Duration kMedia = Duration(seconds: 180);
const Duration kNearEnd = Duration(seconds: 179);

late Directory tempDir;

SongModel makeLocalSong(int id, String title) {
  final path = '${tempDir.path}${Platform.pathSeparator}local_$id.mp3';
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

SongModel makeYouTubeSong(String videoId, String title) {
  return SongModel.fromYouTubeVideo(YouTubeVideo(
    videoId: videoId,
    title: title,
    channelName: 'Channel $title',
    durationSeconds: kMedia.inSeconds,
  ));
}

/// A track as it enters the queue from Spotify playback (SpotifyResolverService
/// maps every playable Spotify track to a YouTube-backed SongModel).
SongModel makeSpotifyResolvedSong(String videoId, String title) {
  final resolver = SpotifyResolverService();
  const metadata = MusicMetadataResult(
    title: 'Spotify Title',
    artist: 'Spotify Artist',
    duration: 180,
  );
  final match = YouTubeVideo(
    videoId: videoId,
    title: title,
    channelName: 'Channel $title',
    durationSeconds: kMedia.inSeconds,
  );
  return resolver.buildPlayableSong(metadata, match);
}

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

/// Drives the live engine to the duration boundary and emits the natural
/// end-of-media sequence (Windows MediaEnded).
Future<void> finishCurrentTrack(FakeJustAudioPlatform platform) async {
  final fake = platform.livePlayer;
  fake.emitPosition(kNearEnd);
  // Let the position ticker publish the near-end position to the provider
  // (feeds _maxObservedPositionMs / the completion boundary check).
  await pump(const Duration(milliseconds: 350));
  fake.emitNaturalEnd();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // just_audio caches the platform instance globally on first use, so the
  // fake must be installed before the first AudioPlayer touches the platform.
  final platform = FakeJustAudioPlatform(defaultDuration: kMedia);
  JustAudioPlatform.instance = platform;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('mymusic_autonext_');
  });

  tearDownAll(() async {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  late PlayerProvider provider;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    platform.hangLoads = false;
    platform.failLoadsRemaining = 0;
    platform.players.clear();
    YouTubeResolver.debugResolveOverride =
        (videoIdOrUrl) async => 'https://stream.fake.test/watch?v=$videoIdOrUrl';
    provider = PlayerProvider();
  });

  tearDown(() async {
    YouTubeResolver.debugResolveOverride = null;
    provider.dispose();
    await pump(const Duration(milliseconds: 50));
  });

  /// Starts [song] through the real (non-test) playSong path and asserts the
  /// engine actually attached the source and started playback.
  Future<FakeAudioPlayerPlatform> startReal(
    SongModel song,
    List<SongModel> queue, {
    int index = 0,
  }) async {
    provider.setQueueForTest(queue, initialIndex: index);
    await provider.playSong(song, playlist: queue);
    final attached = await waitFor(() {
      final live = platform.livePlayers;
      return live.length == 1 && live.single.loadRequests > 0;
    });
    expect(attached, isTrue,
        reason: 'source was never attached during playSong(real path)');
    final fake = platform.livePlayer;
    final played = await waitFor(() => fake.playRequests > 0);
    expect(played, isTrue, reason: 'engine play() was never requested');
    expect(provider.isPlaying, isTrue,
        reason: 'playback was never confirmed after playSong');
    expect(provider.currentIndex, index);
    return fake;
  }

  /// Completes the current track and asserts the queue advanced exactly one
  /// step, the next source got attached, and the engine was asked to play it.
  Future<FakeAudioPlayerPlatform> expectAutoNextAdvance({
    required int fromIndex,
    required int toIndex,
    required String Function(FakeAudioPlayerPlatform attached) sourceCheck,
    String? Function()? songCheck,
  }) async {
    final previous = platform.livePlayer;
    await finishCurrentTrack(platform);

    final advanced = await waitFor(() => provider.currentIndex == toIndex);
    expect(advanced, isTrue,
        reason:
            'auto-next did not advance from index $fromIndex after a genuine '
            'end-of-track event (currentIndex=${provider.currentIndex}, '
            'current=${provider.currentSong?.title})');
    expect(provider.currentIndex, isNot(fromIndex));

    final nextAttached = await waitFor(() {
      final live = platform.livePlayers;
      return live.length == 1 && !identical(live.single, previous);
    });
    expect(nextAttached, isTrue, reason: 'next source was never attached');

    final nextFake = platform.livePlayer;
    expect(nextFake.lastLoadedSource, contains(sourceCheck(nextFake)));
    final played = await waitFor(() => nextFake.playRequests > 0);
    expect(played, isTrue, reason: 'engine was never asked to play the next track');
    expect(nextFake.enginePlaying, isTrue, reason: 'next track is not playing');
    expect(provider.isPlaying, isTrue);

    final title = songCheck?.call();
    if (title != null) {
      expect(provider.currentSong?.title, title);
    }
    return nextFake;
  }

  group('real-path auto-next across sources (reported transitions)', () {
    test('1. local -> local auto-next completes the full handover', () async {
      final localA = makeLocalSong(1, 'Local A');
      final localB = makeLocalSong(2, 'Local B');
      final queue = [localA, localB];

      await startReal(localA, queue);
      await expectAutoNextAdvance(
        fromIndex: 0,
        toIndex: 1,
        sourceCheck: (fake) => 'local_2.mp3',
        songCheck: () => 'Local B',
      );
    });

    test('2. local -> Spotify (resolved YouTube) auto-next fires', () async {
      final localA = makeLocalSong(10, 'Local A');
      final spotify = makeSpotifyResolvedSong('spotify_vid_1', 'Spotify Hit');
      expect(spotify.source, 'youtube');
      final queue = [localA, spotify];

      await startReal(localA, queue);
      await expectAutoNextAdvance(
        fromIndex: 0,
        toIndex: 1,
        sourceCheck: (fake) => 'spotify_vid_1',
        songCheck: () => spotify.title,
      );
    });

    test('3. Spotify/YouTube Music -> YouTube Music auto-next fires', () async {
      final outgoing = makeSpotifyResolvedSong('spotify_vid_2', 'Spotify Out');
      final ytm = makeYouTubeSong('ytm_vid_1', 'YT Music Next');
      final queue = [outgoing, ytm];

      await startReal(outgoing, queue);
      await expectAutoNextAdvance(
        fromIndex: 0,
        toIndex: 1,
        sourceCheck: (fake) => 'ytm_vid_1',
        songCheck: () => 'YT Music Next',
      );
    });

    test('4. YouTube Music -> local auto-next fires', () async {
      final ytm = makeYouTubeSong('ytm_vid_2', 'YT Music Out');
      final localB = makeLocalSong(20, 'Local Next');
      final queue = [ytm, localB];

      await startReal(ytm, queue);
      await expectAutoNextAdvance(
        fromIndex: 0,
        toIndex: 1,
        sourceCheck: (fake) => 'local_20.mp3',
        songCheck: () => 'Local Next',
      );
    });

    test('5. Spotify -> local (remaining reported pairing) fires', () async {
      final spotify = makeSpotifyResolvedSong('spotify_vid_3', 'Spotify Out');
      final localB = makeLocalSong(30, 'Local Tail');
      final queue = [spotify, localB];

      await startReal(spotify, queue);
      await expectAutoNextAdvance(
        fromIndex: 0,
        toIndex: 1,
        sourceCheck: (fake) => 'local_30.mp3',
        songCheck: () => 'Local Tail',
      );
    });
  });

  group('completion guards: exactly-once and stale isolation', () {
    test('duplicate end-of-media events advance exactly once', () async {
      final localA = makeLocalSong(40, 'Local Dup A');
      final localB = makeLocalSong(41, 'Local Dup B');
      final localC = makeLocalSong(42, 'Local Dup C');
      final queue = [localA, localB, localC];

      final fake = await startReal(localA, queue);
      fake.emitPosition(kNearEnd);
      await pump(const Duration(milliseconds: 350));
      fake.emitNaturalEnd();
      // Replayed broadcast from the same source, delivered while the next
      // transition is in flight.
      fake.emitNaturalEnd();

      final advanced = await waitFor(() => provider.currentIndex == 1);
      expect(advanced, isTrue, reason: 'first completion must advance');
      await pump(const Duration(milliseconds: 400));
      expect(provider.currentIndex, 1,
          reason: 'duplicate completion advanced the queue twice');
      expect(provider.currentSong?.title, 'Local Dup B');
      // The original (disposed) engine may still deliver queued events; no
      // further transition may happen afterwards.
      await pump(const Duration(milliseconds: 300));
      expect(provider.currentIndex, 1);
    });

    test('stale completed replay at position 0 is rejected, no skip', () async {
      final localA = makeLocalSong(50, 'Local Stale A');
      final localB = makeLocalSong(51, 'Local Stale B');
      final queue = [localA, localB];

      await startReal(localA, queue);
      await pump(const Duration(milliseconds: 200));

      // A completion attributed to the active session but with no position
      // evidence (unstarted track) must never advance the queue.
      platform.livePlayer.emitCompletedAt(Duration.zero);
      await pump(const Duration(milliseconds: 400));

      expect(provider.currentIndex, 0,
          reason: 'premature completed event skipped the current track');
      expect(provider.currentSong?.title, 'Local Stale A');
      expect(provider.isPlaying, isTrue);
    });

    test('mid-track failure does not skip the queued track', () async {
      final localA = makeLocalSong(60, 'Local Fail A');
      final localB = makeLocalSong(61, 'Local Fail B');
      final queue = [localA, localB];

      await startReal(localA, queue);
      platform.livePlayer.emitPosition(const Duration(seconds: 10));
      await pump(const Duration(milliseconds: 350));
      platform.livePlayer.emitEndFailure(message: 'mid-track media failure');
      await pump(const Duration(milliseconds: 400));

      expect(provider.currentIndex, 0,
          reason: 'a mid-track failure must not skip a valid queued track');
      expect(provider.currentSong?.title, 'Local Fail A');
    });
  });

  group('failure and manual recovery paths', () {
    test('failure at end of media (MediaFailed) advances once', () async {
      final localA = makeLocalSong(70, 'Local EndFail A');
      final localB = makeLocalSong(71, 'Local EndFail B');
      final queue = [localA, localB];

      await startReal(localA, queue);
      final fake = platform.livePlayer;
      fake.emitPosition(kNearEnd);
      await pump(const Duration(milliseconds: 350));
      fake.emitEndFailure(message: 'network stream tore down at end');
      await pump(const Duration(milliseconds: 400));

      expect(provider.currentIndex, 1,
          reason: 'end-of-media failure must advance the queue');
      final nextFake = await waitFor(() {
        final live = platform.livePlayers;
        return live.length == 1 && !identical(live.single, fake);
      });
      expect(nextFake, isTrue, reason: 'next source never attached');
      final played = await waitFor(() => platform.livePlayer.playRequests > 0);
      expect(played, isTrue, reason: 'next track never started');
      expect(provider.isPlaying, isTrue);
    });

    test('source-load failure auto-skips instead of stalling', () async {
      final localA = makeLocalSong(80, 'Local Skip A');
      final localB = makeLocalSong(81, 'Local Skip B');
      final localC = makeLocalSong(82, 'Local Skip C');
      final queue = [localA, localB, localC];

      await startReal(localA, queue);
      // The next source (B) fails to open; the one after (C) is fine.
      platform.failLoadsRemaining = 1;
      await finishCurrentTrack(platform);

      final advanced = await waitFor(() => provider.currentIndex == 2,
          timeout: const Duration(seconds: 6));
      expect(advanced, isTrue,
          reason: 'a failing source must not stall the queue '
              '(currentIndex=${provider.currentIndex})');
      expect(provider.currentSong?.title, 'Local Skip C');
      final played = await waitFor(() => platform.livePlayer.playRequests > 0);
      expect(played, isTrue);
      expect(provider.isPlaying, isTrue);
    });

    test('manual Next still advances and plays through the real path', () async {
      final localA = makeLocalSong(90, 'Local Manual A');
      final localB = makeLocalSong(91, 'Local Manual B');
      final queue = [localA, localB];

      await startReal(localA, queue);
      final previous = platform.livePlayer;
      await provider.next();
      await pump();

      expect(provider.currentIndex, 1);
      expect(provider.currentSong?.title, 'Local Manual B');
      final nextAttached = await waitFor(() {
        final live = platform.livePlayers;
        return live.length == 1 && !identical(live.single, previous);
      });
      expect(nextAttached, isTrue);
      final played = await waitFor(() => platform.livePlayer.playRequests > 0);
      expect(played, isTrue);
      expect(provider.isPlaying, isTrue);
    });
  });

  group('crossfade-enabled track end still advances', () {
    test('fade completes and swaps even though Windows defers the play '
        'future until end-of-media', () async {
      provider.setCrossfadeDuration(1); // 1s fade
      final localA = makeLocalSong(130, 'Fade A');
      final localB = makeLocalSong(131, 'Fade B');
      final queue = [localA, localB];

      await startReal(localA, queue);
      final fadePlayer = platform.livePlayer;

      // Enter the crossfade window: remaining (900ms) <= crossfadeDuration
      // (1s) and > 500ms -> _triggerCrossfade starts loading the next track
      // on the incoming (fade) player.
      fadePlayer.emitPosition(const Duration(seconds: 179, milliseconds: 100));

      final incomingStarted =
          await waitFor(() => platform.livePlayers.length == 2);
      expect(incomingStarted, isTrue,
          reason: 'crossfade never began loading the incoming track');

      // The outgoing track reaches its natural end during the fade. That
      // completion is swallowed by design (the crossfade owns the
      // transition), so the FADE ITSELF must complete and swap — if it does
      // not, the queue is stuck forever while manual Next (which cancels the
      // crossfade) keeps working. Pre-fix, the fade never even started:
      // `await incomingPlayer.play()` does not resolve until the incoming
      // track's end-of-media on Windows, blocking the fade timer.
      fadePlayer.emitNaturalEnd();

      final advanced = await waitFor(
        () => provider.currentIndex == 1,
        timeout: const Duration(seconds: 5),
      );
      expect(advanced, isTrue,
          reason: 'crossfade swap never completed — queue stuck at index '
              '${provider.currentIndex} (current=${provider.currentSong?.title})');
      expect(provider.currentSong?.title, 'Fade B');
      expect(provider.isPlaying, isTrue);

      final nextFake = platform.livePlayer;
      expect(nextFake.lastLoadedSource, contains('local_131.mp3'));
      expect(nextFake.enginePlaying, isTrue,
          reason: 'incoming track is not playing after the crossfade swap');
    });
  });
}
