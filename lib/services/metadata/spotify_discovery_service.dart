import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../services/youtube/youtube_service.dart';
import 'metadata_model.dart';
import 'metadata_service.dart';
import 'spotify_url_parser.dart';

class SpotifyDiscoveryResult {
  final bool isDirectUrl;
  final MusicMetadataResult?
  entity; // If input was album, playlist, or single track
  final List<MusicMetadataResult> tracks;
  final List<MusicMetadataResult> albums;
  final List<MusicMetadataResult> playlists;
  final List<MusicMetadataResult> artists;
  final String? errorMessage;

  const SpotifyDiscoveryResult({
    required this.isDirectUrl,
    this.entity,
    required this.tracks,
    this.albums = const [],
    this.playlists = const [],
    this.artists = const [],
    this.errorMessage,
  });

  bool get isEmpty =>
      tracks.isEmpty &&
      albums.isEmpty &&
      playlists.isEmpty &&
      artists.isEmpty &&
      entity == null;
}

/// Discovers music from Spotify URLs, URIs, or public metadata search queries.
class SpotifyDiscoveryService {
  static SpotifyDiscoveryService? _instance;
  static SpotifyDiscoveryService get instance =>
      _instance ??= SpotifyDiscoveryService();

  final http.Client _client;
  final MetadataService _metadataService;
  final YouTubeService _ytService;

  SpotifyDiscoveryService({
    http.Client? client,
    MetadataService? metadataService,
    YouTubeService? ytService,
  }) : _client = client ?? http.Client(),
       _metadataService = metadataService ?? MetadataService.instance,
       _ytService = ytService ?? YouTubeService.instance;

  /// Main search/discovery entry point.
  /// Handles both direct Spotify links/URIs and free-text music searches.
  Future<SpotifyDiscoveryResult> searchOrResolve(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) {
      return const SpotifyDiscoveryResult(isDirectUrl: false, tracks: []);
    }

    // 1. Direct Spotify link or URI detection
    if (SpotifyUrlParser.isValid(clean)) {
      debugPrint('[SpotifyDiscovery] Detected Spotify URL: $clean');
      try {
        final entity = await _metadataService.fetchSpotifyMetadata(clean);
        if (entity != null) {
          if (entity.type == SpotifyEntityType.track) {
            return SpotifyDiscoveryResult(
              isDirectUrl: true,
              entity: entity,
              tracks: [entity],
            );
          } else {
            // Album, playlist, or artist with track list
            return SpotifyDiscoveryResult(
              isDirectUrl: true,
              entity: entity,
              tracks: entity.trackList,
            );
          }
        } else {
          return const SpotifyDiscoveryResult(
            isDirectUrl: true,
            tracks: [],
            errorMessage:
                'Tidak dapat memuat metadata dari tautan Spotify tersebut.',
          );
        }
      } catch (e) {
        debugPrint('[SpotifyDiscovery] Spotify URL fetch error: $e');
        return SpotifyDiscoveryResult(
          isDirectUrl: true,
          tracks: [],
          errorMessage: 'Gagal memproses tautan Spotify: $e',
        );
      }
    }

    // 2. Free-text search: Query public music metadata across tracks, albums, playlists
    List<MusicMetadataResult> tracks = [];
    List<MusicMetadataResult> albums = [];
    List<MusicMetadataResult> playlists = [];
    List<MusicMetadataResult> artists = [];

    // Query tracks via iTunes
    try {
      tracks = await _searchITunes(clean);
    } catch (e) {
      debugPrint('[SpotifyDiscovery] iTunes search error: $e');
    }

    // Supplement tracks via Deezer if empty, and fetch albums/playlists/artists
    try {
      if (tracks.isEmpty) {
        tracks = await _searchDeezer(clean);
      }
      final albumResults = await _searchDeezerAlbums(clean);
      final playlistResults = await _searchDeezerPlaylists(clean);
      final artistResults = await _searchDeezerArtists(clean);

      albums = albumResults;
      playlists = playlistResults;
      artists = artistResults;
    } catch (e) {
      debugPrint('[SpotifyDiscovery] Deezer multi-search error: $e');
    }

    if (tracks.isNotEmpty ||
        albums.isNotEmpty ||
        playlists.isNotEmpty ||
        artists.isNotEmpty) {
      return SpotifyDiscoveryResult(
        isDirectUrl: false,
        tracks: tracks,
        albums: albums,
        playlists: playlists,
        artists: artists,
      );
    }

    // 3. Fallback to YouTube Music metadata if public services are down
    try {
      final ytVideos = await _ytService.search(clean);
      final ytConverted = ytVideos.map((v) {
        return MusicMetadataResult(
          title: v.title,
          artist: v.channelName ?? 'Unknown Artist',
          artists: [v.channelName ?? 'Unknown Artist'],
          album: v.albumName,
          duration: v.durationSeconds,
          artworkUrl: v.thumbnailUrl,
          spotifyUrl: v.sourceUrl,
        );
      }).toList();

      return SpotifyDiscoveryResult(isDirectUrl: false, tracks: ytConverted);
    } catch (e) {
      debugPrint('[SpotifyDiscovery] Fallback search error: $e');
    }

    return const SpotifyDiscoveryResult(
      isDirectUrl: false,
      tracks: [],
      errorMessage: 'Tidak ada hasil ditemukan.',
    );
  }

  /// Open public iTunes Search API (no authentication, HTTPS, CORS-safe, Android+Windows compatible).
  Future<List<MusicMetadataResult>> _searchITunes(String term) async {
    final uri = Uri.parse(
      'https://itunes.apple.com/search',
    ).replace(queryParameters: {'term': term, 'entity': 'song', 'limit': '25'});

    final response = await _client.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return [];

    final decoded = json.decode(utf8.decode(response.bodyBytes));
    if (decoded is! Map || decoded['results'] is! List) return [];

    final List<MusicMetadataResult> list = [];
    for (final item in decoded['results'] as List) {
      if (item is Map) {
        final title = (item['trackName'] ?? '').toString();
        final artist = (item['artistName'] ?? '').toString();
        final album = (item['collectionName'] ?? '').toString();
        final durationMs = (item['trackTimeMillis'] as num?)?.toInt() ?? 0;
        final rawArt = (item['artworkUrl100'] ?? '').toString();
        final hdArt = rawArt
            .replaceAll('100x100bb', '600x600bb')
            .replaceAll('100x100', '600x600');
        final releaseDate = (item['releaseDate'] ?? '').toString();
        final previewUrl = (item['previewUrl'] ?? '').toString();

        if (title.isNotEmpty) {
          list.add(
            MusicMetadataResult(
              title: title,
              artist: artist.isNotEmpty ? artist : null,
              artists: artist.isNotEmpty ? [artist] : const [],
              album: album.isNotEmpty ? album : null,
              albumArtist: artist.isNotEmpty ? artist : null,
              duration: durationMs > 0 ? (durationMs / 1000).round() : null,
              releaseDate: releaseDate.isNotEmpty ? releaseDate : null,
              artworkUrl: hdArt.isNotEmpty ? hdArt : null,
              audioPreviewUrl: previewUrl.isNotEmpty ? previewUrl : null,
            ),
          );
        }
      }
    }
    return list;
  }

  /// Open public Deezer Search API (no authentication, HTTPS).
  Future<List<MusicMetadataResult>> _searchDeezer(String query) async {
    final uri = Uri.parse(
      'https://api.deezer.com/search',
    ).replace(queryParameters: {'q': query, 'limit': '25'});

    final response = await _client.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return [];

    final decoded = json.decode(utf8.decode(response.bodyBytes));
    if (decoded is! Map || decoded['data'] is! List) return [];

    final List<MusicMetadataResult> list = [];
    for (final item in decoded['data'] as List) {
      if (item is Map) {
        final title = (item['title'] ?? '').toString();
        final artist = (item['artist']?['name'] ?? '').toString();
        final album = (item['album']?['title'] ?? '').toString();
        final durationSec = (item['duration'] as num?)?.toInt();
        final art =
            (item['album']?['cover_big'] ??
                    item['album']?['cover_medium'] ??
                    '')
                .toString();
        final preview = (item['preview'] ?? '').toString();

        if (title.isNotEmpty) {
          list.add(
            MusicMetadataResult(
              title: title,
              artist: artist.isNotEmpty ? artist : null,
              artists: artist.isNotEmpty ? [artist] : const [],
              album: album.isNotEmpty ? album : null,
              duration: durationSec,
              artworkUrl: art.isNotEmpty ? art : null,
              audioPreviewUrl: preview.isNotEmpty ? preview : null,
            ),
          );
        }
      }
    }
    return list;
  }

  /// Searches public albums.
  Future<List<MusicMetadataResult>> _searchDeezerAlbums(String query) async {
    final uri = Uri.parse(
      'https://api.deezer.com/search/album',
    ).replace(queryParameters: {'q': query, 'limit': '15'});
    final response = await _client.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return [];

    final decoded = json.decode(utf8.decode(response.bodyBytes));
    if (decoded is! Map || decoded['data'] is! List) return [];

    final List<MusicMetadataResult> list = [];
    for (final item in decoded['data'] as List) {
      if (item is Map) {
        final id = item['id']?.toString();
        final title = (item['title'] ?? '').toString();
        final artist = (item['artist']?['name'] ?? '').toString();
        final art = (item['cover_big'] ?? item['cover_medium'] ?? '')
            .toString();
        final trackCount = (item['nb_tracks'] as num?)?.toInt();

        if (title.isNotEmpty) {
          list.add(
            MusicMetadataResult(
              spotifyId: id,
              title: title,
              artist: artist.isNotEmpty ? artist : null,
              artists: artist.isNotEmpty ? [artist] : const [],
              album: title,
              artworkUrl: art.isNotEmpty ? art : null,
              popularity: trackCount,
              type: SpotifyEntityType.album,
            ),
          );
        }
      }
    }
    return list;
  }

  /// Searches public playlists.
  Future<List<MusicMetadataResult>> _searchDeezerPlaylists(String query) async {
    final uri = Uri.parse(
      'https://api.deezer.com/search/playlist',
    ).replace(queryParameters: {'q': query, 'limit': '15'});
    final response = await _client.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return [];

    final decoded = json.decode(utf8.decode(response.bodyBytes));
    if (decoded is! Map || decoded['data'] is! List) return [];

    final List<MusicMetadataResult> list = [];
    for (final item in decoded['data'] as List) {
      if (item is Map) {
        final id = item['id']?.toString();
        final title = (item['title'] ?? '').toString();
        final creator = (item['user']?['name'] ?? '').toString();
        final art = (item['picture_big'] ?? item['picture_medium'] ?? '')
            .toString();
        final trackCount = (item['nb_tracks'] as num?)?.toInt();

        if (title.isNotEmpty) {
          list.add(
            MusicMetadataResult(
              spotifyId: id,
              title: title,
              artist: creator.isNotEmpty ? creator : 'Playlist',
              artworkUrl: art.isNotEmpty ? art : null,
              popularity: trackCount,
              type: SpotifyEntityType.playlist,
            ),
          );
        }
      }
    }
    return list;
  }

  /// Searches public artists.
  Future<List<MusicMetadataResult>> _searchDeezerArtists(String query) async {
    final uri = Uri.parse(
      'https://api.deezer.com/search/artist',
    ).replace(queryParameters: {'q': query, 'limit': '10'});
    final response = await _client.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return [];

    final decoded = json.decode(utf8.decode(response.bodyBytes));
    if (decoded is! Map || decoded['data'] is! List) return [];

    final List<MusicMetadataResult> list = [];
    for (final item in decoded['data'] as List) {
      if (item is Map) {
        final id = item['id']?.toString();
        final name = (item['name'] ?? '').toString();
        final art = (item['picture_big'] ?? item['picture_medium'] ?? '')
            .toString();

        if (name.isNotEmpty) {
          list.add(
            MusicMetadataResult(
              spotifyId: id,
              title: name,
              artist: name,
              artworkUrl: art.isNotEmpty ? art : null,
              type: SpotifyEntityType.artist,
            ),
          );
        }
      }
    }
    return list;
  }

  /// Loads full tracklist for an album or playlist entity.
  Future<List<MusicMetadataResult>> loadEntityTracks(
    MusicMetadataResult entity,
  ) async {
    // 1. If it already has tracks, return them
    if (entity.trackList.isNotEmpty) {
      return entity.trackList;
    }

    // 2. If it has a Spotify URL, resolve via MetadataService
    if (entity.spotifyUrl != null &&
        SpotifyUrlParser.isValid(entity.spotifyUrl!)) {
      final res = await _metadataService.fetchSpotifyMetadata(
        entity.spotifyUrl!,
      );
      if (res != null && res.trackList.isNotEmpty) {
        return res.trackList;
      }
    }

    // 3. If it has an ID, query tracks from public endpoint
    final id = entity.spotifyId;
    if (id != null && id.isNotEmpty) {
      try {
        final endpoint = entity.type == SpotifyEntityType.album
            ? 'https://api.deezer.com/album/$id/tracks'
            : entity.type == SpotifyEntityType.playlist
            ? 'https://api.deezer.com/playlist/$id/tracks'
            : null;

        if (endpoint != null) {
          final resp = await _client
              .get(Uri.parse(endpoint))
              .timeout(const Duration(seconds: 8));
          if (resp.statusCode == 200) {
            final decoded = json.decode(utf8.decode(resp.bodyBytes));
            if (decoded is Map && decoded['data'] is List) {
              final List<MusicMetadataResult> tracks = [];
              for (final t in decoded['data']) {
                if (t is Map) {
                  final tTitle = (t['title'] ?? '').toString();
                  final tArtist = (t['artist']?['name'] ?? entity.artist ?? '')
                      .toString();
                  final tDur = (t['duration'] as num?)?.toInt();
                  final tAlbumName =
                      (t['album']?['title'] ??
                              (entity.type == SpotifyEntityType.album
                                  ? entity.title
                                  : null))
                          ?.toString();
                  final tArtwork =
                      (t['album']?['cover_big'] ??
                              t['album']?['cover_medium'] ??
                              t['album']?['cover'] ??
                              (entity.type == SpotifyEntityType.album
                                  ? entity.artworkUrl
                                  : null))
                          ?.toString();
                  if (tTitle.isNotEmpty) {
                    tracks.add(
                      MusicMetadataResult(
                        spotifyId: t['id']?.toString(),
                        title: tTitle,
                        artist: tArtist.isNotEmpty ? tArtist : null,
                        artists: tArtist.isNotEmpty
                            ? [tArtist]
                            : entity.artists,
                        album: tAlbumName,
                        duration: tDur,
                        artworkUrl: tArtwork,
                        type: SpotifyEntityType.track,
                      ),
                    );
                  }
                }
              }
              return tracks;
            }
          }
        }
      } catch (e) {
        debugPrint('[SpotifyDiscovery] loadEntityTracks error: $e');
      }
    }

    return [];
  }
}
