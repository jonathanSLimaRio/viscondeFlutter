import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import 'models/gamification_models.dart';

class GamificationApi {
  GamificationApi(this._dio);

  final Dio _dio;

  Future<WalletModel> fetchWallet(String accessToken) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'gamification/wallet',
      options: authOptions(accessToken),
    );

    return WalletModel.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<List<AchievementModel>> listAchievements(String accessToken) async {
    final response = await _dio.get<List<dynamic>>(
      'gamification/achievements',
      options: authOptions(accessToken),
    );

    return (response.data ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(AchievementModel.fromJson)
        .toList();
  }

  Future<List<CatalogItemModel>> listCatalog(
    String accessToken, {
    required String childProfileId,
    CatalogItemType? type,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      'gamification/catalog',
      queryParameters: {
        'childProfileId': childProfileId,
        if (type != null) 'type': catalogItemTypeToApi(type),
      },
      options: authOptions(accessToken),
    );

    return (response.data ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(CatalogItemModel.fromJson)
        .toList();
  }

  Future<ChildProgressionModel> fetchChildProgression(
    String accessToken, {
    required String childId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'gamification/children/$childId/progression',
      options: authOptions(accessToken),
    );

    return ChildProgressionModel.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<UnlockCatalogResultModel> unlockItem(
    String accessToken, {
    required String childId,
    required String itemId,
    required String parentalUnlockToken,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'gamification/children/$childId/unlock',
      data: {'itemId': itemId},
      options: authOptions(accessToken).copyWith(
        headers: {
          'Authorization': 'Bearer $accessToken',
          'x-parental-unlock-token': parentalUnlockToken,
        },
      ),
    );

    return UnlockCatalogResultModel.fromJson(
      response.data ?? <String, dynamic>{},
    );
  }

  Future<List<EquippedInventoryItemModel>> equipItem(
    String accessToken, {
    required String childId,
    required String itemId,
    required bool equipped,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'gamification/children/$childId/equip',
      data: {'itemId': itemId, 'equipped': equipped},
      options: authOptions(accessToken),
    );

    return ((response.data?['equippedItems'] as List<dynamic>?) ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(EquippedInventoryItemModel.fromJson)
        .toList();
  }
}
