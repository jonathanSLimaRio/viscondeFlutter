import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:visconde_app/core/models/child_profile.dart';
import 'package:visconde_app/design_system/visconde.dart';
import 'package:visconde_app/features/auth/auth_controller.dart';
import 'package:visconde_app/features/gamification/gamification_api.dart';
import 'package:visconde_app/features/gamification/models/gamification_models.dart';
import 'package:visconde_app/features/gamification/ui/game_hub_screen.dart';
import 'package:visconde_app/shared/providers.dart';

import '../../helpers/test_harness.dart';

class _FakeGameApi extends GamificationApi {
  _FakeGameApi({
    required this.wallet,
    required this.achievements,
    required this.progression,
  }) : super(Dio());

  final WalletModel wallet;
  final List<AchievementModel> achievements;
  final ChildProgressionModel progression;

  @override
  Future<WalletModel> fetchWallet(String accessToken) async => wallet;

  @override
  Future<List<AchievementModel>> listAchievements(String accessToken) async {
    return achievements;
  }

  @override
  Future<ChildProgressionModel> fetchChildProgression(
    String accessToken, {
    required String childId,
  }) async {
    return progression;
  }

  @override
  Future<List<CatalogItemModel>> listCatalog(
    String accessToken, {
    required String childProfileId,
    CatalogItemType? type,
  }) async {
    return const <CatalogItemModel>[];
  }
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

  final progression = ChildProgressionModel(
    childProfileId: 'child-1',
    weekKey: '2026-W10',
    streak: const StreakModel(currentDays: 2, bestDays: 5, shieldCount: 0),
    weeklyMissions: const <WeeklyMissionModel>[
      WeeklyMissionModel(
        id: 'mission-main',
        weekKey: '2026-W10',
        kind: WeeklyMissionKind.publishCount,
        title: 'Meta principal',
        description: 'Publicar 2 capítulos nesta semana.',
        targetValue: 2,
        progressValue: 1,
        status: WeeklyMissionStatus.active,
        rewardCoins: 35,
        rewardStars: 1,
      ),
      WeeklyMissionModel(
        id: 'mission-secondary',
        weekKey: '2026-W10',
        kind: WeeklyMissionKind.continueEpisode,
        title: 'Missão exclusiva',
        description: 'Continuar 1 episódio nesta semana.',
        targetValue: 1,
        progressValue: 0,
        status: WeeklyMissionStatus.active,
        rewardCoins: 20,
        rewardStars: 1,
      ),
    ],
    inventorySummary: const InventorySummaryModel(
      totalUnlocked: 0,
      equippedItems: <EquippedInventoryItemModel>[],
    ),
  );

  final achievements = <AchievementModel>[
    AchievementModel(
      id: 'ach-1',
      key: 'first_publish',
      title: 'Primeira conquista',
      description: 'Publicar um capítulo.',
      iconKey: 'trophy',
      rewardCoins: 15,
      rewardStars: 1,
      sortOrder: 1,
      unlocked: true,
      unlockedAt: DateTime(2026, 3, 1, 10, 0),
    ),
  ];

  testWidgets('aba padrão é Missões e troca para Conquistas', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));

    await _pumpGameHub(
      tester,
      overrides: [
        ...authOverrides(user: buildTestUser(), authenticated: true),
        childrenApiProvider.overrideWith(
          (ref) => FakeChildrenApi(children: children),
        ),
        gamificationApiProvider.overrideWith(
          (ref) => _FakeGameApi(
            wallet: const WalletModel(
              coins: 200,
              stars: 8,
              recentTransactions: <WalletTransactionModel>[],
            ),
            achievements: achievements,
            progression: progression,
          ),
        ),
      ],
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('game_hub_lower_tabs')), findsOneWidget);
    expect(find.text('Missão exclusiva'), findsOneWidget);
    expect(find.text('Primeira conquista'), findsNothing);

    await tester.tap(find.text('Conquistas'));
    await tester.pumpAndSettle();

    expect(find.text('Primeira conquista'), findsOneWidget);
    expect(find.text('Missão exclusiva'), findsNothing);

    await tester.tap(find.text('Missões'));
    await tester.pumpAndSettle();

    expect(find.text('Missão exclusiva'), findsOneWidget);
  });

  testWidgets('cards de missão mostram progresso e recompensas', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));

    await _pumpGameHub(
      tester,
      overrides: [
        ...authOverrides(user: buildTestUser(), authenticated: true),
        childrenApiProvider.overrideWith(
          (ref) => FakeChildrenApi(children: children),
        ),
        gamificationApiProvider.overrideWith(
          (ref) => _FakeGameApi(
            wallet: const WalletModel(
              coins: 120,
              stars: 4,
              recentTransactions: <WalletTransactionModel>[],
            ),
            achievements: achievements,
            progression: progression,
          ),
        ),
      ],
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Missão exclusiva'), findsOneWidget);
    expect(find.text('Ativa'), findsAtLeastNWidgets(1));
    expect(find.text('0/1'), findsOneWidget);
    expect(find.text('+20'), findsOneWidget);
    expect(find.text('+1'), findsAtLeastNWidgets(1));

    expect(find.text('O Colecionador', skipOffstage: false), findsNothing);
    expect(find.text('Loja e Inventário', skipOffstage: false), findsNothing);
  });
}
