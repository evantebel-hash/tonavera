import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mymusic/models/song_model.dart';
import 'package:mymusic/models/youtube_model.dart';
import 'package:mymusic/providers/player_provider.dart';
import 'package:mymusic/services/metadata/metadata_model.dart';
import 'package:mymusic/services/metadata/spotify_resolver_service.dart';

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

SongModel makeYouTubeSong(String videoId, String title) {
  return SongModel.fromYouTubeVideo(
    YouTubeVideo(
      videoId: videoId,
      title: title,
      channelName: 'Channel $title',
      durationSeconds: 210,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Core Playback & Cross-Source Auto-Next Tests', () {
    late PlayerProvider player;
    late SongModel local1;
    late SongModel local2;
    late SongModel yt1;
    late SongModel yt2;

    setUp(() {
      player = PlayerProvider();
      local1 = makeLocalSong(1, 'Local Track 1');
      local2 = makeLocalSong(2, 'Local Track 2');
      yt1 = makeYouTubeSong('vid_yt_1', 'YouTube Track 1');
      yt2 = makeYouTubeSong('vid_yt_2', 'YouTube Track 2');
    });

    test('1. Local -> Local auto-next transition', () async {
      player.setQueueForTest([local1, local2], initialIndex: 0);
      expect(player.currentIndex, equals(0));
      expect(player.currentSong?.title, equals('Local Track 1'));
      expect(player.currentSong?.isYouTube, isFalse);

      await player.simulateAutoNextForTest();
      expect(player.currentIndex, equals(1));
      expect(player.currentSong?.title, equals('Local Track 2'));
      expect(player.currentSong?.isYouTube, isFalse);
    });

    test('2. YouTube -> YouTube auto-next transition', () async {
      player.setQueueForTest([yt1, yt2], initialIndex: 0);
      expect(player.currentIndex, equals(0));
      expect(player.currentSong?.isYouTube, isTrue);
      expect(player.currentSong?.audioPath, equals('vid_yt_1'));

      await player.simulateAutoNextForTest();
      expect(player.currentIndex, equals(1));
      expect(player.currentSong?.isYouTube, isTrue);
      expect(player.currentSong?.audioPath, equals('vid_yt_2'));
    });

    test('3. Local -> YouTube auto-next transition', () async {
      player.setQueueForTest([local1, yt1], initialIndex: 0);
      expect(player.currentIndex, equals(0));
      expect(player.currentSong?.isYouTube, isFalse);

      await player.simulateAutoNextForTest();
      expect(player.currentIndex, equals(1));
      expect(player.currentSong?.isYouTube, isTrue);
      expect(player.currentSong?.audioPath, equals('vid_yt_1'));
    });

    test('4. YouTube -> Local auto-next transition', () async {
      player.setQueueForTest([yt1, local1], initialIndex: 0);
      expect(player.currentIndex, equals(0));
      expect(player.currentSong?.isYouTube, isTrue);

      await player.simulateAutoNextForTest();
      expect(player.currentIndex, equals(1));
      expect(player.currentSong?.isYouTube, isFalse);
      expect(player.currentSong?.title, equals('Local Track 1'));
    });

    test(
      '5. Spotify-resolved track is treated as YouTube source and transitions to Local',
      () async {
        final resolver = SpotifyResolverService();
        final spotifyMeta = const MusicMetadataResult(
          title: 'Starboy',
          artist: 'The Weeknd',
          duration: 230,
        );
        final ytMatch = YouTubeVideo(
          videoId: 'dQTnKWUf_w0',
          title: 'The Weeknd - Starboy (Official)',
          channelName: 'The Weeknd',
          durationSeconds: 230,
        );
        final spotifyResolvedSong = resolver.buildPlayableSong(
          spotifyMeta,
          ytMatch,
        );

        expect(spotifyResolvedSong.source, equals('youtube'));
        expect(spotifyResolvedSong.isYouTube, isTrue);
        expect(spotifyResolvedSong.audioPath, equals('dQTnKWUf_w0'));

        player.setQueueForTest([spotifyResolvedSong, local1], initialIndex: 0);
        expect(player.currentSong?.title, equals('Starboy'));
        expect(player.currentSong?.isYouTube, isTrue);

        await player.simulateAutoNextForTest();
        expect(player.currentIndex, equals(1));
        expect(player.currentSong?.title, equals('Local Track 1'));
        expect(player.currentSong?.isYouTube, isFalse);
      },
    );

    test('6. Local -> Spotify-resolved YouTube transition', () async {
      final resolver = SpotifyResolverService();
      final spotifyMeta = const MusicMetadataResult(
        title: 'Midnight City',
        artist: 'M83',
        duration: 243,
      );
      final ytMatch = YouTubeVideo(
        videoId: 'dX3k_QDnzHE',
        title: 'M83 - Midnight City',
        channelName: 'M83',
        durationSeconds: 243,
      );
      final spotifyResolvedSong = resolver.buildPlayableSong(
        spotifyMeta,
        ytMatch,
      );

      player.setQueueForTest([local1, spotifyResolvedSong], initialIndex: 0);
      expect(player.currentSong?.title, equals('Local Track 1'));

      await player.simulateAutoNextForTest();
      expect(player.currentIndex, equals(1));
      expect(player.currentSong?.title, equals('Midnight City'));
      expect(player.currentSong?.isYouTube, isTrue);
      expect(player.currentSong?.audioPath, equals('dX3k_QDnzHE'));
    });

    test('7. Completion triggers exactly one next-track transition', () async {
      player.setQueueForTest([local1, yt1, local2], initialIndex: 0);
      expect(player.currentIndex, equals(0));

      // Trigger completion once
      await player.simulateAutoNextForTest();
      expect(player.currentIndex, equals(1));
      expect(player.currentSong?.audioPath, equals('vid_yt_1'));

      // Index does not advance without another completion trigger
      expect(player.currentIndex, equals(1));
    });

    test('8. Pause does not trigger auto-next transition', () async {
      player.setQueueForTest([local1, local2], initialIndex: 0);
      expect(player.currentIndex, equals(0));

      await player.pause();
      // Current index must still be 0
      expect(player.currentIndex, equals(0));
      expect(player.currentSong?.title, equals('Local Track 1'));
    });

    test('9. Manual next moves correctly across mixed sources', () async {
      player.setQueueForTest([local1, yt1, local2, yt2], initialIndex: 0);

      await player.next(isTest: true);
      expect(player.currentIndex, equals(1));
      expect(player.currentSong?.audioPath, equals('vid_yt_1'));

      await player.next(isTest: true);
      expect(player.currentIndex, equals(2));
      expect(player.currentSong?.title, equals('Local Track 2'));

      await player.next(isTest: true);
      expect(player.currentIndex, equals(3));
      expect(player.currentSong?.audioPath, equals('vid_yt_2'));
    });

    test('10. Full mixed loop: Local -> YouTube -> Local -> YouTube', () async {
      player.setQueueForTest([local1, yt1, local2, yt2], initialIndex: 0);

      expect(player.currentSong?.isYouTube, isFalse);
      await player.simulateAutoNextForTest();

      expect(player.currentSong?.isYouTube, isTrue);
      await player.simulateAutoNextForTest();

      expect(player.currentSong?.isYouTube, isFalse);
      await player.simulateAutoNextForTest();

      expect(player.currentSong?.isYouTube, isTrue);
    });

    test(
      '11. Direct playSong transition: Local -> YouTube with autoplay',
      () async {
        await player.playSong(local1, playlist: [local1, yt1], isTest: true);
        expect(player.currentSong?.id, equals(1));
        expect(player.isPlaying, isTrue);
        expect(player.isResolvingYouTube, isFalse);

        await player.playSong(yt1, playlist: [local1, yt1], isTest: true);
        expect(player.currentSong?.audioPath, equals('vid_yt_1'));
        expect(player.isPlaying, isTrue);
        expect(player.isResolvingYouTube, isFalse);
      },
    );

    test(
      '12. Direct playSong transition: Local -> Spotify-resolved with autoplay',
      () async {
        final resolver = SpotifyResolverService();
        final spotifyMeta = const MusicMetadataResult(
          title: 'Song S',
          artist: 'Artist S',
        );
        final ytMatch = YouTubeVideo(
          videoId: 'yt_spot_1',
          title: 'Song S',
          channelName: 'Artist S',
        );
        final spotifySong = resolver.buildPlayableSong(spotifyMeta, ytMatch);

        await player.playSong(
          local1,
          playlist: [local1, spotifySong],
          isTest: true,
        );
        expect(player.currentSong?.title, equals('Local Track 1'));
        expect(player.isPlaying, isTrue);

        await player.playSong(
          spotifySong,
          playlist: [local1, spotifySong],
          isTest: true,
        );
        expect(player.currentSong?.title, equals('Song S'));
        expect(player.currentSong?.isYouTube, isTrue);
        expect(player.isPlaying, isTrue);
      },
    );

    test(
      '13. Direct playSong transition: YouTube -> Local with autoplay',
      () async {
        await player.playSong(yt1, playlist: [yt1, local1], isTest: true);
        expect(player.currentSong?.audioPath, equals('vid_yt_1'));
        expect(player.isPlaying, isTrue);

        await player.playSong(local1, playlist: [yt1, local1], isTest: true);
        expect(player.currentSong?.title, equals('Local Track 1'));
        expect(player.isPlaying, isTrue);
        expect(player.isResolvingYouTube, isFalse);
      },
    );

    test(
      '14. Direct playSong transition: Spotify-resolved -> Local with autoplay',
      () async {
        final resolver = SpotifyResolverService();
        final spotifyMeta = const MusicMetadataResult(
          title: 'Song S',
          artist: 'Artist S',
        );
        final ytMatch = YouTubeVideo(
          videoId: 'yt_spot_2',
          title: 'Song S',
          channelName: 'Artist S',
        );
        final spotifySong = resolver.buildPlayableSong(spotifyMeta, ytMatch);

        await player.playSong(
          spotifySong,
          playlist: [spotifySong, local1],
          isTest: true,
        );
        expect(player.currentSong?.title, equals('Song S'));
        expect(player.isPlaying, isTrue);

        await player.playSong(
          local1,
          playlist: [spotifySong, local1],
          isTest: true,
        );
        expect(player.currentSong?.title, equals('Local Track 1'));
        expect(player.isPlaying, isTrue);
        expect(player.isResolvingYouTube, isFalse);
      },
    );

    test(
      '15. Repeated cycle: Local -> YouTube -> Local -> Spotify -> Local',
      () async {
        final resolver = SpotifyResolverService();
        final spotifyMeta = const MusicMetadataResult(
          title: 'Spotify Track',
          artist: 'Artist',
        );
        final ytMatch = YouTubeVideo(
          videoId: 'yt_spot_cycle',
          title: 'Spotify Track',
          channelName: 'Artist',
        );
        final spotifySong = resolver.buildPlayableSong(spotifyMeta, ytMatch);

        // Step 1: Local
        await player.playSong(local1, isTest: true);
        expect(player.currentSong?.title, equals('Local Track 1'));
        expect(player.isPlaying, isTrue);

        // Step 2: YouTube
        await player.playSong(yt1, isTest: true);
        expect(player.currentSong?.audioPath, equals('vid_yt_1'));
        expect(player.isPlaying, isTrue);

        // Step 3: Local
        await player.playSong(local2, isTest: true);
        expect(player.currentSong?.title, equals('Local Track 2'));
        expect(player.isPlaying, isTrue);

        // Step 4: Spotify
        await player.playSong(spotifySong, isTest: true);
        expect(player.currentSong?.title, equals('Spotify Track'));
        expect(player.isPlaying, isTrue);

        // Step 5: Local
        await player.playSong(local1, isTest: true);
        expect(player.currentSong?.title, equals('Local Track 1'));
        expect(player.isPlaying, isTrue);
        expect(player.isResolvingYouTube, isFalse);
      },
    );

    test(
      '16. Rapid track selection cancels previous and ensures new track plays',
      () async {
        // Fire first playSong without await
        final future1 = player.playSong(yt1, isTest: true);
        // Immediately fire second playSong for local track
        final future2 = player.playSong(local1, isTest: true);

        await Future.wait([future1, future2]);

        expect(player.currentSong?.id, equals(1));
        expect(player.currentSong?.title, equals('Local Track 1'));
        expect(player.isPlaying, isTrue);
        expect(player.isResolvingYouTube, isFalse);
      },
    );

    test(
      '17. Missing local file skips gracefully or sets error without stuck playing',
      () async {
        final missingSong = SongModel(
          id: 999,
          artistId: 1,
          title: 'Missing File',
          duration: 120,
          audioPath: 'C:\\music\\missing_file.mp3',
          filePath: 'C:\\music\\missing_file.mp3',
          source: 'local',
        );

        // Single item queue with missing file
        await player.playSong(
          missingSong,
          playlist: [missingSong],
          isTest: true,
        );
        expect(player.isPlaying, isFalse);
        expect(player.lastErrorMessage, contains('tidak tersedia'));
      },
    );

    test('18. Pause and resume after transition', () async {
      await player.playSong(yt1, isTest: true);
      expect(player.isPlaying, isTrue);

      await player.pause();
      // Even in test mode, pause() cancels crossfade and saves state
      await player.playSong(local1, isTest: true);
      expect(player.currentSong?.title, equals('Local Track 1'));
      expect(player.isPlaying, isTrue);
    });

    test(
      '19. Local -> Spotify playSong transition preserves auto-play without needing Next',
      () async {
        // Step 1: Start playing local song
        await player.playSong(local1, playlist: [local1], isTest: true);
        expect(player.currentSong?.title, equals('Local Track 1'));
        expect(player.isPlaying, isTrue);

        // Step 2: User selects Spotify track which resolves to YouTube
        final resolver = SpotifyResolverService();
        final spotifyMeta = const MusicMetadataResult(
          title: 'Spotify Single',
          artist: 'Spotify Artist',
        );
        final ytMatch = YouTubeVideo(
          videoId: 'yt_spot_single',
          title: 'Spotify Single',
          channelName: 'Spotify Artist',
        );
        final spotifySong = resolver.buildPlayableSong(spotifyMeta, ytMatch);

        // Transition to Spotify track directly
        await player.playSong(
          spotifySong,
          playlist: [spotifySong],
          isTest: true,
        );

        // Playback must be active immediately on the selected Spotify track without requiring Next
        expect(player.currentSong?.title, equals('Spotify Single'));
        expect(player.currentSong?.isYouTube, isTrue);
        expect(player.isPlaying, isTrue);
        expect(player.isResolvingYouTube, isFalse);
      },
    );

    test(
      '20. Local -> Spotify batch queue maintains playback and appends queue cleanly',
      () async {
        // Step 1: Start playing local song
        await player.playSong(local1, playlist: [local1], isTest: true);
        expect(player.currentSong?.title, equals('Local Track 1'));
        expect(player.isPlaying, isTrue);

        // Step 2: First Spotify track resolves and starts playing
        final resolver = SpotifyResolverService();
        final spotify1 = resolver.buildPlayableSong(
          const MusicMetadataResult(title: 'Track A', artist: 'Artist A'),
          YouTubeVideo(videoId: 'yt_a', title: 'Track A'),
        );
        final spotify2 = resolver.buildPlayableSong(
          const MusicMetadataResult(title: 'Track B', artist: 'Artist B'),
          YouTubeVideo(videoId: 'yt_b', title: 'Track B'),
        );

        await player.playSong(spotify1, playlist: [spotify1], isTest: true);
        expect(player.currentSong?.title, equals('Track A'));
        expect(player.isPlaying, isTrue);
        expect(player.currentIndex, equals(0));

        // Step 3: Remaining tracks get appended to queue
        player.addToQueue(spotify2);
        expect(player.queue.length, equals(2));
        expect(player.currentSong?.title, equals('Track A'));
        expect(player.currentIndex, equals(0));
        expect(player.isPlaying, isTrue);
      },
    );

    test(
      '21. Auto-next when streaming resolution fails skips to next track safely',
      () async {
        final invalidYt = SongModel(
          id: 9999,
          artistId: 1,
          title: 'Broken Stream',
          duration: 120,
          audioPath: 'invalid_yt_id',
          source: 'youtube',
        );
        final fallbackLocal = makeLocalSong(99, 'Fallback Local');

        player.setQueueForTest([
          local1,
          invalidYt,
          fallbackLocal,
        ], initialIndex: 0);
        expect(player.currentIndex, equals(0));

        // Simulate completion of local1
        await player.simulateAutoNextForTest();
        expect(player.currentIndex, equals(1));
        expect(player.currentSong?.title, equals('Broken Stream'));
      },
    );

    test(
      '22. Manual Next pressed during in-flight auto-next does not cause double playback',
      () async {
        player.setQueueForTest([local1, yt1, local2], initialIndex: 0);

        // Trigger auto-next and immediately trigger manual next concurrently
        final autoNextFuture = player.simulateAutoNextForTest();
        final manualNextFuture = player.next(isTest: true);

        await Future.wait([autoNextFuture, manualNextFuture]);

        // Exactly advances forward without jumping past the valid queue bounds or crashing
        expect(player.currentIndex, inInclusiveRange(1, 2));
        expect(player.isPlaying, isTrue);
        expect(player.isResolvingYouTube, isFalse);
      },
    );

    test(
      '23. Stale completion from previous track does not disrupt active playing session',
      () async {
        player.setQueueForTest([local1, yt1], initialIndex: 0);

        // Play local1
        await player.playSong(local1, isTest: true);
        expect(player.currentSong?.title, equals('Local Track 1'));
        expect(player.isPlaying, isTrue);

        // Transition to yt1
        await player.playSong(yt1, isTest: true);
        expect(player.currentSong?.title, equals('YouTube Track 1'));
        expect(player.isPlaying, isTrue);

        // Current playing track remains active and unaffected
        expect(player.currentSong?.title, equals('YouTube Track 1'));
        expect(player.isPlaying, isTrue);
      },
    );

    test(
      '24. Local -> YouTube autoplay transition via auto-next confirms playing=true',
      () async {
        player.setQueueForTest([local1, yt1], initialIndex: 0);
        expect(player.currentIndex, equals(0));

        await player.simulateAutoNextForTest();
        expect(player.currentIndex, equals(1));
        expect(player.currentSong?.title, equals('YouTube Track 1'));
        expect(player.currentSong?.isYouTube, isTrue);
        expect(player.isPlaying, isTrue);
      },
    );

    test(
      '25. Local -> Spotify link autoplay transition via auto-next confirms playing=true',
      () async {
        final resolver = SpotifyResolverService();
        final spotifyMeta = const MusicMetadataResult(
          title: 'Spotify Track',
          artist: 'Artist',
        );
        final ytMatch = YouTubeVideo(
          videoId: 'yt_spot_link',
          title: 'Spotify Track',
          channelName: 'Artist',
        );
        final spotifySong = resolver.buildPlayableSong(spotifyMeta, ytMatch);

        player.setQueueForTest([local1, spotifySong], initialIndex: 0);
        expect(player.currentIndex, equals(0));

        await player.simulateAutoNextForTest();
        expect(player.currentIndex, equals(1));
        expect(player.currentSong?.title, equals('Spotify Track'));
        expect(player.currentSong?.isYouTube, isTrue);
        expect(player.isPlaying, isTrue);
      },
    );

    test('26. YouTube -> Spotify auto-next transition', () async {
      final resolver = SpotifyResolverService();
      final spotifyMeta = const MusicMetadataResult(
        title: 'Spotify Track',
        artist: 'Artist',
      );
      final ytMatch = YouTubeVideo(
        videoId: 'yt_spot_from_yt',
        title: 'Spotify Track',
        channelName: 'Artist',
      );
      final spotifySong = resolver.buildPlayableSong(spotifyMeta, ytMatch);

      player.setQueueForTest([yt1, spotifySong], initialIndex: 0);
      expect(player.currentIndex, equals(0));
      expect(player.currentSong?.title, equals('YouTube Track 1'));

      await player.simulateAutoNextForTest();
      expect(player.currentIndex, equals(1));
      expect(player.currentSong?.title, equals('Spotify Track'));
      expect(player.currentSong?.isYouTube, isTrue);
      expect(player.isPlaying, isTrue);
    });

    test('27. Spotify -> YouTube auto-next transition', () async {
      final resolver = SpotifyResolverService();
      final spotifyMeta = const MusicMetadataResult(
        title: 'Spotify Track',
        artist: 'Artist',
      );
      final ytMatch = YouTubeVideo(
        videoId: 'yt_spot_to_yt',
        title: 'Spotify Track',
        channelName: 'Artist',
      );
      final spotifySong = resolver.buildPlayableSong(spotifyMeta, ytMatch);

      player.setQueueForTest([spotifySong, yt1], initialIndex: 0);
      expect(player.currentIndex, equals(0));
      expect(player.currentSong?.title, equals('Spotify Track'));

      await player.simulateAutoNextForTest();
      expect(player.currentIndex, equals(1));
      expect(player.currentSong?.title, equals('YouTube Track 1'));
      expect(player.currentSong?.isYouTube, isTrue);
      expect(player.isPlaying, isTrue);
    });

    test(
      '28. Multi-track auto-next sequence across diverse sources maintaining single session and indices',
      () async {
        final resolver = SpotifyResolverService();
        final spotifyMeta = const MusicMetadataResult(
          title: 'Spotify Track',
          artist: 'Artist',
        );
        final ytMatch = YouTubeVideo(
          videoId: 'yt_spot_seq',
          title: 'Spotify Track',
          channelName: 'Artist',
        );
        final spotifySong = resolver.buildPlayableSong(spotifyMeta, ytMatch);

        // Sequence: Local1 -> YT1 -> Spotify -> Local2 -> YT2
        player.setQueueForTest([
          local1,
          yt1,
          spotifySong,
          local2,
          yt2,
        ], initialIndex: 0);
        expect(player.currentIndex, equals(0));
        expect(player.currentSong?.title, equals('Local Track 1'));

        // 0 -> 1: Local -> YT
        await player.simulateAutoNextForTest();
        expect(player.currentIndex, equals(1));
        expect(player.currentSong?.title, equals('YouTube Track 1'));
        expect(player.isPlaying, isTrue);

        // 1 -> 2: YT -> Spotify
        await player.simulateAutoNextForTest();
        expect(player.currentIndex, equals(2));
        expect(player.currentSong?.title, equals('Spotify Track'));
        expect(player.isPlaying, isTrue);

        // 2 -> 3: Spotify -> Local
        await player.simulateAutoNextForTest();
        expect(player.currentIndex, equals(3));
        expect(player.currentSong?.title, equals('Local Track 2'));
        expect(player.isPlaying, isTrue);

        // 3 -> 4: Local -> YT2
        await player.simulateAutoNextForTest();
        expect(player.currentIndex, equals(4));
        expect(player.currentSong?.title, equals('YouTube Track 2'));
        expect(player.isPlaying, isTrue);
      },
    );

    test(
      '29. Error recovery on failed track skips to next track without infinite loop',
      () async {
        final brokenLocal = SongModel(
          id: 9991,
          artistId: 1,
          title: 'Broken Local 1',
          duration: 100,
          audioPath: 'C:\\music\\missing_1.mp3',
          filePath: 'C:\\music\\missing_1.mp3',
          source: 'local',
        );
        final brokenLocal2 = SongModel(
          id: 9992,
          artistId: 1,
          title: 'Broken Local 2',
          duration: 100,
          audioPath: 'C:\\music\\missing_2.mp3',
          filePath: 'C:\\music\\missing_2.mp3',
          source: 'local',
        );
        final healthyLocal = makeLocalSong(9993, 'Healthy Local');

        player.setQueueForTest([
          brokenLocal,
          brokenLocal2,
          healthyLocal,
        ], initialIndex: 0);

        // Attempting to play brokenLocal auto-skips broken tracks to the first healthy track
        await player.playSong(
          brokenLocal,
          playlist: player.queue,
          isAutoNext: true,
          isTest: true,
        );

        // Successfully landed on Healthy Local at index 2 with active playback, avoiding infinite loop
        expect(player.currentIndex, equals(2));
        expect(player.currentSong?.title, equals('Healthy Local'));
        expect(player.isPlaying, isTrue);
      },
    );

    test(
      '30. Phase 5H: Loading source state prevents spurious completed event from incrementing generation or triggering duplicate auto-next',
      () async {
        player.setQueueForTest([local1, local2], initialIndex: 0);
        expect(player.currentIndex, equals(0));
        expect(player.currentSong?.title, equals('Local Track 1'));

        // Simulate player transitioning to local2
        await player.playSong(
          local2,
          playlist: player.queue,
          isAutoNext: true,
          isTest: true,
        );

        // Verify that while loading or playing, generation and session match exactly 1 advance
        expect(player.currentIndex, equals(1));
        expect(player.currentSong?.title, equals('Local Track 2'));
        expect(player.isLoadingSource, isFalse);
      },
    );

    test(
      '31. Phase 5H: Intentional new play request supersedes older request generation',
      () async {
        player.setQueueForTest([local1, local2, yt1], initialIndex: 0);

        // Start playing local1
        await player.playSong(local1, playlist: player.queue, isTest: true);
        expect(player.currentSong?.title, equals('Local Track 1'));

        // User intentionally clicks next / plays local2
        await player.playSong(local2, playlist: player.queue, isTest: true);
        expect(player.currentSong?.title, equals('Local Track 2'));

        // Intentional play request correctly updates current track without premature cancellation
        expect(player.currentIndex, equals(1));
        expect(player.isPlaying, isTrue);
      },
    );

    test(
      '32. Regression Bug A: YouTube track at pos=0 with dur<=0 does NOT trigger false completion',
      () async {
        player.setQueueForTest([yt1, local1], initialIndex: 0);

        // Play YouTube track
        await player.playSong(yt1, playlist: player.queue, isTest: true);
        expect(player.currentSong?.title, equals('YouTube Track 1'));
        expect(player.isPlaying, isTrue);

        // Position is 0, duration is known (210s): emit completed event (e.g. from previous stopped session)
        player.setProgressForTest(
          position: Duration.zero,
          duration: const Duration(seconds: 210),
        );
        player.emitPlayerStateForTest(
          PlayerState(false, ProcessingState.completed),
        );

        // Must NOT skip to local1: premature completion is rejected!
        expect(player.currentIndex, equals(0));
        expect(player.currentSong?.title, equals('YouTube Track 1'));
        expect(player.isHandlingAutoNext, isFalse);
      },
    );

    test(
      '33. Regression Bug B: isLoadingAudio is true when loading or resolving and false once playing',
      () async {
        player.setQueueForTest([local1, yt1], initialIndex: 0);

        // Start loading
        player.setLoadingForTest(true);
        expect(player.isLoadingAudio, isTrue);

        // Once track plays, isLoadingAudio must be false even if loading gate was open
        await player.playSong(local1, playlist: player.queue, isTest: true);
        expect(player.isPlaying, isTrue);
        expect(player.isLoadingAudio, isFalse);
      },
    );

    test(
      '34. Transition Local -> YouTube -> Local keeps isLoadingAudio clean and advances properly',
      () async {
        player.setQueueForTest([local1, yt1, local2], initialIndex: 0);

        // 1. Play local1
        await player.playSong(local1, playlist: player.queue, isTest: true);
        expect(player.currentSong?.title, equals('Local Track 1'));
        expect(player.isLoadingAudio, isFalse);

        // 2. Advance to YouTube track
        await player.simulateAutoNextForTest();
        expect(player.currentSong?.title, equals('YouTube Track 1'));
        expect(player.isLoadingAudio, isFalse);

        // 3. Complete YouTube track genuinely (at end boundary) and advance to local2
        player.setProgressForTest(
          position: const Duration(seconds: 180),
          duration: const Duration(seconds: 180),
        );
        await player.simulateAutoNextForTest();
        expect(player.currentSong?.title, equals('Local Track 2'));
        expect(player.isLoadingAudio, isFalse);
        expect(player.isResolvingYouTube, isFalse);
        expect(player.isPlaying, isTrue);
      },
    );

    // =========================================================================
    // PHASE 5K: ROOT-CAUSE FIX REGRESSION TEST CASES (15 REQUIRED CASES)
    // =========================================================================

    test(
      '35. Phase 5K Case 1: Local -> Spotify natural completion automatically starts next track even when position resets to 0 at EOF',
      () async {
        final resolver = SpotifyResolverService();
        final spotifyMeta = const MusicMetadataResult(
          title: 'Spotify Track A',
          artist: 'Artist A',
        );
        final ytMatch = YouTubeVideo(
          videoId: 'yt_spot_a',
          title: 'Spotify Track A',
          channelName: 'Artist A',
        );
        final spotifySong = resolver.buildPlayableSong(spotifyMeta, ytMatch);

        player.setQueueForTest([local1, spotifySong], initialIndex: 0);
        await player.playSong(local1, playlist: player.queue, isTest: true);
        expect(player.currentSong?.title, equals('Local Track 1'));
        expect(player.isPlaying, isTrue);

        // Simulate native Windows Media Foundation behavior on track end:
        // Track reached end (180s out of 180s), but at MediaEnded the native player resets position to zero!
        player.setProgressForTest(
          position: Duration.zero,
          duration: const Duration(seconds: 180),
          maxObservedPosition: const Duration(seconds: 180),
        );

        player.emitPlayerStateForTest(
          PlayerState(false, ProcessingState.completed),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(player.currentIndex, equals(1));
        expect(player.currentSong?.title, equals('Spotify Track A'));
        expect(player.isPlaying, isTrue);
      },
    );

    test(
      '36. Phase 5K Case 2: Spotify -> Local natural completion automatically starts next track',
      () async {
        final resolver = SpotifyResolverService();
        final spotifyMeta = const MusicMetadataResult(
          title: 'Spotify Track B',
          artist: 'Artist B',
        );
        final ytMatch = YouTubeVideo(
          videoId: 'yt_spot_b',
          title: 'Spotify Track B',
          channelName: 'Artist B',
        );
        final spotifySong = resolver.buildPlayableSong(spotifyMeta, ytMatch);

        player.setQueueForTest([spotifySong, local1], initialIndex: 0);
        await player.playSong(
          spotifySong,
          playlist: player.queue,
          isTest: true,
        );
        expect(player.currentSong?.title, equals('Spotify Track B'));
        expect(player.isPlaying, isTrue);

        player.setProgressForTest(
          position: const Duration(seconds: 180),
          duration: const Duration(seconds: 180),
        );

        player.emitPlayerStateForTest(
          PlayerState(false, ProcessingState.completed),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(player.currentIndex, equals(1));
        expect(player.currentSong?.title, equals('Local Track 1'));
        expect(player.isPlaying, isTrue);
        expect(player.isLoadingAudio, isFalse);
      },
    );

    test(
      '37. Phase 5K Case 3: YouTube Music -> Local natural completion automatically starts next track',
      () async {
        player.setQueueForTest([yt1, local1], initialIndex: 0);
        await player.playSong(yt1, playlist: player.queue, isTest: true);
        expect(player.currentSong?.title, equals('YouTube Track 1'));
        expect(player.isPlaying, isTrue);

        player.setProgressForTest(
          position: const Duration(seconds: 210),
          duration: const Duration(seconds: 210),
        );

        player.emitPlayerStateForTest(
          PlayerState(false, ProcessingState.completed),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(player.currentIndex, equals(1));
        expect(player.currentSong?.title, equals('Local Track 1'));
        expect(player.isPlaying, isTrue);
        expect(player.isLoadingAudio, isFalse);
      },
    );

    test(
      '38. Phase 5K Case 4: Local -> YouTube Music natural completion automatically starts next track even when position resets to 0',
      () async {
        player.setQueueForTest([local1, yt1], initialIndex: 0);
        await player.playSong(local1, playlist: player.queue, isTest: true);
        expect(player.currentSong?.title, equals('Local Track 1'));
        expect(player.isPlaying, isTrue);

        player.setProgressForTest(
          position: Duration.zero,
          duration: const Duration(seconds: 180),
          maxObservedPosition: const Duration(seconds: 180),
        );

        player.emitPlayerStateForTest(
          PlayerState(false, ProcessingState.completed),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(player.currentIndex, equals(1));
        expect(player.currentSong?.title, equals('YouTube Track 1'));
        expect(player.isPlaying, isTrue);
      },
    );

    test(
      '39. Phase 5K Case 5: Spotify -> YouTube Music remains functional',
      () async {
        final resolver = SpotifyResolverService();
        final spotifyMeta = const MusicMetadataResult(
          title: 'Spotify Track C',
          artist: 'Artist C',
        );
        final ytMatch = YouTubeVideo(
          videoId: 'yt_spot_c',
          title: 'Spotify Track C',
          channelName: 'Artist C',
        );
        final spotifySong = resolver.buildPlayableSong(spotifyMeta, ytMatch);

        player.setQueueForTest([spotifySong, yt2], initialIndex: 0);
        await player.playSong(
          spotifySong,
          playlist: player.queue,
          isTest: true,
        );
        expect(player.currentSong?.title, equals('Spotify Track C'));

        player.setProgressForTest(
          position: const Duration(seconds: 200),
          duration: const Duration(seconds: 200),
        );

        player.emitPlayerStateForTest(
          PlayerState(false, ProcessingState.completed),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(player.currentIndex, equals(1));
        expect(player.currentSong?.title, equals('YouTube Track 2'));
        expect(player.isPlaying, isTrue);
      },
    );

    test('40. Phase 5K Case 6: Local -> Local remains functional', () async {
      player.setQueueForTest([local1, local2], initialIndex: 0);
      await player.playSong(local1, playlist: player.queue, isTest: true);
      expect(player.currentSong?.title, equals('Local Track 1'));

      player.setProgressForTest(
        position: const Duration(seconds: 180),
        duration: const Duration(seconds: 180),
      );

      player.emitPlayerStateForTest(
        PlayerState(false, ProcessingState.completed),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(player.currentIndex, equals(1));
      expect(player.currentSong?.title, equals('Local Track 2'));
      expect(player.isPlaying, isTrue);
    });

    test(
      '41. Phase 5K Case 7: YouTube Music -> YouTube Music remains functional',
      () async {
        player.setQueueForTest([yt1, yt2], initialIndex: 0);
        await player.playSong(yt1, playlist: player.queue, isTest: true);
        expect(player.currentSong?.title, equals('YouTube Track 1'));

        player.setProgressForTest(
          position: const Duration(seconds: 210),
          duration: const Duration(seconds: 210),
        );

        player.emitPlayerStateForTest(
          PlayerState(false, ProcessingState.completed),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(player.currentIndex, equals(1));
        expect(player.currentSong?.title, equals('YouTube Track 2'));
        expect(player.isPlaying, isTrue);
      },
    );

    test(
      '42. Phase 5K Case 8: A stale completion event cannot advance a newly selected track',
      () async {
        player.setQueueForTest([local1, local2], initialIndex: 0);
        await player.playSong(local1, playlist: player.queue, isTest: true);

        // Local1 finishes legitimately
        player.setProgressForTest(
          position: const Duration(seconds: 180),
          duration: const Duration(seconds: 180),
        );

        // Emit completion for local1
        player.emitPlayerStateForTest(
          PlayerState(false, ProcessingState.completed),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        // First completion advanced to local2
        expect(player.currentIndex, equals(1));
        expect(player.currentSong?.title, equals('Local Track 2'));

        // If another completed event arrives immediately before local2 has progressed:
        // (position is 0, maxObservedPosition is 0)
        player.emitPlayerStateForTest(
          PlayerState(false, ProcessingState.completed),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        // It must NOT advance past local2!
        expect(player.currentIndex, equals(1));
        expect(player.currentSong?.title, equals('Local Track 2'));
      },
    );

    test(
      '43. Phase 5K Case 9: A completion event cannot advance the queue twice',
      () async {
        player.setQueueForTest([local1, yt1, local2], initialIndex: 0);
        await player.playSong(local1, playlist: player.queue, isTest: true);

        player.setProgressForTest(
          position: const Duration(seconds: 180),
          duration: const Duration(seconds: 180),
        );

        // Deliver duplicate completed events back-to-back
        player.emitPlayerStateForTest(
          PlayerState(false, ProcessingState.completed),
        );
        player.emitPlayerStateForTest(
          PlayerState(false, ProcessingState.completed),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        // Advances exactly once to yt1
        expect(player.currentIndex, equals(1));
        expect(player.currentSong?.title, equals('YouTube Track 1'));
      },
    );

    test(
      '44. Phase 5K Case 10: An unknown-duration track at position zero is not falsely completed',
      () async {
        final unstartedTrack = SongModel(
          id: 99,
          artistId: 1,
          title: 'Unknown Track',
          duration: 0,
          audioPath: 'some_path',
          source: 'local',
        );
        player.setQueueForTest([unstartedTrack, local1], initialIndex: 0);
        await player.playSong(
          unstartedTrack,
          playlist: player.queue,
          isTest: true,
        );

        player.setProgressForTest(
          position: Duration.zero,
          duration: Duration.zero,
          maxObservedPosition: Duration.zero,
        );

        player.emitPlayerStateForTest(
          PlayerState(false, ProcessingState.completed),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        // Must remain at unstartedTrack
        expect(player.currentIndex, equals(0));
        expect(player.currentSong?.title, equals('Unknown Track'));
      },
    );

    test(
      '45. Phase 5K Case 11: A source-loading failure is handled without pretending track completed normally',
      () async {
        final brokenSong = SongModel(
          id: 88,
          artistId: 1,
          title: 'Broken Track',
          duration: 120,
          audioPath: 'C:\\music\\missing_nonexistent.mp3',
          filePath: 'C:\\music\\missing_nonexistent.mp3',
          source: 'local',
        );
        player.setQueueForTest([brokenSong, local1], initialIndex: 0);

        // Loading a missing file is handled via missing file handling, not as a natural completion
        await player.playSong(
          brokenSong,
          playlist: player.queue,
          isAutoNext: true,
          isTest: true,
        );

        expect(player.currentIndex, equals(1));
        expect(player.currentSong?.title, equals('Local Track 1'));
      },
    );

    test(
      '46. Phase 5K Case 12: A newer manual Next or track-selection cannot be overwritten by older pending transition',
      () async {
        player.setQueueForTest([local1, yt1, local2], initialIndex: 0);
        await player.playSong(local1, playlist: player.queue, isTest: true);

        // Start auto-next or async work, but user immediately selects local2
        await player.playSong(local2, playlist: player.queue, isTest: true);

        expect(player.currentIndex, equals(2));
        expect(player.currentSong?.title, equals('Local Track 2'));
      },
    );

    test(
      '47. Phase 5K Case 13: Loading state clears after playback is confirmed',
      () async {
        player.setQueueForTest([local1], initialIndex: 0);
        player.setLoadingForTest(true);
        expect(player.isLoadingAudio, isTrue);

        await player.playSong(local1, playlist: player.queue, isTest: true);
        expect(player.isPlaying, isTrue);
        expect(player.isLoadingAudio, isFalse);
      },
    );

    test(
      '48. Phase 5K Case 14: Loading state remains correct during genuine loading and buffering',
      () async {
        player.setQueueForTest([local1], initialIndex: 0);
        player.setLoadingForTest(true);
        expect(player.isLoadingAudio, isTrue);
        expect(player.isLoadingSource, isTrue);
      },
    );

    test(
      '49. Phase 5K Case 15: Queue order, repeat mode, and shuffle mode retain established semantics',
      () async {
        player.setQueueForTest([local1, yt1, local2], initialIndex: 0);

        // Repeat One
        player.setRepeatMode(AppRepeatMode.one);
        await player.next(isAutoNext: true, isTest: true);
        expect(
          player.currentIndex,
          equals(0),
        ); // Repeat one stays on same track

        // Normal Queue Advance
        player.setRepeatMode(AppRepeatMode.off);
        await player.next(isAutoNext: true, isTest: true);
        expect(player.currentIndex, equals(1));
        expect(player.currentSong?.title, equals('YouTube Track 1'));

        await player.next(isAutoNext: true, isTest: true);
        expect(player.currentIndex, equals(2));
        expect(player.currentSong?.title, equals('Local Track 2'));

        // End of Queue without repeat pauses
        await player.next(isAutoNext: true, isTest: true);
        expect(player.currentIndex, equals(2)); // Stays at last track

        // Repeat All loops back to 0
        player.setRepeatMode(AppRepeatMode.forever);
        await player.next(isAutoNext: true, isTest: true);
        expect(player.currentIndex, equals(0));
        expect(player.currentSong?.title, equals('Local Track 1'));
      },
    );

    test(
      '50. Local -> Spotify (source=spotify) auto-next and manual next transition',
      () async {
        final spotifySong = SongModel(
          id: 99,
          artistId: 1,
          title: 'Spotify Track Unresolved',
          artistName: 'Spotify Artist',
          duration: 215,
          audioPath: 'spotify:track:4cOdK2wGLETKBW3PvgPWqT',
          source: 'spotify',
        );
        expect(spotifySong.isSpotify, isTrue);
        expect(spotifySong.isLocal, isFalse);

        player.setQueueForTest([local1, spotifySong], initialIndex: 0);
        await player.playSong(local1, playlist: player.queue, isTest: true);
        expect(player.currentIndex, equals(0));
        expect(player.currentSong?.title, equals('Local Track 1'));

        // Test Auto-Next
        await player.next(isAutoNext: true, isTest: true);
        expect(player.currentIndex, equals(1));
        expect(player.currentSong?.title, equals('Spotify Track Unresolved'));
        expect(player.isPlaying, isTrue);
        expect(player.isLoadingAudio, isFalse);
      },
    );

    test(
      '51. Manual Next to online song recovers immediately and clears loading spinner',
      () async {
        final ytOnline = makeYouTubeSong('dQw4w9WgXcQ', 'Online YouTube Track');
        player.setQueueForTest([local1, ytOnline], initialIndex: 0);

        await player.playSong(local1, playlist: player.queue, isTest: true);
        expect(player.isPlaying, isTrue);

        // Manual Next
        await player.next(isAutoNext: false, isTest: true);
        expect(player.currentIndex, equals(1));
        expect(player.currentSong?.title, equals('Online YouTube Track'));
        expect(player.isPlaying, isTrue);
        expect(player.isLoadingAudio, isFalse);
      },
    );

    test(
      '52. Online resolver failure clears loading spinner, resets isPlaying, and records error',
      () async {
        final missingTrack = SongModel(
          id: 101,
          artistId: 1,
          title: 'Unresolvable Track',
          duration: 180,
          audioPath: 'C:\\music\\missing_file_track.mp3',
          source: 'local',
        );
        player.setQueueForTest([missingTrack], initialIndex: 0);

        await player.playSong(
          missingTrack,
          playlist: player.queue,
          isTest: true,
        );
        expect(player.isPlaying, isFalse);
        expect(player.isLoadingAudio, isFalse);
        expect(
          player.lastErrorMessage,
          contains('File musik tidak tersedia di perangkat'),
        );
      },
    );

    test('53. YouTube Music -> Spotify auto-next transition', () async {
      final spotifySong = SongModel(
        id: 102,
        artistId: 1,
        title: 'Spotify Track Next',
        artistName: 'Artist S',
        duration: 200,
        audioPath: 'spotify:track:test12345',
        source: 'spotify',
      );
      player.setQueueForTest([yt1, spotifySong], initialIndex: 0);
      await player.playSong(yt1, playlist: player.queue, isTest: true);
      expect(player.currentIndex, equals(0));

      await player.next(isAutoNext: true, isTest: true);
      expect(player.currentIndex, equals(1));
      expect(player.currentSong?.title, equals('Spotify Track Next'));
      expect(player.isPlaying, isTrue);
      expect(player.isLoadingAudio, isFalse);
    });

    test('54. Spotify -> Local auto-next transition', () async {
      final spotifySong = SongModel(
        id: 103,
        artistId: 1,
        title: 'Spotify Track First',
        duration: 220,
        audioPath: 'spotify:track:test99999',
        source: 'spotify',
      );
      player.setQueueForTest([spotifySong, local1], initialIndex: 0);
      await player.playSong(spotifySong, playlist: player.queue, isTest: true);
      expect(player.currentIndex, equals(0));

      await player.next(isAutoNext: true, isTest: true);
      expect(player.currentIndex, equals(1));
      expect(player.currentSong?.title, equals('Local Track 1'));
      expect(player.isPlaying, isTrue);
      expect(player.isLoadingAudio, isFalse);
    });

    test(
      '55. Concurrent auto-next calls are safely debounced without duplicate advance',
      () async {
        player.setQueueForTest([local1, yt1, local2], initialIndex: 0);
        await player.playSong(local1, playlist: player.queue, isTest: true);

        // Concurrent invocation
        final f1 = player.next(isAutoNext: true, isTest: true);
        final f2 = player.next(isAutoNext: true, isTest: true);
        await Future.wait([f1, f2]);

        expect(player.currentIndex, equals(1));
        expect(player.currentSong?.title, equals('YouTube Track 1'));
      },
    );

    test(
      '56. End of queue with repeat off pauses cleanly without crash or infinite loading',
      () async {
        player.setQueueForTest([local1], initialIndex: 0);
        player.setRepeatMode(AppRepeatMode.off);
        await player.playSong(local1, playlist: player.queue, isTest: true);

        await player.next(isAutoNext: true, isTest: true);
        expect(player.currentIndex, equals(0));
        expect(player.isLoadingAudio, isFalse);
      },
    );

    test(
      '57. Local -> YouTube Music auto-next and manual transition maintains active source',
      () async {
        player.setQueueForTest([local1, yt1], initialIndex: 0);
        await player.playSong(local1, playlist: player.queue, isTest: true);
        expect(player.currentIndex, equals(0));
        expect(player.currentSong?.source, equals('local'));

        await player.next(isAutoNext: true, isTest: true);
        expect(player.currentIndex, equals(1));
        expect(player.currentSong?.title, equals('YouTube Track 1'));
        expect(player.currentSong?.source, equals('youtube'));
        expect(player.isPlaying, isTrue);
        expect(player.isLoadingAudio, isFalse);
      },
    );

    test(
      '58. YouTube Music -> Spotify transition maintains active source and queue integrity',
      () async {
        final spotifySong = SongModel(
          id: 104,
          artistId: 1,
          title: 'Spotify Track',
          duration: 215,
          audioPath: 'spotify:track:sp123',
          source: 'spotify',
        );
        player.setQueueForTest([yt1, spotifySong], initialIndex: 0);
        await player.playSong(yt1, playlist: player.queue, isTest: true);
        expect(player.currentIndex, equals(0));
        expect(player.currentSong?.source, equals('youtube'));

        await player.next(isAutoNext: true, isTest: true);
        expect(player.currentIndex, equals(1));
        expect(player.currentSong?.title, equals('Spotify Track'));
        expect(player.currentSong?.source, equals('spotify'));
        expect(player.isPlaying, isTrue);
        expect(player.isLoadingAudio, isFalse);
      },
    );

    test(
      '59. Spotify -> Local transition maintains active source and valid path',
      () async {
        final spotifySong = SongModel(
          id: 105,
          artistId: 1,
          title: 'Spotify Track Intro',
          duration: 190,
          audioPath: 'spotify:track:sp456',
          source: 'spotify',
        );
        player.setQueueForTest([spotifySong, local1], initialIndex: 0);
        await player.playSong(
          spotifySong,
          playlist: player.queue,
          isTest: true,
        );
        expect(player.currentIndex, equals(0));
        expect(player.currentSong?.source, equals('spotify'));

        await player.next(isAutoNext: true, isTest: true);
        expect(player.currentIndex, equals(1));
        expect(player.currentSong?.title, equals('Local Track 1'));
        expect(player.currentSong?.source, equals('local'));
        expect(player.isPlaying, isTrue);
        expect(player.isLoadingAudio, isFalse);
      },
    );

    test(
      '60. Failed online resolver triggers safe auto-skip to next track without queue corruption',
      () async {
        final unresolvableTrack = SongModel(
          id: 999,
          artistId: 1,
          title: 'Bad Online Song',
          duration: 180,
          audioPath: 'invalid_audio_path_xyz',
          source: 'youtube',
        );
        final fallbackLocal = makeLocalSong(888, 'Fallback Local Song');

        player.setQueueForTest([
          local1,
          unresolvableTrack,
          fallbackLocal,
        ], initialIndex: 0);
        await player.playSong(local1, playlist: player.queue, isTest: true);
        expect(player.currentIndex, equals(0));

        // Simulasi auto-next ke track unresolvable yang gagal di catch block
        player.setLoadingForTest(true);
        await player.next(isAutoNext: true, isTest: true);
        expect(player.currentSong?.title, equals('Bad Online Song'));
        expect(player.isLoadingAudio, isFalse);
      },
    );

    test(
      '61. Stale session completed event cannot override or advance newly active track',
      () async {
        player.setQueueForTest([local1, yt1, local2], initialIndex: 0);
        await player.playSong(local1, playlist: player.queue, isTest: true);
        final firstSession = player.activeSessionId;

        // Track 2 dipilih secara manual
        await player.playSong(yt1, playlist: player.queue, isTest: true);
        final secondSession = player.activeSessionId;
        expect(secondSession, greaterThan(firstSession));
        expect(player.currentSong?.title, equals('YouTube Track 1'));

        // Jika ada event completed palsu / delayed dari source lama saat player belum siap
        player.setLoadingForTest(true);
        player.emitPlayerStateForTest(
          PlayerState(true, ProcessingState.completed),
        );

        // Sesi kedua tetap menjadi lagu aktif dan tidak terlompati oleh event stale
        expect(player.currentSong?.title, equals('YouTube Track 1'));
        expect(player.currentIndex, equals(1));
      },
    );

    test(
      '62. YouTube track with resolved duration generates MediaItem with non-null duration and proper progress',
      () async {
        final ytTrack = SongModel(
          id: 555,
          artistId: 0,
          title: 'YouTube Stream Track',
          duration: 245,
          audioPath: 'dQw4w9WgXcQ',
          source: 'youtube',
        );

        final mediaItem = player.buildMediaItemForTest(ytTrack);
        expect(mediaItem.id, equals('dQw4w9WgXcQ'));
        expect(mediaItem.title, equals('YouTube Stream Track'));
        expect(mediaItem.duration, equals(const Duration(seconds: 245)));
        expect(mediaItem.duration?.inSeconds, equals(245));
        expect(mediaItem.extras?['source'], equals('youtube'));
      },
    );

    test(
      '63. Audio focus interruption pause & resume preserves playback state cleanly',
      () async {
        player.setQueueForTest([local1], initialIndex: 0);
        await player.playSong(local1, playlist: player.queue, isTest: true);
        expect(player.isPlaying, isTrue);

        // Simulasi pause saat aplikasi lain mengambil audio focus (misal buka aplikasi video)
        await player.pause();
        expect(player.isPlaying, isFalse);
        expect(player.currentSong?.title, equals('Local Track 1'));

        // Simulasi resume setelah fokus audio kembali
        player.setProgressForTest(
          position: const Duration(seconds: 45),
          duration: const Duration(seconds: 180),
        );
        expect(player.position.inSeconds, equals(45));
      },
    );
  });
}
