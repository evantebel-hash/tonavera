import 'package:flutter/material.dart';
import '../models/song_model.dart';
import '../models/artist_model.dart';
import '../models/album_model.dart';
import '../models/genre_model.dart';
import '../repositories/local_music_repository.dart';

class CatalogProvider with ChangeNotifier {
  final LocalMusicRepository _repository = LocalMusicRepository();

  List<SongModel> _songs = [];
  List<ArtistModel> _artists = [];
  List<AlbumModel> _albums = [];
  List<GenreModel> _genres = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<SongModel> get songs => _songs;
  List<ArtistModel> get artists => _artists;
  List<AlbumModel> get albums => _albums;
  List<GenreModel> get genres => _genres;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchCatalogData() async {
    _setLoading(true);
    await Future.wait([
      fetchSongs(),
      fetchArtists(),
      fetchAlbums(),
      fetchGenres(),
    ]);
    _setLoading(false);
  }

  Future<void> fetchSongs({
    String? query,
    int? genreId,
    int? artistId,
    int? albumId,
  }) async {
    try {
      _songs = await _repository.getSongs(
        query: query,
        genreId: genreId,
        artistId: artistId,
        albumId: albumId,
      );
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Gagal memuat lagu dari database lokal: $e';
    }
    notifyListeners();
  }

  Future<void> fetchArtists() async {
    try {
      _artists = await _repository.getArtists();
    } catch (e) {
      debugPrint('Error fetch artists: $e');
    }
    notifyListeners();
  }

  Future<void> fetchAlbums() async {
    try {
      _albums = await _repository.getAlbums();
    } catch (e) {
      debugPrint('Error fetch albums: $e');
    }
    notifyListeners();
  }

  Future<void> fetchGenres() async {
    try {
      _genres = await _repository.getGenres();
    } catch (e) {
      debugPrint('Error fetch genres: $e');
    }
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
