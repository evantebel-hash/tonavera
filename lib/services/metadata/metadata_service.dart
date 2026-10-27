import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../models/song_model.dart';
import 'metadata_cache.dart';
import 'metadata_model.dart';
import 'metadata_provider.dart';
import 'spotify_metadata_provider.dart';
import 'spotify_url_parser.dart';
import 'youtube_metadata_provider.dart';
import '../youtube/youtube_parser.dart';

/// Central facade for music metadata operations.
/// Supports multiple metadata providers with caching and safe local music merging.
class MetadataService {
  static MetadataService? _instance;
  static MetadataService get instance => _instance ??= MetadataService();

  final List<MetadataProvider> _providers;
  final MetadataCache _cache;

  MetadataService({
    List<MetadataProvider>? providers,
    MetadataCache? cache,
    http.Client? client,
  }) : _providers =
           providers ??
           [
             SpotifyMetadataProvider(client: client),
             YouTubeMetadataProvider(client: client),
           ],
       _cache = cache ?? MetadataCache();

  /// Retrieves metadata from any matching registered provider with caching.
  Future<MusicMetadataResult?> fetchMetadata(String input) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    // Check cache for Spotify URLs
    final parsed = SpotifyUrlParser.parse(trimmed);
    String? cacheKey;
    if (parsed != null && parsed.isValid) {
      cacheKey = 'spotify:${parsed.type.name}:${parsed.id}';
    } else {
      final ytInfo = YouTubeParser.parseLinkOrQuery(trimmed);
      if (ytInfo.type == YouTubeLinkType.video && ytInfo.videoId != null) {
        cacheKey = 'youtube:video:${ytInfo.videoId}';
      } else if (ytInfo.type == YouTubeLinkType.playlist &&
          ytInfo.playlistId != null) {
        cacheKey = 'youtube:playlist:${ytInfo.playlistId}';
      } else if (ytInfo.type == YouTubeLinkType.channel) {
        final target = ytInfo.channelHandle ?? ytInfo.channelId ?? 'channel';
        cacheKey = 'youtube:channel:$target';
      }
    }

    if (cacheKey != null) {
      final cached = _cache.get(cacheKey);
      if (cached != null) {
        debugPrint('[MetadataService] Cache HIT for $cacheKey');
        return cached;
      }
    }

    // Attempt through providers
    for (final provider in _providers) {
      if (provider.canHandle(trimmed)) {
        try {
          final result = await provider.fetchMetadata(trimmed);
          if (result != null) {
            if (cacheKey != null) {
              _cache.put(cacheKey, result);
              debugPrint('[MetadataService] Cached result for $cacheKey');
            }
            return result;
          }
        } catch (e) {
          debugPrint(
            '[MetadataService] Provider "${provider.name}" failed: $e',
          );
        }
      }
    }

    return null;
  }

  /// Convenience method specifically for Spotify URLs.
  Future<MusicMetadataResult?> fetchSpotifyMetadata(String url) async {
    return fetchMetadata(url);
  }

  /// Matches a local [SongModel] with metadata fetched from a Spotify URL.
  /// Preserves existing non-empty metadata if [overwriteExisting] is false.
  Future<SongModel?> matchLocalSongWithSpotify(
    SongModel song,
    String spotifyUrl, {
    bool overwriteExisting = false,
  }) async {
    final metadata = await fetchMetadata(spotifyUrl);
    if (metadata == null) return null;

    return metadata.mergeIntoSong(song, overwriteExisting: overwriteExisting);
  }

  /// Clears in-memory metadata cache.
  void clearCache() {
    _cache.clear();
  }

  /// Exposed for testing or inspection.
  MetadataCache get cache => _cache;
}
