import 'story_enums.dart';

export 'story_enums.dart';

DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
  final raw = json[key];
  if (raw is! String || raw.trim().isEmpty) {
    throw FormatException('Data obrigatória ausente: $key');
  }
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    throw FormatException('Data inválida em $key: $raw');
  }
  return parsed;
}

class VirtueModel {
  const VirtueModel({
    required this.id,
    required this.slug,
    required this.name,
    required this.shortDescription,
    required this.iconKey,
    required this.sortOrder,
  });

  final String id;
  final String slug;
  final String name;
  final String shortDescription;
  final String iconKey;
  final int sortOrder;

  factory VirtueModel.fromJson(Map<String, dynamic> json) {
    return VirtueModel(
      id: (json['id'] as String?) ?? '',
      slug: (json['slug'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      shortDescription: (json['shortDescription'] as String?) ?? '',
      iconKey: (json['iconKey'] as String?) ?? '',
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
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
      birthDate: _requiredDateTime(json, 'birthDate'),
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}

class StoryCharacterModel {
  const StoryCharacterModel({required this.id, required this.name, this.role});

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

class StoryGameNodeModel {
  const StoryGameNodeModel({
    required this.index,
    required this.x,
    required this.y,
    required this.kind,
  });

  final int index;
  final double x;
  final double y;
  final String kind;

  factory StoryGameNodeModel.fromJson(Map<String, dynamic> json) {
    return StoryGameNodeModel(
      index: (json['index'] as num?)?.toInt() ?? 0,
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      kind: (json['kind'] as String?) ?? 'PATH',
    );
  }
}

class StoryGameMapModel {
  const StoryGameMapModel({
    required this.biome,
    required this.totalNodes,
    required this.nodes,
  });

  final String biome;
  final int totalNodes;
  final List<StoryGameNodeModel> nodes;

  factory StoryGameMapModel.fromJson(Map<String, dynamic> json) {
    return StoryGameMapModel(
      biome: (json['biome'] as String?) ?? 'FOREST',
      totalNodes: (json['totalNodes'] as num?)?.toInt() ?? 12,
      nodes: ((json['nodes'] as List<dynamic>?) ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(StoryGameNodeModel.fromJson)
          .toList(),
    );
  }
}

class StoryGameStateModel {
  const StoryGameStateModel({
    required this.mode,
    required this.seed,
    required this.mapVersion,
    required this.map,
  });

  final String mode;
  final int seed;
  final int mapVersion;
  final StoryGameMapModel map;

  factory StoryGameStateModel.fromJson(Map<String, dynamic> json) {
    return StoryGameStateModel(
      mode: (json['mode'] as String?) ?? 'TRAIL_LINEAR',
      seed: (json['seed'] as num?)?.toInt() ?? 0,
      mapVersion: (json['mapVersion'] as num?)?.toInt() ?? 1,
      map: StoryGameMapModel.fromJson(
        (json['map'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
    );
  }
}

class StoryGameSummaryModel {
  const StoryGameSummaryModel({
    required this.biome,
    required this.totalNodes,
    required this.currentNodeIndex,
    required this.completedNodes,
    required this.progressPercent,
    required this.lastNodeIndex,
  });

  final String biome;
  final int totalNodes;
  final int currentNodeIndex;
  final int completedNodes;
  final double progressPercent;
  final int lastNodeIndex;

  factory StoryGameSummaryModel.fromJson(Map<String, dynamic> json) {
    return StoryGameSummaryModel(
      biome: (json['biome'] as String?) ?? 'FOREST',
      totalNodes: (json['totalNodes'] as num?)?.toInt() ?? 12,
      currentNodeIndex: (json['currentNodeIndex'] as num?)?.toInt() ?? 1,
      completedNodes: (json['completedNodes'] as num?)?.toInt() ?? 0,
      progressPercent: (json['progressPercent'] as num?)?.toDouble() ?? 0.0,
      lastNodeIndex: (json['lastNodeIndex'] as num?)?.toInt() ?? 0,
    );
  }
}

class StoryGameActionModel {
  const StoryGameActionModel({
    required this.key,
    required this.label,
    this.iconKey,
  });

  final String key;
  final String label;
  final String? iconKey;
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
    this.gameNodeIndex,
    this.gameActionKey,
    this.gameActionLabel,
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
  final int? gameNodeIndex;
  final String? gameActionKey;
  final String? gameActionLabel;

  factory StoryStepModel.fromJson(Map<String, dynamic> json) {
    final childOptionsRaw = json['childOptions'] as List<dynamic>?;

    return StoryStepModel(
      id: (json['id'] as String?) ?? '',
      stepIndex: (json['stepIndex'] as num?)?.toInt() ?? 0,
      kind: storyStepKindFromApi((json['kind'] as String?) ?? 'NARRATION'),
      modeUsed: storyModeFromApi(
        (json['modeUsed'] as String?) ?? 'PARENT_NARRATOR',
      ),
      localEventId: (json['localEventId'] as String?) ?? '',
      narratorPrompt: json['narratorPrompt'] as String?,
      childOptions: (childOptionsRaw ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(StoryChoiceOption.fromJson)
          .toList(),
      selectedOptionId: json['selectedOptionId'] as String?,
      selectedOptionLabel: json['selectedOptionLabel'] as String?,
      narratorText: json['narratorText'] as String?,
      gameNodeIndex: (json['gameNodeIndex'] as num?)?.toInt(),
      gameActionKey: json['gameActionKey'] as String?,
      gameActionLabel: json['gameActionLabel'] as String?,
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
    int? gameNodeIndex,
    String? gameActionKey,
    String? gameActionLabel,
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
      gameNodeIndex: gameNodeIndex ?? this.gameNodeIndex,
      gameActionKey: gameActionKey ?? this.gameActionKey,
      gameActionLabel: gameActionLabel ?? this.gameActionLabel,
    );
  }
}

class ContentStoryTemplateModel {
  const ContentStoryTemplateModel({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    this.ageBand,
    required this.version,
    this.theme,
    this.virtue,
    required this.defaultScenario,
    required this.defaultObjective,
    required this.charactersCount,
    required this.nodesCount,
  });

  final String id;
  final String slug;
  final String title;
  final String description;
  final AgeBand? ageBand;
  final int version;
  final StoryNamedRef? theme;
  final StoryNamedRef? virtue;
  final String defaultScenario;
  final String defaultObjective;
  final int charactersCount;
  final int nodesCount;

  factory ContentStoryTemplateModel.fromJson(Map<String, dynamic> json) {
    return ContentStoryTemplateModel(
      id: (json['id'] as String?) ?? '',
      slug: (json['slug'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      ageBand: ageBandFromApi(json['ageBand'] as String?),
      version: (json['version'] as num?)?.toInt() ?? 1,
      theme: (json['theme'] as Map<String, dynamic>?) == null
          ? null
          : StoryNamedRef.fromJson(json['theme'] as Map<String, dynamic>),
      virtue: (json['virtue'] as Map<String, dynamic>?) == null
          ? null
          : StoryNamedRef.fromJson(json['virtue'] as Map<String, dynamic>),
      defaultScenario: (json['defaultScenario'] as String?) ?? '',
      defaultObjective: (json['defaultObjective'] as String?) ?? '',
      charactersCount: (json['charactersCount'] as num?)?.toInt() ?? 0,
      nodesCount: (json['nodesCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class StoryTemplatePrefillModel {
  const StoryTemplatePrefillModel({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    this.ageBand,
    required this.version,
    this.virtueId,
    required this.theme,
    required this.scenario,
    required this.objective,
    required this.characters,
    this.virtue,
    this.themeMeta,
  });

  final String id;
  final String slug;
  final String title;
  final String description;
  final AgeBand? ageBand;
  final int version;
  final String? virtueId;
  final String theme;
  final String scenario;
  final String objective;
  final List<Map<String, String?>> characters;
  final StoryNamedRef? virtue;
  final StoryNamedRef? themeMeta;

  factory StoryTemplatePrefillModel.fromJson(Map<String, dynamic> json) {
    return StoryTemplatePrefillModel(
      id: (json['id'] as String?) ?? '',
      slug: (json['slug'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      ageBand: ageBandFromApi(json['ageBand'] as String?),
      version: (json['version'] as num?)?.toInt() ?? 1,
      virtueId: json['virtueId'] as String?,
      theme: (json['theme'] as String?) ?? '',
      scenario: (json['scenario'] as String?) ?? '',
      objective: (json['objective'] as String?) ?? '',
      characters: ((json['characters'] as List<dynamic>?) ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(
            (item) => <String, String?>{
              'name': (item['name'] as String?) ?? '',
              'role': item['role'] as String?,
            },
          )
          .toList(),
      virtue: (json['virtue'] as Map<String, dynamic>?) == null
          ? null
          : StoryNamedRef.fromJson(json['virtue'] as Map<String, dynamic>),
      themeMeta: (json['themeMeta'] as Map<String, dynamic>?) == null
          ? null
          : StoryNamedRef.fromJson(json['themeMeta'] as Map<String, dynamic>),
    );
  }
}

class StoryNamedRef {
  const StoryNamedRef({
    required this.id,
    required this.slug,
    required this.name,
  });

  final String id;
  final String slug;
  final String name;

  factory StoryNamedRef.fromJson(Map<String, dynamic> json) {
    return StoryNamedRef(
      id: (json['id'] as String?) ?? '',
      slug: (json['slug'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
    );
  }
}

class StorySessionModel {
  const StorySessionModel({
    required this.id,
    required this.childProfileId,
    required this.collectionId,
    required this.episodeNumber,
    this.continuedFromStoryId,
    this.sourceTemplateId,
    this.artStyleId,
    required this.sessionKind,
    required this.titleDraft,
    this.titleFinal,
    required this.title,
    required this.theme,
    required this.scenario,
    required this.objective,
    this.ageBand,
    this.virtueSource,
    this.dilemmaText,
    this.endQuestionText,
    this.virtue,
    required this.status,
    required this.currentMode,
    required this.currentStepIndex,
    this.game,
    this.gameSummary,
    required this.ageSnapshotYears,
    required this.child,
    required this.characters,
    required this.steps,
  });

  final String id;
  final String childProfileId;
  final String collectionId;
  final int episodeNumber;
  final String? continuedFromStoryId;
  final String? sourceTemplateId;
  final String? artStyleId;
  final StorySessionKind sessionKind;
  final String titleDraft;
  final String? titleFinal;
  final String title;
  final String theme;
  final String scenario;
  final String objective;
  final AgeBand? ageBand;
  final VirtueSource? virtueSource;
  final String? dilemmaText;
  final String? endQuestionText;
  final VirtueModel? virtue;
  final StoryStatus status;
  final StoryMode currentMode;
  final int currentStepIndex;
  final StoryGameStateModel? game;
  final StoryGameSummaryModel? gameSummary;
  final int ageSnapshotYears;
  final StoryChildSnapshot child;
  final List<StoryCharacterModel> characters;
  final List<StoryStepModel> steps;

  factory StorySessionModel.fromJson(Map<String, dynamic> json) {
    return StorySessionModel(
      id: (json['id'] as String?) ?? '',
      childProfileId: (json['childProfileId'] as String?) ?? '',
      collectionId: (json['collectionId'] as String?) ?? '',
      episodeNumber: (json['episodeNumber'] as num?)?.toInt() ?? 1,
      continuedFromStoryId: json['continuedFromStoryId'] as String?,
      sourceTemplateId: json['sourceTemplateId'] as String?,
      artStyleId: json['artStyleId'] as String?,
      sessionKind: storySessionKindFromApi(json['sessionKind'] as String?),
      titleDraft: (json['titleDraft'] as String?) ?? '',
      titleFinal: json['titleFinal'] as String?,
      title:
          (json['title'] as String?) ?? (json['titleDraft'] as String?) ?? '',
      theme: (json['theme'] as String?) ?? '',
      scenario: (json['scenario'] as String?) ?? '',
      objective: (json['objective'] as String?) ?? '',
      ageBand: ageBandFromApi(json['ageBand'] as String?),
      virtueSource: virtueSourceFromApi(json['virtueSource'] as String?),
      dilemmaText: json['dilemmaText'] as String?,
      endQuestionText: json['endQuestionText'] as String?,
      virtue: (json['virtue'] as Map<String, dynamic>?) == null
          ? null
          : VirtueModel.fromJson(json['virtue'] as Map<String, dynamic>),
      status: storyStatusFromApi((json['status'] as String?) ?? 'DRAFT'),
      currentMode: storyModeFromApi(
        (json['currentMode'] as String?) ?? 'PARENT_NARRATOR',
      ),
      currentStepIndex: (json['currentStepIndex'] as num?)?.toInt() ?? 0,
      game: (json['game'] as Map<String, dynamic>?) == null
          ? null
          : StoryGameStateModel.fromJson(json['game'] as Map<String, dynamic>),
      gameSummary: (json['gameSummary'] as Map<String, dynamic>?) == null
          ? null
          : StoryGameSummaryModel.fromJson(
              json['gameSummary'] as Map<String, dynamic>,
            ),
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
    String? collectionId,
    int? episodeNumber,
    String? continuedFromStoryId,
    String? sourceTemplateId,
    String? artStyleId,
    String? titleDraft,
    String? titleFinal,
    String? title,
    AgeBand? ageBand,
    VirtueSource? virtueSource,
    String? dilemmaText,
    String? endQuestionText,
    VirtueModel? virtue,
    StoryStatus? status,
    StoryMode? currentMode,
    int? currentStepIndex,
    StoryGameStateModel? game,
    StoryGameSummaryModel? gameSummary,
    List<StoryCharacterModel>? characters,
    List<StoryStepModel>? steps,
  }) {
    return StorySessionModel(
      id: id,
      childProfileId: childProfileId,
      collectionId: collectionId ?? this.collectionId,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      continuedFromStoryId: continuedFromStoryId ?? this.continuedFromStoryId,
      sourceTemplateId: sourceTemplateId ?? this.sourceTemplateId,
      artStyleId: artStyleId ?? this.artStyleId,
      sessionKind: sessionKind,
      titleDraft: titleDraft ?? this.titleDraft,
      titleFinal: titleFinal ?? this.titleFinal,
      title: title ?? this.title,
      theme: theme,
      scenario: scenario,
      objective: objective,
      ageBand: ageBand ?? this.ageBand,
      virtueSource: virtueSource ?? this.virtueSource,
      dilemmaText: dilemmaText ?? this.dilemmaText,
      endQuestionText: endQuestionText ?? this.endQuestionText,
      virtue: virtue ?? this.virtue,
      status: status ?? this.status,
      currentMode: currentMode ?? this.currentMode,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      game: game ?? this.game,
      gameSummary: gameSummary ?? this.gameSummary,
      ageSnapshotYears: ageSnapshotYears,
      child: child,
      characters: characters ?? this.characters,
      steps: steps ?? this.steps,
    );
  }
}

class StoryPublishMetaModel {
  const StoryPublishMetaModel({
    required this.minimumRequiredSteps,
    required this.stepCountBeforePublish,
    required this.autoCompletedSteps,
    required this.finalStepCount,
  });

  final int minimumRequiredSteps;
  final int stepCountBeforePublish;
  final int autoCompletedSteps;
  final int finalStepCount;

  factory StoryPublishMetaModel.fromJson(Map<String, dynamic> json) {
    return StoryPublishMetaModel(
      minimumRequiredSteps:
          (json['minimumRequiredSteps'] as num?)?.toInt() ?? 3,
      stepCountBeforePublish:
          (json['stepCountBeforePublish'] as num?)?.toInt() ?? 0,
      autoCompletedSteps: (json['autoCompletedSteps'] as num?)?.toInt() ?? 0,
      finalStepCount: (json['finalStepCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class StoryListItem {
  const StoryListItem({
    required this.id,
    required this.collectionId,
    required this.episodeNumber,
    this.continuedFromStoryId,
    this.sourceTemplateId,
    required this.title,
    required this.status,
    required this.sessionKind,
    required this.childName,
    this.virtue,
    this.ageBand,
    this.dilemmaText,
    this.endQuestionText,
    required this.currentStepIndex,
    required this.stepsCount,
    required this.updatedAt,
  });

  final String id;
  final String collectionId;
  final int episodeNumber;
  final String? continuedFromStoryId;
  final String? sourceTemplateId;
  final String title;
  final StoryStatus status;
  final StorySessionKind sessionKind;
  final String childName;
  final VirtueModel? virtue;
  final AgeBand? ageBand;
  final String? dilemmaText;
  final String? endQuestionText;
  final int currentStepIndex;
  final int stepsCount;
  final DateTime updatedAt;

  factory StoryListItem.fromJson(Map<String, dynamic> json) {
    return StoryListItem(
      id: (json['id'] as String?) ?? '',
      collectionId: (json['collectionId'] as String?) ?? '',
      episodeNumber: (json['episodeNumber'] as num?)?.toInt() ?? 1,
      continuedFromStoryId: json['continuedFromStoryId'] as String?,
      sourceTemplateId: json['sourceTemplateId'] as String?,
      title: (json['title'] as String?) ?? '',
      status: storyStatusFromApi((json['status'] as String?) ?? 'DRAFT'),
      sessionKind: storySessionKindFromApi(json['sessionKind'] as String?),
      childName: (json['childName'] as String?) ?? '-',
      virtue: (json['virtue'] as Map<String, dynamic>?) == null
          ? null
          : VirtueModel.fromJson(json['virtue'] as Map<String, dynamic>),
      ageBand: ageBandFromApi(json['ageBand'] as String?),
      dilemmaText: json['dilemmaText'] as String?,
      endQuestionText: json['endQuestionText'] as String?,
      currentStepIndex: (json['currentStepIndex'] as num?)?.toInt() ?? 0,
      stepsCount: (json['stepsCount'] as num?)?.toInt() ?? 0,
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
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

class VirtueSuggestionResult {
  const VirtueSuggestionResult({
    required this.virtue,
    this.ageBand,
    required this.reason,
    required this.alternatives,
  });

  final VirtueModel virtue;
  final AgeBand? ageBand;
  final String reason;
  final List<VirtueModel> alternatives;

  factory VirtueSuggestionResult.fromJson(Map<String, dynamic> json) {
    return VirtueSuggestionResult(
      virtue: VirtueModel.fromJson(
        (json['virtue'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
      ageBand: ageBandFromApi(json['ageBand'] as String?),
      reason: (json['reason'] as String?) ?? '',
      alternatives: ((json['alternatives'] as List<dynamic>?) ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(VirtueModel.fromJson)
          .toList(),
    );
  }
}

class VirtueReportChildOverview {
  const VirtueReportChildOverview({
    required this.childId,
    required this.childName,
    this.avatarUrl,
    required this.publishedStories,
    required this.storiesWithVirtue,
    required this.storiesWithoutVirtue,
    required this.virtueStats,
  });

  final String childId;
  final String childName;
  final String? avatarUrl;
  final int publishedStories;
  final int storiesWithVirtue;
  final int storiesWithoutVirtue;
  final List<Map<String, dynamic>> virtueStats;

  factory VirtueReportChildOverview.fromJson(Map<String, dynamic> json) {
    final child =
        (json['child'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final totals =
        (json['totals'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    return VirtueReportChildOverview(
      childId: (child['id'] as String?) ?? '',
      childName: (child['name'] as String?) ?? '-',
      avatarUrl: child['avatarUrl'] as String?,
      publishedStories: (totals['publishedStories'] as num?)?.toInt() ?? 0,
      storiesWithVirtue: (totals['storiesWithVirtue'] as num?)?.toInt() ?? 0,
      storiesWithoutVirtue:
          (totals['storiesWithoutVirtue'] as num?)?.toInt() ?? 0,
      virtueStats: ((json['virtueStats'] as List<dynamic>?) ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .toList(),
    );
  }
}

class VirtueReportOverviewResult {
  const VirtueReportOverviewResult({
    required this.generatedAt,
    required this.totals,
    required this.children,
  });

  final DateTime generatedAt;
  final Map<String, dynamic> totals;
  final List<VirtueReportChildOverview> children;

  factory VirtueReportOverviewResult.fromJson(Map<String, dynamic> json) {
    return VirtueReportOverviewResult(
      generatedAt: _requiredDateTime(json, 'generatedAt'),
      totals: (json['totals'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      children: ((json['children'] as List<dynamic>?) ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(VirtueReportChildOverview.fromJson)
          .toList(),
    );
  }
}

class VirtueChildSummaryResult {
  const VirtueChildSummaryResult({
    required this.child,
    required this.totals,
    required this.virtueStats,
    required this.stories,
  });

  final StoryChildSnapshot child;
  final Map<String, dynamic> totals;
  final List<Map<String, dynamic>> virtueStats;
  final List<Map<String, dynamic>> stories;

  factory VirtueChildSummaryResult.fromJson(Map<String, dynamic> json) {
    return VirtueChildSummaryResult(
      child: StoryChildSnapshot.fromJson(
        (json['child'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
      totals: (json['totals'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      virtueStats: ((json['virtueStats'] as List<dynamic>?) ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .toList(),
      stories: ((json['stories'] as List<dynamic>?) ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .toList(),
    );
  }
}

class StoryVaultChild {
  const StoryVaultChild({required this.id, required this.name, this.avatarUrl});

  final String id;
  final String name;
  final String? avatarUrl;

  factory StoryVaultChild.fromJson(Map<String, dynamic> json) {
    return StoryVaultChild(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '-',
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}

class StoryVaultLatestEpisode {
  const StoryVaultLatestEpisode({
    required this.storyId,
    required this.episodeNumber,
    required this.title,
    required this.status,
    this.publishedAt,
    required this.updatedAt,
    required this.currentStepIndex,
  });

  final String storyId;
  final int episodeNumber;
  final String title;
  final StoryStatus status;
  final DateTime? publishedAt;
  final DateTime updatedAt;
  final int currentStepIndex;

  factory StoryVaultLatestEpisode.fromJson(Map<String, dynamic> json) {
    return StoryVaultLatestEpisode(
      storyId: (json['storyId'] as String?) ?? '',
      episodeNumber: (json['episodeNumber'] as num?)?.toInt() ?? 1,
      title: (json['title'] as String?) ?? '',
      status: storyStatusFromApi((json['status'] as String?) ?? 'DRAFT'),
      publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? ''),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      currentStepIndex: (json['currentStepIndex'] as num?)?.toInt() ?? 0,
    );
  }
}

class StoryVaultCollectionItem {
  const StoryVaultCollectionItem({
    required this.id,
    required this.title,
    required this.theme,
    this.virtue,
    required this.isFavorite,
    required this.child,
    required this.episodesCount,
    required this.publishedCount,
    required this.draftCount,
    required this.lastReferenceAt,
    this.latestEpisode,
  });

  final String id;
  final String title;
  final String theme;
  final VirtueModel? virtue;
  final bool isFavorite;
  final StoryVaultChild child;
  final int episodesCount;
  final int publishedCount;
  final int draftCount;
  final DateTime lastReferenceAt;
  final StoryVaultLatestEpisode? latestEpisode;

  factory StoryVaultCollectionItem.fromJson(Map<String, dynamic> json) {
    final latestEpisodeRaw = json['latestEpisode'] as Map<String, dynamic>?;

    return StoryVaultCollectionItem(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      theme: (json['theme'] as String?) ?? '',
      virtue: (json['virtue'] as Map<String, dynamic>?) == null
          ? null
          : VirtueModel.fromJson(json['virtue'] as Map<String, dynamic>),
      isFavorite: (json['isFavorite'] as bool?) ?? false,
      child: StoryVaultChild.fromJson(
        (json['child'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
      episodesCount: (json['episodesCount'] as num?)?.toInt() ?? 0,
      publishedCount: (json['publishedCount'] as num?)?.toInt() ?? 0,
      draftCount: (json['draftCount'] as num?)?.toInt() ?? 0,
      lastReferenceAt:
          DateTime.tryParse(json['lastReferenceAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      latestEpisode: latestEpisodeRaw == null
          ? null
          : StoryVaultLatestEpisode.fromJson(latestEpisodeRaw),
    );
  }
}

class StoryVaultEpisodeDetail {
  const StoryVaultEpisodeDetail({
    required this.storyId,
    required this.episodeNumber,
    required this.title,
    required this.titleDraft,
    this.titleFinal,
    required this.status,
    this.publishedAt,
    required this.updatedAt,
    required this.currentStepIndex,
    required this.scenario,
    required this.objective,
    required this.characters,
    required this.steps,
  });

  final String storyId;
  final int episodeNumber;
  final String title;
  final String titleDraft;
  final String? titleFinal;
  final StoryStatus status;
  final DateTime? publishedAt;
  final DateTime updatedAt;
  final int currentStepIndex;
  final String scenario;
  final String objective;
  final List<StoryCharacterModel> characters;
  final List<StoryStepModel> steps;

  factory StoryVaultEpisodeDetail.fromJson(Map<String, dynamic> json) {
    return StoryVaultEpisodeDetail(
      storyId: (json['storyId'] as String?) ?? '',
      episodeNumber: (json['episodeNumber'] as num?)?.toInt() ?? 1,
      title: (json['title'] as String?) ?? '',
      titleDraft: (json['titleDraft'] as String?) ?? '',
      titleFinal: json['titleFinal'] as String?,
      status: storyStatusFromApi((json['status'] as String?) ?? 'DRAFT'),
      publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? ''),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      currentStepIndex: (json['currentStepIndex'] as num?)?.toInt() ?? 0,
      scenario: (json['scenario'] as String?) ?? '',
      objective: (json['objective'] as String?) ?? '',
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
}

class StoryVaultCollectionDetail {
  const StoryVaultCollectionDetail({
    required this.id,
    required this.title,
    required this.theme,
    this.virtue,
    required this.isFavorite,
    this.templateFromStoryId,
    required this.lastReferenceAt,
    required this.createdAt,
    required this.updatedAt,
    required this.child,
    required this.episodes,
  });

  final String id;
  final String title;
  final String theme;
  final VirtueModel? virtue;
  final bool isFavorite;
  final String? templateFromStoryId;
  final DateTime lastReferenceAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final StoryVaultChild child;
  final List<StoryVaultEpisodeDetail> episodes;

  factory StoryVaultCollectionDetail.fromJson(Map<String, dynamic> json) {
    final collection =
        (json['collection'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return StoryVaultCollectionDetail(
      id: (collection['id'] as String?) ?? '',
      title: (collection['title'] as String?) ?? '',
      theme: (collection['theme'] as String?) ?? '',
      virtue: (collection['virtue'] as Map<String, dynamic>?) == null
          ? null
          : VirtueModel.fromJson(collection['virtue'] as Map<String, dynamic>),
      isFavorite: (collection['isFavorite'] as bool?) ?? false,
      templateFromStoryId: collection['templateFromStoryId'] as String?,
      lastReferenceAt:
          DateTime.tryParse(collection['lastReferenceAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      createdAt:
          DateTime.tryParse(collection['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          DateTime.tryParse(collection['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      child: StoryVaultChild.fromJson(
        (collection['child'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
      episodes: ((json['episodes'] as List<dynamic>?) ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(StoryVaultEpisodeDetail.fromJson)
          .toList(),
    );
  }
}
