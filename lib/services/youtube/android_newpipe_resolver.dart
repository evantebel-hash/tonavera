import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'youtube_parser.dart';
import 'android_legacy_youtube_resolver.dart';

class AndroidNewPipeResolver {
  static final AndroidNewPipeResolver instance =
      AndroidNewPipeResolver._internal();

  final MethodChannel _channel;

  AndroidNewPipeResolver({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.mymusic/youtube_android');

  AndroidNewPipeResolver._internal()
    : _channel = const MethodChannel('com.mymusic/youtube_android');

  /// Resolves video metadata and audio stream via Android NewPipe Extractor platform bridge.
  Future<AndroidAudioStreamResult> resolveVideo(
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

    final targetIdOrUrl = videoId ?? cleanInput;
    debugPrint('[YouTube][Android][NewPipe] Resolving videoId=$targetIdOrUrl');

    try {
      final dynamic rawResult = await _channel
          .invokeMethod('resolveVideo', {'videoId': targetIdOrUrl})
          .timeout(
            timeout,
            onTimeout: () {
              throw TimeoutException(
                'Penyelesaian audio NewPipe mengalami batas waktu (${timeout.inSeconds}s).',
              );
            },
          );

      if (rawResult == null || rawResult is! Map) {
        throw Exception(
          'Hasil dari NewPipe Extractor tidak valid atau kosong.',
        );
      }

      final map = Map<String, dynamic>.from(rawResult);
      final audioUrl = map['audioUrl']?.toString() ?? '';
      if (audioUrl.isEmpty) {
        throw Exception(
          'NewPipe Extractor tidak menemukan URL audio yang valid.',
        );
      }

      final headersMap = <String, String>{};
      if (map['headers'] != null && map['headers'] is Map) {
        (map['headers'] as Map).forEach((k, v) {
          if (k != null && v != null) {
            headersMap[k.toString()] = v.toString();
          }
        });
      }

      final bitrate = (map['bitrate'] is num)
          ? (map['bitrate'] as num).toInt()
          : 0;
      final duration = (map['duration'] is num)
          ? (map['duration'] as num).toInt()
          : 0;
      final mimeType = map['mimeType']?.toString() ?? 'audio/mp4';
      final title = map['title']?.toString();
      final artist = map['artist']?.toString();
      final thumbnail = map['thumbnail']?.toString();

      debugPrint(
        '[YouTube][Android][NewPipe] Stream resolved: bitrate=$bitrate, duration=$duration',
      );

      return AndroidAudioStreamResult(
        url: audioUrl,
        mimeType: mimeType,
        bitrate: bitrate,
        contentLength: 0,
        headers: headersMap,
        videoId: map['videoId']?.toString() ?? targetIdOrUrl,
        title: title,
        artist: artist,
        duration: duration > 0 ? duration : null,
        thumbnailUrl: thumbnail,
      );
    } on PlatformException catch (e) {
      debugPrint(
        '[YouTube][Android][NewPipe] Platform error: ${e.code} - ${e.message}',
      );
      throw Exception(
        'Gagal mengekstrak stream via NewPipe: ${e.message ?? e.code}',
      );
    } catch (e) {
      debugPrint('[YouTube][Android][NewPipe] Error: $e');
      rethrow;
    }
  }
}
