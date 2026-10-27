// Minimal repro: does just_audio_windows_plus start playback when play() is
// issued without awaiting its (end-of-media-deferred) future?
// Run: flutter run -d windows -t tool/play_fire_and_forget_probe.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

const wav =
    r'C:\Users\evan\.gemini\antigravity-ide\brain\ba6c2c91-447e-4f6f-8b7a-2e79882ed313\scratch\probe_local.wav';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('probe')))));

  final player = AudioPlayer();
  player.playerStateStream.listen((s) {
    debugPrint('[RAW] playerState playing=${s.playing} processing=${s.processingState}');
  });
  player.positionStream.listen((p) {
    if (p.inMilliseconds % 500 < 60) debugPrint('[RAW] pos=${p.inMilliseconds}');
  });
  player.playbackEventStream.listen((e) {
    debugPrint('[RAW] playbackEvent playing=${e.playing} processing=${e.processingState}');
  }, onError: (Object e) => debugPrint('[RAW] playbackEvent error: $e'));

  await Future<void>.delayed(const Duration(seconds: 1));
  debugPrint('[RAW] === setFilePath ===');
  await player.setFilePath(wav);
  debugPrint('[RAW] setFilePath done. state=${player.playerState} playing=${player.playing}');

  await Future<void>.delayed(const Duration(seconds: 1));
  debugPrint('[RAW] === issuing play() (fire and forget) at t=2s ===');
  unawaited(player.play().then(
    (_) => debugPrint('[RAW] play() future completed'),
    onError: (Object e) => debugPrint('[RAW] play() future error: $e'),
  ));
  debugPrint('[RAW] play() issued. playing=${player.playing} state=${player.playerState}');

  await Future<void>.delayed(const Duration(seconds: 4));
  debugPrint('[RAW] === t=6s: state=${player.playerState} pos=${player.position} ===');

  debugPrint('[RAW] === issuing SECOND play() at t=6s ===');
  unawaited(player.play().then(
    (_) => debugPrint('[RAW] play2() future completed'),
    onError: (Object e) => debugPrint('[RAW] play2() future error: $e'),
  ));

  await Future<void>.delayed(const Duration(seconds: 4));
  debugPrint('[RAW] === t=10s: state=${player.playerState} pos=${player.position} ===');
  debugPrint('[RAW] DONE');
  await Future<void>.delayed(const Duration(seconds: 1));
  exit(0);
}
