import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_service.dart';

class OfflineSyncService {
  static const String _pendingHistoryKey = 'pending_offline_history';

  static Future<void> saveOfflineHistory({
    required int songId,
    required DateTime startedAt,
    required DateTime endedAt,
    required int durationPlayed,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> current = prefs.getStringList(_pendingHistoryKey) ?? [];

    final record = {
      'song_id': songId,
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt.toIso8601String(),
      'duration_played': durationPlayed,
    };

    current.add(json.encode(record));
    await prefs.setStringList(_pendingHistoryKey, current);
    debugPrint('Offline history saved locally: $record');
  }

  static Future<void> syncPendingHistory() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> current = prefs.getStringList(_pendingHistoryKey) ?? [];
    if (current.isEmpty) return;

    debugPrint('Syncing ${current.length} offline history items to backend...');
    List<String> failedItems = [];

    for (String itemStr in current) {
      try {
        final Map<String, dynamic> item = json.decode(itemStr);
        final response = await ApiService.post('history', item);
        if (response['status'] != true) {
          failedItems.add(itemStr);
        }
      } catch (e) {
        failedItems.add(itemStr);
      }
    }

    await prefs.setStringList(_pendingHistoryKey, failedItems);
    debugPrint(
      'Offline history sync completed. Remaining unsynced: ${failedItems.length}',
    );
  }
}
