import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import 'inventory_models.dart';

class InventoryApi {
  InventoryApi(this._dio);

  final Dio _dio;

  Future<List<ChildInventoryModel>> getChildInventory(
    String childProfileId,
    String accessToken,
  ) async {
    final response = await _dio.get<List<dynamic>>(
      'children/$childProfileId/inventory',
      options: authOptions(accessToken),
    );

    return (response.data ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(ChildInventoryModel.fromJson)
        .toList();
  }

  Future<StoryMemoryModel?> getLatestMemory(
    String childProfileId,
    String accessToken,
  ) async {
    final response = await _dio.get<Map<String, dynamic>?>(
      'children/$childProfileId/memories',
      options: authOptions(accessToken),
    );

    if (response.data == null) return null;
    return StoryMemoryModel.fromJson(response.data!);
  }

  Future<ChildInventoryModel?> rewardRandomItem(
    String storyId,
    String accessToken,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'stories/$storyId/reward',
      options: authOptions(accessToken),
    );

    final reward = response.data?['reward'] as Map<String, dynamic>?;
    if (reward == null) return null;
    return ChildInventoryModel.fromJson(reward);
  }
}
