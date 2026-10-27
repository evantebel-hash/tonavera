import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/youtube_model.dart';
import '../services/youtube/youtube_service.dart';
import '../services/youtube/youtube_parser.dart';

class YouTubeProvider extends ChangeNotifier {
  final YouTubeService _service;

  YouTubeProvider({YouTubeService? service})
    : _service = service ?? YouTubeService.instance;

  // Search state
  List<YouTubeVideo> _searchResults = [];
  bool _isSearching = false;
  String? _searchError;
  String _lastQuery = '';
  Timer? _debounceTimer;
  YouTubeLinkInfo? _detectedLinkInfo;

  List<YouTubeVideo> get searchResults => _searchResults;
  bool get isSearching => _isSearching;
  String? get searchError => _searchError;
  String get lastQuery => _lastQuery;
  YouTubeLinkInfo? get detectedLinkInfo => _detectedLinkInfo;

  // Saved Online Playlists state
  List<YouTubePlaylist> _savedPlaylists = [];
  bool _isLoadingPlaylists = false;

  List<YouTubePlaylist> get savedPlaylists => _savedPlaylists;
  bool get isLoadingPlaylists => _isLoadingPlaylists;

  /// Performs search with 500ms debounce
  void searchWithDebounce(
    String query, {
    Duration delay = const Duration(milliseconds: 500),
  }) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      _searchResults = [];
      _lastQuery = '';
      _isSearching = false;
      _detectedLinkInfo = null;
      notifyListeners();
      return;
    }

    _debounceTimer = Timer(delay, () {
      executeSearch(query);
    });
  }

  int _searchGeneration = 0;

  Future<void> executeSearch(String query, {bool forceRefresh = false}) async {
    final clean = query.trim();
    if (clean.isEmpty) return;

    final currentGen = ++_searchGeneration;

    _detectedLinkInfo = YouTubeParser.parseLinkOrQuery(clean);
    _isSearching = true;
    _searchError = null;
    _lastQuery = clean;
    notifyListeners();

    try {
      final results = await _service.search(clean, forceRefresh: forceRefresh);

      // Ignore results if a newer search request has been triggered
      if (currentGen != _searchGeneration) return;

      _searchResults = results;
      if (results.isEmpty) {
        if (_detectedLinkInfo?.type == YouTubeLinkType.video) {
          _searchError =
              'Tidak dapat memuat video YouTube ini. Video mungkin tidak tersedia.';
        } else {
          _searchError = 'Tidak ada hasil musik ditemukan untuk "$clean".';
        }
      }
    } catch (e) {
      if (currentGen != _searchGeneration) return;
      _searchError = 'Gagal memuat hasil YouTube Music: $e';
    } finally {
      if (currentGen == _searchGeneration) {
        _isSearching = false;
        notifyListeners();
      }
    }
  }

  Future<void> fetchSavedPlaylists() async {
    _isLoadingPlaylists = true;
    notifyListeners();

    try {
      _savedPlaylists = await _service.getSavedPlaylists();
    } catch (e) {
      debugPrint('YouTubeProvider: fetchSavedPlaylists error: $e');
    } finally {
      _isLoadingPlaylists = false;
      notifyListeners();
    }
  }

  String? _playlistImportError;
  String? get playlistImportError => _playlistImportError;

  Future<YouTubePlaylist?> importPlaylist(String urlOrId) async {
    _playlistImportError = null;
    final cleanInput = urlOrId.trim();

    if (cleanInput.isEmpty) {
      _playlistImportError = 'URL playlist tidak boleh kosong.';
      notifyListeners();
      return null;
    }

    if (cleanInput.startsWith('http://') || cleanInput.startsWith('https://')) {
      final uri = Uri.tryParse(cleanInput);
      if (uri == null ||
          !YouTubeParser.allowedHosts.contains(uri.host.toLowerCase())) {
        _playlistImportError =
            'URL playlist tidak valid atau domain tidak didukung.';
        notifyListeners();
        return null;
      }
    }

    try {
      final playlist = await _service.importPlaylistUrl(cleanInput);
      if (playlist != null && playlist.items.isNotEmpty) {
        await fetchSavedPlaylists();
        _playlistImportError = null;
        return playlist;
      } else {
        _playlistImportError =
            'Playlist tidak ditemukan, bersifat private, atau tidak memiliki lagu.';
      }
    } catch (e) {
      debugPrint('YouTubeProvider: importPlaylist error: $e');
      _playlistImportError =
          'Tidak dapat terhubung ke YouTube. Periksa koneksi internet Anda.';
    }
    notifyListeners();
    return null;
  }

  Future<void> deletePlaylist(String playlistId) async {
    await _service.deletePlaylist(playlistId);
    await fetchSavedPlaylists();
  }

  Future<void> clearCache() async {
    await _service.clearCache();
    _searchResults = [];
    _savedPlaylists = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
