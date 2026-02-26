import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  return dio;
});

Options authOptions(String accessToken) {
  return Options(headers: {'Authorization': 'Bearer $accessToken'});
}
