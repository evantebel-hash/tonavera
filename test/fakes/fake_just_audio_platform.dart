import 'dart:async';

import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

/// In-memory implementation of the just_audio platform interface that mirrors
/// the observable behavior of `just_audio_windows_plus` (WinRT MediaPlayer):
///
/// * `load()` resolves only after a ready broadcast (native `Opened()`), and
///   reports the configured media duration.
/// * `play()` does NOT complete until pause/stop/dispose/end-of-media — the
///   native Windows plugin defers its result exactly like this.
/// * A natural end ([emitNaturalEnd]) broadcasts `completed` and leaves the
///   player-data `playing` flag at `true` (native `playing_` is untouched by
///   `MediaEnded`).
/// * A failure ([emitEndFailure]) broadcasts `idle` plus `errorCode`/`errorMessage`
///   (native `Fail()` maps to index 0 == `ProcessingStateMessage.idle`).
///
/// Tests observe which source was attached ([loadedSources]) and how often
/// playback was requested ([playRequests]) to assert observable behavior.
class FakeJustAudioPlatform extends JustAudioPlatform {
  FakeJustAudioPlatform({this.defaultDuration = const Duration(seconds: 180)});

  /// Duration reported for every loaded source.
  final Duration defaultDuration;

  /// Every player ever initialized (including disposed ones).
  final List<FakeAudioPlayerPlatform> players = <FakeAudioPlayerPlatform>[];

  /// When true, `load()` neither resolves nor emits ready — models a native
  /// load that hangs (WinRT never opens nor fails the source).
  bool hangLoads = false;

  /// When > 0, the next N `load()` calls fail with an exception — models a
  /// source that cannot be opened (bad/expired stream URL). Decremented per
  /// failure so tests can fail exactly one source in a queue.
  int failLoadsRemaining = 0;

  /// Players that have not been disposed yet.
  List<FakeAudioPlayerPlatform> get livePlayers =>
      players.where((p) => !p.disposedFlag).toList();

  /// The single live player; throws if the app did not converge to exactly
  /// one active engine (which is what the provider's stop-then-load flow
  /// must produce).
  FakeAudioPlayerPlatform get livePlayer {
    final live = livePlayers;
    if (live.length != 1) {
      throw StateError('Expected exactly 1 live player, found ${live.length}');
    }
    return live.single;
  }

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    final player = FakeAudioPlayerPlatform(
      request.id,
      defaultDuration: defaultDuration,
      hangLoad: () => hangLoads,
      failLoad: () {
        if (failLoadsRemaining > 0) {
          failLoadsRemaining--;
          return true;
        }
        return false;
      },
    );
    players.add(player);
    return player;
  }

  @override
  Future<DisposePlayerResponse> disposePlayer(
      DisposePlayerRequest request) async {
    for (final player
        in players.where((p) => p.id == request.id && !p.disposedFlag)) {
      player.disposeFromPlatform();
    }
    return DisposePlayerResponse();
  }

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(
      DisposeAllPlayersRequest request) async {
    for (final player in players.where((p) => !p.disposedFlag)) {
      player.disposeFromPlatform();
    }
    return DisposeAllPlayersResponse();
  }
}

class FakeAudioPlayerPlatform extends AudioPlayerPlatform {
  FakeAudioPlayerPlatform(
    super.id, {
    required this.defaultDuration,
    required this.hangLoad,
    required this.failLoad,
  });

  final Duration defaultDuration;
  final bool Function() hangLoad;
  final bool Function() failLoad;

  final StreamController<PlaybackEventMessage> _events =
      StreamController<PlaybackEventMessage>.broadcast();
  final StreamController<PlayerDataMessage> _data =
      StreamController<PlayerDataMessage>.broadcast();

  /// Source URIs (or file URIs) attached via [load], in order.
  final List<String> loadedSources = <String>[];

  Duration mediaDuration = Duration.zero;
  Duration position = Duration.zero;
  bool enginePlaying = false;
  bool disposedFlag = false;
  int loadRequests = 0;
  int playRequests = 0;

  Completer<void>? _pendingPlay;
  Completer<LoadResponse>? _pendingLoad;

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream => _events.stream;

  @override
  Stream<PlayerDataMessage> get playerDataMessageStream => _data.stream;

  String get lastLoadedSource =>
      loadedSources.isEmpty ? '' : loadedSources.last;

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    loadRequests++;
    loadedSources.add(_describe(request.audioSourceMessage));
    if (hangLoad()) {
      final pending = Completer<LoadResponse>();
      _pendingLoad = pending;
      return pending.future;
    }
    if (failLoad()) {
      throw Exception('Fake engine: failed to open '
          '${request.audioSourceMessage.runtimeType}');
    }
    mediaDuration = defaultDuration;
    position = Duration.zero;
    // Native Load() broadcasts loading, then Opened() broadcasts ready and
    // only then resolves the pending load result.
    _emit(ProcessingStateMessage.loading);
    _emit(ProcessingStateMessage.ready);
    return LoadResponse(duration: mediaDuration);
  }

  @override
  Future<PlayResponse> play(PlayRequest request) async {
    playRequests++;
    enginePlaying = true;
    _data.add(PlayerDataMessage(playing: true));
    // Native play broadcasts current state immediately (idle when no source
    // is attached yet because activation can auto-play before load).
    _emit(loadedSources.isEmpty ? ProcessingStateMessage.idle : null);
    // Windows: the result is deferred until pause/stop/dispose/end-of-media.
    _pendingPlay ??= Completer<void>();
    await _pendingPlay!.future;
    return PlayResponse();
  }

  @override
  Future<PauseResponse> pause(PauseRequest request) async {
    enginePlaying = false;
    _data.add(PlayerDataMessage(playing: false));
    _completePlay();
    return PauseResponse();
  }

  @override
  Future<SeekResponse> seek(SeekRequest request) async {
    if (request.position != null) position = request.position!;
    _emit(ProcessingStateMessage.ready);
    return SeekResponse();
  }

  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async =>
      SetVolumeResponse();

  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async =>
      SetSpeedResponse();

  @override
  Future<SetPitchResponse> setPitch(SetPitchRequest request) async =>
      SetPitchResponse();

  @override
  Future<SetSkipSilenceResponse> setSkipSilence(
          SetSkipSilenceRequest request) async =>
      SetSkipSilenceResponse();

  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async =>
      SetLoopModeResponse();

  @override
  Future<SetShuffleModeResponse> setShuffleMode(
          SetShuffleModeRequest request) async =>
      SetShuffleModeResponse();

  @override
  Future<SetShuffleOrderResponse> setShuffleOrder(
          SetShuffleOrderRequest request) async =>
      SetShuffleOrderResponse();

  @override
  Future<SetAutomaticallyWaitsToMinimizeStallingResponse>
      setAutomaticallyWaitsToMinimizeStalling(
              SetAutomaticallyWaitsToMinimizeStallingRequest request) async =>
          SetAutomaticallyWaitsToMinimizeStallingResponse();

  @override
  Future<SetCanUseNetworkResourcesForLiveStreamingWhilePausedResponse>
      setCanUseNetworkResourcesForLiveStreamingWhilePaused(
              SetCanUseNetworkResourcesForLiveStreamingWhilePausedRequest
                  request) async =>
          SetCanUseNetworkResourcesForLiveStreamingWhilePausedResponse();

  @override
  Future<SetPreferredPeakBitRateResponse> setPreferredPeakBitRate(
          SetPreferredPeakBitRateRequest request) async =>
      SetPreferredPeakBitRateResponse();

  @override
  Future<SetAllowsExternalPlaybackResponse> setAllowsExternalPlayback(
          SetAllowsExternalPlaybackRequest request) async =>
      SetAllowsExternalPlaybackResponse();

  @override
  Future<SetAndroidAudioAttributesResponse> setAndroidAudioAttributes(
          SetAndroidAudioAttributesRequest request) async =>
      SetAndroidAudioAttributesResponse();

  @override
  Future<DisposeResponse> dispose(DisposeRequest request) async {
    disposeFromPlatform();
    return DisposeResponse();
  }

  @override
  Future<ConcatenatingInsertAllResponse> concatenatingInsertAll(
          ConcatenatingInsertAllRequest request) async =>
      ConcatenatingInsertAllResponse();

  @override
  Future<ConcatenatingRemoveRangeResponse> concatenatingRemoveRange(
          ConcatenatingRemoveRangeRequest request) async =>
      ConcatenatingRemoveRangeResponse();

  @override
  Future<ConcatenatingMoveResponse> concatenatingMove(
          ConcatenatingMoveRequest request) async =>
      ConcatenatingMoveResponse();

  @override
  Future<AudioEffectSetEnabledResponse> audioEffectSetEnabled(
          AudioEffectSetEnabledRequest request) async =>
      AudioEffectSetEnabledResponse();

  @override
  Future<AndroidLoudnessEnhancerSetTargetGainResponse>
      androidLoudnessEnhancerSetTargetGain(
              AndroidLoudnessEnhancerSetTargetGainRequest request) async =>
          AndroidLoudnessEnhancerSetTargetGainResponse();

  @override
  Future<AndroidEqualizerGetParametersResponse> androidEqualizerGetParameters(
          AndroidEqualizerGetParametersRequest request) async =>
      AndroidEqualizerGetParametersResponse(
        parameters: AndroidEqualizerParametersMessage(
          minDecibels: 0,
          maxDecibels: 0,
          bands: const <AndroidEqualizerBandMessage>[],
        ),
      );

  @override
  Future<AndroidEqualizerBandSetGainResponse> androidEqualizerBandSetGain(
          AndroidEqualizerBandSetGainRequest request) async =>
      AndroidEqualizerBandSetGainResponse();

  @override
  Future<SetWebCrossOriginResponse> setWebCrossOrigin(
          SetWebCrossOriginRequest request) async =>
      SetWebCrossOriginResponse();

  @override
  Future<SetWebSinkIdResponse> setWebSinkId(SetWebSinkIdRequest request) async =>
      SetWebSinkIdResponse();

  // ---------------------------------------------------------------------------
  // Test controls — replay platform event sequences.
  // ---------------------------------------------------------------------------

  /// Models a raw player-data broadcast. Windows `Broadcast()` carries the
  /// native `playing_` flag, which stays false until the native play request
  /// lands — so engine broadcasts issued while playback is being started
  /// deliver `playing: false` and can flip just_audio's Dart-side flag.
  void emitPlaying(bool value) {
    _data.add(PlayerDataMessage(playing: value));
  }

  /// Models a periodic engine state broadcast that advances the reported
  /// position (the app's `_maxObservedPositionMs` is fed from these).
  void emitPosition(Duration pos) {
    position = pos;
    _emit(ProcessingStateMessage.ready);
  }

  /// Windows `MediaEnded`: processingState=completed, position at duration,
  /// player-data `playing` stays true, pending play() result completes.
  void emitNaturalEnd() {
    position = mediaDuration;
    enginePlaying = false;
    _emit(ProcessingStateMessage.completed);
    _data.add(PlayerDataMessage(playing: true));
    _completePlay();
  }

  /// Windows `MediaFailed` / stream teardown: idle state + error fields on the
  /// playback event (drives `errorStream`), player-data `playing` untouched.
  void emitEndFailure(
      {int code = 1, String message = 'stream failed at end of media'}) {
    enginePlaying = false;
    _events.add(PlaybackEventMessage(
      processingState: ProcessingStateMessage.idle,
      updateTime: DateTime.now(),
      updatePosition: position,
      bufferedPosition: position,
      duration: mediaDuration,
      icyMetadata: null,
      currentIndex: null,
      androidAudioSessionId: null,
      errorCode: code,
      errorMessage: message,
    ));
    _data.add(PlayerDataMessage(playing: true));
    _completePlay();
  }

  /// Like [emitNaturalEnd] but replayed while `playing` is false — models a
  /// stale completion replay delivered from the previous source's session.
  void emitCompletedAt(Duration replayPosition) {
    position = replayPosition;
    _emit(ProcessingStateMessage.completed);
  }

  void disposeFromPlatform() {
    if (disposedFlag) return;
    disposedFlag = true;
    // Native Dispose(): cancel pending load, complete pending play, release.
    final pendingLoad = _pendingLoad;
    if (pendingLoad != null && !pendingLoad.isCompleted) {
      pendingLoad.completeError(Exception('Player disposed'));
    }
    _completePlay();
    _events.close();
    _data.close();
  }

  void _completePlay() {
    final pendingPlay = _pendingPlay;
    if (pendingPlay != null && !pendingPlay.isCompleted) {
      pendingPlay.complete();
    }
  }

  void _emit(ProcessingStateMessage? state) {
    if (state == null || _events.isClosed) return;
    _events.add(PlaybackEventMessage(
      processingState: state,
      updateTime: DateTime.now(),
      updatePosition: position,
      bufferedPosition: position,
      duration: mediaDuration,
      icyMetadata: null,
      currentIndex: null,
      androidAudioSessionId: null,
    ));
  }

  String _describe(AudioSourceMessage message) {
    if (message is UriAudioSourceMessage) return message.uri;
    if (message is ConcatenatingAudioSourceMessage) {
      return 'concat[${message.children.map(_describe).join(', ')}]';
    }
    if (message is ClippingAudioSourceMessage) return _describe(message.child);
    if (message is LoopingAudioSourceMessage) return _describe(message.child);
    return message.runtimeType.toString();
  }
}
