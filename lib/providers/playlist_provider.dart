import 'package:flutter/material.dart';
import '../models/playlist_model.dart';
import '../models/song_model.dart';
import '../repositories/local_music_repository.dart';

class PlaylistProvider with ChangeNotifier {
  final LocalMusicRepository _repository = LocalMusicRepository();

  List<PlaylistModel> _playlists = [];
  List<SongModel> _favorites = [];
  bool _isLoading = false;

  List<PlaylistModel> get playlists => _playlists;
  List<SongModel> get favorites => _favorites;
  bool get isLoading => _isLoading;

  Future<void> fetchFavorites() async {
    try {
      _favorites = await _repository.getFavorites();
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetch favorites: $e');
    }
  }

  bool isFavorite(int songId) {
    return _favorites.any((s) => s.id == songId);
  }

  Future<void> toggleFavorite(SongModel song) async {
    if (isFavorite(song.id)) {
      _favorites.removeWhere((s) => s.id == song.id);
      notifyListeners();
      await _repository.removeFavorite(song.id);
    } else {
      _favorites.add(song);
      notifyListeners();
      await _repository.addFavorite(song.id);
    }
  }

  Future<void> fetchPlaylists() async {
    _isLoading = true;
    notifyListeners();

    try {
      _playlists = await _repository.getPlaylists();
    } catch (e) {
      debugPrint('Error fetch playlists: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createPlaylist(
    String name,
    String description,
    String visibility,
  ) async {
    try {
      await _repository.createPlaylist(name, description: description);
      await fetchPlaylists();
      return true;
    } catch (e) {
      debugPrint('Error create playlist: $e');
      return false;
    }
  }

  Future<bool> createSmartPlaylist(
    String name,
    String? description,
    dynamic config,
  ) async {
    try {
      await _repository.createSmartPlaylist(
        name: name,
        description: description,
        config: config,
      );
      await fetchPlaylists();
      return true;
    } catch (e) {
      debugPrint('Error create smart playlist: $e');
      return false;
    }
  }

  Future<bool> updateSmartPlaylist(
    int playlistId,
    String name,
    String? description,
    dynamic config,
  ) async {
    try {
      await _repository.updateSmartPlaylist(
        playlistId: playlistId,
        name: name,
        description: description,
        config: config,
      );
      await fetchPlaylists();
      return true;
    } catch (e) {
      debugPrint('Error update smart playlist: $e');
      return false;
    }
  }

  Future<bool> deletePlaylist(int playlistId) async {
    try {
      await _repository.deletePlaylist(playlistId);
      await fetchPlaylists();
      return true;
    } catch (e) {
      debugPrint('Error delete playlist: $e');
      return false;
    }
  }

  Future<bool> addSongToPlaylist(int playlistId, int songId) async {
    try {
      await _repository.addSongToPlaylist(playlistId, songId);
      await fetchPlaylists();
      return true;
    } catch (e) {
      debugPrint('Error add song to playlist: $e');
      return false;
    }
  }

  Future<int> addSongsToPlaylist(int playlistId, List<int> songIds) async {
    try {
      final added = await _repository.addSongsToPlaylist(playlistId, songIds);
      await fetchPlaylists();
      return added;
    } catch (e) {
      debugPrint('Error bulk add songs to playlist: $e');
      return 0;
    }
  }

  Future<Map<int, int>> addSongsToMultiplePlaylists(
    List<int> playlistIds,
    List<int> songIds,
  ) async {
    try {
      final results = await _repository.addSongsToMultiplePlaylists(
        playlistIds,
        songIds,
      );
      await fetchPlaylists();
      return results;
    } catch (e) {
      debugPrint('Error bulk add songs to multiple playlists: $e');
      return {};
    }
  }

  Future<bool> removeSongFromPlaylist(int playlistId, int songId) async {
    try {
      await _repository.removeSongFromPlaylist(playlistId, songId);
      await fetchPlaylists();
      return true;
    } catch (e) {
      debugPrint('Error remove song from playlist: $e');
      return false;
    }
  }

  Future<int> removeSongsFromPlaylist(int playlistId, List<int> songIds) async {
    try {
      final removed = await _repository.removeSongsFromPlaylist(
        playlistId,
        songIds,
      );
      await fetchPlaylists();
      return removed;
    } catch (e) {
      debugPrint('Error bulk remove songs from playlist: $e');
      return 0;
    }
  }
}
