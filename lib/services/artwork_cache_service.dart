import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:audiotags/audiotags.dart';

class ArtworkCacheService {
  static Directory? _cacheDir;

  static Future<Directory> get cacheDir async {
    if (_cacheDir != null) return _cacheDir!;
    final tempDir = await getTemporaryDirectory();
    final dir = Directory(p.join(tempDir.path, 'mymusic_artwork_cache'));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    _cacheDir = dir;
    return dir;
  }

  static String getCacheKey(String filePath, String type) {
    final file = File(filePath);
    String modTime = '0';
    if (file.existsSync()) {
      modTime = file.lastModifiedSync().millisecondsSinceEpoch.toString();
    }
    final rawKey = '$filePath|$modTime|$type';
    return rawKey.hashCode.toRadixString(36);
  }

  /// Extracts album or artist artwork from pictures array and saves to local disk cache.
  /// Returns the file path of the cached image, or null if no picture available.
  static Future<String?> extractAndCacheArtwork({
    required String audioFilePath,
    required List<Picture> pictures,
    bool isArtistArtwork = false,
  }) async {
    if (pictures.isEmpty) return null;

    Picture? targetPic;
    if (isArtistArtwork) {
      for (final pic in pictures) {
        if (pic.pictureType == PictureType.artist ||
            pic.pictureType == PictureType.leadArtist ||
            pic.pictureType == PictureType.band ||
            pic.pictureType == PictureType.bandLogo) {
          targetPic = pic;
          break;
        }
      }
    }

    targetPic ??= pictures.firstWhere(
      (pic) => pic.pictureType == PictureType.coverFront,
      orElse: () => pictures.first,
    );

    if (targetPic.bytes.isEmpty) return null;

    try {
      final cacheKey = getCacheKey(
        audioFilePath,
        isArtistArtwork ? 'artist' : 'album',
      );
      final ext = targetPic.mimeType == MimeType.png ? 'png' : 'jpg';
      final dir = await cacheDir;
      final cachedFile = File(p.join(dir.path, '$cacheKey.$ext'));

      if (!cachedFile.existsSync()) {
        await cachedFile.writeAsBytes(targetPic.bytes, flush: true);
        debugPrint('[Artwork] Cache WRITE success: ${cachedFile.path}');
      } else {
        debugPrint('[Artwork] Cache HIT: ${cachedFile.path}');
      }

      return cachedFile.path;
    } catch (e) {
      debugPrint('[Artwork] Error caching artwork: $e');
      return null;
    }
  }

  /// Invalidate cache for a file path (e.g. after metadata edit)
  static Future<void> invalidateCache(String audioFilePath) async {
    try {
      final dir = await cacheDir;
      final keyAlbum = getCacheKey(audioFilePath, 'album');
      final keyArtist = getCacheKey(audioFilePath, 'artist');
      for (final entity in dir.listSync()) {
        if (entity is File) {
          final name = p.basename(entity.path);
          if (name.startsWith(keyAlbum) || name.startsWith(keyArtist)) {
            entity.deleteSync();
          }
        }
      }
    } catch (e) {
      debugPrint('[Artwork] Error invalidating cache: $e');
    }
  }
}
