import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visconde_app/core/models/app_user.dart';
import 'package:visconde_app/core/models/auth_session.dart';
import 'package:visconde_app/features/auth/auth_api.dart';
import 'package:visconde_app/features/auth/auth_controller.dart';

import '../../helpers/test_harness.dart';

class ControlledAuthApi extends AuthApi {
  ControlledAuthApi({required this.user}) : super(Dio());

  final AppUser user;
  Object? meError;
  Object? refreshError;
  Object? logoutError;
  AuthSession? refreshSession;
  int logoutCalls = 0;

  @override
  Future<AppUser> me({required String accessToken}) async {
    final error = meError;
    if (error != null) {
      throw error;
    }
    return user;
  }

  @override
  Future<AuthSession> refresh({required String refreshToken}) async {
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
  });
}
