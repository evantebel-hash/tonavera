import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'metadata_model.dart';
import 'metadata_provider.dart';
import 'spotify_url_parser.dart';

/// Non-official Spotify metadata provider.
///
/// STRICTURES:
/// - DOES NOT use api.spotify.com
/// - DOES NOT use Spotify Web API, Client ID, Client Secret, OAuth, or PKCE
/// - DOES NOT require Spotify Premium or developer accounts
/// - Communicates strictly via public web HTTPS endpoints (Embed pages / oEmbed)
class SpotifyMetadataProvider implements MetadataProvider {
  static const Duration defaultTimeout = Duration(seconds: 10);
  final http.Client _client;
  final Duration timeout;

  SpotifyMetadataProvider({http.Client? client, this.timeout = defaultTimeout})
    : _client = client ?? http.Client();

  @override
  String get name => 'Spotify (Public)';

  @override
  bool canHandle(String input) {
    return SpotifyUrlParser.isValid(input);
  }

  @override
  Future<MusicMetadataResult?> fetchMetadata(String input) async {
    final parsed = SpotifyUrlParser.parse(input);
    if (parsed == null || !parsed.isValid) {
      debugPrint(
        '[SpotifyMetadataProvider] Invalid or unparseable Spotify URL: $input',
      );
      return null;
    }

    // Primary strategy: Public Embed Page (__NEXT_DATA__)
    try {
      final embedResult = await _fetchFromEmbedPage(parsed);
      if (embedResult != null) {
        return embedResult;
      }
    } catch (e) {
      debugPrint('[SpotifyMetadataProvider] Embed page lookup failed: $e');
    }

    // Secondary fallback strategy: Public oEmbed API
    try {
      final oembedResult = await _fetchFromOEmbed(parsed);
      if (oembedResult != null) {
        return oembedResult;
      }
    } catch (e) {
      debugPrint('[SpotifyMetadataProvider] oEmbed fallback failed: $e');
    }

    return null;
  }

  /// Primary extractor: Fetches public embed page HTML and extracts __NEXT_DATA__ JSON.
  Future<MusicMetadataResult?> _fetchFromEmbedPage(
    SpotifyParsedUrl parsed,
  ) async {
    final embedUrl = Uri.parse(
      'https://open.spotify.com/embed/${parsed.type.name}/${parsed.id}',
    );

    final response = await _client
        .get(
          embedUrl,
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept':
                'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.9',
          },
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      debugPrint(
        '[SpotifyMetadataProvider] Embed HTTP status: ${response.statusCode}',
      );
      return null;
    }

    final html = utf8.decode(response.bodyBytes, allowMalformed: true);
    return parseEmbedHtml(html, parsed);
  }

  /// Parses embed HTML content containing `<script id="__NEXT_DATA__">`.
  /// Exposed as static/pure function for unit testability without network.
  static MusicMetadataResult? parseEmbedHtml(
    String html,
    SpotifyParsedUrl parsed,
  ) {
    final scriptRegex = RegExp(
      r'<script\s+id="__NEXT_DATA__"\s+type="application\/json">([\s\S]*?)<\/script>',
      caseSensitive: false,
    );

    final match = scriptRegex.firstMatch(html);
    if (match == null) {
      debugPrint(
        '[SpotifyMetadataProvider] __NEXT_DATA__ script tag not found',
      );
      return null;
    }

    final jsonString = match.group(1);
    if (jsonString == null || jsonString.trim().isEmpty) {
      return null;
    }

    dynamic decoded;
    try {
      decoded = json.decode(jsonString);
    } catch (e) {
      debugPrint(
        '[SpotifyMetadataProvider] Failed to decode __NEXT_DATA__ JSON: $e',
      );
      return null;
    }

    if (decoded is! Map<String, dynamic>) return null;

    final entity = decoded['props']?['pageProps']?['state']?['data']?['entity'];
    if (entity is! Map<String, dynamic>) {
      debugPrint('[SpotifyMetadataProvider] Entity data missing in JSON');
      return null;
    }

    return _parseEntity(entity, parsed);
  }

  static MusicMetadataResult _parseEntity(
    Map<String, dynamic> entity,
    SpotifyParsedUrl parsed,
  ) {
    final rawTitle = entity['name'] ?? entity['title'] ?? '';
    final title = rawTitle.toString().trim();

    // Artists extraction
    List<String> artists = [];
    List<ArtistMetadataInfo> artistList = [];
    String? primaryArtist;
    final artistsData = entity['artists'];
    if (artistsData is List) {
      for (final a in artistsData) {
        if (a is Map && a['name'] != null) {
          final aName = a['name'].toString().trim();
          if (aName.isNotEmpty) {
            artists.add(aName);
            final aUri = (a['uri'] ?? '').toString();
            final aId = aUri.contains(':')
                ? aUri.split(':').last
                : (a['id']?.toString());
            artistList.add(
              ArtistMetadataInfo(name: aName, id: aId, provider: 'spotify'),
            );
          }
        }
      }
    }

    if (artists.isNotEmpty) {
      primaryArtist = artists.first;
    } else if (entity['subtitle'] != null &&
        entity['subtitle'].toString().trim().isNotEmpty) {
      primaryArtist = entity['subtitle'].toString().trim();
      artists = [primaryArtist];
      artistList = [
        ArtistMetadataInfo(
          name: primaryArtist,
          id: (parsed.type == SpotifyEntityType.artist) ? parsed.id : null,
          provider: 'spotify',
        ),
      ];
    }

    // Duration extraction (ms -> seconds)
    int? durationSec;
    final rawDuration = entity['duration'];
    if (rawDuration is num && rawDuration > 0) {
      durationSec = (rawDuration / 1000).round();
    }

    // Release date
    String? releaseDate;
    final rawRelease = entity['releaseDate'];
    if (rawRelease is Map && rawRelease['isoString'] != null) {
      final iso = rawRelease['isoString'].toString();
      releaseDate = iso.contains('T') ? iso.split('T').first : iso;
    } else if (rawRelease is String && rawRelease.isNotEmpty) {
      releaseDate = rawRelease;
    }

    // Explicit
    final isExplicit = entity['isExplicit'] == true;

    // Artwork URL: Find largest image in visualIdentity.image
    String? extractedImageUrl;
    final images = entity['visualIdentity']?['image'];
    if (images is List && images.isNotEmpty) {
      int maxWidth = -1;
      for (final img in images) {
        if (img is Map && img['url'] != null) {
          final w = (img['maxWidth'] as num?)?.toInt() ?? 0;
          if (w > maxWidth || extractedImageUrl == null) {
            maxWidth = w;
            extractedImageUrl = img['url'].toString();
          }
        }
      }
    }

    // Entity-specific artwork classification
    final String? artistArtworkUrl = (parsed.type == SpotifyEntityType.artist)
        ? extractedImageUrl
        : null;
    final String? albumArtworkUrl = (parsed.type == SpotifyEntityType.album)
        ? extractedImageUrl
        : null;
    final String? trackArtworkUrl = (parsed.type == SpotifyEntityType.track)
        ? extractedImageUrl
        : null;

    // Audio preview
    String? previewUrl;
    final audioPreview = entity['audioPreview'];
    if (audioPreview is Map && audioPreview['url'] != null) {
      previewUrl = audioPreview['url'].toString();
    }

    // Album title: For albums, title is the album title
    final String? albumTitle = (parsed.type == SpotifyEntityType.album)
        ? title
        : null;

    // Track list (for albums, artists, playlists)
    final List<MusicMetadataResult> trackList = [];
    final rawTrackList = entity['trackList'];
    if (rawTrackList is List) {
      for (final t in rawTrackList) {
        if (t is Map<String, dynamic>) {
          final tTitle = (t['title'] ?? '').toString();
          final tSubtitle = (t['subtitle'] ?? '').toString();
          final tDuration = (t['duration'] is num)
              ? ((t['duration'] as num) / 1000).round()
              : null;
          final tUri = (t['uri'] ?? '').toString();
          final tId = tUri.contains(':') ? tUri.split(':').last : null;
          final tExplicit = t['isExplicit'] == true;
          final tPreview = t['audioPreview']?['url']?.toString();

          // Extract track artist list if provided in track object
          List<String> tArtists = [];
          List<ArtistMetadataInfo> tArtistList = [];
          final tRawArtists = t['artists'];
          if (tRawArtists is List && tRawArtists.isNotEmpty) {
            for (final a in tRawArtists) {
              if (a is Map && a['name'] != null) {
                final aName = a['name'].toString().trim();
                if (aName.isNotEmpty) {
                  tArtists.add(aName);
                  final aUri = (a['uri'] ?? '').toString();
                  final aId = aUri.contains(':')
                      ? aUri.split(':').last
                      : (a['id']?.toString());
                  tArtistList.add(
                    ArtistMetadataInfo(
                      name: aName,
                      id: aId,
                      provider: 'spotify',
                    ),
                  );
                }
              }
            }
          }
          if (tArtists.isEmpty && tSubtitle.isNotEmpty) {
            tArtists = [tSubtitle];
            tArtistList = [
              ArtistMetadataInfo(name: tSubtitle, provider: 'spotify'),
            ];
          } else if (tArtists.isEmpty && primaryArtist != null) {
            tArtists = artists;
            tArtistList = artistList;
          }

          // If this is an artist profile import, ensure the imported artist is the primary artist (index 0)
          if (parsed.type == SpotifyEntityType.artist) {
            final mainIdx = tArtistList.indexWhere(
              (a) =>
                  a.id == parsed.id ||
                  a.name.toLowerCase() == (primaryArtist?.toLowerCase() ?? ''),
            );
            if (mainIdx > 0) {
              final mainInfo = tArtistList.removeAt(mainIdx);
              tArtistList.insert(0, mainInfo);
              if (mainIdx < tArtists.length) {
                final mainName = tArtists.removeAt(mainIdx);
                tArtists.insert(0, mainName);
              }
            }
          }

          // Extract track-specific artwork if provided in track object
          String? tTrackArtwork;
          final tImages =
              t['visualIdentity']?['image'] ??
              t['images'] ??
              t['album']?['images'];
          if (tImages is List && tImages.isNotEmpty) {
            for (final img in tImages) {
              if (img is Map && img['url'] != null) {
                tTrackArtwork = img['url'].toString();
                break;
              }
            }
          }

          // Strict Artwork Assignment for tracks:
          // 1. Specific track artwork (if provided)
          // 2. Album artwork (ONLY if parent entity is an album)
          // NEVER inherit artist photo as track or album artwork!
          final String? tAlbumArtwork = (parsed.type == SpotifyEntityType.album)
              ? albumArtworkUrl
              : null;
          final String? effectiveArtwork = tTrackArtwork ?? tAlbumArtwork;

          trackList.add(
            MusicMetadataResult(
              provider: 'spotify',
              sourceId: tId,
              sourceUrl: tId != null
                  ? 'https://open.spotify.com/track/$tId'
                  : null,
              spotifyId: tId,
              title: tTitle,
              artist: tArtists.isNotEmpty
                  ? tArtists.first
                  : (primaryArtist ?? ''),
              artists: tArtists,
              artistList: tArtistList,
              album: albumTitle,
              duration: tDuration,
              trackArtworkUrl: tTrackArtwork,
              albumArtworkUrl: tAlbumArtwork,
              artworkUrl: effectiveArtwork,
              spotifyUrl: tId != null
                  ? 'https://open.spotify.com/track/$tId'
                  : null,
              explicit: tExplicit,
              audioPreviewUrl: tPreview,
              type: SpotifyEntityType.track,
            ),
          );
        }
      }
    }

    return MusicMetadataResult(
      provider: 'spotify',
      sourceId: parsed.id,
      sourceUrl: parsed.canonicalUrl,
      spotifyId: parsed.id,
      title: title,
      artist: primaryArtist,
      artists: artists,
      artistList: artistList,
      album: albumTitle,
      albumArtist: primaryArtist,
      duration: durationSec,
      releaseDate: releaseDate,
      artistArtworkUrl: artistArtworkUrl,
      albumArtworkUrl: albumArtworkUrl,
      trackArtworkUrl: trackArtworkUrl,
      artworkUrl: extractedImageUrl,
      spotifyUrl: parsed.canonicalUrl,
      explicit: isExplicit,
      audioPreviewUrl: previewUrl,
      type: parsed.type,
      trackList: trackList,
    );
  }

  /// Secondary extractor: Fallback to public Spotify oEmbed API.
  Future<MusicMetadataResult?> _fetchFromOEmbed(SpotifyParsedUrl parsed) async {
    final oembedUri = Uri.parse(
      'https://open.spotify.com/oembed',
    ).replace(queryParameters: {'url': parsed.canonicalUrl});

    final response = await _client
        .get(
          oembedUri,
          headers: {
            'User-Agent': 'MyMusic/1.0 (Public Metadata Resolver)',
            'Accept': 'application/json',
          },
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      return null;
    }

    final decoded = json.decode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) return null;

    final title = (decoded['title'] ?? '').toString().trim();
    final thumbnailUrl = decoded['thumbnail_url']?.toString();

    if (title.isEmpty) return null;

    final String? artistArt = (parsed.type == SpotifyEntityType.artist)
        ? thumbnailUrl
        : null;
    final String? albumArt = (parsed.type == SpotifyEntityType.album)
        ? thumbnailUrl
        : null;
    final String? trackArt = (parsed.type == SpotifyEntityType.track)
        ? thumbnailUrl
        : null;

    return MusicMetadataResult(
      provider: 'spotify',
      sourceId: parsed.id,
      sourceUrl: parsed.canonicalUrl,
      spotifyId: parsed.id,
      title: title,
      artistArtworkUrl: artistArt,
      albumArtworkUrl: albumArt,
      trackArtworkUrl: trackArt,
      artworkUrl: thumbnailUrl,
      spotifyUrl: parsed.canonicalUrl,
      type: parsed.type,
    );
  }
}
