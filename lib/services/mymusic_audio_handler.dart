import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import '../models/song_model.dart';

/// Single source of truth bridge between MyMusic Player and Android MediaSession / Media Notification.
class MyMusicAudioHandler extends BaseAudioHandler with SeekHandler {
  static MyMusicAudioHandler? _instance;
  static MyMusicAudioHandler? get instance => _instance;

  VoidCallback? _onPlay;
  VoidCallback? _onPause;
  VoidCallback? _onNext;
  VoidCallback? _onPrevious;
  ValueChanged<Duration>? _onSeek;
  VoidCallback? _onStop;

  DateTime? _lastPositionLogTime;
  bool _isForegroundStarted = false;

  MyMusicAudioHandler() {
    _instance = this;
    debugPrint('[MyMusic][MediaSync] initialized');
  }

  /// Register callbacks from the single PlayerProvider instance.
  void setPlayerCallbacks({
    required VoidCallback onPlay,
    required VoidCallback onPause,
    required VoidCallback onNext,
    required VoidCallback onPrevious,
    required ValueChanged<Duration> onSeek,
    required VoidCallback onStop,
  }) {
    _onPlay = onPlay;
    _onPause = onPause;
    _onNext = onNext;
    _onPrevious = onPrevious;
    _onSeek = onSeek;
    _onStop = onStop;
  }

  @override
  Future<void> play() async {
    debugPrint('[MyMusic][MediaSync] play');
    _onPlay?.call();
  }

  @override
  Future<void> pause() async {
    debugPrint('[MyMusic][MediaSync] pause');
    _onPause?.call();
  }

  @override
  Future<void> skipToNext() async {
    debugPrint('[MyMusic][MediaSync] next');
    _onNext?.call();
  }

  @override
  Future<void> skipToPrevious() async {
    debugPrint('[MyMusic][MediaSync] previous');
    _onPrevious?.call();
  }

  @override
  Future<void> seek(Duration position) async {
    debugPrint('[MyMusic][MediaSync] position=$position');
    _onSeek?.call(position);
  }

  @override
  Future<void> stop() async {
    debugPrint('[MyMusic][MediaSync] stop');
    _onStop?.call();
    await updatePlaybackState(
      playing: false,
      processingState: AudioProcessingState.idle,
      position: Duration.zero,
      bufferedPosition: Duration.zero,
      speed: 1.0,
    );
  }

  void _logPositionThrottled(Duration pos) {
    final now = DateTime.now();
    if (_lastPositionLogTime == null ||
        now.difference(_lastPositionLogTime!).inSeconds >= 3) {
      debugPrint('[MyMusic][MediaSync] position=$pos');
      _lastPositionLogTime = now;
    }
  }

  /// Update the active MediaItem when current song changes.
  void updateCurrentSong(SongModel? song) {
    if (song == null) {
      debugPrint('[MyMusic][MediaSync] currentSong=null');
      mediaItem.add(null);
      return;
    }

    final item = songToMediaItem(song);
    mediaItem.add(item);
    debugPrint(
      '[MyMusic][MediaSync] currentSong=${song.title} - ${song.artistName ?? 'Unknown Artist'}',
    );
    debugPrint(
      '[MyMusic][MediaSync] mediaItem=${item.title} - ${item.artist} (artUri=${item.artUri})',
    );
  }

  /// Synchronize the queue with Android MediaSession.
  void updateQueueList(List<SongModel> queueSongs) {
    final items = queueSongs.map(songToMediaItem).toList();
    queue.add(items);
  }

  /// Convert SongModel to MediaItem with artwork resolution.
  static MediaItem songToMediaItem(SongModel song) {
    final isYouTube = song.source == 'youtube' || song.isYouTube;
    final isSpotify = song.source == 'spotify' || song.isSpotify;
    final localPath = song.filePath ?? song.audioPath;
    final isLocal =
        !isYouTube &&
        !isSpotify &&
        (song.source == 'local' ||
            song.filePath != null ||
            (song.audioPath.isNotEmpty &&
                !song.audioPath.startsWith('http') &&
                !song.audioPath.startsWith('meta_') &&
                File(song.audioPath).existsSync()));

    final mediaId = isYouTube
        ? (song.audioPath.isNotEmpty ? song.audioPath : 'yt_${song.id}')
        : (isSpotify
              ? (song.sourceId != null && song.sourceId!.isNotEmpty
                    ? song.sourceId!
                    : 'sp_${song.id}')
              : (song.id > 0
                    ? song.id.toString()
                    : 'local_${song.audioPath.hashCode}'));

    Uri? artUri;
    if (song.cover != null && song.cover!.trim().isNotEmpty) {
      final coverStr = song.cover!.trim();
      if (coverStr.startsWith('http://') ||
          coverStr.startsWith('https://') ||
          coverStr.startsWith('file://')) {
        artUri = Uri.tryParse(coverStr);
      } else {
        artUri = Uri.file(coverStr);
      }
    }

    final title = song.title.trim().isNotEmpty
        ? song.title.trim()
        : 'Audio Track';
    final artist =
        (song.artistName != null && song.artistName!.trim().isNotEmpty)
        ? song.artistName!.trim()
        : (isYouTube ? 'YouTube' : (isSpotify ? 'Spotify' : 'Unknown Artist'));
    final album =
        (song.albumTitle != null && song.albumTitle!.trim().isNotEmpty)
        ? song.albumTitle!.trim()
        : (isYouTube
              ? 'YouTube Music'
              : (isSpotify ? 'Spotify' : 'Unknown Album'));

    return MediaItem(
      id: mediaId,
      album: album,
      title: title,
      artist: artist,
      duration: song.duration > 0 ? Duration(seconds: song.duration) : null,
      artUri: artUri,
      extras: {
        'videoId': song.audioPath,
        'filePath': localPath,
        'isLocal': isLocal,
        'source': song.source,
      },
    );
  }

  /// Broadcast updated playbackState to Android MediaSession & notification.
  Future<void> updatePlaybackState({
    required bool playing,
    required AudioProcessingState processingState,
    required Duration position,
    required Duration bufferedPosition,
    required double speed,
    int? queueIndex,
  }) async {
    if (playing && !_isForegroundStarted) {
      _isForegroundStarted = true;
      debugPrint('[MyMusic][MediaSync] foreground service started');
    } else if (!playing &&
        _isForegroundStarted &&
        (processingState == AudioProcessingState.idle ||
            processingState == AudioProcessingState.completed)) {
      _isForegroundStarted = false;
      debugPrint('[MyMusic][MediaSync] foreground service stopped');
    }

    _logPositionThrottled(position);
    debugPrint(
      '[MyMusic][MediaSync] isPlaying=$playing processingState=$processingState',
    );

    // Primary compact & visual media controls: [PREVIOUS] [PLAY/PAUSE] [NEXT]
    // STOP action is kept in systemActions so MediaSession lifecycle & cancellation
    // can handle stop, without showing an unwanted square [■] button on the notification.
    final controls = [
      MediaControl.skipToPrevious,
      playing ? MediaControl.pause : MediaControl.play,
      MediaControl.skipToNext,
    ];

    playbackState.add(
      PlaybackState(
        controls: controls,
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.stop,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: processingState,
        playing: playing,
        updatePosition: position,
        bufferedPosition: bufferedPosition,
        speed: speed,
        queueIndex: queueIndex,
      ),
    );
  }
}
