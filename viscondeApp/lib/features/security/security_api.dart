import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';

class SecurityApi {
  SecurityApi(this._dio);

  final Dio _dio;

  Future<bool> hasPin(String accessToken) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/security/pin/status',
      options: authOptions(accessToken),
    );

    final payload = response.data ?? <String, dynamic>{};
    return (payload['hasPin'] as bool?) ?? false;
  }

  Future<void> setPin(String accessToken, String pin) async {
    await _dio.post<Map<String, dynamic>>(
      '/security/pin/set',
      data: {'pin': pin},
      options: authOptions(accessToken),
    );
  }

  Future<bool> verifyPin(String accessToken, String pin) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/security/pin/verify',
      data: {'pin': pin},
      options: authOptions(accessToken),
    );

    final payload = response.data ?? <String, dynamic>{};
    return (payload['verified'] as bool?) ?? false;
  }

  Future<void> resetPin(
    String accessToken, {
    required String newPin,
    String? currentPassword,
    String? googleIdToken,
    String? appleIdentityToken,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/security/pin/reset',
      data: {
        'newPin': newPin,
        if (currentPassword != null && currentPassword.isNotEmpty)
          'currentPassword': currentPassword,
        if (googleIdToken != null && googleIdToken.isNotEmpty)
          'googleIdToken': googleIdToken,
        if (appleIdentityToken != null && appleIdentityToken.isNotEmpty)
          'appleIdentityToken': appleIdentityToken,
      },
      options: authOptions(accessToken),
    );
  }
}
