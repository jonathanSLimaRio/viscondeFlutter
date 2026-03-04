import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visconde_app/app/app.dart';
import 'package:visconde_app/core/models/child_profile.dart';
import 'package:visconde_app/features/story_room/models/story_models.dart';
import 'package:visconde_app/features/story_room/ui/story_room_screen.dart';
import 'package:visconde_app/shared/providers.dart';
import 'package:visconde_app/shared/ux_analytics.dart';
import 'package:visconde_app/shared/ux_analytics_api.dart';
import 'package:visconde_app/shared/ux_analytics_queue.dart';
import 'package:visconde_app/shared/ux_analytics_service.dart';

import '../../helpers/test_harness.dart';

class QuickCreateStoryApi extends FakeStoryApi {
  QuickCreateStoryApi({
    required super.collections,
    required super.virtues,
    required super.session,
    required this.templates,
  });

  final List<ContentStoryTemplateModel> templates;
  int createCalls = 0;
  int suggestCalls = 0;
  String? lastChildId;
  String? lastTheme;
  String? lastVirtueId;

  @override
  Future<List<ContentStoryTemplateModel>> listPublishedStoryTemplates(
    String accessToken,
  ) async {
    return templates;
  }

  @override
  Future<VirtueSuggestionResult> suggestVirtue(
    String accessToken, {
    required String childProfileId,
  }) async {
    suggestCalls += 1;
    return const VirtueSuggestionResult(
      virtue: VirtueModel(
        id: 'virtue-suggested',
        slug: 'coragem',
        name: 'Coragem',
        shortDescription: 'Seguir em frente',
        iconKey: 'courage',
        sortOrder: 1,
      ),
      ageBand: AgeBand.age6_8,
      reason: 'Sugerida para a faixa etária.',
      alternatives: <VirtueModel>[],
    );
  }

  @override
  Future<StorySessionModel> createStorySession(
    String accessToken, {
    required String childProfileId,
    required String titleDraft,
    required String theme,
    required String scenario,
    required List<Map<String, String?>> characters,
    required String objective,
    required StoryMode startMode,
    String? virtueId,
    String? sourceTemplateId,
    String? artStyleId,
  }) async {
    createCalls += 1;
    lastChildId = childProfileId;
    lastTheme = theme;
    lastVirtueId = virtueId;
    return session!;
  }
}

class NoopUxStore implements UxAnalyticsStore {
  @override
  Future<void> dispose() async {}

  @override
  Future<void> enqueue({
    required UxAnalyticsEvent event,
    required String appSessionId,
    String? source,
    String? childId,
    Map<String, Object?> params = const <String, Object?>{},
  }) async {}

  @override
  Future<List<QueuedUxAnalyticsEvent>> listRetryable({int limit = 50}) async {
    return const <QueuedUxAnalyticsEvent>[];
  }

  @override
  Future<void> markFailed(List<int> ids, {String? reason}) async {}

  @override
  Future<void> markSent(List<int> ids) async {}
}

class NoopUxTransport implements UxAnalyticsTransport {
  @override
  Future<UxAnalyticsBatchResult> sendBatch(
    UxAnalyticsBatchPayload payload, {
    String? accessToken,
  }) async {
    return const UxAnalyticsBatchResult(
      accepted: 0,
      deduplicated: 0,
      rejected: 0,
    );
  }
}

StorySessionModel _buildSession() {
  return StorySessionModel(
    id: 'story-quick',
    childProfileId: 'child-1',
    collectionId: 'collection-1',
    episodeNumber: 1,
    sessionKind: StorySessionKind.presencial,
    titleDraft: 'Aventura de Lia',
    title: 'Aventura de Lia',
    theme: 'Piratas',
    scenario: 'Porto encantado',
    objective: 'Ajudar o capitão',
    status: StoryStatus.draft,
    currentMode: StoryMode.parentNarrator,
    currentStepIndex: 0,
    ageSnapshotYears: 8,
    child: StoryChildSnapshot(
      id: 'child-1',
      name: 'Lia',
      birthDate: DateTime(2018, 1, 1),
    ),
    characters: const <StoryCharacterModel>[
      StoryCharacterModel(id: 'char-1', name: 'Lia', role: 'protagonista'),
    ],
    steps: const <StoryStepModel>[],
  );
}

void main() {
  testWidgets('quick create abre sala e cria sessão com defaults', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));

    final virtues = <VirtueModel>[
      const VirtueModel(
        id: 'virtue-1',
        slug: 'amizade',
        name: 'Amizade',
        shortDescription: 'Trabalhar em equipe',
        iconKey: 'heart',
        sortOrder: 1,
      ),
    ];
    final children = <ChildProfile>[
      ChildProfile(
        id: 'child-1',
        name: 'Lia',
        birthDate: DateTime(2018, 1, 1),
        favoriteThemes: const <String>['Espaço'],
        isArchived: false,
      ),
    ];
    final collections = <StoryVaultCollectionItem>[
      StoryVaultCollectionItem(
        id: 'col-1',
        title: 'Aventura da Lia',
        theme: 'Piratas',
        virtue: virtues.first,
        isFavorite: false,
        child: const StoryVaultChild(id: 'child-1', name: 'Lia'),
        episodesCount: 1,
        publishedCount: 0,
        draftCount: 1,
        lastReferenceAt: DateTime(2026, 3, 3, 10, 0),
        latestEpisode: StoryVaultLatestEpisode(
          storyId: 'story-1',
          episodeNumber: 1,
          title: 'Capítulo 1',
          status: StoryStatus.draft,
          updatedAt: DateTime(2026, 3, 3, 10, 0),
          currentStepIndex: 0,
        ),
      ),
    ];
    final templates = <ContentStoryTemplateModel>[
      const ContentStoryTemplateModel(
        id: 'tpl-1',
        slug: 'template',
        title: 'Template Infantil',
        description: 'template',
        ageBand: AgeBand.age6_8,
        version: 1,
        theme: StoryNamedRef(id: 'theme-1', slug: 'piratas', name: 'Piratas'),
        virtue: StoryNamedRef(id: 'virtue-1', slug: 'amizade', name: 'Amizade'),
        defaultScenario: 'Porto encantado',
        defaultObjective: 'Ajudar o capitão',
        charactersCount: 2,
        nodesCount: 3,
      ),
    ];

    final storyApi = QuickCreateStoryApi(
      collections: collections,
      virtues: virtues,
      session: _buildSession(),
      templates: templates,
    );

    final container = ProviderContainer(
      overrides: [
        ...authOverrides(user: buildTestUser(), authenticated: true),
        childrenApiProvider.overrideWith(
          (ref) => FakeChildrenApi(children: children),
        ),
        storyApiProvider.overrideWith((ref) => storyApi),
        uxAnalyticsServiceProvider.overrideWith(
          (ref) => UxAnalyticsService(
            store: NoopUxStore(),
            transport: NoopUxTransport(),
            readAccessToken: () => null,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(0.8)),
        child: UncontrolledProviderScope(
          container: container,
          child: const ViscondeApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Criar história rápida').first);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(storyApi.createCalls, 1);
    expect(storyApi.suggestCalls, 1);
    expect(storyApi.lastChildId, 'child-1');
    expect(storyApi.lastTheme, 'Piratas');
    expect(find.byType(StoryRoomScreen), findsOneWidget);
  });

  testWidgets('quick create sem criança mostra mensagem e não cria sessão', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));

    final storyApi = QuickCreateStoryApi(
      collections: const <StoryVaultCollectionItem>[],
      virtues: const <VirtueModel>[],
      session: _buildSession(),
      templates: const <ContentStoryTemplateModel>[],
    );

    final container = ProviderContainer(
      overrides: [
        ...authOverrides(user: buildTestUser(), authenticated: true),
        childrenApiProvider.overrideWith(
          (ref) => FakeChildrenApi(children: const <ChildProfile>[]),
        ),
        storyApiProvider.overrideWith((ref) => storyApi),
        uxAnalyticsServiceProvider.overrideWith(
          (ref) => UxAnalyticsService(
            store: NoopUxStore(),
            transport: NoopUxTransport(),
            readAccessToken: () => null,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(0.8)),
        child: UncontrolledProviderScope(
          container: container,
          child: const ViscondeApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Criar história rápida').first);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(storyApi.createCalls, 0);
    expect(
      find.text(
        'Cadastre uma criança em Perfil > Crianças para começar a aventura.',
      ),
      findsOneWidget,
    );
  });
}
