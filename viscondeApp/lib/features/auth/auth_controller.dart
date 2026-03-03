import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/models/app_user.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/session_storage.dart';
import '../../shared/logging/app_logger.dart';
import '../../shared/api_error.dart';
import '../../shared/ux_analytics.dart';
import 'auth_api.dart';

enum AuthStatus { loading, unauthenticated, authenticated }

class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.accessToken,
    this.refreshToken,
    this.error,
  });

  final AuthStatus status;
  final AppUser? user;
  final String? accessToken;
  final String? refreshToken;
  final String? error;

  AuthState copyWith({
    AuthStatus? status,
    AppUser? user,
    String? accessToken,
    String? refreshToken,
    String? error,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      error: clearError ? null : (error ?? this.error),
    );
  }

  static const initial = AuthState(status: AuthStatus.loading);
}

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final sessionStorageProvider = Provider<SessionStorage>((ref) {
  return SessionStorage(ref.watch(secureStorageProvider));
});

final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(ref.watch(dioProvider));
});

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    return AuthController(
      api: ref.watch(authApiProvider),
      sessionStorage: ref.watch(sessionStorageProvider),
    );
  },
);

class AuthController extends StateNotifier<AuthState> {
  AuthController({required AuthApi api, required SessionStorage sessionStorage})
    : _api = api,
      _sessionStorage = sessionStorage,
      super(AuthState.initial) {
    _restoreSession();
  }

  final AuthApi _api;
  final SessionStorage _sessionStorage;
  Future<String?>? _refreshInFlight;

  Future<bool> _tryDevAutoLogin() async {
    if (!kDebugMode || !devAutoLoginEnabled || !hasExplicitDevCredentials) {
      return false;
    }

    try {
      final session = await _api.login(
        email: devAdminEmail,
        password: devAdminPassword,
      );

      await _sessionStorage.save(
        StoredSession(
          accessToken: session.accessToken,
          refreshToken: session.refreshToken,
          user: session.user,
        ),
      );

      state = AuthState(
        status: AuthStatus.authenticated,
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        user: session.user,
      );
      _logSessionStarted(source: 'dev_auto_login_success');

      return true;
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Falha no auto-login de desenvolvimento.',
        error: error,
        stackTrace: stackTrace,
        scope: 'auth',
      );
      state = AuthState(
        status: AuthStatus.unauthenticated,
        error: 'Auto-login dev falhou: ${parseDioError(error)}',
      );
      return false;
    }
  }

  Future<void> _restoreSession() async {
    final stored = await _sessionStorage.read();
    if (stored == null) {
      final autoLogged = await _tryDevAutoLogin();
      if (!autoLogged) {
        state = state.status == AuthStatus.loading
            ? const AuthState(status: AuthStatus.unauthenticated)
            : state;
      }
      return;
    }

    try {
      final user = await _api.me(accessToken: stored.accessToken);
      state = AuthState(
        status: AuthStatus.authenticated,
        accessToken: stored.accessToken,
        refreshToken: stored.refreshToken,
        user: user,
      );
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Falha ao restaurar sessão por /me. Tentando refresh.',
        error: error,
        stackTrace: stackTrace,
        scope: 'auth',
      );
      final refreshed = await refreshSessionIfPossible(
        withUserFacingError: false,
        refreshTokenOverride: stored.refreshToken,
      );
      if (refreshed == null) {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    }
  }

  Future<String?> refreshSessionIfPossible({
    bool withUserFacingError = true,
    String? refreshTokenOverride,
  }) async {
    final inFlight = _refreshInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final refreshFuture = _refreshSessionInternal(
      withUserFacingError: withUserFacingError,
      refreshTokenOverride: refreshTokenOverride,
    );
    _refreshInFlight = refreshFuture;

    try {
      return await refreshFuture;
    } finally {
      if (identical(_refreshInFlight, refreshFuture)) {
        _refreshInFlight = null;
      }
    }
  }

  Future<String?> _refreshSessionInternal({
    required bool withUserFacingError,
    String? refreshTokenOverride,
  }) async {
    final refreshToken = refreshTokenOverride ?? state.refreshToken;
    if (refreshToken == null || refreshToken.trim().isEmpty) {
      await _clearSession(
        userFacingReason: withUserFacingError
            ? 'Sua sessão expirou. Faça login novamente.'
            : null,
      );
      UxAnalytics.log(
        'auth_refresh_failed',
        params: const <String, Object?>{'reason': 'missing_refresh_token'},
      );
      return null;
    }

    try {
      final refreshed = await _api.refresh(refreshToken: refreshToken);
      await _sessionStorage.save(
        StoredSession(
          accessToken: refreshed.accessToken,
          refreshToken: refreshed.refreshToken,
          user: refreshed.user,
        ),
      );

      state = AuthState(
        status: AuthStatus.authenticated,
        accessToken: refreshed.accessToken,
        refreshToken: refreshed.refreshToken,
        user: refreshed.user,
      );

      UxAnalytics.log(
        'auth_refresh_success',
        params: const <String, Object?>{'source': 'interceptor'},
      );
      return refreshed.accessToken;
    } catch (error) {
      UxAnalytics.log(
        'auth_refresh_failed',
        params: <String, Object?>{'message': parseDioError(error)},
      );
      await _clearSession(
        userFacingReason: withUserFacingError
            ? 'Sua sessão expirou. Faça login novamente.'
            : null,
      );
      return null;
    }
  }

  Future<void> _clearSession({String? userFacingReason}) async {
    await _sessionStorage.clear();
    state = userFacingReason == null
        ? const AuthState(status: AuthStatus.unauthenticated)
        : AuthState(
            status: AuthStatus.unauthenticated,
            error: userFacingReason,
          );
  }

  void _logSessionStarted({required String source}) {
    UxAnalytics.log(
      'session_started',
      params: <String, Object?>{'source': source, 'user_id': state.user?.id},
    );
  }

  void _logAuthError(Object error, {required String source}) {
    final presentation = describeApiError(error);
    UxAnalytics.log(
      'auth_error_shown',
      params: <String, Object?>{
        'session_expired': presentation.sessionExpired,
        'message': presentation.message,
        if (presentation.kind != null) 'error_kind': presentation.kind!.name,
        if (presentation.statusCode != null)
          'status_code': presentation.statusCode!,
        if (presentation.code != null && presentation.code!.trim().isNotEmpty)
          'code': presentation.code!.trim(),
        'source': source,
      },
    );
  }

  Future<void> login({required String email, required String password}) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final session = await _api.login(email: email, password: password);
      await _sessionStorage.save(
        StoredSession(
          accessToken: session.accessToken,
          refreshToken: session.refreshToken,
          user: session.user,
        ),
      );

      state = AuthState(
        status: AuthStatus.authenticated,
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        user: session.user,
      );
      _logSessionStarted(source: 'login_success');
    } catch (error) {
      _logAuthError(error, source: 'login_submit');
      state = AuthState(
        status: AuthStatus.unauthenticated,
        error: parseDioError(error),
      );
    }
  }

  Future<void> signup({
    required String email,
    required String password,
    required String name,
    required String timezone,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final session = await _api.signup(
        email: email,
        password: password,
        name: name,
        timezone: timezone,
      );
      await _sessionStorage.save(
        StoredSession(
          accessToken: session.accessToken,
          refreshToken: session.refreshToken,
          user: session.user,
        ),
      );

      state = AuthState(
        status: AuthStatus.authenticated,
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        user: session.user,
      );
      _logSessionStarted(source: 'signup_success');
    } catch (error) {
      _logAuthError(error, source: 'signup_submit');
      state = AuthState(
        status: AuthStatus.unauthenticated,
        error: parseDioError(error),
      );
    }
  }

  Future<void> loginWithGoogleToken(String idToken) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final session = await _api.loginWithGoogle(idToken: idToken);
      await _sessionStorage.save(
        StoredSession(
          accessToken: session.accessToken,
          refreshToken: session.refreshToken,
          user: session.user,
        ),
      );

      state = AuthState(
        status: AuthStatus.authenticated,
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        user: session.user,
      );
      _logSessionStarted(source: 'google_login_success');
    } catch (error) {
      _logAuthError(error, source: 'google_login_submit');
      state = AuthState(
        status: AuthStatus.unauthenticated,
        error: parseDioError(error),
      );
    }
  }

  Future<void> loginWithAppleToken(String idToken) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final session = await _api.loginWithApple(idToken: idToken);
      await _sessionStorage.save(
        StoredSession(
          accessToken: session.accessToken,
          refreshToken: session.refreshToken,
          user: session.user,
        ),
      );

      state = AuthState(
        status: AuthStatus.authenticated,
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        user: session.user,
      );
      _logSessionStarted(source: 'apple_login_success');
    } catch (error) {
      _logAuthError(error, source: 'apple_login_submit');
      state = AuthState(
        status: AuthStatus.unauthenticated,
        error: parseDioError(error),
      );
    }
  }

  Future<void> forgotPassword(String email) async {
    await _api.forgotPassword(email);
  }

  Future<void> logout() async {
    try {
      await _api.logout(
        accessToken: state.accessToken,
        refreshToken: state.refreshToken,
      );
    } catch (error, stackTrace) {
      // Não bloquear logout local por falha remota.
      AppLogger.warn(
        'Falha ao invalidar sessão remota durante logout.',
        error: error,
        stackTrace: stackTrace,
        scope: 'auth',
      );
    }

    await _clearSession();
  }

  Future<void> expireSession({
    String reason = 'Sua sessão expirou. Faça login novamente.',
  }) async {
    if (state.status == AuthStatus.unauthenticated) {
      return;
    }

    await _clearSession(userFacingReason: reason);
  }

  void updateUser(AppUser user) {
    state = state.copyWith(user: user);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  String? get accessToken => state.accessToken;
  AuthState get snapshot => state;
}
