import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:visconde_app/app/app.dart';
import 'package:visconde_app/app/router.dart';
import 'package:visconde_app/core/models/child_profile.dart';
import 'package:visconde_app/features/story_creation/ui/create_story_screen.dart';
import 'package:visconde_app/features/story_room/models/story_models.dart';
import 'package:visconde_app/features/story_room/ui/story_room_screen.dart';
import 'package:visconde_app/features/story_room/ui/story_summary_screen.dart';
import 'package:visconde_app/features/story_vault/ui/story_vault_screen.dart';
import 'package:visconde_app/shared/providers.dart';
import 'package:visconde_app/shared/ux_analytics.dart';
import 'package:visconde_app/shared/ux_analytics_api.dart';
import 'package:visconde_app/shared/ux_analytics_queue.dart';
import 'package:visconde_app/shared/ux_analytics_service.dart';

import 'helpers/test_harness.dart';

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

void main() {
  testWidgets('navigation smoke: home -> create -> room -> summary -> vault', (
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
        episodesCount: 4,
        publishedCount: 3,
        draftCount: 1,
        lastReferenceAt: DateTime(2026, 2, 26, 18, 30),
        latestEpisode: StoryVaultLatestEpisode(
          storyId: 'story-test',
          episodeNumber: 4,
          title: 'Capítulo 4',
          status: StoryStatus.draft,
          updatedAt: DateTime(2026, 2, 26, 18, 30),
          currentStepIndex: 5,
        ),
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
    expect(find.byType(StoryVaultScreen), findsOneWidget);

    final router = container.read(appRouterProvider);

    router.go('/stories/new');
    await tester.pumpAndSettle();
    expect(find.byType(CreateStoryScreen), findsOneWidget);

    router.go('/stories/new?resume=1');
    await tester.pumpAndSettle();
    expect(find.byType(CreateStoryScreen), findsOneWidget);

    router.go('/stories/story-test/room');
    await tester.pumpAndSettle();
    expect(find.byType(StoryRoomScreen), findsOneWidget);

    router.go('/stories/story-test/summary');
    await tester.pumpAndSettle();
    expect(find.byType(StorySummaryScreen), findsOneWidget);

    router.go('/');
    await tester.pumpAndSettle();
    expect(find.byType(StoryVaultScreen), findsOneWidget);

    router.go('/?tab=game');
    await tester.pumpAndSettle();
    expect(find.text('Game'), findsWidgets);
  });
}
