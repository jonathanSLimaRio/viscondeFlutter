import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:visconde_app/app/app.dart';
import 'package:visconde_app/core/models/child_profile.dart';
import 'package:visconde_app/design_system/visconde.dart';
import 'package:visconde_app/features/children/children_api.dart';
import 'package:visconde_app/features/story_room/models/story_models.dart';
import 'package:visconde_app/shared/providers.dart';
import 'package:visconde_app/shared/ui/ui_state_copy.dart';
import 'package:visconde_app/shared/ux_analytics.dart';
import 'package:visconde_app/shared/ux_analytics_api.dart';
import 'package:visconde_app/shared/ux_analytics_queue.dart';
import 'package:visconde_app/shared/ux_analytics_service.dart';

import '../../helpers/test_harness.dart';

class HangingChildrenApi extends ChildrenApi {
  HangingChildrenApi() : super(Dio());

  @override
  Future<List<ChildProfile>> listChildren(String accessToken) {
    return Completer<List<ChildProfile>>().future;
  }
}

class ErrorStoryApi extends FakeStoryApi {
  ErrorStoryApi({required super.collections, required super.virtues});

  int calls = 0;

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
    calls += 1;
    throw DioException(
      requestOptions: RequestOptions(path: 'story-vault/collections'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: 'story-vault/collections'),
        statusCode: 500,
        data: const <String, dynamic>{'error': 'Boom'},
      ),
      type: DioExceptionType.badResponse,
    );
  }
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

Future<void> _pumpApp(
  WidgetTester tester, {
  required List<Override> overrides,
}) async {
  final container = ProviderContainer(
    overrides: [
      ...overrides,
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
}

void main() {
  final children = <ChildProfile>[
    ChildProfile(
      id: 'child-1',
      name: 'Lia',
      birthDate: DateTime(2018, 1, 1),
      favoriteThemes: const <String>['Aventura'],
      isArchived: false,
    ),
  ];

  testWidgets('renderiza skeleton no carregamento inicial', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));

    await _pumpApp(
      tester,
      overrides: [
        ...authOverrides(user: buildTestUser(), authenticated: true),
        childrenApiProvider.overrideWith((ref) => HangingChildrenApi()),
        storyApiProvider.overrideWith(
          (ref) => FakeStoryApi(
            collections: const <StoryVaultCollectionItem>[],
            virtues: const <VirtueModel>[],
          ),
        ),
      ],
    );

    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byType(ViscondeSkeletonCard, skipOffstage: false),
      findsWidgets,
    );
  });

  testWidgets('empty sem filtro mostra CTAs de criação', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));

    await _pumpApp(
      tester,
      overrides: [
        ...authOverrides(user: buildTestUser(), authenticated: true),
        childrenApiProvider.overrideWith(
          (ref) => FakeChildrenApi(children: children),
        ),
        storyApiProvider.overrideWith(
          (ref) => FakeStoryApi(
            collections: const <StoryVaultCollectionItem>[],
            virtues: const <VirtueModel>[],
          ),
        ),
      ],
    );

    await tester.pumpAndSettle();

    expect(find.text('Filtro'), findsOneWidget);
    expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);
    expect(find.text(UiStateCopy.vaultEmptyTitle), findsOneWidget);
    expect(
      find.textContaining('Criar história rápida'),
      findsAtLeastNWidgets(1),
    );
    expect(find.text('Criar com detalhes'), findsAtLeastNWidgets(1));
  });

  testWidgets('filtro inicia recolhido e expande no acordeon', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));

    await _pumpApp(
      tester,
      overrides: [
        ...authOverrides(user: buildTestUser(), authenticated: true),
        childrenApiProvider.overrideWith(
          (ref) => FakeChildrenApi(children: children),
        ),
        storyApiProvider.overrideWith(
          (ref) => FakeStoryApi(
            collections: const <StoryVaultCollectionItem>[],
            virtues: const <VirtueModel>[],
          ),
        ),
      ],
    );

    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);
    await tester.tap(find.byKey(const Key('vault_filter_accordion_header')));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.expand_less_rounded), findsOneWidget);
    expect(find.text('Somente favoritas'), findsOneWidget);
  });

  testWidgets('empty com filtro mostra opção de limpar filtros', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));

    await _pumpApp(
      tester,
      overrides: [
        ...authOverrides(user: buildTestUser(), authenticated: true),
        childrenApiProvider.overrideWith(
          (ref) => FakeChildrenApi(children: children),
        ),
        storyApiProvider.overrideWith(
          (ref) => FakeStoryApi(
            collections: const <StoryVaultCollectionItem>[],
            virtues: const <VirtueModel>[],
          ),
        ),
      ],
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('vault_filter_accordion_header')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Somente favoritas'));
    await tester.pumpAndSettle();

    expect(find.text(UiStateCopy.vaultFilteredEmptyTitle), findsOneWidget);
    expect(find.text('Limpar filtros'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsAtLeastNWidgets(1));
  });

  testWidgets('erro bloqueante exibe retry', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));

    final errorStoryApi = ErrorStoryApi(
      collections: const <StoryVaultCollectionItem>[],
      virtues: const <VirtueModel>[],
    );

    await _pumpApp(
      tester,
      overrides: [
        ...authOverrides(user: buildTestUser(), authenticated: true),
        childrenApiProvider.overrideWith(
          (ref) => FakeChildrenApi(children: children),
        ),
        storyApiProvider.overrideWith((ref) => errorStoryApi),
      ],
    );

    await tester.pumpAndSettle();

    expect(find.text(UiStateCopy.genericErrorTitle), findsOneWidget);
    expect(find.text('Tentar novamente'), findsAtLeastNWidgets(1));

    final callsBeforeRetry = errorStoryApi.calls;
    await tester.tap(find.text('Tentar novamente').first);
    await tester.pumpAndSettle();

    expect(errorStoryApi.calls, greaterThan(callsBeforeRetry));
  });
}
