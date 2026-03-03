import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visconde_app/app/app.dart';
import 'package:visconde_app/app/router.dart';
import 'package:visconde_app/core/models/child_profile.dart';
import 'package:visconde_app/features/story_creation/create_story_wizard_draft_store.dart';
import 'package:visconde_app/features/story_room/illustration_api.dart';
import 'package:visconde_app/features/story_room/models/illustration_models.dart';
import 'package:visconde_app/features/story_room/models/story_models.dart';
import 'package:visconde_app/features/story_room/story_api.dart';
import 'package:visconde_app/features/story_room/ui/story_room_screen.dart';
import 'package:visconde_app/shared/providers.dart';
import 'package:visconde_app/shared/ux_analytics.dart';
import 'package:visconde_app/shared/ux_analytics_api.dart';
import 'package:visconde_app/shared/ux_analytics_queue.dart';
import 'package:visconde_app/shared/ux_analytics_service.dart';

import '../../helpers/test_harness.dart';

class InMemoryCreateStoryDraftStore implements CreateStoryWizardDraftStore {
  final Map<String, CreateStoryWizardDraft> _byUser =
      <String, CreateStoryWizardDraft>{};

  @override
  Future<void> clear(String userId) async {
    _byUser.remove(userId);
  }

  @override
  Future<void> dispose() async {}

  @override
  Future<CreateStoryWizardDraft?> read(String userId) async {
    return _byUser[userId];
  }

  @override
  Future<void> save(CreateStoryWizardDraft draft) async {
    _byUser[draft.userId] = draft;
  }
}

class FakeIllustrationApi extends IllustrationApi {
  FakeIllustrationApi(this.styles) : super(Dio());

  final List<ArtStyleModel> styles;

  @override
  Future<List<ArtStyleModel>> listArtStyles() async => styles;
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

class WizardStoryApi extends StoryApi {
  WizardStoryApi({
    required this.session,
    required this.virtues,
    required this.templates,
    this.collections = const <StoryVaultCollectionItem>[],
  }) : super(Dio());

  StorySessionModel session;
  final List<VirtueModel> virtues;

  final List<ContentStoryTemplateModel> templates;
  final List<StoryVaultCollectionItem> collections;

  int createSessionCalls = 0;
  int updateSetupCalls = 0;
  int createStepCalls = 0;
  int wizardPublishCalls = 0;

  @override
  Future<List<ContentStoryTemplateModel>> listPublishedStoryTemplates(
    String accessToken,
  ) async {
    return templates;
  }

  @override
  Future<List<StoryVaultCollectionItem>> listStoryVaultCollections(
    String accessToken, {
    String? childProfileId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? theme,
    String? virtueId,
    bool favoriteOnly = false,
  }) async {
    return collections;
  }

  @override
  Future<List<VirtueModel>> listVirtues(String accessToken) async {
    return virtues;
  }

  @override
  Future<StorySessionModel> getStorySession(
    String accessToken,
    String storyId,
  ) async {
    return session;
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
    createSessionCalls += 1;

    final nextCharacters = characters
        .map(
          (item) => StoryCharacterModel(
            id: 'c-${item['name']}',
            name: item['name'] ?? '',
            role: item['role'],
          ),
        )
        .toList();

    session = session.copyWith(
      titleDraft: titleDraft,
      title: titleDraft,
      characters: nextCharacters,
      currentMode: startMode,
      sourceTemplateId: sourceTemplateId,
    );

    return session;
  }

  @override
  Future<StorySessionModel> updateStorySessionSetup(
    String accessToken,
    String storyId, {
    required String titleDraft,
    required String theme,
    required String scenario,
    required String objective,
    required List<Map<String, String?>> characters,
    String? virtueId,
    String? sourceTemplateId,
    bool updateSourceTemplate = false,
    String? artStyleId,
    bool updateArtStyle = false,
    StoryMode? mode,
    bool applyAutoVirtue = false,
  }) async {
    updateSetupCalls += 1;

    final nextCharacters = characters
        .map(
          (item) => StoryCharacterModel(
            id: 'c-${item['name']}',
            name: item['name'] ?? '',
            role: item['role'],
          ),
        )
        .toList();

    session = session.copyWith(
      titleDraft: titleDraft,
      title: titleDraft,
      characters: nextCharacters,
      currentMode: mode ?? session.currentMode,
      sourceTemplateId: updateSourceTemplate
          ? sourceTemplateId
          : session.sourceTemplateId,
    );

    return session;
  }

  @override
  Future<StoryStepSaveResult> createStep(
    String accessToken,
    String storyId, {
    required StoryStepKind kind,
    required int stepIndex,
    String? narratorText,
    String? narratorPrompt,
    String? selectedOptionId,
    String? selectedOptionLabel,
    required String localEventId,
  }) async {
    createStepCalls += 1;

    final step = StoryStepModel(
      id: 'step-$stepIndex',
      stepIndex: stepIndex,
      kind: kind,
      modeUsed: session.currentMode,
      localEventId: localEventId,
      narratorPrompt: narratorPrompt,
      childOptions: const <StoryChoiceOption>[],
      selectedOptionId: selectedOptionId,
      selectedOptionLabel: selectedOptionLabel,
      narratorText: narratorText,
    );

    session = session.copyWith(
      currentStepIndex: stepIndex,
      steps: <StoryStepModel>[...session.steps, step],
    );

    return StoryStepSaveResult(story: session, idempotent: false);
  }

  @override
  Future<StoryFinalizeResult> wizardPublishStory(
    String accessToken,
    String storyId, {
    String? titleFinal,
  }) async {
    wizardPublishCalls += 1;

    session = session.copyWith(
      status: StoryStatus.published,
      currentStepIndex: 3,
      titleFinal: titleFinal,
      title: titleFinal ?? session.titleDraft,
    );

    return StoryFinalizeResult(story: session);
  }
}

StorySessionModel _buildSession() {
  return StorySessionModel(
    id: 'story-1',
    childProfileId: 'child-1',
    collectionId: 'collection-1',
    episodeNumber: 1,
    sessionKind: StorySessionKind.presencial,
    titleDraft: 'Aventura de Lia',
    title: 'Aventura de Lia',
    theme: 'Aventura',
    scenario: 'Bosque encantado',
    objective: 'Aprender algo novo',
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
      StoryCharacterModel(id: 'c-1', name: 'Lia', role: 'protagonista'),
    ],
    steps: const <StoryStepModel>[],
  );
}

Future<void> _tapWizardControl(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder, warnIfMissed: false);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('inicia pelo botão de sugestão em um toque', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));

    final user = buildTestUser();
    final draftStore = InMemoryCreateStoryDraftStore();
    final children = <ChildProfile>[
      ChildProfile(
        id: 'child-1',
        name: 'Lia',
        birthDate: DateTime(2018, 1, 1),
        favoriteThemes: const <String>['Aventura'],
        isArchived: false,
      ),
    ];
    final virtues = <VirtueModel>[
      const VirtueModel(
        id: 'virtue-1',
        slug: 'coragem',
        name: 'Coragem',
        shortDescription: 'Seguir em frente',
        iconKey: 'courage',
        sortOrder: 1,
      ),
    ];
    final templates = <ContentStoryTemplateModel>[
      const ContentStoryTemplateModel(
        id: 'tpl-1',
        slug: 'template-inicial',
        title: 'Template Inicial',
        description: 'template',
        ageBand: AgeBand.age6_8,
        version: 1,
        defaultScenario: 'Bosque encantado',
        defaultObjective: 'Aprender algo novo com coragem e gentileza.',
        theme: StoryNamedRef(id: 'theme-1', slug: 'aventura', name: 'Aventura'),
        virtue: StoryNamedRef(id: 'virtue-1', slug: 'coragem', name: 'Coragem'),
        nodesCount: 3,
        charactersCount: 2,
      ),
    ];
    final storyApi = WizardStoryApi(
      virtues: virtues,
      session: _buildSession(),
      templates: templates,
    );

    final container = ProviderContainer(
      overrides: [
        ...authOverrides(user: user, authenticated: true),
        childrenApiProvider.overrideWith(
          (ref) => FakeChildrenApi(children: children),
        ),
        storyApiProvider.overrideWith((ref) => storyApi),
        illustrationApiProvider.overrideWith(
          (ref) => FakeIllustrationApi(const <ArtStyleModel>[
            ArtStyleModel(
              id: 'style-1',
              name: 'Aquarela',
              promptTemplate: 'watercolor',
            ),
          ]),
        ),
        createStoryWizardDraftStoreProvider.overrideWithValue(draftStore),
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

    final router = container.read(appRouterProvider);
    router.go('/stories/new');
    await tester.pumpAndSettle();

    expect(find.text('Para Lia'), findsOneWidget);
    await _tapWizardControl(
      tester,
      find.byKey(const Key('wizard_recommendation_quick_start_button')),
    );

    expect(storyApi.createSessionCalls, 1);
    expect(find.text('Passo 2 de 3'), findsOneWidget);
  });

  testWidgets('autosave por passo e continuar depois salva rascunho local', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));

    final user = buildTestUser();
    final draftStore = InMemoryCreateStoryDraftStore();
    final children = <ChildProfile>[
      ChildProfile(
        id: 'child-1',
        name: 'Lia',
        birthDate: DateTime(2018, 1, 1),
        favoriteThemes: const <String>['Aventura'],
        isArchived: false,
      ),
    ];
    final virtues = <VirtueModel>[
      const VirtueModel(
        id: 'virtue-1',
        slug: 'coragem',
        name: 'Coragem',
        shortDescription: 'Seguir em frente',
        iconKey: 'courage',
        sortOrder: 1,
      ),
    ];
    final templates = <ContentStoryTemplateModel>[
      const ContentStoryTemplateModel(
        id: 'tpl-1',
        slug: 'template-inicial',
        title: 'Template Inicial',
        description: 'template',
        ageBand: AgeBand.age6_8,
        version: 1,
        defaultScenario: 'Bosque encantado',
        defaultObjective: 'Aprender algo novo com coragem e gentileza.',
        theme: StoryNamedRef(id: 'theme-1', slug: 'aventura', name: 'Aventura'),
        virtue: StoryNamedRef(id: 'virtue-1', slug: 'coragem', name: 'Coragem'),
        nodesCount: 3,
        charactersCount: 2,
      ),
    ];
    final storyApi = WizardStoryApi(
      virtues: virtues,
      session: _buildSession(),
      templates: templates,
    );

    final container = ProviderContainer(
      overrides: [
        ...authOverrides(user: user, authenticated: true),
        childrenApiProvider.overrideWith(
          (ref) => FakeChildrenApi(children: children),
        ),
        storyApiProvider.overrideWith((ref) => storyApi),
        illustrationApiProvider.overrideWith(
          (ref) => FakeIllustrationApi(const <ArtStyleModel>[
            ArtStyleModel(
              id: 'style-1',
              name: 'Aquarela',
              promptTemplate: 'watercolor',
            ),
          ]),
        ),
        createStoryWizardDraftStoreProvider.overrideWithValue(draftStore),
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

    final router = container.read(appRouterProvider);
    router.go('/stories/new');
    await tester.pumpAndSettle();

    await _tapWizardControl(
      tester,
      find.byKey(const Key('wizard_save_continue_button')),
    );

    await _tapWizardControl(
      tester,
      find.byKey(const Key('wizard_save_continue_button')),
    );

    await _tapWizardControl(
      tester,
      find.byKey(const Key('wizard_continue_later_button')),
    );

    expect(storyApi.createSessionCalls, 1);
    expect(storyApi.updateSetupCalls, greaterThanOrEqualTo(1));

    final saved = await draftStore.read(user.id);
    expect(saved, isNotNull);
    expect(saved?.currentStep, 2);
  });

  testWidgets('publicar agora executa fluxo híbrido e limpa rascunho local', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));

    final user = buildTestUser();
    final draftStore = InMemoryCreateStoryDraftStore();
    final children = <ChildProfile>[
      ChildProfile(
        id: 'child-1',
        name: 'Lia',
        birthDate: DateTime(2018, 1, 1),
        favoriteThemes: const <String>['Aventura'],
        isArchived: false,
      ),
    ];
    final virtues = <VirtueModel>[
      const VirtueModel(
        id: 'virtue-1',
        slug: 'coragem',
        name: 'Coragem',
        shortDescription: 'Seguir em frente',
        iconKey: 'courage',
        sortOrder: 1,
      ),
    ];
    final templates = <ContentStoryTemplateModel>[
      const ContentStoryTemplateModel(
        id: 'tpl-1',
        slug: 'template-inicial',
        title: 'Template Inicial',
        description: 'template',
        ageBand: AgeBand.age6_8,
        version: 1,
        defaultScenario: 'Bosque encantado',
        defaultObjective: 'Aprender algo novo com coragem e gentileza.',
        theme: StoryNamedRef(id: 'theme-1', slug: 'aventura', name: 'Aventura'),
        virtue: StoryNamedRef(id: 'virtue-1', slug: 'coragem', name: 'Coragem'),
        nodesCount: 3,
        charactersCount: 2,
      ),
    ];
    final storyApi = WizardStoryApi(
      virtues: virtues,
      session: _buildSession(),
      templates: templates,
    );

    final container = ProviderContainer(
      overrides: [
        ...authOverrides(user: user, authenticated: true),
        childrenApiProvider.overrideWith(
          (ref) => FakeChildrenApi(children: children),
        ),
        storyApiProvider.overrideWith((ref) => storyApi),
        illustrationApiProvider.overrideWith(
          (ref) => FakeIllustrationApi(const <ArtStyleModel>[
            ArtStyleModel(
              id: 'style-1',
              name: 'Aquarela',
              promptTemplate: 'watercolor',
            ),
          ]),
        ),
        createStoryWizardDraftStoreProvider.overrideWithValue(draftStore),
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

    final router = container.read(appRouterProvider);
    router.go('/stories/new');
    await tester.pumpAndSettle();

    await _tapWizardControl(
      tester,
      find.byKey(const Key('wizard_save_continue_button')),
    );

    await _tapWizardControl(
      tester,
      find.byKey(const Key('wizard_save_continue_button')),
    );

    await _tapWizardControl(
      tester,
      find.byKey(const Key('wizard_publish_now_button')),
    );

    expect(storyApi.createStepCalls, greaterThanOrEqualTo(3));
    expect(storyApi.wizardPublishCalls, 1);

    expect(find.text('Capítulo publicado!'), findsOneWidget);
    expect(find.text('Continuar saga'), findsOneWidget);
    expect(find.text('Ir para Game'), findsOneWidget);
    expect(find.text('Voltar ao baú'), findsOneWidget);
    await tester.tap(find.text('Voltar ao baú'));
    await tester.pumpAndSettle();

    expect(find.byType(StoryRoomScreen), findsNothing);
    final saved = await draftStore.read(user.id);
    expect(saved, isNull);
  });
}
