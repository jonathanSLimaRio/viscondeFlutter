import 'package:dio/dio.dart';

import '../../core/models/app_user.dart';
import '../../core/network/api_client.dart';

class ProfileApi {
  ProfileApi(this._dio);

  final Dio _dio;

  Future<AppUser> getMe(String accessToken) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'me',
      options: authOptions(accessToken),
    );

    return AppUser.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<AppUser> updateMe(
    String accessToken, {
    required String name,
    required String timezone,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      'me',
      data: {'name': name, 'timezone': timezone},
      options: authOptions(accessToken),
    );

    return AppUser.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<AppUser> updatePhoto(
    String accessToken, {
    required String filePath,
  }) async {
    final data = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });

    final response = await _dio.post<Map<String, dynamic>>(
      'me/photo',
      data: data,
      options: authOptions(accessToken),
    );

    final payload = response.data ?? <String, dynamic>{};
    final userJson = payload['user'] as Map<String, dynamic>?;
    return AppUser.fromJson(userJson ?? <String, dynamic>{});
  }
}
