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

final authorizedDioProvider = Provider((ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  final accessToken = ref.watch(authControllerProvider).accessToken;
  return createApiDio(baseUrl: baseUrl, accessToken: accessToken);
});

final authorizedApiClientProvider = Provider<AuthorizedApiClient>((ref) {
  return AuthorizedApiClient(ref.watch(authorizedDioProvider));
});

final profileApiProvider = Provider<ProfileApi>((ref) {
  return ProfileApi(ref.watch(apiClientProvider).dio);
});

final childrenApiProvider = Provider<ChildrenApi>((ref) {
  return ChildrenApi(ref.watch(apiClientProvider).dio);
});

final securityApiProvider = Provider<SecurityApi>((ref) {
  return SecurityApi(ref.watch(apiClientProvider).dio);
});

final voiceApiProvider = Provider<VoiceApi>((ref) {
  return VoiceApi(ref.watch(authorizedApiClientProvider).dio);
});

final illustrationApiProvider = Provider<IllustrationApi>((ref) {
  return IllustrationApi(ref.watch(authorizedApiClientProvider).dio);
});

final gamificationApiProvider = Provider<GamificationApi>((ref) {
  return GamificationApi(ref.watch(apiClientProvider).dio);
});

final inventoryApiProvider = Provider<InventoryApi>((ref) {
  return InventoryApi(ref.watch(apiClientProvider).dio);
});

final storyApiProvider = Provider<StoryApi>((ref) {
  return StoryApi(ref.watch(apiClientProvider).dio);
});

final bookApiProvider = Provider<BookApi>((ref) {
  return BookApi(ref.watch(apiClientProvider).dio);
});

final adminApiProvider = Provider<AdminApi>((ref) {
  return AdminApi(ref.watch(apiClientProvider).dio);
});

final storySyncQueueProvider = Provider<StorySyncQueue>((ref) {
  final queue = StorySyncQueue();
  ref.onDispose(queue.dispose);
  return queue;
});
