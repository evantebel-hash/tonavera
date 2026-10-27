import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../models/youtube_model.dart';

class YouTubeResolver {
  static final YouTubeResolver instance = YouTubeResolver._internal();

  YouTubeResolver._internal();

  String? _cachedYtDlpPath;

  /// Finds valid path to yt-dlp executable on Windows using application-relative paths
  Future<String?> getExecutablePath() async {
    if (_cachedYtDlpPath != null && File(_cachedYtDlpPath!).existsSync()) {
      return _cachedYtDlpPath;
    }

    if (!Platform.isWindows) {
      return null;
    }

    final cwd = Directory.current.path;
    final exeDir = File(Platform.resolvedExecutable).parent.path;

    final candidatePaths = [
      '$exeDir\\bin\\yt-dlp.exe',
      '$exeDir\\yt-dlp.exe',
      '$cwd\\bin\\yt-dlp.exe',
      '$cwd\\yt-dlp.exe',
      '$cwd\\windows\\bin\\yt-dlp.exe',
      '$cwd\\..\\yt-dlp.exe',
      '$cwd\\..\\bin\\yt-dlp.exe',
      '$cwd\\mymusic_flutter\\bin\\yt-dlp.exe',
      '$cwd\\mymusic_flutter\\windows\\bin\\yt-dlp.exe',
    ];

    for (final path in candidatePaths) {
      final file = File(path);
      if (file.existsSync()) {
        _cachedYtDlpPath = file.path;
        debugPrint('[YouTube][Windows] yt-dlp path=$_cachedYtDlpPath');
        return _cachedYtDlpPath;
      }
    }

    return null;
  }

  /// Test seam: when set, [resolveAudioStreamUrl] delegates to this function
  /// instead of spawning yt-dlp, so playback regression tests stay hermetic.
  /// Production code never sets this.
  static Future<String> Function(String videoIdOrUrl)? debugResolveOverride;

  /// Resolves direct audio stream URL for a given YouTube videoId or URL on Windows
  Future<String> resolveAudioStreamUrl(
    String videoIdOrUrl, {
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final override = debugResolveOverride;
    if (override != null) {
      return override(videoIdOrUrl);
    }
    final cleanInput = videoIdOrUrl.trim();
    if (cleanInput.isEmpty) {
      throw Exception('Video ID / URL YouTube tidak boleh kosong.');
    }

    if (!Platform.isWindows) {
      throw UnsupportedError(
        'YouTubeResolver hanya didukung di platform Windows.',
      );
    }

    final videoUrl = cleanInput.startsWith('http')
        ? cleanInput
        : 'https://www.youtube.com/watch?v=$cleanInput';

    final videoId = cleanInput.startsWith('http')
        ? (Uri.tryParse(cleanInput)?.queryParameters['v'] ?? cleanInput)
        : cleanInput;

    debugPrint('[YouTube][Windows] Resolving videoId=$videoId');

    final ytDlpPath = await getExecutablePath();
    if (ytDlpPath == null) {
      throw Exception(
        'Engine YouTube (yt-dlp.exe) tidak ditemukan. Pastikan binary yt-dlp.exe terpasang di folder bin.',
      );
    }

    Process? process;
    try {
      process = await Process.start(ytDlpPath, [
        videoUrl,
        '-f',
        'bestaudio/best',
        '-g',
        '--no-warnings',
        '--skip-download',
      ], runInShell: false);

      final stdoutFuture = utf8.decoder.bind(process.stdout).join();
      final stderrFuture = utf8.decoder.bind(process.stderr).join();

      final results =
          await Future.wait([
            stdoutFuture,
            stderrFuture,
            process.exitCode,
          ]).timeout(
            timeout,
            onTimeout: () {
              debugPrint(
                '[YouTube][Windows] TIMEOUT reached (${timeout.inSeconds}s). Killing process...',
              );
              process?.kill(ProcessSignal.sigkill);
              throw TimeoutException(
                'Proses penyiapan audio YouTube mengalami batas waktu (${timeout.inSeconds} detik).',
              );
            },
          );

      final stdoutStr = (results[0] as String).trim();
      final stderrStr = (results[1] as String).trim();
      final exitCode = results[2] as int;

      if (stderrStr.isNotEmpty) {
        debugPrint('[YouTube][Windows] stderr: $stderrStr');
      }

      if (exitCode == 0) {
        final lines = stdoutStr
            .split('\n')
            .map((s) => s.trim())
            .where((s) => s.startsWith('http'))
            .toList();

        if (lines.isNotEmpty) {
          debugPrint('[YouTube][Windows] Stream resolved');
          return lines.first;
        }
      }

      throw Exception(
        stderrStr.isNotEmpty
            ? stderrStr
            : 'Resolving audio stream gagal (exit code $exitCode).',
      );
    } on TimeoutException catch (e) {
      process?.kill(ProcessSignal.sigkill);
      debugPrint('[YouTube][Windows] ERROR Timeout: $e');
      throw Exception(
        'YouTube audio gagal disiapkan (timeout). Silakan coba lagi.',
      );
    } catch (e) {
      process?.kill(ProcessSignal.sigkill);
      debugPrint('[YouTube][Windows] ERROR: $e');
      throw Exception('Gagal memproses URL audio YouTube: $e');
    }
  }

  /// Fetches single video metadata via yt-dlp on Windows
  Future<YouTubeVideo?> fetchVideoMetadataViaYtDlp(
    String videoIdOrUrl, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final cleanInput = videoIdOrUrl.trim();
    if (cleanInput.isEmpty || !Platform.isWindows) return null;

    final targetUrl = cleanInput.startsWith('http')
        ? cleanInput
        : 'https://www.youtube.com/watch?v=$cleanInput';

    final ytDlpPath = await getExecutablePath();
    if (ytDlpPath == null) return null;

    Process? process;
    try {
      process = await Process.start(ytDlpPath, [
        targetUrl,
        '-j',
        '--skip-download',
        '--no-warnings',
      ], runInShell: false);

      final stdoutFuture = utf8.decoder.bind(process.stdout).join();
      final stderrFuture = utf8.decoder.bind(process.stderr).join();

      final results =
          await Future.wait([
            stdoutFuture,
            stderrFuture,
            process.exitCode,
          ]).timeout(
            timeout,
            onTimeout: () {
              process?.kill(ProcessSignal.sigkill);
              throw TimeoutException(
                'Batas waktu fetching metadata YouTube tercapai.',
              );
            },
          );

      final stdoutStr = (results[0] as String).trim();
      final exitCode = results[2] as int;

      if (exitCode == 0 && stdoutStr.isNotEmpty) {
        final data = json.decode(stdoutStr) as Map<String, dynamic>;
        final vId = data['id']?.toString() ?? cleanInput;
        final title = data['title']?.toString() ?? 'YouTube Track $cleanInput';
        final channel =
            data['uploader']?.toString() ??
            data['channel']?.toString() ??
            'YouTube';
        final durationSec = (data['duration'] is num)
            ? (data['duration'] as num).toInt()
            : (data['duration_string'] != null
                  ? _parseDurationString(data['duration_string'].toString())
                  : 0);

        String? thumb;
        final thumbs = data['thumbnails'] as List<dynamic>?;
        if (thumbs != null && thumbs.isNotEmpty) {
          thumb = thumbs.last['url']?.toString();
        }
        thumb ??= 'https://i.ytimg.com/vi/$vId/hqdefault.jpg';

        return YouTubeVideo(
          videoId: vId,
          title: title,
          channelName: channel,
          thumbnailUrl: thumb,
          durationSeconds: durationSec,
        );
      }
    } catch (e) {
      process?.kill(ProcessSignal.sigkill);
      debugPrint(
        '[YouTube][Windows] ERROR fetch video metadata via yt-dlp: $e',
      );
    }
    return null;
  }

  /// Fetches playlist metadata and entry list via yt-dlp flat playlist JSON extraction
  Future<YouTubePlaylist?> fetchPlaylistViaYtDlp(
    String playlistId, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final cleanId = playlistId.trim();
    if (cleanId.isEmpty || !Platform.isWindows) return null;

    final targetUrl = cleanId.startsWith('http')
        ? cleanId
        : 'https://www.youtube.com/playlist?list=$cleanId';

    final ytDlpPath = await getExecutablePath();
    if (ytDlpPath == null) {
      debugPrint(
        '[YouTube][Windows] yt-dlp executable not found for playlist fetch.',
      );
      return null;
    }

    debugPrint(
      '[YouTube][Windows] START fetch playlist via yt-dlp: $targetUrl',
    );

    Process? process;
    try {
      process = await Process.start(ytDlpPath, [
        targetUrl,
        '--flat-playlist',
        '-j',
        '--no-warnings',
        '--ignore-errors',
      ], runInShell: false);

      String title = 'YouTube Playlist';
      String? channelName;
      String? thumbnailUrl;
      final items = <YouTubePlaylistItem>[];

      final stdoutStream = utf8.decoder
          .bind(process.stdout)
          .transform(const LineSplitter());
      final stderrFuture = utf8.decoder.bind(process.stderr).join();

      final streamSubscription = stdoutStream.listen((line) {
        if (line.trim().isEmpty) return;
        try {
          final data = json.decode(line) as Map<String, dynamic>;
          final vId = data['id']?.toString();
          final itemTitle = data['title']?.toString();

          final pTitle =
              data['playlist_title']?.toString() ??
              data['playlist']?.toString();
          if (pTitle != null && pTitle.isNotEmpty) {
            title = pTitle;
          }
          final pChannel =
              data['playlist_uploader']?.toString() ??
              data['playlist_channel']?.toString();
          if (pChannel != null && pChannel.isNotEmpty) {
            channelName = pChannel;
          }

          if (vId != null &&
              vId.isNotEmpty &&
              itemTitle != null &&
              itemTitle.isNotEmpty &&
              itemTitle != '[Private video]' &&
              itemTitle != '[Deleted video]' &&
              itemTitle != '[Unavailable video]') {
            final durationSec = (data['duration'] is num)
                ? (data['duration'] as num).toInt()
                : (data['duration_string'] != null
                      ? _parseDurationString(data['duration_string'].toString())
                      : 0);

            final channel =
                data['uploader']?.toString() ??
                data['channel']?.toString() ??
                'YouTube';

            String? thumb;
            final thumbs = data['thumbnails'] as List<dynamic>?;
            if (thumbs != null && thumbs.isNotEmpty) {
              thumb = thumbs.last['url']?.toString();
            }
            if (thumb == null || thumb.isEmpty) {
              thumb = 'https://i.ytimg.com/vi/$vId/hqdefault.jpg';
            }

            items.add(
              YouTubePlaylistItem(
                playlistId: cleanId,
                videoId: vId,
                position: items.length,
                title: itemTitle,
                channelName: channel,
                thumbnailUrl: thumb,
                durationSeconds: durationSec,
              ),
            );
          }
        } catch (e) {
          debugPrint('[YouTube][Windows] Error parsing playlist json line: $e');
        }
      });

      final results =
          await Future.wait([
            streamSubscription.asFuture(),
            stderrFuture,
            process.exitCode,
          ]).timeout(
            timeout,
            onTimeout: () {
              debugPrint(
                '[YouTube][Windows] Playlist fetch TIMEOUT reached. Killing process...',
              );
              process?.kill(ProcessSignal.sigkill);
              throw TimeoutException(
                'Batas waktu fetching playlist YouTube tercapai.',
              );
            },
          );

      final stderrStr = (results[1] as String).trim();
      final exitCode = results[2] as int;

      debugPrint(
        '[YouTube][Windows] Playlist fetch exit code: $exitCode, items parsed: ${items.length}',
      );
      if (stderrStr.isNotEmpty) {
        debugPrint('[YouTube][Windows] Playlist fetch stderr: $stderrStr');
      }

      if (items.isNotEmpty || exitCode == 0) {
        thumbnailUrl = items.isNotEmpty ? items.first.thumbnailUrl : null;
        return YouTubePlaylist(
          playlistId: cleanId,
          title: title,
          channelName: channelName,
          thumbnailUrl: thumbnailUrl,
          itemCount: items.length,
          items: items,
        );
      }
      return null;
    } catch (e) {
      process?.kill(ProcessSignal.sigkill);
      debugPrint('[YouTube][Windows] ERROR fetch playlist via yt-dlp: $e');
      return null;
    }
  }

  static int _parseDurationString(String durStr) {
    try {
      final parts = durStr.split(':').map((e) => int.parse(e.trim())).toList();
      if (parts.length == 3) {
        return parts[0] * 3600 + parts[1] * 60 + parts[2];
      } else if (parts.length == 2) {
        return parts[0] * 60 + parts[1];
      } else if (parts.length == 1) {
        return parts[0];
      }
    } catch (_) {}
    return 0;
  }
}
