import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visconde_app/app/app.dart';
import 'package:visconde_app/app/app_route.dart';
import 'package:visconde_app/app/router.dart';
import 'package:visconde_app/core/models/child_profile.dart';
import 'package:visconde_app/features/auth/auth_controller.dart';
import 'package:visconde_app/features/auth/ui/login_screen.dart';
import 'package:visconde_app/features/story_room/models/story_models.dart';
import 'package:visconde_app/shared/providers.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets('redirects to login preserving from query when session expires', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));

    final virtues = [
      const VirtueModel(
        id: 'v1',
        slug: 'coragem',
        name: 'Coragem',
        shortDescription: 'Seguir em frente',
        iconKey: 'courage',
        sortOrder: 1,
      ),
    ];

    final collections = [
      StoryVaultCollectionItem(
        id: 'col-1',
        title: 'Mistério na Floresta',
        theme: 'Aventura',
        virtue: virtues.first,
        isFavorite: true,
        child: const StoryVaultChild(id: 'child-1', name: 'Lucas'),
        episodesCount: 2,
        publishedCount: 1,
        draftCount: 1,
        lastReferenceAt: DateTime(2026, 2, 26, 18, 30),
      ),
    ];

    final children = [
      ChildProfile(
        id: 'child-1',
        name: 'Lucas',
        birthDate: DateTime(2018, 1, 1),
        favoriteThemes: const ['Aventura'],
        isArchived: false,
      ),
    ];

    final container = ProviderContainer(
      overrides: [
        ...authOverrides(user: buildTestUser(), authenticated: true),
        childrenApiProvider.overrideWith(
          (ref) => FakeChildrenApi(children: children),
        ),
        storyApiProvider.overrideWith(
          (ref) => FakeStoryApi(collections: collections, virtues: virtues),
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
    router.go(AppRoute.storyCreate);
    await tester.pump();

    final beforeExpire = router.routeInformationProvider.value.uri.toString();
    expect(beforeExpire, AppRoute.storyCreate);

    await container
        .read(authControllerProvider.notifier)
        .expireSession(reason: 'Sua sessão expirou. Faça login novamente.');
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    final afterExpire = router.routeInformationProvider.value.uri.toString();
    expect(afterExpire.startsWith(AppRoute.login), isTrue);
    expect(afterExpire.contains('from=%2Fstories%2Fnew'), isTrue);
  });
}
