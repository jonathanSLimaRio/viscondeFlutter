enum StoryMode { parentNarrator, childChooser }

enum StoryStatus { draft, published, archived }

enum StoryStepKind { narration, childChoice, system }

StoryMode storyModeFromApi(String value) {
  switch (value) {
    case 'CHILD_CHOOSER':
      return StoryMode.childChooser;
    case 'PARENT_NARRATOR':
    default:
      return StoryMode.parentNarrator;
  }
}

String storyModeToApi(StoryMode value) {
  switch (value) {
    case StoryMode.childChooser:
      return 'CHILD_CHOOSER';
    case StoryMode.parentNarrator:
      return 'PARENT_NARRATOR';
  }
}

StoryStatus storyStatusFromApi(String value) {
  switch (value) {
    case 'PUBLISHED':
      return StoryStatus.published;
    case 'ARCHIVED':
      return StoryStatus.archived;
    case 'DRAFT':
    default:
      return StoryStatus.draft;
  }
}

String storyStatusToApi(StoryStatus value) {
  switch (value) {
    case StoryStatus.published:
      return 'PUBLISHED';
    case StoryStatus.archived:
      return 'ARCHIVED';
    case StoryStatus.draft:
      return 'DRAFT';
  }
}

StoryStepKind storyStepKindFromApi(String value) {
  switch (value) {
    case 'CHILD_CHOICE':
      return StoryStepKind.childChoice;
    case 'SYSTEM':
      return StoryStepKind.system;
    case 'NARRATION':
    default:
      return StoryStepKind.narration;
  }
}

String storyStepKindToApi(StoryStepKind value) {
  switch (value) {
    case StoryStepKind.childChoice:
      return 'CHILD_CHOICE';
    case StoryStepKind.system:
      return 'SYSTEM';
    case StoryStepKind.narration:
      return 'NARRATION';
  }
}

class StoryChildSnapshot {
  const StoryChildSnapshot({
    required this.id,
    required this.name,
    required this.birthDate,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final DateTime birthDate;
  final String? avatarUrl;

  factory StoryChildSnapshot.fromJson(Map<String, dynamic> json) {
    return StoryChildSnapshot(
      id: json['id'] as String,
      name: json['name'] as String,
      birthDate: DateTime.tryParse(json['birthDate'] as String? ?? '') ??
          DateTime(2018, 1, 1),
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}

class StoryCharacterModel {
  const StoryCharacterModel({
    required this.id,
    required this.name,
    this.role,
  });

  final String id;
  final String name;
  final String? role;

  factory StoryCharacterModel.fromJson(Map<String, dynamic> json) {
    return StoryCharacterModel(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      role: json['role'] as String?,
    );
  }
}

class StoryChoiceOption {
  const StoryChoiceOption({required this.id, required this.label});

  final String id;
  final String label;

  factory StoryChoiceOption.fromJson(Map<String, dynamic> json) {
    return StoryChoiceOption(
      id: (json['id'] as String?) ?? '',
      label: (json['label'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'label': label};
  }
}

class StoryStepModel {
  const StoryStepModel({
    required this.id,
    required this.stepIndex,
    required this.kind,
    required this.modeUsed,
    required this.localEventId,
    this.narratorPrompt,
    required this.childOptions,
    this.selectedOptionId,
    this.selectedOptionLabel,
    this.narratorText,
  });

  final String id;
  final int stepIndex;
  final StoryStepKind kind;
  final StoryMode modeUsed;
  final String localEventId;
  final String? narratorPrompt;
  final List<StoryChoiceOption> childOptions;
  final String? selectedOptionId;
  final String? selectedOptionLabel;
  final String? narratorText;

  factory StoryStepModel.fromJson(Map<String, dynamic> json) {
    final childOptionsRaw = json['childOptions'] as List<dynamic>?;

    return StoryStepModel(
      id: (json['id'] as String?) ?? '',
      stepIndex: (json['stepIndex'] as num?)?.toInt() ?? 0,
      kind: storyStepKindFromApi((json['kind'] as String?) ?? 'NARRATION'),
      modeUsed: storyModeFromApi((json['modeUsed'] as String?) ?? 'PARENT_NARRATOR'),
      localEventId: (json['localEventId'] as String?) ?? '',
      narratorPrompt: json['narratorPrompt'] as String?,
      childOptions: (childOptionsRaw ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(StoryChoiceOption.fromJson)
          .toList(),
      selectedOptionId: json['selectedOptionId'] as String?,
      selectedOptionLabel: json['selectedOptionLabel'] as String?,
      narratorText: json['narratorText'] as String?,
    );
  }

  StoryStepModel copyWith({
    String? id,
    int? stepIndex,
    StoryStepKind? kind,
    StoryMode? modeUsed,
    String? localEventId,
    String? narratorPrompt,
    List<StoryChoiceOption>? childOptions,
    String? selectedOptionId,
    String? selectedOptionLabel,
    String? narratorText,
  }) {
    return StoryStepModel(
      id: id ?? this.id,
      stepIndex: stepIndex ?? this.stepIndex,
      kind: kind ?? this.kind,
      modeUsed: modeUsed ?? this.modeUsed,
      localEventId: localEventId ?? this.localEventId,
      narratorPrompt: narratorPrompt ?? this.narratorPrompt,
      childOptions: childOptions ?? this.childOptions,
      selectedOptionId: selectedOptionId ?? this.selectedOptionId,
      selectedOptionLabel: selectedOptionLabel ?? this.selectedOptionLabel,
      narratorText: narratorText ?? this.narratorText,
    );
  }
}

class StorySessionModel {
  const StorySessionModel({
    required this.id,
    required this.childProfileId,
    required this.titleDraft,
    this.titleFinal,
    required this.title,
    required this.theme,
    required this.scenario,
    required this.objective,
    required this.status,
    required this.currentMode,
    required this.currentStepIndex,
    required this.ageSnapshotYears,
    required this.child,
    required this.characters,
    required this.steps,
  });

  final String id;
  final String childProfileId;
  final String titleDraft;
  final String? titleFinal;
  final String title;
  final String theme;
  final String scenario;
  final String objective;
  final StoryStatus status;
  final StoryMode currentMode;
  final int currentStepIndex;
  final int ageSnapshotYears;
  final StoryChildSnapshot child;
  final List<StoryCharacterModel> characters;
  final List<StoryStepModel> steps;

  factory StorySessionModel.fromJson(Map<String, dynamic> json) {
    return StorySessionModel(
      id: (json['id'] as String?) ?? '',
      childProfileId: (json['childProfileId'] as String?) ?? '',
      titleDraft: (json['titleDraft'] as String?) ?? '',
      titleFinal: json['titleFinal'] as String?,
      title: (json['title'] as String?) ?? (json['titleDraft'] as String?) ?? '',
      theme: (json['theme'] as String?) ?? '',
      scenario: (json['scenario'] as String?) ?? '',
      objective: (json['objective'] as String?) ?? '',
      status: storyStatusFromApi((json['status'] as String?) ?? 'DRAFT'),
      currentMode:
          storyModeFromApi((json['currentMode'] as String?) ?? 'PARENT_NARRATOR'),
      currentStepIndex: (json['currentStepIndex'] as num?)?.toInt() ?? 0,
      ageSnapshotYears: (json['ageSnapshotYears'] as num?)?.toInt() ?? 0,
      child: StoryChildSnapshot.fromJson(
        (json['child'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
      characters: ((json['characters'] as List<dynamic>?) ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(StoryCharacterModel.fromJson)
          .toList(),
      steps: ((json['steps'] as List<dynamic>?) ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(StoryStepModel.fromJson)
          .toList(),
    );
  }

  StorySessionModel copyWith({
    String? titleDraft,
    String? titleFinal,
    String? title,
    StoryStatus? status,
    StoryMode? currentMode,
    int? currentStepIndex,
    List<StoryCharacterModel>? characters,
    List<StoryStepModel>? steps,
  }) {
    return StorySessionModel(
      id: id,
      childProfileId: childProfileId,
      titleDraft: titleDraft ?? this.titleDraft,
      titleFinal: titleFinal ?? this.titleFinal,
      title: title ?? this.title,
      theme: theme,
      scenario: scenario,
      objective: objective,
      status: status ?? this.status,
      currentMode: currentMode ?? this.currentMode,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      ageSnapshotYears: ageSnapshotYears,
      child: child,
      characters: characters ?? this.characters,
      steps: steps ?? this.steps,
    );
  }
}

class StoryListItem {
  const StoryListItem({
    required this.id,
    required this.title,
    required this.status,
    required this.childName,
    required this.currentStepIndex,
    required this.stepsCount,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final StoryStatus status;
  final String childName;
  final int currentStepIndex;
  final int stepsCount;
  final DateTime updatedAt;

  factory StoryListItem.fromJson(Map<String, dynamic> json) {
    return StoryListItem(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      status: storyStatusFromApi((json['status'] as String?) ?? 'DRAFT'),
      childName: (json['childName'] as String?) ?? '-',
      currentStepIndex: (json['currentStepIndex'] as num?)?.toInt() ?? 0,
      stepsCount: (json['stepsCount'] as num?)?.toInt() ?? 0,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class StoryIdeasResult {
  const StoryIdeasResult({
    required this.ideas,
    required this.source,
    required this.safetyAdjusted,
  });

  final List<String> ideas;
  final String source;
  final bool safetyAdjusted;

  factory StoryIdeasResult.fromJson(Map<String, dynamic> json) {
    return StoryIdeasResult(
      ideas: ((json['ideas'] as List<dynamic>?) ?? <dynamic>[])
          .map((item) => item.toString())
          .toList(),
      source: (json['source'] as String?) ?? 'TEMPLATE',
      safetyAdjusted: (json['safetyAdjusted'] as bool?) ?? false,
    );
  }
}
