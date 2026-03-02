import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_exception.dart';

const devAutoLoginEnabled = bool.fromEnvironment(
  'DEV_AUTO_LOGIN',
  defaultValue: false,
);

const devAdminEmail = String.fromEnvironment(
  'DEV_ADMIN_EMAIL',
  defaultValue: 'admin@visconde.app',
);

const devAdminPassword = String.fromEnvironment(
  'DEV_ADMIN_PASSWORD',
  defaultValue: 'admin123',
);

final apiBaseUrlProvider = Provider<String>((ref) {
  return const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api/v1',
  );
});

final dioProvider = Provider<Dio>((ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  return createApiDio(baseUrl: baseUrl);
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(dioProvider));
});

Options authOptions(String accessToken) {
  return Options(headers: {'Authorization': 'Bearer $accessToken'});
}

class ApiClient {
  ApiClient(this.dio);

  final Dio dio;
}

class AuthorizedApiClient extends ApiClient {
  AuthorizedApiClient(super.dio);
}

Dio createApiDio({required String baseUrl, String? accessToken}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      headers: {
        'Content-Type': 'application/json',
        if (accessToken != null && accessToken.trim().isNotEmpty)
          'Authorization': 'Bearer ${accessToken.trim()}',
      },
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = accessToken?.trim();
        if (token != null &&
            token.isNotEmpty &&
            options.headers['Authorization'] == null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        final mapped = ApiException.fromDio(error);
        handler.reject(
          DioException(
            requestOptions: error.requestOptions,
            response: error.response,
            type: error.type,
            message: mapped.message,
            error: mapped,
          ),
        );
      },
    ),
  );

  return dio;
}
