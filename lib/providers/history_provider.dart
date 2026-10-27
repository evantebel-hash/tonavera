import 'package:flutter/foundation.dart';
import '../models/song_model.dart';
import '../repositories/local_music_repository.dart';

class HistoryProvider with ChangeNotifier {
  final LocalMusicRepository _repository = LocalMusicRepository();

  List<SongModel> _recentlyPlayed = [];
  bool _isLoading = false;
  String? _error;

  List<SongModel> get recentlyPlayed => _recentlyPlayed;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchRecentlyPlayed({int limit = 20}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _recentlyPlayed = await _repository.getRecentlyPlayed(limit: limit);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
