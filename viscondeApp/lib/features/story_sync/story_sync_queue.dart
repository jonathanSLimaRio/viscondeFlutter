import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class StorySyncEvent {
  const StorySyncEvent({
    required this.id,
    required this.storyId,
    required this.payload,
    required this.createdAt,
  });

  final int id;
  final String storyId;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
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
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE story_sync_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  story_id TEXT NOT NULL,
  payload TEXT NOT NULL,
  created_at INTEGER NOT NULL
)
''');
        await db.execute(
          'CREATE INDEX idx_story_sync_story ON story_sync_events(story_id)',
        );
      },
    );

    return _db!;
  }

  Future<void> enqueueStep({
    required String storyId,
    required Map<String, dynamic> payload,
    DateTime? createdAt,
  }) async {
    final db = await _open();

    await db.insert('story_sync_events', {
      'story_id': storyId,
      'payload': jsonEncode(payload),
      'created_at': (createdAt ?? DateTime.now()).millisecondsSinceEpoch,
    });
  }

  Future<List<StorySyncEvent>> listPending({String? storyId}) async {
    final db = await _open();

    final rows = await db.query(
      'story_sync_events',
      where: storyId != null ? 'story_id = ?' : null,
      whereArgs: storyId != null ? [storyId] : null,
      orderBy: 'created_at ASC, id ASC',
    );

    return rows.map((row) {
      final payloadRaw = row['payload'] as String?;
      final payloadJson = payloadRaw == null
          ? <String, dynamic>{}
          : jsonDecode(payloadRaw) as Map<String, dynamic>;

      return StorySyncEvent(
        id: (row['id'] as num?)?.toInt() ?? 0,
        storyId: (row['story_id'] as String?) ?? '',
        payload: payloadJson,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (row['created_at'] as num?)?.toInt() ?? 0,
        ),
      );
    }).toList();
  }

  Future<int> pendingCount({String? storyId}) async {
    final db = await _open();

    final rows = await db.rawQuery(
      storyId == null
          ? 'SELECT COUNT(*) as c FROM story_sync_events'
          : 'SELECT COUNT(*) as c FROM story_sync_events WHERE story_id = ?',
      storyId == null ? <Object?>[] : <Object?>[storyId],
    );

    if (rows.isEmpty) {
      return 0;
    }

    return (rows.first['c'] as num?)?.toInt() ?? 0;
  }

  Future<void> removeEvent(int id) async {
    final db = await _open();
    await db.delete('story_sync_events', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearStory(String storyId) async {
    final db = await _open();
    await db.delete('story_sync_events', where: 'story_id = ?', whereArgs: [storyId]);
  }

  Future<void> dispose() async {
    await _db?.close();
    _db = null;
  }
}
