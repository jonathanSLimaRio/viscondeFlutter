import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../features/auth/auth_controller.dart';
import '../features/admin/admin_api.dart';
import '../features/children/children_api.dart';
import '../features/gamification/gamification_api.dart';
import '../features/gamification/inventory_api.dart';
import '../features/profile/profile_api.dart';
import '../features/security/parental_gate_controller.dart';
import '../features/security/parental_unlock_service.dart';
import '../features/security/security_api.dart';
import '../features/security/voice_api.dart';
import '../features/story_room/illustration_api.dart';
import '../features/story_room/story_api.dart';
import '../features/story_sync/story_sync_queue.dart';
import '../features/story_vault/book_api.dart';
import '../features/story_creation/create_story_wizard_draft_store.dart';
import 'ux_analytics_api.dart';
import 'ux_analytics_queue.dart';
import 'ux_analytics_service.dart';

final sessionAwareDioProvider = Provider<Dio>((ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  final accessToken = ref.watch(authControllerProvider).accessToken;
  final authNotifier = ref.read(authControllerProvider.notifier);
  final adapter = ref.watch(dioHttpClientAdapterProvider);
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
          final refreshedToken = await authNotifier.refreshSessionIfPossible();
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
});

final authorizedApiClientProvider = Provider<AuthorizedApiClient>((ref) {
  return AuthorizedApiClient(ref.watch(sessionAwareDioProvider));
});

final profileApiProvider = Provider<ProfileApi>((ref) {
  return ProfileApi(ref.watch(sessionAwareDioProvider));
});

final childrenApiProvider = Provider<ChildrenApi>((ref) {
  return ChildrenApi(ref.watch(sessionAwareDioProvider));
});

final securityApiProvider = Provider<SecurityApi>((ref) {
  return SecurityApi(ref.watch(sessionAwareDioProvider));
});

final parentalUnlockServiceProvider = Provider<ParentalUnlockService>((ref) {
  return ParentalUnlockService(
    ref,
    securityApi: ref.watch(securityApiProvider),
  );
});

final voiceApiProvider = Provider<VoiceApi>((ref) {
  return VoiceApi(ref.watch(authorizedApiClientProvider).dio);
});

final illustrationApiProvider = Provider<IllustrationApi>((ref) {
  return IllustrationApi(ref.watch(authorizedApiClientProvider).dio);
});

final gamificationApiProvider = Provider<GamificationApi>((ref) {
  return GamificationApi(ref.watch(sessionAwareDioProvider));
});

final inventoryApiProvider = Provider<InventoryApi>((ref) {
  return InventoryApi(ref.watch(sessionAwareDioProvider));
});

final storyApiProvider = Provider<StoryApi>((ref) {
  return StoryApi(ref.watch(sessionAwareDioProvider));
});

final bookApiProvider = Provider<BookApi>((ref) {
  return BookApi(ref.watch(sessionAwareDioProvider));
});

final adminApiProvider = Provider<AdminApi>((ref) {
  return AdminApi(ref.watch(sessionAwareDioProvider));
});

final storySyncQueueProvider = Provider<StorySyncQueue>((ref) {
  final queue = StorySyncQueue();
  ref.onDispose(queue.dispose);
  return queue;
});

final uxAnalyticsQueueProvider = Provider<UxAnalyticsQueue>((ref) {
  final queue = UxAnalyticsQueue();
  ref.onDispose(() {
    unawaited(queue.dispose());
  });
  return queue;
});

final uxAnalyticsApiProvider = Provider<UxAnalyticsApi>((ref) {
  return UxAnalyticsApi(ref.watch(dioProvider));
});

final uxAnalyticsServiceProvider = Provider<UxAnalyticsService>((ref) {
  final service = UxAnalyticsService(
    store: ref.watch(uxAnalyticsQueueProvider),
    transport: ref.watch(uxAnalyticsApiProvider),
    readAccessToken: () => ref.read(authControllerProvider).accessToken,
  );
  ref.onDispose(() {
    unawaited(service.dispose());
  });
  return service;
});

final createStoryWizardDraftStoreProvider =
    Provider<CreateStoryWizardDraftStore>((ref) {
      final store = SQLiteCreateStoryWizardDraftStore();
      ref.onDispose(() {
        unawaited(store.dispose());
      });
      return store;
    });

String? _extractErrorCode(Object? raw) {
  if (raw is Map) {
    final code = raw['code'];
    if (code is String && code.trim().isNotEmpty) {
      return code.trim();
    }
  }

  return null;
}
