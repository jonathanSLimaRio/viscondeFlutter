enum StoryMode { parentNarrator, childChooser }

enum StoryStatus { draft, published, archived }

enum StoryStepKind { narration, childChoice, system }

enum StorySessionKind { presencial, remote }

enum AgeBand { age4_5, age6_8, age9_10 }

enum VirtueSource { manual, auto }

enum RemoteRoomStatus { open, active, closed, expired }

enum RemoteParticipantRole { hostParent, guestChild }

enum RemoteCallMode { none, audio, video }

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

StorySessionKind storySessionKindFromApi(String? value) {
  switch (value) {
    case 'REMOTE':
      return StorySessionKind.remote;
    case 'PRESENTIAL':
    default:
      return StorySessionKind.presencial;
  }
}

RemoteRoomStatus remoteRoomStatusFromApi(String? value) {
  switch (value) {
    case 'ACTIVE':
      return RemoteRoomStatus.active;
    case 'CLOSED':
      return RemoteRoomStatus.closed;
    case 'EXPIRED':
      return RemoteRoomStatus.expired;
    case 'OPEN':
    default:
      return RemoteRoomStatus.open;
  }
}

RemoteParticipantRole remoteParticipantRoleFromApi(String? value) {
  switch (value) {
    case 'GUEST_CHILD':
      return RemoteParticipantRole.guestChild;
    case 'HOST_PARENT':
    default:
      return RemoteParticipantRole.hostParent;
  }
}

RemoteCallMode remoteCallModeFromApi(String? value) {
  switch (value) {
    case 'NONE':
      return RemoteCallMode.none;
    case 'VIDEO':
      return RemoteCallMode.video;
    case 'AUDIO':
    default:
      return RemoteCallMode.audio;
  }
}

String remoteCallModeToApi(RemoteCallMode value) {
  switch (value) {
    case RemoteCallMode.none:
      return 'NONE';
    case RemoteCallMode.video:
      return 'VIDEO';
    case RemoteCallMode.audio:
      return 'AUDIO';
  }
}

AgeBand? ageBandFromApi(String? value) {
  switch (value) {
    case 'AGE_4_5':
      return AgeBand.age4_5;
    case 'AGE_6_8':
      return AgeBand.age6_8;
    case 'AGE_9_10':
      return AgeBand.age9_10;
    default:
      return null;
  }
}

String ageBandLabel(AgeBand? ageBand) {
  switch (ageBand) {
    case AgeBand.age4_5:
      return '4-5';
    case AgeBand.age6_8:
      return '6-8';
    case AgeBand.age9_10:
      return '9-10';
    case null:
      return '-';
  }
}

VirtueSource? virtueSourceFromApi(String? value) {
  switch (value) {
    case 'MANUAL':
      return VirtueSource.manual;
    case 'AUTO':
      return VirtueSource.auto;
    default:
      return null;
  }
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
      birthDate:
          DateTime.tryParse(json['birthDate'] as String? ?? '') ??
          DateTime(2018, 1, 1),
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

class RemoteParticipantModel {
  const RemoteParticipantModel({
    required this.id,
    required this.role,
    required this.displayName,
    required this.status,
    required this.lastSeenAt,
    required this.joinedAt,
    this.leftAt,
  });

  final String id;
  final RemoteParticipantRole role;
  final String displayName;
  final String status;
  final DateTime lastSeenAt;
  final DateTime joinedAt;
  final DateTime? leftAt;

  factory RemoteParticipantModel.fromJson(Map<String, dynamic> json) {
    return RemoteParticipantModel(
      id: (json['id'] as String?) ?? '',
      role: remoteParticipantRoleFromApi(json['role'] as String?),
      displayName: (json['displayName'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'CONNECTED',
      lastSeenAt:
          DateTime.tryParse(json['lastSeenAt'] as String? ?? '') ??
          DateTime.now(),
      joinedAt:
          DateTime.tryParse(json['joinedAt'] as String? ?? '') ??
          DateTime.now(),
      leftAt: DateTime.tryParse(json['leftAt'] as String? ?? ''),
    );
  }
}

class RemoteRoomModel {
  const RemoteRoomModel({
    required this.id,
    required this.status,
    required this.callMode,
    required this.maxParticipants,
    required this.isOpen,
    required this.joinCodeExpiresAt,
    this.joinCodeConsumedAt,
    this.closedAt,
    required this.participants,
  });

  final String id;
  final RemoteRoomStatus status;
  final RemoteCallMode callMode;
  final int maxParticipants;
  final bool isOpen;
  final DateTime joinCodeExpiresAt;
  final DateTime? joinCodeConsumedAt;
  final DateTime? closedAt;
  final List<RemoteParticipantModel> participants;

  factory RemoteRoomModel.fromJson(Map<String, dynamic> json) {
    return RemoteRoomModel(
      id: (json['id'] as String?) ?? '',
      status: remoteRoomStatusFromApi(json['status'] as String?),
      callMode: remoteCallModeFromApi(json['callMode'] as String?),
      maxParticipants: (json['maxParticipants'] as num?)?.toInt() ?? 2,
      isOpen: (json['isOpen'] as bool?) ?? true,
      joinCodeExpiresAt:
          DateTime.tryParse(json['joinCodeExpiresAt'] as String? ?? '') ??
          DateTime.now(),
      joinCodeConsumedAt: DateTime.tryParse(
        json['joinCodeConsumedAt'] as String? ?? '',
      ),
      closedAt: DateTime.tryParse(json['closedAt'] as String? ?? ''),
      participants: ((json['participants'] as List<dynamic>?) ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(RemoteParticipantModel.fromJson)
          .toList(),
    );
  }

  RemoteRoomModel copyWith({
    RemoteRoomStatus? status,
    RemoteCallMode? callMode,
    bool? isOpen,
    List<RemoteParticipantModel>? participants,
  }) {
    return RemoteRoomModel(
      id: id,
      status: status ?? this.status,
      callMode: callMode ?? this.callMode,
      maxParticipants: maxParticipants,
      isOpen: isOpen ?? this.isOpen,
      joinCodeExpiresAt: joinCodeExpiresAt,
      joinCodeConsumedAt: joinCodeConsumedAt,
      closedAt: closedAt,
      participants: participants ?? this.participants,
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
    required this.ageSnapshotYears,
    this.remote,
    required this.child,
    required this.characters,
    required this.steps,
  });

  final String id;
  final String childProfileId;
  final String collectionId;
  final int episodeNumber;
  final String? continuedFromStoryId;
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
  final int ageSnapshotYears;
  final RemoteRoomModel? remote;
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
      ageSnapshotYears: (json['ageSnapshotYears'] as num?)?.toInt() ?? 0,
      remote: (json['remote'] as Map<String, dynamic>?) == null
          ? null
          : RemoteRoomModel.fromJson(json['remote'] as Map<String, dynamic>),
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
    RemoteRoomModel? remote,
    List<StoryCharacterModel>? characters,
    List<StoryStepModel>? steps,
  }) {
    return StorySessionModel(
      id: id,
      childProfileId: childProfileId,
      collectionId: collectionId ?? this.collectionId,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      continuedFromStoryId: continuedFromStoryId ?? this.continuedFromStoryId,
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
      ageSnapshotYears: ageSnapshotYears,
      remote: remote ?? this.remote,
      child: child,
      characters: characters ?? this.characters,
      steps: steps ?? this.steps,
    );
  }
}

class StoryListItem {
  const StoryListItem({
    required this.id,
    required this.collectionId,
    required this.episodeNumber,
    this.continuedFromStoryId,
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
    this.remote,
  });

  final String id;
  final String collectionId;
  final int episodeNumber;
  final String? continuedFromStoryId;
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
  final RemoteRoomModel? remote;

  factory StoryListItem.fromJson(Map<String, dynamic> json) {
    return StoryListItem(
      id: (json['id'] as String?) ?? '',
      collectionId: (json['collectionId'] as String?) ?? '',
      episodeNumber: (json['episodeNumber'] as num?)?.toInt() ?? 1,
      continuedFromStoryId: json['continuedFromStoryId'] as String?,
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
      remote: (json['remote'] as Map<String, dynamic>?) == null
          ? null
          : RemoteRoomModel.fromJson(json['remote'] as Map<String, dynamic>),
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
      generatedAt:
          DateTime.tryParse(json['generatedAt'] as String? ?? '') ??
          DateTime.now(),
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

class RemoteOpenResult {
  const RemoteOpenResult({
    required this.joinCode,
    required this.joinLink,
    required this.participantToken,
    required this.signalingWsUrl,
    required this.rtcConfig,
    required this.expiresAt,
    required this.remoteRoom,
  });

  final String joinCode;
  final String joinLink;
  final String participantToken;
  final String signalingWsUrl;
  final Map<String, dynamic> rtcConfig;
  final DateTime expiresAt;
  final RemoteRoomModel remoteRoom;

  factory RemoteOpenResult.fromJson(Map<String, dynamic> json) {
    return RemoteOpenResult(
      joinCode: (json['joinCode'] as String?) ?? '',
      joinLink: (json['joinLink'] as String?) ?? '',
      participantToken: (json['hostParticipantToken'] as String?) ?? '',
      signalingWsUrl: (json['signalingWsUrl'] as String?) ?? '',
      rtcConfig:
          (json['rtcConfig'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      expiresAt:
          DateTime.tryParse(json['expiresAt'] as String? ?? '') ??
          DateTime.now(),
      remoteRoom: RemoteRoomModel.fromJson(
        (json['remoteRoom'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
    );
  }
}

class RemoteRoomStateResult {
  const RemoteRoomStateResult({
    required this.remoteRoom,
    required this.storySnapshot,
    required this.participantToken,
    required this.signalingWsUrl,
    required this.rtcConfig,
  });

  final RemoteRoomModel remoteRoom;
  final StorySessionModel storySnapshot;
  final String participantToken;
  final String signalingWsUrl;
  final Map<String, dynamic> rtcConfig;

  factory RemoteRoomStateResult.fromJson(Map<String, dynamic> json) {
    return RemoteRoomStateResult(
      remoteRoom: RemoteRoomModel.fromJson(
        (json['remoteRoom'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
      storySnapshot: StorySessionModel.fromJson(
        (json['storySnapshot'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
      participantToken: (json['hostParticipantToken'] as String?) ?? '',
      signalingWsUrl: (json['signalingWsUrl'] as String?) ?? '',
      rtcConfig:
          (json['rtcConfig'] as Map<String, dynamic>?) ?? <String, dynamic>{},
    );
  }
}

class RemoteJoinResult {
  const RemoteJoinResult({
    required this.participantToken,
    required this.remoteRoom,
    required this.storySnapshot,
    required this.signalingWsUrl,
    required this.rtcConfig,
  });

  final String participantToken;
  final RemoteRoomModel remoteRoom;
  final StorySessionModel storySnapshot;
  final String signalingWsUrl;
  final Map<String, dynamic> rtcConfig;

  factory RemoteJoinResult.fromJson(Map<String, dynamic> json) {
    return RemoteJoinResult(
      participantToken: (json['guestParticipantToken'] as String?) ?? '',
      remoteRoom: RemoteRoomModel.fromJson(
        (json['remoteRoom'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
      storySnapshot: StorySessionModel.fromJson(
        (json['storySnapshot'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
      signalingWsUrl: (json['signalingWsUrl'] as String?) ?? '',
      rtcConfig:
          (json['rtcConfig'] as Map<String, dynamic>?) ?? <String, dynamic>{},
    );
  }
}

class RemoteJoinBundle {
  const RemoteJoinBundle({
    required this.participantToken,
    required this.remoteRoom,
    required this.storySnapshot,
    required this.signalingWsUrl,
    required this.rtcConfig,
    required this.isGuest,
    this.joinCode,
    this.joinLink,
  });

  final String participantToken;
  final RemoteRoomModel remoteRoom;
  final StorySessionModel storySnapshot;
  final String signalingWsUrl;
  final Map<String, dynamic> rtcConfig;
  final bool isGuest;
  final String? joinCode;
  final String? joinLink;
}

class StoryInteractionModel {
  const StoryInteractionModel({
    required this.id,
    required this.type,
    required this.authorRole,
    required this.authorDisplayName,
    this.messageText,
    this.emoji,
    required this.createdAt,
  });

  final String id;
  final String type;
  final RemoteParticipantRole authorRole;
  final String authorDisplayName;
  final String? messageText;
  final String? emoji;
  final DateTime createdAt;

  factory StoryInteractionModel.fromJson(Map<String, dynamic> json) {
    return StoryInteractionModel(
      id: (json['id'] as String?) ?? '',
      type: (json['type'] as String?) ?? 'CHAT',
      authorRole: remoteParticipantRoleFromApi(json['authorRole'] as String?),
      authorDisplayName: (json['authorDisplayName'] as String?) ?? '-',
      messageText: json['messageText'] as String?,
      emoji: json['emoji'] as String?,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class StoryInteractionsResult {
  const StoryInteractionsResult({
    required this.storyId,
    required this.storyTitle,
    required this.remoteRoomId,
    required this.interactions,
  });

  final String storyId;
  final String storyTitle;
  final String? remoteRoomId;
  final List<StoryInteractionModel> interactions;

  factory StoryInteractionsResult.fromJson(Map<String, dynamic> json) {
    final story =
        (json['story'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return StoryInteractionsResult(
      storyId: (story['id'] as String?) ?? '',
      storyTitle: (story['title'] as String?) ?? '',
      remoteRoomId: story['remoteRoomId'] as String?,
      interactions: ((json['interactions'] as List<dynamic>?) ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(StoryInteractionModel.fromJson)
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
    final collection = (json['collection'] as Map<String, dynamic>?) ?? <String, dynamic>{};
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
