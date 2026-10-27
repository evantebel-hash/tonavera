import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../audio/android_diagnostic_logger.dart';
import 'android_legacy_youtube_resolver.dart';
import 'android_newpipe_resolver.dart';

export 'android_legacy_youtube_resolver.dart' show AndroidAudioStreamResult;

class AndroidYouTubeResolver {
  static final AndroidYouTubeResolver instance =
      AndroidYouTubeResolver._internal();

  final AndroidNewPipeResolver _newPipeResolver;
  final AndroidLegacyYouTubeResolver _legacyResolver;

  AndroidYouTubeResolver({
    AndroidNewPipeResolver? newPipeResolver,
    AndroidLegacyYouTubeResolver? legacyResolver,
  }) : _newPipeResolver = newPipeResolver ?? AndroidNewPipeResolver.instance,
       _legacyResolver =
           legacyResolver ?? AndroidLegacyYouTubeResolver.instance;

  AndroidYouTubeResolver._internal()
    : _newPipeResolver = AndroidNewPipeResolver.instance,
      _legacyResolver = AndroidLegacyYouTubeResolver.instance;

  AndroidAudioStreamResult? extractAudioUrlFromPlayerDataForTest(
    Map<String, dynamic> data,
    String userAgent,
  ) {
    return _legacyResolver.extractAudioUrlFromPlayerDataForTest(
      data,
      userAgent,
    );
  }

  /// Resolves direct audio stream URL with NewPipe primary + Legacy fallback
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

  /// Resolves full stream details with NewPipe primary + Legacy fallback
  Future<AndroidAudioStreamResult> resolveAudioStreamDetails(
    String videoIdOrUrl, {
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final cleanInput = videoIdOrUrl.trim();
    if (cleanInput.isEmpty) {
      throw Exception('Video ID / URL YouTube tidak boleh kosong.');
    }

    debugPrint('[YouTube][Android] Resolving videoIdOrUrl=$cleanInput');

    // Attempt resolution with max 1 retry for transient network/DNS glitch
    int attempts = 0;
    const maxAttempts = 2;

    while (attempts < maxAttempts) {
      attempts++;

      // 1. Primary: NewPipe Extractor
      try {
        debugPrint(
          '[YouTube][Android][NewPipe] Attempting primary extraction (attempt $attempts)...',
        );
        if (Platform.isAndroid) {
          AndroidDiagnosticLogger.instance.log(
            'YT_NEWPIPE_START',
            'Attempting NewPipe extraction for videoId=$cleanInput (attempt $attempts)',
          );
        }
        final newPipeResult = await _newPipeResolver.resolveVideo(
          cleanInput,
          timeout: timeout,
        );
        if (newPipeResult.url.isNotEmpty) {
          debugPrint(
            '[YouTube][Android][NewPipe] Primary extraction succeeded',
          );
          if (Platform.isAndroid) {
            AndroidDiagnosticLogger.instance.log(
              'YT_NEWPIPE_OK',
              'Primary extraction succeeded for videoId=$cleanInput, bitrate=${newPipeResult.bitrate}',
            );
          }
          return newPipeResult;
        }
      } catch (newPipeError) {
        final safeErr = newPipeError.toString().split('?').first;
        debugPrint(
          '[YouTube][Android][NewPipe] Failed: $safeErr. Falling back to AndroidLegacyYouTubeResolver...',
        );
        if (Platform.isAndroid) {
          AndroidDiagnosticLogger.instance.log(
            'YT_NEWPIPE_FAIL',
            'videoId=$cleanInput, type=${newPipeError.runtimeType}, error=$safeErr',
          );
        }
      }

      // 2. Fallback: Legacy InnerTube / HTML scrape resolver
      try {
        debugPrint(
          '[YouTube][Android][Legacy] Attempting fallback extraction (attempt $attempts)...',
        );
        if (Platform.isAndroid) {
          AndroidDiagnosticLogger.instance.log(
            'YT_LEGACY_START',
            'Attempting Legacy fallback for videoId=$cleanInput (attempt $attempts)',
          );
        }
        final legacyResult = await _legacyResolver.resolveAudioStreamDetails(
          cleanInput,
          timeout: timeout,
        );
        if (legacyResult.url.isNotEmpty) {
          debugPrint(
            '[YouTube][Android][Legacy] Fallback extraction succeeded',
          );
          if (Platform.isAndroid) {
            AndroidDiagnosticLogger.instance.log(
              'YT_LEGACY_OK',
              'Fallback extraction succeeded for videoId=$cleanInput, bitrate=${legacyResult.bitrate}',
            );
          }
          return legacyResult;
        }
      } catch (legacyError) {
        final safeErr = legacyError.toString().split('?').first;
        debugPrint('[YouTube][Android][Legacy] Fallback failed: $safeErr');
        if (Platform.isAndroid) {
          AndroidDiagnosticLogger.instance.log(
            'YT_LEGACY_FAIL',
            'videoId=$cleanInput, type=${legacyError.runtimeType}, error=$safeErr',
          );
        }

        // Jika error terkait DNS lookup / SocketException sementara dan masih ada percobaan tersisa, beri jeda singkat
        final isDnsOrSocket =
            safeErr.contains('No address associated with hostname') ||
            safeErr.contains('SocketException') ||
            safeErr.contains('HandshakeException') ||
            safeErr.contains('Connection refused');

        if (isDnsOrSocket && attempts < maxAttempts) {
          debugPrint(
            '[YouTube][Android] Transient network/DNS error detected. Retrying once after 600ms...',
          );
          if (Platform.isAndroid) {
            AndroidDiagnosticLogger.instance.log(
              'YT_RESOLVE_RETRY',
              'Retrying videoId=$cleanInput due to transient network/DNS error: $safeErr',
            );
          }
          await Future.delayed(const Duration(milliseconds: 600));
          continue;
        }
      }

      // Jika NewPipe dan Legacy gagal dan bukan transient retryable error, keluar dari loop
      break;
    }

    // 3. Both resolvers failed -> return clear error
    debugPrint(
      '[YouTube][Android] Both NewPipe and Legacy resolvers failed for $cleanInput',
    );
    if (Platform.isAndroid) {
      AndroidDiagnosticLogger.instance.log(
        'YT_RESOLVE_BOTH_FAILED',
        'Both NewPipe and Legacy resolvers failed for videoId=$cleanInput after $attempts attempts',
      );
    }
    throw Exception(
      'Gagal mendapatkan sumber audio YouTube yang dapat diputar di Android (NewPipe dan Legacy resolver gagal).',
    );
  }
}
