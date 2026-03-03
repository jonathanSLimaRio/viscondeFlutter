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

class QuickStoryRecommendations {
  const QuickStoryRecommendations({
    required this.child,
    required this.ageBand,
    required this.themeSuggestions,
    required this.virtueSuggestions,
    required this.fallbackUsed,
    required this.reason,
    this.sourceTemplateId,
  });

  final ChildProfile child;
  final AgeBand ageBand;
  final List<String> themeSuggestions;
  final List<VirtueModel> virtueSuggestions;
  final bool fallbackUsed;
  final String reason;
  final String? sourceTemplateId;
}

const Map<AgeBand, List<String>> _ageBandThemeSuggestions =
    <AgeBand, List<String>>{
      AgeBand.age4_5: <String>['Animais', 'Amizade', 'Natureza'],
      AgeBand.age6_8: <String>['Aventura', 'Exploração', 'Mistério'],
      AgeBand.age9_10: <String>['Missão', 'Descobertas', 'Trabalho em equipe'],
    };

const Map<AgeBand, List<String>> _ageBandVirtueHints = <AgeBand, List<String>>{
  AgeBand.age4_5: <String>['empatia', 'gentileza', 'amizade'],
  AgeBand.age6_8: <String>['coragem', 'responsabilidade', 'cooperacao'],
  AgeBand.age9_10: <String>['autonomia', 'resiliencia', 'lideranca'],
};

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

QuickStoryRecommendations? buildQuickStoryRecommendations({
  required List<ChildProfile> children,
  required List<StoryVaultCollectionItem> collections,
  required List<ContentStoryTemplateModel> templates,
  required List<VirtueModel> virtues,
  String? selectedChildId,
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

  final childCollections =
      collections
          .where((collection) => collection.child.id == child.id)
          .toList()
        ..sort(
          (left, right) =>
              right.lastReferenceAt.compareTo(left.lastReferenceAt),
        );
  final hasRecentHistory = childCollections.isNotEmpty;

  final themeSuggestions = _dedupeThemeSuggestions(<String?>[
    ...childCollections.take(2).map((collection) => collection.theme),
    template?.theme?.name,
    ...child.favoriteThemes.take(2),
    ...(_ageBandThemeSuggestions[ageBand] ?? const <String>[]),
    _fallbackTheme,
  ]);

  final virtueSuggestions = _buildVirtueSuggestions(
    childCollections: childCollections,
    template: template,
    virtues: virtues,
    ageBand: ageBand,
  );

  final reason = hasRecentHistory
      ? 'Com base no histórico recente e na faixa etária ${ageBandLabel(ageBand)}.'
      : child.favoriteThemes.isNotEmpty
      ? 'Sem histórico suficiente. Sugestões com base em temas favoritos e faixa etária.'
      : 'Sem histórico suficiente. Sugestões com base na faixa etária.';

  return QuickStoryRecommendations(
    child: child,
    ageBand: ageBand,
    themeSuggestions: themeSuggestions,
    virtueSuggestions: virtueSuggestions,
    fallbackUsed: !hasRecentHistory,
    reason: reason,
    sourceTemplateId: template?.id,
  );
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

List<String> _dedupeThemeSuggestions(Iterable<String?> rawValues) {
  final result = <String>[];
  final seen = <String>{};

  for (final raw in rawValues) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) {
      continue;
    }
    final normalized = _normalizeForLookup(value);
    if (seen.contains(normalized)) {
      continue;
    }
    seen.add(normalized);
    result.add(value);
    if (result.length == 3) {
      break;
    }
  }

  if (result.isEmpty) {
    return const <String>[_fallbackTheme];
  }
  return result;
}

List<VirtueModel> _buildVirtueSuggestions({
  required List<StoryVaultCollectionItem> childCollections,
  required ContentStoryTemplateModel? template,
  required List<VirtueModel> virtues,
  required AgeBand ageBand,
}) {
  if (virtues.isEmpty) {
    return const <VirtueModel>[];
  }

  final results = <VirtueModel>[];
  final seenIds = <String>{};

  void addVirtue(VirtueModel? value) {
    if (value == null || value.id.trim().isEmpty) {
      return;
    }
    if (seenIds.add(value.id)) {
      results.add(value);
    }
  }

  final recentVirtue = childCollections.isEmpty
      ? null
      : childCollections.first.virtue;
  addVirtue(
    _findVirtueByHints(
      virtues: virtues,
      idHint: recentVirtue?.id,
      slugHint: recentVirtue?.slug,
      nameHint: recentVirtue?.name,
    ),
  );
  addVirtue(
    _findVirtueByHints(
      virtues: virtues,
      idHint: template?.virtue?.id,
      slugHint: template?.virtue?.slug,
      nameHint: template?.virtue?.name,
    ),
  );

  final ageHints = _ageBandVirtueHints[ageBand] ?? const <String>[];
  for (final hint in ageHints) {
    addVirtue(
      _findVirtueByHints(virtues: virtues, slugHint: hint, nameHint: hint),
    );
  }

  final sortedVirtues = List<VirtueModel>.from(virtues)
    ..sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
  for (final virtue in sortedVirtues) {
    addVirtue(virtue);
    if (results.length >= 3) {
      break;
    }
  }

  return results.take(3).toList(growable: false);
}

VirtueModel? _findVirtueByHints({
  required List<VirtueModel> virtues,
  String? idHint,
  String? slugHint,
  String? nameHint,
}) {
  final normalizedId = _normalizeForLookup(idHint ?? '');
  final normalizedSlug = _normalizeForLookup(slugHint ?? '');
  final normalizedName = _normalizeForLookup(nameHint ?? '');

  for (final virtue in virtues) {
    final virtueId = _normalizeForLookup(virtue.id);
    final virtueSlug = _normalizeForLookup(virtue.slug);
    final virtueName = _normalizeForLookup(virtue.name);
    if (normalizedId.isNotEmpty && virtueId == normalizedId) {
      return virtue;
    }
    if (normalizedSlug.isNotEmpty &&
        (virtueSlug == normalizedSlug || virtueName.contains(normalizedSlug))) {
      return virtue;
    }
    if (normalizedName.isNotEmpty &&
        (virtueName == normalizedName || virtueName.contains(normalizedName))) {
      return virtue;
    }
  }

  return null;
}

String _normalizeForLookup(String input) {
  return input
      .trim()
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('à', 'a')
      .replaceAll('â', 'a')
      .replaceAll('ã', 'a')
      .replaceAll('ä', 'a')
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('ë', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ì', 'i')
      .replaceAll('î', 'i')
      .replaceAll('ï', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ò', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('õ', 'o')
      .replaceAll('ö', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ù', 'u')
      .replaceAll('û', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ç', 'c');
}
