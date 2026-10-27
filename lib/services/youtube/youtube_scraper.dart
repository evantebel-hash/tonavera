import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../models/youtube_model.dart';
import 'youtube_normalizer.dart';
import 'youtube_parser.dart';

class YouTubeScraper {
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

  final http.Client _client;

  YouTubeScraper({http.Client? client}) : _client = client ?? http.Client();

  /// Searches YouTube Music using InnerTube WEB_REMIX API
  Future<List<YouTubeVideo>> searchMusic(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    try {
      final url = Uri.parse(
        'https://music.youtube.com/youtubei/v1/search?alt=json',
      );
      final body = json.encode({
        'context': {
          'client': {
            'clientName': 'WEB_REMIX',
            'clientVersion': '1.20240101.01.00',
            'hl': 'en',
            'gl': 'US',
          },
        },
        'query': cleanQuery,
      });

      final response = await _client
          .post(
            url,
            headers: {
              'User-Agent': userAgent,
              'Content-Type': 'application/json',
              'Origin': 'https://music.youtube.com',
              'Referer': 'https://music.youtube.com/',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = json.decode(response.body);
        final musicResults = YouTubeParser.parseYouTubeMusicSearchJson(decoded);
        if (musicResults.isNotEmpty) {
          return musicResults;
        }
      }
    } catch (e) {
      debugPrint('YouTubeScraper: YouTube Music search error: $e');
    }

    // Fallback to video search if YouTube Music returns empty or fails
    return searchVideos(cleanQuery);
  }

  /// Searches YouTube public videos for query
  Future<List<YouTubeVideo>> searchVideos(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    try {
      final encodedQuery = Uri.encodeComponent(cleanQuery);
      final url = Uri.parse(
        'https://www.youtube.com/results?search_query=$encodedQuery',
      );

      final response = await _client
          .get(
            url,
            headers: {
              'User-Agent': userAgent,
              'Accept-Language': 'en-US,en;q=0.9',
            },
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        return YouTubeParser.parseSearchResultsHtml(response.body);
      }
    } catch (e) {
      debugPrint('YouTubeScraper: Search error: $e');
    }

    return [];
  }

  /// Fetches YouTube public playlist metadata and items
  Future<YouTubePlaylist?> fetchPlaylist(String playlistId) async {
    final cleanId = playlistId.trim();
    if (cleanId.isEmpty) return null;

    final browseId = cleanId.startsWith('VL') ? cleanId : 'VL$cleanId';

    // 1. Try InnerTube browse API (supports both YouTube and YouTube Music playlists)
    try {
      final url = Uri.parse(
        'https://music.youtube.com/youtubei/v1/browse?alt=json',
      );
      final body = json.encode({
        'context': {
          'client': {
            'clientName': 'WEB_REMIX',
            'clientVersion': '1.20240101.01.00',
            'hl': 'en',
            'gl': 'US',
          },
        },
        'browseId': browseId,
      });

      final response = await _client
          .post(
            url,
            headers: {
              'User-Agent': userAgent,
              'Content-Type': 'application/json',
              'Origin': 'https://music.youtube.com',
              'Referer': 'https://music.youtube.com/',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final playlist = YouTubeParser.parseInnerTubePlaylistJson(
          data,
          cleanId,
        );
        if (playlist.items.isNotEmpty) {
          return playlist;
        }
      }
    } catch (e) {
      debugPrint('YouTubeScraper: InnerTube playlist fetch error: $e');
    }

    // 2. HTML Scraper Fallback
    try {
      final url = Uri.parse('https://www.youtube.com/playlist?list=$cleanId');

      final response = await _client
          .get(
            url,
            headers: {
              'User-Agent': userAgent,
              'Accept-Language': 'en-US,en;q=0.9',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return YouTubeParser.parsePlaylistHtml(response.body, cleanId);
      }
    } catch (e) {
      debugPrint('YouTubeScraper: Fetch playlist HTML error: $e');
    }

    return null;
  }

  /// Fetches single YouTube public video metadata with accurate title, author, and duration
  Future<YouTubeVideo?> fetchVideo(String videoId) async {
    final cleanId = videoId.trim();
    if (cleanId.isEmpty) return null;

    // 1. Try parsing ytInitialPlayerResponse from watch page HTML (most reliable for lengthSeconds)
    try {
      final url = Uri.parse('https://www.youtube.com/watch?v=$cleanId');
      final response = await _client
          .get(
            url,
            headers: {
              'User-Agent': userAgent,
              'Accept-Language': 'en-US,en;q=0.9',
            },
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final html = response.body;
        final match =
            RegExp(
              r'var\s+ytInitialPlayerResponse\s*=\s*(\{.+?\});<',
              dotAll: true,
            ).firstMatch(html) ??
            RegExp(
              r'ytInitialPlayerResponse\s*=\s*(\{.+?\});',
              dotAll: true,
            ).firstMatch(html);

        if (match != null) {
          final jsonStr = match.group(1);
          if (jsonStr != null) {
            final data = json.decode(jsonStr) as Map<String, dynamic>;
            final videoDetails = data['videoDetails'] as Map<String, dynamic>?;
            if (videoDetails != null) {
              final title =
                  videoDetails['title']?.toString() ?? 'YouTube Track $cleanId';
              final author =
                  videoDetails['author']?.toString() ?? 'YouTube Channel';
              final lengthSecondsStr = videoDetails['lengthSeconds']
                  ?.toString();
              final durationSec = int.tryParse(lengthSecondsStr ?? '0') ?? 0;
              final thumbs =
                  videoDetails['thumbnail']?['thumbnails'] as List<dynamic>?;
              final thumbUrl = thumbs != null && thumbs.isNotEmpty
                  ? thumbs.last['url']?.toString()
                  : null;

              return YouTubeVideo(
                videoId: cleanId,
                title: YouTubeNormalizer.normalizeTitle(title),
                channelName: author,
                thumbnailUrl: YouTubeNormalizer.formatThumbnailUrl(
                  thumbUrl,
                  cleanId,
                ),
                durationSeconds: durationSec,
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('YouTubeScraper: HTML player response error: $e');
    }

    // 2. oEmbed fallback for metadata
    try {
      final oEmbedUrl = Uri.parse(
        'https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=$cleanId&format=json',
      );
      final response = await _client
          .get(oEmbedUrl)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final oEmbedData = json.decode(response.body) as Map<String, dynamic>;
        final title = oEmbedData['title']?.toString();
        final author = oEmbedData['author_name']?.toString();
        if (title != null && title.isNotEmpty) {
          return YouTubeVideo(
            videoId: cleanId,
            title: YouTubeNormalizer.normalizeTitle(title),
            channelName: author ?? 'YouTube',
            thumbnailUrl: YouTubeNormalizer.formatThumbnailUrl(null, cleanId),
            durationSeconds: 0,
          );
        }
      }
    } catch (e) {
      debugPrint('YouTubeScraper: oEmbed fetch error: $e');
    }

    return YouTubeVideo(
      videoId: cleanId,
      title: 'YouTube Track $cleanId',
      thumbnailUrl: YouTubeNormalizer.formatThumbnailUrl(null, cleanId),
    );
  }
}
