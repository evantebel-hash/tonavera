import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/song_model.dart';
import '../../models/youtube_model.dart';
import '../../services/youtube/youtube_service.dart';
import 'metadata_model.dart';

/// Resolves Spotify metadata tracks to playable/downloadable YouTube audio tracks.
/// Uses a title + artist + duration heuristics matcher with caching.
class SpotifyResolverService {
  static SpotifyResolverService? _instance;
  static SpotifyResolverService get instance =>
      _instance ??= SpotifyResolverService();

  final YouTubeService _ytService;
  final Map<String, SongModel> _resolutionCache = {};

  SpotifyResolverService({YouTubeService? ytService})
    : _ytService = ytService ?? YouTubeService.instance;

  String _getCacheKey(MusicMetadataResult track) {
    if (track.spotifyId != null && track.spotifyId!.isNotEmpty) {
      return 'sp:${track.spotifyId}';
    }
    return 'sp:${track.title.toLowerCase()}|${track.displayArtist.toLowerCase()}';
  }

  /// Resolves a single Spotify track into a playable YouTube [SongModel].
  /// Returns null if no acceptable YouTube match was found or on error.
  Future<SongModel?> resolveTrack(MusicMetadataResult track) async {
    final cacheKey = _getCacheKey(track);
    if (_resolutionCache.containsKey(cacheKey)) {
      debugPrint('[SpotifyResolver] Cache HIT for $cacheKey');
      return _resolutionCache[cacheKey];
    }

    final query = '${track.title} ${track.displayArtist}'.trim();
    if (query.isEmpty) return null;

    try {
      final results = await _ytService
          .search(query)
          .timeout(const Duration(seconds: 12));
      if (results.isEmpty) {
        debugPrint('[SpotifyResolver] No YouTube match found for: $query');
        return null;
      }

      final bestMatch = pickBestMatch(track, results);
      if (bestMatch == null) return null;

      final resolved = buildPlayableSong(track, bestMatch);
      _resolutionCache[cacheKey] = resolved;
      debugPrint(
        '[SpotifyResolver] Resolved "$query" -> videoId=${bestMatch.videoId}',
      );
      return resolved;
    } catch (e) {
      debugPrint('[SpotifyResolver] Failed to resolve "$query": $e');
      return null;
    }
  }

  /// Minimum heuristic score to consider a YouTube candidate acceptable.
  static const int minConfidenceScore = 30;

  /// Builds a playable [SongModel] with source 'youtube' combining metadata from Spotify and stream from YouTube.
  SongModel buildPlayableSong(MusicMetadataResult track, YouTubeVideo video) {
    final numericId = video.id ?? (video.videoId.hashCode.abs());
    return SongModel(
      id: numericId,
      artistId: 0,
      title: track.title.isNotEmpty ? track.title : video.title,
      artistName: track.displayArtist.isNotEmpty
          ? track.displayArtist
          : (video.channelName ?? 'YouTube'),
      albumTitle: track.album ?? video.albumName ?? 'Spotify Import',
      duration: (track.duration != null && track.duration! > 0)
          ? track.duration!
          : video.durationSeconds,
      audioPath: video.videoId,
      cover: (track.artworkUrl != null && track.artworkUrl!.isNotEmpty)
          ? track.artworkUrl
          : video.thumbnailUrl,
      source: 'youtube',
    );
  }

  /// Resolves a list of Spotify tracks using controlled concurrency (default max 3 concurrent requests).
  /// Guarantees original order of successful tracks without overwhelming network resources.
  Future<List<SongModel>> resolveBatch(
    List<MusicMetadataResult> tracks, {
    int maxConcurrency = 3,
    void Function(int current, int total)? onProgress,
  }) async {
    if (tracks.isEmpty) return [];

    final List<SongModel?> slots = List.filled(tracks.length, null);
    int completedCount = 0;
    int cursor = 0;

    Future<void> worker() async {
      while (true) {
        final idx = cursor++;
        if (idx >= tracks.length) break;

        final track = tracks[idx];
        try {
          final song = await resolveTrack(track);
          slots[idx] = song;
        } catch (e) {
          debugPrint('[SpotifyResolver] Batch item $idx failed: $e');
        } finally {
          completedCount++;
          onProgress?.call(completedCount, tracks.length);
        }
      }
    }

    final workerCount = maxConcurrency.clamp(1, tracks.length);
    final workers = List.generate(workerCount, (_) => worker());
    await Future.wait(workers);

    return slots.whereType<SongModel>().toList();
  }

  /// Heuristic matching algorithm to pick the most accurate video for a track.
  /// Rejects candidates if the top score is below [minConfidenceScore].
  YouTubeVideo? pickBestMatch(
    MusicMetadataResult track,
    List<YouTubeVideo> candidates,
  ) {
    if (candidates.isEmpty) return null;

    YouTubeVideo? bestCandidate;
    int bestScore = -99999;

    for (final candidate in candidates) {
      final score = computeMatchScore(track, candidate);
      if (score > bestScore) {
        bestScore = score;
        bestCandidate = candidate;
      }
    }

    if (bestScore < minConfidenceScore) {
      debugPrint(
        '[SpotifyResolver] Best score ($bestScore) below threshold ($minConfidenceScore) for "${track.title}"',
      );
      return null;
    }

    return bestCandidate;
  }

  /// Computes a heuristic match score between a Spotify track and a YouTube video candidate.
  int computeMatchScore(MusicMetadataResult track, YouTubeVideo candidate) {
    int score = 0;
    final targetTitle = _normalize(track.title);
    final cleanBaseTitle = _cleanTitle(track.title);
    final targetArtist = _normalize(track.displayArtist);
    final targetDuration = track.duration ?? 0;

    final candTitle = _normalize(candidate.title);
    final candChannel = _normalize(candidate.channelName ?? '');

    // Title match: check full title or clean base title (without feat/remaster tags)
    if (candTitle.contains(targetTitle)) {
      score += 50;
    } else if (cleanBaseTitle.isNotEmpty &&
        candTitle.contains(cleanBaseTitle)) {
      score += 45;
    }

    // Artist match in title or channel
    if (targetArtist.isNotEmpty &&
        (candTitle.contains(targetArtist) ||
            candChannel.contains(targetArtist))) {
      score += 40;
    } else if (track.artists.isNotEmpty) {
      // Check each contributing artist
      for (final a in track.artists) {
        final normA = _normalize(a);
        if (normA.isNotEmpty &&
            (candTitle.contains(normA) || candChannel.contains(normA))) {
          score += 25;
          break;
        }
      }
    }

    // Penalize unwanted versions unless Spotify metadata requested them
    if (!targetTitle.contains('live') && candTitle.contains('live')) {
      score -= 40;
    }
    if (!targetTitle.contains('cover') && candTitle.contains('cover')) {
      score -= 45;
    }
    if (!targetTitle.contains('karaoke') && candTitle.contains('karaoke')) {
      score -= 50;
    }
    if (!targetTitle.contains('instrumental') &&
        candTitle.contains('instrumental')) {
      score -= 50;
    }
    if (!targetTitle.contains('spedup') &&
        (candTitle.contains('spedup') || candTitle.contains('speedup'))) {
      score -= 50;
    }
    if (!targetTitle.contains('slowed') && candTitle.contains('slowed')) {
      score -= 50;
    }
    if (!targetTitle.contains('nightcore') && candTitle.contains('nightcore')) {
      score -= 50;
    }
    if (!targetTitle.contains('8d') && candTitle.contains('8daudio')) {
      score -= 35;
    }
    if (!targetTitle.contains('remix') && candTitle.contains('remix')) {
      score -= 30;
    }

    // Official audio/video bonus
    if (candTitle.contains('officialaudio') ||
        candTitle.contains('officialmusicvideo') ||
        candTitle.contains('officialvideo')) {
      score += 10;
    }

    // Duration proximity check
    if (targetDuration > 0 && candidate.durationSeconds > 0) {
      final diff = (candidate.durationSeconds - targetDuration).abs();
      if (diff <= 5) {
        score += 30;
      } else if (diff <= 15) {
        score += 20;
      } else if (diff <= 30) {
        score += 10;
      } else if (diff > 90) {
        score -= 30; // Very large duration mismatch
      }
    }

    return score;
  }

  static String _cleanTitle(String raw) {
    // Strip parenthesized text like (feat. X), (Remastered 2021), [Official Audio]
    final cleaned = raw
        .replaceAll(RegExp(r'\([^)]*\)'), '')
        .replaceAll(RegExp(r'\[[^\]]*\]'), '')
        .replaceAll(RegExp(r'-\s*remaster.*$', caseSensitive: false), '')
        .trim();
    return _normalize(cleaned);
  }

  static String _normalize(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  void clearCache() {
    _resolutionCache.clear();
  }
}
