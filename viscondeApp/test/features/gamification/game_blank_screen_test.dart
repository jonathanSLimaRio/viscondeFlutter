import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:visconde_app/app/app_route.dart';
import 'package:visconde_app/core/models/child_profile.dart';
import 'package:visconde_app/design_system/visconde.dart';
import 'package:visconde_app/features/gamification/game_adventure_session_controller.dart';
import 'package:visconde_app/features/gamification/ui/game_blank_screen.dart';
import 'package:visconde_app/features/story_room/models/story_models.dart';
import 'package:visconde_app/shared/providers.dart';

import '../../helpers/test_harness.dart';

class CountingChildrenApi extends FakeChildrenApi {
  CountingChildrenApi({required super.children});

  int listChildrenCalls = 0;

  @override
  Future<List<ChildProfile>> listChildren(String accessToken) async {
    listChildrenCalls += 1;
    return super.listChildren(accessToken);
  }
}

void main() {
  testWidgets('exibe estado vazio quando não há crianças cadastradas', (
    tester,
  ) async {
    final user = buildTestUser();

    await tester.pumpWidget(
      wrapTestApp(
        const GameBlankScreen(),
        overrides: [
          ...authOverrides(user: user),
          childrenApiProvider.overrideWith(
            (ref) => FakeChildrenApi(children: const <ChildProfile>[]),
          ),
          storyApiProvider.overrideWith(
            (ref) => FakeStoryApi(
              collections: const <StoryVaultCollectionItem>[],
              virtues: const <VirtueModel>[],
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma criança cadastrada'), findsOneWidget);
  });

  testWidgets('exibe card da aventura ativa no hub game', (tester) async {
    final user = buildTestUser();
    final child = ChildProfile(
      id: 'child-1',
      name: 'Lia',
      birthDate: DateTime(2018, 1, 1),
      favoriteThemes: const <String>['Floresta'],
      isArchived: false,
    );
    final session = StorySessionModel(
      id: 'story-1',
      childProfileId: child.id,
      collectionId: 'col-1',
      episodeNumber: 1,
      sessionKind: StorySessionKind.presencial,
      titleDraft: 'Mistério na Floresta',
      title: 'Mistério na Floresta',
      theme: 'Floresta',
      scenario: 'Bosque mágico',
      objective: 'Ajudar um amigo',
      status: StoryStatus.draft,
      currentMode: StoryMode.parentNarrator,
      currentStepIndex: 1,
      game: StoryGameStateModel(
        mode: 'TRAIL_LINEAR',
        seed: 1,
        mapVersion: 1,
        map: const StoryGameMapModel(
          biome: 'FOREST',
          totalNodes: 12,
          nodes: <StoryGameNodeModel>[],
        ),
      ),
      ageSnapshotYears: 8,
      child: StoryChildSnapshot(
        id: child.id,
        name: child.name,
        birthDate: child.birthDate,
      ),
      characters: const <StoryCharacterModel>[],
      steps: const <StoryStepModel>[],
    );

    await tester.pumpWidget(
      wrapTestApp(
        const GameBlankScreen(),
        overrides: [
          ...authOverrides(user: user),
          childrenApiProvider.overrideWith(
            (ref) => FakeChildrenApi(children: <ChildProfile>[child]),
          ),
          storyApiProvider.overrideWith(
            (ref) => FakeStoryApi(
              collections: const <StoryVaultCollectionItem>[],
              virtues: const <VirtueModel>[],
              session: session,
              listItems: <StoryListItem>[
                StoryListItem(
                  id: 'story-1',
                  collectionId: 'col-1',
                  episodeNumber: 1,
                  title: 'Mistério na Floresta',
                  status: StoryStatus.draft,
                  sessionKind: StorySessionKind.presencial,
                  childName: child.name,
                  currentStepIndex: 1,
                  stepsCount: 1,
                  updatedAt: DateTime.now(),
                ),
              ],
            ),
          ),
          gameAdventureSessionControllerProvider.overrideWith((ref) {
            final controller = GameAdventureSessionController();
            controller.setFromStory(
              storyId: 'story-1',
              title: 'Misterio na Floresta',
            );
            return controller;
          }),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sua aventura está pronta'), findsOneWidget);
    expect(find.text('Mistério na Floresta'), findsOneWidget);
    expect(find.text('Entrar na aventura'), findsOneWidget);
  });

  testWidgets(
    'mantém seletor de criança visível quando não há aventura ativa',
    (tester) async {
      final user = buildTestUser();
      final children = <ChildProfile>[
        ChildProfile(
          id: 'child-1',
          name: 'Lia',
          birthDate: DateTime(2018, 1, 1),
          favoriteThemes: const <String>['Floresta'],
          isArchived: false,
        ),
        ChildProfile(
          id: 'child-2',
          name: 'Ravi',
          birthDate: DateTime(2017, 3, 10),
          favoriteThemes: const <String>['Espaço'],
          isArchived: false,
        ),
      ];

      await tester.pumpWidget(
        wrapTestApp(
          const GameBlankScreen(),
          overrides: [
            ...authOverrides(user: user),
            childrenApiProvider.overrideWith(
              (ref) => FakeChildrenApi(children: children),
            ),
            storyApiProvider.overrideWith(
              (ref) => FakeStoryApi(
                collections: const <StoryVaultCollectionItem>[],
                virtues: const <VirtueModel>[],
                listItems: const <StoryListItem>[],
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nenhuma aventura ativa'), findsOneWidget);
      expect(find.text('Lia'), findsOneWidget);
      expect(find.text('Ravi'), findsOneWidget);
      expect(find.text('Criar aventura'), findsOneWidget);
    },
  );

  testWidgets('recarrega contexto ao voltar do editor de avatar', (
    tester,
  ) async {
    final user = buildTestUser();
    final child = ChildProfile(
      id: 'child-1',
      name: 'Lia',
      birthDate: DateTime(2018, 1, 1),
      favoriteThemes: const <String>['Floresta'],
      isArchived: false,
    );
    final session = StorySessionModel(
      id: 'story-1',
      childProfileId: child.id,
      collectionId: 'col-1',
      episodeNumber: 1,
      sessionKind: StorySessionKind.presencial,
      titleDraft: 'Mistério na Floresta',
      title: 'Mistério na Floresta',
      theme: 'Floresta',
      scenario: 'Bosque mágico',
      objective: 'Ajudar um amigo',
      status: StoryStatus.draft,
      currentMode: StoryMode.parentNarrator,
      currentStepIndex: 1,
      game: StoryGameStateModel(
        mode: 'TRAIL_LINEAR',
        seed: 1,
        mapVersion: 1,
        map: const StoryGameMapModel(
          biome: 'FOREST',
          totalNodes: 12,
          nodes: <StoryGameNodeModel>[],
        ),
      ),
      ageSnapshotYears: 8,
      child: StoryChildSnapshot(
        id: child.id,
        name: child.name,
        birthDate: child.birthDate,
      ),
      characters: const <StoryCharacterModel>[],
      steps: const <StoryStepModel>[],
    );
    final childrenApi = CountingChildrenApi(children: <ChildProfile>[child]);
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const GameBlankScreen(),
        ),
        GoRoute(
          path: AppRoute.avatarEditor,
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Editor Avatar'))),
        ),
        GoRoute(
          path: AppRoute.storyCreate,
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Criar'))),
        ),
        GoRoute(
          path: AppRoute.storyRoomPattern,
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Story Room'))),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...authOverrides(user: user),
          childrenApiProvider.overrideWith((ref) => childrenApi),
          storyApiProvider.overrideWith(
            (ref) => FakeStoryApi(
              collections: const <StoryVaultCollectionItem>[],
              virtues: const <VirtueModel>[],
              session: session,
              listItems: <StoryListItem>[
                StoryListItem(
                  id: 'story-1',
                  collectionId: 'col-1',
                  episodeNumber: 1,
                  title: 'Mistério na Floresta',
                  status: StoryStatus.draft,
                  sessionKind: StorySessionKind.presencial,
                  childName: child.name,
                  currentStepIndex: 1,
                  stepsCount: 1,
                  updatedAt: DateTime.now(),
                ),
              ],
            ),
          ),
          gameAdventureSessionControllerProvider.overrideWith((ref) {
            final controller = GameAdventureSessionController();
            controller.setFromStory(
              storyId: 'story-1',
              title: 'Misterio na Floresta',
            );
            return controller;
          }),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: ViscondeTheme.buildLightTheme(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(childrenApi.listChildrenCalls, 1);

    await tester.tap(find.text('Trocar avatares'));
    await tester.pumpAndSettle();
    expect(find.text('Editor Avatar'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();

    expect(childrenApi.listChildrenCalls, greaterThanOrEqualTo(2));
    expect(find.text('Sua aventura está pronta'), findsOneWidget);
  });
}
