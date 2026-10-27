import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song_model.dart';
import '../repositories/local_music_repository.dart';
import '../services/download_service.dart';
import '../services/metadata/metadata_model.dart';
import '../services/metadata/spotify_discovery_service.dart';
import '../services/metadata/spotify_resolver_service.dart';
import 'catalog_provider.dart';
import 'player_provider.dart';

class SpotifyProvider extends ChangeNotifier {
  final SpotifyDiscoveryService _discoveryService;
  final SpotifyResolverService _resolverService;
  final LocalMusicRepository _localRepo;

  SpotifyProvider({
    SpotifyDiscoveryService? discoveryService,
    SpotifyResolverService? resolverService,
    LocalMusicRepository? localRepo,
  }) : _discoveryService = discoveryService ?? SpotifyDiscoveryService.instance,
       _resolverService = resolverService ?? SpotifyResolverService.instance,
       _localRepo = localRepo ?? LocalMusicRepository();

  // Search / Discovery state
  String _searchQuery = '';
  bool _isSearching = false;
  String? _searchError;
  SpotifyDiscoveryResult? _discoveryResult;
  Timer? _debounceTimer;

  String get searchQuery => _searchQuery;
  bool get isSearching => _isSearching;
  String? get searchError => _searchError;
  SpotifyDiscoveryResult? get discoveryResult => _discoveryResult;
  List<MusicMetadataResult> get tracks => _discoveryResult?.tracks ?? [];
  List<MusicMetadataResult> get albums => _discoveryResult?.albums ?? [];
  List<MusicMetadataResult> get playlists => _discoveryResult?.playlists ?? [];
  List<MusicMetadataResult> get artists => _discoveryResult?.artists ?? [];
  MusicMetadataResult? get currentEntity => _discoveryResult?.entity;

  // Resolving status
  bool _isResolving = false;
  String? _resolvingProgress;
  final Set<String> _resolvingTrackKeys = {};

  bool get isResolving => _isResolving;
  String? get resolvingProgress => _resolvingProgress;
  bool isTrackResolving(MusicMetadataResult t) =>
      _resolvingTrackKeys.contains(_getTrackKey(t));

  String _getTrackKey(MusicMetadataResult t) =>
      t.spotifyId ??
      '${t.title.toLowerCase()}|${t.displayArtist.toLowerCase()}';

  void searchWithDebounce(
    String query, {
    Duration delay = const Duration(milliseconds: 500),
  }) {
    _debounceTimer?.cancel();
    final clean = query.trim();
    if (clean.isEmpty) {
      _searchQuery = '';
      _isSearching = false;
      _searchError = null;
      _discoveryResult = null;
      notifyListeners();
      return;
    }

    _debounceTimer = Timer(delay, () {
      executeSearch(clean);
    });
  }

  int _searchGeneration = 0;

  Future<void> executeSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;

    final gen = ++_searchGeneration;
    _searchQuery = clean;
    _isSearching = true;
    _searchError = null;
    notifyListeners();

    try {
      final res = await _discoveryService.searchOrResolve(clean);
      if (gen != _searchGeneration) return;

      _discoveryResult = res;
      _searchError = res.errorMessage;
    } catch (e) {
      if (gen != _searchGeneration) return;
      _searchError = 'Gagal memuat hasil Spotify: $e';
    } finally {
      if (gen == _searchGeneration) {
        _isSearching = false;
        notifyListeners();
      }
    }
  }

  /// Loads full tracklist for an album or playlist entity and displays it.
  Future<void> selectEntity(MusicMetadataResult entity) async {
    _isSearching = true;
    notifyListeners();

    try {
      final tracks = await _discoveryService.loadEntityTracks(entity);
      _discoveryResult = SpotifyDiscoveryResult(
        isDirectUrl: false,
        entity: entity,
        tracks: tracks,
      );
    } catch (e) {
      _searchError = 'Gagal memuat daftar lagu: $e';
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  /// Resolves a single Spotify track into a playable YouTube [SongModel].
  Future<SongModel?> resolveTrack(MusicMetadataResult track) async {
    final key = _getTrackKey(track);
    _resolvingTrackKeys.add(key);
    notifyListeners();

    try {
      final song = await _resolverService.resolveTrack(track);
      return song;
    } finally {
      _resolvingTrackKeys.remove(key);
      notifyListeners();
    }
  }

  int _playbackSessionId = 0;

  /// Plays a single Spotify track by resolving it to a YouTube stream.
  Future<void> playTrack(
    BuildContext context,
    MusicMetadataResult track,
  ) async {
    final sessionId = ++_playbackSessionId;
    final transitionId =
        'tr_sp_${DateTime.now().millisecondsSinceEpoch}_$sessionId';
    debugPrint(
      '[AudioTransition] Start | $transitionId | spotify | youtube | ${track.title}',
    );
    final song = await resolveTrack(track);
    if (!context.mounted) return;

    if (sessionId != _playbackSessionId) {
      debugPrint(
        '[AudioTransition] Cancelled | $transitionId | Superseded by newer playback request',
      );
      return;
    }

    if (song != null) {
      await Provider.of<PlayerProvider>(
        context,
        listen: false,
      ).playSong(song, context: context);
    } else {
      debugPrint(
        '[AudioTransition] Failed | $transitionId | SpotifyResolutionFailed | No YouTube candidate',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tidak dapat menemukan audio untuk "${track.title}".'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  /// Plays a list of tracks starting from [startIndex], skipping failed tracks gracefully.
  Future<void> playTracks(
    BuildContext context,
    List<MusicMetadataResult> tracksList, {
    int startIndex = 0,
  }) async {
    if (tracksList.isEmpty) return;

    final sessionId = ++_playbackSessionId;
    final transitionId =
        'tr_sp_${DateTime.now().millisecondsSinceEpoch}_$sessionId';
    debugPrint(
      '[AudioTransition] Start | $transitionId | spotify | queue | total=${tracksList.length}',
    );

    _isResolving = true;
    _resolvingProgress = 'Menyiapkan pemutaran...';
    notifyListeners();

    try {
      SongModel? firstSong;
      int foundIndex = -1;

      // Search starting from startIndex
      for (int i = startIndex; i < tracksList.length; i++) {
        if (sessionId != _playbackSessionId) return;
        final candidate = await resolveTrack(tracksList[i]);
        if (candidate != null) {
          firstSong = candidate;
          foundIndex = i;
          break;
        }
      }

      // If not found after startIndex, search before startIndex
      if (firstSong == null) {
        for (int i = 0; i < startIndex; i++) {
          if (sessionId != _playbackSessionId) return;
          final candidate = await resolveTrack(tracksList[i]);
          if (candidate != null) {
            firstSong = candidate;
            foundIndex = i;
            break;
          }
        }
      }

      if (!context.mounted || sessionId != _playbackSessionId) return;

      if (firstSong == null) {
        debugPrint(
          '[AudioTransition] Failed | $transitionId | SpotifyBatchResolutionFailed | No tracks could be resolved',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tidak dapat menemukan audio yang dapat diputar untuk lagu-lagu tersebut.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      final player = Provider.of<PlayerProvider>(context, listen: false);
      // Await playSong so that previous source stop, stream resolution, setAudioSource,
      // and play() complete before queue background mutation or progress reset.
      await player.playSong(firstSong, playlist: [firstSong], context: context);

      if (sessionId != _playbackSessionId) return;

      // Asynchronously resolve remaining tracks in background and append to queue
      final remaining = <MusicMetadataResult>[];
      for (int i = 0; i < tracksList.length; i++) {
        if (i != foundIndex) remaining.add(tracksList[i]);
      }

      if (remaining.isNotEmpty) {
        _resolveAndAppendRemaining(remaining, player, sessionId);
      }
    } finally {
      if (sessionId == _playbackSessionId) {
        _isResolving = false;
        _resolvingProgress = null;
        notifyListeners();
      }
    }
  }

  Future<void> _resolveAndAppendRemaining(
    List<MusicMetadataResult> remaining,
    PlayerProvider player,
    int sessionId,
  ) async {
    try {
      final resolved = await _resolverService.resolveBatch(remaining);
      if (sessionId != _playbackSessionId) return;
      var appended = 0;
      for (final s in resolved) {
        if (sessionId != _playbackSessionId) return;
        player.addToQueue(s);
        appended++;
      }
      debugPrint(
        '[Spotify] Queue append completed: $appended/${remaining.length} tracks (session=$sessionId).',
      );
    } catch (e) {
      // Never lose a background append silently: if this future dies with an
      // error the queue stays at [firstTrack] and auto-next at natural
      // completion hits end-of-queue and pauses instead of advancing.
      debugPrint(
        '[Spotify] Queue append failed (${remaining.length} tracks pending, session=$sessionId): $e',
      );
    }
  }

  /// Adds a single track to the current player queue.
  Future<void> addTrackToQueue(
    BuildContext context,
    MusicMetadataResult track,
  ) async {
    final song = await resolveTrack(track);
    if (!context.mounted) return;

    if (song != null) {
      Provider.of<PlayerProvider>(context, listen: false).addToQueue(song);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${track.title}" ditambahkan ke antrean.'),
          backgroundColor: const Color(0xFF1DB954),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menambahkan "${track.title}" ke antrean.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  /// Batch add multiple tracks to player queue with partial failure reporting.
  Future<void> addTracksToQueue(
    BuildContext context,
    List<MusicMetadataResult> tracksList,
  ) async {
    if (tracksList.isEmpty) return;

    _isResolving = true;
    _resolvingProgress = 'Menyiapkan 0/${tracksList.length} lagu...';
    notifyListeners();

    try {
      final player = Provider.of<PlayerProvider>(context, listen: false);
      final resolvedSongs = await _resolverService.resolveBatch(
        tracksList,
        onProgress: (current, total) {
          _resolvingProgress = 'Menyiapkan $current/$total lagu...';
          notifyListeners();
        },
      );

      for (final song in resolvedSongs) {
        player.addToQueue(song);
      }

      final added = resolvedSongs.length;
      final failed = tracksList.length - added;

      if (context.mounted) {
        final message = failed > 0
            ? '$added lagu ditambahkan ke antrean ($failed lagu tidak ditemukan).'
            : '$added lagu berhasil ditambahkan ke antrean.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: added > 0
                ? const Color(0xFF1DB954)
                : Colors.redAccent,
          ),
        );
      }
    } finally {
      _isResolving = false;
      _resolvingProgress = null;
      notifyListeners();
    }
  }

  /// Adds Spotify tracks to local database / library, and optionally to playlists.
  Future<void> addTracksToLibrary(
    BuildContext context,
    List<MusicMetadataResult> tracksList, {
    String? playlistTitle,
    List<int>? targetPlaylistIds,
  }) async {
    if (tracksList.isEmpty) return;

    _isResolving = true;
    _resolvingProgress = 'Menyimpan 0/${tracksList.length} lagu ke Library...';
    notifyListeners();

    try {
      final resolvedSongs = await _resolverService.resolveBatch(
        tracksList,
        onProgress: (current, total) {
          _resolvingProgress = 'Menyimpan $current/$total lagu ke Library...';
          notifyListeners();
        },
      );

      final List<int> savedSongIds = [];
      for (final song in resolvedSongs) {
        final id = await _localRepo.insertOrUpdateSong(song);
        savedSongIds.add(id > 0 ? id : song.id);
      }

      // If a playlist name was requested, create and add
      if (playlistTitle != null &&
          playlistTitle.trim().isNotEmpty &&
          savedSongIds.isNotEmpty) {
        final playlistId = await _localRepo.createPlaylist(
          playlistTitle.trim(),
        );
        await _localRepo.addSongsToMultiplePlaylists([
          playlistId,
        ], savedSongIds);
      } else if (targetPlaylistIds != null &&
          targetPlaylistIds.isNotEmpty &&
          savedSongIds.isNotEmpty) {
        await _localRepo.addSongsToMultiplePlaylists(
          targetPlaylistIds,
          savedSongIds,
        );
      }

      if (context.mounted) {
        try {
          Provider.of<CatalogProvider>(
            context,
            listen: false,
          ).fetchCatalogData();
        } catch (_) {}

        final savedCount = savedSongIds.length;
        final failedCount = tracksList.length - savedCount;
        final message = failedCount > 0
            ? '$savedCount lagu disimpan ($failedCount gagal/tidak ditemukan).'
            : playlistTitle != null
            ? '$savedCount lagu berhasil disimpan ke playlist "$playlistTitle"!'
            : '$savedCount lagu berhasil ditambahkan ke pustaka lokal!';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: savedCount > 0
                ? const Color(0xFF1DB954)
                : Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan lagu: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      _isResolving = false;
      _resolvingProgress = null;
      notifyListeners();
    }
  }

  /// Enqueues download for a single Spotify track.
  Future<void> downloadTrack(
    BuildContext context,
    MusicMetadataResult track,
  ) async {
    final song = await resolveTrack(track);
    if (!context.mounted) return;

    if (song != null) {
      if (DownloadService.isDownloadableSource(song)) {
        DownloadService.instance.enqueueDownload(song);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '"${track.title}" ditambahkan ke antrean Download Manager.',
            ),
            backgroundColor: const Color(0xFF1DB954),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Lagu siap diputar dari streaming ("${track.title}").',
            ),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyiapkan download untuk "${track.title}".'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  /// Batch download for multiple Spotify tracks with partial failure reporting.
  Future<void> downloadTracks(
    BuildContext context,
    List<MusicMetadataResult> tracksList,
  ) async {
    if (tracksList.isEmpty) return;

    _isResolving = true;
    _resolvingProgress = 'Menyiapkan download 0/${tracksList.length}...';
    notifyListeners();

    try {
      final resolvedSongs = await _resolverService.resolveBatch(
        tracksList,
        onProgress: (current, total) {
          _resolvingProgress = 'Menyiapkan download $current/$total...';
          notifyListeners();
        },
      );

      int enqueued = 0;
      for (final song in resolvedSongs) {
        if (DownloadService.isDownloadableSource(song)) {
          DownloadService.instance.enqueueDownload(song);
          enqueued++;
        }
      }

      final failed = tracksList.length - enqueued;
      if (context.mounted) {
        final message = failed > 0
            ? '$enqueued lagu ditambahkan ke Download Manager ($failed gagal).'
            : '$enqueued lagu ditambahkan ke antrean Download.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: enqueued > 0
                ? const Color(0xFF1DB954)
                : Colors.redAccent,
          ),
        );
      }
    } finally {
      _isResolving = false;
      _resolvingProgress = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
