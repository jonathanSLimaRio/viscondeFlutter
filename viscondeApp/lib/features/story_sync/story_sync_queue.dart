import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

enum StorySyncEventStatus { pending, failed, conflict, synced }

StorySyncEventStatus storySyncEventStatusFromDb(String? raw) {
  switch (raw) {
    case 'failed':
      return StorySyncEventStatus.failed;
    case 'conflict':
      return StorySyncEventStatus.conflict;
    case 'synced':
      return StorySyncEventStatus.synced;
    case 'pending':
    default:
      return StorySyncEventStatus.pending;
  }
}

String storySyncEventStatusToDb(StorySyncEventStatus status) {
  switch (status) {
    case StorySyncEventStatus.pending:
      return 'pending';
    case StorySyncEventStatus.failed:
      return 'failed';
    case StorySyncEventStatus.conflict:
      return 'conflict';
    case StorySyncEventStatus.synced:
      return 'synced';
  }
}

class StorySyncEvent {
  const StorySyncEvent({
    required this.id,
    required this.storyId,
    required this.payload,
    required this.status,
    required this.retryCount,
    this.lastError,
    this.lastHttpStatus,
    this.nextRetryAt,
    this.lastAttemptAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String storyId;
  final Map<String, dynamic> payload;
  final StorySyncEventStatus status;
  final int retryCount;
  final String? lastError;
  final int? lastHttpStatus;
  final DateTime? nextRetryAt;
  final DateTime? lastAttemptAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class StorySyncQueueStatusCounts {
  const StorySyncQueueStatusCounts({
    this.pending = 0,
    this.failed = 0,
    this.conflict = 0,
    this.synced = 0,
  });

  final int pending;
  final int failed;
  final int conflict;
  final int synced;

  int get unsynced => pending + failed + conflict;
}

class StorySyncQueue {
  StorySyncQueue();

  Database? _db;

  Future<Database> _open() async {
    if (_db != null) {
      return _db!;
    }

    final dbPath = await getDatabasesPath();
    final filePath = p.join(dbPath, 'visconde_story_sync.db');

    _db = await openDatabase(
      filePath,
      version: 2,
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE story_sync_events ADD COLUMN status TEXT NOT NULL DEFAULT 'pending'",
          );
          await db.execute(
            'ALTER TABLE story_sync_events ADD COLUMN retry_count INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute(
            'ALTER TABLE story_sync_events ADD COLUMN last_error TEXT',
          );
          await db.execute(
            'ALTER TABLE story_sync_events ADD COLUMN last_http_status INTEGER',
          );
          await db.execute(
            'ALTER TABLE story_sync_events ADD COLUMN next_retry_at INTEGER',
          );
          await db.execute(
            'ALTER TABLE story_sync_events ADD COLUMN last_attempt_at INTEGER',
          );
          await db.execute(
            'ALTER TABLE story_sync_events ADD COLUMN updated_at INTEGER',
          );
          final now = DateTime.now().millisecondsSinceEpoch;
          await db.rawUpdate(
            'UPDATE story_sync_events SET updated_at = created_at WHERE updated_at IS NULL',
          );
          await db.rawUpdate(
            "UPDATE story_sync_events SET status = 'pending' WHERE status IS NULL OR status = ''",
          );
          await db.rawUpdate(
            'UPDATE story_sync_events SET retry_count = 0 WHERE retry_count IS NULL',
          );
          await db.rawUpdate(
            'UPDATE story_sync_events SET updated_at = ? WHERE updated_at IS NULL',
            <Object?>[now],
          );
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_story_sync_status ON story_sync_events(status)',
          );
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_story_sync_next_retry ON story_sync_events(next_retry_at)',
          );
        }
      },
    );

    return _db!;
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
CREATE TABLE story_sync_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  story_id TEXT NOT NULL,
  payload TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  retry_count INTEGER NOT NULL DEFAULT 0,
  last_error TEXT,
  last_http_status INTEGER,
  next_retry_at INTEGER,
  last_attempt_at INTEGER,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)
''');
    await db.execute(
      'CREATE INDEX idx_story_sync_story ON story_sync_events(story_id)',
    );
    await db.execute(
      'CREATE INDEX idx_story_sync_status ON story_sync_events(status)',
    );
    await db.execute(
      'CREATE INDEX idx_story_sync_next_retry ON story_sync_events(next_retry_at)',
    );
  }

  StorySyncEvent _mapRow(Map<String, Object?> row) {
    final payloadRaw = row['payload'] as String?;
    final payloadJson = payloadRaw == null
        ? <String, dynamic>{}
        : jsonDecode(payloadRaw) as Map<String, dynamic>;

    DateTime? parseEpoch(Object? raw) {
      final ms = (raw as num?)?.toInt();
      if (ms == null || ms <= 0) {
        return null;
      }
      return DateTime.fromMillisecondsSinceEpoch(ms);
    }

    return StorySyncEvent(
      id: (row['id'] as num?)?.toInt() ?? 0,
      storyId: (row['story_id'] as String?) ?? '',
      payload: payloadJson,
      status: storySyncEventStatusFromDb(row['status'] as String?),
      retryCount: (row['retry_count'] as num?)?.toInt() ?? 0,
      lastError: row['last_error'] as String?,
      lastHttpStatus: (row['last_http_status'] as num?)?.toInt(),
      nextRetryAt: parseEpoch(row['next_retry_at']),
      lastAttemptAt: parseEpoch(row['last_attempt_at']),
      createdAt:
          parseEpoch(row['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          parseEpoch(row['updated_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Future<void> enqueueStep({
    required String storyId,
    required Map<String, dynamic> payload,
    DateTime? createdAt,
  }) async {
    final db = await _open();
    final now = createdAt ?? DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;

    await db.insert('story_sync_events', {
      'story_id': storyId,
      'payload': jsonEncode(payload),
      'status': storySyncEventStatusToDb(StorySyncEventStatus.pending),
      'retry_count': 0,
      'created_at': nowMs,
      'updated_at': nowMs,
    });
  }

  Future<List<StorySyncEvent>> listPending({String? storyId}) async {
    final db = await _open();

    final rows = await db.query(
      'story_sync_events',
      where: storyId != null
          ? "story_id = ? AND status != 'synced'"
          : "status != 'synced'",
      whereArgs: storyId != null ? <Object?>[storyId] : null,
      orderBy: 'created_at ASC, id ASC',
    );

    return rows.map(_mapRow).toList();
  }

  Future<List<StorySyncEvent>> listRetryable({String? storyId}) async {
    final db = await _open();
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final where = storyId != null
        ? "story_id = ? AND status IN ('pending','failed') AND (next_retry_at IS NULL OR next_retry_at <= ?)"
        : "status IN ('pending','failed') AND (next_retry_at IS NULL OR next_retry_at <= ?)";

    final args = storyId != null ? <Object?>[storyId, nowMs] : <Object?>[nowMs];

    final rows = await db.query(
      'story_sync_events',
      where: where,
      whereArgs: args,
      orderBy: 'created_at ASC, id ASC',
    );

    return rows.map(_mapRow).toList();
  }

  Future<int> pendingCount({String? storyId}) async {
    final counts = await statusCounts(storyId: storyId);
    return counts.unsynced;
  }

  Future<StorySyncQueueStatusCounts> statusCounts({String? storyId}) async {
    final db = await _open();
    final where = storyId != null ? 'WHERE story_id = ?' : '';
    final rows = await db.rawQuery('''
SELECT status, COUNT(*) AS c
FROM story_sync_events
$where
GROUP BY status
''', storyId == null ? <Object?>[] : <Object?>[storyId]);

    int countFor(String status) {
      for (final row in rows) {
        if ((row['status'] as String?) == status) {
          return (row['c'] as num?)?.toInt() ?? 0;
        }
      }
      return 0;
    }

    return StorySyncQueueStatusCounts(
      pending: countFor('pending'),
      failed: countFor('failed'),
      conflict: countFor('conflict'),
      synced: countFor('synced'),
    );
  }

  Future<void> markSynced(int id) async {
    final db = await _open();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'story_sync_events',
      {
        'status': storySyncEventStatusToDb(StorySyncEventStatus.synced),
        'last_error': null,
        'next_retry_at': null,
        'updated_at': nowMs,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> markConflict({
    required int id,
    required String reason,
    int? httpStatus,
  }) async {
    final db = await _open();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'story_sync_events',
      {
        'status': storySyncEventStatusToDb(StorySyncEventStatus.conflict),
        'last_error': reason,
        'last_http_status': httpStatus,
        'last_attempt_at': nowMs,
        'next_retry_at': null,
        'updated_at': nowMs,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> markFailed({
    required int id,
    required String reason,
    int? httpStatus,
    Duration retryAfter = const Duration(seconds: 5),
  }) async {
    final db = await _open();
    final now = DateTime.now();
    final rows = await db.query(
      'story_sync_events',
      columns: <String>['retry_count'],
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    final currentRetry = rows.isNotEmpty
        ? (rows.first['retry_count'] as num?)?.toInt() ?? 0
        : 0;
    final nextRetry = now.add(retryAfter);

    await db.update(
      'story_sync_events',
      {
        'status': storySyncEventStatusToDb(StorySyncEventStatus.failed),
        'retry_count': currentRetry + 1,
        'last_error': reason,
        'last_http_status': httpStatus,
        'last_attempt_at': now.millisecondsSinceEpoch,
        'next_retry_at': nextRetry.millisecondsSinceEpoch,
        'updated_at': now.millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> markPending(int id) async {
    final db = await _open();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'story_sync_events',
      {
        'status': storySyncEventStatusToDb(StorySyncEventStatus.pending),
        'last_error': null,
        'next_retry_at': null,
        'updated_at': nowMs,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> removeEvent(int id) async {
    final db = await _open();
    await db.delete(
      'story_sync_events',
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> clearStory(String storyId) async {
    final db = await _open();
    await db.delete(
      'story_sync_events',
      where: 'story_id = ?',
      whereArgs: <Object?>[storyId],
    );
  }

  Future<void> purgeSynced({DateTime? olderThan}) async {
    final db = await _open();
    if (olderThan == null) {
      await db.delete('story_sync_events', where: "status = 'synced'");
      return;
    }

    await db.delete(
      'story_sync_events',
      where: "status = 'synced' AND updated_at <= ?",
      whereArgs: <Object?>[olderThan.millisecondsSinceEpoch],
    );
  }

  Future<void> dispose() async {
    await _db?.close();
    _db = null;
  }
}
