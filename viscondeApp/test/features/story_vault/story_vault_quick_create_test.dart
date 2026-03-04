import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:visconde_app/app/app.dart';
import 'package:visconde_app/core/models/child_profile.dart';
import 'package:visconde_app/features/story_creation/ui/create_story_screen.dart';
import 'package:visconde_app/features/story_room/models/story_models.dart';
import 'package:visconde_app/shared/providers.dart';
import 'package:visconde_app/shared/ux_analytics.dart';
import 'package:visconde_app/shared/ux_analytics_api.dart';
import 'package:visconde_app/shared/ux_analytics_queue.dart';
import 'package:visconde_app/shared/ux_analytics_service.dart';

import '../../helpers/test_harness.dart';

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

void main() {
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

  testWidgets('Criar Aventura abre o fluxo detalhado', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));

    final container = ProviderContainer(
      overrides: [
        ...authOverrides(user: buildTestUser(), authenticated: true),
        childrenApiProvider.overrideWith(
          (ref) => FakeChildrenApi(children: children),
        ),
        storyApiProvider.overrideWith(
          (ref) => FakeStoryApi(
            collections: const <StoryVaultCollectionItem>[],
            virtues: virtues,
          ),
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

    await tester.tap(find.text('Criar Aventura').first);
    await tester.pumpAndSettle();

    expect(find.byType(CreateStoryScreen), findsOneWidget);
  });

  testWidgets('Baú não mostra CTA de criação rápida', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));

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

    expect(find.textContaining('Criar história rápida'), findsNothing);
    expect(find.text('Criar Aventura'), findsAtLeastNWidgets(1));
  });
}
