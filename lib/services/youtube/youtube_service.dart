import 'package:flutter/foundation.dart';
import '../../models/youtube_model.dart';
import '../../models/song_model.dart';
import '../../repositories/local_music_repository.dart';
import 'youtube_scraper.dart';
import 'youtube_repository.dart';
import 'youtube_parser.dart';
import 'youtube_normalizer.dart';
import 'youtube_cache_service.dart';
import 'youtube_resolver.dart';
import 'android_youtube_resolver.dart';

class YouTubeService {
  static final YouTubeService instance = YouTubeService._internal();

  final YouTubeScraper _scraper;
  final YouTubeRepository _repository;
  final YouTubeCacheService _cacheService;
  final YouTubeResolver _resolver;

  YouTubeService({
    YouTubeScraper? scraper,
    YouTubeRepository? repository,
    YouTubeCacheService? cacheService,
    YouTubeResolver? resolver,
  }) : _scraper = scraper ?? YouTubeScraper(),
       _repository = repository ?? YouTubeRepository(),
       _cacheService = cacheService ?? YouTubeCacheService.instance,
       _resolver = resolver ?? YouTubeResolver.instance;

  YouTubeService._internal()
    : _scraper = YouTubeScraper(),
      _repository = YouTubeRepository(),
      _cacheService = YouTubeCacheService.instance,
      _resolver = YouTubeResolver.instance;

  /// Public Search / Link Resolver with Cache-First strategy and TTL check
  Future<List<YouTubeVideo>> search(
    String query, {
    bool forceRefresh = false,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final linkInfo = YouTubeParser.parseLinkOrQuery(cleanQuery);

    // If input is a direct video URL or Video ID
    if (linkInfo.type == YouTubeLinkType.video && linkInfo.videoId != null) {
      final video = await getMetadata(linkInfo.videoId!);
      if (video != null) {
        return [video];
      }
      return [
        YouTubeVideo(
          videoId: linkInfo.videoId!,
          title: 'YouTube Track ${linkInfo.videoId}',
          thumbnailUrl: YouTubeNormalizer.formatThumbnailUrl(
            null,
            linkInfo.videoId!,
          ),
        ),
      ];
    }

    if (!forceRefresh) {
      try {
        final cached = await _repository.getCachedSearch(
          cleanQuery,
          allowStale: false,
        );
        if (cached != null && cached.isNotEmpty) {
          return cached;
        }
      } catch (_) {}
    }

    // Fetch from YouTube Music scraper
    final fresh = await _scraper.searchMusic(cleanQuery);
    if (fresh.isNotEmpty) {
      try {
        await _repository.saveSearchCache(cleanQuery, fresh);
        for (final v in fresh) {
          _cacheService.cacheVideoData(v);
        }
      } catch (_) {}
      return fresh;
    }

    // Stale fallback
    try {
      final stale = await _repository.getCachedSearch(
        cleanQuery,
        allowStale: true,
      );
      return stale ?? [];
    } catch (_) {
      return [];
    }
  }

  /// Parses input string URL/ID to extract playlist ID
  String? parsePlaylistUrl(String url) {
    return YouTubeParser.extractPlaylistId(url);
  }

  /// Parses input string URL/ID to extract video ID
  String? parseVideoUrl(String url) {
    return YouTubeParser.extractVideoId(url);
  }

  /// Fetches & saves YouTube public playlist by URL or ID via scraper (and yt-dlp on Desktop)
  /// and automatically creates a MyMusic Local Playlist.
  Future<YouTubePlaylist?> importPlaylistUrl(String urlOrId) async {
    final cleanInput = urlOrId.trim();
    final linkInfo = YouTubeParser.parseLinkOrQuery(cleanInput);

    // Validate domain if URL is provided
    if (cleanInput.startsWith('http://') || cleanInput.startsWith('https://')) {
      final uri = Uri.tryParse(cleanInput);
      if (uri == null ||
          !YouTubeParser.allowedHosts.contains(uri.host.toLowerCase())) {
        debugPrint(
          '[PlaylistImport] inputUrl=$cleanInput failureReason=INVALID_DOMAIN',
        );
        return null;
      }
    }

    final playlistId =
        parsePlaylistUrl(cleanInput) ??
        (linkInfo.type == YouTubeLinkType.playlist
            ? linkInfo.playlistId
            : null);
    if (playlistId == null || playlistId.isEmpty) {
      debugPrint(
        '[PlaylistImport] inputUrl=$cleanInput failureReason=INVALID_URL',
      );
      return null;
    }

    debugPrint(
      '[PlaylistImport] inputUrl=$cleanInput playlistId=$playlistId fetchStart',
    );

    YouTubePlaylist? playlist;

    // On Desktop (Windows), try yt-dlp first. On Android, bypass yt-dlp completely.
    if (kIsWeb ||
        (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows)) {
      playlist = await _resolver.fetchPlaylistViaYtDlp(playlistId);
    }

    // Fallback or primary InnerTube/HTML scraper for Android & Desktop
    if (playlist == null || playlist.items.isEmpty) {
      debugPrint(
        '[PlaylistImport] Fetching playlist via InnerTube/Scraper for playlistId: $playlistId',
      );
      playlist = await _scraper.fetchPlaylist(playlistId);
    }

    if (playlist != null && playlist.items.isNotEmpty) {
      debugPrint(
        '[PlaylistImport] fetchSuccess playlistId=$playlistId itemCount=${playlist.itemCount} validItems=${playlist.items.length}',
      );
      // Save to YouTube cache repository
      await _repository.savePlaylist(playlist);

      // Create corresponding MyMusic Local Playlist
      try {
        final localRepo = LocalMusicRepository();
        final songIds = <int>[];
        for (final item in playlist.items) {
          final video = YouTubeVideo(
            videoId: item.videoId,
            title: item.title,
            channelName: item.channelName,
            thumbnailUrl: item.thumbnailUrl,
            durationSeconds: item.durationSeconds,
          );
          final song = SongModel.fromYouTubeVideo(video);
          final insertedId = await localRepo.insertOrUpdateSong(song);
          songIds.add(insertedId);
        }

        final myMusicPlaylistId = await localRepo.createPlaylist(
          playlist.title,
          description: 'Diimpor dari YouTube Playlist (${playlist.playlistId})',
        );

        await localRepo.addSongsToPlaylist(myMusicPlaylistId, songIds);
        debugPrint(
          '[YouTubeService] Created MyMusic playlist id $myMusicPlaylistId with ${songIds.length} tracks.',
        );
      } catch (e) {
        debugPrint(
          '[YouTubeService] Error creating MyMusic local playlist from YouTube import: $e',
        );
      }

      return playlist;
    }

    // Offline stale fallback
    return await _repository.getPlaylist(playlistId, allowStale: true);
  }

  /// Resolves single video metadata (checks local filesystem cache first)
  Future<YouTubeVideo?> getMetadata(String videoId) async {
    final cleanId = videoId.trim();
    if (cleanId.isEmpty) return null;

    // 1. Local filesystem cache
    try {
      final fsCached = await _cacheService.getCachedVideo(cleanId);
      if (fsCached != null) return fsCached;
    } catch (_) {}

    // 2. Database repository cache
    try {
      final dbCached = await _repository.getVideo(cleanId);
      if (dbCached != null) {
        try {
          await _cacheService.cacheVideoData(dbCached);
        } catch (_) {}
        return dbCached;
      }
    } catch (_) {}

    // 3. On Windows, try yt-dlp first for 100% accurate title & duration extraction
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      final ytDlpVideo = await _resolver.fetchVideoMetadataViaYtDlp(cleanId);
      if (ytDlpVideo != null) {
        try {
          await _repository.saveVideo(ytDlpVideo);
          await _cacheService.cacheVideoData(ytDlpVideo);
        } catch (_) {}
        return ytDlpVideo;
      }
    }

    // 4. Scraper fresh fetch (Android and Desktop fallback)
    final fresh = await _scraper.fetchVideo(cleanId);
    if (fresh != null) {
      try {
        await _repository.saveVideo(fresh);
        await _cacheService.cacheVideoData(fresh);
      } catch (_) {}
      return fresh;
    }
    return null;
  }

  /// Resolves single video metadata (alias for backward compatibility)
  Future<YouTubeVideo?> resolveVideo(String videoId) async {
    return getMetadata(videoId);
  }

  /// Gets artwork (local cached artwork file path or thumbnail URL)
  Future<String?> getArtwork(String videoId) async {
    final cachedFile = await _cacheService.getCachedArtworkPath(videoId);
    if (cachedFile != null) return cachedFile;

    final video = await getMetadata(videoId);
    return video?.thumbnailUrl;
  }

  /// Resolves direct temporary audio stream URL using yt-dlp on Windows
  Future<String> resolveWindowsAudioStreamUrl(dynamic input) async {
    String videoIdOrUrl = '';
    if (input is SongModel) {
      videoIdOrUrl = input.audioPath;
    } else if (input is YouTubeVideo) {
      videoIdOrUrl = input.videoId;
    } else if (input != null) {
      videoIdOrUrl = input.toString();
    }

    return await _resolver.resolveAudioStreamUrl(videoIdOrUrl);
  }

  /// Resolves direct temporary audio stream details using Android resolver
  Future<AndroidAudioStreamResult> resolveAndroidAudioStreamDetails(
    dynamic input,
  ) async {
    String videoIdOrUrl = '';
    if (input is SongModel) {
      videoIdOrUrl = input.audioPath;
    } else if (input is YouTubeVideo) {
      videoIdOrUrl = input.videoId;
    } else if (input != null) {
      videoIdOrUrl = input.toString();
    }

    return await AndroidYouTubeResolver.instance.resolveAudioStreamDetails(
      videoIdOrUrl,
    );
  }

  /// Resolves direct temporary audio stream details based on current platform
  Future<AndroidAudioStreamResult> resolveAudioStreamDetails(
    dynamic input,
  ) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      final url = await resolveWindowsAudioStreamUrl(input);
      return AndroidAudioStreamResult(
        url: url,
        mimeType: 'audio/mp4',
        bitrate: 128000,
        contentLength: 0,
        headers: {},
      );
    }
    return await resolveAndroidAudioStreamDetails(input);
  }

  /// Resolves direct temporary audio stream URL based on current platform
  Future<String> resolveAudioStreamUrl(dynamic input) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      return await resolveWindowsAudioStreamUrl(input);
    }
    final details = await resolveAndroidAudioStreamDetails(input);
    return details.url;
  }

  /// Matches YouTube video against local library songs
  SongModel? matchLocalSong(YouTubeVideo video, List<SongModel> localSongs) {
    if (localSongs.isEmpty) return null;

    final targetTitle = video.title.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    final targetChannel = (video.channelName ?? '').toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );

    // 1. Exact title + artist match
    for (final s in localSongs) {
      final sTitle = s.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      final sArtist = (s.artistName ?? '').toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]'),
        '',
      );
      if (sTitle == targetTitle && sArtist == targetChannel) {
        return s;
      }
    }

    // 2. Title match
    for (final s in localSongs) {
      final sTitle = s.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (sTitle.isNotEmpty &&
          (sTitle == targetTitle || targetTitle.contains(sTitle))) {
        return s;
      }
    }

    return null;
  }

  Future<List<YouTubePlaylist>> getSavedPlaylists() async {
    return await _repository.getAllPlaylists();
  }

  Future<void> deletePlaylist(String playlistId) async {
    await _repository.deletePlaylist(playlistId);
  }

  Future<void> clearCache() async {
    await _repository.clearAllCache();
    await _cacheService.clearAllCache();
  }
}
