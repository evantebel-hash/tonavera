import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/lyric_line.dart';
import '../models/lyrics_model.dart';
import '../models/song_model.dart';
import 'lrc_parser.dart';

enum LrclibErrorType {
  none,
  notFound,
  rateLimited,
  networkError,
  serverError,
  invalidResponse,
}

class LrclibResponse {
  final LyricsModel? lyrics;
  final LrclibErrorType errorType;
  final String? errorMessage;

  const LrclibResponse({
    this.lyrics,
    this.errorType = LrclibErrorType.none,
    this.errorMessage,
  });

  bool get isSuccess => lyrics != null;
}

class LrclibService {
  static const String _baseUrl = 'https://lrclib.net/api';
  static const Duration _timeout = Duration(seconds: 8);
  static const int _maxLyricsSize = 256 * 1024; // 256 KB max

  final http.Client _client;

  LrclibService({http.Client? client}) : _client = client ?? http.Client();

  /// Performs secure HTTPS lookup against LRCLIB with 2-step fallback strategy.
  Future<LrclibResponse> fetchLyrics(SongModel song) async {
    final title = song.title.trim();
    if (title.isEmpty || title.toLowerCase() == 'unknown title') {
      return const LrclibResponse(
        errorType: LrclibErrorType.notFound,
        errorMessage: 'Judul lagu tidak valid untuk pencarian.',
      );
    }

    final artist =
        (song.artistName != null &&
            song.artistName!.trim().isNotEmpty &&
            song.artistName!.toLowerCase() != 'unknown artist')
        ? song.artistName!.trim()
        : '';
    final album =
        (song.albumTitle != null &&
            song.albumTitle!.trim().isNotEmpty &&
            song.albumTitle!.toLowerCase() != 'unknown album')
        ? song.albumTitle!.trim()
        : '';
    final duration = song.duration;

    // Attempt 1: Specific GET /api/get with title + artist + album + duration
    try {
      final specificUri = Uri.parse('$_baseUrl/get').replace(
        queryParameters: {
          'track_name': title,
          if (artist.isNotEmpty) 'artist_name': artist,
          if (album.isNotEmpty) 'album_name': album,
          if (duration > 0) 'duration': duration.toString(),
        },
      );

      final res1 = await _client
          .get(
            specificUri,
            headers: {'User-Agent': 'MyMusic/1.0 (Local-First Music Player)'},
          )
          .timeout(_timeout);

      final processed1 = _processResponse(song.id, res1);
      if (processed1.isSuccess) {
        return processed1;
      }
    } catch (e) {
      debugPrint('LrclibService: Specific lookup exception: $e');
    }

    // Attempt 2: Fallback GET /api/search with title + artist
    try {
      final searchUri = Uri.parse('$_baseUrl/search').replace(
        queryParameters: {'q': artist.isNotEmpty ? '$artist $title' : title},
      );

      final res2 = await _client
          .get(
            searchUri,
            headers: {'User-Agent': 'MyMusic/1.0 (Local-First Music Player)'},
          )
          .timeout(_timeout);

      if (res2.statusCode == 200) {
        final decoded = json.decode(utf8.decode(res2.bodyBytes));
        if (decoded is List && decoded.isNotEmpty) {
          // Select best candidate based on duration and title/artist match
          Map<String, dynamic>? bestMatch;
          int minDurationDiff = 999999;

          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              final itemTrack = (item['trackName'] ?? item['name'] ?? '')
                  .toString()
                  .toLowerCase();
              final itemArtist = (item['artistName'] ?? '')
                  .toString()
                  .toLowerCase();
              final itemDur =
                  int.tryParse((item['duration'] ?? 0).toString()) ?? 0;
              final hasSynced =
                  item['syncedLyrics'] != null &&
                  item['syncedLyrics'].toString().trim().isNotEmpty;

              // Check title and artist relevance
              final titleMatches =
                  itemTrack.contains(title.toLowerCase()) ||
                  title.toLowerCase().contains(itemTrack);
              final artistMatches =
                  artist.isEmpty ||
                  itemArtist.contains(artist.toLowerCase()) ||
                  artist.toLowerCase().contains(itemArtist);

              if (titleMatches && artistMatches) {
                if (duration > 0 && itemDur > 0) {
                  final diff = (itemDur - duration).abs();
                  // Stricter duration matching: prefer candidates with synced lyrics within 15 seconds
                  if (diff <= 15) {
                    if (bestMatch == null ||
                        (hasSynced && diff <= minDurationDiff) ||
                        diff < minDurationDiff) {
                      minDurationDiff = diff;
                      bestMatch = item;
                    }
                  }
                } else {
                  if (bestMatch == null || hasSynced) {
                    bestMatch = item;
                  }
                }
              }
            }
          }

          if (bestMatch != null) {
            if (kDebugMode) {
              debugPrint(
                '[LrclibCandidate] Matched track: "${bestMatch['trackName']}" by "${bestMatch['artistName']}" | '
                'Dur: ${bestMatch['duration']}s (target: ${song.duration}s, diff: $minDurationDiff s) | '
                'HasSynced: ${bestMatch['syncedLyrics'] != null}',
              );
            }
            return mapJsonToLyricsModel(song.id, bestMatch);
          } else if (kDebugMode) {
            debugPrint(
              '[LrclibCandidate] No suitable candidate found for "${song.title}" (${decoded.length} items evaluated)',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('LrclibService: Search fallback exception: $e');
    }

    return const LrclibResponse(
      errorType: LrclibErrorType.notFound,
      errorMessage: 'Lirik tidak ditemukan di LRCLIB.',
    );
  }

  LrclibResponse _processResponse(int songId, http.Response response) {
    if (response.statusCode == 404) {
      return const LrclibResponse(errorType: LrclibErrorType.notFound);
    }
    if (response.statusCode == 429) {
      return const LrclibResponse(
        errorType: LrclibErrorType.rateLimited,
        errorMessage:
            'Batas permintaan lirik tercapai. Coba beberapa saat lagi.',
      );
    }
    if (response.statusCode >= 500) {
      return const LrclibResponse(
        errorType: LrclibErrorType.serverError,
        errorMessage: 'Server lirik sedang mengalami gangguan.',
      );
    }
    if (response.statusCode != 200) {
      return LrclibResponse(
        errorType: LrclibErrorType.invalidResponse,
        errorMessage: 'HTTP status ${response.statusCode}',
      );
    }

    if (response.bodyBytes.length > _maxLyricsSize) {
      return const LrclibResponse(
        errorType: LrclibErrorType.invalidResponse,
        errorMessage: 'Ukuran lirik melebihi batas yang diizinkan.',
      );
    }

    try {
      final decoded = json.decode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        return mapJsonToLyricsModel(songId, decoded);
      }
    } catch (e) {
      return LrclibResponse(
        errorType: LrclibErrorType.invalidResponse,
        errorMessage: 'Format response tidak valid: $e',
      );
    }

    return const LrclibResponse(errorType: LrclibErrorType.notFound);
  }

  LyricsModel? parseApiResponse(Map<String, dynamic> jsonMap, SongModel song) {
    if (jsonMap.containsKey('duration') && song.duration > 0) {
      final remoteDuration = (jsonMap['duration'] as num).toDouble();
      if ((remoteDuration - song.duration).abs() > 15) {
        return null;
      }
    }
    final resp = mapJsonToLyricsModel(song.id, jsonMap);
    return resp.lyrics;
  }

  LrclibResponse mapJsonToLyricsModel(
    int songId,
    Map<String, dynamic> jsonMap,
  ) {
    final synced = jsonMap['syncedLyrics']?.toString();
    final plain = jsonMap['plainLyrics']?.toString();

    final cleanSynced = synced != null && synced.trim().isNotEmpty
        ? LrcParser.normalize(synced)
        : null;
    final cleanPlain = plain != null && plain.trim().isNotEmpty
        ? LrcParser.normalize(plain)
        : null;

    if (cleanSynced == null && cleanPlain == null) {
      return const LrclibResponse(errorType: LrclibErrorType.notFound);
    }

    final isSynced = cleanSynced != null && cleanSynced.isNotEmpty;
    final parsed = isSynced
        ? LrcParser.parse(cleanSynced)
        : const <LyricLine>[];

    final lyrics = LyricsModel(
      songId: songId,
      source: LyricsSource.lrclib,
      plainLyrics: cleanPlain,
      syncedLyrics: cleanSynced,
      language: jsonMap['language']?.toString(),
      fetchedAt: DateTime.now(),
      isSynced: isSynced && parsed.isNotEmpty,
      parsedLines: parsed,
    );

    return LrclibResponse(lyrics: lyrics);
  }
}
