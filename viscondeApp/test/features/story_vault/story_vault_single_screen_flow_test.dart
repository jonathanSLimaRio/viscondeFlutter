import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:visconde_app/app/app_route.dart';
import 'package:visconde_app/core/models/child_profile.dart';
import 'package:visconde_app/core/network/api_exception.dart';
import 'package:visconde_app/design_system/visconde.dart';
import 'package:visconde_app/features/auth/auth_controller.dart';
import 'package:visconde_app/features/story_creation/create_story_wizard_draft_store.dart';
import 'package:visconde_app/features/story_room/models/story_models.dart';
import 'package:visconde_app/features/story_vault/ui/story_vault_collection_redirect_screen.dart';
import 'package:visconde_app/features/story_vault/ui/story_vault_screen.dart';
import 'package:visconde_app/shared/providers.dart';
import 'package:visconde_app/shared/ux_analytics.dart';
import 'package:visconde_app/shared/ux_analytics_api.dart';
import 'package:visconde_app/shared/ux_analytics_queue.dart';
import 'package:visconde_app/shared/ux_analytics_service.dart';

import '../../helpers/test_harness.dart';

class StaticAuthController extends AuthController {
  StaticAuthController()
    : super(
        api: FakeAuthApi(user: buildTestUser()),
        sessionStorage: MemorySessionStorage(
          buildStoredSession(buildTestUser()),
        ),
      ) {
    state = AuthState(
      status: AuthStatus.authenticated,
      user: buildTestUser(),
      accessToken: 'token-123',
      refreshToken: 'refresh-123',
    );
  }
}

class InMemoryCreateStoryDraftStore implements CreateStoryWizardDraftStore {
  @override
  Future<void> clear(String userId) async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<CreateStoryWizardDraft?> read(String userId) async => null;

  @override
  Future<void> save(CreateStoryWizardDraft draft) async {}
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

class StoryVaultSingleFlowApi extends FakeStoryApi {
  StoryVaultSingleFlowApi({
    required this.collectionsSequence,
    required this.detailSequences,
    this.continueHandler,
    this.duplicateHandler,
    required super.virtues,
  }) : super(
         collections: collectionsSequence.isEmpty
             ? const <StoryVaultCollectionItem>[]
             : collectionsSequence.first,
       );

  final List<List<StoryVaultCollectionItem>> collectionsSequence;
  final Map<String, List<StoryVaultCollectionDetail>> detailSequences;
  final Future<StorySessionModel> Function(String sourceStoryId)?
  continueHandler;
  final Future<StorySessionModel> Function(
    String sourceStoryId,
    String? childProfileId,
  )?
  duplicateHandler;

  int listCollectionsCalls = 0;
  int continueCalls = 0;
  int duplicateCalls = 0;
  int getDetailCalls = 0;
  String? lastContinueSourceStoryId;
  String? lastDuplicateSourceStoryId;
  String? lastDuplicateChildId;
  final Map<String, int> _detailIndexes = <String, int>{};

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
    listCollectionsCalls += 1;
    if (collectionsSequence.isEmpty) {
      return const <StoryVaultCollectionItem>[];
    }
    final index = listCollectionsCalls - 1;
    if (index >= collectionsSequence.length) {
      return collectionsSequence.last;
    }
    return collectionsSequence[index];
  }

  @override
  Future<StoryVaultCollectionDetail> getStoryVaultCollection(
    String accessToken,
    String collectionId,
  ) async {
    getDetailCalls += 1;
    final details = detailSequences[collectionId];
    if (details == null || details.isEmpty) {
      throw StateError('No detail sequence registered for $collectionId.');
    }
    final currentIndex = _detailIndexes[collectionId] ?? 0;
    final nextIndex = currentIndex + 1;
    _detailIndexes[collectionId] = nextIndex;
    if (currentIndex >= details.length) {
      return details.last;
    }
    return details[currentIndex];
  }

  @override
  Future<StorySessionModel> continueStory(
    String accessToken,
    String storyId, {
    String? titleDraft,
  }) async {
    continueCalls += 1;
    lastContinueSourceStoryId = storyId;
    final handler = continueHandler;
    if (handler == null) {
      throw const ApiException(
        kind: ApiErrorKind.unknown,
        message: 'continueStory not configured for this test.',
      );
    }
    return handler(storyId);
  }

  @override
  Future<StorySessionModel> duplicateStoryAsTemplate(
    String accessToken,
    String storyId, {
    String? childProfileId,
  }) async {
    duplicateCalls += 1;
    lastDuplicateSourceStoryId = storyId;
    lastDuplicateChildId = childProfileId;
    final handler = duplicateHandler;
    if (handler == null) {
      throw const ApiException(
        kind: ApiErrorKind.unknown,
        message: 'duplicateStoryAsTemplate not configured for this test.',
      );
    }
    return handler(storyId, childProfileId);
  }
}

StoryVaultLatestEpisode _latestEpisode({
  required String storyId,
  required int episodeNumber,
  required StoryStatus status,
}) {
  return StoryVaultLatestEpisode(
    storyId: storyId,
    episodeNumber: episodeNumber,
    title: 'Capítulo $episodeNumber',
    status: status,
    updatedAt: DateTime(2026, 3, 4, 10, 0),
    currentStepIndex: 1,
  );
}

StoryVaultCollectionItem _collection({
  required String id,
  required String title,
  required int draftCount,
  required int episodesCount,
  StoryVaultLatestEpisode? latestEpisode,
}) {
  return StoryVaultCollectionItem(
    id: id,
    title: title,
    theme: 'Mistério',
    virtue: null,
    isFavorite: false,
    child: const StoryVaultChild(id: 'child-1', name: 'Lia'),
    episodesCount: episodesCount,
    publishedCount: draftCount == 0 ? episodesCount : episodesCount - 1,
    draftCount: draftCount,
    lastReferenceAt: DateTime(2026, 3, 4, 10, 0),
    latestEpisode: latestEpisode,
  );
}

StoryVaultEpisodeDetail _detailEpisode({
  required String storyId,
  required int episodeNumber,
  required StoryStatus status,
}) {
  final updatedAt = DateTime(
    2026,
    3,
    4,
    10,
    0,
  ).add(Duration(minutes: episodeNumber));
  return StoryVaultEpisodeDetail(
    storyId: storyId,
    episodeNumber: episodeNumber,
    title: 'Capítulo $episodeNumber',
    titleDraft: 'Capítulo $episodeNumber',
    titleFinal: null,
    status: status,
    publishedAt: status == StoryStatus.published ? updatedAt : null,
    updatedAt: updatedAt,
    currentStepIndex: episodeNumber,
    scenario: 'Floresta',
    objective: 'Resolver um enigma',
    characters: const <StoryCharacterModel>[
      StoryCharacterModel(id: 'char-1', name: 'Lia'),
    ],
    steps: const <StoryStepModel>[],
  );
}

StoryVaultCollectionDetail _detail({
  required String collectionId,
  required String title,
  required List<StoryVaultEpisodeDetail> episodes,
}) {
  return StoryVaultCollectionDetail(
    id: collectionId,
    title: title,
    theme: 'Mistério',
    virtue: null,
    isFavorite: false,
    templateFromStoryId: null,
    lastReferenceAt: DateTime(2026, 3, 4, 10, 0),
    createdAt: DateTime(2026, 3, 1, 10, 0),
    updatedAt: DateTime(2026, 3, 4, 10, 0),
    child: const StoryVaultChild(id: 'child-1', name: 'Lia'),
    episodes: episodes,
  );
}

StorySessionModel _session(String storyId) {
  return StorySessionModel(
    id: storyId,
    childProfileId: 'child-1',
    collectionId: 'collection-1',
    episodeNumber: 1,
    sessionKind: StorySessionKind.presencial,
    titleDraft: 'Aventura',
    title: 'Aventura',
    theme: 'Mistério',
    scenario: 'Floresta',
    objective: 'Resolver um enigma',
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
      StoryCharacterModel(id: 'char-1', name: 'Lia'),
    ],
    steps: const <StoryStepModel>[],
  );
}

Future<void> _pumpVaultFlowApp(
  WidgetTester tester, {
  required ProviderContainer container,
  required String initialLocation,
}) async {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: StoryVaultScreen()),
      ),
      GoRoute(
        path: AppRoute.vaultDetailPattern,
        builder: (context, state) {
          final collectionId = state.pathParameters['id'] ?? '';
          return StoryVaultCollectionRedirectScreen(collectionId: collectionId);
        },
      ),
      GoRoute(
        path: AppRoute.storyRoomPattern,
        builder: (context, state) {
          final storyId = state.pathParameters['id'] ?? '';
          return Scaffold(body: Center(child: Text('room:$storyId')));
        },
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(0.8)),
      child: UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          routerConfig: router,
        ),
      ),
    ),
  );
}

Future<void> _pumpUntilVisible(
  WidgetTester tester,
  Finder finder, {
  int maxTicks = 80,
}) async {
  for (var tick = 0; tick < maxTicks; tick += 1) {
    await tester.pump(const Duration(milliseconds: 16));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  throw StateError('Widget not visible after pumping: $finder');
}

Future<void> _tapAndAdvance(
  WidgetTester tester,
  Finder finder, {
  int frames = 30,
}) async {
  await tester.tap(finder);
  for (var index = 0; index < frames; index += 1) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<Finder> _ensureFirstStoryCardVisible(WidgetTester tester) async {
  final storyCard = find
      .byType(ViscondeStoryRowCard, skipOffstage: false)
      .first;
  await tester.scrollUntilVisible(
    storyCard,
    320,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump(const Duration(milliseconds: 50));
  return storyCard;
}

ProviderContainer _containerForApi(StoryVaultSingleFlowApi api) {
  final container = ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith((ref) => StaticAuthController()),
      childrenApiProvider.overrideWith(
        (ref) => FakeChildrenApi(
          children: [
            ChildProfile(
              id: 'child-1',
              name: 'Lia',
              birthDate: DateTime(2018, 1, 1),
              favoriteThemes: const <String>['Mistério'],
              isArchived: false,
            ),
          ],
        ),
      ),
      storyApiProvider.overrideWith((ref) => api),
      createStoryWizardDraftStoreProvider.overrideWithValue(
        InMemoryCreateStoryDraftStore(),
      ),
      uxAnalyticsServiceProvider.overrideWith(
        (ref) => UxAnalyticsService(
          store: NoopUxStore(),
          transport: NoopUxTransport(),
          readAccessToken: () => null,
        ),
      ),
    ],
  );
  return container;
}

void main() {
  testWidgets('card com draft abre sala direto sem continueStory', (
    tester,
  ) async {
    final api = StoryVaultSingleFlowApi(
      collectionsSequence: [
        [
          _collection(
            id: 'collection-1',
            title: 'Mistério na Floresta',
            draftCount: 1,
            episodesCount: 2,
            latestEpisode: _latestEpisode(
              storyId: 'story-draft',
              episodeNumber: 2,
              status: StoryStatus.draft,
            ),
          ),
        ],
      ],
      detailSequences: {
        'collection-1': [
          _detail(
            collectionId: 'collection-1',
            title: 'Mistério na Floresta',
            episodes: [
              _detailEpisode(
                storyId: 'story-published',
                episodeNumber: 1,
                status: StoryStatus.published,
              ),
              _detailEpisode(
                storyId: 'story-draft',
                episodeNumber: 2,
                status: StoryStatus.draft,
              ),
            ],
          ),
        ],
      },
      virtues: const <VirtueModel>[],
    );
    final container = _containerForApi(api);
    addTearDown(container.dispose);

    await _pumpVaultFlowApp(tester, container: container, initialLocation: '/');
    await _pumpUntilVisible(
      tester,
      find.byType(ViscondeStoryRowCard, skipOffstage: false),
    );
    final storyCard = await _ensureFirstStoryCardVisible(tester);

    await _tapAndAdvance(tester, storyCard);

    expect(api.continueCalls, 0);
    expect(find.text('room:story-draft'), findsOneWidget);
  });

  testWidgets('card sem draft chama continueStory e abre criada', (
    tester,
  ) async {
    final api = StoryVaultSingleFlowApi(
      collectionsSequence: [
        [
          _collection(
            id: 'collection-1',
            title: 'Castelo Encantado',
            draftCount: 0,
            episodesCount: 1,
            latestEpisode: _latestEpisode(
              storyId: 'story-published',
              episodeNumber: 1,
              status: StoryStatus.published,
            ),
          ),
        ],
      ],
      detailSequences: {
        'collection-1': [
          _detail(
            collectionId: 'collection-1',
            title: 'Castelo Encantado',
            episodes: [
              _detailEpisode(
                storyId: 'story-published',
                episodeNumber: 1,
                status: StoryStatus.published,
              ),
            ],
          ),
        ],
      },
      continueHandler: (sourceStoryId) async => _session('story-created'),
      virtues: const <VirtueModel>[],
    );
    final container = _containerForApi(api);
    addTearDown(container.dispose);

    await _pumpVaultFlowApp(tester, container: container, initialLocation: '/');
    await _pumpUntilVisible(
      tester,
      find.byType(ViscondeStoryRowCard, skipOffstage: false),
    );
    final storyCard = await _ensureFirstStoryCardVisible(tester);

    await _tapAndAdvance(tester, storyCard);

    expect(api.continueCalls, 1);
    expect(api.lastContinueSourceStoryId, 'story-published');
    expect(find.text('room:story-created'), findsOneWidget);
  });

  testWidgets(
    'erro STORY_COLLECTION_DRAFT_EXISTS recarrega lista e abre draft',
    (tester) async {
      final api = StoryVaultSingleFlowApi(
        collectionsSequence: [
          [
            _collection(
              id: 'collection-1',
              title: 'Viagem ao Espaço',
              draftCount: 0,
              episodesCount: 1,
              latestEpisode: _latestEpisode(
                storyId: 'story-published',
                episodeNumber: 1,
                status: StoryStatus.published,
              ),
            ),
          ],
          [
            _collection(
              id: 'collection-1',
              title: 'Viagem ao Espaço',
              draftCount: 1,
              episodesCount: 2,
              latestEpisode: _latestEpisode(
                storyId: 'story-draft',
                episodeNumber: 2,
                status: StoryStatus.draft,
              ),
            ),
          ],
        ],
        detailSequences: {
          'collection-1': [
            _detail(
              collectionId: 'collection-1',
              title: 'Viagem ao Espaço',
              episodes: [
                _detailEpisode(
                  storyId: 'story-published',
                  episodeNumber: 1,
                  status: StoryStatus.published,
                ),
              ],
            ),
          ],
        },
        continueHandler: (sourceStoryId) async {
          throw const ApiException(
            kind: ApiErrorKind.conflict,
            message: 'Já existe rascunho.',
            statusCode: 409,
            code: 'STORY_COLLECTION_DRAFT_EXISTS',
          );
        },
        virtues: const <VirtueModel>[],
      );
      final container = _containerForApi(api);
      addTearDown(container.dispose);

      await _pumpVaultFlowApp(
        tester,
        container: container,
        initialLocation: '/',
      );
      await _pumpUntilVisible(
        tester,
        find.byType(ViscondeStoryRowCard, skipOffstage: false),
      );
      final storyCard = await _ensureFirstStoryCardVisible(tester);

      await _tapAndAdvance(tester, storyCard);

      expect(api.continueCalls, 1);
      expect(api.listCollectionsCalls, greaterThanOrEqualTo(2));
      expect(find.text('room:story-draft'), findsOneWidget);
    },
  );

  testWidgets('saga sem episódios mostra snackbar amigável', (tester) async {
    final api = StoryVaultSingleFlowApi(
      collectionsSequence: [
        [
          _collection(
            id: 'collection-1',
            title: 'Saga vazia',
            draftCount: 0,
            episodesCount: 0,
          ),
        ],
      ],
      detailSequences: {
        'collection-1': [
          _detail(
            collectionId: 'collection-1',
            title: 'Saga vazia',
            episodes: [],
          ),
        ],
      },
      virtues: const <VirtueModel>[],
    );
    final container = _containerForApi(api);
    addTearDown(container.dispose);

    await _pumpVaultFlowApp(tester, container: container, initialLocation: '/');
    await _pumpUntilVisible(
      tester,
      find.byType(ViscondeStoryRowCard, skipOffstage: false),
    );
    final storyCard = await _ensureFirstStoryCardVisible(tester);

    await _tapAndAdvance(tester, storyCard);

    expect(
      find.text('Esta saga ainda não possui capítulos para continuar.'),
      findsOneWidget,
    );
    expect(find.textContaining('room:'), findsNothing);
  });

  testWidgets('bottom sheet de ações abre capítulo selecionado', (
    tester,
  ) async {
    final api = StoryVaultSingleFlowApi(
      collectionsSequence: [
        [
          _collection(
            id: 'collection-1',
            title: 'Castelo Encantado',
            draftCount: 1,
            episodesCount: 2,
            latestEpisode: _latestEpisode(
              storyId: 'story-draft',
              episodeNumber: 2,
              status: StoryStatus.draft,
            ),
          ),
        ],
      ],
      detailSequences: {
        'collection-1': [
          _detail(
            collectionId: 'collection-1',
            title: 'Castelo Encantado',
            episodes: [
              _detailEpisode(
                storyId: 'story-1',
                episodeNumber: 1,
                status: StoryStatus.published,
              ),
              _detailEpisode(
                storyId: 'story-2',
                episodeNumber: 2,
                status: StoryStatus.draft,
              ),
            ],
          ),
        ],
      },
      virtues: const <VirtueModel>[],
    );
    final container = _containerForApi(api);
    addTearDown(container.dispose);

    await _pumpVaultFlowApp(tester, container: container, initialLocation: '/');
    await _pumpUntilVisible(
      tester,
      find.byType(ViscondeStoryRowCard, skipOffstage: false),
    );
    await _ensureFirstStoryCardVisible(tester);

    final actionsButton = find.byTooltip('Ações da saga', skipOffstage: false);
    await tester.scrollUntilVisible(
      actionsButton.first,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 50));

    await _tapAndAdvance(tester, actionsButton.first);
    await _pumpUntilVisible(tester, find.text('Capítulos'));

    await _tapAndAdvance(tester, find.text('Ep 2 · Capítulo 2'));

    expect(find.text('room:story-2'), findsOneWidget);
  });

  testWidgets('bottom sheet repetir aventura cria cópia e abre sala', (
    tester,
  ) async {
    final api = StoryVaultSingleFlowApi(
      collectionsSequence: [
        [
          _collection(
            id: 'collection-1',
            title: 'Castelo Encantado',
            draftCount: 1,
            episodesCount: 2,
            latestEpisode: _latestEpisode(
              storyId: 'story-draft',
              episodeNumber: 2,
              status: StoryStatus.draft,
            ),
          ),
        ],
      ],
      detailSequences: {
        'collection-1': [
          _detail(
            collectionId: 'collection-1',
            title: 'Castelo Encantado',
            episodes: [
              _detailEpisode(
                storyId: 'story-1',
                episodeNumber: 1,
                status: StoryStatus.published,
              ),
              _detailEpisode(
                storyId: 'story-2',
                episodeNumber: 2,
                status: StoryStatus.draft,
              ),
            ],
          ),
        ],
      },
      duplicateHandler: (sourceStoryId, childProfileId) async =>
          _session('story-duplicate'),
      virtues: const <VirtueModel>[],
    );
    final container = _containerForApi(api);
    addTearDown(container.dispose);

    await _pumpVaultFlowApp(tester, container: container, initialLocation: '/');
    await _pumpUntilVisible(
      tester,
      find.byType(ViscondeStoryRowCard, skipOffstage: false),
    );
    await _ensureFirstStoryCardVisible(tester);

    final actionsButton = find.byTooltip('Ações da saga', skipOffstage: false);
    await tester.scrollUntilVisible(
      actionsButton.first,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 50));

    await _tapAndAdvance(tester, actionsButton.first);
    await _pumpUntilVisible(tester, find.text('Repetir aventura'));

    await _tapAndAdvance(tester, find.text('Repetir aventura'));
    await _pumpUntilVisible(tester, find.text('Criar template'));

    await _tapAndAdvance(tester, find.text('Criar template'));

    expect(api.duplicateCalls, 1);
    expect(api.lastDuplicateSourceStoryId, 'story-2');
    expect(find.text('room:story-duplicate'), findsOneWidget);
  });

  testWidgets('rota /vault/:id redireciona para sala', (tester) async {
    final api = StoryVaultSingleFlowApi(
      collectionsSequence: [
        [
          _collection(
            id: 'collection-1',
            title: 'Mistério na Floresta',
            draftCount: 1,
            episodesCount: 2,
            latestEpisode: _latestEpisode(
              storyId: 'story-draft',
              episodeNumber: 2,
              status: StoryStatus.draft,
            ),
          ),
        ],
      ],
      detailSequences: {
        'collection-1': [
          _detail(
            collectionId: 'collection-1',
            title: 'Mistério na Floresta',
            episodes: [
              _detailEpisode(
                storyId: 'story-published',
                episodeNumber: 1,
                status: StoryStatus.published,
              ),
              _detailEpisode(
                storyId: 'story-draft',
                episodeNumber: 2,
                status: StoryStatus.draft,
              ),
            ],
          ),
        ],
      },
      virtues: const <VirtueModel>[],
    );
    final container = _containerForApi(api);
    addTearDown(container.dispose);

    await _pumpVaultFlowApp(
      tester,
      container: container,
      initialLocation: AppRoute.vaultDetail('collection-1'),
    );
    await _pumpUntilVisible(tester, find.text('room:story-draft'));

    expect(find.text('room:story-draft'), findsOneWidget);
  });

  testWidgets('rota /vault/:id com falha mostra CTA para voltar ao Baú', (
    tester,
  ) async {
    final api = StoryVaultSingleFlowApi(
      collectionsSequence: [const <StoryVaultCollectionItem>[]],
      detailSequences: {
        'collection-1': [
          _detail(
            collectionId: 'collection-1',
            title: 'Coleção vazia',
            episodes: const <StoryVaultEpisodeDetail>[],
          ),
        ],
      },
      virtues: const <VirtueModel>[],
    );
    final container = _containerForApi(api);
    addTearDown(container.dispose);

    await _pumpVaultFlowApp(
      tester,
      container: container,
      initialLocation: AppRoute.vaultDetail('collection-1'),
    );
    await _pumpUntilVisible(
      tester,
      find.text('Não foi possível abrir a história'),
    );

    expect(find.text('Voltar ao Baú'), findsOneWidget);
  });
}
