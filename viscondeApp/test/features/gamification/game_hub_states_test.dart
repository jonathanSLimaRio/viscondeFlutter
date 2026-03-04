import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:visconde_app/core/models/child_profile.dart';
import 'package:visconde_app/design_system/visconde.dart';
import 'package:visconde_app/features/auth/auth_controller.dart';
import 'package:visconde_app/features/children/children_api.dart';
import 'package:visconde_app/features/gamification/gamification_api.dart';
import 'package:visconde_app/features/gamification/inventory_api.dart';
import 'package:visconde_app/features/gamification/inventory_models.dart';
import 'package:visconde_app/features/gamification/models/gamification_models.dart';
import 'package:visconde_app/features/gamification/ui/game_hub_screen.dart';
import 'package:visconde_app/shared/providers.dart';
import 'package:visconde_app/shared/ui/ui_state_copy.dart';

import '../../helpers/test_harness.dart';

class HangingChildrenApi extends ChildrenApi {
  HangingChildrenApi() : super(Dio());

  @override
  Future<List<ChildProfile>> listChildren(String accessToken) {
    return Completer<List<ChildProfile>>().future;
  }
}

class FakeGameApi extends GamificationApi {
  FakeGameApi({
    required this.wallet,
    required this.achievements,
    required this.progression,
    required this.catalog,
    this.delay = Duration.zero,
  }) : super(Dio());

  final WalletModel wallet;
  final List<AchievementModel> achievements;
  final ChildProgressionModel progression;
  final List<CatalogItemModel> catalog;
  final Duration delay;

  @override
  Future<WalletModel> fetchWallet(String accessToken) async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    return wallet;
  }

  @override
  Future<List<AchievementModel>> listAchievements(String accessToken) async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    return achievements;
  }

  @override
  Future<ChildProgressionModel> fetchChildProgression(
    String accessToken, {
    required String childId,
  }) async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    return progression;
  }

  @override
  Future<List<CatalogItemModel>> listCatalog(
    String accessToken, {
    required String childProfileId,
    CatalogItemType? type,
  }) async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    return catalog;
  }
}

class ErrorGameApi extends GamificationApi {
  ErrorGameApi() : super(Dio());

  int walletCalls = 0;

  DioException _error() {
    return DioException(
      requestOptions: RequestOptions(path: 'gamification/wallet'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: 'gamification/wallet'),
        statusCode: 500,
        data: const <String, dynamic>{'error': 'Boom'},
      ),
      type: DioExceptionType.badResponse,
    );
  }

  @override
  Future<WalletModel> fetchWallet(String accessToken) async {
    walletCalls += 1;
    throw _error();
  }

  @override
  Future<List<AchievementModel>> listAchievements(String accessToken) async {
    throw _error();
  }

  @override
  Future<ChildProgressionModel> fetchChildProgression(
    String accessToken, {
    required String childId,
  }) async {
    throw _error();
  }

  @override
  Future<List<CatalogItemModel>> listCatalog(
    String accessToken, {
    required String childProfileId,
    CatalogItemType? type,
  }) async {
    throw _error();
  }
}

class FakeInventoryApi extends InventoryApi {
  FakeInventoryApi(this._items, {this.delay = Duration.zero}) : super(Dio());

  final List<ChildInventoryModel> _items;
  final Duration delay;

  @override
  Future<List<ChildInventoryModel>> getChildInventory(
    String childProfileId,
    String accessToken,
  ) async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    return _items;
  }
}

ChildProgressionModel _emptyProgression() {
  return const ChildProgressionModel(
    childProfileId: 'child-1',
    weekKey: '2026-W10',
    streak: StreakModel(currentDays: 0, bestDays: 0, shieldCount: 0),
    weeklyMissions: <WeeklyMissionModel>[],
    inventorySummary: InventorySummaryModel(
      totalUnlocked: 0,
      equippedItems: <EquippedInventoryItemModel>[],
    ),
  );
}

Future<void> _pumpGameHub(
  WidgetTester tester, {
  required List<Override> overrides,
}) async {
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);

  container.read(authControllerProvider);
  for (var i = 0; i < 24; i++) {
    if (container.read(authControllerProvider).status != AuthStatus.loading) {
      break;
    }
    await tester.pump(const Duration(milliseconds: 8));
  }

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ViscondeTheme.buildLightTheme(),
        home: const ViscondeScaffoldBackground(
          child: Scaffold(body: GameHubScreen()),
        ),
      ),
    ),
  );

  final authState = container.read(authControllerProvider);
  expect(authState.status, AuthStatus.authenticated);
  expect(authState.accessToken, isNotNull);
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

    await _pumpGameHub(
      tester,
      overrides: [
        ...authOverrides(user: buildTestUser(), authenticated: true),
        childrenApiProvider.overrideWith((ref) => HangingChildrenApi()),
        gamificationApiProvider.overrideWith(
          (ref) => FakeGameApi(
            wallet: const WalletModel(
              coins: 0,
              stars: 0,
              recentTransactions: <WalletTransactionModel>[],
            ),
            achievements: const <AchievementModel>[],
            progression: _emptyProgression(),
            catalog: const <CatalogItemModel>[],
            delay: const Duration(milliseconds: 250),
          ),
        ),
        inventoryApiProvider.overrideWith(
          (ref) => FakeInventoryApi(
            const <ChildInventoryModel>[],
            delay: const Duration(milliseconds: 250),
          ),
        ),
      ],
    );

    await tester.pump();

    expect(find.byType(ViscondeSkeletonCard), findsWidgets);
  });

  testWidgets('erro bloqueante exibe ação de retry', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));

    final gameApi = ErrorGameApi();

    await _pumpGameHub(
      tester,
      overrides: [
        ...authOverrides(user: buildTestUser(), authenticated: true),
        childrenApiProvider.overrideWith(
          (ref) => FakeChildrenApi(children: children),
        ),
        gamificationApiProvider.overrideWith((ref) => gameApi),
        inventoryApiProvider.overrideWith(
          (ref) => FakeInventoryApi(const <ChildInventoryModel>[]),
        ),
      ],
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Tentar novamente'), findsAtLeastNWidgets(1));

    final callsBeforeRetry = gameApi.walletCalls;
    await tester.tap(find.text('Tentar novamente').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(gameApi.walletCalls, greaterThan(callsBeforeRetry));
  });

  testWidgets('renderiza empty states por seção com CTA', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));

    await _pumpGameHub(
      tester,
      overrides: [
        ...authOverrides(user: buildTestUser(), authenticated: true),
        childrenApiProvider.overrideWith(
          (ref) => FakeChildrenApi(children: children),
        ),
        gamificationApiProvider.overrideWith(
          (ref) => FakeGameApi(
            wallet: const WalletModel(
              coins: 20,
              stars: 5,
              recentTransactions: <WalletTransactionModel>[],
            ),
            achievements: const <AchievementModel>[],
            progression: _emptyProgression(),
            catalog: const <CatalogItemModel>[],
          ),
        ),
        inventoryApiProvider.overrideWith(
          (ref) => FakeInventoryApi(const <ChildInventoryModel>[]),
        ),
      ],
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text(UiStateCopy.gameMissionsEmptyTitle, skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.text('Ler histórias', skipOffstage: false),
      findsAtLeastNWidgets(1),
    );

    await tester.tap(find.text('Conquistas'));
    await tester.pumpAndSettle();

    expect(
      find.text(UiStateCopy.gameAchievementsEmptyTitle, skipOffstage: false),
      findsAtLeastNWidgets(1),
    );
    expect(
      find.text('Criar história', skipOffstage: false),
      findsAtLeastNWidgets(1),
    );
  });
}
