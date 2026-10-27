import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../../models/youtube_model.dart';

class YouTubeCacheService {
  static final YouTubeCacheService instance = YouTubeCacheService._internal();

  YouTubeCacheService._internal();

  Directory? _cacheDir;

  Future<Directory> _getCacheDirectory({bool createIfMissing = false}) async {
    if (_cacheDir != null && _cacheDir!.existsSync()) return _cacheDir!;
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${docDir.path}/mymusic_cache/youtube');
      if (createIfMissing && !dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      _cacheDir = dir;
      return dir;
    } catch (_) {
      final tmpDir = Directory.systemTemp;
      final dir = Directory('${tmpDir.path}/mymusic_cache/youtube');
      if (createIfMissing && !dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      _cacheDir = dir;
      return dir;
    }
  }

  Future<Directory?> _getVideoFolder(
    String videoId, {
    bool createIfMissing = false,
  }) async {
    final parentDir = await _getCacheDirectory(
      createIfMissing: createIfMissing,
    );
    final folder = Directory('${parentDir.path}/$videoId');
    if (createIfMissing && !folder.existsSync()) {
      folder.createSync(recursive: true);
    }
    if (!folder.existsSync()) return null;
    return folder;
  }

  /// Saves metadata and artwork locally for a video (creates cache folder if needed)
  Future<void> cacheVideoData(YouTubeVideo video) async {
    try {
      final folder = await _getVideoFolder(
        video.videoId,
        createIfMissing: true,
      );
      if (folder == null) return;

      final metaFile = File('${folder.path}/metadata.json');
      await metaFile.writeAsString(jsonEncode(video.toMap()), encoding: utf8);

      if (video.thumbnailUrl != null && video.thumbnailUrl!.isNotEmpty) {
        final artFile = File('${folder.path}/artwork.jpg');
        if (!artFile.existsSync()) {
          final response = await http
              .get(Uri.parse(video.thumbnailUrl!))
              .timeout(const Duration(seconds: 10));
          if (response.statusCode == 200) {
            await artFile.writeAsBytes(response.bodyBytes);
          }
        }
      }
    } catch (e) {
      debugPrint(
        'YouTubeCacheService: Failed to cache video data (${video.videoId}): $e',
      );
    }
  }

  /// Retrieves cached YouTubeVideo metadata if available (does NOT create empty folder on read)
  Future<YouTubeVideo?> getCachedVideo(String videoId) async {
    try {
      final folder = await _getVideoFolder(videoId, createIfMissing: false);
      if (folder == null) return null;

      final metaFile = File('${folder.path}/metadata.json');
      if (metaFile.existsSync()) {
        final content = await metaFile.readAsString(encoding: utf8);
        final map = jsonDecode(content) as Map<String, dynamic>;
        return YouTubeVideo.fromMap(map);
      }
    } catch (e) {
      debugPrint(
        'YouTubeCacheService: Failed to get cached video ($videoId): $e',
      );
    }
    return null;
  }

  /// Returns cached local artwork file path if available (does NOT create empty folder on read)
  Future<String?> getCachedArtworkPath(String videoId) async {
    try {
      final folder = await _getVideoFolder(videoId, createIfMissing: false);
      if (folder == null) return null;

      final artFile = File('${folder.path}/artwork.jpg');
      if (artFile.existsSync()) {
        return artFile.path;
      }
    } catch (_) {}
    return null;
  }

  /// Clears all YouTube local cache
  Future<void> clearAllCache() async {
    try {
      final parentDir = await _getCacheDirectory(createIfMissing: false);
      if (parentDir.existsSync()) {
        parentDir.deleteSync(recursive: true);
      }
      _cacheDir = null;
    } catch (e) {
      debugPrint('YouTubeCacheService: Failed to clear cache: $e');
    }
  }
}
