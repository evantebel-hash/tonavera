import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'youtube_parser.dart';

class AndroidAudioStreamResult {
  final String url;
  final String mimeType;
  final int bitrate;
  final int contentLength;
  final Map<String, String> headers;
  final String? videoId;
  final String? title;
  final String? artist;
  final int? duration;
  final String? thumbnailUrl;

  AndroidAudioStreamResult({
    required this.url,
    required this.mimeType,
    required this.bitrate,
    required this.contentLength,
    required this.headers,
    this.videoId,
    this.title,
    this.artist,
    this.duration,
    this.thumbnailUrl,
  });
}

class AndroidLegacyYouTubeResolver {
  static final AndroidLegacyYouTubeResolver instance =
      AndroidLegacyYouTubeResolver._internal();

  final http.Client _client;

  AndroidLegacyYouTubeResolver({http.Client? client})
    : _client = client ?? http.Client();

  AndroidLegacyYouTubeResolver._internal() : _client = http.Client();

  static const String _userAgentIos =
      'com.google.ios.youtube/19.02.1 (iPhone; CPU iPhone OS 17_3 like Mac OS X; en_US)';

  static const String _userAgentAndroidTestSuite =
      'com.google.android.youtube/19.02.39 (Linux; U; Android 12; en_US)';

  static const String _userAgentWeb =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

  AndroidAudioStreamResult? extractAudioUrlFromPlayerDataForTest(
    Map<String, dynamic> data,
    String userAgent,
  ) {
    return _extractAudioUrlFromPlayerData(data, userAgent);
  }

  /// Resolves direct audio stream URL for Android using HTTP InnerTube player API (legacy fallback)
  Future<String> resolveAudioStreamUrl(
    String videoIdOrUrl, {
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final result = await resolveAudioStreamDetails(
      videoIdOrUrl,
      timeout: timeout,
    );
    return result.url;
  }

  /// Resolves full stream details including headers and format diagnostic info
  Future<AndroidAudioStreamResult> resolveAudioStreamDetails(
    String videoIdOrUrl, {
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final cleanInput = videoIdOrUrl.trim();
    if (cleanInput.isEmpty) {
      throw Exception('Video ID / URL YouTube tidak boleh kosong.');
    }

    final videoId =
        YouTubeParser.extractVideoId(cleanInput) ??
        (cleanInput.length == 11 ? cleanInput : null);

    if (videoId == null) {
      throw Exception('Video ID YouTube tidak valid.');
    }

    debugPrint('[YouTube][Android][Legacy] Resolving videoId=$videoId');

    try {
      final result = await _resolveViaInnerTube(videoId).timeout(
        timeout,
        onTimeout: () {
          throw TimeoutException(
            'Penyiapan audio YouTube pada Android mengalami batas waktu (${timeout.inSeconds}s).',
          );
        },
      );

      if (result != null) {
        debugPrint('[YouTube][Android][Legacy] Stream resolved via InnerTube');
        return result;
      }
    } catch (e) {
      debugPrint(
        '[YouTube][Android][Legacy] InnerTube error: $e. Trying HTML fallback...',
      );
    }

    // HTML scraping fallback
    try {
      final fallbackResult = await _resolveViaHtmlScrape(
        videoId,
      ).timeout(timeout);
      if (fallbackResult != null) {
        debugPrint(
          '[YouTube][Android][Legacy] Stream resolved via HTML scrape',
        );
        return fallbackResult;
      }
    } catch (e) {
      debugPrint('[YouTube][Android][Legacy] HTML fallback error: $e');
    }

    throw Exception(
      'Gagal mendapatkan sumber audio YouTube dari Android legacy resolver.',
    );
  }

  /// InnerTube player endpoint request trying client profiles that return unencrypted direct stream URLs
  Future<AndroidAudioStreamResult?> _resolveViaInnerTube(String videoId) async {
    final clientProfiles = [
      {
        'clientName': 'IOS',
        'clientVersion': '19.02.1',
        'userAgent': _userAgentIos,
        'osName': 'iOS',
        'osVersion': '17.3.1',
        'deviceModel': 'iPhone16,2',
      },
      {
        'clientName': 'ANDROID_TESTSUITE',
        'clientVersion': '1.9',
        'userAgent': _userAgentAndroidTestSuite,
        'osName': 'Android',
        'osVersion': '12',
      },
      {
        'clientName': 'TVHTML5_SIMPLY_EMBEDDED_PLAYER',
        'clientVersion': '2.0',
        'userAgent': _userAgentWeb,
      },
      {
        'clientName': 'WEB_EMBEDDED_PLAYER',
        'clientVersion': '1.20240101.01.00',
        'userAgent': _userAgentWeb,
      },
    ];

    for (final profile in clientProfiles) {
      try {
        final url = Uri.parse(
          'https://www.youtube.com/youtubei/v1/player?alt=json',
        );
        final bodyMap = {
          'context': {
            'client': {
              'clientName': profile['clientName'],
              'clientVersion': profile['clientVersion'],
              'hl': 'en',
              'gl': 'US',
              if (profile.containsKey('osName')) 'osName': profile['osName'],
              if (profile.containsKey('osVersion'))
                'osVersion': profile['osVersion'],
              if (profile.containsKey('deviceModel'))
                'deviceModel': profile['deviceModel'],
            },
          },
          'videoId': videoId,
          'contentCheckOk': true,
          'racyCheckOk': true,
        };

        final response = await _client
            .post(
              url,
              headers: {
                'User-Agent': profile['userAgent']!,
                'Content-Type': 'application/json',
                'Origin': 'https://www.youtube.com',
                'Referer': 'https://www.youtube.com/',
              },
              body: json.encode(bodyMap),
            )
            .timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          final streamResult = _extractAudioUrlFromPlayerData(
            data,
            profile['userAgent']!,
            videoId: videoId,
          );
          if (streamResult != null) {
            return streamResult;
          }
        }
      } catch (e) {
        debugPrint(
          '[AndroidLegacyYouTube] Profile ${profile['clientName']} failed: $e',
        );
      }
    }

    return null;
  }

  /// HTML watch page fallback
  Future<AndroidAudioStreamResult?> _resolveViaHtmlScrape(
    String videoId,
  ) async {
    final watchUrl = Uri.parse(
      'https://www.youtube.com/watch?v=$videoId&bpctr=9999999999&has_verified=1',
    );
    final response = await _client
        .get(
          watchUrl,
          headers: {
            'User-Agent': _userAgentWeb,
            'Accept-Language': 'en-US,en;q=0.9',
          },
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final html = response.body;
      final playerResponseMatch =
          RegExp(
            r'var\s+ytInitialPlayerResponse\s*=\s*(\{.+?\});</script>',
            dotAll: true,
          ).firstMatch(html) ??
          RegExp(
            r'ytInitialPlayerResponse\s*=\s*(\{.+?\});',
            dotAll: true,
          ).firstMatch(html);

      if (playerResponseMatch != null) {
        final jsonStr = playerResponseMatch.group(1);
        if (jsonStr != null) {
          final data = json.decode(jsonStr) as Map<String, dynamic>;
          return _extractAudioUrlFromPlayerData(
            data,
            _userAgentWeb,
            videoId: videoId,
          );
        }
      }
    }
    return null;
  }

  /// Extracts best audio-only stream URL from InnerTube player response object
  AndroidAudioStreamResult? _extractAudioUrlFromPlayerData(
    Map<String, dynamic> data,
    String userAgent, {
    String? videoId,
  }) {
    final streamingData = data['streamingData'] as Map<String, dynamic>?;
    if (streamingData == null) return null;

    final formats = <Map<String, dynamic>>[];

    final adaptiveFormats = streamingData['adaptiveFormats'] as List<dynamic>?;
    if (adaptiveFormats != null) {
      for (final item in adaptiveFormats) {
        if (item is Map<String, dynamic>) {
          formats.add(item);
        }
      }
    }

    final regularFormats = streamingData['formats'] as List<dynamic>?;
    if (regularFormats != null) {
      for (final item in regularFormats) {
        if (item is Map<String, dynamic>) {
          formats.add(item);
        }
      }
    }

    // Filter audio-only formats
    final audioFormats = formats.where((f) {
      final mime = f['mimeType']?.toString() ?? '';
      return mime.startsWith('audio/');
    }).toList();

    // Sort by bitrate (highest bitrate first)
    audioFormats.sort((a, b) {
      final bitrateA = (a['bitrate'] is num)
          ? (a['bitrate'] as num).toInt()
          : 0;
      final bitrateB = (b['bitrate'] is num)
          ? (b['bitrate'] as num).toInt()
          : 0;
      return bitrateB.compareTo(bitrateA);
    });

    // Extract title / author if available
    final videoDetails = data['videoDetails'] as Map<String, dynamic>?;
    final title = videoDetails?['title']?.toString();
    final author = videoDetails?['author']?.toString();
    final lengthSeconds = int.tryParse(
      videoDetails?['lengthSeconds']?.toString() ?? '',
    );

    // Pick first audio format with direct unencrypted URL
    for (final fmt in audioFormats) {
      final rawUrl = fmt['url']?.toString();
      if (rawUrl != null &&
          rawUrl.startsWith('http') &&
          !rawUrl.contains('signatureCipher')) {
        final mimeType = fmt['mimeType']?.toString() ?? 'audio/mp4';
        final bitrate = (fmt['bitrate'] is num)
            ? (fmt['bitrate'] as num).toInt()
            : 0;
        final contentLength = (fmt['contentLength'] is num)
            ? (fmt['contentLength'] as num).toInt()
            : int.tryParse(fmt['contentLength']?.toString() ?? '0') ?? 0;

        return AndroidAudioStreamResult(
          url: rawUrl,
          mimeType: mimeType,
          bitrate: bitrate,
          contentLength: contentLength,
          headers: {
            'User-Agent': userAgent,
            'Origin': 'https://www.youtube.com',
            'Referer': 'https://www.youtube.com/',
          },
          videoId: videoId,
          title: title,
          artist: author,
          duration: lengthSeconds,
        );
      }
    }

    // Fallback: Check formats for any direct unencrypted audio URL
    for (final fmt in formats) {
      final mimeType = fmt['mimeType']?.toString() ?? '';
      final rawUrl = fmt['url']?.toString();
      if (mimeType.startsWith('audio/') &&
          rawUrl != null &&
          rawUrl.startsWith('http') &&
          !rawUrl.contains('signatureCipher')) {
        final bitrate = (fmt['bitrate'] is num)
            ? (fmt['bitrate'] as num).toInt()
            : 0;
        final contentLength = (fmt['contentLength'] is num)
            ? (fmt['contentLength'] as num).toInt()
            : int.tryParse(fmt['contentLength']?.toString() ?? '0') ?? 0;

        return AndroidAudioStreamResult(
          url: rawUrl,
          mimeType: mimeType,
          bitrate: bitrate,
          contentLength: contentLength,
          headers: {
            'User-Agent': userAgent,
            'Origin': 'https://www.youtube.com',
            'Referer': 'https://www.youtube.com/',
          },
          videoId: videoId,
          title: title,
          artist: author,
          duration: lengthSeconds,
        );
      }
    }

    return null;
  }
}
