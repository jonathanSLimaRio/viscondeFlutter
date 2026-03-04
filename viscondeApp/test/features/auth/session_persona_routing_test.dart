import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:visconde_app/app/app.dart';
import 'package:visconde_app/app/app_route.dart';
import 'package:visconde_app/app/router.dart';
import 'package:visconde_app/core/models/child_profile.dart';
import 'package:visconde_app/features/auth/auth_controller.dart';
import 'package:visconde_app/features/auth/session_persona_controller.dart';
import 'package:visconde_app/features/auth/ui/session_persona_screen.dart';
import 'package:visconde_app/features/profile/ui/home_shell_screen.dart';
import 'package:visconde_app/features/security/ui/virtue_reports_screen.dart';
import 'package:visconde_app/features/story_room/models/story_models.dart';
import 'package:visconde_app/shared/providers.dart';
import 'package:visconde_app/shared/ux_analytics.dart';
import 'package:visconde_app/shared/ux_analytics_api.dart';
import 'package:visconde_app/shared/ux_analytics_queue.dart';
import 'package:visconde_app/shared/ux_analytics_service.dart';

import '../../helpers/test_harness.dart';

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

List<StoryVaultCollectionItem> _collections(List<VirtueModel> virtues) {
  return [
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
}

List<ChildProfile> _children() {
  return [
    ChildProfile(
      id: 'child-1',
      name: 'Lucas',
      birthDate: DateTime(2018, 1, 1),
      favoriteThemes: const ['Aventura'],
      isArchived: false,
    ),
  ];
}

void main() {
  testWidgets('authenticated sem persona é redirecionado para seleção', (
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

    final container = ProviderContainer(
      overrides: [
        ...authOverrides(
          user: buildTestUser(),
          authenticated: true,
          selectParentPersonaWhenAuthenticated: false,
        ),
        childrenApiProvider.overrideWith(
          (ref) => FakeChildrenApi(children: _children()),
        ),
        storyApiProvider.overrideWith(
          (ref) => FakeStoryApi(
            collections: _collections(virtues),
            virtues: virtues,
          ),
        ),
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
    final location = router.routeInformationProvider.value.uri.toString();

    expect(location.startsWith(AppRoute.sessionPersona), isTrue);
    expect(find.byType(SessionPersonaScreen), findsOneWidget);
  });

  testWidgets('modo FILHO bloqueia deep link em /adult/*', (tester) async {
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

    final container = ProviderContainer(
      overrides: [
        ...authOverrides(
          user: buildTestUser(),
          authenticated: true,
          sessionPersona: SessionPersona.child,
        ),
        childrenApiProvider.overrideWith(
          (ref) => FakeChildrenApi(children: _children()),
        ),
        storyApiProvider.overrideWith(
          (ref) => FakeStoryApi(
            collections: _collections(virtues),
            virtues: virtues,
          ),
        ),
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

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    expect(find.text('Área do pai'), findsNothing);
    await tester.tapAt(const Offset(420, 120));
    await tester.pumpAndSettle();

    final router = container.read(appRouterProvider);
    router.go(AppRoute.adultVirtueReports);
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.toString(), AppRoute.home);
    expect(find.byType(HomeShellScreen), findsOneWidget);
  });

  testWidgets(
    'com persona escolhida, /session/persona redireciona para from válido',
    (tester) async {
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

      final container = ProviderContainer(
        overrides: [
          ...authOverrides(
            user: buildTestUser(),
            authenticated: true,
            sessionPersona: SessionPersona.parent,
          ),
          childrenApiProvider.overrideWith(
            (ref) => FakeChildrenApi(children: _children()),
          ),
          storyApiProvider.overrideWith(
            (ref) => FakeStoryApi(
              collections: _collections(virtues),
              virtues: virtues,
            ),
          ),
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
      router.go('${AppRoute.sessionPersona}?from=${AppRoute.storyCreate}');
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.toString(),
        AppRoute.storyCreate,
      );
    },
  );

  testWidgets('modo PAI mantém acesso a rotas /adult/*', (tester) async {
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

    final container = ProviderContainer(
      overrides: [
        ...authOverrides(
          user: buildTestUser(),
          authenticated: true,
          sessionPersona: SessionPersona.parent,
        ),
        childrenApiProvider.overrideWith(
          (ref) => FakeChildrenApi(children: _children()),
        ),
        storyApiProvider.overrideWith(
          (ref) => FakeStoryApi(
            collections: _collections(virtues),
            virtues: virtues,
          ),
        ),
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

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    expect(find.text('Área do pai'), findsOneWidget);
    await tester.tapAt(const Offset(420, 120));
    await tester.pumpAndSettle();

    final router = container.read(appRouterProvider);
    router.go(AppRoute.adultVirtueReports);
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.toString(),
      AppRoute.adultVirtueReports,
    );
    expect(find.byType(VirtueReportsScreen), findsOneWidget);
  });

  testWidgets('logout limpa persona da sessão', (tester) async {
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

    final container = ProviderContainer(
      overrides: [
        ...authOverrides(
          user: buildTestUser(),
          authenticated: true,
          sessionPersona: SessionPersona.parent,
        ),
        childrenApiProvider.overrideWith(
          (ref) => FakeChildrenApi(children: _children()),
        ),
        storyApiProvider.overrideWith(
          (ref) => FakeStoryApi(
            collections: _collections(virtues),
            virtues: virtues,
          ),
        ),
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

    expect(
      container.read(sessionPersonaControllerProvider).persona,
      SessionPersona.parent,
    );

    await container.read(authControllerProvider.notifier).logout();
    await tester.pumpAndSettle();

    expect(container.read(sessionPersonaControllerProvider).persona, isNull);
  });
}
