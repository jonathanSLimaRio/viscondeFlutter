import 'package:dio/dio.dart';

import '../../core/models/child_profile.dart';
import '../../core/network/api_client.dart';

class ChildrenApi {
  ChildrenApi(this._dio);

  final Dio _dio;

  Future<List<ChildProfile>> listChildren(String accessToken) async {
    final response = await _dio.get<List<dynamic>>(
      '/children',
      options: authOptions(accessToken),
    );

    return (response.data ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(ChildProfile.fromJson)
        .toList();
  }

  Future<ChildProfile> createChild(
    String accessToken, {
    required String name,
    required DateTime birthDate,
    required List<String> favoriteThemes,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/children',
      data: {
        'name': name,
        'birthDate': birthDate.toIso8601String(),
        'favoriteThemes': favoriteThemes,
      },
      options: authOptions(accessToken),
    );

    return ChildProfile.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<ChildProfile> updateChild(
    String accessToken,
    String childId, {
    required String name,
    required DateTime birthDate,
    required List<String> favoriteThemes,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/children/$childId',
      data: {
        'name': name,
        'birthDate': birthDate.toIso8601String(),
        'favoriteThemes': favoriteThemes,
      },
      options: authOptions(accessToken),
    );

    return ChildProfile.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<void> deleteChild(String accessToken, String childId) async {
    await _dio.delete<Map<String, dynamic>>(
      '/children/$childId',
      options: authOptions(accessToken),
    );
  }

  Future<ChildProfile> uploadAvatar(
    String accessToken,
    String childId, {
    required String filePath,
  }) async {
    final data = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });

    final response = await _dio.post<Map<String, dynamic>>(
      '/children/$childId/avatar',
      data: data,
      options: authOptions(accessToken),
    );

    final payload = response.data ?? <String, dynamic>{};
    final childJson = payload['child'] as Map<String, dynamic>?;

    return ChildProfile.fromJson(childJson ?? <String, dynamic>{});
  }
}
