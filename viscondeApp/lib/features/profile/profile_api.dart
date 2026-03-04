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
    String? name,
    String? timezone,
    String? avatarPresetKey,
    int? avatarVariant,
    String? avatarAccent,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) {
      data['name'] = name;
    }
    if (timezone != null) {
      data['timezone'] = timezone;
    }
    if (avatarPresetKey != null) {
      data['avatarPresetKey'] = avatarPresetKey;
    }
    if (avatarVariant != null) {
      data['avatarVariant'] = avatarVariant;
    }
    if (avatarAccent != null) {
      data['avatarAccent'] = avatarAccent;
    }

    final response = await _dio.patch<Map<String, dynamic>>(
      'me',
      data: data,
      options: authOptions(accessToken),
    );

    return AppUser.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<AppUser> updateAvatarPreset(
    String accessToken, {
    required String avatarPresetKey,
    required int avatarVariant,
    required String avatarAccent,
  }) {
    return updateMe(
      accessToken,
      avatarPresetKey: avatarPresetKey,
      avatarVariant: avatarVariant,
      avatarAccent: avatarAccent,
    );
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
