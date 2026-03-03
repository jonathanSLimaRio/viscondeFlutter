import '../../core/models/child_profile.dart';
import '../story_room/models/story_models.dart';

const _fallbackTheme = 'Aventura';
const _fallbackScenario = 'Bosque encantado';
const _fallbackObjective = 'Aprender algo novo com coragem e gentileza.';
const _defaultGuideName = 'Visconde';

class QuickStoryDefaults {
  const QuickStoryDefaults({
    required this.child,
    required this.ageBand,
    required this.titleDraft,
    required this.theme,
    required this.scenario,
    required this.objective,
    required this.characters,
    this.virtueId,
    this.sourceTemplateId,
  });

  final ChildProfile child;
  final AgeBand ageBand;
  final String titleDraft;
  final String theme;
  final String scenario;
  final String objective;
  final List<Map<String, String?>> characters;
  final String? virtueId;
  final String? sourceTemplateId;
}

AgeBand resolveQuickStoryAgeBand(
  DateTime birthDate, {
  DateTime? referenceDate,
}) {
  final now = referenceDate ?? DateTime.now();
  var years = now.year - birthDate.year;
  final birthdayPending =
      now.month < birthDate.month ||
      (now.month == birthDate.month && now.day < birthDate.day);
  if (birthdayPending) {
    years -= 1;
  }

  if (years <= 5) {
    return AgeBand.age4_5;
  }
  if (years <= 8) {
    return AgeBand.age6_8;
  }
  return AgeBand.age9_10;
}

ChildProfile? selectQuickStoryChild({
  required List<ChildProfile> children,
  required List<StoryVaultCollectionItem> collections,
  String? selectedChildId,
}) {
  if (children.isEmpty) {
    return null;
  }

  if (selectedChildId != null && selectedChildId.trim().isNotEmpty) {
    for (final child in children) {
      if (child.id == selectedChildId) {
        return child;
      }
    }
  }

  for (final collection in collections) {
    for (final child in children) {
      if (child.id == collection.child.id) {
        return child;
      }
    }
  }

  return children.first;
}

ContentStoryTemplateModel? selectQuickStoryTemplate({
  required List<ContentStoryTemplateModel> templates,
  required AgeBand ageBand,
}) {
  for (final template in templates) {
    if (template.ageBand == ageBand) {
      return template;
    }
  }
  for (final template in templates) {
    if (template.ageBand == null) {
      return template;
    }
  }
  if (templates.isEmpty) {
    return null;
  }
  return templates.first;
}

QuickStoryDefaults? buildQuickStoryDefaults({
  required List<ChildProfile> children,
  required List<StoryVaultCollectionItem> collections,
  required List<ContentStoryTemplateModel> templates,
  String? selectedChildId,
  String? suggestedVirtueId,
  DateTime? referenceDate,
}) {
  final child = selectQuickStoryChild(
    children: children,
    collections: collections,
    selectedChildId: selectedChildId,
  );
  if (child == null) {
    return null;
  }

  final ageBand = resolveQuickStoryAgeBand(
    child.birthDate,
    referenceDate: referenceDate,
  );
  final template = selectQuickStoryTemplate(
    templates: templates,
    ageBand: ageBand,
  );

  StoryVaultCollectionItem? recentCollection;
  for (final collection in collections) {
    if (collection.child.id == child.id) {
      recentCollection = collection;
      break;
    }
  }

  final theme = _firstNonBlank(<String?>[
    recentCollection?.theme,
    template?.theme?.name,
    child.favoriteThemes.isNotEmpty ? child.favoriteThemes.first : null,
  ], fallback: _fallbackTheme);
  final scenario = _firstNonBlank(<String?>[
    template?.defaultScenario,
  ], fallback: _fallbackScenario);
  final objective = _firstNonBlank(<String?>[
    template?.defaultObjective,
  ], fallback: _fallbackObjective);
  final virtueId = _firstNonBlankOrNull(<String?>[
    recentCollection?.virtue?.id,
    template?.virtue?.id,
    suggestedVirtueId,
  ]);

  return QuickStoryDefaults(
    child: child,
    ageBand: ageBand,
    titleDraft: 'Aventura de ${child.name}',
    theme: theme,
    scenario: scenario,
    objective: objective,
    characters: <Map<String, String?>>[
      <String, String?>{'name': child.name, 'role': 'protagonista'},
      <String, String?>{'name': _defaultGuideName, 'role': 'guia'},
    ],
    virtueId: virtueId,
    sourceTemplateId: template?.id,
  );
}

String _firstNonBlank(Iterable<String?> values, {required String fallback}) {
  for (final value in values) {
    final normalized = value?.trim() ?? '';
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }
  return fallback;
}

String? _firstNonBlankOrNull(Iterable<String?> values) {
  for (final value in values) {
    final normalized = value?.trim() ?? '';
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }
  return null;
}
