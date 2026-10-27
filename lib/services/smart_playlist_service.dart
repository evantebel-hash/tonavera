import 'dart:math';
import '../models/song_model.dart';
import '../models/smart_playlist_model.dart';
import '../models/playlist_model.dart';
import '../repositories/local_music_repository.dart';

class SmartPlaylistService {
  final LocalMusicRepository _repository;

  SmartPlaylistService({LocalMusicRepository? repository})
    : _repository = repository ?? LocalMusicRepository();

  /// Evaluates a single song against a single rule.
  static bool evaluateRule(
    SongModel song,
    SmartPlaylistRule rule, {
    Map<int, int>? playCounts,
    Map<int, DateTime>? lastPlayedMap,
  }) {
    switch (rule.field) {
      case SmartRuleField.title:
        return _evalString(song.title, rule.operator, rule.value);
      case SmartRuleField.artist:
        return _evalString(song.artistName ?? '', rule.operator, rule.value);
      case SmartRuleField.album:
        return _evalString(song.albumTitle ?? '', rule.operator, rule.value);
      case SmartRuleField.genre:
        return _evalString(song.genreName ?? '', rule.operator, rule.value);
      case SmartRuleField.year:
        // Tag year or 0
        final targetYear = int.tryParse(rule.value) ?? 0;
        // In local DB if not explicitly in song model, we treat as 0 or eval if available
        return _evalNumber(0, rule.operator, targetYear);
      case SmartRuleField.duration:
        final targetDur = int.tryParse(rule.value) ?? 0;
        return _evalNumber(song.duration, rule.operator, targetDur);
      case SmartRuleField.format:
        final path = song.filePath ?? song.audioPath;
        final ext = path.contains('.')
            ? path.split('.').last.toLowerCase()
            : '';
        return _evalString(
          ext,
          rule.operator,
          rule.value.toLowerCase().replaceAll('.', ''),
        );
      case SmartRuleField.favorite:
        if (rule.operator == SmartRuleOperator.isFalse) {
          return !song.isFavorite;
        }
        return song.isFavorite;
      case SmartRuleField.playCount:
        final count = playCounts?[song.id] ?? 0;
        final targetCount = int.tryParse(rule.value) ?? 0;
        return _evalNumber(count, rule.operator, targetCount);
      case SmartRuleField.dateAdded:
        // Song creation date / now fallback
        return true;
      case SmartRuleField.lastPlayed:
        final lastDate = lastPlayedMap?[song.id] ?? song.playedAt;
        if (lastDate == null) return false;
        final days = int.tryParse(rule.value) ?? 7;
        final diff = DateTime.now().difference(lastDate).inDays;
        return diff <= days;
      case SmartRuleField.albumArtist:
        return _evalString(song.artistName ?? '', rule.operator, rule.value);
    }
  }

  static bool _evalString(String text, SmartRuleOperator op, String target) {
    final t = text.trim().toLowerCase();
    final q = target.trim().toLowerCase();
    switch (op) {
      case SmartRuleOperator.equals:
        return t == q;
      case SmartRuleOperator.notEquals:
        return t != q;
      case SmartRuleOperator.contains:
        return t.contains(q);
      case SmartRuleOperator.startsWith:
        return t.startsWith(q);
      case SmartRuleOperator.endsWith:
        return t.endsWith(q);
      case SmartRuleOperator.isTrue:
        return t.isNotEmpty && t != 'false' && t != '0';
      case SmartRuleOperator.isFalse:
        return t.isEmpty || t == 'false' || t == '0';
      default:
        return t.contains(q);
    }
  }

  static bool _evalNumber(int val, SmartRuleOperator op, int target) {
    switch (op) {
      case SmartRuleOperator.equals:
        return val == target;
      case SmartRuleOperator.notEquals:
        return val != target;
      case SmartRuleOperator.greaterThan:
        return val > target;
      case SmartRuleOperator.greaterThanOrEqual:
        return val >= target;
      case SmartRuleOperator.lessThan:
        return val < target;
      case SmartRuleOperator.lessThanOrEqual:
        return val <= target;
      default:
        return val == target;
    }
  }

  /// Filters and sorts songs dynamically according to the SmartPlaylistConfig.
  static List<SongModel> filterSongs({
    required List<SongModel> allSongs,
    required SmartPlaylistConfig config,
    Map<int, int>? playCounts,
    Map<int, DateTime>? lastPlayedMap,
  }) {
    final matched = <SongModel>[];

    if (config.rules.isEmpty) {
      matched.addAll(allSongs);
    } else {
      for (final song in allSongs) {
        bool isMatch = false;
        if (config.logic == SmartRuleLogic.all) {
          isMatch = true;
          for (final rule in config.rules) {
            if (!evaluateRule(
              song,
              rule,
              playCounts: playCounts,
              lastPlayedMap: lastPlayedMap,
            )) {
              isMatch = false;
              break;
            }
          }
        } else {
          // ANY (OR)
          isMatch = false;
          for (final rule in config.rules) {
            if (evaluateRule(
              song,
              rule,
              playCounts: playCounts,
              lastPlayedMap: lastPlayedMap,
            )) {
              isMatch = true;
              break;
            }
          }
        }

        if (isMatch) {
          matched.add(song);
        }
      }
    }

    // Apply sorting
    _sortSongs(matched, config.sort, playCounts, lastPlayedMap);

    // Apply limit
    if (config.limit != null &&
        config.limit! > 0 &&
        matched.length > config.limit!) {
      return matched.sublist(0, config.limit!);
    }

    return matched;
  }

  static void _sortSongs(
    List<SongModel> list,
    SmartSortOption sort,
    Map<int, int>? playCounts,
    Map<int, DateTime>? lastPlayedMap,
  ) {
    switch (sort) {
      case SmartSortOption.titleAsc:
        list.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        break;
      case SmartSortOption.titleDesc:
        list.sort(
          (a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()),
        );
        break;
      case SmartSortOption.artistAsc:
        list.sort(
          (a, b) => (a.artistName ?? '').toLowerCase().compareTo(
            (b.artistName ?? '').toLowerCase(),
          ),
        );
        break;
      case SmartSortOption.albumAsc:
        list.sort(
          (a, b) => (a.albumTitle ?? '').toLowerCase().compareTo(
            (b.albumTitle ?? '').toLowerCase(),
          ),
        );
        break;
      case SmartSortOption.dateAddedDesc:
      case SmartSortOption.dateAddedAsc:
        // fallback to id ordering
        if (sort == SmartSortOption.dateAddedDesc) {
          list.sort((a, b) => b.id.compareTo(a.id));
        } else {
          list.sort((a, b) => a.id.compareTo(b.id));
        }
        break;
      case SmartSortOption.playCountDesc:
        list.sort((a, b) {
          final cA = playCounts?[a.id] ?? 0;
          final cB = playCounts?[b.id] ?? 0;
          return cB.compareTo(cA);
        });
        break;
      case SmartSortOption.playCountAsc:
        list.sort((a, b) {
          final cA = playCounts?[a.id] ?? 0;
          final cB = playCounts?[b.id] ?? 0;
          return cA.compareTo(cB);
        });
        break;
      case SmartSortOption.lastPlayedDesc:
        list.sort((a, b) {
          final dtA =
              lastPlayedMap?[a.id] ??
              a.playedAt ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final dtB =
              lastPlayedMap?[b.id] ??
              b.playedAt ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return dtB.compareTo(dtA);
        });
        break;
      case SmartSortOption.durationDesc:
        list.sort((a, b) => b.duration.compareTo(a.duration));
        break;
      case SmartSortOption.durationAsc:
        list.sort((a, b) => a.duration.compareTo(b.duration));
        break;
      case SmartSortOption.random:
        list.shuffle(Random());
        break;
    }
  }

  /// Dynamically computes matching songs for a smart playlist from current database state.
  Future<List<SongModel>> evaluateSmartPlaylist(PlaylistModel playlist) async {
    if (!playlist.isSmart || playlist.smartConfig == null) {
      return playlist.songs;
    }

    final allSongs = await _repository.getAllSongs();
    final favorites = await _repository.getFavorites();
    final favoriteIds = favorites.map((f) => f.id).toSet();

    // Map favorites accurately
    final mappedSongs = allSongs
        .map((s) => s.copyWith(isFavorite: favoriteIds.contains(s.id)))
        .toList();

    // Collect play counts & last played from listening history
    final db = await _repository.database;
    final playCountMap = <int, int>{};
    final lastPlayedMap = <int, DateTime>{};

    try {
      final counts = await db.rawQuery('''
        SELECT song_id, COUNT(*) as play_count, MAX(started_at) as max_started
        FROM listening_histories
        GROUP BY song_id
      ''');
      for (final row in counts) {
        final sid = row['song_id'] as int;
        final cnt = row['play_count'] as int;
        playCountMap[sid] = cnt;
        if (row['max_started'] != null) {
          final dt = DateTime.tryParse(row['max_started'].toString());
          if (dt != null) lastPlayedMap[sid] = dt;
        }
      }
    } catch (_) {}

    return filterSongs(
      allSongs: mappedSongs,
      config: playlist.smartConfig!,
      playCounts: playCountMap,
      lastPlayedMap: lastPlayedMap,
    );
  }

  /// Creates a persistent smart playlist.
  Future<int> createSmartPlaylist({
    required String name,
    String? description,
    required SmartPlaylistConfig config,
  }) async {
    return await _repository.createSmartPlaylist(
      name: name,
      description: description,
      config: config,
    );
  }

  /// Updates an existing smart playlist configuration.
  Future<void> updateSmartPlaylist({
    required int playlistId,
    required String name,
    String? description,
    required SmartPlaylistConfig config,
  }) async {
    await _repository.updateSmartPlaylist(
      playlistId: playlistId,
      name: name,
      description: description,
      config: config,
    );
  }
}
