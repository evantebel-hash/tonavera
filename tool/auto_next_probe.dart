// Auto-next reproduction probe for the TONAVERA bug report:
//   "auto-next tidak berjalan pada Spotify -> YouTube Music,
//    YouTube Music -> lagu lokal, lagu lokal -> Spotify; Next manual OK."
//
// Runs the REAL PlayerProvider (isTest: false) through the three reported
// transition shapes on the real Windows audio engine (just_audio_windows_plus)
// and prints, for every attempt:
//   - every raw playerState (via [LISTEN] / [PLAYER] provider logs)
//   - provider state every 500ms (index / isPlaying / isLoadingAudio / position)
//   - which completion guard rejected the event, if any ([PLAYER] Ignoring ...)
//
// YouTube-shaped sources resolve through YouTubeResolver.debugResolveOverride
// to a localhost HTTP WAV, so the full YouTube branch (resolve -> attach ->
// confirm) runs without yt-dlp/network. No external services are required.
//
// Run: flutter run -d windows -t tool/auto_next_probe.dart

// Diagnostic probe: `print` IS the output channel (terminal), and the
// PlayerProvider test hooks are used deliberately to drive the real path.
// ignore_for_file: avoid_print, invalid_use_of_visible_for_testing_member

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mymusic/models/song_model.dart';
import 'package:mymusic/models/youtube_model.dart';
import 'package:mymusic/providers/player_provider.dart';
import 'package:mymusic/services/youtube/youtube_resolver.dart';

Uint8List buildWav({required double seconds, double frequency = 440}) {
  const sampleRate = 44100;
  final sampleCount = (seconds * sampleRate).floor();
  final dataSize = sampleCount * 2;
  final builder = BytesBuilder();
  final header = ByteData(44);
  void fourCc(int offset, String s) {
    for (var i = 0; i < 4; i++) {
      header.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  fourCc(0, 'RIFF');
  header.setUint32(4, 36 + dataSize, Endian.little);
  fourCc(8, 'WAVE');
  fourCc(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little); // PCM
  header.setUint16(22, 1, Endian.little); // mono
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * 2, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  fourCc(36, 'data');
  header.setUint32(40, dataSize, Endian.little);
  builder.add(header.buffer.asUint8List());

  // Quiet tone so the probe is audible but unobtrusive.
  final samples = Int16List(sampleCount);
  for (var i = 0; i < sampleCount; i++) {
    final t = i / sampleRate;
    final envelope = (t < 0.02 ? t / 0.02 : 1.0) *
        (t > seconds - 0.05 ? (seconds - t) / 0.05 : 1.0);
    samples[i] = (sin2pi(frequency * t) * 8000 * envelope).round();
  }
  builder.add(Uint8List.view(samples.buffer));
  return builder.takeBytes();
}

double sin2pi(double x) {
  final t = x - x.floorToDouble();
  // sin(2*pi*t) without importing dart:math for the hot path.
  const pi2 = 6.283185307179586;
  final a = pi2 * t;
  // Taylor is fine at these amplitudes? Use dart:math instead for accuracy.
  return _sin(a);
}

double _sin(double x) {
  // Range-reduce to [-pi, pi] then use a short Taylor series.
  const pi = 3.141592653589793;
  while (x > pi) {
    x -= 2 * pi;
  }
  while (x < -pi) {
    x += 2 * pi;
  }
  final x2 = x * x;
  return x * (1 - x2 / 6 * (1 - x2 / 20 * (1 - x2 / 42 * (1 - x2 / 72))));
}

SongModel localSong(int id, String title, String path, int seconds) =>
    SongModel(
      id: id,
      artistId: 1,
      title: title,
      duration: seconds,
      audioPath: path,
      filePath: path,
      source: 'local',
    );

SongModel networkSong(String videoId, String title, int seconds) =>
    SongModel.fromYouTubeVideo(YouTubeVideo(
      videoId: videoId,
      title: title,
      channelName: 'probe',
      durationSeconds: seconds,
    ));

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('[PROBE] boot at ${DateTime.now().toIso8601String()}');
  runApp(const MaterialApp(
    home: Scaffold(body: Center(child: Text('auto-next probe running...'))),
  ));

  final temp = await Directory.systemTemp.createTemp('autonext_probe');
  final localA = File('${temp.path}\\localA.wav')
    ..writeAsBytesSync(buildWav(seconds: 6, frequency: 440));
  final localB = File('${temp.path}\\localB.wav')
    ..writeAsBytesSync(buildWav(seconds: 6, frequency: 330));

  // Localhost HTTP server standing in for a YouTube/Spotify network stream:
  // the real YouTube code path runs (resolve -> AudioSource.uri -> WinRT
  // HTTP streaming), only the origin is local, so no yt-dlp/network needed.
  final netBytesA = buildWav(seconds: 6, frequency: 550);
  final netBytesB = buildWav(seconds: 6, frequency: 660);
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    final body = request.uri.path.contains('b') ? netBytesB : netBytesA;
    request.response.headers.contentType = ContentType('audio', 'wav');
    request.response.contentLength = body.length;
    request.response.add(body);
    await request.response.close();
  });
  final baseUrl = 'http://127.0.0.1:${server.port}';
  YouTubeResolver.debugResolveOverride = (videoIdOrUrl) async {
    print('[PROBE] resolver override for $videoIdOrUrl');
    return '$baseUrl/$videoIdOrUrl.wav';
  };
  print('[PROBE] local http origin: $baseUrl');

  final provider = PlayerProvider();

  final summary = <String, String>{};

  Future<void> runScenario(String name, SongModel first,
      SongModel second) async {
    print('\n[PROBE] === scenario "$name" ===');
    final queue = [first, second];
    provider.setQueueForTest(queue, initialIndex: 0);
    try {
      await provider.playSong(first, playlist: queue);
    } catch (e, st) {
      print('[PROBE] playSong threw: $e\n$st');
    }
    print('[PROBE] started "${first.title}" '
        'index=${provider.currentIndex} playing=${provider.isPlaying}');

    final deadline = DateTime.now().add(const Duration(seconds: 25));
    var tick = 0;
    var advanced = false;
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      tick++;
      if (tick % 2 == 0) {
        print('[PROBE] t=${tick ~/ 2}s index=${provider.currentIndex} '
            'playing=${provider.isPlaying} '
            'loading=${provider.isLoadingAudio} '
            'pos=${provider.position} cur="${provider.currentSong?.title}"');
      }
      if (provider.currentIndex == 1 && provider.isPlaying) {
        advanced = true;
        break;
      }
    }
    summary[name] = advanced
        ? 'ADVANCED to "${second.title}"'
        : 'FAILED (index=${provider.currentIndex}, '
            'playing=${provider.isPlaying}, loading=${provider.isLoadingAudio}, '
            'pos=${provider.position})';
    print('[PROBE] result "$name": ${summary[name]}');
    try {
      await provider.stop();
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  // Overall watchdog so a hung platform call can never block exit.
  Timer(const Duration(seconds: 300), () {
    print('[PROBE] WATCHDOG TIMEOUT — dumping state and exiting');
    print('[PROBE] summary so far: $summary');
    exit(2);
  });

  await runScenario(
    'local -> network (approx local -> Spotify)',
    localSong(1, 'localA', localA.path, 6),
    networkSong('net_a', 'netA', 6),
  );
  await runScenario(
    'network -> local (approx YTM -> local)',
    networkSong('net_b', 'netB', 6),
    localSong(2, 'localB', localB.path, 6),
  );
  await runScenario(
    'network -> network (approx Spotify -> YTM)',
    networkSong('net_c', 'netC', 6),
    networkSong('net_d', 'netD', 6),
  );

  // Crossfade-enabled transition: while the fade runs, completion is
  // swallowed by design — the FADE itself must complete and swap to the
  // incoming track (pre-fix it never even started because `await play()`
  // does not resolve until end-of-media on Windows).
  print('\n[PROBE] enabling crossfade (1s) for the next scenario');
  provider.setCrossfadeDuration(1);
  await runScenario(
    'crossfade local -> local (fade owns the end-of-track)',
    localSong(5, 'cfA', localA.path, 6),
    localSong(6, 'cfB', localB.path, 6),
  );
  provider.setCrossfadeDuration(0);
  print('[PROBE] crossfade disabled again');

  // Manual Next control (must always work per the bug report).
  print('\n[PROBE] === manual Next control ===');
  final queue = [
    localSong(3, 'manualA', localA.path, 6),
    localSong(4, 'manualB', localB.path, 6),
  ];
  provider.setQueueForTest(queue, initialIndex: 0);
  await provider.playSong(queue.first, playlist: queue);
  await Future<void>.delayed(const Duration(seconds: 1));
  await provider.next();
  await Future<void>.delayed(const Duration(seconds: 1));
  summary['manual Next'] = provider.currentIndex == 1 && provider.isPlaying
      ? 'WORKS'
      : 'BROKEN (index=${provider.currentIndex})';
  print('[PROBE] result manual Next: ${summary['manual Next']}');

  print('\n[PROBE] ===== SUMMARY =====');
  summary.forEach((k, v) => print('[PROBE] $k => $v'));
  provider.dispose();
  await server.close(force: true);
  exit(0);
}
