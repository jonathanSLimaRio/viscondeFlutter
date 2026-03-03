import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../features/auth/auth_controller.dart';
import '../features/admin/admin_api.dart';
import '../features/children/children_api.dart';
import '../features/gamification/gamification_api.dart';
import '../features/gamification/inventory_api.dart';
import '../features/profile/profile_api.dart';
import '../features/security/security_api.dart';
import '../features/security/voice_api.dart';
import '../features/story_room/illustration_api.dart';
import '../features/story_room/story_api.dart';
import '../features/story_sync/story_sync_queue.dart';
import '../features/story_vault/book_api.dart';

final sessionAwareDioProvider = Provider<Dio>((ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  final accessToken = ref.watch(authControllerProvider).accessToken;
  final dio = createApiDio(baseUrl: baseUrl, accessToken: accessToken);

  dio.interceptors.add(
    InterceptorsWrapper(
      onError: (error, handler) async {
        final status = error.response?.statusCode;
        final auth = ref.read(authControllerProvider);
        if (status == 401 && auth.status == AuthStatus.authenticated) {
          await ref
              .read(authControllerProvider.notifier)
              .expireSession(
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
