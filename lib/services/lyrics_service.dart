import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/lyrics_model.dart';
import '../models/song_model.dart';
import '../repositories/lyrics_repository.dart';
import 'lrc_parser.dart';
import 'lrclib_service.dart';
import 'lyrics_fallback_provider.dart';

enum LyricsLoadingStatus { idle, loading, loaded, notFound, offline, error }

class LyricsState {
  final LyricsLoadingStatus status;
  final LyricsModel? lyrics;
  final String? message;
  final int? songId;

  const LyricsState({
    this.status = LyricsLoadingStatus.idle,
    this.lyrics,
    this.message,
    this.songId,
  });

  bool get hasLyrics => lyrics != null && lyrics!.hasContent;
  bool get isSynced => lyrics?.isSynced ?? false;
}

class LyricsService {
  static final LyricsService instance = LyricsService._internal();

  final LyricsRepository _repository;
  final LrclibService _lrclibService;
  final List<LyricsFallbackProvider> _fallbackProviders;

  // Track latest request token to prevent race condition when songs change rapidly
  int _currentRequestToken = 0;

  LyricsService({
    LyricsRepository? repository,
    LrclibService? lrclibService,
    List<LyricsFallbackProvider>? fallbackProviders,
  }) : _repository = repository ?? LyricsRepository(),
       _lrclibService = lrclibService ?? LrclibService(),
       _fallbackProviders = fallbackProviders ?? [LocalAiLyricsProvider()];

  LyricsService._internal()
    : _repository = LyricsRepository(),
      _lrclibService = LrclibService(),
      _fallbackProviders = [LocalAiLyricsProvider()];

  /// Retrieves lyrics for a song following priority:
  /// 1. SQLite Cached Lyrics (includes previously cached embedded or online lyrics)
  /// 2. Embedded lyrics in SongModel if available
  /// 3. LRCLIB Online Lookup (HTTPS)
  /// 4. Future Local AI fallback
  Future<LyricsState> getLyricsForSong(
    SongModel song, {
    bool forceRefresh = false,
  }) async {
    final requestToken = ++_currentRequestToken;

    // 1. Check local SQLite Cache if not forcing refresh
    if (!forceRefresh) {
      try {
        final cached = await _repository.getLyricsBySongId(song.id);
        if (cached != null && cached.hasContent) {
          if (requestToken != _currentRequestToken) {
            return LyricsState(
              status: LyricsLoadingStatus.idle,
              songId: song.id,
            );
          }
          return LyricsState(
            status: LyricsLoadingStatus.loaded,
            lyrics: cached,
            songId: song.id,
          );
        }
      } catch (e) {
        debugPrint('LyricsService: Cache read error: $e');
      }
    }

    // 2. Check embedded lyrics on SongModel
    if (!forceRefresh &&
        song.lyrics != null &&
        song.lyrics!.trim().isNotEmpty) {
      final normalized = LrcParser.normalize(song.lyrics!);
      final parsed = LrcParser.parse(normalized);
      final isSynced = parsed.isNotEmpty;

      final embeddedModel = LyricsModel(
        songId: song.id,
        source: LyricsSource.embedded,
        plainLyrics: isSynced ? null : normalized,
        syncedLyrics: isSynced ? normalized : null,
        fetchedAt: DateTime.now(),
        isSynced: isSynced,
        parsedLines: parsed,
      );

      // Persist to cache for future instant offline access
      try {
        await _repository.saveLyrics(embeddedModel);
      } catch (_) {}

      if (requestToken != _currentRequestToken) {
        return LyricsState(status: LyricsLoadingStatus.idle, songId: song.id);
      }

      return LyricsState(
        status: LyricsLoadingStatus.loaded,
        lyrics: embeddedModel,
        songId: song.id,
      );
    }

    // 3. Online LRCLIB Lookup
    try {
      final onlineRes = await _lrclibService.fetchLyrics(song);

      if (requestToken != _currentRequestToken) {
        return LyricsState(status: LyricsLoadingStatus.idle, songId: song.id);
      }

      if (onlineRes.isSuccess && onlineRes.lyrics != null) {
        final lyrics = onlineRes.lyrics!;
        // Cache to SQLite
        try {
          await _repository.saveLyrics(lyrics);
        } catch (_) {}

        return LyricsState(
          status: LyricsLoadingStatus.loaded,
          lyrics: lyrics,
          songId: song.id,
        );
      }

      // 4. Try Fallback Providers (e.g. Local AI)
      for (final provider in _fallbackProviders) {
        try {
          final fallback = await provider.fetchLyrics(song);
          if (fallback != null && fallback.hasContent) {
            await _repository.saveLyrics(fallback);
            return LyricsState(
              status: LyricsLoadingStatus.loaded,
              lyrics: fallback,
              songId: song.id,
            );
          }
        } catch (_) {}
      }

      // Handled error type
      if (onlineRes.errorType == LrclibErrorType.rateLimited) {
        return LyricsState(
          status: LyricsLoadingStatus.error,
          message:
              onlineRes.errorMessage ??
              'Terlalu banyak permintaan lirik. Coba lagi nanti.',
          songId: song.id,
        );
      } else if (onlineRes.errorType == LrclibErrorType.serverError ||
          onlineRes.errorType == LrclibErrorType.networkError) {
        return LyricsState(
          status: LyricsLoadingStatus.offline,
          message: 'Lirik belum tersedia secara offline.',
          songId: song.id,
        );
      }

      return LyricsState(
        status: LyricsLoadingStatus.notFound,
        message: 'Lirik tidak ditemukan untuk lagu ini.',
        songId: song.id,
      );
    } catch (e) {
      if (requestToken != _currentRequestToken) {
        return LyricsState(status: LyricsLoadingStatus.idle, songId: song.id);
      }
      return LyricsState(
        status: LyricsLoadingStatus.offline,
        message: 'Lirik belum tersedia secara offline.',
        songId: song.id,
      );
    }
  }

  /// Clears cached lyrics when metadata changes significantly
  Future<void> invalidateLyricsCache(int songId) async {
    await _repository.deleteLyrics(songId);
  }

  /// Cancels any in-flight lookup
  void cancelPendingLookup() {
    _currentRequestToken++;
  }
}
