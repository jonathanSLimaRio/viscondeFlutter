import 'admin_enums.dart';

export 'admin_enums.dart';

class AdminRefModel {
  const AdminRefModel({
    required this.id,
    required this.slug,
    required this.name,
  });

  final String id;
  final String slug;
  final String name;

  factory AdminRefModel.fromJson(Map<String, dynamic> json) {
    return AdminRefModel(
      id: (json['id'] as String?) ?? '',
      slug: (json['slug'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
    );
  }
}

class AdminThemeModel {
  const AdminThemeModel({
    required this.id,
    required this.slug,
    required this.name,
    required this.shortDescription,
    required this.iconKey,
    required this.sortOrder,
    required this.isActive,
  });

  final String id;
  final String slug;
  final String name;
  final String shortDescription;
  final String iconKey;
  final int sortOrder;
  final bool isActive;

  factory AdminThemeModel.fromJson(Map<String, dynamic> json) {
    return AdminThemeModel(
      id: (json['id'] as String?) ?? '',
      slug: (json['slug'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      shortDescription: (json['shortDescription'] as String?) ?? '',
      iconKey: (json['iconKey'] as String?) ?? '',
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: (json['isActive'] as bool?) ?? true,
    );
  }
}

class AdminVirtueModel {
  const AdminVirtueModel({
    required this.id,
    required this.slug,
    required this.name,
    required this.shortDescription,
    required this.iconKey,
    required this.sortOrder,
    required this.isActive,
  });

  final String id;
  final String slug;
  final String name;
  final String shortDescription;
  final String iconKey;
  final int sortOrder;
  final bool isActive;

  factory AdminVirtueModel.fromJson(Map<String, dynamic> json) {
    return AdminVirtueModel(
      id: (json['id'] as String?) ?? '',
      slug: (json['slug'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      shortDescription: (json['shortDescription'] as String?) ?? '',
      iconKey: (json['iconKey'] as String?) ?? '',
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: (json['isActive'] as bool?) ?? true,
    );
  }
}

class AdminVirtueTemplateModel {
  const AdminVirtueTemplateModel({
    required this.id,
    required this.virtueId,
    required this.ageBand,
    required this.dilemmaText,
    required this.endQuestionText,
    required this.sortOrder,
    required this.isActive,
  });

  final String id;
  final String virtueId;
  final String ageBand;
  final String dilemmaText;
  final String endQuestionText;
  final int sortOrder;
  final bool isActive;

  factory AdminVirtueTemplateModel.fromJson(Map<String, dynamic> json) {
    return AdminVirtueTemplateModel(
      id: (json['id'] as String?) ?? '',
      virtueId: (json['virtueId'] as String?) ?? '',
      ageBand: (json['ageBand'] as String?) ?? 'AGE_6_8',
      dilemmaText: (json['dilemmaText'] as String?) ?? '',
      endQuestionText: (json['endQuestionText'] as String?) ?? '',
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: (json['isActive'] as bool?) ?? true,
    );
  }
}

class AdminPromptModel {
  const AdminPromptModel({
    required this.id,
    required this.key,
    required this.kind,
    required this.title,
    required this.text,
    this.ageBand,
    this.mode,
    this.theme,
    this.virtue,
    required this.sortOrder,
    required this.isActive,
  });

  final String id;
  final String key;
  final AdminPromptKind kind;
  final String title;
  final String text;
  final String? ageBand;
  final String? mode;
  final AdminRefModel? theme;
  final AdminRefModel? virtue;
  final int sortOrder;
  final bool isActive;

  factory AdminPromptModel.fromJson(Map<String, dynamic> json) {
    return AdminPromptModel(
      id: (json['id'] as String?) ?? '',
      key: (json['key'] as String?) ?? '',
      kind: adminPromptKindFromApi(json['kind'] as String?),
      title: (json['title'] as String?) ?? '',
      text: (json['text'] as String?) ?? '',
      ageBand: json['ageBand'] as String?,
      mode: json['mode'] as String?,
      theme: (json['theme'] as Map<String, dynamic>?) == null
          ? null
          : AdminRefModel.fromJson(json['theme'] as Map<String, dynamic>),
      virtue: (json['virtue'] as Map<String, dynamic>?) == null
          ? null
          : AdminRefModel.fromJson(json['virtue'] as Map<String, dynamic>),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: (json['isActive'] as bool?) ?? true,
    );
  }
}

class AdminStoryTemplateListItem {
  const AdminStoryTemplateListItem({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    this.ageBand,
    this.updatedAt,
    this.publishedAt,
    this.theme,
    this.virtue,
    required this.isActive,
    required this.isPublished,
    required this.version,
    required this.nodesCount,
    required this.charactersCount,
  });

  final String id;
  final String slug;
  final String title;
  final String description;
  final String? ageBand;
  final DateTime? updatedAt;
  final DateTime? publishedAt;
  final AdminRefModel? theme;
  final AdminRefModel? virtue;
  final bool isActive;
  final bool isPublished;
  final int version;
  final int nodesCount;
  final int charactersCount;

  factory AdminStoryTemplateListItem.fromJson(Map<String, dynamic> json) {
    return AdminStoryTemplateListItem(
      id: (json['id'] as String?) ?? '',
      slug: (json['slug'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      ageBand: json['ageBand'] as String?,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? ''),
      theme: (json['theme'] as Map<String, dynamic>?) == null
          ? null
          : AdminRefModel.fromJson(json['theme'] as Map<String, dynamic>),
      virtue: (json['virtue'] as Map<String, dynamic>?) == null
          ? null
          : AdminRefModel.fromJson(json['virtue'] as Map<String, dynamic>),
      isActive: (json['isActive'] as bool?) ?? true,
      isPublished: (json['isPublished'] as bool?) ?? false,
      version: (json['version'] as num?)?.toInt() ?? 1,
      nodesCount: (json['nodesCount'] as num?)?.toInt() ?? 0,
      charactersCount: (json['charactersCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminStoryTemplateOptionModel {
  const AdminStoryTemplateOptionModel({
    required this.id,
    required this.optionKey,
    required this.label,
    required this.nextNodeId,
    required this.sortOrder,
  });

  final String id;
  final String optionKey;
  final String label;
  final String nextNodeId;
  final int sortOrder;

  factory AdminStoryTemplateOptionModel.fromJson(Map<String, dynamic> json) {
    return AdminStoryTemplateOptionModel(
      id: (json['id'] as String?) ?? '',
      optionKey: (json['optionKey'] as String?) ?? '',
      label: (json['label'] as String?) ?? '',
      nextNodeId: (json['nextNodeId'] as String?) ?? '',
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminStoryTemplateNodeModel {
  const AdminStoryTemplateNodeModel({
    required this.id,
    required this.nodeKey,
    required this.kind,
    required this.title,
    this.narratorText,
    this.promptHint,
    required this.sortOrder,
    required this.options,
  });

  final String id;
  final String nodeKey;
  final AdminStoryTemplateNodeKind kind;
  final String title;
  final String? narratorText;
  final String? promptHint;
  final int sortOrder;
  final List<AdminStoryTemplateOptionModel> options;

  factory AdminStoryTemplateNodeModel.fromJson(Map<String, dynamic> json) {
    return AdminStoryTemplateNodeModel(
      id: (json['id'] as String?) ?? '',
      nodeKey: (json['nodeKey'] as String?) ?? '',
      kind: adminStoryTemplateNodeKindFromApi(json['kind'] as String?),
      title: (json['title'] as String?) ?? '',
      narratorText: json['narratorText'] as String?,
      promptHint: json['promptHint'] as String?,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      options: ((json['options'] as List<dynamic>?) ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(AdminStoryTemplateOptionModel.fromJson)
          .toList(),
    );
  }
}

class AdminStoryTemplateCharacterModel {
  const AdminStoryTemplateCharacterModel({
    required this.id,
    required this.name,
    this.role,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final String? role;
  final int sortOrder;

  factory AdminStoryTemplateCharacterModel.fromJson(Map<String, dynamic> json) {
    return AdminStoryTemplateCharacterModel(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      role: json['role'] as String?,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminStoryTemplateDetail {
  const AdminStoryTemplateDetail({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    this.ageBand,
    required this.defaultScenario,
    required this.defaultObjective,
    this.theme,
    this.virtue,
    required this.isActive,
    required this.isPublished,
    required this.version,
    required this.characters,
    required this.nodes,
  });

  final String id;
  final String slug;
  final String title;
  final String description;
  final String? ageBand;
  final String defaultScenario;
  final String defaultObjective;
  final AdminRefModel? theme;
  final AdminRefModel? virtue;
  final bool isActive;
  final bool isPublished;
  final int version;
  final List<AdminStoryTemplateCharacterModel> characters;
  final List<AdminStoryTemplateNodeModel> nodes;

  factory AdminStoryTemplateDetail.fromJson(Map<String, dynamic> json) {
    return AdminStoryTemplateDetail(
      id: (json['id'] as String?) ?? '',
      slug: (json['slug'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      ageBand: json['ageBand'] as String?,
      defaultScenario: (json['defaultScenario'] as String?) ?? '',
      defaultObjective: (json['defaultObjective'] as String?) ?? '',
      theme: (json['theme'] as Map<String, dynamic>?) == null
          ? null
          : AdminRefModel.fromJson(json['theme'] as Map<String, dynamic>),
      virtue: (json['virtue'] as Map<String, dynamic>?) == null
          ? null
          : AdminRefModel.fromJson(json['virtue'] as Map<String, dynamic>),
      isActive: (json['isActive'] as bool?) ?? true,
      isPublished: (json['isPublished'] as bool?) ?? false,
      version: (json['version'] as num?)?.toInt() ?? 1,
      characters: ((json['characters'] as List<dynamic>?) ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(AdminStoryTemplateCharacterModel.fromJson)
          .toList(),
      nodes: ((json['nodes'] as List<dynamic>?) ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(AdminStoryTemplateNodeModel.fromJson)
          .toList(),
    );
  }
}

class AdminTemplateValidationIssue {
  const AdminTemplateValidationIssue({
    required this.code,
    required this.message,
    this.nodeId,
  });

  final String code;
  final String message;
  final String? nodeId;

  factory AdminTemplateValidationIssue.fromJson(Map<String, dynamic> json) {
    return AdminTemplateValidationIssue(
      code: (json['code'] as String?) ?? '',
      message: (json['message'] as String?) ?? '',
      nodeId: json['nodeId'] as String?,
    );
  }
}

class AdminTemplateValidationResult {
  const AdminTemplateValidationResult({
    required this.valid,
    required this.issues,
  });

  final bool valid;
  final List<AdminTemplateValidationIssue> issues;

  factory AdminTemplateValidationResult.fromJson(Map<String, dynamic> json) {
    return AdminTemplateValidationResult(
      valid: (json['valid'] as bool?) ?? false,
      issues: ((json['issues'] as List<dynamic>?) ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(AdminTemplateValidationIssue.fromJson)
          .toList(),
    );
  }
}

class AdminModerationTermModel {
  const AdminModerationTermModel({
    required this.id,
    required this.termNormalized,
    required this.displayTerm,
    required this.policy,
    required this.scope,
    required this.isActive,
    this.replacement,
  });

  final String id;
  final String termNormalized;
  final String displayTerm;
  final AdminModerationPolicy policy;
  final AdminModerationScope scope;
  final bool isActive;
  final String? replacement;

  factory AdminModerationTermModel.fromJson(Map<String, dynamic> json) {
    return AdminModerationTermModel(
      id: (json['id'] as String?) ?? '',
      termNormalized: (json['termNormalized'] as String?) ?? '',
      displayTerm: (json['displayTerm'] as String?) ?? '',
      policy: adminModerationPolicyFromApi(json['policy'] as String?),
      scope: adminModerationScopeFromApi(json['scope'] as String?),
      isActive: (json['isActive'] as bool?) ?? true,
      replacement: json['replacement'] as String?,
    );
  }
}
