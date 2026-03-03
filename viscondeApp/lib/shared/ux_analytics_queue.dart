import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'ux_analytics.dart';

enum UxAnalyticsQueueStatus { pending, failed, sent }

String uxAnalyticsQueueStatusToDb(UxAnalyticsQueueStatus status) {
  switch (status) {
    case UxAnalyticsQueueStatus.pending:
      return 'pending';
    case UxAnalyticsQueueStatus.failed:
      return 'failed';
    case UxAnalyticsQueueStatus.sent:
      return 'sent';
  }
}

UxAnalyticsQueueStatus uxAnalyticsQueueStatusFromDb(String? raw) {
  switch (raw) {
    case 'failed':
      return UxAnalyticsQueueStatus.failed;
    case 'sent':
      return UxAnalyticsQueueStatus.sent;
    case 'pending':
    default:
      return UxAnalyticsQueueStatus.pending;
  }
}

class QueuedUxAnalyticsEvent {
  const QueuedUxAnalyticsEvent({
    required this.id,
    required this.eventId,
    required this.name,
    required this.appSessionId,
    required this.occurredAt,
    required this.params,
    this.source,
    this.childId,
    required this.status,
    required this.retryCount,
    this.nextRetryAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String eventId;
  final String name;
  final String appSessionId;
  final DateTime occurredAt;
  final Map<String, Object?> params;
  final String? source;
  final String? childId;
  final UxAnalyticsQueueStatus status;
  final int retryCount;
  final DateTime? nextRetryAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}

abstract class UxAnalyticsStore {
  Future<void> enqueue({
    required UxAnalyticsEvent event,
    required String appSessionId,
    String? source,
    String? childId,
    Map<String, Object?> params,
  });

  Future<List<QueuedUxAnalyticsEvent>> listRetryable({int limit = 50});

  Future<void> markSent(List<int> ids);

  Future<void> markFailed(List<int> ids, {String? reason});

  Future<void> dispose();
}

class UxAnalyticsQueue implements UxAnalyticsStore {
  UxAnalyticsQueue();

  Database? _db;

  Future<Database> _open() async {
    if (_db != null) {
      return _db!;
    }

    final dbPath = await getDatabasesPath();
    final filePath = p.join(dbPath, 'visconde_ux_analytics.db');

    _db = await openDatabase(
      filePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE ux_analytics_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  event_id TEXT NOT NULL,
  event_name TEXT NOT NULL,
  app_session_id TEXT NOT NULL,
  occurred_at INTEGER NOT NULL,
  source TEXT,
  child_id TEXT,
  params_json TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  retry_count INTEGER NOT NULL DEFAULT 0,
  next_retry_at INTEGER,
  last_error TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)
''');
        await db.execute(
          'CREATE UNIQUE INDEX idx_ux_event_id ON ux_analytics_events(event_id)',
        );
        await db.execute(
          'CREATE INDEX idx_ux_status_next_retry ON ux_analytics_events(status, next_retry_at)',
        );
        await db.execute(
          'CREATE INDEX idx_ux_occurred ON ux_analytics_events(occurred_at)',
        );
      },
    );

    return _db!;
  }

  QueuedUxAnalyticsEvent _mapRow(Map<String, Object?> row) {
    DateTime parseEpoch(Object? value) {
      final milliseconds = (value as num?)?.toInt() ?? 0;
      return DateTime.fromMillisecondsSinceEpoch(milliseconds);
    }

    DateTime? parseOptionalEpoch(Object? value) {
      final milliseconds = (value as num?)?.toInt();
      if (milliseconds == null) {
        return null;
      }
      return DateTime.fromMillisecondsSinceEpoch(milliseconds);
    }

    final rawParams = (row['params_json'] as String?)?.trim();
    final params = rawParams == null || rawParams.isEmpty
        ? const <String, Object?>{}
        : (jsonDecode(rawParams) as Map<String, dynamic>).map(
            (key, value) => MapEntry(key, value),
          );

    return QueuedUxAnalyticsEvent(
      id: (row['id'] as num?)?.toInt() ?? 0,
      eventId: (row['event_id'] as String?) ?? '',
      name: (row['event_name'] as String?) ?? '',
      appSessionId: (row['app_session_id'] as String?) ?? '',
      occurredAt: parseEpoch(row['occurred_at']),
      source: row['source'] as String?,
      childId: row['child_id'] as String?,
      params: params,
      status: uxAnalyticsQueueStatusFromDb(row['status'] as String?),
      retryCount: (row['retry_count'] as num?)?.toInt() ?? 0,
      nextRetryAt: parseOptionalEpoch(row['next_retry_at']),
      createdAt: parseEpoch(row['created_at']),
      updatedAt: parseEpoch(row['updated_at']),
    );
  }

  @override
  Future<void> enqueue({
    required UxAnalyticsEvent event,
    required String appSessionId,
    String? source,
    String? childId,
    Map<String, Object?> params = const <String, Object?>{},
  }) async {
    final db = await _open();
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;

    await db.insert('ux_analytics_events', {
      'event_id': event.eventId,
      'event_name': event.name,
      'app_session_id': appSessionId,
      'occurred_at': event.occurredAt.millisecondsSinceEpoch,
      'source': source,
      'child_id': childId,
      'params_json': params.isEmpty ? null : jsonEncode(params),
      'status': uxAnalyticsQueueStatusToDb(UxAnalyticsQueueStatus.pending),
      'retry_count': 0,
      'next_retry_at': null,
      'last_error': null,
      'created_at': nowMs,
      'updated_at': nowMs,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  @override
  Future<List<QueuedUxAnalyticsEvent>> listRetryable({int limit = 50}) async {
    final db = await _open();
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final rows = await db.query(
      'ux_analytics_events',
      where:
          "status IN ('pending','failed') AND (next_retry_at IS NULL OR next_retry_at <= ?)",
      whereArgs: <Object?>[nowMs],
      orderBy: 'occurred_at ASC, id ASC',
      limit: limit,
    );

    return rows.map(_mapRow).toList();
  }

  @override
  Future<void> markSent(List<int> ids) async {
    if (ids.isEmpty) {
      return;
    }

    final db = await _open();
    final placeholders = List<String>.filled(ids.length, '?').join(', ');
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    await db.rawUpdate(
      '''
UPDATE ux_analytics_events
SET status = ?, updated_at = ?, next_retry_at = NULL, last_error = NULL
WHERE id IN ($placeholders)
''',
      <Object?>[
        uxAnalyticsQueueStatusToDb(UxAnalyticsQueueStatus.sent),
        nowMs,
        ...ids,
      ],
    );
  }

  @override
  Future<void> markFailed(List<int> ids, {String? reason}) async {
    if (ids.isEmpty) {
      return;
    }

    final db = await _open();
    final rows = await db.query(
      'ux_analytics_events',
      columns: <String>['id', 'retry_count'],
      where: 'id IN (${List<String>.filled(ids.length, '?').join(', ')})',
      whereArgs: ids,
    );

    final now = DateTime.now();

    for (final row in rows) {
      final id = (row['id'] as num?)?.toInt();
      if (id == null) {
        continue;
      }

      final retryCount = ((row['retry_count'] as num?)?.toInt() ?? 0) + 1;
      final delaySeconds = _retryDelaySeconds(retryCount);
      final nextRetry = now.add(Duration(seconds: delaySeconds));

      await db.update(
        'ux_analytics_events',
        {
          'status': uxAnalyticsQueueStatusToDb(UxAnalyticsQueueStatus.failed),
          'retry_count': retryCount,
          'next_retry_at': nextRetry.millisecondsSinceEpoch,
          'last_error': reason,
          'updated_at': now.millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    }
  }

  int _retryDelaySeconds(int retryCount) {
    final delay = 5 * (1 << (retryCount - 1));
    if (delay > 300) {
      return 300;
    }
    return delay;
  }

  @override
  Future<void> dispose() async {
    await _db?.close();
    _db = null;
  }
}
