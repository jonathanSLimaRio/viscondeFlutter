import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:visconde_app/app/app_route.dart';
import 'package:visconde_app/core/network/api_exception.dart';
import 'package:visconde_app/core/models/child_profile.dart';
import 'package:visconde_app/features/auth/auth_controller.dart';
import 'package:visconde_app/features/story_room/models/story_models.dart';
import 'package:visconde_app/features/story_vault/ui/story_vault_detail_screen.dart';
import 'package:visconde_app/shared/providers.dart';

import '../../helpers/test_harness.dart';

class StoryVaultDetailTestApi extends FakeStoryApi {
  StoryVaultDetailTestApi({required this.detailSequence, this.continueHandler})
    : super(
        collections: const <StoryVaultCollectionItem>[],
        virtues: const <VirtueModel>[],
      );

  final List<StoryVaultCollectionDetail> detailSequence;
  final Future<StorySessionModel> Function(String sourceStoryId)?
  continueHandler;

  int getDetailCalls = 0;
  int continueCalls = 0;
  String? lastContinueSourceStoryId;
  int _detailIndex = 0;

  @override
  Future<StoryVaultCollectionDetail> getStoryVaultCollection(
    String accessToken,
    String collectionId,
  ) async {
    getDetailCalls += 1;
    if (detailSequence.isEmpty) {
      throw StateError('Detail sequence cannot be empty.');
    }
    final index = _detailIndex < detailSequence.length
        ? _detailIndex
        : detailSequence.length - 1;
    _detailIndex += 1;
    return detailSequence[index];
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
      throw StateError('continueStory should not be called in this scenario.');
    }
    return handler(storyId);
  }
}

StoryVaultEpisodeDetail _episode({
  required String storyId,
  required int episodeNumber,
  required StoryStatus status,
  int currentStepIndex = 0,
  DateTime? updatedAt,
}) {
  final reference = updatedAt ?? DateTime(2026, 3, 4, 10, 0);
  return StoryVaultEpisodeDetail(
    storyId: storyId,
    episodeNumber: episodeNumber,
    title: 'Ep $episodeNumber',
    titleDraft: 'Ep $episodeNumber',
    titleFinal: null,
    status: status,
    publishedAt: status == StoryStatus.published ? reference : null,
    updatedAt: reference,
    currentStepIndex: currentStepIndex,
    scenario: 'Floresta',
    objective: 'Ajudar um amigo',
    characters: const <StoryCharacterModel>[
      StoryCharacterModel(id: 'char-1', name: 'Lia'),
    ],
    steps: const <StoryStepModel>[],
  );
}

StoryVaultCollectionDetail _detail({
  required List<StoryVaultEpisodeDetail> episodes,
}) {
  return StoryVaultCollectionDetail(
    id: 'collection-1',
    title: 'Mistério na Floresta',
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
    titleDraft: 'Novo capítulo',
    title: 'Novo capítulo',
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

Future<void> _pumpDetailApp(
  WidgetTester tester, {
  required ProviderContainer container,
}) async {
  await _ensureAuthenticated(container);

  final router = GoRouter(
    initialLocation: AppRoute.vaultDetail('collection-1'),
    routes: [
      GoRoute(
        path: AppRoute.vaultDetailPattern,
        builder: (context, state) {
          final collectionId = state.pathParameters['id'] ?? '';
          return StoryVaultDetailScreen(collectionId: collectionId);
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

Future<void> _ensureAuthenticated(ProviderContainer container) async {
  container.read(authControllerProvider);
  for (var attempt = 0; attempt < 20; attempt += 1) {
    final auth = container.read(authControllerProvider);
    if (auth.status == AuthStatus.authenticated &&
        auth.accessToken != null &&
        auth.accessToken!.isNotEmpty) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  final auth = container.read(authControllerProvider);
  throw StateError(
    'Auth did not become ready for tests. status=${auth.status.name}',
  );
}

void main() {
  final children = <ChildProfile>[
    ChildProfile(
      id: 'child-1',
      name: 'Lia',
      birthDate: DateTime(2018, 1, 1),
      favoriteThemes: const <String>['Mistério'],
      isArchived: false,
    ),
  ];

  ProviderContainer _containerWithApi(StoryVaultDetailTestApi api) {
    final container = ProviderContainer(
      overrides: [
        ...authOverrides(user: buildTestUser(), authenticated: true),
        childrenApiProvider.overrideWith(
          (ref) => FakeChildrenApi(children: children),
        ),
        storyApiProvider.overrideWith((ref) => api),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  testWidgets('com draft existente abre sala direto sem chamar continue', (
    tester,
  ) async {
    final api = StoryVaultDetailTestApi(
      detailSequence: [
        _detail(
          episodes: [
            _episode(
              storyId: 'story-published',
              episodeNumber: 1,
              status: StoryStatus.published,
            ),
            _episode(
              storyId: 'story-draft',
              episodeNumber: 2,
              status: StoryStatus.draft,
            ),
          ],
        ),
      ],
    );
    final container = _containerWithApi(api);

    await _pumpDetailApp(tester, container: container);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continuar aventura'));
    await tester.pumpAndSettle();

    expect(api.continueCalls, 0);
    expect(find.text('room:story-draft'), findsOneWidget);
  });

  testWidgets('sem draft e com publicado cria continuação e navega', (
    tester,
  ) async {
    final api = StoryVaultDetailTestApi(
      detailSequence: [
        _detail(
          episodes: [
            _episode(
              storyId: 'story-published',
              episodeNumber: 1,
              status: StoryStatus.published,
            ),
          ],
        ),
      ],
      continueHandler: (sourceStoryId) async => _session('story-created'),
    );
    final container = _containerWithApi(api);

    await _pumpDetailApp(tester, container: container);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continuar aventura'));
    await tester.pumpAndSettle();

    expect(api.continueCalls, 1);
    expect(api.lastContinueSourceStoryId, 'story-published');
    expect(find.text('room:story-created'), findsOneWidget);
  });

  testWidgets('sem draft e sem publicado mostra snackbar amigável', (
    tester,
  ) async {
    final api = StoryVaultDetailTestApi(
      detailSequence: [
        _detail(
          episodes: [
            _episode(
              storyId: 'story-archived',
              episodeNumber: 1,
              status: StoryStatus.archived,
            ),
          ],
        ),
      ],
    );
    final container = _containerWithApi(api);

    await _pumpDetailApp(tester, container: container);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continuar aventura'));
    await tester.pumpAndSettle();

    expect(api.continueCalls, 0);
    expect(
      find.text('Não há capítulo em andamento ou publicado para continuar.'),
      findsOneWidget,
    );
    expect(find.textContaining('room:'), findsNothing);
  });

  testWidgets('erro STORY_COLLECTION_DRAFT_EXISTS recarrega e abre draft', (
    tester,
  ) async {
    final api = StoryVaultDetailTestApi(
      detailSequence: [
        _detail(
          episodes: [
            _episode(
              storyId: 'story-published',
              episodeNumber: 1,
              status: StoryStatus.published,
            ),
          ],
        ),
        _detail(
          episodes: [
            _episode(
              storyId: 'story-published',
              episodeNumber: 1,
              status: StoryStatus.published,
            ),
            _episode(
              storyId: 'story-draft',
              episodeNumber: 2,
              status: StoryStatus.draft,
            ),
          ],
        ),
      ],
      continueHandler: (sourceStoryId) async {
        throw const ApiException(
          kind: ApiErrorKind.conflict,
          message: 'Já existe um rascunho.',
          statusCode: 409,
          code: 'STORY_COLLECTION_DRAFT_EXISTS',
        );
      },
    );
    final container = _containerWithApi(api);

    await _pumpDetailApp(tester, container: container);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continuar aventura'));
    await tester.pumpAndSettle();

    expect(api.continueCalls, 1);
    expect(api.getDetailCalls, greaterThanOrEqualTo(2));
    expect(find.text('room:story-draft'), findsOneWidget);
  });
}
