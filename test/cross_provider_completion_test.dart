import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mymusic/models/song_model.dart';
import 'package:mymusic/models/youtube_model.dart';
import 'package:mymusic/providers/player_provider.dart';
import 'package:mymusic/services/metadata/metadata_model.dart';
import 'package:mymusic/services/metadata/spotify_resolver_service.dart';

/// Regression tests for cross-provider auto-next completion attribution.
///
/// Reported bug (Windows): Spotify track -> YouTube Music track -> local track.
/// The YouTube Music track was selected (session N) but a `ProcessingState.completed`
/// event arrived before its source was ever attached / playback confirmed, and was
/// mis-attributed to session N (the handler read `_activeSessionId`/`_currentSong`
/// at delivery time). That triggered auto-next and immediately skipped the
/// YouTube Music track to the local track.
///
/// Fix under test: a completed event is only accepted for the session whose
/// playback was confirmed (`_playbackConfirmedSessionId`). Events arriving while
/// the active session has no confirmed playback belong to the previous session's
/// source and must be ignored.

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

/// YouTube Music track. With an empty [videoId] the Windows resolver throws
/// immediately (offline, no network) before SourceAttached, which reproduces the
/// reported "source never attached" window through the real playSong path.
SongModel makeYtSong(int id, String title, {String videoId = ''}) {
  return SongModel(
    id: id,
    artistId: 1,
    title: title,
    duration: 180,
    audioPath: videoId,
    source: 'youtube',
  );
}

/// Spotify link resolved to a YouTube source (source == 'youtube'), duration 180.
SongModel makeSpotifySong() {
  final resolver = SpotifyResolverService();
  return resolver.buildPlayableSong(
    const MusicMetadataResult(title: 'Spotify Track', artist: 'Artist', duration: 180),
    YouTubeVideo(
      videoId: 'vid_spotify_1',
      title: 'Spotify Track',
      channelName: 'Artist',
      durationSeconds: 180,
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

  group('Cross-provider completion attribution (Spotify -> YouTube Music -> local)', () {
    test(
        'Regression: stale completed for an unconfirmed session must not skip the YouTube Music track',
        () async {
      final player = PlayerProvider();
      final spotifySong = makeSpotifySong();
      final ytmSong = makeYtSong(2, 'Wake Me up When September Ends');
      final localSong = makeLocalSong(3, 'American Idiot');

      player.setQueueForTest([spotifySong, ytmSong, localSong], initialIndex: 0);

      // 1. Spotify track plays: session 1, playback confirmed.
      await player.playSong(spotifySong, playlist: player.queue, isTest: true);
      expect(player.currentSong?.title, 'Spotify Track');
      expect(player.isPlaying, isTrue);

      // 2. Spotify's genuine completion auto-advances to the YouTube Music track
      //    (session 2, confirmed) via the real completion-handler path.
      //    A genuine completion carries position evidence: the track played to
      //    its end (position near duration). A zero-position completion is the
      //    stale/phantom signal the gates must keep rejecting (see steps 3-4).
      player.setProgressForTest(
        position: const Duration(seconds: 180),
        duration: const Duration(seconds: 180),
      );
      player.emitPlayerStateForTest(PlayerState(false, ProcessingState.completed));
      await drainAutoNext(player);
      expect(player.currentIndex, 1);
      expect(player.currentSong?.title, 'Wake Me up When September Ends');
      expect(player.isPlaying, isTrue);

      // 3. Reproduce the reported window through the real (non-test) playSong path:
      //    the YouTube Music session is selected, but its source never attaches
      //    (resolution fails before SourceAttached) and playSong's finally clears
      //    the loading gate -> session active, playback NEVER confirmed.
      await player.playSong(ytmSong, playlist: player.queue);
      expect(player.lastErrorMessage, isNotNull); // resolution/source attach failed
      expect(player.isLoadingSource, isFalse); // loading gate already cleared
      expect(player.currentIndex, 1);
      expect(player.currentSong?.title, 'Wake Me up When September Ends');

      // 4. The previous source's stale 'completed' event arrives now (delivered late).
      player.emitPlayerStateForTest(PlayerState(false, ProcessingState.completed));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Must NOT trigger auto-next: playback was never confirmed for this session,
      // so the event belongs to the previous session's source.
      expect(player.isHandlingAutoNext, isFalse);
      expect(player.currentIndex, 1,
          reason: 'YouTube Music track must not be skipped by a stale completion');
      expect(player.currentSong?.title, 'Wake Me up When September Ends');

      // 5. A genuine completion after a confirmed playback still auto-advances to local.
      await player.playSong(ytmSong, playlist: player.queue, isTest: true);
      expect(player.isPlaying, isTrue);
      player.setProgressForTest(
        position: const Duration(seconds: 180),
        duration: const Duration(seconds: 180),
      );
      player.emitPlayerStateForTest(PlayerState(false, ProcessingState.completed));
      await drainAutoNext(player);
      expect(player.currentIndex, 2);
      expect(player.currentSong?.title, 'American Idiot');
    });

    test('Genuine completion after confirmed playback still auto-advances local -> YouTube Music', () async {
      final player = PlayerProvider();
      final localSong = makeLocalSong(1, 'Local Track 1');
      final ytmSong = makeYtSong(2, 'YouTube Music Track', videoId: 'vid_ok');

      player.setQueueForTest([localSong, ytmSong], initialIndex: 0);

      await player.playSong(localSong, playlist: player.queue, isTest: true);
      expect(player.isPlaying, isTrue);

      // Genuine completion evidence: the track played to its end.
      player.setProgressForTest(
        position: const Duration(seconds: 180),
        duration: const Duration(seconds: 180),
      );
      player.emitPlayerStateForTest(PlayerState(false, ProcessingState.completed));
      await drainAutoNext(player);

      expect(player.currentIndex, 1);
      expect(player.currentSong?.isYouTube, isTrue);
      expect(player.currentSong?.title, 'YouTube Music Track');
      expect(player.isPlaying, isTrue);
    });

    test('Genuine completion after confirmed playback still auto-advances local -> Spotify', () async {
      final player = PlayerProvider();
      final localSong = makeLocalSong(1, 'Local Track 1');
      final spotifySong = makeSpotifySong();

      player.setQueueForTest([localSong, spotifySong], initialIndex: 0);

      await player.playSong(localSong, playlist: player.queue, isTest: true);
      expect(player.isPlaying, isTrue);

      // Genuine completion evidence: the track played to its end.
      player.setProgressForTest(
        position: const Duration(seconds: 180),
        duration: const Duration(seconds: 180),
      );
      player.emitPlayerStateForTest(PlayerState(false, ProcessingState.completed));
      await drainAutoNext(player);

      expect(player.currentIndex, 1);
      expect(player.currentSong?.title, 'Spotify Track');
      expect(player.currentSong?.isYouTube, isTrue);
      expect(player.isPlaying, isTrue);
    });

    test('Spotify -> YouTube Music auto-next still works via a genuine completion (no phantom involved)', () async {
      final player = PlayerProvider();
      final spotifySong = makeSpotifySong();
      final ytmSong = makeYtSong(2, 'YouTube Music Track', videoId: 'vid_ok');

      player.setQueueForTest([spotifySong, ytmSong], initialIndex: 0);

      await player.playSong(spotifySong, playlist: player.queue, isTest: true);
      expect(player.isPlaying, isTrue);

      // Genuine completion evidence: the track played to its end.
      player.setProgressForTest(
        position: const Duration(seconds: 180),
        duration: const Duration(seconds: 180),
      );
      player.emitPlayerStateForTest(PlayerState(false, ProcessingState.completed));
      await drainAutoNext(player);

      expect(player.currentIndex, 1);
      expect(player.currentSong?.title, 'YouTube Music Track');
      expect(player.currentSong?.isYouTube, isTrue);
      expect(player.isPlaying, isTrue);
    });
  });
}
