import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../youtube/youtube_normalizer.dart';
import '../youtube/youtube_parser.dart';
import '../youtube/youtube_scraper.dart';
import 'metadata_model.dart';
import 'metadata_provider.dart';
import 'spotify_url_parser.dart';

/// Legitimate YouTube and YouTube Music metadata provider.
///
/// Features:
/// - Official YouTube oEmbed API for video/track metadata (public, no authentication needed)
/// - InnerTube WEB_REMIX API via [YouTubeScraper] for albums and playlists
/// - Strictly extracts metadata only (no audio downloads)
class YouTubeMetadataProvider implements MetadataProvider {
  static const Duration defaultTimeout = Duration(seconds: 10);
  final http.Client _client;
  final YouTubeScraper _scraper;
  final Duration timeout;
  final String? apiKey;

  YouTubeMetadataProvider({
    http.Client? client,
    YouTubeScraper? scraper,
    this.apiKey = const String.fromEnvironment(
      'YOUTUBE_API_KEY',
      defaultValue: '',
    ),
    this.timeout = defaultTimeout,
  }) : _client = client ?? http.Client(),
       _scraper = scraper ?? YouTubeScraper(client: client);

  @override
  String get name => 'YouTube Music (Official/oEmbed)';

  @override
  bool canHandle(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return false;

    // Check if it's a YouTube / YouTube Music URL
    final info = YouTubeParser.parseLinkOrQuery(trimmed);
    return info.type == YouTubeLinkType.video ||
        info.type == YouTubeLinkType.playlist ||
        info.type == YouTubeLinkType.channel;
  }

  @override
  Future<MusicMetadataResult?> fetchMetadata(String input) async {
    final trimmed = input.trim();
    final info = YouTubeParser.parseLinkOrQuery(trimmed);

    // 1. YouTube Video / Track
    if (info.type == YouTubeLinkType.video && info.videoId != null) {
      return _fetchVideoMetadata(info.videoId!, trimmed);
    }

    // 2. YouTube Music Album / Playlist
    if (info.type == YouTubeLinkType.playlist && info.playlistId != null) {
      return _fetchPlaylistMetadata(info.playlistId!, trimmed);
    }

    // 3. YouTube Music Artist / Channel Profile
    if (info.type == YouTubeLinkType.channel) {
      return _fetchChannelMetadata(info, trimmed);
    }

    return null;
  }

  /// Fetches single video metadata via YouTube official oEmbed API
  Future<MusicMetadataResult?> _fetchVideoMetadata(
    String videoId,
    String rawUrl,
  ) async {
    // 1. Try official oEmbed API: https://www.youtube.com/oembed?url=...&format=json
    try {
      final oembedUrl = Uri.parse('https://www.youtube.com/oembed').replace(
        queryParameters: {
          'url': 'https://www.youtube.com/watch?v=$videoId',
          'format': 'json',
        },
      );

      final response = await _client
          .get(
            oembedUrl,
            headers: {
              'User-Agent': 'MyMusic/1.0 (Public Metadata Resolver)',
              'Accept': 'application/json',
            },
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(
          utf8.decode(response.bodyBytes),
        );
        final rawTitle = (data['title'] ?? '').toString().trim();
        final channelName = (data['author_name'] ?? '').toString().trim();
        final thumbnailUrl = (data['thumbnail_url'] ?? '').toString().trim();

        // Extract Artist and Track Title from "Artist - Title" convention if present
        String parsedTitle = rawTitle;
        String? parsedArtist = channelName.isNotEmpty ? channelName : null;

        if (rawTitle.contains(' - ')) {
          final parts = rawTitle.split(' - ');
          if (parts.length >= 2) {
            final possibleArtist = parts[0].trim();
            final possibleTitle = parts.sublist(1).join(' - ').trim();
            if (possibleArtist.isNotEmpty && possibleTitle.isNotEmpty) {
              parsedArtist = possibleArtist;
              parsedTitle = possibleTitle;
            }
          }
        }

        final String? validThumbnail = thumbnailUrl.isNotEmpty
            ? thumbnailUrl
            : null;
        return MusicMetadataResult(
          provider: 'youtube',
          sourceId: videoId,
          sourceUrl: 'https://music.youtube.com/watch?v=$videoId',
          title: parsedTitle.isNotEmpty
              ? parsedTitle
              : 'YouTube Track $videoId',
          artist: parsedArtist,
          artists: parsedArtist != null ? [parsedArtist] : [],
          artistList: parsedArtist != null
              ? [ArtistMetadataInfo(name: parsedArtist, provider: 'youtube')]
              : [],
          album: 'YouTube Music',
          trackArtworkUrl: validThumbnail,
          artworkUrl: validThumbnail,
          type: SpotifyEntityType.track,
        );
      }
    } catch (e) {
      debugPrint('[YouTubeMetadataProvider] oEmbed error: $e');
    }

    // Fallback: standard high-resolution thumbnail
    final fallbackThumbnail = 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
    return MusicMetadataResult(
      provider: 'youtube',
      sourceId: videoId,
      sourceUrl: 'https://music.youtube.com/watch?v=$videoId',
      title: 'YouTube Track $videoId',
      trackArtworkUrl: fallbackThumbnail,
      artworkUrl: fallbackThumbnail,
      type: SpotifyEntityType.track,
    );
  }

  /// Fetches playlist/album metadata via InnerTube API in [YouTubeScraper]
  Future<MusicMetadataResult?> _fetchPlaylistMetadata(
    String playlistId,
    String rawUrl,
  ) async {
    try {
      final playlist = await _scraper.fetchPlaylist(playlistId);
      if (playlist != null) {
        final tracks = playlist.items.map((item) {
          final effectiveChannel = item.channelName ?? playlist.channelName;
          return MusicMetadataResult(
            provider: 'youtube',
            sourceId: item.videoId,
            sourceUrl: 'https://music.youtube.com/watch?v=${item.videoId}',
            title: item.title.isNotEmpty ? item.title : 'Track ${item.videoId}',
            artist: effectiveChannel,
            artists: effectiveChannel != null ? [effectiveChannel] : [],
            artistList: effectiveChannel != null
                ? [
                    ArtistMetadataInfo(
                      name: effectiveChannel,
                      provider: 'youtube',
                    ),
                  ]
                : [],
            album: playlist.title,
            duration: item.durationSeconds > 0 ? item.durationSeconds : null,
            trackArtworkUrl: item.thumbnailUrl,
            artworkUrl: item.thumbnailUrl,
            type: SpotifyEntityType.track,
          );
        }).toList();

        final isAlbum =
            playlistId.startsWith('OLAK5uy_') ||
            playlist.title.toLowerCase().contains('album') ||
            playlist.title.toLowerCase().contains('ep');

        return MusicMetadataResult(
          provider: 'youtube',
          sourceId: playlistId,
          sourceUrl: 'https://music.youtube.com/playlist?list=$playlistId',
          title: playlist.title,
          artist: playlist.channelName,
          artists: playlist.channelName != null ? [playlist.channelName!] : [],
          artistList: playlist.channelName != null
              ? [
                  ArtistMetadataInfo(
                    name: playlist.channelName!,
                    provider: 'youtube',
                  ),
                ]
              : [],
          albumArtworkUrl: isAlbum ? playlist.thumbnailUrl : null,
          artworkUrl: playlist.thumbnailUrl,
          type: isAlbum ? SpotifyEntityType.album : SpotifyEntityType.playlist,
          trackList: tracks,
        );
      }
    } catch (e) {
      debugPrint('[YouTubeMetadataProvider] InnerTube playlist error: $e');
    }

    return null;
  }

  /// Fetches artist / channel metadata via YouTube Data API v3 (if apiKey available)
  /// or InnerTube browse API / HTML channel metadata.
  Future<MusicMetadataResult?> _fetchChannelMetadata(
    YouTubeLinkInfo info,
    String rawUrl,
  ) async {
    final handle = info.channelHandle?.trim();
    final channelId = info.channelId?.trim();
    final cleanKey = (apiKey ?? '').trim();

    // 1. Try official YouTube Data API v3 if API key is provided
    if (cleanKey.isNotEmpty) {
      try {
        final queryParams = <String, String>{
          'part': 'snippet,contentDetails',
          'key': cleanKey,
        };
        if (handle != null && handle.isNotEmpty) {
          final cleanHandle = handle.startsWith('@')
              ? handle.substring(1)
              : handle;
          queryParams['forHandle'] = cleanHandle;
        } else if (channelId != null && channelId.isNotEmpty) {
          queryParams['id'] = channelId;
        }

        final apiUrl = Uri.parse(
          'https://www.googleapis.com/youtube/v3/channels',
        ).replace(queryParameters: queryParams);

        final response = await _client
            .get(apiUrl, headers: {'Accept': 'application/json'})
            .timeout(timeout);

        if (response.statusCode == 200) {
          final data =
              json.decode(utf8.decode(response.bodyBytes))
                  as Map<String, dynamic>;
          final items = data['items'] as List<dynamic>?;
          if (items != null && items.isNotEmpty) {
            final ch = items.first as Map<String, dynamic>;
            final chId = ch['id']?.toString() ?? channelId ?? handle ?? '';
            final snippet = ch['snippet'] as Map<String, dynamic>? ?? {};
            final title =
                snippet['title']?.toString().trim() ??
                handle ??
                'YouTube Artist';
            final thumbs = snippet['thumbnails'] as Map<String, dynamic>? ?? {};
            final avatarUrl =
                (thumbs['high'] ??
                        thumbs['medium'] ??
                        thumbs['default'])?['url']
                    ?.toString();

            // Check contentDetails.relatedPlaylists.uploads for official public track/video uploads
            final relatedPlaylists =
                ch['contentDetails']?['relatedPlaylists']
                    as Map<String, dynamic>?;
            final uploadsPlaylistId = relatedPlaylists?['uploads']
                ?.toString()
                .trim();

            List<MusicMetadataResult> channelTracks = [];
            if (uploadsPlaylistId != null && uploadsPlaylistId.isNotEmpty) {
              try {
                String? pageToken;
                int fetchedCount = 0;
                const int maxTotalTracks =
                    50; // Fetch up to 50 public uploaded tracks

                while (fetchedCount < maxTotalTracks) {
                  final queryParams = <String, String>{
                    'part': 'snippet,contentDetails',
                    'playlistId': uploadsPlaylistId,
                    'maxResults': '25',
                    'key': cleanKey,
                  };
                  if (pageToken != null && pageToken.isNotEmpty) {
                    queryParams['pageToken'] = pageToken;
                  }

                  final playlistItemsUrl = Uri.parse(
                    'https://www.googleapis.com/youtube/v3/playlistItems',
                  ).replace(queryParameters: queryParams);

                  final piResponse = await _client
                      .get(
                        playlistItemsUrl,
                        headers: {'Accept': 'application/json'},
                      )
                      .timeout(timeout);

                  if (piResponse.statusCode != 200) break;

                  final piData =
                      json.decode(utf8.decode(piResponse.bodyBytes))
                          as Map<String, dynamic>;
                  final piItems = piData['items'] as List<dynamic>?;
                  if (piItems == null || piItems.isEmpty) break;

                  for (final item in piItems) {
                    final itemSnippet =
                        item['snippet'] as Map<String, dynamic>?;
                    final vId =
                        itemSnippet?['resourceId']?['videoId']?.toString() ??
                        item['contentDetails']?['videoId']?.toString();
                    final rawTrackTitle =
                        itemSnippet?['title']?.toString() ?? '';
                    if (vId == null || vId.isEmpty || rawTrackTitle.isEmpty)
                      continue;

                    // Skip private, deleted or unavailable videos
                    final cleanTrackTitle = rawTrackTitle.trim();
                    if (cleanTrackTitle == 'Private video' ||
                        cleanTrackTitle == 'Deleted video' ||
                        cleanTrackTitle.startsWith('[Private') ||
                        cleanTrackTitle.startsWith('[Deleted')) {
                      continue;
                    }

                    // Avoid duplicate video entries in trackList
                    if (channelTracks.any((t) => t.sourceId == vId)) continue;

                    final normalizedTitle = YouTubeNormalizer.normalizeTitle(
                      cleanTrackTitle,
                    );
                    final piThumbs =
                        itemSnippet?['thumbnails'] as Map<String, dynamic>? ??
                        {};
                    final thumbUrl =
                        (piThumbs['high'] ??
                                piThumbs['medium'] ??
                                piThumbs['default'])?['url']
                            ?.toString() ??
                        'https://i.ytimg.com/vi/$vId/hqdefault.jpg';

                    channelTracks.add(
                      MusicMetadataResult(
                        provider: 'youtube',
                        sourceId: vId,
                        sourceUrl: 'https://music.youtube.com/watch?v=$vId',
                        title: normalizedTitle,
                        artist: title,
                        artists: [title],
                        artistList: [
                          ArtistMetadataInfo(
                            name: title,
                            id: chId,
                            provider: 'youtube',
                          ),
                        ],
                        album: 'Unggahan Publik',
                        trackArtworkUrl: thumbUrl,
                        artworkUrl: thumbUrl,
                        type: SpotifyEntityType.track,
                      ),
                    );
                    fetchedCount++;
                  }

                  pageToken = piData['nextPageToken']?.toString();
                  if (pageToken == null || pageToken.isEmpty) break;
                }
              } catch (e) {
                debugPrint(
                  '[YouTubeMetadataProvider] Failed to fetch channel uploads: $e',
                );
              }
            }

            return MusicMetadataResult(
              provider: 'youtube',
              sourceId: chId,
              sourceUrl: rawUrl,
              title: title,
              artist: title,
              artists: [title],
              artistList: [
                ArtistMetadataInfo(
                  name: title,
                  id: chId,
                  provider: 'youtube',
                  artworkUrl: avatarUrl,
                ),
              ],
              artistArtworkUrl: avatarUrl,
              artworkUrl: avatarUrl,
              type: SpotifyEntityType.artist,
              trackList: channelTracks,
            );
          }
        }
      } catch (e) {
        debugPrint(
          '[YouTubeMetadataProvider] YouTube Data API channel error: $e',
        );
      }
    }

    // 2. Fallback: Query channel profile via InnerTube web or channel web page
    try {
      final String targetPath = handle != null && handle.isNotEmpty
          ? (handle.startsWith('@') ? handle : '@$handle')
          : (channelId != null ? 'channel/$channelId' : '');

      if (targetPath.isNotEmpty) {
        final pageUrl = Uri.parse('https://www.youtube.com/$targetPath');
        final response = await _client
            .get(
              pageUrl,
              headers: {
                'User-Agent': YouTubeScraper.userAgent,
                'Accept-Language': 'en-US,en;q=0.9',
              },
            )
            .timeout(timeout);

        if (response.statusCode == 200) {
          final html = response.body;

          // Extract title (og:title or title tag)
          String? extractedTitle;
          final ogTitleMatch =
              RegExp(
                r'<meta\s+property="og:title"\s+content="([^"]+)"',
                caseSensitive: false,
              ).firstMatch(html) ??
              RegExp(
                r'<meta\s+content="([^"]+)"\s+property="og:title"',
                caseSensitive: false,
              ).firstMatch(html);
          if (ogTitleMatch != null) {
            extractedTitle = ogTitleMatch
                .group(1)
                ?.replaceAll(
                  RegExp(r'\s*-\s*YouTube(?:\s*Music)?$', caseSensitive: false),
                  '',
                )
                .trim();
          } else {
            final titleTagMatch = RegExp(
              r'<title>([^<]+)</title>',
              caseSensitive: false,
            ).firstMatch(html);
            if (titleTagMatch != null) {
              extractedTitle = titleTagMatch
                  .group(1)
                  ?.replaceAll(
                    RegExp(
                      r'\s*-\s*YouTube(?:\s*Music)?$',
                      caseSensitive: false,
                    ),
                    '',
                  )
                  .trim();
            }
          }

          // Extract avatar/profile image (og:image)
          String? extractedAvatar;
          final ogImageMatch =
              RegExp(
                r'<meta\s+property="og:image"\s+content="([^"]+)"',
                caseSensitive: false,
              ).firstMatch(html) ??
              RegExp(
                r'<meta\s+content="([^"]+)"\s+property="og:image"',
                caseSensitive: false,
              ).firstMatch(html);
          if (ogImageMatch != null) {
            extractedAvatar = ogImageMatch.group(1);
          }

          final finalTitle =
              (extractedTitle != null && extractedTitle.isNotEmpty)
              ? extractedTitle
              : (handle ?? channelId ?? 'YouTube Artist');

          // Fetch available songs for the artist using YouTubeScraper if no API key is provided
          List<MusicMetadataResult> fallbackTracks = [];
          try {
            final videos = await _scraper.searchMusic(finalTitle);
            if (videos.isNotEmpty) {
              for (final v in videos.take(20)) {
                fallbackTracks.add(
                  MusicMetadataResult(
                    provider: 'youtube',
                    sourceId: v.videoId,
                    sourceUrl: 'https://music.youtube.com/watch?v=${v.videoId}',
                    title: v.title,
                    artist: v.channelName ?? finalTitle,
                    artists: [v.channelName ?? finalTitle],
                    artistList: [
                      ArtistMetadataInfo(
                        name: finalTitle,
                        id: channelId ?? handle,
                        provider: 'youtube',
                      ),
                    ],
                    album: v.albumName ?? 'Single / Unggahan',
                    duration: v.durationSeconds > 0 ? v.durationSeconds : null,
                    trackArtworkUrl: v.thumbnailUrl,
                    artworkUrl: v.thumbnailUrl,
                    type: SpotifyEntityType.track,
                  ),
                );
              }
            }
          } catch (e) {
            debugPrint(
              '[YouTubeMetadataProvider] Fallback artist songs fetch error: $e',
            );
          }

          return MusicMetadataResult(
            provider: 'youtube',
            sourceId: channelId ?? handle ?? 'channel',
            sourceUrl: rawUrl,
            title: finalTitle,
            artist: finalTitle,
            artists: [finalTitle],
            artistList: [
              ArtistMetadataInfo(
                name: finalTitle,
                id: channelId ?? handle,
                provider: 'youtube',
                artworkUrl: extractedAvatar,
              ),
            ],
            artistArtworkUrl: extractedAvatar,
            artworkUrl: extractedAvatar,
            type: SpotifyEntityType.artist,
            trackList: fallbackTracks,
          );
        }
      }
    } catch (e) {
      debugPrint('[YouTubeMetadataProvider] Web channel fallback error: $e');
    }

    // 3. Fallback: Parse from handle if present without network crash
    if (handle != null && handle.isNotEmpty) {
      final cleanName = handle.replaceFirst('@', '').trim();
      return MusicMetadataResult(
        provider: 'youtube',
        sourceId: handle,
        sourceUrl: rawUrl,
        title: cleanName,
        artist: cleanName,
        artists: [cleanName],
        artistList: [
          ArtistMetadataInfo(name: cleanName, id: handle, provider: 'youtube'),
        ],
        type: SpotifyEntityType.artist,
        trackList: const [],
      );
    }

    return null;
  }
}
