enum CatalogItemType { scenario, character, skin, avatar }

enum WeeklyMissionStatus { active, completed, expired }

enum WeeklyMissionKind { publishCount, publishWithVirtue, continueEpisode }

CatalogItemType catalogItemTypeFromApi(String? value) {
  switch (value) {
    case 'SCENARIO':
      return CatalogItemType.scenario;
    case 'CHARACTER':
      return CatalogItemType.character;
    case 'SKIN':
      return CatalogItemType.skin;
    case 'AVATAR':
    default:
      return CatalogItemType.avatar;
  }
}

String catalogItemTypeToApi(CatalogItemType value) {
  switch (value) {
    case CatalogItemType.scenario:
      return 'SCENARIO';
    case CatalogItemType.character:
      return 'CHARACTER';
    case CatalogItemType.skin:
      return 'SKIN';
    case CatalogItemType.avatar:
      return 'AVATAR';
  }
}

WeeklyMissionStatus weeklyMissionStatusFromApi(String? value) {
  switch (value) {
    case 'COMPLETED':
      return WeeklyMissionStatus.completed;
    case 'EXPIRED':
      return WeeklyMissionStatus.expired;
    case 'ACTIVE':
    default:
      return WeeklyMissionStatus.active;
  }
}

WeeklyMissionKind weeklyMissionKindFromApi(String? value) {
  switch (value) {
    case 'PUBLISH_WITH_VIRTUE':
      return WeeklyMissionKind.publishWithVirtue;
    case 'CONTINUE_EPISODE':
      return WeeklyMissionKind.continueEpisode;
    case 'PUBLISH_COUNT':
    default:
      return WeeklyMissionKind.publishCount;
  }
}

class WalletTransactionModel {
  const WalletTransactionModel({
    required this.id,
    required this.currencyType,
    required this.amount,
    required this.reason,
    this.referenceType,
    this.referenceId,
    required this.balanceAfter,
    required this.createdAt,
  });

  final String id;
  final String currencyType;
  final int amount;
  final String reason;
  final String? referenceType;
  final String? referenceId;
  final int balanceAfter;
  final DateTime createdAt;

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) {
    return WalletTransactionModel(
      id: (json['id'] as String?) ?? '',
      currencyType: (json['currencyType'] as String?) ?? 'COIN',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      reason: (json['reason'] as String?) ?? '',
      referenceType: json['referenceType'] as String?,
      referenceId: json['referenceId'] as String?,
      balanceAfter: (json['balanceAfter'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class WalletModel {
  const WalletModel({
    required this.coins,
    required this.stars,
    required this.recentTransactions,
  });

  final int coins;
  final int stars;
  final List<WalletTransactionModel> recentTransactions;

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      stars: (json['stars'] as num?)?.toInt() ?? 0,
      recentTransactions:
          ((json['recentTransactions'] as List<dynamic>?) ?? <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(WalletTransactionModel.fromJson)
              .toList(),
    );
  }
}

class AchievementModel {
  const AchievementModel({
    required this.id,
    required this.key,
    required this.title,
    required this.description,
    required this.iconKey,
    required this.rewardCoins,
    required this.rewardStars,
    required this.sortOrder,
    required this.unlocked,
    this.unlockedAt,
  });

  final String id;
  final String key;
  final String title;
  final String description;
  final String iconKey;
  final int rewardCoins;
  final int rewardStars;
  final int sortOrder;
  final bool unlocked;
  final DateTime? unlockedAt;

  factory AchievementModel.fromJson(Map<String, dynamic> json) {
    return AchievementModel(
      id: (json['id'] as String?) ?? '',
      key: (json['key'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      iconKey: (json['iconKey'] as String?) ?? '',
      rewardCoins: (json['rewardCoins'] as num?)?.toInt() ?? 0,
      rewardStars: (json['rewardStars'] as num?)?.toInt() ?? 0,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      unlocked: (json['unlocked'] as bool?) ?? false,
      unlockedAt: DateTime.tryParse(json['unlockedAt'] as String? ?? ''),
    );
  }
}

class CatalogItemModel {
  const CatalogItemModel({
    required this.id,
    required this.key,
    required this.type,
    required this.name,
    required this.description,
    required this.iconKey,
    required this.priceCoins,
    required this.priceStars,
    required this.sortOrder,
    required this.unlocked,
    required this.equipped,
    this.unlockedAt,
  });

  final String id;
  final String key;
  final CatalogItemType type;
  final String name;
  final String description;
  final String iconKey;
  final int priceCoins;
  final int priceStars;
  final int sortOrder;
  final bool unlocked;
  final bool equipped;
  final DateTime? unlockedAt;

  factory CatalogItemModel.fromJson(Map<String, dynamic> json) {
    return CatalogItemModel(
      id: (json['id'] as String?) ?? '',
      key: (json['key'] as String?) ?? '',
      type: catalogItemTypeFromApi(json['type'] as String?),
      name: (json['name'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      iconKey: (json['iconKey'] as String?) ?? '',
      priceCoins: (json['priceCoins'] as num?)?.toInt() ?? 0,
      priceStars: (json['priceStars'] as num?)?.toInt() ?? 0,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      unlocked: (json['unlocked'] as bool?) ?? false,
      equipped: (json['equipped'] as bool?) ?? false,
      unlockedAt: DateTime.tryParse(json['unlockedAt'] as String? ?? ''),
    );
  }
}

class StreakModel {
  const StreakModel({
    required this.currentDays,
    required this.bestDays,
    required this.shieldCount,
    this.lastCountedDate,
  });

  final int currentDays;
  final int bestDays;
  final int shieldCount;
  final DateTime? lastCountedDate;

  factory StreakModel.fromJson(Map<String, dynamic> json) {
    return StreakModel(
      currentDays: (json['currentDays'] as num?)?.toInt() ?? 0,
      bestDays: (json['bestDays'] as num?)?.toInt() ?? 0,
      shieldCount: (json['shieldCount'] as num?)?.toInt() ?? 0,
      lastCountedDate: DateTime.tryParse(
        json['lastCountedDate'] as String? ?? '',
      ),
    );
  }
}

class WeeklyMissionModel {
  const WeeklyMissionModel({
    required this.id,
    required this.weekKey,
    required this.kind,
    required this.title,
    required this.description,
    required this.targetValue,
    required this.progressValue,
    required this.status,
    required this.rewardCoins,
    required this.rewardStars,
    this.completedAt,
    this.virtue,
  });

  final String id;
  final String weekKey;
  final WeeklyMissionKind kind;
  final String title;
  final String description;
  final int targetValue;
  final int progressValue;
  final WeeklyMissionStatus status;
  final int rewardCoins;
  final int rewardStars;
  final DateTime? completedAt;
  final Map<String, dynamic>? virtue;

  factory WeeklyMissionModel.fromJson(Map<String, dynamic> json) {
    return WeeklyMissionModel(
      id: (json['id'] as String?) ?? '',
      weekKey: (json['weekKey'] as String?) ?? '',
      kind: weeklyMissionKindFromApi(json['kind'] as String?),
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      targetValue: (json['targetValue'] as num?)?.toInt() ?? 0,
      progressValue: (json['progressValue'] as num?)?.toInt() ?? 0,
      status: weeklyMissionStatusFromApi(json['status'] as String?),
      rewardCoins: (json['rewardCoins'] as num?)?.toInt() ?? 0,
      rewardStars: (json['rewardStars'] as num?)?.toInt() ?? 0,
      completedAt: DateTime.tryParse(json['completedAt'] as String? ?? ''),
      virtue: json['virtue'] as Map<String, dynamic>?,
    );
  }
}

class EquippedInventoryItemModel {
  const EquippedInventoryItemModel({
    required this.id,
    required this.key,
    required this.type,
    required this.name,
    required this.iconKey,
  });

  final String id;
  final String key;
  final CatalogItemType type;
  final String name;
  final String iconKey;

  factory EquippedInventoryItemModel.fromJson(Map<String, dynamic> json) {
    return EquippedInventoryItemModel(
      id: (json['id'] as String?) ?? '',
      key: (json['key'] as String?) ?? '',
      type: catalogItemTypeFromApi(json['type'] as String?),
      name: (json['name'] as String?) ?? '',
      iconKey: (json['iconKey'] as String?) ?? '',
    );
  }
}

class InventorySummaryModel {
  const InventorySummaryModel({
    required this.totalUnlocked,
    required this.equippedItems,
  });

  final int totalUnlocked;
  final List<EquippedInventoryItemModel> equippedItems;

  factory InventorySummaryModel.fromJson(Map<String, dynamic> json) {
    return InventorySummaryModel(
      totalUnlocked: (json['totalUnlocked'] as num?)?.toInt() ?? 0,
      equippedItems: ((json['equippedItems'] as List<dynamic>?) ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(EquippedInventoryItemModel.fromJson)
          .toList(),
    );
  }
}

class ChildProgressionModel {
  const ChildProgressionModel({
    required this.childProfileId,
    required this.weekKey,
    required this.streak,
    required this.weeklyMissions,
    required this.inventorySummary,
  });

  final String childProfileId;
  final String weekKey;
  final StreakModel streak;
  final List<WeeklyMissionModel> weeklyMissions;
  final InventorySummaryModel inventorySummary;

  factory ChildProgressionModel.fromJson(Map<String, dynamic> json) {
    return ChildProgressionModel(
      childProfileId: (json['childProfileId'] as String?) ?? '',
      weekKey: (json['weekKey'] as String?) ?? '',
      streak: StreakModel.fromJson(
        (json['streak'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
      weeklyMissions:
          ((json['weeklyMissions'] as List<dynamic>?) ?? <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(WeeklyMissionModel.fromJson)
              .toList(),
      inventorySummary: InventorySummaryModel.fromJson(
        (json['inventorySummary'] as Map<String, dynamic>?) ??
            <String, dynamic>{},
      ),
    );
  }
}

class UnlockCatalogResultModel {
  const UnlockCatalogResultModel({
    required this.wallet,
    required this.spentCoins,
    required this.spentStars,
    required this.item,
  });

  final WalletModel wallet;
  final int spentCoins;
  final int spentStars;
  final CatalogItemModel item;

  factory UnlockCatalogResultModel.fromJson(Map<String, dynamic> json) {
    final walletJson =
        (json['wallet'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final inventoryItemJson =
        (json['inventoryItem'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final itemJson =
        (inventoryItemJson['item'] as Map<String, dynamic>?) ??
        <String, dynamic>{};

    return UnlockCatalogResultModel(
      wallet: WalletModel.fromJson({
        'coins': walletJson['coins'],
        'stars': walletJson['stars'],
        'recentTransactions': const <dynamic>[],
      }),
      spentCoins:
          ((json['spent'] as Map<String, dynamic>?)?['coins'] as num?)
              ?.toInt() ??
          0,
      spentStars:
          ((json['spent'] as Map<String, dynamic>?)?['stars'] as num?)
              ?.toInt() ??
          0,
      item: CatalogItemModel.fromJson({
        ...itemJson,
        'priceCoins': 0,
        'priceStars': 0,
        'sortOrder': 0,
        'description': '',
        'unlocked': true,
        'equipped': (inventoryItemJson['equipped'] as bool?) ?? false,
        'unlockedAt': inventoryItemJson['unlockedAt'],
      }),
    );
  }
}

class PublishGamificationSummaryModel {
  const PublishGamificationSummaryModel({
    required this.wallet,
    required this.deltaCoins,
    required this.deltaStars,
    required this.unlockedAchievements,
    required this.completedMissions,
    required this.streak,
  });

  final WalletModel wallet;
  final int deltaCoins;
  final int deltaStars;
  final List<AchievementModel> unlockedAchievements;
  final List<WeeklyMissionModel> completedMissions;
  final StreakModel streak;

  factory PublishGamificationSummaryModel.fromJson(Map<String, dynamic> json) {
    final unlockedAchievementsRaw =
        (json['unlockedAchievements'] as List<dynamic>?) ?? <dynamic>[];
    final completedMissionsRaw =
        (json['completedMissions'] as List<dynamic>?) ?? <dynamic>[];

    return PublishGamificationSummaryModel(
      wallet: WalletModel.fromJson({
        'coins': (json['wallet'] as Map<String, dynamic>?)?['coins'],
        'stars': (json['wallet'] as Map<String, dynamic>?)?['stars'],
        'recentTransactions': const <dynamic>[],
      }),
      deltaCoins:
          ((json['delta'] as Map<String, dynamic>?)?['coins'] as num?)
              ?.toInt() ??
          0,
      deltaStars:
          ((json['delta'] as Map<String, dynamic>?)?['stars'] as num?)
              ?.toInt() ??
          0,
      unlockedAchievements: unlockedAchievementsRaw
          .whereType<Map<String, dynamic>>()
          .map(
            (raw) => AchievementModel.fromJson({
              'id': '',
              'key': raw['key'],
              'title': raw['title'],
              'description': '',
              'iconKey': '',
              'rewardCoins': raw['rewardCoins'],
              'rewardStars': raw['rewardStars'],
              'sortOrder': 0,
              'unlocked': true,
              'unlockedAt': DateTime.now().toIso8601String(),
            }),
          )
          .toList(),
      completedMissions: completedMissionsRaw
          .whereType<Map<String, dynamic>>()
          .map(
            (raw) => WeeklyMissionModel.fromJson({
              'id': raw['id'],
              'weekKey': '',
              'kind': raw['kind'],
              'title': raw['title'],
              'description': '',
              'targetValue': 1,
              'progressValue': 1,
              'status': 'COMPLETED',
              'rewardCoins': raw['rewardCoins'],
              'rewardStars': raw['rewardStars'],
              'completedAt': DateTime.now().toIso8601String(),
            }),
          )
          .toList(),
      streak: StreakModel.fromJson(
        (json['streak'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
    );
  }
}
