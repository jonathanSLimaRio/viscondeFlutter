import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:visconde_app/app/app_route.dart';
import 'package:visconde_app/core/models/child_profile.dart';
import 'package:visconde_app/design_system/visconde.dart';
import 'package:visconde_app/features/gamification/game_adventure_session_controller.dart';
import 'package:visconde_app/features/gamification/ui/game_blank_screen.dart';
import 'package:visconde_app/features/profile/ui/home_shell_screen.dart';
import 'package:visconde_app/features/story_room/models/story_models.dart';
import 'package:visconde_app/shared/providers.dart';

import '../../helpers/test_harness.dart';

ProviderContainer _buildContainer({
  List<Override> extraOverrides = const <Override>[],
}) {
  final user = buildTestUser();
  const virtues = <VirtueModel>[
    VirtueModel(
      id: 'virtue-1',
      slug: 'coragem',
      name: 'Coragem',
      shortDescription: 'Seguir em frente',
      iconKey: 'courage',
      sortOrder: 1,
    ),
  ];

  final collections = <StoryVaultCollectionItem>[
    StoryVaultCollectionItem(
      id: 'collection-1',
      title: 'Aventura de Teste',
      theme: 'Aventura',
      virtue: virtues.first,
      isFavorite: false,
      child: const StoryVaultChild(id: 'child-1', name: 'Lia'),
      episodesCount: 1,
      publishedCount: 0,
      draftCount: 1,
      lastReferenceAt: DateTime(2026, 3, 1),
      latestEpisode: StoryVaultLatestEpisode(
        storyId: 'story-1',
        episodeNumber: 1,
        title: 'Episódio 1',
        status: StoryStatus.draft,
        updatedAt: DateTime(2026, 3, 1),
        currentStepIndex: 1,
      ),
    ),
  ];

  final children = <ChildProfile>[
    ChildProfile(
      id: 'child-1',
      name: 'Lia',
      birthDate: DateTime(2018, 1, 1),
      favoriteThemes: const <String>['Aventura'],
      isArchived: false,
    ),
  ];

  return ProviderContainer(
    overrides: <Override>[
      ...authOverrides(user: user),
      childrenApiProvider.overrideWith(
        (ref) => FakeChildrenApi(children: children),
      ),
      storyApiProvider.overrideWith(
        (ref) => FakeStoryApi(
          collections: collections,
          virtues: virtues,
          listItems: <StoryListItem>[
            StoryListItem(
              id: 'story-1',
              collectionId: 'collection-1',
              episodeNumber: 1,
              title: 'Aventura de Teste',
              status: StoryStatus.draft,
              sessionKind: StorySessionKind.presencial,
              childName: 'Lia',
              currentStepIndex: 1,
              stepsCount: 1,
              updatedAt: DateTime(2026, 3, 1),
            ),
          ],
        ),
      ),
      ...extraOverrides,
    ],
  );
}

Widget _buildApp(ProviderContainer container, GoRouter router) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: ViscondeTheme.buildLightTheme(),
      routerConfig: router,
    ),
  );
}

GoRouter _buildRouter({HomeTab initialTab = HomeTab.stories}) {
  return GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (context, state) => HomeShellScreen(initialTab: initialTab),
      ),
      GoRoute(
        path: AppRoute.avatarEditor,
        builder: (context, state) => Scaffold(
          body: Center(
            child: Text(
              'Avatar source: ${state.uri.queryParameters['source'] ?? ''}',
              key: const ValueKey<String>('avatar_route_label'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: AppRoute.storyRoomPattern,
        builder: (context, state) => Scaffold(
          body: Center(
            child: Text(
              'Story route: ${state.pathParameters['id']}',
              key: const ValueKey<String>('story_route_label'),
            ),
          ),
        ),
      ),
    ],
  );
}

void main() {
  testWidgets('renderiza logo e título Visconde no header', (tester) async {
    final container = _buildContainer();
    final router = _buildRouter();
    addTearDown(container.dispose);
    addTearDown(router.dispose);

    await tester.pumpWidget(_buildApp(container, router));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('home_header_logo')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('home_header_title')),
      findsOneWidget,
    );
    expect(find.text('Visconde'), findsOneWidget);
  });

  testWidgets('footer Avatares abre rota com source home_footer', (
    tester,
  ) async {
    final container = _buildContainer();
    final router = _buildRouter();
    addTearDown(container.dispose);
    addTearDown(router.dispose);

    await tester.pumpWidget(_buildApp(container, router));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('home_footer_avatars')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('avatar_route_label')),
      findsOneWidget,
    );
    expect(find.text('Avatar source: home_footer'), findsOneWidget);
  });

  testWidgets('footer Game abre última aventura quando storyId existe', (
    tester,
  ) async {
    final container = _buildContainer(
      extraOverrides: <Override>[
        gameAdventureSessionControllerProvider.overrideWith((ref) {
          final controller = GameAdventureSessionController();
          controller.setFromStory(
            storyId: 'story-last-opened',
            title: 'Aventura guardada',
            childProfileId: 'child-1',
            theme: 'Aventura',
            biome: 'FOREST',
          );
          return controller;
        }),
      ],
    );
    final router = _buildRouter();
    addTearDown(container.dispose);
    addTearDown(router.dispose);

    await tester.pumpWidget(_buildApp(container, router));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('home_footer_game')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('story_route_label')),
      findsOneWidget,
    );
    expect(find.text('Story route: story-last-opened'), findsOneWidget);
  });

  testWidgets('footer Game mantém aba game quando não há storyId', (
    tester,
  ) async {
    final container = _buildContainer();
    final router = _buildRouter();
    addTearDown(container.dispose);
    addTearDown(router.dispose);

    await tester.pumpWidget(_buildApp(container, router));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('home_footer_game')));
    await tester.pumpAndSettle();

    expect(find.byType(GameBlankScreen), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('story_route_label')),
      findsNothing,
    );
  });
}
