import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mymusic/models/song_model.dart';
import 'package:mymusic/models/youtube_model.dart';
import 'package:mymusic/providers/player_provider.dart';
import 'package:mymusic/services/metadata/metadata_model.dart';
import 'package:mymusic/services/metadata/spotify_resolver_service.dart';

/// Phase 5I regression tests for the unified cross-provider auto-next stall.
///
/// Reported complaints (Windows):
///  Issue A: a YouTube Music track finishes naturally but the next queued
///           track never starts; manual Next recovers.
///  Issue B: a Spotify track finishes and the queued YouTube Music track does
///           not reliably start on its own.
///
/// Root cause addressed here: on Windows a network source that tears down at
/// end-of-media reports a native playback failure (MediaFailed -> errorStream /
/// idle state) instead of ProcessingState.completed. The app had no error
/// listener, so the queue silently stalled and only manual Next (which resets
/// failure state and replays the next track) recovered. These tests drive the
/// real handler paths through `emitPlaybackErrorForTest` /
/// `emitPlayerStateForTest`.

SongModel makeYtSong(int id, String title, {String videoId = 'vid_ok'}) {
  return SongModel(
    id: id,
    artistId: 1,
    title: title,
    duration: 180,
    audioPath: videoId,
    source: 'youtube',
  );
}

SongModel makeLocalSong(int id, String title) {
  return SongModel(
    id: id,
    artistId: 1,
    title: title,
    duration: 180,
    audioPath: 'C:\\music\\$title.mp3',
    filePath: 'C:\\music\\$title.mp3',
    source: 'local',
  );
}

/// Spotify link resolved to a YouTube source, as production queues do.
SongModel makeSpotifySong(String title) {
  final resolver = SpotifyResolverService();
  return resolver.buildPlayableSong(
    MusicMetadataResult(title: title, artist: 'Artist', duration: 0),
    YouTubeVideo(
      videoId: 'vid_${title.hashCode}',
      title: title,
      channelName: 'Artist',
      durationSeconds: 0,
    ),
  );
}

Future<void> drainAutoNext(PlayerProvider player) async {
  var guard = 0;
  while (player.isHandlingAutoNext && guard++ < 500) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Issue A: YouTube Music -> YouTube Music auto-next', () {
    test('Playback failure at the end of a confirmed track auto-advances to the next track', () async {
      final player = PlayerProvider();
      final trackA = makeYtSong(1, 'YTM Track A', videoId: 'vid_a');
      final trackB = makeYtSong(2, 'YTM Track B', videoId: 'vid_b');
      player.setQueueForTest([trackA, trackB], initialIndex: 0);

      await player.playSong(trackA, playlist: player.queue, isTest: true);
      expect(player.isPlaying, isTrue);

      // Track A was confirmed and is now at its duration boundary when the
      // platform reports a failure instead of ProcessingState.completed.
      player.setProgressForTest(
        position: const Duration(seconds: 119),
        duration: const Duration(seconds: 120),
      );
      player.emitPlaybackErrorForTest(
        code: 1,
        message: 'The network connection was aborted.',
      );
      await drainAutoNext(player);

      expect(player.currentIndex, 1);
      expect(player.currentSong?.title, 'YTM Track B');
      expect(player.isPlaying, isTrue);
    });

    test('Genuine ProcessingState.completed still advances YouTube Music -> YouTube Music', () async {
      final player = PlayerProvider();
      final trackA = makeYtSong(1, 'YTM Track A', videoId: 'vid_a');
      final trackB = makeYtSong(2, 'YTM Track B', videoId: 'vid_b');
      player.setQueueForTest([trackA, trackB], initialIndex: 0);

      await player.playSong(trackA, playlist: player.queue, isTest: true);
      expect(player.isPlaying, isTrue);

      // Genuine completion evidence: the track played to its end (position
      // near duration). A zero-position completion is the stale signal the
      // gates must keep rejecting.
      player.setProgressForTest(
        position: const Duration(seconds: 119),
        duration: const Duration(seconds: 120),
      );
      player.emitPlayerStateForTest(PlayerState(false, ProcessingState.completed));
      await drainAutoNext(player);

      expect(player.currentIndex, 1);
      expect(player.currentSong?.title, 'YTM Track B');
      expect(player.isPlaying, isTrue);
    });
  });

  group('Issue B: Spotify -> YouTube Music auto-next', () {
    test('Playback failure at the end of a confirmed Spotify track auto-advances to the queued YouTube Music track', () async {
      final player = PlayerProvider();
      final spotifyTrack = makeSpotifySong('Spotify Track');
      final ytmTrack = makeYtSong(2, 'YouTube Music Track', videoId: 'vid_b');
      player.setQueueForTest([spotifyTrack, ytmTrack], initialIndex: 0);

      await player.playSong(spotifyTrack, playlist: player.queue, isTest: true);
      expect(player.isPlaying, isTrue);

      player.setProgressForTest(
        position: const Duration(seconds: 119),
        duration: const Duration(seconds: 120),
      );
      player.emitPlaybackErrorForTest(
        code: 1,
        message: 'Source connection closed unexpectedly',
      );
      await drainAutoNext(player);

      expect(player.currentIndex, 1);
      expect(player.currentSong?.title, 'YouTube Music Track');
      expect(player.isPlaying, isTrue);
    });

    test('Late failure from the previous source cannot skip a newly selected but unconfirmed track', () async {
      final player = PlayerProvider();
      final spotifyTrack = makeSpotifySong('Spotify Track');
      final ytmTrack = makeYtSong(2, 'YouTube Music Track', videoId: 'vid_b');
      final localTrack = makeLocalSong(3, 'Local Track');
      player.setQueueForTest([spotifyTrack, ytmTrack, localTrack], initialIndex: 0);

      await player.playSong(spotifyTrack, playlist: player.queue, isTest: true);
      expect(player.isPlaying, isTrue);

      // Select the YouTube Music track through the real (non-test) path with a
      // resolution failure: session active, loading gate cleared, playback
      // NEVER confirmed — the reported "source never attached" window.
      await player.playSong(ytmTrack, playlist: player.queue);
      expect(player.lastErrorMessage, isNotNull);
      expect(player.isLoadingSource, isFalse);
      expect(player.currentIndex, 1);

      // The previous source's error arrives late.
      player.emitPlaybackErrorForTest(code: 1, message: 'stale failure');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(player.isHandlingAutoNext, isFalse);
      expect(player.currentIndex, 1);
      expect(player.currentSong?.title, 'YouTube Music Track');
    });
  });

  group('Failure handling must not skip tracks without evidence', () {
    test('Mid-track failure is reported distinctly and does not advance the queue', () async {
      final player = PlayerProvider();
      final trackA = makeYtSong(1, 'YTM Track A', videoId: 'vid_a');
      final trackB = makeYtSong(2, 'YTM Track B', videoId: 'vid_b');
      player.setQueueForTest([trackA, trackB], initialIndex: 0);

      await player.playSong(trackA, playlist: player.queue, isTest: true);
      player.setProgressForTest(
        position: const Duration(seconds: 10),
        duration: const Duration(seconds: 120),
      );
      player.emitPlaybackErrorForTest(
        code: 1,
        message: 'Connection dropped at https://media.example/stream?expire=1&sig=SECRET',
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(player.currentIndex, 0);
      expect(player.isHandlingAutoNext, isFalse);
      expect(player.lastErrorMessage, isNotNull);
      // Secrets/query strings must never reach logs or UI state.
      expect(player.lastErrorMessage, isNot(contains('SECRET')));
      expect(player.lastErrorMessage, isNot(contains('?')));
    });

    test('Duplicate and idle-state failure notifications advance exactly once', () async {
      final player = PlayerProvider();
      final trackA = makeYtSong(1, 'YTM Track A', videoId: 'vid_a');
      final trackB = makeYtSong(2, 'YTM Track B', videoId: 'vid_b');
      player.setQueueForTest([trackA, trackB], initialIndex: 0);

      await player.playSong(trackA, playlist: player.queue, isTest: true);
      player.setProgressForTest(
        position: const Duration(seconds: 119),
        duration: const Duration(seconds: 120),
      );

      player.emitPlaybackErrorForTest(code: 1, message: 'failure at end');
      await drainAutoNext(player);
      expect(player.currentIndex, 1);

      // The platform also emits the idle PlayerState for the same failure,
      // and a repeated broadcast may follow once the next session confirmed
      // (its position was zeroed by the transition, like production stop()).
      player.emitPlayerStateForTest(PlayerState(false, ProcessingState.idle));
      player.setProgressForTest(position: Duration.zero, duration: const Duration(seconds: 120));
      player.emitPlaybackErrorForTest(code: 1, message: 'failure repeat');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(player.currentIndex, 1);
      expect(player.currentSong?.title, 'YTM Track B');
      expect(player.isHandlingAutoNext, isFalse);
    });

    test('Failure observed during source loading is rejected (transition owner handles it)', () async {
      final player = PlayerProvider();
      final trackA = makeYtSong(1, 'YTM Track A', videoId: 'vid_a');
      final trackB = makeYtSong(2, 'YTM Track B', videoId: 'vid_b');
      player.setQueueForTest([trackA, trackB], initialIndex: 0);

      await player.playSong(trackA, playlist: player.queue, isTest: true);
      player.setProgressForTest(
        position: const Duration(seconds: 119),
        duration: const Duration(seconds: 120),
      );

      player.setLoadingForTest(true);
      player.emitPlaybackErrorForTest(code: 1, message: 'failure during load');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      player.setLoadingForTest(false);

      expect(player.currentIndex, 0);
      expect(player.isHandlingAutoNext, isFalse);
    });

    test('Failure at end of a single-track queue stops cleanly without advancing or crashing', () async {
      final player = PlayerProvider();
      final trackA = makeYtSong(1, 'YTM Track A', videoId: 'vid_a');
      player.setQueueForTest([trackA], initialIndex: 0);

      await player.playSong(trackA, playlist: player.queue, isTest: true);
      player.setProgressForTest(
        position: const Duration(seconds: 119),
        duration: const Duration(seconds: 120),
      );

      player.emitPlaybackErrorForTest(code: 1, message: 'failure at end');
      await drainAutoNext(player);

      expect(player.currentIndex, 0);
      expect(player.isHandlingAutoNext, isFalse);
    });
  });

  group('Preserved cross-provider behavior', () {
    test('Local -> YouTube Music auto-next still works with the failure listener installed', () async {
      final player = PlayerProvider();
      final localTrack = makeLocalSong(1, 'Local Track');
      final ytmTrack = makeYtSong(2, 'YouTube Music Track', videoId: 'vid_b');
      player.setQueueForTest([localTrack, ytmTrack], initialIndex: 0);

      await player.playSong(localTrack, playlist: player.queue, isTest: true);
      expect(player.isPlaying, isTrue);

      // Genuine completion evidence: the track played to its end.
      player.setProgressForTest(
        position: const Duration(seconds: 119),
        duration: const Duration(seconds: 120),
      );
      player.emitPlayerStateForTest(PlayerState(false, ProcessingState.completed));
      await drainAutoNext(player);

      expect(player.currentIndex, 1);
      expect(player.currentSong?.title, 'YouTube Music Track');
      expect(player.isPlaying, isTrue);
    });
  });
}
