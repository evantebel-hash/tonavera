import 'dart:convert';
import '../../repositories/sync_outbox_repository.dart';
import 'api_service.dart';

class SyncService {
  final SyncOutboxRepository _outboxRepo = SyncOutboxRepository();
  bool _isSyncing = false;

  bool get isSyncing => _isSyncing;

  Future<int> processOutbox() async {
    if (_isSyncing) return 0;
    _isSyncing = true;

    int syncedCount = 0;
    try {
      final items = await _outboxRepo.getPendingItems(limit: 20);
      if (items.isEmpty) {
        _isSyncing = false;
        return 0;
      }

      for (final item in items) {
        if (item.retryCount >= 5) {
          // Skip items that have failed repeatedly
          continue;
        }

        bool success = false;
        try {
          final payload = json.decode(item.payloadJson) as Map<String, dynamic>;

          if (item.entityType == 'playlist') {
            if (item.operation == 'CREATE') {
              final res = await ApiService.post('playlists', payload);
              success = res['status'] == true;
            } else if (item.operation == 'DELETE') {
              final res = await ApiService.delete(
                'playlists/${item.entityUuid}',
              );
              success = res['status'] == true;
            }
          } else if (item.entityType == 'favorite') {
            if (item.operation == 'CREATE') {
              final res = await ApiService.post('favorites', payload);
              success = res['status'] == true;
            } else if (item.operation == 'DELETE') {
              final res = await ApiService.delete(
                'favorites/${item.entityUuid}',
              );
              success = res['status'] == true;
            }
          } else if (item.entityType == 'history') {
            if (item.operation == 'CREATE') {
              final res = await ApiService.post('history', payload);
              success = res['status'] == true;
            }
          }

          if (success) {
            if (item.id != null) {
              await _outboxRepo.remove(item.id!);
              syncedCount++;
            }
          } else {
            if (item.id != null) {
              await _outboxRepo.updateRetry(
                item.id!,
                item.retryCount + 1,
                'Sync failed or server offline',
              );
            }
          }
        } catch (e) {
          if (item.id != null) {
            await _outboxRepo.updateRetry(
              item.id!,
              item.retryCount + 1,
              e.toString(),
            );
          }
        }
      }
    } finally {
      _isSyncing = false;
    }

    return syncedCount;
  }
}
