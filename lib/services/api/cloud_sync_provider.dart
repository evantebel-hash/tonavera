import 'dart:convert';
import '../../repositories/sync_outbox_repository.dart';
import 'api_service.dart';

abstract class CloudSyncProvider {
  String get providerName;
  bool get isCloudAvailable;
  Future<bool> isConnected();
  Future<Map<String, dynamic>> getSyncStatus();
  Future<bool> syncNow();
  Future<int> syncPendingOutbox();
}

/// Production-ready Cloud Sync Provider wrapping SyncOutboxRepository & ApiService
class DefaultCloudSyncProvider implements CloudSyncProvider {
  final SyncOutboxRepository _outboxRepo;
  bool _isSyncing = false;

  DefaultCloudSyncProvider({SyncOutboxRepository? outboxRepo})
    : _outboxRepo = outboxRepo ?? SyncOutboxRepository();

  @override
  String get providerName => 'MyMusic PHP/XAMPP API Backend';

  @override
  bool get isCloudAvailable => false; // Local-first offline mode by default until user logs in

  @override
  Future<bool> isConnected() async {
    final token = await ApiService.getToken();
    return token != null &&
        token.isNotEmpty &&
        !token.startsWith('local_token_');
  }

  @override
  Future<Map<String, dynamic>> getSyncStatus() async {
    final online = await isConnected();
    int pending = 0;
    if (online) {
      try {
        pending = await _outboxRepo.getPendingCount();
      } catch (_) {}
    }
    return {
      'enabled': online,
      'pendingCount': pending,
      'provider': providerName,
    };
  }

  @override
  Future<bool> syncNow() async {
    final synced = await syncPendingOutbox();
    return synced >= 0;
  }

  @override
  Future<int> syncPendingOutbox() async {
    if (_isSyncing) return 0;
    _isSyncing = true;
    int syncedCount = 0;

    try {
      final isOnline = await isConnected();
      if (!isOnline) return 0;

      final items = await _outboxRepo.getPendingItems(limit: 50);
      for (final item in items) {
        if (item.retryCount >= 5) continue;

        bool success = false;
        try {
          Map<String, dynamic> payload = {};
          if (item.payloadJson.isNotEmpty) {
            try {
              payload = json.decode(item.payloadJson) as Map<String, dynamic>;
            } catch (_) {}
          }

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

          if (success && item.id != null) {
            await _outboxRepo.remove(item.id!);
            syncedCount++;
          } else if (item.id != null) {
            await _outboxRepo.updateRetry(
              item.id!,
              item.retryCount + 1,
              'Sync attempt unconfirmed',
            );
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
