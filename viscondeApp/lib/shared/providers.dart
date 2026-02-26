import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../features/children/children_api.dart';
import '../features/profile/profile_api.dart';
import '../features/security/security_api.dart';

final profileApiProvider = Provider<ProfileApi>((ref) {
  return ProfileApi(ref.watch(dioProvider));
});

final childrenApiProvider = Provider<ChildrenApi>((ref) {
  return ChildrenApi(ref.watch(dioProvider));
});

final securityApiProvider = Provider<SecurityApi>((ref) {
  return SecurityApi(ref.watch(dioProvider));
});
