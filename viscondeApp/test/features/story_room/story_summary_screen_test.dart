import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:visconde_app/app/app.dart';
import 'package:visconde_app/app/router.dart';
import 'package:visconde_app/features/gamification/inventory_api.dart';
import 'package:visconde_app/features/gamification/inventory_models.dart';
import 'package:visconde_app/features/gamification/models/gamification_models.dart';
import 'package:visconde_app/features/story_room/models/story_models.dart';
import 'package:visconde_app/features/story_room/story_api.dart';
import 'package:visconde_app/shared/providers.dart';
import 'package:visconde_app/shared/ux_analytics.dart';
import 'package:visconde_app/shared/ux_analytics_api.dart';
import 'package:visconde_app/shared/ux_analytics_queue.dart';
import 'package:visconde_app/shared/ux_analytics_service.dart';

import '../../helpers/test_harness.dart';

class _SummaryStoryApi extends StoryApi {
  _SummaryStoryApi({
    required StorySessionModel session,
    this.failContinue = false,
    this.autoCompletedSteps = 0,
  }) : _session = session,
       super(Dio());

  StorySessionModel _session;
  bool failContinue;
  int autoCompletedSteps;
  int continueCalls = 0;

  @override
  Future<StorySessionModel> getStorySession(
    String accessToken,
    String storyId,
  ) async {
    return _session.copyWith(status: _session.status, title: _session.title);
  }

  @override
  Future<StoryFinalizeResult> finalizeStory(
    String accessToken,
    String storyId, {
    String? titleFinal,
  }) async {
    _session = _session.copyWith(
      status: StoryStatus.published,
      titleFinal: titleFinal?.trim().isNotEmpty == true ? titleFinal : null,
      title: titleFinal?.trim().isNotEmpty == true
          ? titleFinal!
          : _session.title,
    );
    return StoryFinalizeResult(
      story: _session,
      gamification: PublishGamificationSummaryModel(
        wallet: const WalletModel(coins: 90, stars: 50, recentTransactions: []),
        deltaCoins: 10,
        deltaStars: 4,
        unlockedAchievements: const [],
        completedMissions: const [],
        streak: const StreakModel(
          currentDays: 2,
          bestDays: 3,
          shieldCount: 0,
          lastCountedDate: null,
        ),
      ),
      publishMeta: StoryPublishMetaModel(
        minimumRequiredSteps: 3,
        stepCountBeforePublish: _session.steps.length,
        autoCompletedSteps: autoCompletedSteps,
        finalStepCount: _session.steps.length + autoCompletedSteps,
      ),
    );
  }

  @override
  Future<StorySessionModel> continueStory(
    String accessToken,
    String storyId, {
    String? titleDraft,
  }) async {
    continueCalls += 1;
    if (failContinue) {
      throw DioException(
        requestOptions: RequestOptions(path: 'stories/$storyId/continue'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: 'stories/$storyId/continue'),
          statusCode: 500,
          data: const <String, dynamic>{'error': 'Falha ao continuar'},
        ),
      );
    }

    _session = StorySessionModel(
      id: 'story-continued',
      childProfileId: _session.childProfileId,
      collectionId: _session.collectionId,
      episodeNumber: _session.episodeNumber + 1,
      continuedFromStoryId: _session.id,
      sourceTemplateId: _session.sourceTemplateId,
      artStyleId: _session.artStyleId,
      sessionKind: StorySessionKind.presencial,
      titleDraft: 'Continuação',
      titleFinal: null,
      title: 'Continuação',
      theme: _session.theme,
      scenario: _session.scenario,
      objective: _session.objective,
      ageBand: _session.ageBand,
      virtueSource: _session.virtueSource,
      dilemmaText: _session.dilemmaText,
      endQuestionText: _session.endQuestionText,
      virtue: _session.virtue,
      status: StoryStatus.draft,
      currentMode: _session.currentMode,
      currentStepIndex: 0,
      ageSnapshotYears: _session.ageSnapshotYears,
      child: _session.child,
      characters: _session.characters,
      steps: const [],
    );

    return _session;
  }
}

class _SummaryInventoryApi extends InventoryApi {
  _SummaryInventoryApi() : super(Dio());

  @override
  Future<ChildInventoryModel?> rewardRandomItem(
    String storyId,
    String accessToken,
  ) async {
    return null;
  }
}

class _NoopUxStore implements UxAnalyticsStore {
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

class _NoopUxTransport implements UxAnalyticsTransport {
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

StorySessionModel _buildSession({
  List<StoryStepModel>? steps,
  int currentStepIndex = 2,
}) {
  final timelineSteps =
      steps ??
      const [
        StoryStepModel(
          id: 'step-1',
          stepIndex: 1,
          kind: StoryStepKind.narration,
          modeUsed: StoryMode.parentNarrator,
          localEventId: 'local-1',
          narratorPrompt: null,
          childOptions: [],
          selectedOptionId: null,
          selectedOptionLabel: null,
          narratorText: 'Era uma vez...',
        ),
      ];

  return StorySessionModel(
    id: 'story-test',
    childProfileId: 'child-1',
    collectionId: 'collection-1',
    episodeNumber: 1,
    continuedFromStoryId: null,
    sourceTemplateId: null,
    artStyleId: null,
    sessionKind: StorySessionKind.presencial,
    titleDraft: 'Aventura do Lucas',
    titleFinal: null,
    title: 'Aventura do Lucas',
    theme: 'Aventura',
    scenario: 'Bosque',
    objective: 'Ajudar um amigo',
    ageBand: AgeBand.age6_8,
    virtueSource: null,
    dilemmaText: null,
    endQuestionText: null,
    virtue: const VirtueModel(
      id: 'virtue-1',
      slug: 'coragem',
      name: 'Coragem',
      shortDescription: 'Seguir em frente',
      iconKey: 'courage',
      sortOrder: 1,
    ),
    status: StoryStatus.draft,
    currentMode: StoryMode.parentNarrator,
    currentStepIndex: currentStepIndex,
    ageSnapshotYears: 7,
    child: StoryChildSnapshot(
      id: 'child-1',
      name: 'Lucas',
      birthDate: DateTime(2018, 1, 1),
    ),
    characters: const [
      StoryCharacterModel(id: 'char-1', name: 'Lucas', role: 'Protagonista'),
    ],
    steps: timelineSteps,
  );
}

void main() {
  testWidgets(
    'summary mostra publicação assistida quando há menos de 3 etapas',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      final api = _SummaryStoryApi(
        session: _buildSession(),
        autoCompletedSteps: 2,
      );

      final container = ProviderContainer(
        overrides: [
          ...authOverrides(user: buildTestUser(), authenticated: true),
          storyApiProvider.overrideWith((ref) => api),
          inventoryApiProvider.overrideWith((ref) => _SummaryInventoryApi()),
          storySyncQueueProvider.overrideWith((ref) => FakeStorySyncQueue()),
          uxAnalyticsServiceProvider.overrideWith(
            (ref) => UxAnalyticsService(
              store: _NoopUxStore(),
              transport: _NoopUxTransport(),
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
      router.go('/stories/story-test/summary');
      await tester.pumpAndSettle();

      expect(find.text('Publicar e completar 2 etapas'), findsOneWidget);
      await tester.tap(find.byKey(const Key('story_summary_publish_button')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Capítulo publicado. 2 etapas foram completadas automaticamente.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('summary mantém CTA padrão com 3 etapas salvas', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    final api = _SummaryStoryApi(
      session: _buildSession(
        currentStepIndex: 3,
        steps: const [
          StoryStepModel(
            id: 'step-1',
            stepIndex: 1,
            kind: StoryStepKind.narration,
            modeUsed: StoryMode.parentNarrator,
            localEventId: 'local-1',
            narratorPrompt: null,
            childOptions: [],
            selectedOptionId: null,
            selectedOptionLabel: null,
            narratorText: 'A',
          ),
          StoryStepModel(
            id: 'step-2',
            stepIndex: 2,
            kind: StoryStepKind.narration,
            modeUsed: StoryMode.parentNarrator,
            localEventId: 'local-2',
            narratorPrompt: null,
            childOptions: [],
            selectedOptionId: null,
            selectedOptionLabel: null,
            narratorText: 'B',
          ),
          StoryStepModel(
            id: 'step-3',
            stepIndex: 3,
            kind: StoryStepKind.narration,
            modeUsed: StoryMode.parentNarrator,
            localEventId: 'local-3',
            narratorPrompt: null,
            childOptions: [],
            selectedOptionId: null,
            selectedOptionLabel: null,
            narratorText: 'C',
          ),
        ],
      ),
    );

    final container = ProviderContainer(
      overrides: [
        ...authOverrides(user: buildTestUser(), authenticated: true),
        storyApiProvider.overrideWith((ref) => api),
        inventoryApiProvider.overrideWith((ref) => _SummaryInventoryApi()),
        storySyncQueueProvider.overrideWith((ref) => FakeStorySyncQueue()),
        uxAnalyticsServiceProvider.overrideWith(
          (ref) => UxAnalyticsService(
            store: _NoopUxStore(),
            transport: _NoopUxTransport(),
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
    router.go('/stories/story-test/summary');
    await tester.pumpAndSettle();

    expect(find.text('Publicar capítulo'), findsOneWidget);
  });

  testWidgets('continue saga opens next room after publish', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    final api = _SummaryStoryApi(session: _buildSession());

    final container = ProviderContainer(
      overrides: [
        ...authOverrides(user: buildTestUser(), authenticated: true),
        storyApiProvider.overrideWith((ref) => api),
        inventoryApiProvider.overrideWith((ref) => _SummaryInventoryApi()),
        storySyncQueueProvider.overrideWith((ref) => FakeStorySyncQueue()),
        uxAnalyticsServiceProvider.overrideWith(
          (ref) => UxAnalyticsService(
            store: _NoopUxStore(),
            transport: _NoopUxTransport(),
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
    router.go('/stories/story-test/summary');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('story_summary_publish_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar saga'));
    await tester.pumpAndSettle();

    expect(api.continueCalls, 1);
    final location = router.routeInformationProvider.value.uri.toString();
    expect(location, '/stories/story-continued/room');
  });

  testWidgets('ir para conquistas abre aba de conquistas após publicar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    final api = _SummaryStoryApi(session: _buildSession());

    final container = ProviderContainer(
      overrides: [
        ...authOverrides(user: buildTestUser(), authenticated: true),
        storyApiProvider.overrideWith((ref) => api),
        inventoryApiProvider.overrideWith((ref) => _SummaryInventoryApi()),
        storySyncQueueProvider.overrideWith((ref) => FakeStorySyncQueue()),
        uxAnalyticsServiceProvider.overrideWith(
          (ref) => UxAnalyticsService(
            store: _NoopUxStore(),
            transport: _NoopUxTransport(),
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
    router.go('/stories/story-test/summary');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('story_summary_publish_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ir para Conquistas'));
    await tester.pumpAndSettle();

    final location = router.routeInformationProvider.value.uri.toString();
    expect(location, '/?tab=achievements');
  });

  testWidgets('voltar ao baú sai do resumo após publicar', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    final api = _SummaryStoryApi(session: _buildSession());

    final container = ProviderContainer(
      overrides: [
        ...authOverrides(user: buildTestUser(), authenticated: true),
        storyApiProvider.overrideWith((ref) => api),
        inventoryApiProvider.overrideWith((ref) => _SummaryInventoryApi()),
        storySyncQueueProvider.overrideWith((ref) => FakeStorySyncQueue()),
        uxAnalyticsServiceProvider.overrideWith(
          (ref) => UxAnalyticsService(
            store: _NoopUxStore(),
            transport: _NoopUxTransport(),
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
    router.go('/stories/story-test/summary');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('story_summary_publish_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voltar ao baú'));
    await tester.pumpAndSettle();

    final location = router.routeInformationProvider.value.uri.toString();
    expect(location, '/');
  });

  testWidgets('continue saga failure falls back to stories tab', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    final api = _SummaryStoryApi(session: _buildSession(), failContinue: true);

    final container = ProviderContainer(
      overrides: [
        ...authOverrides(user: buildTestUser(), authenticated: true),
        storyApiProvider.overrideWith((ref) => api),
        inventoryApiProvider.overrideWith((ref) => _SummaryInventoryApi()),
        storySyncQueueProvider.overrideWith((ref) => FakeStorySyncQueue()),
        uxAnalyticsServiceProvider.overrideWith(
          (ref) => UxAnalyticsService(
            store: _NoopUxStore(),
            transport: _NoopUxTransport(),
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
    router.go('/stories/story-test/summary');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('story_summary_publish_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar saga'));
    await tester.pumpAndSettle();

    expect(api.continueCalls, 1);
    final location = router.routeInformationProvider.value.uri.toString();
    expect(location, '/');
  });
}
