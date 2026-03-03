import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/security/parental_gate_controller.dart';

class SessionAwareDioFactory {
  const SessionAwareDioFactory._();

  static Dio create({
    required Ref ref,
    required String baseUrl,
    required String? accessToken,
    required HttpClientAdapter? adapter,
  }) {
    final authNotifier = ref.read(authControllerProvider.notifier);
    final dio = createApiDio(
      baseUrl: baseUrl,
      accessToken: accessToken,
      httpClientAdapter: adapter,
      mapErrors: false,
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) async {
          final requestOptions = error.requestOptions;
          final status = error.response?.statusCode;
          final responseCode = _extractErrorCode(error.response?.data);
          final isParentalUnlockError =
              status == 401 &&
              (responseCode == 'PARENTAL_UNLOCK_REQUIRED' ||
                  responseCode == 'PARENTAL_UNLOCK_INVALID');
          final authState = authNotifier.snapshot;

          if (isParentalUnlockError) {
            ref.read(parentalGateControllerProvider.notifier).clear();
            handler.next(error);
            return;
          }

          if (shouldAttemptAuthRetry(requestOptions, status) &&
              authState.status == AuthStatus.authenticated) {
            final refreshedToken = await authNotifier
                .refreshSessionIfPossible();
            if (refreshedToken != null) {
              try {
                final retriedRequest = markRequestAuthRetried(
                  requestOptions,
                  accessToken: refreshedToken,
                );
                final response = await dio.fetch<dynamic>(retriedRequest);
                handler.resolve(response);
                return;
              } on DioException catch (retryError) {
                handler.next(retryError);
                return;
              } catch (retryError) {
                handler.next(
                  DioException(
                    requestOptions: requestOptions,
                    type: DioExceptionType.unknown,
                    error: retryError,
                  ),
                );
                return;
              }
            }
          }

          if (status == 401 &&
              authState.status == AuthStatus.authenticated &&
              !requestDisablesAuthRetry(requestOptions)) {
            await authNotifier.expireSession(
              reason: 'Sua sessão expirou. Faça login novamente.',
            );
          }

          handler.next(error);
        },
      ),
    );

    return dio;
  }
}

String? _extractErrorCode(Object? raw) {
  if (raw is Map) {
    final code = raw['code'];
    if (code is String && code.trim().isNotEmpty) {
      return code.trim();
    }
  }

  return null;
}
