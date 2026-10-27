// Replicates the provider's exact sequence (stop -> setAudioSource -> setSpeed
// -> setVolume -> play fire-and-forget) and logs every just_audio event to
// find who flips playing back to false after play() is issued.
// Run: flutter run -d windows -t tool/play_sequence_probe.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

const wav =
    r'C:\Users\evan\.gemini\antigravity-ide\brain\ba6c2c91-447e-4f6f-8b7a-2e79882ed313\scratch\probe_local.wav';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('probe')))));
  final sw = Stopwatch()..start();

  final session = await AudioSession.instance;
  final configured = session.isConfigured;
  final ok = await session.setActive(true);
  debugPrint('[SEQ] t=${sw.elapsedMilliseconds} setActive=$ok (wasConfigured=$configured)');

  final player = AudioPlayer();
  player.playerEventStream.listen((e) {
    debugPrint('[SEQ] t=${sw.elapsedMilliseconds} playerEvent playing=${e.playing} proc=${e.playbackEvent.processingState} pos=${e.playbackEvent.updatePosition.inMilliseconds}');
  });
  player.playerStateStream.listen((s) {
    debugPrint('[SEQ] t=${sw.elapsedMilliseconds} playerState playing=${s.playing} proc=${s.processingState}');
  });

  await Future<void>.delayed(const Duration(milliseconds: 500));

  debugPrint('[SEQ] t=${sw.elapsedMilliseconds} --- stop() ---');
  await player.stop();
  debugPrint('[SEQ] t=${sw.elapsedMilliseconds} stop() returned; playing=${player.playing}');

  debugPrint('[SEQ] t=${sw.elapsedMilliseconds} --- setFilePath ---');
  await player.setFilePath(wav);
  debugPrint('[SEQ] t=${sw.elapsedMilliseconds} setFilePath done; playing=${player.playing} state=${player.playerState}');

  await player.setSpeed(1.0);
  player.setVolume(0.8);
  debugPrint('[SEQ] t=${sw.elapsedMilliseconds} setSpeed/setVolume done; playing=${player.playing}');

  debugPrint('[SEQ] t=${sw.elapsedMilliseconds} --- issuing play() fire-and-forget ---');
  unawaited(player.play().then(
    (_) => debugPrint('[SEQ] t=${sw.elapsedMilliseconds} play() future completed'),
    onError: (Object e) => debugPrint('[SEQ] t=${sw.elapsedMilliseconds} play() future error: $e'),
  ));
  debugPrint('[SEQ] t=${sw.elapsedMilliseconds} play() issued; playing=${player.playing}');

  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    debugPrint('[SEQ] t=${sw.elapsedMilliseconds} tick playing=${player.playing} proc=${player.processingState} pos=${player.position.inMilliseconds}');
  }

  debugPrint('[SEQ] DONE');
  exit(0);
}
