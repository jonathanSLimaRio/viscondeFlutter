import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_exception.dart';

const devAutoLoginEnabled = bool.fromEnvironment(
  'DEV_AUTO_LOGIN',
  defaultValue: false,
);

const devLoginPrefillEnabled = bool.fromEnvironment(
  'DEV_LOGIN_PREFILL',
  defaultValue: true,
);

const devAdminEmail = String.fromEnvironment(
  'DEV_ADMIN_EMAIL',
  defaultValue: 'admin@visconde.app',
);

const devAdminPassword = String.fromEnvironment(
  'DEV_ADMIN_PASSWORD',
  defaultValue: 'admin123',
);

bool get hasExplicitDevCredentials =>
    devAdminEmail.trim().isNotEmpty && devAdminPassword.trim().isNotEmpty;

final apiBaseUrlProvider = Provider<String>((ref) {
  return const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api/v1/',
  );
});

const authRetriedExtraKey = 'authRetried';
const disableAuthRetryExtraKey = 'disableAuthRetry';

final dioHttpClientAdapterProvider = Provider<HttpClientAdapter?>((ref) {
  return null;
});

final dioProvider = Provider<Dio>((ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  final adapter = ref.watch(dioHttpClientAdapterProvider);
  return createApiDio(baseUrl: baseUrl, httpClientAdapter: adapter);
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

bool requestHasAuthRetried(RequestOptions options) {
  return options.extra[authRetriedExtraKey] == true;
}

bool requestDisablesAuthRetry(RequestOptions options) {
  return options.extra[disableAuthRetryExtraKey] == true;
}

bool isAuthEndpointPath(String path) {
  final normalized = path.toLowerCase();
  return normalized.contains('/auth/login') ||
      normalized.contains('/auth/signup') ||
      normalized.contains('/auth/refresh') ||
      normalized.contains('/auth/logout') ||
      normalized.contains('/auth/forgot-password') ||
      normalized.contains('/auth/reset-password');
}

bool shouldAttemptAuthRetry(RequestOptions options, int? statusCode) {
  if (statusCode != 401) {
    return false;
  }

  if (requestHasAuthRetried(options) || requestDisablesAuthRetry(options)) {
    return false;
  }

  final path = _normalizedRequestPath(options.path);
  if (isAuthEndpointPath(path)) {
    return false;
  }

  return true;
}

RequestOptions markRequestAuthRetried(
  RequestOptions options, {
  required String accessToken,
}) {
  final headers = Map<String, dynamic>.from(options.headers)
    ..removeWhere(
      (key, value) => key.toString().toLowerCase() == 'authorization',
    )
    ..['Authorization'] = 'Bearer $accessToken';
  final extra = Map<String, dynamic>.from(options.extra)
    ..[authRetriedExtraKey] = true;

  return options.copyWith(headers: headers, extra: extra);
}

String _normalizedRequestPath(String rawPath) {
  final uri = Uri.tryParse(rawPath);
  if (uri != null && uri.path.isNotEmpty) {
    return uri.path;
  }
  return rawPath;
}

Dio createApiDio({
  required String baseUrl,
  String? accessToken,
  HttpClientAdapter? httpClientAdapter,
  bool mapErrors = true,
}) {
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

  if (httpClientAdapter != null) {
    dio.httpClientAdapter = httpClientAdapter;
  }

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = accessToken?.trim();
        if (token != null &&
            token.isNotEmpty &&
            !_hasAuthorizationHeader(options.headers)) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: mapErrors
          ? (error, handler) {
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
            }
          : null,
    ),
  );

  return dio;
}

bool _hasAuthorizationHeader(Map<String, dynamic> headers) {
  return headers.keys.any(
    (key) => key.toString().toLowerCase() == 'authorization',
  );
}
