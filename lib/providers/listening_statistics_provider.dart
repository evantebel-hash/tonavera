import 'package:flutter/foundation.dart';
import '../models/listening_history_model.dart';
import '../models/listening_statistics_model.dart';
import '../services/listening_statistics_service.dart';

class ListeningStatisticsProvider with ChangeNotifier {
  final ListeningStatisticsService _service;

  ListeningStatisticsProvider({ListeningStatisticsService? service})
    : _service = service ?? ListeningStatisticsService();

  StatisticsTimeRange _selectedTimeRange = StatisticsTimeRange.allTime;
  StatisticsTimeRange get selectedTimeRange => _selectedTimeRange;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  ListeningStatisticsModel _statistics = ListeningStatisticsModel();
  ListeningStatisticsModel get statistics => _statistics;

  List<TopMusicItemModel> _topSongs = [];
  List<TopMusicItemModel> get topSongs => _topSongs;

  List<TopMusicItemModel> _topArtists = [];
  List<TopMusicItemModel> get topArtists => _topArtists;

  List<TopMusicItemModel> _topAlbums = [];
  List<TopMusicItemModel> get topAlbums => _topAlbums;

  Map<String, DailyListeningActivityModel> _monthlyActivity = {};
  Map<String, DailyListeningActivityModel> get monthlyActivity =>
      _monthlyActivity;

  int _calendarYear = DateTime.now().year;
  int _calendarMonth = DateTime.now().month;
  int get calendarYear => _calendarYear;
  int get calendarMonth => _calendarMonth;

  DateTime? _selectedDate;
  DateTime? get selectedDate => _selectedDate;

  List<ListeningHistoryModel> _selectedDateHistory = [];
  List<ListeningHistoryModel> get selectedDateHistory => _selectedDateHistory;

  List<ListeningHistoryModel> _historyStream = [];
  List<ListeningHistoryModel> get historyStream => _historyStream;

  bool _hasMoreHistory = true;
  bool get hasMoreHistory => _hasMoreHistory;
  bool _isLoadingMoreHistory = false;
  bool get isLoadingMoreHistory => _isLoadingMoreHistory;

  static const int _pageSize = 50;

  Future<void> setTimeRange(StatisticsTimeRange range) async {
    if (_selectedTimeRange == range) return;
    _selectedTimeRange = range;
    notifyListeners();
    await fetchAll();
  }

  Future<void> fetchAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final start = _selectedTimeRange.startDate;
      final end = _selectedTimeRange.endDate;

      final results = await Future.wait([
        _service.getStatistics(startDate: start, endDate: end),
        _service.getTopSongs(startDate: start, endDate: end, limit: 20),
        _service.getTopArtists(startDate: start, endDate: end, limit: 20),
        _service.getTopAlbums(startDate: start, endDate: end, limit: 20),
        _service.getMonthlyActivity(year: _calendarYear, month: _calendarMonth),
        _service.getHistory(limit: _pageSize, offset: 0),
      ]);

      _statistics = results[0] as ListeningStatisticsModel;
      _topSongs = results[1] as List<TopMusicItemModel>;
      _topArtists = results[2] as List<TopMusicItemModel>;
      _topAlbums = results[3] as List<TopMusicItemModel>;
      _monthlyActivity = results[4] as Map<String, DailyListeningActivityModel>;
      _historyStream = results[5] as List<ListeningHistoryModel>;
      _hasMoreHistory = _historyStream.length >= _pageSize;

      if (_selectedDate != null) {
        _selectedDateHistory = await _service.getHistoryForDate(_selectedDate!);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreHistory() async {
    if (_isLoadingMoreHistory || !_hasMoreHistory) return;
    _isLoadingMoreHistory = true;
    notifyListeners();

    try {
      final newRecords = await _service.getHistory(
        limit: _pageSize,
        offset: _historyStream.length,
      );
      if (newRecords.isEmpty) {
        _hasMoreHistory = false;
      } else {
        _historyStream.addAll(newRecords);
        if (newRecords.length < _pageSize) {
          _hasMoreHistory = false;
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoadingMoreHistory = false;
      notifyListeners();
    }
  }

  Future<void> changeCalendarMonth(int year, int month) async {
    _calendarYear = year;
    _calendarMonth = month;
    notifyListeners();

    try {
      _monthlyActivity = await _service.getMonthlyActivity(
        year: _calendarYear,
        month: _calendarMonth,
      );
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> selectCalendarDate(DateTime date) async {
    _selectedDate = date;
    notifyListeners();

    try {
      _selectedDateHistory = await _service.getHistoryForDate(date);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> clearAllHistory() async {
    try {
      await _service.clearHistory();
      _selectedDate = null;
      _selectedDateHistory = [];
      await fetchAll();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}
