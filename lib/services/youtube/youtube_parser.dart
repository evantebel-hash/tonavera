import 'dart:convert';
import '../../models/youtube_model.dart';
import 'youtube_normalizer.dart';

enum YouTubeLinkType { video, playlist, channel, textSearch }

class YouTubeLinkInfo {
  final YouTubeLinkType type;
  final String? videoId;
  final String? playlistId;
  final String? channelHandle; // e.g. @ricchiepoveriofficial or channel name
  final String? channelId; // e.g. UC...
  final String rawQuery;

  YouTubeLinkInfo({
    required this.type,
    this.videoId,
    this.playlistId,
    this.channelHandle,
    this.channelId,
    required this.rawQuery,
  });
}

class YouTubeParser {
  /// Allowed YouTube domain hostnames
  static const Set<String> allowedHosts = {
    'youtube.com',
    'www.youtube.com',
    'm.youtube.com',
    'music.youtube.com',
    'youtu.be',
  };

  /// Parses an input string (query, URL, or video/playlist ID) into structured link info.
  static YouTubeLinkInfo parseLinkOrQuery(String input) {
    final str = input.trim();
    if (str.isEmpty) {
      return YouTubeLinkInfo(type: YouTubeLinkType.textSearch, rawQuery: str);
    }

    final uri = Uri.tryParse(str);
    final bool hasScheme =
        str.startsWith('http://') || str.startsWith('https://');

    if (hasScheme && uri != null) {
      final host = uri.host.toLowerCase();
      // Enforce strict hostname validation
      if (allowedHosts.contains(host)) {
        // 1. Check for watch URL with video ID (e.g. /watch?v=... with optional &list=...)
        if (uri.queryParameters.containsKey('v')) {
          final vId = uri.queryParameters['v']?.trim();
          if (vId != null && _isValidVideoId(vId)) {
            return YouTubeLinkInfo(
              type: YouTubeLinkType.video,
              videoId: vId,
              playlistId: uri.queryParameters['list']?.trim(),
              rawQuery: str,
            );
          }
        }

        // 2. Check for explicit playlist URL (/playlist?list=... or any list parameter without v)
        if (uri.queryParameters.containsKey('list')) {
          final listId = uri.queryParameters['list']?.trim();
          if (listId != null && listId.isNotEmpty) {
            return YouTubeLinkInfo(
              type: YouTubeLinkType.playlist,
              playlistId: listId,
              rawQuery: str,
            );
          }
        }

        // 3. Check for short URL (e.g. youtu.be/VIDEO_ID)
        if (host == 'youtu.be' && uri.pathSegments.isNotEmpty) {
          final vId = uri.pathSegments.first;
          if (_isValidVideoId(vId)) {
            return YouTubeLinkInfo(
              type: YouTubeLinkType.video,
              videoId: vId.trim(),
              rawQuery: str,
            );
          }
        }

        // 4. Check for Artist / Channel profile URL:
        // Examples:
        // - https://music.youtube.com/@ricchiepoveriofficial?si=...
        // - https://www.youtube.com/@handle
        // - https://youtube.com/channel/UCxxxxxx
        // - https://youtube.com/c/customName
        if (uri.pathSegments.isNotEmpty) {
          final firstSegment = uri.pathSegments.first.trim();
          if (firstSegment.startsWith('@') && firstSegment.length > 1) {
            return YouTubeLinkInfo(
              type: YouTubeLinkType.channel,
              channelHandle: firstSegment,
              rawQuery: str,
            );
          } else if (firstSegment.toLowerCase() == 'channel' &&
              uri.pathSegments.length > 1) {
            final cId = uri.pathSegments[1].trim();
            if (cId.isNotEmpty) {
              return YouTubeLinkInfo(
                type: YouTubeLinkType.channel,
                channelId: cId,
                rawQuery: str,
              );
            }
          } else if ((firstSegment.toLowerCase() == 'c' ||
                  firstSegment.toLowerCase() == 'user') &&
              uri.pathSegments.length > 1) {
            final handle = uri.pathSegments[1].trim();
            if (handle.isNotEmpty) {
              return YouTubeLinkInfo(
                type: YouTubeLinkType.channel,
                channelHandle: handle,
                rawQuery: str,
              );
            }
          } else if (firstSegment.toLowerCase() == 'browse' &&
              uri.pathSegments.length > 1) {
            final bId = uri.pathSegments[1].trim();
            if (bId.startsWith('UC') ||
                bId.startsWith(
                  'FEmusic_library_privately_owned_artist_detail',
                )) {
              return YouTubeLinkInfo(
                type: YouTubeLinkType.channel,
                channelId: bId,
                rawQuery: str,
              );
            }
          }
        }
      } else {
        // Domain is invalid / unrecognized HTTP URL
        return YouTubeLinkInfo(type: YouTubeLinkType.textSearch, rawQuery: str);
      }
    }

    // Direct @handle check (e.g. @ricchiepoveriofficial)
    if (str.startsWith('@') &&
        str.length > 1 &&
        !str.contains('/') &&
        !str.contains(' ')) {
      return YouTubeLinkInfo(
        type: YouTubeLinkType.channel,
        channelHandle: str,
        rawQuery: str,
      );
    }

    // Direct Playlist ID check (e.g., PL... or OLAK5uy_...)
    final directPlaylistReg = RegExp(
      r'^(PL|OLAK5uy_|RDMM|FL|UU|LL)[a-zA-Z0-9_-]+$',
    );
    if (directPlaylistReg.hasMatch(str)) {
      return YouTubeLinkInfo(
        type: YouTubeLinkType.playlist,
        playlistId: str,
        rawQuery: str,
      );
    }

    // Direct Video ID check (11 characters alphanum/dash/underscore)
    if (_isValidVideoId(str)) {
      return YouTubeLinkInfo(
        type: YouTubeLinkType.video,
        videoId: str,
        rawQuery: str,
      );
    }

    return YouTubeLinkInfo(type: YouTubeLinkType.textSearch, rawQuery: str);
  }

  static bool _isValidVideoId(String input) {
    final str = input.trim();
    if (str.length != 11) return false;
    final directReg = RegExp(r'^[a-zA-Z0-9_-]{11}$');
    return directReg.hasMatch(str) &&
        !str.contains('/') &&
        !str.startsWith('http');
  }

  /// Extracts YouTube Playlist ID from a URL or raw ID
  static String? extractPlaylistId(String input) {
    final info = parseLinkOrQuery(input);
    if (info.type == YouTubeLinkType.playlist) return info.playlistId;

    final str = input.trim();
    if (str.isEmpty) return null;

    final directReg = RegExp(r'^(PL|OLAK5uy_|RDMM|FL|UU|LL)[a-zA-Z0-9_-]+$');
    if (directReg.hasMatch(str)) return str;

    final uri = Uri.tryParse(str);
    if (uri != null &&
        (str.startsWith('http://') || str.startsWith('https://'))) {
      final host = uri.host.toLowerCase();
      if (!allowedHosts.contains(host)) return null;
      if (uri.queryParameters.containsKey('list')) {
        final listId = uri.queryParameters['list']?.trim();
        if (listId != null && listId.isNotEmpty) return listId;
      }
    }

    return null;
  }

  /// Extracts YouTube Video ID from a URL or raw ID
  static String? extractVideoId(String input) {
    final info = parseLinkOrQuery(input);
    if (info.type == YouTubeLinkType.video) return info.videoId;
    return null;
  }

  /// Parses YouTube Music search JSON response from InnerTube WEB_REMIX endpoint
  static List<YouTubeVideo> parseYouTubeMusicSearchJson(
    Map<String, dynamic> jsonResponse,
  ) {
    final results = <YouTubeVideo>[];
    try {
      final sectionList =
          jsonResponse['contents']?['tabbedSearchResultsRenderer']?['tabs']?[0]?['tabRenderer']?['content']?['sectionListRenderer']?['contents']
              as List<dynamic>?;

      if (sectionList == null) return results;

      for (final section in sectionList) {
        final musicCard = section['musicCardShelfRenderer'];
        if (musicCard != null) {
          final title = musicCard['title']?['runs']?[0]?['text'] ?? 'Untitled';
          final subtitleRuns = musicCard['subtitle']?['runs'] as List<dynamic>?;

          final onTap = musicCard['onTap'];
          final vId =
              onTap?['watchEndpoint']?['videoId'] ??
              musicCard['buttons']?[0]?['buttonRenderer']?['command']?['watchEndpoint']?['videoId'];

          String? artistName;
          String? albumName;
          if (subtitleRuns != null && subtitleRuns.isNotEmpty) {
            artistName = subtitleRuns[0]['text']?.toString();
            if (subtitleRuns.length >= 3) {
              albumName = subtitleRuns[2]['text']?.toString();
            }
          }

          final thumbs =
              musicCard['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails']
                  as List<dynamic>?;
          final thumbUrl = thumbs != null && thumbs.isNotEmpty
              ? thumbs.last['url']?.toString()
              : null;

          if (vId != null && vId.toString().isNotEmpty) {
            results.add(
              YouTubeVideo(
                videoId: vId.toString(),
                title: YouTubeNormalizer.normalizeTitle(title.toString()),
                channelName: artistName,
                albumName: albumName,
                thumbnailUrl: YouTubeNormalizer.formatThumbnailUrl(
                  thumbUrl,
                  vId.toString(),
                ),
              ),
            );
          }
        }

        final shelfItems =
            section['musicShelfRenderer']?['contents'] as List<dynamic>?;
        if (shelfItems != null) {
          for (final item in shelfItems) {
            final flexItem = item['musicResponsiveListItemRenderer'];
            if (flexItem == null) continue;

            final flexColumns = flexItem['flexColumns'] as List<dynamic>?;
            if (flexColumns == null || flexColumns.isEmpty) continue;

            final titleRuns =
                flexColumns[0]?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs']
                    as List<dynamic>?;
            final title = titleRuns != null && titleRuns.isNotEmpty
                ? titleRuns[0]['text']?.toString()
                : null;

            final playlistItemData = flexItem['playlistItemData'];
            String? vId = playlistItemData?['videoId']?.toString();

            if (vId == null || vId.isEmpty) {
              final menuItems =
                  flexItem['menu']?['menuRenderer']?['items'] as List<dynamic>?;
              if (menuItems != null) {
                for (final mi in menuItems) {
                  final serviceEndpoint =
                      mi['menuNavigationItemRenderer']?['navigationEndpoint'] ??
                      mi['menuServiceItemRenderer']?['serviceEndpoint'];
                  final candidateVid =
                      serviceEndpoint?['queueAddEndpoint']?['queueTarget']?['videoId'] ??
                      serviceEndpoint?['watchEndpoint']?['videoId'];
                  if (candidateVid != null &&
                      candidateVid.toString().isNotEmpty) {
                    vId = candidateVid.toString();
                    break;
                  }
                }
              }
            }

            if (vId == null || vId.isEmpty) {
              final overlay =
                  flexItem['overlay']?['musicItemThumbnailOverlayRenderer']?['content']?['musicPlayButtonRenderer'];
              vId =
                  overlay?['playNavigationEndpoint']?['watchEndpoint']?['videoId']
                      ?.toString();
            }

            if (vId == null || vId.isEmpty || title == null) continue;

            String? artistName;
            String? albumName;
            int durationSec = 0;

            if (flexColumns.length > 1) {
              final subRuns =
                  flexColumns[1]?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs']
                      as List<dynamic>?;
              if (subRuns != null) {
                final textSegments = subRuns
                    .map((r) => r['text']?.toString() ?? '')
                    .where((t) => t.trim() != '•' && t.trim() != '• ')
                    .toList();
                if (textSegments.isNotEmpty) artistName = textSegments[0];
                if (textSegments.length >= 2) albumName = textSegments[1];
                if (textSegments.length >= 3) {
                  durationSec = YouTubeNormalizer.parseDurationToSeconds(
                    textSegments.last,
                  );
                }
              }
            }

            final fixedDurationText =
                flexItem['fixedColumns']?[0]?['musicResponsiveListItemFixedColumnRenderer']?['text']?['runs']?[0]?['text']
                    ?.toString();
            if (fixedDurationText != null && durationSec == 0) {
              durationSec = YouTubeNormalizer.parseDurationToSeconds(
                fixedDurationText,
              );
            }

            final thumbs =
                flexItem['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails']
                    as List<dynamic>?;
            final thumbUrl = thumbs != null && thumbs.isNotEmpty
                ? thumbs.last['url']?.toString()
                : null;

            if (!results.any((r) => r.videoId == vId)) {
              results.add(
                YouTubeVideo(
                  videoId: vId,
                  title: YouTubeNormalizer.normalizeTitle(title),
                  channelName: artistName,
                  albumName: albumName,
                  thumbnailUrl: YouTubeNormalizer.formatThumbnailUrl(
                    thumbUrl,
                    vId,
                  ),
                  durationSeconds: durationSec,
                ),
              );
            }
          }
        }
      }
    } catch (_) {}
    return results;
  }

  /// Parses YouTube search HTML page containing embedded `ytInitialData` JSON
  static List<YouTubeVideo> parseSearchResultsHtml(String html) {
    final results = <YouTubeVideo>[];

    try {
      // Locate ytInitialData json block
      final jsonStr = _extractYtInitialData(html);
      if (jsonStr != null) {
        final decoded = json.decode(jsonStr);
        _extractVideosFromInitialData(decoded, results);
      }
    } catch (_) {}

    // Fallback regex parsing if initial data is partial
    if (results.isEmpty) {
      _fallbackRegexVideoParse(html, results);
    }

    return results;
  }

  /// Parses InnerTube browse endpoint response for YouTube / YouTube Music playlists
  static YouTubePlaylist parseInnerTubePlaylistJson(
    Map<String, dynamic> jsonResponse,
    String playlistId,
  ) {
    String title = 'YouTube Playlist';
    String? channelName;
    String? thumbnailUrl;
    final items = <YouTubePlaylistItem>[];

    try {
      final header =
          jsonResponse['header']?['musicDetailHeaderRenderer'] ??
          jsonResponse['header']?['playlistHeaderRenderer'] ??
          jsonResponse['header']?['musicHeaderRenderer'];

      if (header != null) {
        final tRuns = header['title']?['runs'] as List<dynamic>?;
        if (tRuns != null && tRuns.isNotEmpty) {
          title = tRuns[0]['text']?.toString() ?? title;
        } else if (header['title']?['simpleText'] != null) {
          title = header['title']['simpleText'].toString();
        }

        final cRuns =
            header['subtitle']?['runs'] ??
            header['owner']?['videoOwnerRenderer']?['title']?['runs'];
        if (cRuns is List<dynamic> && cRuns.isNotEmpty) {
          channelName = cRuns[0]['text']?.toString();
        }
      }

      _extractPlaylistItemsFromInitialData(jsonResponse, playlistId, items);
    } catch (_) {}

    thumbnailUrl ??= items.isNotEmpty ? items.first.thumbnailUrl : null;

    return YouTubePlaylist(
      playlistId: playlistId,
      title: title,
      channelName: channelName,
      thumbnailUrl: thumbnailUrl,
      itemCount: items.length,
      items: items,
    );
  }

  /// Parses YouTube playlist HTML page
  static YouTubePlaylist parsePlaylistHtml(String html, String playlistId) {
    String title = 'YouTube Playlist';
    String? channelName;
    String? thumbnailUrl;

    final items = <YouTubePlaylistItem>[];

    try {
      final jsonStr = _extractYtInitialData(html);
      if (jsonStr != null) {
        final decoded = json.decode(jsonStr);
        // Extract title & header
        final header =
            decoded['header']?['playlistHeaderRenderer'] ??
            decoded['sidebar']?['playlistSidebarRenderer']?['items']?[0]?['playlistSidebarPrimaryInfoRenderer'];
        if (header != null) {
          title =
              header['title']?['runs']?[0]?['text'] ??
              header['title']?['simpleText'] ??
              title;
          channelName =
              header['owner']?['videoOwnerRenderer']?['title']?['runs']?[0]?['text'];
        }

        _extractPlaylistItemsFromInitialData(decoded, playlistId, items);
      }
    } catch (_) {}

    thumbnailUrl ??= items.isNotEmpty ? items.first.thumbnailUrl : null;

    return YouTubePlaylist(
      playlistId: playlistId,
      title: title,
      channelName: channelName,
      thumbnailUrl: thumbnailUrl,
      itemCount: items.length,
      items: items,
    );
  }

  static String? _extractYtInitialData(String html) {
    final match =
        RegExp(
          r'var\s+ytInitialData\s*=\s*(\{.+?\});</script>',
          dotAll: true,
        ).firstMatch(html) ??
        RegExp(
          r'var\s+ytInitialData\s*=\s*(\{.+?\});',
          dotAll: true,
        ).firstMatch(html);
    if (match != null) {
      return match.group(1);
    }
    return null;
  }

  static void _extractVideosFromInitialData(
    dynamic jsonNode,
    List<YouTubeVideo> results,
  ) {
    if (jsonNode is Map<String, dynamic>) {
      if (jsonNode.containsKey('videoRenderer')) {
        final vr = jsonNode['videoRenderer'] as Map<String, dynamic>;
        final videoId = vr['videoId']?.toString();
        if (videoId != null && videoId.isNotEmpty) {
          final title =
              vr['title']?['runs']?[0]?['text'] ??
              vr['title']?['simpleText'] ??
              'Untitled Video';
          final channelName =
              vr['ownerText']?['runs']?[0]?['text'] ??
              vr['longBylineText']?['runs']?[0]?['text'] ??
              'YouTube Channel';
          final durationStr =
              vr['lengthText']?['simpleText'] ??
              vr['lengthText']?['runs']?[0]?['text'];
          final durationSec = YouTubeNormalizer.parseDurationToSeconds(
            durationStr,
          );

          final thumbs = vr['thumbnail']?['thumbnails'] as List<dynamic>?;
          final thumbUrl = thumbs != null && thumbs.isNotEmpty
              ? thumbs.last['url']?.toString()
              : null;

          results.add(
            YouTubeVideo(
              videoId: videoId,
              title: YouTubeNormalizer.normalizeTitle(title),
              channelName: channelName,
              thumbnailUrl: YouTubeNormalizer.formatThumbnailUrl(
                thumbUrl,
                videoId,
              ),
              durationSeconds: durationSec,
            ),
          );
        }
      } else {
        for (final value in jsonNode.values) {
          _extractVideosFromInitialData(value, results);
        }
      }
    } else if (jsonNode is List<dynamic>) {
      for (final item in jsonNode) {
        _extractVideosFromInitialData(item, results);
      }
    }
  }

  static void _extractPlaylistItemsFromInitialData(
    dynamic jsonNode,
    String playlistId,
    List<YouTubePlaylistItem> items,
  ) {
    if (jsonNode is Map<String, dynamic>) {
      if (jsonNode.containsKey('playlistVideoRenderer')) {
        final pvr = jsonNode['playlistVideoRenderer'] as Map<String, dynamic>;
        final videoId = pvr['videoId']?.toString();
        if (videoId != null && videoId.isNotEmpty) {
          final title =
              pvr['title']?['runs']?[0]?['text'] ??
              pvr['title']?['simpleText'] ??
              'Track';
          final cleanTitle = title.toString().trim();
          if (cleanTitle != '[Deleted video]' &&
              cleanTitle != '[Private video]' &&
              cleanTitle != '[Unavailable video]' &&
              !cleanTitle.startsWith('[Deleted') &&
              !cleanTitle.startsWith('[Private')) {
            final channelName =
                pvr['shortBylineText']?['runs']?[0]?['text'] ?? 'YouTube';
            final durationStr = pvr['lengthText']?['simpleText'];
            final durationSec = YouTubeNormalizer.parseDurationToSeconds(
              durationStr,
            );

            final thumbs = pvr['thumbnail']?['thumbnails'] as List<dynamic>?;
            final thumbUrl = thumbs != null && thumbs.isNotEmpty
                ? thumbs.last['url']?.toString()
                : null;

            items.add(
              YouTubePlaylistItem(
                playlistId: playlistId,
                videoId: videoId,
                position: items.length,
                title: YouTubeNormalizer.normalizeTitle(title),
                channelName: channelName,
                thumbnailUrl: YouTubeNormalizer.formatThumbnailUrl(
                  thumbUrl,
                  videoId,
                ),
                durationSeconds: durationSec,
              ),
            );
          }
        }
      } else {
        for (final value in jsonNode.values) {
          _extractPlaylistItemsFromInitialData(value, playlistId, items);
        }
      }
    } else if (jsonNode is List<dynamic>) {
      for (final item in jsonNode) {
        _extractPlaylistItemsFromInitialData(item, playlistId, items);
      }
    }
  }

  static void _fallbackRegexVideoParse(
    String html,
    List<YouTubeVideo> results,
  ) {
    final reg = RegExp(
      r'"videoId":"([a-zA-Z0-9_-]{11})".*?"title":\{"runs":\[\{"text":"([^"]+)"\}',
    );
    final matches = reg.allMatches(html);
    for (final match in matches) {
      final vId = match.group(1);
      final title = match.group(2);
      if (vId != null &&
          title != null &&
          !results.any((r) => r.videoId == vId)) {
        results.add(
          YouTubeVideo(
            videoId: vId,
            title: YouTubeNormalizer.normalizeTitle(title),
            thumbnailUrl: YouTubeNormalizer.formatThumbnailUrl(null, vId),
          ),
        );
      }
    }
  }
}
