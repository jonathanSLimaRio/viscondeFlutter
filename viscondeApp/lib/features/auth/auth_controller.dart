import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/models/app_user.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/session_storage.dart';
import '../../shared/api_error.dart';
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

  Future<void> _restoreSession() async {
    final stored = await _sessionStorage.read();
    if (stored == null) {
      state = const AuthState(status: AuthStatus.unauthenticated);
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
    } catch (_) {
      try {
        final refreshed = await _api.refresh(refreshToken: stored.refreshToken);
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
      } catch (_) {
        await _sessionStorage.clear();
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    }
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
    } catch (error) {
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
    } catch (error) {
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
    } catch (error) {
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
    } catch (error) {
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
    } catch (_) {
      // Ignore logout failures in MVP and clear local session.
    }

    await _sessionStorage.clear();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void updateUser(AppUser user) {
    state = state.copyWith(user: user);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  String? get accessToken => state.accessToken;
}
