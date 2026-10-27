import 'package:sqflite/sqflite.dart';
import '../database/local_database_service.dart';

class SyncOutboxItem {
  final int? id;
  final String entityType; // 'playlist', 'favorite', 'history'
  final String entityUuid;
  final String operation; // 'CREATE', 'UPDATE', 'DELETE'
  final String payloadJson;
  final int retryCount;
  final String? lastError;
  final String createdAtUtc;

  SyncOutboxItem({
    this.id,
    required this.entityType,
    required this.entityUuid,
    required this.operation,
    required this.payloadJson,
    this.retryCount = 0,
    this.lastError,
    required this.createdAtUtc,
  });

  factory SyncOutboxItem.fromMap(Map<String, dynamic> map) {
    return SyncOutboxItem(
      id: map['id'] as int?,
      entityType: map['entity_type'] as String,
      entityUuid: map['entity_uuid'] as String,
      operation: map['operation'] as String,
      payloadJson: map['payload_json'] as String,
      retryCount: map['retry_count'] as int? ?? 0,
      lastError: map['last_error'] as String?,
      createdAtUtc: map['created_at_utc'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'entity_type': entityType,
      'entity_uuid': entityUuid,
      'operation': operation,
      'payload_json': payloadJson,
      'retry_count': retryCount,
      'last_error': lastError,
      'created_at_utc': createdAtUtc,
    };
  }
}

class SyncOutboxRepository {
  final LocalDatabaseService _dbService = LocalDatabaseService.instance;

  Future<int> enqueue(SyncOutboxItem item) async {
    final db = await _dbService.database;
    return await db.insert('sync_outbox', item.toMap());
  }

  Future<List<SyncOutboxItem>> getPendingItems({int limit = 50}) async {
    final db = await _dbService.database;
    final maps = await db.query('sync_outbox', orderBy: 'id ASC', limit: limit);
    return maps.map((m) => SyncOutboxItem.fromMap(m)).toList();
  }

  Future<int> remove(int id) async {
    final db = await _dbService.database;
    return await db.delete('sync_outbox', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateRetry(int id, int retryCount, String error) async {
    final db = await _dbService.database;
    return await db.update(
      'sync_outbox',
      {'retry_count': retryCount, 'last_error': error},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> getPendingCount() async {
    final db = await _dbService.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM sync_outbox',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
