import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visconde_app/core/models/app_user.dart';
import 'package:visconde_app/core/models/auth_session.dart';
import 'package:visconde_app/features/auth/auth_api.dart';
import 'package:visconde_app/features/auth/auth_controller.dart';
import 'package:visconde_app/shared/ux_analytics.dart';

import '../../helpers/test_harness.dart';

class ControlledAuthApi extends AuthApi {
  ControlledAuthApi({required this.user}) : super(Dio());

  final AppUser user;
  Object? meError;
  Object? refreshError;
  Object? logoutError;
  Object? loginError;
  AuthSession? loginSession;
  AuthSession? refreshSession;
  Completer<AuthSession>? refreshCompleter;
  int logoutCalls = 0;
  int refreshCalls = 0;

  @override
  Future<AppUser> me({required String accessToken}) async {
    final error = meError;
    if (error != null) {
      throw error;
    }
    return user;
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final error = loginError;
    if (error != null) {
      throw error;
    }

    return loginSession ??
        AuthSession(
          accessToken: 'login-access',
          refreshToken: 'login-refresh',
          user: user,
        );
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
          accessToken: 'new-access',
          refreshToken: 'new-refresh',
          user: user,
        );
  }

  @override
  Future<void> logout({
    required String? accessToken,
    required String? refreshToken,
  }) async {
    logoutCalls += 1;
    final error = logoutError;
    if (error != null) {
      throw error;
    }
  }
}

Future<void> _waitAuthReady(AuthController controller) async {
  for (var i = 0; i < 40; i++) {
    if (controller.state.status != AuthStatus.loading) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  throw StateError('AuthController did not leave loading state in time.');
}

void main() {
  group('AuthController session flow', () {
    late List<UxAnalyticsEvent> analyticsEvents;

    setUp(() {
      analyticsEvents = <UxAnalyticsEvent>[];
      UxAnalytics.configure(
        sink: (event) {
          analyticsEvents.add(event);
        },
      );
    });

    tearDown(() {
      UxAnalytics.clearSink();
    });

    test('restores authenticated session when /me succeeds', () async {
      final user = buildTestUser();
      final api = ControlledAuthApi(user: user);
      final storage = MemorySessionStorage(buildStoredSession(user));
      final controller = AuthController(api: api, sessionStorage: storage);

      await _waitAuthReady(controller);

      expect(controller.state.status, AuthStatus.authenticated);
      expect(controller.state.accessToken, 'token-123');
      expect(controller.state.user?.id, user.id);
    });

    test('falls back to refresh when /me fails', () async {
      final user = buildTestUser();
      final api = ControlledAuthApi(user: user)..meError = Exception('401');
      api.refreshSession = AuthSession(
        accessToken: 'refreshed-access',
        refreshToken: 'refreshed-refresh',
        user: user,
      );

      final storage = MemorySessionStorage(buildStoredSession(user));
      final controller = AuthController(api: api, sessionStorage: storage);

      await _waitAuthReady(controller);
      final stored = await storage.read();

      expect(controller.state.status, AuthStatus.authenticated);
      expect(controller.state.accessToken, 'refreshed-access');
      expect(stored?.accessToken, 'refreshed-access');
    });

    test('expires to unauthenticated when restore and refresh fail', () async {
      final user = buildTestUser();
      final api = ControlledAuthApi(user: user)
        ..meError = Exception('401')
        ..refreshError = Exception('refresh failed');

      final storage = MemorySessionStorage(buildStoredSession(user));
      final controller = AuthController(api: api, sessionStorage: storage);

      await _waitAuthReady(controller);

      expect(controller.state.status, AuthStatus.unauthenticated);
      expect(await storage.read(), isNull);
    });

    test(
      'refreshSessionIfPossible updates tokens and persists session',
      () async {
        final user = buildTestUser();
        final api = ControlledAuthApi(user: user)
          ..refreshSession = AuthSession(
            accessToken: 'fresh-access',
            refreshToken: 'fresh-refresh',
            user: user,
          );
        final storage = MemorySessionStorage(buildStoredSession(user));
        final controller = AuthController(api: api, sessionStorage: storage);

        await _waitAuthReady(controller);
        final refreshedAccessToken = await controller
            .refreshSessionIfPossible();
        final stored = await storage.read();

        expect(refreshedAccessToken, 'fresh-access');
        expect(controller.state.status, AuthStatus.authenticated);
        expect(controller.state.accessToken, 'fresh-access');
        expect(controller.state.refreshToken, 'fresh-refresh');
        expect(stored?.accessToken, 'fresh-access');
        expect(stored?.refreshToken, 'fresh-refresh');
        expect(api.refreshCalls, 1);
      },
    );

    test(
      'refreshSessionIfPossible is single-flight for concurrent calls',
      () async {
        final user = buildTestUser();
        final api = ControlledAuthApi(user: user)
          ..refreshCompleter = Completer<AuthSession>();
        final storage = MemorySessionStorage(buildStoredSession(user));
        final controller = AuthController(api: api, sessionStorage: storage);

        await _waitAuthReady(controller);

        final refreshFutureA = controller.refreshSessionIfPossible();
        final refreshFutureB = controller.refreshSessionIfPossible();

        api.refreshCompleter!.complete(
          AuthSession(
            accessToken: 'single-flight-access',
            refreshToken: 'single-flight-refresh',
            user: user,
          ),
        );

        final tokens = await Future.wait([refreshFutureA, refreshFutureB]);

        expect(tokens, ['single-flight-access', 'single-flight-access']);
        expect(api.refreshCalls, 1);
      },
    );

    test(
      'refreshSessionIfPossible expires session with fixed message on failure',
      () async {
        final user = buildTestUser();
        final api = ControlledAuthApi(user: user)
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
        final controller = AuthController(api: api, sessionStorage: storage);

        await _waitAuthReady(controller);
        final refreshedAccessToken = await controller
            .refreshSessionIfPossible();

        expect(refreshedAccessToken, isNull);
        expect(controller.state.status, AuthStatus.unauthenticated);
        expect(
          controller.state.error,
          'Sua sessão expirou. Faça login novamente.',
        );
        expect(await storage.read(), isNull);
      },
    );

    test('logout clears local session even if remote logout fails', () async {
      final user = buildTestUser();
      final api = ControlledAuthApi(user: user)..logoutError = Exception('500');
      final storage = MemorySessionStorage(buildStoredSession(user));
      final controller = AuthController(api: api, sessionStorage: storage);

      await _waitAuthReady(controller);
      await controller.logout();

      expect(api.logoutCalls, 1);
      expect(controller.state.status, AuthStatus.unauthenticated);
      expect(await storage.read(), isNull);
    });

    test('login failure logs auth_error_shown event', () async {
      final user = buildTestUser();
      final api = ControlledAuthApi(user: user)
        ..loginError = DioException(
          requestOptions: RequestOptions(path: '/auth/login'),
          response: Response<Map<String, dynamic>>(
            requestOptions: RequestOptions(path: '/auth/login'),
            statusCode: 401,
            data: {'error': 'Unauthorized'},
          ),
          type: DioExceptionType.badResponse,
        );
      final controller = AuthController(
        api: api,
        sessionStorage: MemorySessionStorage(null),
      );

      await _waitAuthReady(controller);
      await controller.login(email: 'demo@visconde.app', password: 'invalid');

      expect(controller.state.status, AuthStatus.unauthenticated);
      final event = analyticsEvents
          .where((item) => item.name == 'auth_error_shown')
          .last;
      expect(event.params['session_expired'], true);
      expect(event.params['source'], 'login_submit');
    });
  });
}
