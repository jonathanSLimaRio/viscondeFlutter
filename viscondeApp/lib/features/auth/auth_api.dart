import 'package:dio/dio.dart';

import '../../core/models/app_user.dart';
import '../../core/models/auth_session.dart';
import '../../core/network/api_client.dart';

class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<AuthSession> signup({
    required String email,
    required String password,
    required String name,
    required String timezone,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/signup',
      data: {
        'email': email,
        'password': password,
        'name': name,
        'timezone': timezone,
      },
    );

    return AuthSession.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );

    return AuthSession.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<AuthSession> loginWithGoogle({required String idToken}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/social/google',
      data: {'idToken': idToken},
    );

    return AuthSession.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<AuthSession> loginWithApple({required String idToken}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/social/apple',
      data: {'idToken': idToken},
    );

    return AuthSession.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<AuthSession> refresh({required String refreshToken}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
    );

    return AuthSession.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<void> logout({
    required String? accessToken,
    required String? refreshToken,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/auth/logout',
      data: <String, dynamic>{'refreshToken': refreshToken}
        ..removeWhere((_, value) => value == null),
      options: accessToken != null ? authOptions(accessToken) : null,
    );
  }

  Future<void> forgotPassword(String email) async {
    await _dio.post<Map<String, dynamic>>(
      '/auth/forgot-password',
      data: {'email': email},
    );
  }

  Future<AppUser> me({required String accessToken}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/me',
      options: authOptions(accessToken),
    );

    return AppUser.fromJson(response.data ?? <String, dynamic>{});
  }
}
