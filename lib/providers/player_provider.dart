import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart';
import '../services/mymusic_audio_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song_model.dart';
import '../core/config/api_config.dart';
import '../services/storage/offline_sync_service.dart';
import '../repositories/local_music_repository.dart';
import '../services/youtube/youtube_service.dart';
import '../services/youtube/youtube_resolver.dart';
import '../services/youtube/android_youtube_resolver.dart';
import '../services/metadata/metadata_model.dart';
import '../services/metadata/spotify_resolver_service.dart';
import '../services/audio/android_diagnostic_logger.dart';

enum AppRepeatMode { off, one, count, forever }

class PlayerProvider with ChangeNotifier {
  final AndroidEqualizer _equalizerA = AndroidEqualizer();
  final AndroidEqualizer _equalizerB = AndroidEqualizer();

  late final AudioPlayer _audioPlayerA;
  late final AudioPlayer _audioPlayerB;

  AudioPlayer? _activePlayerRef;
  AudioPlayer? _fadePlayerRef;

  AudioPlayer get _activePlayer => _activePlayerRef ?? _audioPlayerA;
  AudioPlayer get _fadePlayer => _fadePlayerRef ?? _audioPlayerB;

  SongModel? _currentSong;
  List<SongModel> _queue = [];
  List<SongModel> _shuffleOriginalQueue = [];
  int _currentIndex = -1;
  int _shuffleOriginalIndex = -1;

  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  bool _isShuffle = false;
  LoopMode _loopMode = LoopMode.off;
  AppRepeatMode _repeatMode = AppRepeatMode.off;
  int _targetRepeatCount = 1;
  int _remainingRepeatCount = 0;

  double _volume = 1.0;
  bool _isMuted = false;

  DateTime? _playStartTime;
  String? _lastErrorMessage;

  // Crossfade state
  int _crossfadeDuration = 0; // 0 to 12 seconds
  bool _gaplessEnabled = true;
  bool _isCrossfading = false;
  Timer? _crossfadeTimer;

  // --- EQUALIZER STATE ---
  static const Map<String, List<double>> eqPresets = {
    'Flat': [0.0, 0.0, 0.0, 0.0, 0.0],
    'Classical': [5.0, 3.0, -2.0, 4.0, 4.0],
    'Dance': [6.0, 0.0, 2.0, 4.0, 1.0],
    'Electronic': [5.0, 4.0, 0.0, 3.0, 5.0],
    'Hip Hop': [7.0, 3.0, -1.0, 3.0, -2.0],
    'Jazz': [4.0, 2.0, -2.0, 2.0, 4.0],
    'Pop': [-1.0, 2.0, 5.0, 1.0, -2.0],
    'Rock': [5.0, 3.0, -1.0, 3.0, 5.0],
    'Vocal': [-2.0, 4.0, 6.0, 4.0, 0.0],
    'Bass Boost': [8.0, 5.0, 0.0, 0.0, -2.0],
    'Treble Boost': [-2.0, 0.0, 2.0, 6.0, 9.0],
    'Custom': [0.0, 0.0, 0.0, 0.0, 0.0],
  };

  bool _equalizerEnabled = false;
  String _equalizerPreset = 'Flat';
  List<double> _customBands = [0.0, 0.0, 0.0, 0.0, 0.0];

  bool get isEqualizerSupported => Platform.isAndroid;
  bool get equalizerEnabled => _equalizerEnabled;
  String get equalizerPreset => _equalizerPreset;
  List<double> get currentBands => _equalizerPreset == 'Custom'
      ? _customBands
      : (eqPresets[_equalizerPreset] ?? [0.0, 0.0, 0.0, 0.0, 0.0]);

  // --- PLAYBACK SPEED STATE ---
  double _playbackSpeed = 1.0;
  double get playbackSpeed => _playbackSpeed;

  // --- SLEEP TIMER STATE ---
  DateTime? _sleepTimerEndTime;
  bool _stopAfterCurrentSong = false;
  Timer? _sleepTimerTicker;

  bool get isSleepTimerActive =>
      _stopAfterCurrentSong ||
      (_sleepTimerEndTime != null &&
          _sleepTimerEndTime!.isAfter(DateTime.now()));
  bool get stopAfterCurrentSong => _stopAfterCurrentSong;
  Duration? get sleepTimerRemaining {
    if (_sleepTimerEndTime == null) return null;
    final diff = _sleepTimerEndTime!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  String get sleepTimerFormatted {
    if (_stopAfterCurrentSong) return 'Stops after current song';
    final rem = sleepTimerRemaining;
    if (rem == null || rem == Duration.zero) return 'Off';
    final minutes = rem.inMinutes;
    final seconds = rem.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')} remaining';
  }

  int get crossfadeDuration => _crossfadeDuration;
  bool get gaplessEnabled => _gaplessEnabled;

  // --- DYNAMIC BACKGROUND STATE ---
  bool _dynamicBackgroundEnabled = true;
  bool get dynamicBackgroundEnabled => _dynamicBackgroundEnabled;

  void setDynamicBackgroundEnabled(bool enabled) {
    _dynamicBackgroundEnabled = enabled;
    _saveAudioSettings();
    notifyListeners();
  }

  // --- AUDIO VISUALIZER STATE (PHASE 3.3) ---
  bool _visualizerEnabled = true;
  bool get visualizerEnabled => _visualizerEnabled;

  void setVisualizerEnabled(bool enabled) {
    _visualizerEnabled = enabled;
    _saveAudioSettings();
    notifyListeners();
  }

  // --- WAVEFORM SEEK STATE (PHASE 3.4) ---
  bool _waveformSeekEnabled = true;
  bool get waveformSeekEnabled => _waveformSeekEnabled;

  void setWaveformSeekEnabled(bool enabled) {
    _waveformSeekEnabled = enabled;
    _saveAudioSettings();
    notifyListeners();
  }

  // --- ANDROID EXPERIENCE SETTINGS (PHASE 6) ---
  bool _resumePlaybackEnabled = true;
  bool _pauseOnHeadphoneDisconnect = true;
  bool _notificationPlayerEnabled = true;

  bool get resumePlaybackEnabled => _resumePlaybackEnabled;
  bool get pauseOnHeadphoneDisconnect => _pauseOnHeadphoneDisconnect;
  bool get notificationPlayerEnabled => _notificationPlayerEnabled;

  void setResumePlaybackEnabled(bool enabled) {
    _resumePlaybackEnabled = enabled;
    _saveAudioSettings();
    notifyListeners();
  }

  void setPauseOnHeadphoneDisconnect(bool enabled) {
    _pauseOnHeadphoneDisconnect = enabled;
    _saveAudioSettings();
    notifyListeners();
  }

  void setNotificationPlayerEnabled(bool enabled) {
    _notificationPlayerEnabled = enabled;
    _saveAudioSettings();
    if (Platform.isAndroid) {
      if (enabled) {
        MyMusicAudioHandler.instance?.updateCurrentSong(_currentSong);
        MyMusicAudioHandler.instance?.updateQueueList(_queue);
        _syncAudioHandlerPlaybackState(force: true);
      } else {
        MyMusicAudioHandler.instance?.stop();
      }
    }
    notifyListeners();
  }

  MediaItem _buildMediaItem(SongModel song) {
    return MyMusicAudioHandler.songToMediaItem(song);
  }

  @visibleForTesting
  MediaItem buildMediaItemForTest(SongModel song) {
    return _buildMediaItem(song);
  }

  // --- YOUTUBE RESOLVING & CANCELLATION STATE ---
  int _youtubeResolveGeneration = 0;
  int _consecutiveFailures = 0;
  bool _isResolvingYouTube = false;
  bool get isResolvingYouTube => _isResolvingYouTube;

  // Session & Transition tracking (prevents stale completed callbacks and auto-next deadlocks)
  int _activeSessionId = 0;
  int get activeSessionId => _activeSessionId;
  int _lastCompletedSessionId = -1;
  // Session whose playback was actually confirmed (PlayRequested/PlaybackConfirmed).
  // A ProcessingState.completed event may only be attributed to this session; an event
  // arriving while _activeSessionId > this value belongs to the previous session's source
  // (e.g. a late 'completed' from the prior track delivered after the next track was selected).
  int _playbackConfirmedSessionId = -1;
  int get playbackConfirmedSessionId => _playbackConfirmedSessionId;
  String? _autoNextInFlightTrackId;
  String? _currentTransitionId;
  bool _isTransitionInFlight = false;
  bool get isTransitionInFlight => _isTransitionInFlight;
  bool _isLoadingSource = false;
  bool get isLoadingSource => _isLoadingSource;

  // Track the furthest playback position reached during the active session.
  // Native engines (such as Windows Media Foundation / just_audio_windows_plus)
  // frequently reset or rewind the position stream to zero or EOF upon MediaEnded.
  // By tracking the maximum observed position reached for the confirmed session,
  // completion validation is preserved even if _position drops back to zero on ended.
  int _maxObservedPositionMs = 0;
  @visibleForTesting
  int get maxObservedPositionMsForTest => _maxObservedPositionMs;

  /// True when the audio is resolving (e.g. YouTube metadata / URL resolution)
  /// or setting audio source, or buffering while not yet actively playing.
  /// Once playback is confirmed and actively playing (or ready with position > 0),
  /// the spinner indicator is released.
  bool get isLoadingAudio {
    if (_isPlaying) return false;
    final state = _activePlayer.processingState;
    return _isResolvingYouTube ||
        _isLoadingSource ||
        state == ProcessingState.loading ||
        state == ProcessingState.buffering;
  }

  // Getters
  SongModel? get currentSong => _currentSong;
  List<SongModel> get queue => List.unmodifiable(_queue);
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;
  bool get isShuffle => _isShuffle;
  LoopMode get loopMode => _loopMode;
  AppRepeatMode get repeatMode => _repeatMode;
  int get targetRepeatCount => _targetRepeatCount;
  int get remainingRepeatCount => _remainingRepeatCount;
  double get volume => _volume;
  bool get isMuted => _isMuted;
  String? get lastErrorMessage => _lastErrorMessage;

  PlayerProvider() {
    if (Platform.isAndroid) {
      _audioPlayerA = AudioPlayer(
        audioPipeline: AudioPipeline(androidAudioEffects: [_equalizerA]),
      );
      _audioPlayerB = AudioPlayer(
        audioPipeline: AudioPipeline(androidAudioEffects: [_equalizerB]),
      );
    } else {
      _audioPlayerA = AudioPlayer();
      _audioPlayerB = AudioPlayer();
    }
    _activePlayerRef = _audioPlayerA;
    _fadePlayerRef = _audioPlayerB;

    if (Platform.isAndroid) {
      AudioSession.instance.then((session) {
        session.configure(const AudioSessionConfiguration.music());
        session.setActive(true);
      });
    }
    _initAudioListeners();
    _loadAudioSettings();
    _initAudioHandlerBridge();
  }

  DateTime? _lastAudioHandlerStateUpdateTime;

  void _initAudioHandlerBridge() {
    if (!Platform.isAndroid) return;
    final handler = MyMusicAudioHandler.instance;
    if (handler != null) {
      handler.setPlayerCallbacks(
        onPlay: resume,
        onPause: pause,
        onNext: () => next(isAutoNext: false),
        onPrevious: previous,
        onSeek: seek,
        onStop: stop,
      );
    }
  }

  void _syncAudioHandlerPlaybackState({bool force = false}) {
    if (!Platform.isAndroid || !_notificationPlayerEnabled) return;
    final handler = MyMusicAudioHandler.instance;
    if (handler == null) return;

    final now = DateTime.now();
    if (!force && _lastAudioHandlerStateUpdateTime != null) {
      final elapsed = now
          .difference(_lastAudioHandlerStateUpdateTime!)
          .inMilliseconds;
      if (elapsed < 1000) {
        return;
      }
    }
    _lastAudioHandlerStateUpdateTime = now;

    AudioProcessingState processingState;
    switch (_activePlayer.processingState) {
      case ProcessingState.idle:
        processingState = AudioProcessingState.idle;
        break;
      case ProcessingState.loading:
        processingState = AudioProcessingState.loading;
        break;
      case ProcessingState.buffering:
        processingState = AudioProcessingState.buffering;
        break;
      case ProcessingState.ready:
        processingState = AudioProcessingState.ready;
        break;
      case ProcessingState.completed:
        processingState = AudioProcessingState.completed;
        break;
    }

    handler.updatePlaybackState(
      playing: _isPlaying,
      processingState: processingState,
      position: _activePlayer.position,
      bufferedPosition: _activePlayer.bufferedPosition,
      speed: _playbackSpeed,
      queueIndex: _currentIndex >= 0 ? _currentIndex : null,
    );
  }

  void _initAudioListeners() {
    _listenToPlayer(_audioPlayerA, isPlayerA: true);
    _listenToPlayer(_audioPlayerB, isPlayerA: false);
  }

  bool _isTestMode = false;

  /// Player stream subscriptions, cancelled in [dispose]. Without this, an
  /// in-flight platform event delivered after dispose called notifyListeners
  /// on a disposed ChangeNotifier (debug assertion / wasted work).
  final List<StreamSubscription<dynamic>> _playerSubscriptions = [];

  void _listenToPlayer(AudioPlayer player, {required bool isPlayerA}) {
    _playerSubscriptions.add(
      player.playerStateStream.listen((state) {
        debugPrint(
          '[LISTEN][DIAG] t=${DateTime.now().millisecondsSinceEpoch % 100000} player=${identical(player, _audioPlayerA) ? 'A' : 'B'} active=${identical(player, _activePlayer)} test=$_isTestMode state=$state isPlayingBefore=$_isPlaying',
        );
        if (Platform.isAndroid && identical(player, _activePlayer)) {
          AndroidDiagnosticLogger.instance.log(
            'STREAM_STATE',
            'playing=${state.playing}, processingState=${state.processingState}, isPlayingBefore=$_isPlaying',
          );
        }
        if (player == _activePlayer) {
          if (_isTestMode) return;
          _handleActivePlayerState(state);
        }
      }),
    );

    // Native playback failures (Windows MediaFailed, ItemFailed, stream
    // teardown at end-of-source) surface here instead of as
    // ProcessingState.completed. Without this listener the queue silently
    // stalled at the failed track and only manual Next recovered it.
    _playerSubscriptions.add(
      player.errorStream.listen((error) {
        debugPrint(
          '[DIAG][Android] Native errorStream emitted: code=${error.code}, msg=${error.message}',
        );
        if (Platform.isAndroid && identical(player, _activePlayer)) {
          AndroidDiagnosticLogger.instance.recordError(
            'STREAM_ERROR',
            'Native code=${error.code}, msg=${error.message}',
          );
        }
        if (player == _activePlayer) {
          if (_isTestMode) return;
          _handlePlaybackFailure(code: error.code, message: error.message);
        }
      }),
    );

    _playerSubscriptions.add(
      player.positionStream.listen((pos) {
        if (player == _activePlayer) {
          _position = pos;
          if (pos.inMilliseconds > _maxObservedPositionMs) {
            _maxObservedPositionMs = pos.inMilliseconds;
          }
          if (pos > Duration.zero && !_isPlaying && player.playing) {
            _isPlaying = true;
          }
          _syncAudioHandlerPlaybackState(force: false);
          notifyListeners();

          // Check if near end for crossfade triggering
          _checkCrossfadeTrigger(pos);
        }
      }),
    );

    _playerSubscriptions.add(
      player.bufferedPositionStream.listen((buf) {
        if (player == _activePlayer) {
          _syncAudioHandlerPlaybackState(force: false);
        }
      }),
    );

    _playerSubscriptions.add(
      player.durationStream.listen((dur) {
        if (player == _activePlayer && dur != null) {
          _duration = dur;
          if (_currentSong != null &&
              _currentSong!.duration == 0 &&
              dur.inSeconds > 0) {
            _currentSong = _currentSong!.copyWith(duration: dur.inSeconds);
            if (Platform.isAndroid && _notificationPlayerEnabled) {
              MyMusicAudioHandler.instance?.updateCurrentSong(_currentSong);
            }
          }
          _syncAudioHandlerPlaybackState(force: true);
          notifyListeners();
        }
      }),
    );
  }

  /// Handles a PlayerState emitted by the active player.
  ///
  /// The completion branch only accepts events whose session has confirmed playback.
  /// just_audio reports ProcessingState.completed for the source currently loaded on
  /// the player: if the next session has not yet attached/confirmed its source, the
  /// event still belongs to the previous session's source (delivered late through the
  /// platform event channel) and must not be attributed to the newly selected session.
  void _handleActivePlayerState(PlayerState state) {
    _isPlaying = state.playing;
    if (state.processingState == ProcessingState.completed && !_isCrossfading) {
      if (_isLoadingSource || _isResolvingYouTube) {
        debugPrint(
          '[PLAYER] Ignoring ProcessingState.completed emitted during source loading/resolving (sessionId=$_activeSessionId, song="${_currentSong?.title}")',
        );
        return;
      }
      final completedSession = _activeSessionId;
      final completedSong = _currentSong;
      if (completedSession == _lastCompletedSessionId) {
        debugPrint(
          '[PLAYER] Ignoring stale completed event for session $completedSession ("${completedSong?.title}")',
        );
        return;
      }
      if (completedSession != _playbackConfirmedSessionId) {
        debugPrint(
          '[PLAYER] Ignoring ProcessingState.completed for unconfirmed session $completedSession '
          '(confirmedSession=$_playbackConfirmedSessionId, song="${completedSong?.title}"). '
          'Event belongs to the previous session source; playback was never confirmed for this session.',
        );
        return;
      }
      // Validate track actually finished or is at duration boundary.
      // An unstarted track (effectivePosMs == 0) or unconfirmed duration (durMs <= 0) must NEVER be treated as completed.
      // We check effectivePosMs = max(posMs, _maxObservedPositionMs) because native engines
      // (like Windows Media Foundation) may rewind _position to 0 upon reaching MediaEnded.
      final posMs = _position.inMilliseconds;
      final effectivePosMs = max(posMs, _maxObservedPositionMs);
      final durMs = _duration.inMilliseconds;
      final isNearEnd =
          effectivePosMs > 0 &&
          (durMs > 0
              ? (_isTestMode || effectivePosMs >= (durMs - 1500))
              : (_isTestMode || effectivePosMs > 3000));
      if (!isNearEnd) {
        debugPrint(
          '[PLAYER] ProcessingState.completed emitted prematurely (pos=$posMs, maxPos=$_maxObservedPositionMs, dur=$durMs, sessionId=$completedSession). Ignoring false completion.',
        );
        return;
      }

      _lastCompletedSessionId = completedSession;
      debugPrint(
        '[PLAYER] completed track: "${completedSong?.title}" (sessionId=$completedSession)',
      );
      _sendHistoryRecord(completed: true);
      _handleAutoNext(
        completedSessionId: completedSession,
        completedSong: completedSong,
      );
    } else if (state.processingState == ProcessingState.completed) {
      // _isCrossfading swallows the event; make it observable instead of silent.
      debugPrint(
        '[PLAYER] CompletionObserved during crossfade (sessionId=$_activeSessionId, song="${_currentSong?.title}"); crossfade owns this transition.',
      );
    } else if (state.processingState == ProcessingState.idle) {
      // Diagnostic only: native Fail() lands here, but advancement is driven
      // exclusively by the errorStream handler so a single failure can never
      // advance the queue twice.
      debugPrint(
        '[PLAYER] Player entered idle state (sessionId=$_activeSessionId, confirmedSession=$_playbackConfirmedSessionId, loading=$_isLoadingSource, song="${_currentSong?.title}").',
      );
    }
    _syncAudioHandlerPlaybackState(force: true);
    notifyListeners();
  }

  /// Test-only entry point to deliver a PlayerState as if it came from the active
  /// player's playerStateStream, bypassing the `_isTestMode` short-circuit that
  /// normally silences the real listener during tests.
  @visibleForTesting
  void emitPlayerStateForTest(PlayerState state) =>
      _handleActivePlayerState(state);

  /// Test-only entry point for [errorStream] deliveries.
  @visibleForTesting
  void emitPlaybackErrorForTest({int code = 1, String? message}) =>
      _handlePlaybackFailure(code: code, message: message);

  /// Test-only override for the progress used by end-of-track validation.
  /// Must be called after `playSong` (which re-seeds `_duration`).
  @visibleForTesting
  void setProgressForTest({
    required Duration position,
    required Duration duration,
    Duration? maxObservedPosition,
  }) {
    _position = position;
    _duration = duration;
    _maxObservedPositionMs = maxObservedPosition != null
        ? maxObservedPosition.inMilliseconds
        : max(position.inMilliseconds, _maxObservedPositionMs);
  }

  /// Test-only override for the source-loading gate.
  @visibleForTesting
  void setLoadingForTest(bool loading) => _isLoadingSource = loading;

  /// Handles a playback error reported by the platform (native MediaFailed /
  /// ItemFailed / stream teardown). A failure is NOT a natural completion:
  /// it may only advance the queue when the failed session was
  /// playback-confirmed, no transition is in flight, and the reported
  /// position sits at the duration boundary — evidence that the source
  /// failed while finishing an otherwise complete track (the common Windows
  /// network-stream case where the connection tears down at end-of-media
  /// instead of emitting ProcessingState.completed). Advancement reuses the
  /// same `_lastCompletedSessionId` / `_autoNextInFlightTrackId`
  /// bookkeeping as a natural completion, so duplicate notifications (the
  /// error plus the idle PlayerState plus a repeated broadcast) advance
  /// exactly once. Mid-track failures are reported distinctly and never skip
  /// a valid queued track.
  ///
  /// Limitation: the platform does not tag an error with the session that
  /// produced it, so a late error from the previous source delivered after
  /// the next session confirmed playback is attributed to the active
  /// session. The mid-track branch only records `_lastErrorMessage` (no
  /// queue/index/playing changes), so such a late error cannot skip a track;
  /// position validation rejects it as premature.
  void _handlePlaybackFailure({int code = 1, String? message}) {
    final sanitized = _sanitizeErrorMessage(message);
    final failedSession = _activeSessionId;
    final failedSong = _currentSong;
    debugPrint(
      '[AudioTransition] Failed | ${_currentTransitionId ?? '-'} | NativePlaybackError | session=$failedSession code=$code msg=$sanitized',
    );

    if (_isLoadingSource) {
      debugPrint(
        '[PLAYER] PlaybackErrorRejected | session=$failedSession | reason=sourceLoading | the in-flight transition owns this failure.',
      );
      return;
    }
    if (_isCrossfading) {
      debugPrint(
        '[PLAYER] PlaybackErrorRejected | session=$failedSession | reason=crossfading | crossfade owns this transition.',
      );
      return;
    }
    if (failedSession == _lastCompletedSessionId) {
      debugPrint(
        '[PLAYER] PlaybackErrorRejected | session=$failedSession | reason=duplicateOfCompleted',
      );
      return;
    }
    if (failedSession != _playbackConfirmedSessionId) {
      debugPrint(
        '[PLAYER] PlaybackErrorRejected | session=$failedSession | reason=unconfirmed (confirmedSession=$_playbackConfirmedSessionId, song="${failedSong?.title}"). Error belongs to the previous session source.',
      );
      return;
    }

    final posMs = _position.inMilliseconds;
    final effectivePosMs = max(posMs, _maxObservedPositionMs);
    final durMs = _duration.inMilliseconds;
    // Strict evidence for a failure-at-end: unlike natural completions, a
    // failure with unknown duration (durMs <= 0) must not skip a track.
    if (durMs > 0 && effectivePosMs >= (durMs - 1500)) {
      _lastCompletedSessionId = failedSession;
      _isPlaying = false;
      debugPrint(
        '[PLAYER] PlaybackErrorAtEnd treated as natural completion: "${failedSong?.title}" (sessionId=$failedSession, pos=$posMs, maxPos=$_maxObservedPositionMs, dur=$durMs)',
      );
      _sendHistoryRecord(completed: true);
      _handleAutoNext(
        completedSessionId: failedSession,
        completedSong: failedSong,
      );
      return;
    }

    _lastErrorMessage =
        'Playback gagal: ${failedSong?.title ?? 'audio'} ($sanitized)';
    debugPrint(
      '[PLAYER] PlaybackErrorMidTrack | session=$failedSession | pos=$posMs dur=$durMs | queue not advanced (reported distinctly).',
    );
    _syncAudioHandlerPlaybackState(force: true);
    notifyListeners();
  }

  /// Strips query strings (signed stream URLs, tokens) and truncates native
  /// error text before it reaches logs or UI state.
  String _sanitizeErrorMessage(String? message) {
    if (message == null || message.isEmpty) return 'unknown';
    final noQuery = message.split('?').first;
    return noQuery.length > 200 ? '${noQuery.substring(0, 200)}...' : noQuery;
  }

  void _checkCrossfadeTrigger(Duration currentPos) {
    if (_crossfadeDuration <= 0 ||
        _isCrossfading ||
        !_isPlaying ||
        _duration == Duration.zero) {
      return;
    }

    // Do not trigger crossfade if single song repeat mode is active
    if (_repeatMode == AppRepeatMode.one) return;

    final remaining = _duration - currentPos;
    final fadeDurationThreshold = Duration(seconds: _crossfadeDuration);

    if (remaining <= fadeDurationThreshold &&
        remaining > const Duration(milliseconds: 500)) {
      _triggerCrossfade();
    }
  }

  void _triggerCrossfade() {
    _isCrossfading = true;

    // Check Sleep Timer bounds before triggering auto next crossfade
    if (_stopAfterCurrentSong ||
        (_sleepTimerEndTime != null &&
            DateTime.now().isAfter(_sleepTimerEndTime!))) {
      // Sleep timer should stop playback when song ends, don't start next track
      _isCrossfading = false;
      return;
    }

    int nextIndex = -1;
    if (_repeatMode == AppRepeatMode.count && _remainingRepeatCount > 0) {
      nextIndex = _currentIndex;
    } else if (_isShuffle) {
      final availableIndexes = <int>[];
      for (int i = 0; i < _queue.length; i++) {
        if (i != _currentIndex) availableIndexes.add(i);
      }
      if (availableIndexes.isNotEmpty) {
        nextIndex = availableIndexes[Random().nextInt(availableIndexes.length)];
      } else if (_repeatMode == AppRepeatMode.forever ||
          _loopMode == LoopMode.all) {
        nextIndex = 0;
      }
    } else {
      nextIndex = _currentIndex + 1;
      if (nextIndex >= _queue.length) {
        if (_repeatMode == AppRepeatMode.forever || _loopMode == LoopMode.all) {
          nextIndex = 0;
        } else {
          nextIndex = -1;
        }
      }
    }

    if (nextIndex == -1 || nextIndex >= _queue.length) {
      _isCrossfading = false;
      return;
    }

    final outgoingPlayer = _activePlayer;
    final incomingPlayer = _fadePlayer;

    final nextSong = _queue[nextIndex];
    final isYouTube = nextSong.source == 'youtube' || nextSong.isYouTube;
    final isSpotify =
        nextSong.source == 'spotify' ||
        nextSong.isSpotify ||
        nextSong.audioPath.startsWith('spotify:') ||
        nextSong.audioPath.startsWith('meta_spotify');
    final isLocal =
        !isYouTube &&
        !isSpotify &&
        (nextSong.source == 'local' ||
            nextSong.filePath != null ||
            (nextSong.audioPath.isNotEmpty &&
                !nextSong.audioPath.startsWith('http') &&
                !nextSong.audioPath.startsWith('meta_') &&
                File(nextSong.audioPath).existsSync()));
    final localPath = nextSong.filePath ?? nextSong.audioPath;

    Future.microtask(() async {
      try {
        if (isLocal) {
          if (Platform.isAndroid) {
            await incomingPlayer.setAudioSource(
              AudioSource.file(localPath, tag: _buildMediaItem(nextSong)),
            );
          } else {
            await incomingPlayer.setAudioSource(AudioSource.file(localPath));
          }
        } else if (isYouTube || isSpotify) {
          var playableSong = nextSong;
          if (isSpotify &&
              !nextSong.audioPath.startsWith('http') &&
              nextSong.audioPath.length != 11) {
            final metaTrack = MusicMetadataResult(
              title: nextSong.title,
              artist: nextSong.artistName,
              album: nextSong.albumTitle,
              duration: nextSong.duration,
              artworkUrl: nextSong.cover,
              spotifyId: nextSong.sourceId,
            );
            final resolved = await SpotifyResolverService.instance.resolveTrack(
              metaTrack,
            );
            if (resolved != null) {
              playableSong = nextSong.copyWith(audioPath: resolved.audioPath);
            }
          }
          if (Platform.isWindows) {
            final streamUrl = await YouTubeResolver.instance
                .resolveAudioStreamUrl(playableSong.audioPath);
            await incomingPlayer.setUrl(streamUrl);
          } else if (Platform.isAndroid) {
            final details = await AndroidYouTubeResolver.instance
                .resolveAudioStreamDetails(playableSong.audioPath);
            final hasHeaders = details.headers.isNotEmpty;
            if (_notificationPlayerEnabled) {
              await incomingPlayer.setAudioSource(
                AudioSource.uri(
                  Uri.parse(details.url),
                  headers: hasHeaders ? details.headers : null,
                  tag: _buildMediaItem(nextSong),
                ),
              );
            } else {
              await incomingPlayer.setAudioSource(
                AudioSource.uri(
                  Uri.parse(details.url),
                  headers: hasHeaders ? details.headers : null,
                ),
              );
            }
          } else {
            final streamUrl = await YouTubeService.instance
                .resolveAudioStreamUrl(nextSong);
            await incomingPlayer.setUrl(streamUrl);
          }
        } else {
          final audioUrl = '${ApiConfig.baseUrl}/songs/${nextSong.id}/stream';
          if (Platform.isAndroid) {
            await incomingPlayer.setAudioSource(
              AudioSource.uri(
                Uri.parse(audioUrl),
                tag: _buildMediaItem(nextSong),
              ),
            );
          } else {
            await incomingPlayer.setUrl(audioUrl);
          }
        }
        await incomingPlayer.setSpeed(_playbackSpeed);
        if (isEqualizerSupported) {
          await _applyEqualizerGains();
        }

        await _ensureSourceReady(incomingPlayer);

        incomingPlayer.setVolume(0.0);
        // Do NOT await the play() future here (same Windows semantics as the
        // un-awaited play in _prepareAndStartPlayback): just_audio_windows_plus
        // completes the play result only at pause/stop/failure/END OF MEDIA,
        // so awaiting it would block this microtask until the incoming track
        // finishes — the fade timer below would never start, _isCrossfading
        // would stay true, and every subsequent completion would be swallowed
        // by the crossfade gate, stalling auto-next until a manual Next (which
        // cancels the crossfade). The session is already warm at this point
        // (an outgoing track is playing), so play()'s internal awaits are
        // microtask-only and the request cannot be dropped by a stale
        // `playing: false` broadcast.
        unawaited(
          incomingPlayer.play().catchError((Object e, StackTrace st) {
            debugPrint('[PLAYER] crossfade incoming play() request failed: $e');
          }),
        );

        // Perform gradual volume crossfade
        final steps = _crossfadeDuration * 20; // 50ms intervals
        final stepDuration = const Duration(milliseconds: 50);
        int currentStep = 0;

        _crossfadeTimer?.cancel();
        _crossfadeTimer = Timer.periodic(stepDuration, (timer) async {
          currentStep++;
          final progress = (currentStep / steps).clamp(0.0, 1.0);

          final outVol = (_volume * (1.0 - progress)).clamp(0.0, 1.0);
          final inVol = (_volume * progress).clamp(0.0, 1.0);

          if (!_isMuted) {
            outgoingPlayer.setVolume(outVol);
            incomingPlayer.setVolume(inVol);
          }

          if (currentStep >= steps || !_isCrossfading) {
            timer.cancel();
            await outgoingPlayer.stop();
            outgoingPlayer.setVolume(_isMuted ? 0.0 : _volume);

            // Swap active and fade players
            _activePlayerRef = incomingPlayer;
            _fadePlayerRef = outgoingPlayer;

            _currentIndex = nextIndex;
            _currentSong = nextSong;
            // The swap runs inside `await outgoingPlayer.stop()`: the
            // outgoing player's playing=false / idle events are processed
            // while it is still active and clear _isPlaying, and
            // _maxObservedPositionMs still holds the outgoing track's end
            // position. The incoming player is playing (its play request was
            // issued above), so restore the observable playing state and
            // reset position bookkeeping for the new current track — the
            // same reset playSong performs — so the completion guards
            // validate the incoming track's own position instead of the
            // previous track's end.
            _isPlaying = true;
            _position = Duration.zero;
            _maxObservedPositionMs = 0;

            if (_repeatMode == AppRepeatMode.count &&
                _remainingRepeatCount > 0) {
              _remainingRepeatCount--;
            } else {
              _remainingRepeatCount = _targetRepeatCount;
            }

            _isCrossfading = false;
            if (Platform.isAndroid && _notificationPlayerEnabled) {
              MyMusicAudioHandler.instance?.updateCurrentSong(_currentSong);
              MyMusicAudioHandler.instance?.updateQueueList(_queue);
              _syncAudioHandlerPlaybackState(force: true);
            }
            notifyListeners();
          }
        });
      } catch (e) {
        debugPrint('Crossfade failed: $e');
        _isCrossfading = false;
      }
    });
  }

  void _cancelCrossfade() {
    _crossfadeTimer?.cancel();
    if (_isCrossfading) {
      _isCrossfading = false;
      _fadePlayer.stop();
      _fadePlayer.setVolume(_isMuted ? 0.0 : _volume);
      _activePlayer.setVolume(_isMuted ? 0.0 : _volume);
    }
  }

  Future<void> _sendHistoryRecord({
    bool completed = false,
    bool skipped = false,
  }) async {
    if (_currentSong == null || _playStartTime == null) return;
    final durationPlayed = _position.inSeconds;
    if (durationPlayed < 2) return;

    final start = _playStartTime!;
    final end = DateTime.now();
    final songId = _currentSong!.id;

    _playStartTime = null;

    try {
      final repo = LocalMusicRepository();
      await repo.recordHistory(
        songId: songId,
        startedAt: start,
        endedAt: end,
        durationPlayed: durationPlayed,
        completed: completed,
        skipped: skipped,
      );
    } catch (e) {
      await OfflineSyncService.saveOfflineHistory(
        songId: songId,
        startedAt: start,
        endedAt: end,
        durationPlayed: durationPlayed,
      );
    }
  }

  Future<void> _ensureSourceReady(
    AudioPlayer player, {
    String? transitionId,
    String? trackTitle,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    // If player is already ready for the newly loaded source, confirm immediately.
    // Note: completed state from a previous source should not be treated as ready.
    if (player.processingState == ProcessingState.ready) {
      if (transitionId != null) {
        debugPrint(
          '[AudioTransition] SourceReady | $transitionId | $trackTitle',
        );
      }
      return;
    }

    try {
      final readyWatch = Stopwatch()..start();
      debugPrint(
        '[DIAG][Android] Stage 2: waiting for source ready (startState=${player.processingState}, timeout=${timeout.inSeconds}s)',
      );
      if (Platform.isAndroid) {
        AndroidDiagnosticLogger.instance.startStage(
          'Stage 2: _ensureSourceReady',
          details:
              'startState=${player.processingState}, timeout=${timeout.inSeconds}s',
        );
      }
      await player.processingStateStream
          .firstWhere((state) => state == ProcessingState.ready)
          .timeout(timeout);
      debugPrint(
        '[DIAG][Android] Stage 2 Success: source ready in ${readyWatch.elapsedMilliseconds}ms (state=${player.processingState})',
      );
      if (Platform.isAndroid) {
        AndroidDiagnosticLogger.instance.endStage(
          'Stage 2: _ensureSourceReady',
          details: 'state=${player.processingState}',
          success: true,
        );
      }
      if (transitionId != null) {
        debugPrint(
          '[AudioTransition] SourceReady | $transitionId | $trackTitle',
        );
      }
    } on TimeoutException {
      debugPrint(
        '[DIAG][Android] Stage 2 Warning: _ensureSourceReady timed out after ${timeout.inSeconds}s (state=${player.processingState})',
      );
      if (Platform.isAndroid) {
        AndroidDiagnosticLogger.instance.recordError(
          'SOURCE_READY_TIMEOUT',
          'Timed out after ${timeout.inSeconds}s (state=${player.processingState})',
        );
        AndroidDiagnosticLogger.instance.endStage(
          'Stage 2: _ensureSourceReady',
          details: 'Timeout warning (state=${player.processingState})',
          success: false,
        );
      }
      if (transitionId != null) {
        debugPrint(
          '[AudioTransition] Failed | $transitionId | SourceReadyTimeout | processingState=${player.processingState}',
        );
      }
    } catch (e) {
      debugPrint(
        '[DIAG][Android] Stage 2 Error: _ensureSourceReady error: $e | state=${player.processingState}',
      );
      if (Platform.isAndroid) {
        AndroidDiagnosticLogger.instance.recordError(
          'SOURCE_READY_ERROR',
          '$e (state=${player.processingState})',
        );
        AndroidDiagnosticLogger.instance.endStage(
          'Stage 2: _ensureSourceReady',
          details: 'Error: $e',
          success: false,
        );
      }
      if (transitionId != null) {
        debugPrint(
          '[AudioTransition] Failed | $transitionId | SourceReadyError | $e',
        );
      }
    }
  }

  /// Completes the audio-session platform-channel round trips BEFORE
  /// [AudioPlayer.play] is issued.
  ///
  /// just_audio's `play()` broadcasts `playing = true`, then awaits
  /// `AudioSession.instance` and `setActive(true)` — platform-channel round
  /// trips on platforms without the audio_session plugin (Windows) — and only
  /// then re-checks the flag (`if (!playing) return;`) before sending the
  /// native play request. Windows `Broadcast()` carries the native `playing_`
  /// flag, which stays false until that native play request lands; if such a
  /// broadcast is delivered inside the round-trip window, `play()` returns
  /// WITHOUT ever asking the engine to play. The track then stays silent, no
  /// end-of-track event ever fires, and auto-next stalls — while manual Next
  /// recovers because by then the session is warm and play()'s window has
  /// collapsed to microtasks (which platform messages cannot interleave
  /// with). Warming the session here, before play(), removes the window on
  /// every playback start. Reproduced by tool/auto_next_probe.dart
  /// scenario 1; pinned by test/auto_next_first_play_session_race_test.dart.
  Future<void> _warmAudioSessionBeforePlayback() async {
    try {
      final warmWatch = Stopwatch()..start();
      if (Platform.isAndroid) {
        AndroidDiagnosticLogger.instance.startStage(
          'Stage 3: AudioSession Warmup',
        );
      }
      final session = await AudioSession.instance.timeout(
        const Duration(seconds: 4),
        onTimeout: () =>
            throw TimeoutException('AudioSession.instance timeout'),
      );
      if (!session.isConfigured) {
        await session
            .configure(const AudioSessionConfiguration.music())
            .timeout(
              const Duration(seconds: 4),
              onTimeout: () =>
                  throw TimeoutException('AudioSession.configure timeout'),
            );
      }
      debugPrint(
        '[DIAG][Android] AudioSession warmed in ${warmWatch.elapsedMilliseconds}ms (configured=${session.isConfigured})',
      );
      if (Platform.isAndroid) {
        AndroidDiagnosticLogger.instance.endStage(
          'Stage 3: AudioSession Warmup',
          details: 'configured=${session.isConfigured}',
          success: true,
        );
      }
    } catch (e) {
      // Best effort: AudioPlayer.play() repeats these calls itself.
      debugPrint('[DIAG][Android] AudioSession warm-up notice/warning: $e');
      if (Platform.isAndroid) {
        AndroidDiagnosticLogger.instance.recordError(
          'AUDIOSESSION_WARM_WARN',
          'Notice/Warning: $e',
        );
        AndroidDiagnosticLogger.instance.endStage(
          'Stage 3: AudioSession Warmup',
          details: 'Warning: $e',
          success: false,
        );
      }
    }
  }

  Future<void> _prepareAndStartPlayback(
    AudioPlayer player, {
    required int sessionId,
    bool isTest = false,
    String? transitionId,
    String? trackTitle,
  }) async {
    final prepWatch = Stopwatch()..start();
    if (Platform.isAndroid) {
      AndroidDiagnosticLogger.instance.log(
        'PREP_ENTRY',
        'sessionId=$sessionId, isTest=$isTest, activePlayerState=${player.playerState}',
      );
    }
    if (isTest) {
      _isPlaying = true;
      _playbackConfirmedSessionId = sessionId;
      if (transitionId != null) {
        debugPrint(
          '[AudioTransition] PlayRequested | $transitionId | $trackTitle',
        );
        debugPrint(
          '[AudioTransition] PlaybackConfirmed | $transitionId | playing=true',
        );
      }
      notifyListeners();
      return;
    }

    try {
      debugPrint(
        '[PLAYER] waiting for source ready (state=${player.processingState})',
      );
      if (Platform.isAndroid) {
        AndroidDiagnosticLogger.instance.log(
          'PREP_STEP_1',
          'invoking _ensureSourceReady (state=${player.processingState})',
        );
      }
      await _ensureSourceReady(
        player,
        transitionId: transitionId,
        trackTitle: trackTitle,
      );
      debugPrint(
        '[PLAYER] source ready (state=${player.processingState}, elapsed=${prepWatch.elapsedMilliseconds}ms)',
      );
      if (Platform.isAndroid) {
        AndroidDiagnosticLogger.instance.log(
          'PREP_STEP_2',
          'returned from _ensureSourceReady, setting speed $_playbackSpeed',
        );
      }

      await player.setSpeed(_playbackSpeed);
      if (Platform.isAndroid) {
        AndroidDiagnosticLogger.instance.log(
          'PREP_SPEED_SET',
          'player.setSpeed($_playbackSpeed) resolved | session=$sessionId',
        );
      }

      if (isEqualizerSupported) {
        final eqWatch = Stopwatch()..start();
        if (Platform.isAndroid) {
          AndroidDiagnosticLogger.instance.log(
            'PREP_STEP_3',
            'applying equalizer gains (enabled=$_equalizerEnabled) | session=$sessionId',
          );
        }
        await _applyEqualizerGains(sessionId: sessionId);
        debugPrint(
          '[PLAYER] equalizer applied (${eqWatch.elapsedMilliseconds}ms)',
        );
        if (Platform.isAndroid) {
          AndroidDiagnosticLogger.instance.log(
            'PREP_STEP_4',
            'equalizer applied in ${eqWatch.elapsedMilliseconds}ms | session=$sessionId',
          );
        }
      }
      player.setVolume(_isMuted ? 0.0 : _volume);
      if (Platform.isAndroid) {
        AndroidDiagnosticLogger.instance.log(
          'PREP_VOL_SET',
          'player.setVolume(${_isMuted ? 0.0 : _volume}) set | session=$sessionId',
        );
      }

      // Move the audio-session round trips out of play()'s internal guard
      // window (see _warmAudioSessionBeforePlayback): on Windows the first
      // play of a session otherwise races an engine `playing: false` broadcast
      // and aborts before the native play request is ever sent.
      final warmWatch = Stopwatch()..start();
      if (Platform.isAndroid) {
        AndroidDiagnosticLogger.instance.log(
          'PREP_STEP_5',
          'invoking _warmAudioSessionBeforePlayback | session=$sessionId',
        );
      }
      await _warmAudioSessionBeforePlayback();
      debugPrint(
        '[PLAYER] audio session warmed (${warmWatch.elapsedMilliseconds}ms)',
      );
      if (Platform.isAndroid) {
        AndroidDiagnosticLogger.instance.log(
          'PREP_STEP_6',
          'warmAudioSession completed in ${warmWatch.elapsedMilliseconds}ms | session=$sessionId',
        );
      }

      if (transitionId != null) {
        debugPrint(
          '[AudioTransition] PlayRequested | $transitionId | $trackTitle',
        );
      }
      debugPrint(
        '[DIAG][Android] Stage 3: issuing play() request (currentState=${player.playerState})',
      );
      if (Platform.isAndroid) {
        AndroidDiagnosticLogger.instance.startStage(
          'Stage 4: player.play() Request',
          details: 'currentState=${player.playerState} | session=$sessionId',
        );
      }
      final playFuture = player.play();
      if (Platform.isAndroid) {
        // End stage immediately after request dispatch so it measures the API call initiation,
        // not the entire playback duration of the track.
        AndroidDiagnosticLogger.instance.endStage(
          'Stage 4: player.play() Request',
          details:
              'Dispatched (state=${player.playerState}) | session=$sessionId',
          success: true,
        );
      }
      unawaited(
        playFuture
            .then((_) {
              debugPrint(
                '[DIAG][Android] Stage 3: player.play() Future completed normally (playing=${player.playing}, state=${player.playerState})',
              );
              if (Platform.isAndroid) {
                AndroidDiagnosticLogger.instance.log(
                  'PLAY_FUTURE_RESOLVED',
                  'Future resolved: playing=${player.playing}, state=${player.playerState} | session=$sessionId',
                );
              }
            })
            .catchError((Object e, StackTrace st) {
              debugPrint(
                '[DIAG][Android] Stage 3 Error: player.play() request failed: $e\n$st',
              );
              if (Platform.isAndroid) {
                AndroidDiagnosticLogger.instance.recordError(
                  'PLAY_FUTURE_ERROR',
                  e,
                  st,
                );
              }
              if (sessionId == _activeSessionId) {
                _lastErrorMessage = 'Gagal memulai pemutaran: $e';
                notifyListeners();
              }
            }),
      );

      if (sessionId != _activeSessionId) {
        // A newer session superseded this one while its awaits were in flight.
        // That session owns the loading/confirmation state now; writing
        // _isLoadingSource/_playbackConfirmedSessionId here would stomp it and
        // reopen the completed-event gate for the wrong session.
        debugPrint(
          '[PLAYER] Skipping stale playback confirmation for session $sessionId (active session=$_activeSessionId).',
        );
        if (Platform.isAndroid) {
          AndroidDiagnosticLogger.instance.log(
            'PREP_STALE_SESSION',
            'session=$sessionId superseded by activeSession=$_activeSessionId',
          );
        }
        return;
      }

      _consecutiveFailures = 0;
      // On Android / ExoPlayer, unawaited play() initiates asynchronous native playback.
      // player.playing may still be false synchronously before the native state transition fires.
      // Setting _isPlaying = true here reflects the confirmed play request, releasing the
      // loading spinner without waiting for position > 0.
      _isPlaying = Platform.isAndroid ? true : (player.playing || _isPlaying);
      // Confirm this session's playback BEFORE opening the completed-event gate
      // (_isLoadingSource = false), so a stale 'completed' from the previous source
      // can never be attributed to a session that never reached playback. Position
      // validation remains the discriminator between that stale event (position
      // still zero) and a genuine end-of-track completion (position near
      // duration, tracked by _maxObservedPositionMs even when the native engine
      // rewinds position to zero on MediaEnded).
      _playbackConfirmedSessionId = sessionId;
      if (transitionId != null) {
        debugPrint(
          '[AudioTransition] PlaybackConfirmed | $transitionId | playing=${player.playing}',
        );
      }
      debugPrint(
        '[DIAG][Android] Stage 3 Success: playback confirmed (playerState=${player.playerState}, isPlaying=$_isPlaying, totalPrep=${prepWatch.elapsedMilliseconds}ms)',
      );
      if (Platform.isAndroid) {
        AndroidDiagnosticLogger.instance.log(
          'PREP_CONFIRMED',
          'session=$sessionId, confirmedSession=$_playbackConfirmedSessionId, isPlaying=$_isPlaying',
        );
      }
    } catch (e, st) {
      if (Platform.isAndroid) {
        AndroidDiagnosticLogger.instance.recordError(
          'PREP_UNHANDLED_EXCEPTION',
          'session=$sessionId: $e',
          st,
        );
      }
      rethrow;
    } finally {
      if (Platform.isAndroid) {
        AndroidDiagnosticLogger.instance.log(
          'PREP_FINALLY',
          'session=$sessionId, activeSession=$_activeSessionId, isLoadingSourceBefore=$_isLoadingSource',
        );
      }
      if (sessionId == _activeSessionId) {
        _isLoadingSource = false;
        notifyListeners();
      }
    }
  }

  Future<void> playSong(
    SongModel song, {
    List<SongModel>? playlist,
    BuildContext? context,
    bool isAutoNext = false,
    bool isTest = false,
  }) async {
    final oldGeneration = _youtubeResolveGeneration;
    final generation = ++_youtubeResolveGeneration;
    final oldSessionId = _activeSessionId;
    final sessionId = ++_activeSessionId;
    final transitionId =
        'tr_${DateTime.now().millisecondsSinceEpoch}_$generation';
    _currentTransitionId = transitionId;
    final trigger = isAutoNext ? 'autoNext' : 'playRequest';
    final fromSource = _currentSong?.source ?? 'none';
    final toSource = (song.source == 'youtube' || song.isYouTube)
        ? 'youtube'
        : (song.source.isNotEmpty ? song.source : 'local');

    if (isTest) {
      _isTestMode = true;
    }

    _isLoadingSource = true;
    debugPrint(
      '[AudioTransition] GenerationChanged | $transitionId | gen: $oldGeneration -> $generation | session: $oldSessionId -> $sessionId | track: "${song.title}" ($toSource) | trigger: $trigger',
    );
    debugPrint(
      '[AudioTransition] Start | $transitionId | $fromSource | $toSource | ${song.title}',
    );

    _cancelCrossfade();
    _lastErrorMessage = null;
    if (_currentSong != null && _isPlaying && !isAutoNext) {
      await _sendHistoryRecord(skipped: true);
    }

    if (playlist != null && playlist.isNotEmpty) {
      if (!identical(_queue, playlist)) {
        _queue = List.from(playlist);
        _currentIndex = _queue.indexWhere((s) => s.id == song.id);
        if (_currentIndex == -1) {
          _queue.insert(0, song);
          _currentIndex = 0;
        }
      }
    } else {
      if (!_queue.any((s) => s.id == song.id)) {
        _queue.add(song);
      }
      if (_currentIndex < 0 ||
          _currentIndex >= _queue.length ||
          _queue[_currentIndex].id != song.id) {
        _currentIndex = _queue.indexWhere((s) => s.id == song.id);
      }
    }

    _currentSong = song;
    _remainingRepeatCount = _targetRepeatCount;
    _playStartTime = DateTime.now();
    _duration = song.duration > 0
        ? Duration(seconds: song.duration)
        : Duration.zero;
    if (Platform.isAndroid && _notificationPlayerEnabled) {
      MyMusicAudioHandler.instance?.updateCurrentSong(_currentSong);
      MyMusicAudioHandler.instance?.updateQueueList(_queue);
      _syncAudioHandlerPlaybackState(force: true);
    }

    final isYouTube = song.source == 'youtube' || song.isYouTube;
    final isSpotify =
        song.source == 'spotify' ||
        song.isSpotify ||
        song.audioPath.startsWith('spotify:') ||
        song.audioPath.startsWith('meta_spotify');
    final isLocal =
        !isYouTube &&
        !isSpotify &&
        (song.source == 'local' ||
            song.filePath != null ||
            (song.audioPath.isNotEmpty &&
                !song.audioPath.startsWith('http') &&
                !song.audioPath.startsWith('meta_') &&
                File(song.audioPath).existsSync()));
    final localPath = song.filePath ?? song.audioPath;

    debugPrint(
      '[PLAYER] set current track: "${song.title}" (source=${song.source}, index=$_currentIndex, autoNext=$isAutoNext, sessionId=$sessionId)',
    );

    if (!isTest) {
      debugPrint(
        '[PLAYER] stopping previous session before loading next source',
      );
      await _activePlayer.stop();
    }
    _position = Duration.zero;
    _maxObservedPositionMs = 0;

    if (isYouTube || isSpotify) {
      _isResolvingYouTube = true;
      debugPrint(
        '[PLAYER] resolving online source: source=${song.source}, audioPath=${song.audioPath}',
      );
    } else {
      _isResolvingYouTube = false;
    }
    notifyListeners();

    try {
      if (isLocal) {
        if (Platform.isAndroid) {
          AndroidDiagnosticLogger.instance.setCurrentTrack(
            title: song.title,
            path: localPath,
          );
          AndroidDiagnosticLogger.instance.startStage(
            'Stage 1: File Check & setAudioSource',
            details: 'sessionId=$sessionId',
          );
        }
        final file = File(localPath);
        final fileExists = isTest
            ? (!localPath.contains('missing') &&
                  !localPath.startsWith('/missing'))
            : await file.exists();
        int fileSizeBytes = -1;
        if (fileExists && !isTest) {
          try {
            fileSizeBytes = await file.length();
          } catch (_) {}
        }
        debugPrint(
          '[DIAG][Android] Stage 1 LocalFile: exists=$fileExists, sizeBytes=$fileSizeBytes, path="$localPath"',
        );
        if (Platform.isAndroid) {
          AndroidDiagnosticLogger.instance.log(
            'FILE_INFO',
            'exists=$fileExists, sizeBytes=$fileSizeBytes, path="$localPath"',
          );
        }
        if (!fileExists) {
          if (Platform.isAndroid) {
            AndroidDiagnosticLogger.instance.recordError(
              'FILE_NOT_FOUND',
              'Local file does not exist: $localPath',
            );
            AndroidDiagnosticLogger.instance.endStage(
              'Stage 1: File Check & setAudioSource',
              details: 'File not found',
              success: false,
            );
          }
          _lastErrorMessage =
              'File musik tidak tersedia di perangkat: ${song.title}';
          debugPrint('[PLAYER] Local file not found: $localPath');
          debugPrint(
            '[AudioTransition] Failed | $transitionId | LocalFileNotFound | $localPath',
          );
          if (context != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Lagu "${song.title}" dilewati karena file tidak tersedia.',
                ),
                backgroundColor: Colors.orangeAccent,
                action: SnackBarAction(
                  label: 'Hapus dari Queue',
                  textColor: Colors.white,
                  onPressed: () => removeFromQueue(_currentIndex),
                ),
              ),
            );
          }
          _isPlaying = false;
          await _activePlayer.stop();
          notifyListeners();

          if (_queue.length > 1) {
            debugPrint('[PLAYER] Skipping missing local file to next item.');
            _isTransitionInFlight = false;
            await next(isAutoNext: true, isTest: isTest);
          } else {
            _currentSong = null;
            _currentIndex = -1;
            if (Platform.isAndroid && _notificationPlayerEnabled) {
              MyMusicAudioHandler.instance?.updateCurrentSong(null);
              _syncAudioHandlerPlaybackState(force: true);
            }
            notifyListeners();
          }
          return;
        }

        if (isTest) {
          _isLoadingSource = false;
          _isPlaying = true;
          _playbackConfirmedSessionId = sessionId;
          debugPrint(
            '[AudioTransition] SourceReady | $transitionId | ${song.title}',
          );
          debugPrint(
            '[AudioTransition] PlayRequested | $transitionId | ${song.title}',
          );
          debugPrint(
            '[AudioTransition] PlaybackConfirmed | $transitionId | playing=true',
          );
          notifyListeners();
          return;
        }

        debugPrint('[PLAYER] loading local file source');
        debugPrint(
          '[AudioTransition] SourceAttached | $transitionId | path=$localPath',
        );
        final attachWatch = Stopwatch()..start();
        final tagItem = (Platform.isAndroid && _notificationPlayerEnabled)
            ? _buildMediaItem(song)
            : null;
        debugPrint(
          '[DIAG][Android] Stage 1: calling setAudioSource (tagTitle="${tagItem?.title}", tagArtUri=${tagItem?.artUri})',
        );
        if (Platform.isAndroid) {
          AndroidDiagnosticLogger.instance.log(
            'SOURCE_SET_START',
            'hasTagItem=${tagItem != null}, tagTitle="${tagItem?.title}", tagArtUri=${tagItem?.artUri}',
          );
        }

        final audioSource = tagItem != null
            ? AudioSource.file(localPath, tag: tagItem)
            : AudioSource.file(localPath);

        try {
          await _activePlayer
              .setAudioSource(audioSource)
              .timeout(
                const Duration(seconds: 12),
                onTimeout: () =>
                    throw TimeoutException('setAudioSource timeout (12s)'),
              );
        } catch (e, st) {
          if (Platform.isAndroid) {
            AndroidDiagnosticLogger.instance.recordError(
              'SET_AUDIO_SOURCE_ERROR',
              e,
              st,
            );
            AndroidDiagnosticLogger.instance.endStage(
              'Stage 1: File Check & setAudioSource',
              details: 'Exception: $e',
              success: false,
            );
          }
          rethrow;
        }

        debugPrint(
          '[DIAG][Android] Stage 1 Success: setAudioSource completed in ${attachWatch.elapsedMilliseconds}ms, playerDuration=${_activePlayer.duration}, playerState=${_activePlayer.playerState}',
        );
        if (Platform.isAndroid) {
          AndroidDiagnosticLogger.instance.endStage(
            'Stage 1: File Check & setAudioSource',
            details:
                'duration=${_activePlayer.duration}, state=${_activePlayer.playerState}',
            success: true,
          );
        }
      } else if (isYouTube || isSpotify) {
        // If Spotify track is not yet matched to a playable stream, resolve to YouTube
        if (isSpotify &&
            !song.audioPath.startsWith('http') &&
            song.audioPath.length != 11) {
          if (!isTest) {
            debugPrint(
              '[PLAYER] Dynamically resolving Spotify track "${song.title}" to YouTube stream...',
            );
            final metaTrack = MusicMetadataResult(
              title: song.title,
              artist: song.artistName,
              album: song.albumTitle,
              duration: song.duration,
              artworkUrl: song.cover,
              spotifyId: song.sourceId,
            );
            final resolved = await SpotifyResolverService.instance.resolveTrack(
              metaTrack,
            );
            if (generation != _youtubeResolveGeneration) {
              debugPrint(
                '[PLAYER] Spotify resolution superseded by newer request ($generation != $_youtubeResolveGeneration).',
              );
              return;
            }
            if (resolved == null) {
              throw Exception(
                'Tidak dapat menemukan audio yang dapat diputar untuk lagu Spotify "${song.title}".',
              );
            }
            song = song.copyWith(
              audioPath: resolved.audioPath,
              duration: (resolved.duration > 0)
                  ? resolved.duration
                  : song.duration,
            );
            _currentSong = song;
          }
        }

        if (isTest) {
          _isResolvingYouTube = false;
          _isLoadingSource = false;
          _isPlaying = true;
          _playbackConfirmedSessionId = sessionId;
          debugPrint(
            '[AudioTransition] SourceReady | $transitionId | ${song.title}',
          );
          debugPrint(
            '[AudioTransition] PlayRequested | $transitionId | ${song.title}',
          );
          debugPrint(
            '[AudioTransition] PlaybackConfirmed | $transitionId | playing=true',
          );
          notifyListeners();
          return;
        }

        if (Platform.isWindows) {
          debugPrint(
            '[PLAYER][Windows] Resolving YouTube videoId=${song.audioPath}',
          );
          debugPrint(
            '[AudioTransition] UrlResolutionStart | $transitionId | videoId=${song.audioPath}',
          );
          final streamUrl = await YouTubeResolver.instance
              .resolveAudioStreamUrl(song.audioPath);
          debugPrint(
            '[AudioTransition] UrlResolutionDone | $transitionId | validUrl=${streamUrl.isNotEmpty}',
          );
          if (generation != _youtubeResolveGeneration) {
            debugPrint(
              '[PLAYER] YouTube resolve generation stale ($generation != $_youtubeResolveGeneration). Ignoring result.',
            );
            debugPrint(
              '[AudioTransition] Failed | $transitionId | StaleGeneration | superseded by new request',
            );
            return;
          }
          _isResolvingYouTube = false;
          notifyListeners();

          debugPrint('[PLAYER][Windows] setting stream source on player');
          debugPrint(
            '[AudioTransition] SourceAttached | $transitionId | uri=$streamUrl',
          );
          await _activePlayer.setAudioSource(
            AudioSource.uri(Uri.parse(streamUrl), tag: _buildMediaItem(song)),
          );
        } else if (Platform.isAndroid) {
          debugPrint(
            '[PLAYER][Android] Resolving YouTube videoId=${song.audioPath} (autoNext=$isAutoNext)',
          );
          final ytResolveWatch = Stopwatch()..start();
          final resolveTimeout = isAutoNext
              ? const Duration(seconds: 10)
              : const Duration(seconds: 25);
          final details = await AndroidYouTubeResolver.instance
              .resolveAudioStreamDetails(
                song.audioPath,
                timeout: resolveTimeout,
              );
          debugPrint(
            '[PLAYER][Android] YouTube resolved in ${ytResolveWatch.elapsedMilliseconds}ms',
          );
          if (generation != _youtubeResolveGeneration) {
            debugPrint(
              '[PLAYER] YouTube resolve generation stale ($generation != $_youtubeResolveGeneration). Ignoring result.',
            );
            debugPrint(
              '[AudioTransition] Failed | $transitionId | StaleGeneration | superseded by new request',
            );
            return;
          }
          if (details.duration != null && details.duration! > 0) {
            if (song.duration == 0) {
              song = song.copyWith(duration: details.duration);
            }
            if (_currentSong != null && _currentSong!.duration == 0) {
              _currentSong = _currentSong!.copyWith(duration: details.duration);
              _duration = Duration(seconds: details.duration!);
            }
            if (_notificationPlayerEnabled) {
              MyMusicAudioHandler.instance?.updateCurrentSong(
                _currentSong ?? song,
              );
            }
          }
          _isResolvingYouTube = false;
          notifyListeners();

          debugPrint('[PLAYER][Android] setting stream URL on player');
          final hasHeaders = details.headers.isNotEmpty;
          if (_notificationPlayerEnabled) {
            await _activePlayer.setAudioSource(
              AudioSource.uri(
                Uri.parse(details.url),
                headers: hasHeaders ? details.headers : null,
                tag: _buildMediaItem(song),
              ),
            );
          } else {
            await _activePlayer.setAudioSource(
              AudioSource.uri(
                Uri.parse(details.url),
                headers: hasHeaders ? details.headers : null,
              ),
            );
          }
        } else {
          final streamUrl = await YouTubeService.instance.resolveAudioStreamUrl(
            song,
          );
          if (generation != _youtubeResolveGeneration) {
            debugPrint(
              '[AudioTransition] Failed | $transitionId | StaleGeneration | superseded by new request',
            );
            return;
          }
          _isResolvingYouTube = false;
          notifyListeners();
          await _activePlayer.setUrl(streamUrl);
        }
        debugPrint(
          '[PLAYER] setAudioSourceSuccess duration=${_activePlayer.duration}',
        );
      } else {
        if (isTest) {
          _isLoadingSource = false;
          _isPlaying = true;
          _playbackConfirmedSessionId = sessionId;
          debugPrint(
            '[AudioTransition] SourceReady | $transitionId | ${song.title}',
          );
          debugPrint(
            '[AudioTransition] PlayRequested | $transitionId | ${song.title}',
          );
          debugPrint(
            '[AudioTransition] PlaybackConfirmed | $transitionId | playing=true',
          );
          notifyListeners();
          return;
        }
        final audioUrl = '${ApiConfig.baseUrl}/songs/${song.id}/stream';
        debugPrint('[PLAYER] loading network stream source');
        debugPrint(
          '[AudioTransition] SourceAttached | $transitionId | uri=$audioUrl',
        );
        if (Platform.isAndroid && _notificationPlayerEnabled) {
          await _activePlayer.setAudioSource(
            AudioSource.uri(Uri.parse(audioUrl), tag: _buildMediaItem(song)),
          );
        } else {
          await _activePlayer.setAudioSource(
            AudioSource.uri(Uri.parse(audioUrl), tag: _buildMediaItem(song)),
          );
        }
        debugPrint(
          '[PLAYER] setAudioSourceSuccess duration=${_activePlayer.duration}',
        );
      }

      if (generation != _youtubeResolveGeneration) {
        debugPrint(
          '[PLAYER] Request generation changed before start ($generation != $_youtubeResolveGeneration). Stopping.',
        );
        debugPrint(
          '[AudioTransition] Failed | $transitionId | StaleGeneration | superseded before playback',
        );
        return;
      }

      if (Platform.isAndroid) {
        AndroidDiagnosticLogger.instance.log(
          'CALLING_PREP',
          'generation=$generation, sessionId=$sessionId, source=${song.source}',
        );
      }

      await _prepareAndStartPlayback(
        _activePlayer,
        sessionId: sessionId,
        isTest: isTest,
        transitionId: transitionId,
        trackTitle: song.title,
      );

      if (Platform.isAndroid) {
        AndroidDiagnosticLogger.instance.log(
          'PREP_RETURNED',
          'returned from _prepareAndStartPlayback, isPlaying=$_isPlaying',
        );
      }
      if (Platform.isAndroid && _notificationPlayerEnabled) {
        MyMusicAudioHandler.instance?.updateCurrentSong(_currentSong ?? song);
        MyMusicAudioHandler.instance?.updateQueueList(_queue);
        _syncAudioHandlerPlaybackState(force: true);
      }
      savePlayerState();
    } catch (e, st) {
      if (Platform.isAndroid) {
        AndroidDiagnosticLogger.instance.recordError(
          'PLAYSONG_EXCEPTION',
          e,
          st,
        );
      }
      _isResolvingYouTube = false;
      _isLoadingSource = false;
      _isPlaying = false;
      if (!isTest) {
        try {
          await _activePlayer.stop();
        } catch (_) {}
      }
      notifyListeners();
      if (generation != _youtubeResolveGeneration) return;
      debugPrint('[PLAYER] resolution or playback failed: $e');
      debugPrint(
        '[AudioTransition] Failed | $transitionId | PlaybackException | $e',
      );
      _lastErrorMessage = 'Gagal memutar audio: ${e.toString()}';
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_lastErrorMessage!),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      notifyListeners();

      _consecutiveFailures++;
      // If playing automatically via auto-next and it failed, auto-skip to next track in queue safely without infinite loop
      if (isAutoNext &&
          _queue.length > 1 &&
          _consecutiveFailures < _queue.length) {
        debugPrint(
          '[PLAYER] Auto-skipping failed track to next index ($_consecutiveFailures/${_queue.length}).',
        );
        Future.microtask(() => next(isAutoNext: true));
      }
    } finally {
      if (generation == _youtubeResolveGeneration) {
        _isResolvingYouTube = false;
        _isLoadingSource = false;
        if (Platform.isAndroid) {
          AndroidDiagnosticLogger.instance.log(
            'FINALLY_CLEANUP',
            'sessionId=$sessionId, gen=$generation, isLoadingSource=false',
          );
        }
      }
    }
  }

  Future<void> playQueueIndex(int index, {BuildContext? context}) async {
    if (index >= 0 && index < _queue.length) {
      _currentIndex = index;
      final song = _queue[index];
      await playSong(song, playlist: _queue, context: context);
    }
  }

  Future<void> setQueueAndPlay(
    List<SongModel> songs, {
    int initialIndex = 0,
    BuildContext? context,
  }) async {
    if (songs.isEmpty) return;
    final index = initialIndex.clamp(0, songs.length - 1);
    await playSong(songs[index], playlist: songs, context: context);
  }

  @visibleForTesting
  void setQueueForTest(List<SongModel> songs, {int initialIndex = 0}) {
    _queue = List.from(songs);
    _currentIndex = initialIndex.clamp(0, _queue.length - 1);
    if (_queue.isNotEmpty) {
      _currentSong = _queue[_currentIndex];
    }
  }

  Future<void> pause() async {
    _cancelCrossfade();
    _isPlaying = false;
    notifyListeners();
    await _activePlayer.pause();
    _syncAudioHandlerPlaybackState(force: true);
    savePlayerState();
  }

  Future<void> resume() async {
    await _ensureSourceReady(_activePlayer);
    // Same audio-session race as _prepareAndStartPlayback: play() re-checks
    // its `playing` flag after awaiting session round trips, and a stale
    // engine broadcast inside that window would silently drop the request.
    await _warmAudioSessionBeforePlayback();
    // On Windows just_audio_windows_plus completes the play() future only
    // when playback pauses or ends, so awaiting it here would stall this
    // future (and the sync/save below) until the track finishes. Issue the
    // request without awaiting completion; playerStateStream reflects the
    // resulting playing state.
    unawaited(
      _activePlayer.play().catchError((Object e, StackTrace st) {
        debugPrint('[PLAYER] resume() play() request failed: $e');
      }),
    );
    _isPlaying = true;
    _syncAudioHandlerPlaybackState(force: true);
    savePlayerState();
  }

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await pause();
    } else {
      await resume();
    }
  }

  Future<void> seek(Duration position) async {
    _position = position;
    notifyListeners();
    await _activePlayer.seek(position);
    _syncAudioHandlerPlaybackState(force: true);
  }

  Future<void> stop() async {
    _cancelCrossfade();
    _isLoadingSource = false;
    _isPlaying = false;
    _position = Duration.zero;
    _maxObservedPositionMs = 0;
    await _activePlayer.stop();
    await _fadePlayer.stop();
    _syncAudioHandlerPlaybackState(force: true);
    notifyListeners();
  }

  Future<void> next({bool isTest = false, bool isAutoNext = false}) async {
    _cancelCrossfade();
    if (_queue.isEmpty || _currentIndex == -1) return;

    if (_isTransitionInFlight && isAutoNext && _consecutiveFailures == 0) {
      debugPrint(
        '[AudioTransition] AutoNextIgnored | reason=transitionInFlight | transition already in progress.',
      );
      return;
    }

    if (_stopAfterCurrentSong ||
        (_sleepTimerEndTime != null &&
            DateTime.now().isAfter(_sleepTimerEndTime!))) {
      debugPrint(
        '[AudioTransition] AutoNextStopped | reason=stopAfterCurrentSong/sleepTimer | autoNext=$isAutoNext | pausing instead of advancing.',
      );
      _stopAfterCurrentSong = false;
      _sleepTimerEndTime = null;
      _sleepTimerTicker?.cancel();
      _saveAudioSettings();
      if (!isTest) await pause();
      notifyListeners();
      return;
    }

    if (!isAutoNext) {
      _consecutiveFailures = 0;
    }

    if (!isTest && !isAutoNext) {
      await _sendHistoryRecord(skipped: true);
    }

    if (_repeatMode == AppRepeatMode.one) {
      if (!isTest) {
        await seek(Duration.zero);
        await resume();
      }
      return;
    }

    if (_repeatMode == AppRepeatMode.count) {
      if (_remainingRepeatCount > 0) {
        _remainingRepeatCount--;
        notifyListeners();
        if (!isTest) {
          await seek(Duration.zero);
          await resume();
        }
        return;
      } else {
        _remainingRepeatCount = _targetRepeatCount;
      }
    }

    if (_isShuffle) {
      final availableIndexes = <int>[];
      for (int i = 0; i < _queue.length; i++) {
        if (i != _currentIndex) {
          availableIndexes.add(i);
        }
      }

      if (availableIndexes.isNotEmpty) {
        _currentIndex =
            availableIndexes[Random().nextInt(availableIndexes.length)];
      } else {
        if (_repeatMode == AppRepeatMode.forever || _loopMode == LoopMode.all) {
          _currentIndex = 0;
        } else {
          _currentIndex = _queue.length - 1;
          debugPrint(
            '[AudioTransition] QueueEnded | index=$_currentIndex | queueLength=${_queue.length} | autoNext=$isAutoNext | shuffle: no other track available; pausing.',
          );
          if (!isTest) await pause();
          return;
        }
      }
    } else {
      _currentIndex++;
      if (_currentIndex >= _queue.length) {
        if (_repeatMode == AppRepeatMode.forever || _loopMode == LoopMode.all) {
          _currentIndex = 0;
        } else {
          _currentIndex = _queue.length - 1;
          debugPrint(
            '[AudioTransition] QueueEnded | index=$_currentIndex | queueLength=${_queue.length} | autoNext=$isAutoNext | end of queue; pausing.',
          );
          if (!isTest) await pause();
          return;
        }
      }
    }

    _remainingRepeatCount = _targetRepeatCount;
    _currentSong = _queue[_currentIndex];
    final selectedTrack = _queue[_currentIndex];
    debugPrint(
      '[AudioTransition] TrackSelected | ${_currentTransitionId ?? "tr_next"} | index=$_currentIndex | ${selectedTrack.title} | autoNext=$isAutoNext',
    );
    notifyListeners();

    _isTransitionInFlight = true;
    try {
      await playSong(
        selectedTrack,
        playlist: _queue,
        isAutoNext: isAutoNext,
        isTest: isTest,
      );
    } finally {
      _isTransitionInFlight = false;
    }
  }

  Future<void> previous({bool isTest = false}) async {
    _cancelCrossfade();
    if (_queue.isEmpty || _currentIndex == -1) return;

    if (!isTest && _position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }

    if (!isTest) {
      await _sendHistoryRecord(skipped: true);
    }
    _currentIndex--;
    if (_currentIndex < 0) {
      if (_repeatMode == AppRepeatMode.forever || _loopMode == LoopMode.all) {
        _currentIndex = _queue.length - 1;
      } else {
        _currentIndex = 0;
      }
    }

    _remainingRepeatCount = _targetRepeatCount;
    _currentSong = _queue[_currentIndex];
    notifyListeners();
    if (!isTest) {
      await playSong(_queue[_currentIndex], playlist: _queue);
    }
  }

  bool get isHandlingAutoNext => _autoNextInFlightTrackId != null;

  void _handleAutoNext({int? completedSessionId, SongModel? completedSong}) {
    final trackKey =
        '${completedSessionId ?? _activeSessionId}_${completedSong?.id ?? _currentSong?.id}';
    if (_autoNextInFlightTrackId == trackKey) {
      debugPrint(
        '[PLAYER] Auto-next already in flight for $trackKey. Skipping duplicate trigger.',
      );
      return;
    }
    _autoNextInFlightTrackId = trackKey;
    debugPrint(
      '[PLAYER] auto-next triggered for track $trackKey ("${completedSong?.title ?? _currentSong?.title}")',
    );

    final transitionId = _currentTransitionId;
    if (transitionId != null) {
      debugPrint(
        '[AudioTransition] AutoNextTriggered | $transitionId | track=$trackKey',
      );
    }

    // In test mode (isTest flows), keep the listener-driven auto-next hermetic:
    // production never sets _isTestMode, so this is a no-op outside tests.
    next(isAutoNext: true, isTest: _isTestMode).whenComplete(() {
      if (_autoNextInFlightTrackId == trackKey) {
        _autoNextInFlightTrackId = null;
      }
    });
  }

  @visibleForTesting
  Future<void> simulateAutoNextForTest() async {
    _sendHistoryRecord(completed: true);
    await next(isTest: true, isAutoNext: true);
  }

  Future<void> toggleFavorite(SongModel song) async {
    final newFav = !song.isFavorite;

    if (_currentSong?.id == song.id) {
      _currentSong = _currentSong!.copyWith(isFavorite: newFav);
    }
    for (int i = 0; i < _queue.length; i++) {
      if (_queue[i].id == song.id) {
        _queue[i] = _queue[i].copyWith(isFavorite: newFav);
      }
    }
    notifyListeners();

    try {
      final repo = LocalMusicRepository();
      await repo.toggleFavorite(song.id);
    } catch (e) {
      debugPrint('Gagal update favorit ke database: $e');
    }
  }

  void setVolume(double vol) {
    _volume = vol.clamp(0.0, 1.0);
    _isMuted = _volume == 0;
    if (!_isCrossfading) {
      _activePlayer.setVolume(_volume);
    }
    notifyListeners();
    savePlayerState();
  }

  void toggleMute() {
    if (_isMuted) {
      _isMuted = false;
      _activePlayer.setVolume(_volume > 0 ? _volume : 1.0);
    } else {
      _isMuted = true;
      _activePlayer.setVolume(0);
    }
    notifyListeners();
  }

  void toggleShuffle() {
    if (_queue.isEmpty) return;

    if (_isShuffle) {
      if (_shuffleOriginalQueue.isNotEmpty) {
        _queue = List.from(_shuffleOriginalQueue);
        _currentIndex = _shuffleOriginalIndex >= 0
            ? _shuffleOriginalIndex
            : (_currentSong != null
                  ? _queue.indexWhere((song) => song.id == _currentSong!.id)
                  : 0);
      }
      _isShuffle = false;
      _shuffleOriginalQueue = [];
      _shuffleOriginalIndex = -1;
    } else {
      _shuffleOriginalQueue = List.from(_queue);
      _shuffleOriginalIndex = _currentIndex;
      final currentSong =
          _currentSong ?? (_currentIndex >= 0 ? _queue[_currentIndex] : null);

      if (currentSong != null && _currentIndex >= 0) {
        final beforeCurrent = _currentIndex > 0
            ? _queue.sublist(0, _currentIndex)
            : <SongModel>[];
        final remaining = _queue
            .where((song) => song.id != currentSong.id)
            .toList();
        remaining.shuffle();
        _queue = [...beforeCurrent, currentSong, ...remaining];
        _currentIndex = beforeCurrent.length;
      } else {
        final shuffled = List<SongModel>.from(_queue);
        shuffled.shuffle();
        _queue = shuffled;
        _currentIndex = 0;
      }
      _isShuffle = true;
    }

    savePlayerQueue();
    notifyListeners();
    savePlayerState();
  }

  void setRepeatMode(AppRepeatMode mode, {int count = 1}) {
    _repeatMode = mode;
    _targetRepeatCount = count;
    _remainingRepeatCount = count;

    if (mode == AppRepeatMode.one) {
      _loopMode = LoopMode.one;
    } else if (mode == AppRepeatMode.forever) {
      _loopMode = LoopMode.all;
    } else {
      _loopMode = LoopMode.off;
    }
    notifyListeners();
    savePlayerState();
  }

  void toggleRepeat() {
    if (_repeatMode == AppRepeatMode.off) {
      setRepeatMode(AppRepeatMode.one);
    } else if (_repeatMode == AppRepeatMode.one) {
      setRepeatMode(AppRepeatMode.forever);
    } else {
      setRepeatMode(AppRepeatMode.off);
    }
  }

  void addToQueue(SongModel song, {bool playNext = false}) {
    if (_queue.isEmpty && _currentSong == null) {
      _queue.add(song);
      if (_isShuffle) _shuffleOriginalQueue.add(song);
      _currentIndex = 0;
      _currentSong = song;
      savePlayerQueue();
      notifyListeners();
      return;
    }

    if (playNext) {
      final insertIndex =
          (_currentIndex >= 0 ? _currentIndex + 1 : _queue.length).clamp(
            0,
            _queue.length,
          );
      _queue.insert(insertIndex, song);
      if (_isShuffle) {
        _shuffleOriginalQueue.insert(
          insertIndex.clamp(0, _shuffleOriginalQueue.length),
          song,
        );
      }
    } else {
      _queue.add(song);
      if (_isShuffle) _shuffleOriginalQueue.add(song);
    }

    if (_currentIndex == -1 && _queue.isNotEmpty) {
      _currentIndex = 0;
      _currentSong = _queue[0];
    }

    savePlayerQueue();
    notifyListeners();
  }

  void playNext(SongModel song) {
    addToQueue(song, playNext: true);
  }

  Future<void> playAll(List<SongModel> songs, {BuildContext? context}) async {
    if (songs.isEmpty) return;
    await playSong(songs.first, playlist: songs, context: context);
  }

  void addAllToQueue(List<SongModel> songs) {
    for (final song in songs) {
      addToQueue(song);
    }
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= _queue.length) return;

    final removedSong = _queue.removeAt(index);
    if (_isShuffle) {
      final origIndex = _shuffleOriginalQueue.indexWhere(
        (s) => s.id == removedSong.id,
      );
      if (origIndex != -1) _shuffleOriginalQueue.removeAt(origIndex);
    }

    final isCurrentSong =
        _currentSong != null && removedSong.id == _currentSong!.id;

    if (_queue.isEmpty) {
      _currentIndex = -1;
      _currentSong = null;
      _activePlayer.stop();
      _fadePlayer.stop();
      if (Platform.isAndroid && _notificationPlayerEnabled) {
        MyMusicAudioHandler.instance?.updateCurrentSong(null);
        MyMusicAudioHandler.instance?.updateQueueList([]);
        _syncAudioHandlerPlaybackState(force: true);
      }
      savePlayerQueue();
      notifyListeners();
      return;
    }

    if (isCurrentSong) {
      _currentIndex = index.clamp(0, _queue.length - 1);
      _currentSong = _queue[_currentIndex];
      if (Platform.isAndroid && _notificationPlayerEnabled) {
        MyMusicAudioHandler.instance?.updateCurrentSong(_currentSong);
        MyMusicAudioHandler.instance?.updateQueueList(_queue);
        _syncAudioHandlerPlaybackState(force: true);
      }
    } else if (_currentIndex > index) {
      _currentIndex--;
    } else if (_currentIndex >= _queue.length) {
      _currentIndex = _queue.length - 1;
    }

    savePlayerQueue();
    notifyListeners();
  }

  void clearQueue() {
    if (_currentSong != null) {
      _queue = [_currentSong!];
      _currentIndex = 0;
      if (_isShuffle) {
        _shuffleOriginalQueue = [_currentSong!];
        _shuffleOriginalIndex = 0;
      }
    } else {
      _queue.clear();
      _shuffleOriginalQueue.clear();
      _currentIndex = -1;
      _shuffleOriginalIndex = -1;
      _activePlayer.stop();
      _fadePlayer.stop();
    }
    savePlayerQueue();
    notifyListeners();
  }

  void updateSongMetadata(SongModel updatedSong) {
    if (_currentSong?.id == updatedSong.id) {
      _currentSong = updatedSong;
      if (Platform.isAndroid && _notificationPlayerEnabled) {
        MyMusicAudioHandler.instance?.updateCurrentSong(_currentSong);
        MyMusicAudioHandler.instance?.updateQueueList(_queue);
        _syncAudioHandlerPlaybackState(force: true);
      }
    }
    for (int i = 0; i < _queue.length; i++) {
      if (_queue[i].id == updatedSong.id) {
        _queue[i] = updatedSong;
      }
    }
    for (int i = 0; i < _shuffleOriginalQueue.length; i++) {
      if (_shuffleOriginalQueue[i].id == updatedSong.id) {
        _shuffleOriginalQueue[i] = updatedSong;
      }
    }
    notifyListeners();
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _queue.length) return;
    if (newIndex < 0) newIndex = 0;
    if (newIndex > _queue.length) newIndex = _queue.length;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    if (oldIndex == newIndex) return;

    final song = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, song);

    if (_currentIndex == oldIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex--;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex++;
    }

    if (_isShuffle && _shuffleOriginalQueue.isNotEmpty) {
      final origOldIndex = _shuffleOriginalQueue.indexWhere(
        (s) => s.id == song.id,
      );
      if (origOldIndex != -1) {
        final origSong = _shuffleOriginalQueue.removeAt(origOldIndex);
        _shuffleOriginalQueue.add(origSong);
      }
    }

    savePlayerQueue();
    notifyListeners();
  }

  Future<void> savePlayerState() async {
    if (_currentSong == null) return;
    try {
      final repModeStr = _repeatMode == AppRepeatMode.one
          ? 'one'
          : (_repeatMode == AppRepeatMode.forever
                ? 'forever'
                : (_repeatMode == AppRepeatMode.count
                      ? 'count_$_targetRepeatCount'
                      : 'off'));
      final repo = LocalMusicRepository();
      await repo.savePlayerState(
        currentSongId: _currentSong?.id,
        positionSeconds: _position.inSeconds,
        isPlaying: _isPlaying,
        isShuffle: _isShuffle,
        repeatMode: repModeStr,
        volume: _volume,
      );
    } catch (e) {
      debugPrint('Gagal simpan player state ke DB lokal: $e');
    }
  }

  Future<void> savePlayerQueue() async {
    try {
      final songIds = _queue.map((s) => s.id).whereType<int>().toList();
      final repo = LocalMusicRepository();
      await repo.savePlayerQueue(songIds);
    } catch (e) {
      debugPrint('Gagal simpan player queue ke DB lokal: $e');
    }
  }

  Future<void> restorePlayerState() async {
    try {
      final repo = LocalMusicRepository();
      final data = await repo.getPlayerState();
      int savedPosition = 0;

      if (data != null) {
        _volume = double.parse((data['volume'] ?? 1.0).toString());
        _isShuffle = data['is_shuffle'] == 1 || data['is_shuffle'] == true;
        savedPosition = data['position_seconds'] as int? ?? 0;
        final rep = data['repeat_mode']?.toString();
        if (rep == 'one') {
          setRepeatMode(AppRepeatMode.one);
        } else if (rep == 'forever' || rep == 'all') {
          setRepeatMode(AppRepeatMode.forever);
        } else if (rep != null && rep.startsWith('count_')) {
          final cnt = int.tryParse(rep.split('_').last) ?? 1;
          setRepeatMode(AppRepeatMode.count, count: cnt);
        } else {
          setRepeatMode(AppRepeatMode.off);
        }

        final songId = data['current_song_id'] as int?;
        if (songId != null) {
          final songs = await repo.getAllSongs();
          final candidate = songs.firstWhere(
            (s) => s.id == songId,
            orElse: () => songs.first,
          );
          final localPath = candidate.filePath ?? candidate.audioPath;
          final isOnline =
              candidate.source == 'youtube' ||
              candidate.source == 'spotify' ||
              candidate.isOnline;
          final isLocal =
              !isOnline &&
              (candidate.source == 'local' ||
                  candidate.filePath != null ||
                  File(candidate.audioPath).existsSync());

          if (!isLocal || File(localPath).existsSync()) {
            _currentSong = candidate;
          }
        }
      }

      final queuedSongs = await repo.getPlayerQueue();
      // Filter out deleted local files from queue for safety
      final validQueue = <SongModel>[];
      for (final s in queuedSongs) {
        final isOnline =
            s.source == 'youtube' || s.source == 'spotify' || s.isOnline;
        final isLocal =
            !isOnline &&
            (s.source == 'local' ||
                s.filePath != null ||
                File(s.audioPath).existsSync());
        final localPath = s.filePath ?? s.audioPath;
        if (!isLocal || File(localPath).existsSync()) {
          validQueue.add(s);
        }
      }

      if (validQueue.isNotEmpty) {
        _queue = validQueue;
        if (_currentSong != null) {
          _currentIndex = _queue.indexWhere((s) => s.id == _currentSong!.id);
          if (_currentIndex == -1) {
            _currentSong = _queue.first;
            _currentIndex = 0;
          }
        } else {
          _currentSong = _queue.first;
          _currentIndex = 0;
        }
      } else if (_currentSong != null) {
        _queue = [_currentSong!];
        _currentIndex = 0;
      }

      if (_currentSong != null) {
        final durSeconds = _currentSong!.duration;
        if (durSeconds > 0 && savedPosition > durSeconds) {
          _position = Duration(seconds: durSeconds);
        } else if (savedPosition > 0) {
          _position = Duration(seconds: savedPosition);
        }

        if (Platform.isAndroid && _notificationPlayerEnabled) {
          MyMusicAudioHandler.instance?.updateCurrentSong(_currentSong);
          MyMusicAudioHandler.instance?.updateQueueList(_queue);
          _syncAudioHandlerPlaybackState(force: true);
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Gagal pulihkan state player dari DB lokal: $e');
    }
  }

  // --- EQUALIZER METHODS ---
  Future<void> _applyEqualizerGains({int? sessionId}) async {
    if (!isEqualizerSupported) return;
    final prefix = sessionId != null ? 'session=$sessionId | ' : '';
    try {
      if (Platform.isAndroid) {
        AndroidDiagnosticLogger.instance.log(
          'EQ_APPLY_START',
          '${prefix}currentBands=$currentBands, enabled=$_equalizerEnabled',
        );
      }
      final bands = currentBands;

      // Determine which players need equalizer configuration
      final shouldApplyA =
          _activePlayerRef == null ||
          _activePlayerRef == _audioPlayerA ||
          _isCrossfading;
      final shouldApplyB = _activePlayerRef == _audioPlayerB || _isCrossfading;

      if (shouldApplyA) {
        if (Platform.isAndroid) {
          AndroidDiagnosticLogger.instance.log(
            'EQ_PARAM_A_WAIT',
            '${prefix}requesting _equalizerA.parameters',
          );
        }
        final paramsA = await _equalizerA.parameters.timeout(
          const Duration(seconds: 2),
          onTimeout: () =>
              throw TimeoutException('_equalizerA.parameters timeout (2s)'),
        );
        if (Platform.isAndroid) {
          AndroidDiagnosticLogger.instance.log(
            'EQ_PARAM_A_OK',
            '${prefix}received ${paramsA.bands.length} bands on EQ_A',
          );
        }
        for (int i = 0; i < paramsA.bands.length && i < bands.length; i++) {
          await paramsA.bands[i]
              .setGain(bands[i])
              .timeout(
                const Duration(seconds: 1),
                onTimeout: () =>
                    throw TimeoutException('setGain($i) timeout on EQ_A'),
              );
        }
        if (Platform.isAndroid) {
          AndroidDiagnosticLogger.instance.log(
            'EQ_ENABLE_A_WAIT',
            '${prefix}setting _equalizerA.setEnabled($_equalizerEnabled)',
          );
        }
        await _equalizerA
            .setEnabled(_equalizerEnabled)
            .timeout(
              const Duration(seconds: 2),
              onTimeout: () =>
                  throw TimeoutException('setEnabled timeout on EQ_A'),
            );
        if (Platform.isAndroid) {
          AndroidDiagnosticLogger.instance.log(
            'EQ_A_OK',
            '${prefix}EQ_A configuration applied successfully',
          );
        }
      }

      // EQ_B is only active if crossfade player is in use / initialized on native
      if (shouldApplyB) {
        if (Platform.isAndroid) {
          AndroidDiagnosticLogger.instance.log(
            'EQ_PARAM_B_WAIT',
            '${prefix}requesting _equalizerB.parameters',
          );
        }
        final paramsB = await _equalizerB.parameters.timeout(
          const Duration(seconds: 2),
          onTimeout: () =>
              throw TimeoutException('_equalizerB.parameters timeout (2s)'),
        );
        if (Platform.isAndroid) {
          AndroidDiagnosticLogger.instance.log(
            'EQ_PARAM_B_OK',
            '${prefix}received ${paramsB.bands.length} bands on EQ_B',
          );
        }
        for (int i = 0; i < paramsB.bands.length && i < bands.length; i++) {
          await paramsB.bands[i]
              .setGain(bands[i])
              .timeout(
                const Duration(seconds: 1),
                onTimeout: () =>
                    throw TimeoutException('setGain($i) timeout on EQ_B'),
              );
        }
        if (Platform.isAndroid) {
          AndroidDiagnosticLogger.instance.log(
            'EQ_ENABLE_B_WAIT',
            '${prefix}setting _equalizerB.setEnabled($_equalizerEnabled)',
          );
        }
        await _equalizerB
            .setEnabled(_equalizerEnabled)
            .timeout(
              const Duration(seconds: 2),
              onTimeout: () =>
                  throw TimeoutException('setEnabled timeout on EQ_B'),
            );
        if (Platform.isAndroid) {
          AndroidDiagnosticLogger.instance.log(
            'EQ_B_OK',
            '${prefix}EQ_B configuration applied successfully',
          );
        }
      }
    } catch (e, st) {
      debugPrint('Gagal menerapkan gain EQ: $e');
      if (Platform.isAndroid) {
        AndroidDiagnosticLogger.instance.recordError(
          'EQ_APPLY_ERROR',
          '$prefix$e',
          st,
        );
      }
    }
  }

  void setEqualizerEnabled(bool enabled) {
    if (!isEqualizerSupported) return;
    _equalizerEnabled = enabled;
    _applyEqualizerGains();
    _saveAudioSettings();
    notifyListeners();
  }

  void setEqualizerPreset(String preset) {
    _equalizerPreset = preset;
    _applyEqualizerGains();
    _saveAudioSettings();
    notifyListeners();
  }

  void setCustomBandValue(int index, double gainDb) {
    if (index >= 0 && index < 5) {
      _equalizerPreset = 'Custom';
      _customBands[index] = gainDb.clamp(-12.0, 12.0);
      _applyEqualizerGains();
      _saveAudioSettings();
      notifyListeners();
    }
  }

  void resetEqualizer() {
    _equalizerEnabled = true;
    _equalizerPreset = 'Flat';
    _customBands = [0.0, 0.0, 0.0, 0.0, 0.0];
    _applyEqualizerGains();
    _saveAudioSettings();
    notifyListeners();
  }

  // --- PLAYBACK SPEED METHODS ---
  Future<void> setPlaybackSpeed(double speed) async {
    _playbackSpeed = speed.clamp(0.5, 2.0);
    try {
      await _activePlayer.setSpeed(_playbackSpeed);
      await _fadePlayer.setSpeed(_playbackSpeed);
    } catch (e) {
      debugPrint('Gagal mengubah playback speed: $e');
    }
    await _saveAudioSettings();
    notifyListeners();
  }

  // --- SLEEP TIMER METHODS ---
  void setSleepTimer(Duration? duration, {bool stopAfterCurrent = false}) {
    _sleepTimerTicker?.cancel();
    _stopAfterCurrentSong = stopAfterCurrent;

    if (stopAfterCurrent) {
      _sleepTimerEndTime = null;
    } else if (duration != null) {
      _sleepTimerEndTime = DateTime.now().add(duration);
      _startSleepTimerTicker();
    } else {
      _sleepTimerEndTime = null;
    }

    _saveAudioSettings();
    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepTimerTicker?.cancel();
    _sleepTimerEndTime = null;
    _stopAfterCurrentSong = false;
    _saveAudioSettings();
    notifyListeners();
  }

  void _startSleepTimerTicker() {
    _sleepTimerTicker?.cancel();
    _sleepTimerTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_sleepTimerEndTime != null) {
        if (DateTime.now().isAfter(_sleepTimerEndTime!)) {
          timer.cancel();
          _sleepTimerEndTime = null;
          _stopAfterCurrentSong = false;
          pause();
          _saveAudioSettings();
        }
        notifyListeners();
      } else {
        timer.cancel();
      }
    });
  }

  // --- CROSSFADE & GAPLESS METHODS ---
  void setCrossfadeDuration(int seconds) {
    _crossfadeDuration = seconds.clamp(0, 12);
    _saveAudioSettings();
    notifyListeners();
  }

  void setGaplessEnabled(bool enabled) {
    _gaplessEnabled = enabled;
    _saveAudioSettings();
    notifyListeners();
  }

  // --- AUDIO SETTINGS PERSISTENCE ---
  Future<void> _loadAudioSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _equalizerEnabled = prefs.getBool('eq_enabled') ?? false;
      _equalizerPreset = prefs.getString('eq_preset') ?? 'Flat';
      final bandsList = prefs.getStringList('eq_custom_bands');
      if (bandsList != null && bandsList.length == 5) {
        _customBands = bandsList.map((s) => double.tryParse(s) ?? 0.0).toList();
      }
      _playbackSpeed = prefs.getDouble('playback_speed') ?? 1.0;
      _crossfadeDuration = prefs.getInt('crossfade_duration') ?? 0;
      _gaplessEnabled = prefs.getBool('gapless_enabled') ?? true;
      _dynamicBackgroundEnabled = prefs.getBool('dynamic_bg_enabled') ?? true;
      _visualizerEnabled = prefs.getBool('visualizer_enabled') ?? true;
      _waveformSeekEnabled = prefs.getBool('waveform_seek_enabled') ?? true;
      _resumePlaybackEnabled = prefs.getBool('resume_playback_enabled') ?? true;
      _pauseOnHeadphoneDisconnect =
          prefs.getBool('pause_on_headphone_disconnect') ?? true;
      _notificationPlayerEnabled =
          prefs.getBool('notification_player_enabled') ?? true;

      _stopAfterCurrentSong = prefs.getBool('stop_after_current_song') ?? false;
      final endEpoch = prefs.getInt('sleep_timer_end_epoch');
      if (endEpoch != null) {
        final endTime = DateTime.fromMillisecondsSinceEpoch(endEpoch);
        if (endTime.isAfter(DateTime.now())) {
          _sleepTimerEndTime = endTime;
          _startSleepTimerTicker();
        } else {
          prefs.remove('sleep_timer_end_epoch');
        }
      }

      await _activePlayer.setSpeed(_playbackSpeed);
      await _fadePlayer.setSpeed(_playbackSpeed);
      if (isEqualizerSupported) {
        await _applyEqualizerGains();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Gagal memuat pengaturan audio: $e');
    }
  }

  Future<void> _saveAudioSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('eq_enabled', _equalizerEnabled);
      await prefs.setString('eq_preset', _equalizerPreset);
      await prefs.setStringList(
        'eq_custom_bands',
        _customBands.map((b) => b.toString()).toList(),
      );
      await prefs.setDouble('playback_speed', _playbackSpeed);
      await prefs.setInt('crossfade_duration', _crossfadeDuration);
      await prefs.setBool('gapless_enabled', _gaplessEnabled);
      await prefs.setBool('dynamic_bg_enabled', _dynamicBackgroundEnabled);
      await prefs.setBool('visualizer_enabled', _visualizerEnabled);
      await prefs.setBool('waveform_seek_enabled', _waveformSeekEnabled);
      await prefs.setBool('resume_playback_enabled', _resumePlaybackEnabled);
      await prefs.setBool(
        'pause_on_headphone_disconnect',
        _pauseOnHeadphoneDisconnect,
      );
      await prefs.setBool(
        'notification_player_enabled',
        _notificationPlayerEnabled,
      );
      await prefs.setBool('stop_after_current_song', _stopAfterCurrentSong);
      if (_sleepTimerEndTime != null) {
        await prefs.setInt(
          'sleep_timer_end_epoch',
          _sleepTimerEndTime!.millisecondsSinceEpoch,
        );
      } else {
        await prefs.remove('sleep_timer_end_epoch');
      }
    } catch (e) {
      debugPrint('Gagal menyimpan pengaturan audio: $e');
    }
  }

  @override
  void dispose() {
    // Detach player streams first: events already queued by the platform must
    // not call notifyListeners() after this provider is disposed.
    for (final subscription in _playerSubscriptions) {
      subscription.cancel();
    }
    _playerSubscriptions.clear();
    _sendHistoryRecord();
    _sleepTimerTicker?.cancel();
    _crossfadeTimer?.cancel();
    _audioPlayerA.dispose();
    _audioPlayerB.dispose();
    super.dispose();
  }
}
