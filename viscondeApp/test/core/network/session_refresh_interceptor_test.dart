import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visconde_app/core/models/app_user.dart';
import 'package:visconde_app/core/models/auth_session.dart';
import 'package:visconde_app/core/network/api_client.dart';
import 'package:visconde_app/features/auth/auth_api.dart';
import 'package:visconde_app/features/auth/auth_controller.dart';
import 'package:visconde_app/features/security/parental_gate_controller.dart';
import 'package:visconde_app/shared/providers.dart';

import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/test_harness.dart';

class InterceptorAuthApi extends AuthApi {
  InterceptorAuthApi({required this.user}) : super(Dio());

  final AppUser user;
  int refreshCalls = 0;
  Object? refreshError;
  Completer<AuthSession>? refreshCompleter;
  AuthSession? refreshSession;

  @override
  Future<AppUser> me({required String accessToken}) async {
    return user;
  }

  @override
  Future<AuthSession> refresh({required String refreshToken}) async {
    refreshCalls += 1;
    final completer = refreshCompleter;
    if (completer != null) {
      return completer.future;
    }

    final error = refreshError;
    if (error != null) {
      throw error;
    }

    return refreshSession ??
        AuthSession(
          accessToken: 'token-456',
          refreshToken: 'refresh-456',
          user: user,
        );
  }
}

Future<void> _waitAuthReady(ProviderContainer container) async {
  for (var i = 0; i < 40; i++) {
    if (container.read(authControllerProvider).status != AuthStatus.loading) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  throw StateError('AuthController did not leave loading state in time.');
}

String? _authorizationHeader(RequestOptions options) {
  for (final entry in options.headers.entries) {
    if (entry.key.toString().toLowerCase() == 'authorization') {
      return entry.value?.toString();
    }
  }
  return null;
}

void main() {
  group('sessionAwareDioProvider refresh interceptor', () {
    test('401 triggers refresh and retries original request once', () async {
      final user = buildTestUser();
      final authApi = InterceptorAuthApi(user: user)
        ..refreshSession = AuthSession(
          accessToken: 'token-456',
          refreshToken: 'refresh-456',
          user: user,
        );
      final storage = MemorySessionStorage(buildStoredSession(user));
      var protectedCalls = 0;

      final container = ProviderContainer(
        overrides: [
          apiBaseUrlProvider.overrideWith((ref) => 'https://api.test/api/v1'),
          dioHttpClientAdapterProvider.overrideWith(
            (ref) => FakeDioAdapter((options) async {
              if (options.path == '/protected') {
                protectedCalls += 1;
                final authHeader = _authorizationHeader(options);
                if (authHeader == 'Bearer token-123') {
                  return jsonResponse({
                    'error': 'Unauthorized',
                  }, statusCode: 401);
                }
                if (authHeader == 'Bearer token-456') {
                  return jsonResponse({'ok': true});
                }
              }

              return jsonResponse({
                'error': 'Unexpected route',
              }, statusCode: 404);
            }),
          ),
          authApiProvider.overrideWith((ref) => authApi),
          sessionStorageProvider.overrideWith((ref) => storage),
        ],
      );
      addTearDown(container.dispose);

      await _waitAuthReady(container);
      final dio = container.read(sessionAwareDioProvider);

      final response = await dio.get<Map<String, dynamic>>('/protected');

      expect(response.statusCode, 200);
      expect(response.data?['ok'], true);
      expect(protectedCalls, 2);
      expect(authApi.refreshCalls, 1);
      expect(
        container.read(authControllerProvider).status,
        AuthStatus.authenticated,
      );
      expect(container.read(authControllerProvider).accessToken, 'token-456');
    });

    test('failed refresh expires session with fixed message', () async {
      final user = buildTestUser();
      final authApi = InterceptorAuthApi(user: user)
        ..refreshError = DioException(
          requestOptions: RequestOptions(path: '/auth/refresh'),
          response: Response<Map<String, dynamic>>(
            requestOptions: RequestOptions(path: '/auth/refresh'),
            statusCode: 401,
            data: {'error': 'Unauthorized'},
          ),
          type: DioExceptionType.badResponse,
        );
      final storage = MemorySessionStorage(buildStoredSession(user));

      final container = ProviderContainer(
        overrides: [
          apiBaseUrlProvider.overrideWith((ref) => 'https://api.test/api/v1'),
          dioHttpClientAdapterProvider.overrideWith(
            (ref) => FakeDioAdapter((options) async {
              if (options.path == '/protected') {
                return jsonResponse({'error': 'Unauthorized'}, statusCode: 401);
              }
              return jsonResponse({
                'error': 'Unexpected route',
              }, statusCode: 404);
            }),
          ),
          authApiProvider.overrideWith((ref) => authApi),
          sessionStorageProvider.overrideWith((ref) => storage),
        ],
      );
      addTearDown(container.dispose);

      await _waitAuthReady(container);
      final dio = container.read(sessionAwareDioProvider);

      await expectLater(
        dio.get<Map<String, dynamic>>('/protected'),
        throwsA(isA<DioException>()),
      );

      final authState = container.read(authControllerProvider);
      expect(authState.status, AuthStatus.unauthenticated);
      expect(authState.error, 'Sua sessão expirou. Faça login novamente.');
      expect(await storage.read(), isNull);
      expect(authApi.refreshCalls, 1);
    });

    test('concurrent 401s use single-flight refresh', () async {
      final user = buildTestUser();
      final authApi = InterceptorAuthApi(user: user)
        ..refreshCompleter = Completer<AuthSession>();
      final storage = MemorySessionStorage(buildStoredSession(user));
      var oldTokenCalls = 0;
      var newTokenCalls = 0;

      final container = ProviderContainer(
        overrides: [
          apiBaseUrlProvider.overrideWith((ref) => 'https://api.test/api/v1'),
          dioHttpClientAdapterProvider.overrideWith(
            (ref) => FakeDioAdapter((options) async {
              if (options.path.startsWith('/protected')) {
                final authHeader = _authorizationHeader(options);
                if (authHeader == 'Bearer token-123') {
                  oldTokenCalls += 1;
                  return jsonResponse({
                    'error': 'Unauthorized',
                  }, statusCode: 401);
                }
                if (authHeader == 'Bearer token-789') {
                  newTokenCalls += 1;
                  return jsonResponse({'ok': true});
                }
              }
              return jsonResponse({
                'error': 'Unexpected route',
              }, statusCode: 404);
            }),
          ),
          authApiProvider.overrideWith((ref) => authApi),
          sessionStorageProvider.overrideWith((ref) => storage),
        ],
      );
      addTearDown(container.dispose);

      await _waitAuthReady(container);
      final dio = container.read(sessionAwareDioProvider);

      final callA = dio.get<Map<String, dynamic>>('/protected?call=A');
      final callB = dio.get<Map<String, dynamic>>('/protected?call=B');

      await Future<void>.delayed(const Duration(milliseconds: 10));
      authApi.refreshCompleter!.complete(
        AuthSession(
          accessToken: 'token-789',
          refreshToken: 'refresh-789',
          user: user,
        ),
      );

      final responses = await Future.wait([callA, callB]);
      expect(responses.every((response) => response.statusCode == 200), isTrue);
      expect(authApi.refreshCalls, 1);
      expect(oldTokenCalls, 2);
      expect(newTokenCalls, 2);
    });

    test('401 parental unlock error does not expire auth session', () async {
      final user = buildTestUser();
      final authApi = InterceptorAuthApi(user: user);
      final storage = MemorySessionStorage(buildStoredSession(user));

      final container = ProviderContainer(
        overrides: [
          apiBaseUrlProvider.overrideWith((ref) => 'https://api.test/api/v1'),
          dioHttpClientAdapterProvider.overrideWith(
            (ref) => FakeDioAdapter((options) async {
              if (options.path == '/protected-parental') {
                return jsonResponse({
                  'error': 'Área protegida por PIN.',
                  'code': 'PARENTAL_UNLOCK_REQUIRED',
                }, statusCode: 401);
              }

              return jsonResponse({
                'error': 'Unexpected route',
              }, statusCode: 404);
            }),
          ),
          authApiProvider.overrideWith((ref) => authApi),
          sessionStorageProvider.overrideWith((ref) => storage),
        ],
      );
      addTearDown(container.dispose);

      await _waitAuthReady(container);
      container
          .read(parentalGateControllerProvider.notifier)
          .setUnlocked(
            token: 'unlock-token',
            expiresAt: DateTime.now().add(const Duration(minutes: 9)),
          );

      final dio = container.read(sessionAwareDioProvider);
      await expectLater(
        dio.get<Map<String, dynamic>>('/protected-parental'),
        throwsA(isA<DioException>()),
      );

      expect(
        container.read(authControllerProvider).status,
        AuthStatus.authenticated,
      );
      expect(authApi.refreshCalls, 0);
      expect(
        container.read(parentalGateControllerProvider).isUnlocked,
        isFalse,
      );
    });
  });
}
