import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../story_room/models/story_enums.dart';

class CreateStoryWizardDraft {
  const CreateStoryWizardDraft({
    required this.userId,
    required this.currentStep,
    required this.mode,
    required this.titleDraft,
    required this.theme,
    required this.scenario,
    required this.objective,
    required this.characters,
    required this.updatedAt,
    this.storyId,
    this.selectedChildId,
    this.selectedVirtueId,
    this.selectedTemplateId,
    this.selectedArtStyleId,
  });

  final String userId;
  final String? storyId;
  final int currentStep;
  final String? selectedChildId;
  final String? selectedVirtueId;
  final String? selectedTemplateId;
  final String? selectedArtStyleId;
  final StoryMode mode;
  final String titleDraft;
  final String theme;
  final String scenario;
  final String objective;
  final String characters;
  final DateTime updatedAt;

  Map<String, Object?> toDbMap() {
    return <String, Object?>{
      'user_id': userId,
      'story_id': storyId,
      'current_step': currentStep,
      'selected_child_id': selectedChildId,
      'selected_virtue_id': selectedVirtueId,
      'selected_template_id': selectedTemplateId,
      'selected_art_style_id': selectedArtStyleId,
      'mode': storyModeToApi(mode),
      'title_draft': titleDraft,
      'theme': theme,
      'scenario': scenario,
      'objective': objective,
      'characters': characters,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory CreateStoryWizardDraft.fromDbMap(Map<String, Object?> row) {
    final rawStep = (row['current_step'] as num?)?.toInt() ?? 0;
    return CreateStoryWizardDraft(
      userId: (row['user_id'] as String?) ?? '',
      storyId: row['story_id'] as String?,
      currentStep: rawStep.clamp(0, 2),
      selectedChildId: row['selected_child_id'] as String?,
      selectedVirtueId: row['selected_virtue_id'] as String?,
      selectedTemplateId: row['selected_template_id'] as String?,
      selectedArtStyleId: row['selected_art_style_id'] as String?,
      mode: storyModeFromApi(
        (row['mode'] as String?) ?? storyModeToApi(StoryMode.parentNarrator),
      ),
      titleDraft: (row['title_draft'] as String?) ?? '',
      theme: (row['theme'] as String?) ?? '',
      scenario: (row['scenario'] as String?) ?? '',
      objective: (row['objective'] as String?) ?? '',
      characters: (row['characters'] as String?) ?? '',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (row['updated_at'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  CreateStoryWizardDraft copyWith({
    String? storyId,
    int? currentStep,
    String? selectedChildId,
    String? selectedVirtueId,
    String? selectedTemplateId,
    String? selectedArtStyleId,
    StoryMode? mode,
    String? titleDraft,
    String? theme,
    String? scenario,
    String? objective,
    String? characters,
    DateTime? updatedAt,
  }) {
    return CreateStoryWizardDraft(
      userId: userId,
      storyId: storyId ?? this.storyId,
      currentStep: currentStep ?? this.currentStep,
      selectedChildId: selectedChildId ?? this.selectedChildId,
      selectedVirtueId: selectedVirtueId ?? this.selectedVirtueId,
      selectedTemplateId: selectedTemplateId ?? this.selectedTemplateId,
      selectedArtStyleId: selectedArtStyleId ?? this.selectedArtStyleId,
      mode: mode ?? this.mode,
      titleDraft: titleDraft ?? this.titleDraft,
      theme: theme ?? this.theme,
      scenario: scenario ?? this.scenario,
      objective: objective ?? this.objective,
      characters: characters ?? this.characters,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toDebugJson() {
    return <String, Object?>{
      'userId': userId,
      'storyId': storyId,
      'currentStep': currentStep,
      'selectedChildId': selectedChildId,
      'selectedVirtueId': selectedVirtueId,
      'selectedTemplateId': selectedTemplateId,
      'selectedArtStyleId': selectedArtStyleId,
      'mode': storyModeToApi(mode),
      'titleDraft': titleDraft,
      'theme': theme,
      'scenario': scenario,
      'objective': objective,
      'characters': characters,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  @override
  String toString() => jsonEncode(toDebugJson());
}

abstract class CreateStoryWizardDraftStore {
  Future<void> save(CreateStoryWizardDraft draft);

  Future<CreateStoryWizardDraft?> read(String userId);

  Future<void> clear(String userId);

  Future<void> dispose();
}

class SQLiteCreateStoryWizardDraftStore implements CreateStoryWizardDraftStore {
  SQLiteCreateStoryWizardDraftStore();

  Database? _db;

  Future<Database> _open() async {
    if (_db != null) {
      return _db!;
    }

    final dbPath = await getDatabasesPath();
    final filePath = p.join(dbPath, 'visconde_create_story_draft.db');

    _db = await openDatabase(
      filePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE create_story_wizard_drafts (
  user_id TEXT PRIMARY KEY,
  story_id TEXT,
  current_step INTEGER NOT NULL,
  selected_child_id TEXT,
  selected_virtue_id TEXT,
  selected_template_id TEXT,
  selected_art_style_id TEXT,
  mode TEXT NOT NULL,
  title_draft TEXT NOT NULL,
  theme TEXT NOT NULL,
  scenario TEXT NOT NULL,
  objective TEXT NOT NULL,
  characters TEXT NOT NULL,
  updated_at INTEGER NOT NULL
)
''');
      },
    );

    return _db!;
  }

  @override
  Future<void> save(CreateStoryWizardDraft draft) async {
    final db = await _open();
    await db.insert(
      'create_story_wizard_drafts',
      draft.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<CreateStoryWizardDraft?> read(String userId) async {
    final db = await _open();
    final rows = await db.query(
      'create_story_wizard_drafts',
      where: 'user_id = ?',
      whereArgs: <Object?>[userId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return CreateStoryWizardDraft.fromDbMap(rows.first);
  }

  @override
  Future<void> clear(String userId) async {
    final db = await _open();
    await db.delete(
      'create_story_wizard_drafts',
      where: 'user_id = ?',
      whereArgs: <Object?>[userId],
    );
  }

  @override
  Future<void> dispose() async {
    final db = _db;
    _db = null;
    if (db != null && db.isOpen) {
      await db.close();
    }
  }
}
