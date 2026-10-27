// Diagnostic probe (Windows). Plays a real local WAV to natural completion and
// verifies auto-next into a YouTube track, then YouTube -> local.
// Run: flutter run -d windows -t tool/autonext_probe.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mymusic/models/song_model.dart';
import 'package:mymusic/providers/player_provider.dart';

const wav = r'C:\Users\evan\.gemini\antigravity-ide\brain\ba6c2c91-447e-4f6f-8b7a-2e79882ed313\scratch\probe_local.wav';

SongModel local(int id) => SongModel(
    id: id, artistId: 0, title: 'LOCAL_$id', duration: 4,
    audioPath: wav, filePath: wav, source: 'local');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('probe')))));
  final p = PlayerProvider();
  await Future.delayed(const Duration(seconds: 2));
  final yt = SongModel(
      id: 900001, artistId: 0, title: 'YT_ZOO', duration: 19,
      audioPath: 'jNQXAC9IVRw', source: 'youtube');
  final queue = [local(1), local(2), yt, local(3)];

  final sw = Stopwatch()..start();
  Timer.periodic(const Duration(milliseconds: 500), (_) {
    debugPrint('[PROBE] t=${sw.elapsedMilliseconds} song=${p.currentSong?.title} '
        'idx=${p.currentIndex} isPlaying=${p.isPlaying} pos=${p.position.inMilliseconds} '
        'resolving=${p.isResolvingYouTube} err=${p.lastErrorMessage}');
  });
  unawaited(p.playSong(queue.first, playlist: queue));
  await Future.delayed(const Duration(seconds: 60));
  debugPrint('[PROBE] DONE');
  exit(0);
}
