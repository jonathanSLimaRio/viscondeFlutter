import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:visconde_app/core/models/app_user.dart';
import 'package:visconde_app/core/models/child_profile.dart';
import 'package:visconde_app/core/storage/session_storage.dart';
import 'package:visconde_app/design_system/visconde.dart';
import 'package:visconde_app/features/auth/auth_api.dart';
import 'package:visconde_app/features/auth/auth_controller.dart';
import 'package:visconde_app/features/children/children_api.dart';
import 'package:visconde_app/features/story_room/models/story_models.dart';
import 'package:visconde_app/features/story_room/story_api.dart';
import 'package:visconde_app/shared/providers.dart';

class MemorySessionStorage extends SessionStorage {
  MemorySessionStorage(this._stored) : super(const FlutterSecureStorage());

  StoredSession? _stored;

  @override
  Future<void> clear() async {
    _stored = null;
  }

  @override
  Future<StoredSession?> read() async {
    return _stored;
  }

  @override
  Future<void> save(StoredSession session) async {
    _stored = session;
  }
}

class FakeAuthApi extends AuthApi {
  FakeAuthApi({required this.user}) : super(Dio());

  final AppUser user;

  @override
  Future<AppUser> me({required String accessToken}) async {
    return user;
  }
}

class FakeChildrenApi extends ChildrenApi {
  FakeChildrenApi({required this.children}) : super(Dio());

  final List<ChildProfile> children;

  @override
  Future<List<ChildProfile>> listChildren(String accessToken) async {
    return children;
  }
}

class FakeStoryApi extends StoryApi {
  FakeStoryApi({required this.collections, required this.virtues, this.session})
    : super(Dio());

  final List<StoryVaultCollectionItem> collections;
  final List<VirtueModel> virtues;
  final StorySessionModel? session;

  @override
  Future<List<StoryVaultCollectionItem>> listStoryVaultCollections(
    String accessToken, {
    String? childProfileId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? theme,
    String? virtueId,
    bool favoriteOnly = false,
  }) async {
    return collections;
  }

  @override
  Future<List<VirtueModel>> listVirtues(String accessToken) async {
    return virtues;
  }

  @override
  Future<StorySessionModel> getStorySession(
    String accessToken,
    String storyId,
  ) async {
    return session ?? _sampleSession(storyId);
  }

  @override
  Future<StorySessionModel> createStorySession(
    String accessToken, {
    required String childProfileId,
    required String titleDraft,
    required String theme,
    required String scenario,
    required List<Map<String, String?>> characters,
    required String objective,
    required StoryMode startMode,
    String? virtueId,
    String? sourceTemplateId,
  }) async {
    return session ?? _sampleSession('story-test');
  }

  StorySessionModel _sampleSession(String storyId) {
    final child = collections.isNotEmpty
        ? collections.first.child
        : const StoryVaultChild(id: 'child-1', name: 'Lucas');

    return StorySessionModel(
      id: storyId,
      childProfileId: child.id,
      collectionId: 'col-1',
      episodeNumber: 1,
      sessionKind: StorySessionKind.presencial,
      titleDraft: 'Aventura de Teste',
      title: 'Aventura de Teste',
      theme: 'Aventura',
      scenario: 'Floresta',
      objective: 'Ajudar um amigo',
      status: StoryStatus.draft,
      currentMode: StoryMode.parentNarrator,
      currentStepIndex: 1,
      ageSnapshotYears: 8,
      child: StoryChildSnapshot(
        id: child.id,
        name: child.name,
        birthDate: DateTime(2018, 1, 1),
      ),
      characters: const [StoryCharacterModel(id: 'c1', name: 'Luna')],
      steps: const [],
    );
  }
}

Widget wrapTestApp(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ViscondeTheme.buildLightTheme(),
      builder: (context, inner) {
        return ViscondeScaffoldBackground(
          child: inner ?? const SizedBox.shrink(),
        );
      },
      home: child,
    ),
  );
}

AppUser buildTestUser({bool isAdmin = false}) {
  return AppUser(
    id: 'user-1',
    email: 'admin@visconde.app',
    name: 'admin',
    timezone: 'UTC',
    role: isAdmin ? AppUserRole.admin : AppUserRole.user,
  );
}

StoredSession buildStoredSession(AppUser user) {
  return StoredSession(
    accessToken: 'token-123',
    refreshToken: 'refresh-123',
    user: user,
  );
}

List<Override> authOverrides({
  required AppUser user,
  bool authenticated = true,
}) {
  final storage = MemorySessionStorage(
    authenticated ? buildStoredSession(user) : null,
  );

  return [
    authApiProvider.overrideWith((ref) => FakeAuthApi(user: user)),
    sessionStorageProvider.overrideWith((ref) => storage),
  ];
}
