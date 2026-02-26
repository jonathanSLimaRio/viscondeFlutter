import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../features/children/children_api.dart';
import '../features/profile/profile_api.dart';
import '../features/security/security_api.dart';
import '../features/story_room/story_api.dart';
import '../features/story_sync/story_sync_queue.dart';

final profileApiProvider = Provider<ProfileApi>((ref) {
  return ProfileApi(ref.watch(dioProvider));
});

final childrenApiProvider = Provider<ChildrenApi>((ref) {
  return ChildrenApi(ref.watch(dioProvider));
});

final securityApiProvider = Provider<SecurityApi>((ref) {
  return SecurityApi(ref.watch(dioProvider));
});

final storyApiProvider = Provider<StoryApi>((ref) {
  return StoryApi(ref.watch(dioProvider));
});

final storySyncQueueProvider = Provider<StorySyncQueue>((ref) {
  final queue = StorySyncQueue();
  ref.onDispose(queue.dispose);
  return queue;
});
