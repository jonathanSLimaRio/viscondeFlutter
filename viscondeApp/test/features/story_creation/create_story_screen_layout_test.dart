import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visconde_app/app/app.dart';
import 'package:visconde_app/app/router.dart';
import 'package:visconde_app/core/models/child_profile.dart';
import 'package:visconde_app/features/story_creation/ui/create_story_screen.dart';
import 'package:visconde_app/features/story_room/illustration_api.dart';
import 'package:visconde_app/features/story_room/models/illustration_models.dart';
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

class _LayoutStoryApi extends FakeStoryApi {
  _LayoutStoryApi({
    required super.collections,
    required super.virtues,
    required this.templates,
  });

  final List<ContentStoryTemplateModel> templates;

  @override
  Future<List<ContentStoryTemplateModel>> listPublishedStoryTemplates(
    String accessToken,
  ) async {
    return templates;
  }
}

class _LayoutIllustrationApi extends IllustrationApi {
  _LayoutIllustrationApi(this.styles) : super(Dio());

  final List<ArtStyleModel> styles;

  @override
  Future<List<ArtStyleModel>> listArtStyles() async => styles;
}

void main() {
  testWidgets('renderiza layout compacto com CTA fixo e card de recomendação', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 700));

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
        slug: 'template-layout',
        title: 'Template Layout',
        description: 'template',
        ageBand: AgeBand.age6_8,
        version: 1,
        defaultScenario: 'Bosque encantado',
        defaultObjective: 'Aprender algo novo',
        theme: StoryNamedRef(id: 'theme-1', slug: 'aventura', name: 'Aventura'),
        virtue: StoryNamedRef(id: 'virtue-1', slug: 'coragem', name: 'Coragem'),
        nodesCount: 3,
        charactersCount: 2,
      ),
    ];

    final container = ProviderContainer(
      overrides: [
        ...authOverrides(user: buildTestUser(), authenticated: true),
        childrenApiProvider.overrideWith(
          (ref) => FakeChildrenApi(children: children),
        ),
        storyApiProvider.overrideWith(
          (ref) => _LayoutStoryApi(
            collections: const <StoryVaultCollectionItem>[],
            virtues: virtues,
            templates: templates,
          ),
        ),
        illustrationApiProvider.overrideWith(
          (ref) => _LayoutIllustrationApi(const <ArtStyleModel>[
            ArtStyleModel(
              id: 'style-1',
              name: 'Aquarela',
              promptTemplate: 'watercolor',
            ),
          ]),
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
    router.go('/stories/new');
    await tester.pumpAndSettle();

    expect(find.byType(CreateStoryScreen), findsOneWidget);
    expect(find.text('Criar nova aventura'), findsOneWidget);
    expect(find.text('Para Lia'), findsOneWidget);
    expect(
      find.byKey(const Key('wizard_recommendation_quick_start_button')),
      findsOneWidget,
    );

    final ctaFinder = find.byKey(const Key('wizard_save_continue_button'));
    expect(ctaFinder, findsOneWidget);
    final cta = tester.widget<FilledButton>(ctaFinder);
    expect(cta.onPressed, isNotNull);

    final ctaRect = tester.getRect(ctaFinder);
    expect(ctaRect.bottom, lessThanOrEqualTo(700));
  });
}
