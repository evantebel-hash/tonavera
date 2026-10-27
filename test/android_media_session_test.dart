import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mymusic/models/song_model.dart';
import 'package:mymusic/providers/player_provider.dart';
import 'package:mymusic/services/mymusic_audio_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Android MediaSession & Media Notification Integration Tests', () {
    late MyMusicAudioHandler audioHandler;

    final localSong1 = SongModel(
      id: 101,
      artistId: 1,
      title: 'Local Track One',
      artistName: 'Artist Alpha',
      albumTitle: 'Album One',
      duration: 180,
      audioPath: '/storage/music/track1.mp3',
      filePath: '/storage/music/track1.mp3',
      cover: '/storage/music/cover1.jpg',
      source: 'local',
    );

    final localSong2 = SongModel(
      id: 102,
      artistId: 1,
      title: 'Local Track Two',
      artistName: 'Artist Alpha',
      albumTitle: 'Album One',
      duration: 210,
      audioPath: '/storage/music/track2.mp3',
      filePath: '/storage/music/track2.mp3',
      cover: '/storage/music/cover2.jpg',
      source: 'local',
    );

    final streamingSong = SongModel(
      id: 201,
      artistId: 0,
      title: 'Streaming Hit',
      artistName: 'Online Star',
      albumTitle: 'YouTube Music',
      duration: 240,
      audioPath: 'dQw4w9WgXcQ',
      cover: 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
      source: 'youtube',
    );

    setUp(() {
      audioHandler = MyMusicAudioHandler();
    });

    test('TEST A: MediaItem conversion correctly captures title, artist, album, duration, artwork', () {
      final mediaItem = MyMusicAudioHandler.songToMediaItem(localSong1);

      expect(mediaItem.id, equals('101'));
      expect(mediaItem.title, equals('Local Track One'));
      expect(mediaItem.artist, equals('Artist Alpha'));
      expect(mediaItem.album, equals('Album One'));
      expect(mediaItem.duration, equals(const Duration(seconds: 180)));
      expect(mediaItem.artUri, isNotNull);
      expect(mediaItem.extras?['source'], equals('local'));
    });

    test('TEST B & C: Media notification Play/Pause triggers MyMusic player callbacks', () async {
      bool playCalled = false;
      bool pauseCalled = false;

      audioHandler.setPlayerCallbacks(
        onPlay: () => playCalled = true,
        onPause: () => pauseCalled = true,
        onNext: () {},
        onPrevious: () {},
        onSeek: (_) {},
        onStop: () {},
      );

      await audioHandler.play();
      expect(playCalled, isTrue);

      await audioHandler.pause();
      expect(pauseCalled, isTrue);
    });

    test('TEST D & E: Media notification Next & Previous trigger MyMusic player queue callbacks', () async {
      bool nextCalled = false;
      bool previousCalled = false;

      audioHandler.setPlayerCallbacks(
        onPlay: () {},
        onPause: () {},
        onNext: () => nextCalled = true,
        onPrevious: () => previousCalled = true,
        onSeek: (_) {},
        onStop: () {},
      );

      await audioHandler.skipToNext();
      expect(nextCalled, isTrue);

      await audioHandler.skipToPrevious();
      expect(previousCalled, isTrue);
    });

    test('TEST F & G: Lock screen and compact actions include Prev, Play/Pause, Next with Seek enabled', () async {
      await audioHandler.updatePlaybackState(
        playing: true,
        processingState: AudioProcessingState.ready,
        position: const Duration(seconds: 45),
        bufferedPosition: const Duration(seconds: 90),
        speed: 1.0,
        queueIndex: 0,
      );

      final state = audioHandler.playbackState.value;
      expect(state.playing, isTrue);
      expect(state.processingState, equals(AudioProcessingState.ready));
      expect(state.updatePosition, equals(const Duration(seconds: 45)));
      expect(state.position.inSeconds, equals(45));

      // Compact indices must map to Prev (0), Pause (1), Next (2)
      expect(state.androidCompactActionIndices, equals([0, 1, 2]));
      expect(state.controls.length, equals(3));
      expect(state.controls[0], equals(MediaControl.skipToPrevious));
      expect(state.controls[1], equals(MediaControl.pause));
      expect(state.controls[2], equals(MediaControl.skipToNext));
      expect(state.controls.contains(MediaControl.stop), isFalse);

      // System actions must support seeking and stop
      expect(state.systemActions.contains(MediaAction.seek), isTrue);
      expect(state.systemActions.contains(MediaAction.stop), isTrue);
    });

    test('TEST H: UI track update updates mediaItem and queue immediately', () {
      audioHandler.updateCurrentSong(localSong1);
      expect(audioHandler.mediaItem.value?.title, equals('Local Track One'));

      audioHandler.updateQueueList([localSong1, localSong2, streamingSong]);
      expect(audioHandler.queue.value.length, equals(3));
      expect(audioHandler.queue.value[2].id, equals('dQw4w9WgXcQ'));
    });

    test('TEST I: Local track -> Streaming track switches metadata and remote HTTP artwork', () {
      audioHandler.updateCurrentSong(localSong1);
      expect(audioHandler.mediaItem.value?.id, equals('101'));

      audioHandler.updateCurrentSong(streamingSong);
      final ytItem = audioHandler.mediaItem.value;
      expect(ytItem?.id, equals('dQw4w9WgXcQ'));
      expect(ytItem?.title, equals('Streaming Hit'));
      expect(ytItem?.artist, equals('Online Star'));
      expect(ytItem?.album, equals('YouTube Music'));
      expect(ytItem?.artUri?.scheme, equals('https'));
      expect(ytItem?.artUri?.toString(), contains('i.ytimg.com'));
    });

    test('TEST J: Streaming track -> Local track switches back to local metadata cleanly', () {
      audioHandler.updateCurrentSong(streamingSong);
      expect(audioHandler.mediaItem.value?.id, equals('dQw4w9WgXcQ'));

      audioHandler.updateCurrentSong(localSong2);
      final localItem = audioHandler.mediaItem.value;
      expect(localItem?.id, equals('102'));
      expect(localItem?.title, equals('Local Track Two'));
      expect(localItem?.artist, equals('Artist Alpha'));
    });

    test('TEST K: PlayerProvider Auto-next simulation advances track and updates MediaItem', () async {
      final player = PlayerProvider();
      player.setQueueForTest([localSong1, localSong2], initialIndex: 0);

      expect(player.currentSong?.id, equals(101));
      await player.simulateAutoNextForTest();

      expect(player.currentSong?.id, equals(102));
      expect(player.currentIndex, equals(1));
    });

    test('TEST L: Pausing playback updates playbackState.playing to false with Play control', () async {
      await audioHandler.updatePlaybackState(
        playing: false,
        processingState: AudioProcessingState.ready,
        position: const Duration(seconds: 30),
        bufferedPosition: const Duration(seconds: 60),
        speed: 1.0,
      );

      final state = audioHandler.playbackState.value;
      expect(state.playing, isFalse);
      expect(state.controls[1], equals(MediaControl.play));
    });

    test('TEST M: Stopping playback cleans up MediaSession to idle state with zero position', () async {
      await audioHandler.stop();

      final state = audioHandler.playbackState.value;
      expect(state.playing, isFalse);
      expect(state.processingState, equals(AudioProcessingState.idle));
      expect(state.position, equals(Duration.zero));
    });
  });
}
